import Entities
import Foundation
import ServiceProtocols
import Session

/// Live card-status source: the actor that owns the per-card status event
/// stream and an in-memory per-id cache.
///
/// `CardStatusRepositoryProtocol` is a thin validation/error wrapper over
/// this actor. It subscribes on `card.events.{cardId}` and parses only
/// the status-shaped payloads on that channel — balance/transaction/limit
/// frames decode as `CardState` failures and are skipped, keeping one
/// source of truth per card while other data sources parse their own kinds
/// from the same channel.
///
/// Contract notes:
/// - A returned stream means "subscribed": `subscribeToCardStatus` throws on
///   setup failure (invalid card id) before any stream is handed out.
/// - The stream yields the current cached state first, then live updates —
///   so a re-subscribe after a disconnect/reload renders the last known
///   state immediately: models re-subscribe on reload. The seed is buffered
///   before the stream is returned, so the first element is deterministic.
/// - Delivery is the happens-before edge for the cache: a frame is written
///   to the per-id cache *before* it is yielded, so once a state has been
///   observed on a subscription, `getCardStatus` answers it. (An event
///   freshly injected into the session but not yet delivered has no such
///   ordering guarantee — event processing is asynchronous.)
/// - The per-id cache lets `getCardStatus` answer immediately without a
///   network round-trip; `nil` means no state is known yet.
/// - The per-id cache is bounded (`cacheLimit`, default 50 entries, LRU
///   eviction) so a long-lived source never grows without bound — the same
///   50-item budget `CacheManager` applies to ephemeral live state. Evicted
///   entries simply read as "not known" until the next status frame
///   arrives.
public actor CardStateDataSource {
    private let eventSubscriptionManager: any EventSubscriptionManagerProtocol
    private let logger: any LoggerProtocol
    private let decoder = JSONDecoder()

    /// Default cap for the per-id cache (50 items).
    public static let defaultCacheLimit = 50

    private let cacheLimit: Int

    /// Per-id cache of the latest decoded `CardState` seen on the wire.
    private var cardStatesCache: [String: CardState] = [:]

    /// Card ids most-recently-used first; bounds the cache to `cacheLimit`
    /// entries (LRU eviction on insert when the cap is exceeded).
    private var cacheRecency: [String] = []

    /// - Parameters:
    ///   - eventSubscriptionManager: The session facade data sources receive.
    ///   - logger: Receives `.error` messages for skipped malformed payloads.
    ///   - cacheLimit: Maximum per-id cache entries before LRU eviction;
    ///     inject a small value in tests.
    public init(
        eventSubscriptionManager: any EventSubscriptionManagerProtocol,
        logger: any LoggerProtocol,
        cacheLimit: Int = CardStateDataSource.defaultCacheLimit,
    ) {
        self.eventSubscriptionManager = eventSubscriptionManager
        self.logger = logger
        self.cacheLimit = cacheLimit
    }

    // MARK: - Cache

    /// Reads one card's cached state and bumps its recency (LRU).
    private func cachedState(for cardId: String) -> CardState? {
        guard cardStatesCache[cardId] != nil else {
            return nil
        }
        touch(cardId)
        return cardStatesCache[cardId]
    }

    /// Writes or refreshes one card's state under LRU order, evicting the
    /// least-recently-used entry when the cache is over its limit.
    private func cache(_ state: CardState) {
        cardStatesCache[state.cardId] = state
        touch(state.cardId)
        while cacheRecency.count > cacheLimit {
            let evicted = cacheRecency.removeLast()
            cardStatesCache.removeValue(forKey: evicted)
        }
    }

    /// Marks `cardId` as most-recently-used.
    private func touch(_ cardId: String) {
        cacheRecency.removeAll { $0 == cardId }
        cacheRecency.insert(cardId, at: 0)
    }

    // MARK: - One-shot

    /// The latest known status for one card, or `nil` when no status has
    /// arrived on the wire yet (cache read — no network round-trip).
    public func getCardStatus(cardId: String) async -> CardState? {
        cachedState(for: cardId)
    }

    // MARK: - Subscription

    /// Subscribes to one card's status updates on `card.events.{cardId}`.
    ///
    /// Throws `AppError.validationError` when `cardId` is empty — a returned
    /// stream means the subscription is live.
    public func subscribeToCardStatus(cardId: String) async throws -> AsyncStream<CardState> {
        guard !cardId.isEmpty else {
            throw AppError.validationError(
                field: "cardId",
                reason: "Card id must not be empty.",
            )
        }
        let channel = EventChannels.cardEvents(cardId: cardId)
        // The session facade is `@MainActor` (its `events(for:)` is a sync
        // protocol requirement), so registration hops to the main actor
        // before touching it — actor-isolated callers cannot invoke the
        // main-actor witness directly.
        let eventManager = eventSubscriptionManager
        let source = await MainActor.run {
            eventManager.events(for: channel)
        }
        let cached = cachedState(for: cardId)
        return AsyncStream { continuation in
            // Seed the stream *synchronously*, before the stream is handed
            // out: whatever the cache holds right now is buffered as the
            // first element, so a resubscribe deterministically yields the
            // last known state first — no scheduling race with the live
            // consumer task below.
            if let cached {
                continuation.yield(cached)
            }
            // The producer task is unstructured and deliberately does NOT
            // inherit the actor's isolation: `self` is captured weakly so a
            // subscription must not pin the whole actor (and its session
            // facade) in memory once the source is no longer needed. Every
            // event hops to the actor via `await process`, which keeps the
            // cache write race-free and yields only after caching — delivery
            // stays the happens-before edge for reads.
            let task = Task { [weak self] in
                for await event in source {
                    if Task.isCancelled {
                        break
                    }
                    guard let self else {
                        break
                    }
                    await process(event, cardId: cardId, continuation: continuation)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    // MARK: - Parsing

    /// Normalizes one wire payload into a typed `CardState`.
    ///
    /// Any payload that is not a status frame (other entity kinds on the
    /// shared per-card channel, malformed JSON, unknown statuses) is logged
    /// and skipped — a decode failure is never a stream error and never a
    /// crash.
    func parseEvent(_ event: BankingEvent) -> CardState? {
        guard let data = event.payload.data(using: .utf8) else {
            logger.log(
                "CardState from \(event.channel): payload is not UTF-8.",
                level: .error,
            )
            return nil
        }
        return try? decoder.decode(
            CardState.self,
            from: data,
            logger: logger,
            context: "CardState from \(event.channel)",
        )
    }

    /// Actor-isolated event handling: update the per-id cache, then yield to
    /// the subscriber only when the frame concerns the subscribed card. A
    /// misrouted frame for another card warms that card's cache entry but is
    /// never delivered on this subscription.
    private func process(
        _ event: BankingEvent,
        cardId: String,
        continuation: AsyncStream<CardState>.Continuation,
    ) {
        guard let state = parseEvent(event) else {
            return
        }
        cache(state)
        guard state.cardId == cardId else {
            return
        }
        continuation.yield(state)
    }
}
