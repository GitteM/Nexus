#if DEBUG
    import Entities
    import RepositoryProtocols

    /// In-memory `TransactionRepositoryProtocol` double shared by previews,
    /// model tests, and demo mode (architecture.md §9.5, §11.2; tasks.md
    /// Day 13).
    ///
    /// Mirrors the live contract (architecture.md §4.2, §6.1):
    /// - `getTransactions` answers the current newest-first list for a
    ///   card.
    /// - `subscribeToTransactions` yields the current list first, then the
    ///   updated list after every `publish`. Subscribing with an empty card
    ///   id throws `AppError.validationError`.
    /// - `publish(_:)` models a backend transaction push (a
    ///   `card.events.{id}` frame): it folds the transaction into the
    ///   card's list — replacing any earlier frame with the same id, keeping
    ///   newest-first order — *before* yielding the updated list, so
    ///   delivery is the happens-before edge for reads.
    ///
    /// Failure knobs: `shouldThrowError` throws `thrownError` (default
    /// `.apiConnectionFailed`) from every method before any stream is
    /// handed out; `shouldNeverComplete` parks the call forever. `publish`
    /// is a server push and is never gated by the knobs.
    @MainActor
    public final class MockTransactionRepository: TransactionRepositoryProtocol {
        /// Current newest-first list per card id. `private(set)` so tests
        /// can read the store after pushes; mutate only through `publish`.
        public private(set) var transactionsByCardId: [String: [Transaction]]

        public var shouldThrowError = false
        public var shouldNeverComplete = false
        public var thrownError: AppError = .apiConnectionFailed()

        public private(set) var getTransactionsCallCount = 0
        public private(set) var subscribeToTransactionsCallCount = 0
        /// Transactions pushed via `publish`, oldest first.
        public private(set) var publishedTransactions: [Transaction] = []

        private var nextSubscriberID = 0
        private var subscribers: [String: [Int: AsyncStream<[Transaction]>.Continuation]] = [:]

        /// - Parameter seed: The lists known at start, keyed by `cardId`.
        ///   Seed lists are stored as-is (callers pass them newest first).
        public init(seed: [String: [Transaction]] = [:]) {
            transactionsByCardId = seed
        }

        /// The current transaction list for one card, newest first.
        public func getTransactions(cardId: String) async throws -> [Transaction] {
            getTransactionsCallCount += 1
            try await checkFailureMode()
            guard !cardId.isEmpty else {
                throw AppError.validationError(
                    field: "cardId",
                    reason: "Card id must not be empty.",
                )
            }
            return transactionsByCardId[cardId] ?? []
        }

        /// Subscribes to one card's transaction feed; the stream yields the
        /// current list first, then the updated list after every `publish`
        /// for that card.
        public func subscribeToTransactions(cardId: String) async throws -> AsyncStream<[Transaction]> {
            subscribeToTransactionsCallCount += 1
            try await checkFailureMode()
            guard !cardId.isEmpty else {
                throw AppError.validationError(
                    field: "cardId",
                    reason: "Card id must not be empty.",
                )
            }
            let (stream, continuation) = AsyncStream<[Transaction]>.makeStream()
            let id = register(cardId: cardId, continuation: continuation)
            continuation.onTermination = { [weak self] _ in
                // Termination can fire away from the main actor; hop back
                // before touching the registry (APISessionManager pattern).
                Task { @MainActor [weak self] in
                    self?.removeSubscriber(id: id, cardId: cardId)
                }
            }
            continuation.yield(transactionsByCardId[cardId] ?? [])
            return stream
        }

        /// Folds one transaction into its card's list and yields the
        /// updated list to that card's subscribers — the mock's "the
        /// backend pushed a new transaction".
        public func publish(_ transaction: Transaction) {
            publishedTransactions.append(transaction)
            var list = transactionsByCardId[transaction.cardId] ?? []
            list.removeAll { $0.id == transaction.id }
            list.append(transaction)
            list.sort { lhs, rhs in
                lhs.date == rhs.date ? lhs.id > rhs.id : lhs.date > rhs.date
            }
            transactionsByCardId[transaction.cardId] = list
            let listeners = subscribers[transaction.cardId].map { Array($0.values) } ?? []
            for continuation in listeners {
                continuation.yield(list)
            }
        }

        private func register(cardId: String, continuation: AsyncStream<[Transaction]>.Continuation) -> Int {
            let id = nextSubscriberID
            nextSubscriberID += 1
            subscribers[cardId, default: [:]][id] = continuation
            return id
        }

        private func removeSubscriber(id: Int, cardId: String) {
            subscribers[cardId]?[id] = nil
            if subscribers[cardId]?.isEmpty == true {
                subscribers[cardId] = nil
            }
        }

        private func checkFailureMode() async throws {
            if shouldNeverComplete {
                // Park the call like a request that never gets an answer.
                // Sleeping on a practically infinite interval (UInt64.max
                // nanoseconds ≈ 584 years) also mirrors a real transport:
                // cancelling the caller's task throws CancellationError and
                // the mock call ends instead of leaking.
                try await Task.sleep(nanoseconds: UInt64.max)
            }
            if shouldThrowError {
                throw thrownError
            }
        }
    }
#endif
