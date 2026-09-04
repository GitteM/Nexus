import Entities
import Foundation
import Observation
import RepositoryProtocols

/// Owns one card's account-activity screen: the live balance header and the
/// searchable/filterable transaction history (architecture.md §9.1,
/// tasks.md Day 13).
///
/// The "M" of MV for a card's financial activity: it loads the balance and
/// the transaction feed through their repositories, subscribes to both live
/// streams (balance is a per-card latest value; the transaction feed is a
/// newest-first list snapshot), and owns the search/filter `query` whose
/// results are derived through the pure `TransactionQuery.filter` rule.
///
/// Live semantics: status is `.loaded` once the first fetch lands; every
/// later frame from either subscription updates state in place (no polling)
/// and never blanks the screen. A failed fetch lands `.error` with the
/// standard retry path; a failed *subscription* is dropped silently so one
/// dead channel never takes the screen down (§9.1).
@MainActor
@Observable
public final class TransactionHistoryModel {
    public private(set) var viewState: TransactionHistoryViewState = .loading

    /// The card's latest balance, or `nil` until a frame arrives (a card
    /// with no balance known yet shows the header in its neutral state).
    public private(set) var balance: Balance?

    /// The card's newest-first transaction list, as published by the feed
    /// subscription (filtering is derived, never mutating).
    public private(set) var transactions: [Transaction] = []

    /// The active search/filter state. Views mutate it through the helper
    /// methods below so every change is an explicit, observable replace.
    public private(set) var query = TransactionQuery()

    private let cardID: String
    private let balanceRepository: BalanceRepositoryProtocol
    private let transactionRepository: TransactionRepositoryProtocol
    private let subscriptionBox = ActivitySubscriptionBox()

    public init(
        cardID: String,
        balanceRepository: BalanceRepositoryProtocol,
        transactionRepository: TransactionRepositoryProtocol,
    ) {
        self.cardID = cardID
        self.balanceRepository = balanceRepository
        self.transactionRepository = transactionRepository
    }

    /// The transactions matching the current query, newest first. Derived
    /// on every read so the list always reflects `query` (no staleness).
    public var filteredTransactions: [Transaction] {
        TransactionQuery.filter(transactions, by: query)
    }

    // MARK: - Query mutations

    public func setSearchText(_ text: String) {
        query.searchText = text
    }

    public func setCategoryFilter(_ category: TransactionCategory?) {
        query.category = category
    }

    public func setStatusFilter(_ status: TransactionStatus?) {
        query.status = status
    }

    public func setDateRange(_ dateRange: TransactionDateRange) {
        query.dateRange = dateRange
    }

    public func setAmountRange(minimum: Decimal?, maximum: Decimal?) {
        query.minimumAmount = minimum
        query.maximumAmount = maximum
    }

    public func clearFilters() {
        query = TransactionQuery()
    }

    // MARK: - Load

    /// Idempotent initial load — safe to refire on every appear; once the
    /// screen is loaded it is a no-op, and from `.error` it retries. The
    /// balance and the transaction feed fetch in parallel (`async let`),
    /// then both live subscriptions start.
    public func load() async {
        // Deliberately no in-flight guard: a `.task` retry that lands while
        // an earlier attempt is cancelled-but-unwinding (push identity
        // changes) would otherwise return early forever, leaving the screen
        // stuck in `.loading` (CardDetailModel.load notes the same race).
        // The fetches are idempotent, so an overlapping retry just refetches.
        guard viewState != .loaded else { return }
        viewState = .loading
        do {
            async let fetchedBalance = balanceRepository.getBalance(cardId: cardID)
            async let fetchedTransactions = transactionRepository.getTransactions(cardId: cardID)
            let (balance, transactions) = try await (fetchedBalance, fetchedTransactions)
            self.balance = balance
            self.transactions = transactions
            startSubscriptions()
            viewState = .loaded
        } catch is CancellationError {
            // The triggering view task was cancelled (screen disappeared
            // mid-load); the next appear refires load().
        } catch let error as AppError {
            viewState = .error(error)
        } catch {
            viewState = .error(.unknown(underlying: error))
        }
    }

    // MARK: - Live subscriptions

    /// Starts the balance and transaction-feed subscriptions. Each task is
    /// held weakly against the model (via the box) and ends when the model
    /// or the task is cancelled — a subscription that cannot be set up is
    /// dropped silently (§9.1).
    private func startSubscriptions() {
        subscriptionBox.tasks.forEach { $0.cancel() }
        subscriptionBox.tasks.removeAll()

        let cardID = cardID
        let balanceRepository = balanceRepository
        subscriptionBox.tasks.append(
            Task { @MainActor [weak self] in
                guard let stream = try? await balanceRepository
                    .subscribeToBalance(cardId: cardID)
                else { return }
                for await value in stream {
                    guard !Task.isCancelled else { break }
                    self?.balance = value
                }
            },
        )

        let transactionRepository = transactionRepository
        subscriptionBox.tasks.append(
            Task { @MainActor [weak self] in
                guard let stream = try? await transactionRepository
                    .subscribeToTransactions(cardId: cardID)
                else { return }
                for await list in stream {
                    guard !Task.isCancelled else { break }
                    self?.transactions = list
                }
            },
        )
    }
}

/// Owns the screen's subscription tasks so they can be cancelled when the
/// model goes away (§9.1). Nonisolated so its `deinit` can cancel without
/// touching main-actor state.
private final class ActivitySubscriptionBox {
    var tasks: [Task<Void, Never>] = []

    deinit {
        for task in tasks {
            task.cancel()
        }
    }
}
