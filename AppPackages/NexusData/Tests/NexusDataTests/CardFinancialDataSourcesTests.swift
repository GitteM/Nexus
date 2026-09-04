@testable import DataSources
import Entities
import Foundation
import Testing

/// Day 13 tests for the balance and transaction-feed sources
/// (architecture.md §6.1): per-kind parse on the shared per-card channel,
/// cache/feed seed semantics, live delivery, and malformed-payload
/// skipping. Mirrors `CardStateDataSourceTests` conventions.
@Suite("Card balance + transaction sources")
@MainActor
struct CardFinancialDataSourcesTests {
    // MARK: - Helpers

    private func balanceEvent(cardId: String, current: Decimal = 100) throws -> BankingEvent {
        let payload = try String(decoding: JSONEncoder().encode(
            Balance(cardId: cardId, current: current, available: current, creditLimit: nil, currency: "EUR"),
        ), as: UTF8.self)
        return BankingEvent(channel: EventChannels.cardEvents(cardId: cardId), payload: payload)
    }

    private func transactionEvent(_ transaction: Transaction) throws -> BankingEvent {
        let payload = try String(decoding: JSONEncoder().encode(transaction), as: UTF8.self)
        return BankingEvent(
            channel: EventChannels.cardEvents(cardId: transaction.cardId),
            payload: payload,
        )
    }

    private func statusEvent(cardId: String) throws -> BankingEvent {
        let payload = try String(decoding: JSONEncoder().encode(
            CardState(cardId: cardId, status: .frozen),
        ), as: UTF8.self)
        return BankingEvent(channel: EventChannels.cardEvents(cardId: cardId), payload: payload)
    }

    private func nextBalance(_ stream: AsyncStream<Balance>) async -> Balance? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    private func nextList(_ stream: AsyncStream<[Transaction]>) async -> [Transaction]? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    // MARK: - Balance source

    @Test func `balance subscription delivers live updates and warms the cache`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardBalanceDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = try await source.subscribeToBalance(cardId: "card-credit-001")
        #expect(await source.getBalance(cardId: "card-credit-001") == nil)

        try session.inject(balanceEvent(cardId: "card-credit-001", current: 500))
        #expect(await nextBalance(stream)?.current == 500)
        #expect(await source.getBalance(cardId: "card-credit-001")?.current == 500)
    }

    @Test func `balance resubscribe seeds the cached value first`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardBalanceDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let first = try await source.subscribeToBalance(cardId: "card-credit-001")
        try session.inject(balanceEvent(cardId: "card-credit-001", current: 250))
        #expect(await nextBalance(first)?.current == 250)

        let stream = try await source.subscribeToBalance(cardId: "card-credit-001")
        #expect(await nextBalance(stream)?.current == 250)
    }

    @Test func `balance source skips non-balance frames`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardBalanceDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = try await source.subscribeToBalance(cardId: "card-credit-001")
        try session.inject(statusEvent(cardId: "card-credit-001"))
        session.inject(BankingEvent(
            channel: EventChannels.cardEvents(cardId: "card-credit-001"),
            payload: "not json at all",
        ))
        // Neither a status frame nor garbage is a balance — the cache stays
        // cold until a real frame arrives, proving the skip never killed
        // the stream.
        try session.inject(balanceEvent(cardId: "card-credit-001", current: 300))
        #expect(await nextBalance(stream)?.current == 300)
        #expect(await source.getBalance(cardId: "card-credit-001")?.current == 300)
    }

    @Test func `balance source rejects an empty card id`() async {
        let source = CardBalanceDataSource(
            eventSubscriptionManager: FakeEventSubscriptionManager(),
            logger: RecordingLogger(),
        )

        await #expect(throws: AppError.validationError(field: "cardId", reason: "Card id must not be empty.")) {
            try await source.subscribeToBalance(cardId: "")
        }
    }

    // MARK: - Transaction feed source

    @Test func `transaction feed delivers newest-first list snapshots`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardTransactionsDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = try await source.subscribeToTransactions(cardId: Card.mockCreditCard.id)
        // The stream seeds the current (empty) list first.
        #expect(await nextList(stream) == [])

        try session.inject(transactionEvent(Transaction.mockCoffeePurchase))
        #expect(await nextList(stream) == [Transaction.mockCoffeePurchase])

        // A later frame with an older date sorts after the newer purchase:
        // the feed stays newest-first by date, not arrival order.
        try session.inject(transactionEvent(Transaction.mockOnlineShoppingPurchase))
        #expect(await nextList(stream) == [Transaction.mockCoffeePurchase, Transaction.mockOnlineShoppingPurchase])
    }

    @Test func `transaction feed replaces a same-id frame in place`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardTransactionsDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = try await source.subscribeToTransactions(cardId: Card.mockCreditCard.id)
        #expect(await nextList(stream) == [])
        try session.inject(transactionEvent(Transaction.mockCoffeePurchase))
        #expect(await nextList(stream)?.count == 1)

        // The pending purchase clears: same id, updated status → one row.
        let cleared = Transaction(
            id: Transaction.mockCoffeePurchase.id,
            cardId: Transaction.mockCoffeePurchase.cardId,
            date: Transaction.mockCoffeePurchase.date,
            merchant: Transaction.mockCoffeePurchase.merchant,
            amount: Transaction.mockCoffeePurchase.amount,
            currency: Transaction.mockCoffeePurchase.currency,
            category: Transaction.mockCoffeePurchase.category,
            status: .cleared,
            location: Transaction.mockCoffeePurchase.location,
        )
        try session.inject(transactionEvent(cleared))
        let list = await nextList(stream)
        #expect(list == [cleared])
    }

    @Test func `transaction feed getTransactions mirrors delivered state`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardTransactionsDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = try await source.subscribeToTransactions(cardId: Card.mockCreditCard.id)
        #expect(await nextList(stream) == [])
        try session.inject(transactionEvent(Transaction.mockCoffeePurchase))
        #expect(await nextList(stream)?.count == 1)
        #expect(await source.getTransactions(cardId: Card.mockCreditCard.id) == [Transaction.mockCoffeePurchase])
    }

    @Test func `transaction feed bounds its per-card list`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardTransactionsDataSource(
            eventSubscriptionManager: session,
            logger: RecordingLogger(),
            feedLimit: 2,
        )
        let stream = try await source.subscribeToTransactions(cardId: Card.mockCreditCard.id)
        #expect(await nextList(stream) == [])

        try session.inject(transactionEvent(Transaction.mockParkingCharge))
        #expect(await nextList(stream)?.count == 1)
        try session.inject(transactionEvent(Transaction.mockCoffeePurchase))
        #expect(await nextList(stream)?.count == 2)
        try session.inject(transactionEvent(Transaction.mockRefund))
        let list = await nextList(stream)
        #expect(list?.count == 2)
        // The newest two survive (Parking is the oldest of the three).
        #expect(list?.contains { $0.id == Transaction.mockParkingCharge.id } == false)
    }

    @Test func `transaction feed skips non-transaction frames`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardTransactionsDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = try await source.subscribeToTransactions(cardId: Card.mockCreditCard.id)
        #expect(await nextList(stream) == [])
        // A balance frame is not a transaction: the feed stays quiet, then a
        // real frame still arrives — proving the skip never killed the stream.
        try session.inject(balanceEvent(cardId: Card.mockCreditCard.id))
        try session.inject(transactionEvent(Transaction.mockCoffeePurchase))
        #expect(await nextList(stream) == [Transaction.mockCoffeePurchase])
    }
}
