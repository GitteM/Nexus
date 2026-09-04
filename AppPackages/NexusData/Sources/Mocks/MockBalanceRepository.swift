#if DEBUG
    import Entities
    import RepositoryProtocols

    /// In-memory `BalanceRepositoryProtocol` double shared by previews,
    /// model tests, and demo mode (architecture.md §9.5, §11.2; tasks.md
    /// Day 13).
    ///
    /// Mirrors the live contract (architecture.md §4.2, §6.1):
    /// - `getBalance` answers the latest known balance, or `nil` when none
    ///   is known for the card.
    /// - `subscribeToBalance` yields the current balance first, then every
    ///   balance `publish` delivers for that card. Subscribing with an
    ///   empty card id throws `AppError.validationError`.
    /// - `publish(_:)` models a backend balance push (a `card.events.{id}`
    ///   frame): it stores the value *before* yielding — delivery is the
    ///   happens-before edge for reads.
    ///
    /// Failure knobs: `shouldThrowError` throws `thrownError` (default
    /// `.apiConnectionFailed`) from every method before any stream is
    /// handed out; `shouldNeverComplete` parks the call forever. `publish`
    /// is a server push and is never gated by the knobs.
    @MainActor
    public final class MockBalanceRepository: BalanceRepositoryProtocol {
        /// Latest known balance per card id. `private(set)` so tests can
        /// read the store after pushes; mutate only through `publish`.
        public private(set) var balancesByCardId: [String: Balance]

        public var shouldThrowError = false
        public var shouldNeverComplete = false
        public var thrownError: AppError = .apiConnectionFailed()

        public private(set) var getBalanceCallCount = 0
        public private(set) var subscribeToBalanceCallCount = 0
        /// Balances pushed via `publish`, oldest first.
        public private(set) var publishedBalances: [Balance] = []

        private var nextSubscriberID = 0
        private var subscribers: [String: [Int: AsyncStream<Balance>.Continuation]] = [:]

        /// - Parameter seed: The balances known at start, keyed by
        ///   `cardId`; duplicates collapse to the last entry.
        public init(seed: [Balance] = Balance.mockDefaults) {
            balancesByCardId = Dictionary(seed.map { ($0.cardId, $0) }, uniquingKeysWith: { _, last in last })
        }

        /// The latest known balance for one card, or `nil` when none is
        /// known.
        public func getBalance(cardId: String) async throws -> Balance? {
            getBalanceCallCount += 1
            try await checkFailureMode()
            return balancesByCardId[cardId]
        }

        /// Subscribes to one card's balance; the stream yields the current
        /// value first, then every balance `publish` delivers for that
        /// card.
        public func subscribeToBalance(cardId: String) async throws -> AsyncStream<Balance> {
            subscribeToBalanceCallCount += 1
            try await checkFailureMode()
            guard !cardId.isEmpty else {
                throw AppError.validationError(
                    field: "cardId",
                    reason: "Card id must not be empty.",
                )
            }
            let (stream, continuation) = AsyncStream<Balance>.makeStream()
            let id = register(cardId: cardId, continuation: continuation)
            continuation.onTermination = { [weak self] _ in
                // Termination can fire away from the main actor; hop back
                // before touching the registry (APISessionManager pattern).
                Task { @MainActor [weak self] in
                    self?.removeSubscriber(id: id, cardId: cardId)
                }
            }
            if let current = balancesByCardId[cardId] {
                continuation.yield(current)
            }
            return stream
        }

        /// Stores a new balance for its card and yields it to that card's
        /// subscribers — the mock's "the backend pushed a new balance".
        public func publish(_ balance: Balance) {
            publishedBalances.append(balance)
            balancesByCardId[balance.cardId] = balance
            let listeners = subscribers[balance.cardId].map { Array($0.values) } ?? []
            for continuation in listeners {
                continuation.yield(balance)
            }
        }

        private func register(cardId: String, continuation: AsyncStream<Balance>.Continuation) -> Int {
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
