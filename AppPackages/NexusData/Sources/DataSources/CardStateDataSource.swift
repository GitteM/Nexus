import Entities
import Foundation
import ServiceProtocols
import Session

/// Live card-status source: the actor that owns the per-card status event
/// stream and an in-memory per-id cache (architecture.md §6.1, tasks.md
/// Day 6).
///
/// `CardStatusRepositoryProtocol` (Day 7) is a thin validation/error wrapper
/// over this actor. It subscribes on `card.events.{cardId}` and parses only
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
///   state immediately (architecture.md §9.1: models re-subscribe on
///   reload). The seed is buffered before the stream is returned, so the
///   first element is deterministic.
/// - Delivery is the happens-before edge for the cache: a frame is written
///   to the per-id cache *before* it is yielded, so once a state has been
///   observed on a subscription, `getCardStatus` answers it. (An event
///   freshly injected into the session but not yet delivered has no such
///   ordering guarantee — event processing is asynchronous.)
/// - The per-id cache lets `getCardStatus` answer immediately without a
///   network round-trip; `nil` means no state is known yet.
public actor CardStateDataSource {
    private let eventSubscriptionManager: any EventSubscriptionManagerProtocol
    private let logger: any LoggerProtocol
    private let decoder = JSONDecoder()

    /// Per-id cache of the latest decoded `CardState` seen on the wire.
    private var cardStatesCache: [String: CardState] = [:]

    public init(
        eventSubscriptionManager: any EventSubscriptionManagerProtocol,
        logger: any LoggerProtocol,
    ) {
        self.eventSubscriptionManager = eventSubscriptionManager
        self.logger = logger
    }

    // MARK: - One-shot

    /// The latest known status for one card, or `nil` when no status has
    /// arrived on the wire yet (cache read — no network round-trip).
    public func getCardStatus(cardId: String) async -> CardState? {
        cardStatesCache[cardId]
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
        // main-actor witness directly (architecture.md §12.3 #8).
        let eventManager = eventSubscriptionManager
        let source = await MainActor.run {
            eventManager.events(for: channel)
        }
        let cached = cardStatesCache[cardId]
        return AsyncStream { continuation in
            // Seed the stream *synchronously*, before the stream is handed
            // out: whatever the cache holds right now is buffered as the
            // first element, so a resubscribe deterministically yields the
            // last known state first — no scheduling race with the live
            // consumer task below.
            if let cached {
                continuation.yield(cached)
            }
            let task = Task {
                for await event in source {
                    if Task.isCancelled {
                        break
                    }
                    // The task inherits the actor's isolation, so `process`
                    // runs on the actor and writes the cache race-free.
                    self.process(event, cardId: cardId, continuation: continuation)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    // MARK: - Parsing

    /// Normalizes one wire payload into a typed `CardState`
    /// (architecture.md §6.1: `parseEvent`).
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
        cardStatesCache[state.cardId] = state
        guard state.cardId == cardId else {
            return
        }
        continuation.yield(state)
    }
}
