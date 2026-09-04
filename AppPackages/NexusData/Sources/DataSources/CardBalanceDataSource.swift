import Entities
import Foundation
import ServiceProtocols
import Session

/// Live balance source: the actor that owns one card's balance event
/// stream and a per-card cache (architecture.md §6.1, tasks.md Day 13).
///
/// `BalanceRepositoryProtocol` (thin validation/error wrapper) exposes this
/// actor. It subscribes on `card.events.{cardId}` and parses only the
/// balance-shaped payloads on that channel — status/transaction/limit
/// frames decode as `Balance` failures and are skipped, keeping one source
/// of truth per kind while other data sources parse their own kinds from
/// the same channel (the `CardStateDataSource` contract, §6.1).
///
/// Contract notes (mirror `CardStateDataSource`):
/// - A returned stream means "subscribed": `subscribeToBalance` throws on
///   setup failure before any stream is handed out.
/// - The stream yields the current cached balance first, then live updates;
///   the seed is buffered before the stream is returned, so re-subscribes
///   are deterministic.
/// - Delivery is the happens-before edge for the cache: a frame is written
///   to the per-id cache *before* it is yielded, so once a balance has been
///   observed, `getBalance` answers it.
/// - The per-id cache is bounded (`cacheLimit`, default 50) so a
///   long-lived source never grows without bound (architecture.md §6.4).
public actor CardBalanceDataSource {
    private let eventSubscriptionManager: any EventSubscriptionManagerProtocol
    private let logger: any LoggerProtocol
    private let decoder = JSONDecoder()

    /// Default cap for the per-id cache (architecture.md §6.4: 50 items).
    public static let defaultCacheLimit = 50

    private let cacheLimit: Int
    /// Latest decoded balance per card id.
    private var balancesByCardId: [String: Balance] = [:]

    /// - Parameters:
    ///   - eventSubscriptionManager: The session facade data sources receive.
    ///   - logger: Receives `.error` messages for skipped malformed payloads.
    ///   - cacheLimit: Maximum per-id cache entries; inject a small value in
    ///     tests.
    public init(
        eventSubscriptionManager: any EventSubscriptionManagerProtocol,
        logger: any LoggerProtocol,
        cacheLimit: Int = CardBalanceDataSource.defaultCacheLimit,
    ) {
        self.eventSubscriptionManager = eventSubscriptionManager
        self.logger = logger
        self.cacheLimit = cacheLimit
    }

    // MARK: - One-shot

    /// The latest known balance for one card, or `nil` when no balance has
    /// arrived on the wire yet (cache read — no network round-trip).
    public func getBalance(cardId: String) async -> Balance? {
        balancesByCardId[cardId]
    }

    // MARK: - Subscription

    /// Subscribes to one card's balance on `card.events.{cardId}`.
    ///
    /// Throws `AppError.validationError` when `cardId` is empty — a returned
    /// stream means the subscription is live.
    public func subscribeToBalance(cardId: String) async throws -> AsyncStream<Balance> {
        guard !cardId.isEmpty else {
            throw AppError.validationError(
                field: "cardId",
                reason: "Card id must not be empty.",
            )
        }
        let channel = EventChannels.cardEvents(cardId: cardId)
        let eventManager = eventSubscriptionManager
        // The session facade is `@MainActor` (its `events(for:)` is a sync
        // protocol requirement), so registration hops to the main actor
        // (architecture.md §12.3 #8).
        let source = await MainActor.run {
            eventManager.events(for: channel)
        }
        let cached = balancesByCardId[cardId]
        return AsyncStream { continuation in
            // Seed the stream synchronously so a resubscribe deterministically
            // yields the last known balance first.
            if let cached {
                continuation.yield(cached)
            }
            let task = Task { [weak self] in
                for await event in source {
                    if Task.isCancelled {
                        break
                    }
                    guard let self else {
                        break
                    }
                    await self.process(event, cardId: cardId, continuation: continuation)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    // MARK: - Parsing

    /// Normalizes one wire payload into a `Balance` (§6.1 `parseEvent`).
    ///
    /// Any payload that is not a balance frame (other entity kinds on the
    /// shared per-card channel, malformed JSON) is logged and skipped — a
    /// decode failure is never a stream error and never a crash.
    private func parseEvent(_ event: BankingEvent) -> Balance? {
        guard let data = event.payload.data(using: .utf8) else {
            logger.log(
                "Balance from \(event.channel): payload is not UTF-8.",
                level: .error,
            )
            return nil
        }
        return try? decoder.decode(
            Balance.self,
            from: data,
            logger: logger,
            context: "Balance from \(event.channel)",
        )
    }

    /// Actor-isolated event handling: update the per-id cache, then yield to
    /// the subscriber only when the frame concerns the subscribed card. A
    /// misrouted frame for another card warms that card's cache entry but is
    /// never delivered on this subscription.
    private func process(
        _ event: BankingEvent,
        cardId: String,
        continuation: AsyncStream<Balance>.Continuation,
    ) {
        guard let balance = parseEvent(event) else {
            return
        }
        cache(balance)
        guard balance.cardId == cardId else {
            return
        }
        continuation.yield(balance)
    }

    /// Writes or refreshes one card's balance, evicting an arbitrary entry
    /// when the cache is over its limit.
    private func cache(_ balance: Balance) {
        balancesByCardId[balance.cardId] = balance
        while balancesByCardId.count > cacheLimit, let evicted = balancesByCardId.first {
            balancesByCardId.removeValue(forKey: evicted.key)
        }
    }
}
