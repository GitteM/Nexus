import Entities
import Foundation
import ServiceProtocols
import Session

/// Offer-list source with a TTL-bounded in-memory cache (architecture.md
/// §6.1, tasks.md Day 6: "offers cache drops stale entries after a few
/// minutes").
///
/// The backend owns the offer list and publishes full-list replacements on
/// `card.offers` (an `OffersSnapshotDTO` envelope). Every snapshot replaces
/// the cache; reads and stream seeding only serve snapshots fresher than
/// `ttl` — a stale entry is dropped rather than shown, so the dashboard never
/// renders offers the backend stopped publishing.
///
/// Contract notes:
/// - `getAvailableOffers` answers from the cache without a network hop —
///   `[]` means "no fresh offers known" (empty is a valid UI state, and the
///   dashboard treats it as an empty offers row).
/// - `subscribeToOffers` yields the current fresh list first, then every
///   replacement (architecture.md §4.2 `CardOffersRepositoryProtocol`: "the
///   stream yields the current offers first, then updates as they change").
///   The seed is buffered before the stream is returned, so the first
///   element is deterministic.
/// - Delivery is the happens-before edge for the cache: a snapshot is
///   written *before* it is yielded, so once a list has been observed on a
///   subscription, `getAvailableOffers` answers it. (An event freshly
///   injected into the session but not yet delivered has no such ordering
///   guarantee — event processing is asynchronous.)
/// - Malformed snapshots are logged and skipped; a decode failure never
///   clears or half-applies the cache.
public actor OffersDataSource {
    /// Default freshness window for a cached snapshot (architecture.md §6.1:
    /// "a few minutes").
    public static let defaultTTL: TimeInterval = 5 * 60

    private let eventSubscriptionManager: any EventSubscriptionManagerProtocol
    private let logger: any LoggerProtocol
    private let decoder = JSONDecoder()
    private let ttl: TimeInterval

    /// Latest decoded snapshot; `nil` until the first `card.offers` frame.
    private var cachedOffers: [CardOffer]?
    /// When `cachedOffers` arrived on the wire.
    private var receivedAt: Date?

    /// - Parameters:
    ///   - eventSubscriptionManager: The session facade data sources receive.
    ///   - logger: Receives `.error` messages for skipped malformed payloads.
    ///   - ttl: Snapshot freshness window; inject a short value in tests.
    public init(
        eventSubscriptionManager: any EventSubscriptionManagerProtocol,
        logger: any LoggerProtocol,
        ttl: TimeInterval = OffersDataSource.defaultTTL,
    ) {
        self.eventSubscriptionManager = eventSubscriptionManager
        self.logger = logger
        self.ttl = ttl
    }

    // MARK: - One-shot

    /// The current offer list when a fresh snapshot is cached, otherwise `[]`.
    public func getAvailableOffers() async -> [CardOffer] {
        freshSnapshot() ?? []
    }

    // MARK: - Subscription

    /// Subscribes to full-list offer snapshots on `card.offers`.
    ///
    /// The stream yields the current fresh snapshot first (when one exists),
    /// then every replacement the backend publishes.
    public func subscribeToOffers() async -> AsyncStream<[CardOffer]> {
        // The session facade is `@MainActor` (its `events(for:)` is a sync
        // protocol requirement), so registration hops to the main actor
        // before touching it — actor-isolated callers cannot invoke the
        // main-actor witness directly (architecture.md §12.3 #8).
        let eventManager = eventSubscriptionManager
        let source = await MainActor.run {
            eventManager.events(for: EventChannels.offers)
        }
        let cached = freshSnapshot()
        return AsyncStream { continuation in
            // Seed the stream *synchronously*, before the stream is handed
            // out: a fresh snapshot is buffered as the first element, so a
            // resubscribe deterministically sees the current list first — no
            // scheduling race with the live consumer task below.
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
                    await process(event, continuation: continuation)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    // MARK: - Parsing

    /// Normalizes one `card.offers` payload into the decoded offer list
    /// (architecture.md §6.1 `parseEvent`). Any frame that is not a valid
    /// snapshot — malformed JSON, a missing `offers` key, an offer that does
    /// not decode — is logged and skipped.
    func parseEvent(_ event: BankingEvent) -> [CardOffer]? {
        guard let data = event.payload.data(using: .utf8) else {
            logger.log(
                "OffersSnapshot from \(event.channel): payload is not UTF-8.",
                level: .error,
            )
            return nil
        }
        let dto = try? decoder.decode(
            OffersSnapshotDTO.self,
            from: data,
            logger: logger,
            context: "OffersSnapshot from \(event.channel)",
        )
        return dto?.offers
    }

    /// Actor-isolated event handling: replace the cache and fan the snapshot
    /// out to the subscriber. A valid empty list (`{"offers":[]}`) replaces
    /// the cache too — the backend clearing offers is a real state.
    private func process(
        _ event: BankingEvent,
        continuation: AsyncStream<[CardOffer]>.Continuation,
    ) {
        guard let offers = parseEvent(event) else {
            return
        }
        cachedOffers = offers
        receivedAt = Date()
        continuation.yield(offers)
    }

    /// The cached snapshot when it is still fresh; a stale (or never
    /// received) snapshot is reported as missing.
    ///
    /// Side effect: reading past the TTL clears the stale snapshot and its
    /// timestamp, so an expired list is neither served nor retained — the
    /// dashboard must never render offers the backend stopped publishing.
    /// Both the one-shot read and the subscription seed go through this one
    /// method, so eviction behaves identically on either path.
    private func freshSnapshot() -> [CardOffer]? {
        guard
            let cachedOffers,
            let receivedAt,
            Date().timeIntervalSince(receivedAt) < ttl
        else {
            if cachedOffers != nil {
                cachedOffers = nil
                receivedAt = nil
            }
            return nil
        }
        return cachedOffers
    }
}
