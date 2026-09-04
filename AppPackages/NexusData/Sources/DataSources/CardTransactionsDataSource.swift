import Entities
import Foundation
import ServiceProtocols
import Session

/// Live transaction-feed source: the actor that owns each card's
/// transaction event stream and its per-card, newest-first list
/// (architecture.md §6.1, tasks.md Day 13).
///
/// `TransactionRepositoryProtocol` (thin validation/error wrapper) exposes
/// this actor. It subscribes on `card.events.{cardId}` and parses only the
/// transaction-shaped payloads on that channel — status/balance/limit
/// frames decode as `Transaction` failures and are skipped (the
/// `CardStateDataSource` contract, §6.1).
///
/// Contract notes (mirror `CardStateDataSource` / `CardOffersDataSource`):
/// - A returned stream means "subscribed": setup failure throws before any
///   stream is handed out.
/// - The stream yields the current list first, then the *updated list*
///   after every frame that lands for the subscribed card (snapshot
///   semantics — models republish a flat list).
/// - Delivery is the happens-before edge for the store: a frame is written
///   to the per-card list *before* it is yielded, so `getTransactions`
///   answers the same state a subscriber just observed.
/// - A frame replaces any earlier frame with the same transaction id (a
///   status transition pending → cleared updates in place) and the list
///   stays newest-first by date.
/// - The per-card list is bounded (`feedLimit`, default 100 entries, oldest
///   dropped) so a long-lived feed never grows without bound.
public actor CardTransactionsDataSource {
    private let eventSubscriptionManager: any EventSubscriptionManagerProtocol
    private let logger: any LoggerProtocol
    private let decoder = JSONDecoder()

    /// Default cap for one card's in-memory feed.
    public static let defaultFeedLimit = 100

    private let feedLimit: Int
    /// Newest-first transaction list per card id.
    private var transactionsByCardId: [String: [Transaction]] = [:]

    /// - Parameters:
    ///   - eventSubscriptionManager: The session facade data sources receive.
    ///   - logger: Receives `.error` messages for skipped malformed payloads.
    ///   - feedLimit: Maximum transactions kept per card; inject a small
    ///     value in tests.
    public init(
        eventSubscriptionManager: any EventSubscriptionManagerProtocol,
        logger: any LoggerProtocol,
        feedLimit: Int = CardTransactionsDataSource.defaultFeedLimit,
    ) {
        self.eventSubscriptionManager = eventSubscriptionManager
        self.logger = logger
        self.feedLimit = feedLimit
    }

    // MARK: - One-shot

    /// The current transaction list for one card, newest first.
    public func getTransactions(cardId: String) async -> [Transaction] {
        transactionsByCardId[cardId] ?? []
    }

    // MARK: - Subscription

    /// Subscribes to one card's transaction feed on `card.events.{cardId}`.
    ///
    /// Throws `AppError.validationError` when `cardId` is empty — a returned
    /// stream means the subscription is live.
    public func subscribeToTransactions(cardId: String) async throws -> AsyncStream<[Transaction]> {
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
        let cached = transactionsByCardId[cardId] ?? []
        return AsyncStream { continuation in
            // Seed the stream synchronously so a resubscribe deterministically
            // yields the current list first.
            continuation.yield(cached)
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

    /// Normalizes one wire payload into a `Transaction` (§6.1 `parseEvent`).
    ///
    /// Any payload that is not a transaction frame (other entity kinds on
    /// the shared per-card channel, malformed JSON) is logged and skipped —
    /// a decode failure is never a stream error and never a crash.
    private func parseEvent(_ event: BankingEvent) -> Transaction? {
        guard let data = event.payload.data(using: .utf8) else {
            logger.log(
                "Transaction from \(event.channel): payload is not UTF-8.",
                level: .error,
            )
            return nil
        }
        return try? decoder.decode(
            Transaction.self,
            from: data,
            logger: logger,
            context: "Transaction from \(event.channel)",
        )
    }

    /// Actor-isolated event handling: fold the frame into the per-card
    /// list, then yield the updated list only to the subscribed card's
    /// stream. A misrouted frame for another card warms that card's list
    /// but is never delivered on this subscription.
    private func process(
        _ event: BankingEvent,
        cardId: String,
        continuation: AsyncStream<[Transaction]>.Continuation,
    ) {
        guard let transaction = parseEvent(event) else {
            return
        }
        let list = folding(transaction)
        guard transaction.cardId == cardId else {
            return
        }
        continuation.yield(list)
    }

    /// Inserts or replaces one transaction in its card's list and returns
    /// the updated, newest-first, bounded list.
    private func folding(_ transaction: Transaction) -> [Transaction] {
        var list = transactionsByCardId[transaction.cardId] ?? []
        list.removeAll { $0.id == transaction.id }
        list.append(transaction)
        list.sort { lhs, rhs in
            lhs.date == rhs.date ? lhs.id > rhs.id : lhs.date > rhs.date
        }
        if list.count > feedLimit {
            list.removeLast(list.count - feedLimit)
        }
        transactionsByCardId[transaction.cardId] = list
        return list
    }
}
