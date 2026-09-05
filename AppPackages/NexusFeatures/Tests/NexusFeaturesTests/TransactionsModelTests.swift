import Entities
import Foundation
import Mocks
import Testing
import Transactions

/// Pure filtering rule tests: search/filter across merchant text, category,
/// status, date window, and amount magnitude. Deterministic `now` keeps the
/// date-window cases stable.
@Suite("Transaction query filtering")
struct TransactionFilterTests {
    private let transactions = Transaction.mockDefaults

    /// A fixed "now" shortly after the mock feed's newest purchase: the
    /// date-window expectations below are computed against it.
    private let now = Date(timeIntervalSinceReferenceDate: 799_459_200)

    @Test func `empty query keeps the whole list`() {
        #expect(TransactionQuery.filter(transactions, by: TransactionQuery(), now: now) == transactions)
        #expect(TransactionQuery().isDefault)
    }

    @Test func `search matches merchant names case-insensitively`() {
        let query = TransactionQuery(searchText: "cafe")

        let result = TransactionQuery.filter(transactions, by: query, now: now)

        #expect(result == [Transaction.mockCoffeePurchase])
        #expect(TransactionQuery.filter(transactions, by: TransactionQuery(searchText: "FRESH"), now: now).count == 2)
        #expect(TransactionQuery.filter(transactions, by: TransactionQuery(searchText: "no such shop"), now: now).isEmpty)
    }

    @Test func `category filter narrows to one category`() {
        let dining = TransactionQuery(category: .dining)
        #expect(TransactionQuery.filter(transactions, by: dining, now: now) == [Transaction.mockCoffeePurchase])

        let groceries = TransactionQuery(category: .groceries)
        #expect(TransactionQuery.filter(transactions, by: groceries, now: now) == [
            Transaction.mockGroceriesPurchase,
            Transaction.mockRefund,
        ])
    }

    @Test func `status filter separates pending from cleared`() {
        let pending = TransactionQuery(status: .pending)
        #expect(TransactionQuery.filter(transactions, by: pending, now: now) == [
            Transaction.mockCoffeePurchase,
            Transaction.mockStreamingSubscription,
        ])

        let cleared = TransactionQuery(status: .cleared)
        #expect(TransactionQuery.filter(transactions, by: cleared, now: now).count == 7)
    }

    @Test func `date range filters by window relative to now`() {
        // `now` is ≈ 3 days after the newest purchase (Coffee). The groceries
        // purchase is ≈ 3.5 days older, so both fall inside 7 days…
        let last7 = TransactionQuery(dateRange: .last7Days)
        #expect(TransactionQuery.filter(transactions, by: last7, now: now) == [
            Transaction.mockCoffeePurchase,
            Transaction.mockGroceriesPurchase,
        ])

        // …while the streaming subscription (≈ 24 days older) needs the
        // 30-day window, and the utility bill (≈ 35 days older) is out.
        let last30 = TransactionQuery(dateRange: .last30Days)
        let in30 = TransactionQuery.filter(transactions, by: last30, now: now)
        #expect(in30.contains { $0.id == Transaction.mockStreamingSubscription.id })
        #expect(in30.contains { $0.id == Transaction.mockUtilityBill.id } == false)
    }

    @Test func `amount filters apply to the magnitude`() {
        // Between €100 and €300 of spending: Shoply (129.99) and the peer
        // transfer (200) qualify; the flight (342) and small items do not.
        let range = TransactionQuery(minimumAmount: 100, maximumAmount: 300)
        let result = TransactionQuery.filter(transactions, by: range, now: now)
        #expect(Set(result.map(\.id)) == Set([
            Transaction.mockOnlineShoppingPurchase.id,
            Transaction.mockPeerTransfer.id,
        ]))
    }

    @Test func `combined filters intersect`() {
        let query = TransactionQuery(
            searchText: "fresh",
            category: .groceries,
            status: .cleared,
        )
        #expect(TransactionQuery.filter(transactions, by: query, now: now).count == 2)

        let noMatch = TransactionQuery(searchText: "fresh", status: .pending)
        #expect(TransactionQuery.filter(transactions, by: noMatch, now: now).isEmpty)
    }
}

/// `TransactionHistoryModel` orchestration: load transitions, the live
/// balance/feed subscriptions, and the query mutations whose results the
/// views render.
@Suite("Transaction history model")
@MainActor
struct TransactionHistoryModelTests {
    private func makeModel(
        cardID: String = Card.mockCreditCard.id,
        balances: [Balance] = Balance.mockDefaults,
        transactions: [Transaction] = Transaction.mockDefaults,
    ) -> (
        model: TransactionHistoryModel,
        balanceRepository: MockBalanceRepository,
        transactionRepository: MockTransactionRepository,
    ) {
        let balanceRepository = MockBalanceRepository(seed: balances)
        let transactionRepository = MockTransactionRepository(
            seed: cardID == Card.mockCreditCard.id ? [cardID: transactions] : [:],
        )
        let model = TransactionHistoryModel(
            cardID: cardID,
            balanceRepository: balanceRepository,
            transactionRepository: transactionRepository,
        )
        return (model, balanceRepository, transactionRepository)
    }

    @Test func `starts in the loading state with no data`() {
        let (model, _, _) = makeModel()

        #expect(model.viewState == .loading)
        #expect(model.balance == nil)
        #expect(model.transactions.isEmpty)
        #expect(model.query.isDefault)
    }

    @Test func `load fetches balance and transactions then subscribes live`() async {
        let (model, balanceRepository, transactionRepository) = makeModel()

        await model.load()

        #expect(model.viewState == .loaded)
        #expect(model.balance == .mockCreditBalance)
        #expect(model.transactions == Transaction.mockDefaults)
        #expect(balanceRepository.getBalanceCallCount == 1)
        #expect(transactionRepository.getTransactionsCallCount == 1)
        await waitUntil { balanceRepository.subscribeToBalanceCallCount == 1 }
        await waitUntil { transactionRepository.subscribeToTransactionsCallCount == 1 }
    }

    @Test func `a card with no activity loads an empty feed`() async {
        // The debit card carries no seeded transactions: the feed fetch
        // resolves empty, the screen still lands `.loaded` (the view shows
        // its empty state rather than an error).
        let (model, _, _) = makeModel(cardID: Card.mockDebitCard.id, transactions: [])

        await model.load()

        #expect(model.viewState == .loaded)
        #expect(model.transactions.isEmpty)
        #expect(model.filteredTransactions.isEmpty)
    }

    @Test func `load is idempotent once the screen is loaded`() async {
        let (model, balanceRepository, transactionRepository) = makeModel()

        await model.load()
        await model.load()

        #expect(model.viewState == .loaded)
        #expect(balanceRepository.getBalanceCallCount == 1)
        #expect(transactionRepository.getTransactionsCallCount == 1)
    }

    @Test func `load lands in the error state when a repository fails`() async {
        let (model, balanceRepository, _) = makeModel()
        balanceRepository.shouldThrowError = true
        balanceRepository.thrownError = .apiConnectionFailed()

        await model.load()

        #expect(model.viewState == .error(.apiConnectionFailed()))
    }

    @Test func `live balance frames update the header without a reload`() async {
        let (model, balanceRepository, _) = makeModel()
        await model.load()

        let updated = Balance(
            cardId: Card.mockCreditCard.id,
            current: 1000,
            available: 1000,
            creditLimit: 2500,
            currency: "EUR",
        )
        balanceRepository.publish(updated)

        await waitUntil { model.balance == updated }
        #expect(model.viewState == .loaded) // never blanked by an update
    }

    @Test func `live transaction frames update the feed in place`() async {
        let (model, _, transactionRepository) = makeModel()
        await model.load()

        let newer = Transaction(
            id: "txn-live-1",
            cardId: Card.mockCreditCard.id,
            date: .now,
            merchant: "Live Shop",
            amount: -33,
            currency: "EUR",
            category: .shopping,
            status: .pending,
            location: nil,
        )
        transactionRepository.publish(newer)

        await waitUntil { model.transactions.first?.id == "txn-live-1" }
        #expect(model.transactions.count == Transaction.mockDefaults.count + 1)
    }

    // MARK: - Query

    @Test func `search text narrows the filtered list`() async {
        let (model, _, _) = makeModel()
        await model.load()

        model.setSearchText("cafe")

        #expect(model.filteredTransactions == [Transaction.mockCoffeePurchase])
        #expect(model.transactions.count == Transaction.mockDefaults.count) // source untouched
    }

    @Test func `category and status filters narrow the list`() async {
        let (model, _, _) = makeModel()
        await model.load()

        model.setCategoryFilter(.groceries)
        #expect(model.filteredTransactions.count == 2)

        model.setStatusFilter(.cleared)
        #expect(model.filteredTransactions.count == 2) // both groceries rows are cleared

        model.setStatusFilter(.pending)
        #expect(model.filteredTransactions.isEmpty)
    }

    @Test func `amount filters narrow the list`() async {
        let (model, _, _) = makeModel()
        await model.load()

        model.setAmountRange(minimum: 100, maximum: 300)
        #expect(model.filteredTransactions.count == 2)

        // Date-window behavior is covered deterministically in
        // TransactionFilterTests (the model filters against the real clock;
        // the fixed mock dates make wall-clock assertions brittle here).
        model.clearFilters()
        #expect(model.filteredTransactions == Transaction.mockDefaults)
    }

    @Test func `clear filters restores the whole list`() async {
        let (model, _, _) = makeModel()
        await model.load()

        model.setSearchText("cafe")
        model.setCategoryFilter(.dining)
        #expect(model.filteredTransactions == [Transaction.mockCoffeePurchase])

        model.clearFilters()
        #expect(model.query.isDefault)
        #expect(model.filteredTransactions == Transaction.mockDefaults)
    }
}

/// `TransactionDetailModel` behavior: snapshot fetch by id, stale-link
/// handling, and failure mapping.
@Suite("Transaction detail model")
@MainActor
struct TransactionDetailModelTests {
    @Test func `load finds the transaction in the feed`() async {
        let repository = MockTransactionRepository(
            seed: [Card.mockCreditCard.id: Transaction.mockDefaults],
        )
        let model = TransactionDetailModel(
            cardID: Card.mockCreditCard.id,
            transactionID: Transaction.mockFlightPurchase.id,
            transactionRepository: repository,
        )

        #expect(model.viewState == .loading)
        await model.load()

        #expect(model.viewState == .loaded(Transaction.mockFlightPurchase))
        #expect(repository.getTransactionsCallCount == 1)
    }

    @Test func `load is idempotent once a transaction is shown`() async {
        let repository = MockTransactionRepository(
            seed: [Card.mockCreditCard.id: Transaction.mockDefaults],
        )
        let model = TransactionDetailModel(
            cardID: Card.mockCreditCard.id,
            transactionID: Transaction.mockFlightPurchase.id,
            transactionRepository: repository,
        )

        await model.load()
        await model.load()

        #expect(model.viewState == .loaded(Transaction.mockFlightPurchase))
        #expect(repository.getTransactionsCallCount == 1)
    }

    @Test func `a stale transaction id lands in the missing state`() async {
        let repository = MockTransactionRepository(
            seed: [Card.mockCreditCard.id: Transaction.mockDefaults],
        )
        let model = TransactionDetailModel(
            cardID: Card.mockCreditCard.id,
            transactionID: "txn-gone",
            transactionRepository: repository,
        )

        await model.load()

        #expect(model.viewState == .missing)
    }

    @Test func `a failed fetch lands in the error state and can retry`() async {
        let repository = MockTransactionRepository(
            seed: [Card.mockCreditCard.id: Transaction.mockDefaults],
        )
        repository.shouldThrowError = true
        let model = TransactionDetailModel(
            cardID: Card.mockCreditCard.id,
            transactionID: Transaction.mockFlightPurchase.id,
            transactionRepository: repository,
        )

        await model.load()
        #expect(model.viewState == .error(.apiConnectionFailed()))

        repository.shouldThrowError = false
        await model.load()
        #expect(model.viewState == .loaded(Transaction.mockFlightPurchase))
    }
}

@MainActor
private func waitUntil(_ condition: @MainActor () -> Bool) async {
    for _ in 0 ..< 200 {
        if condition() {
            return
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
}
