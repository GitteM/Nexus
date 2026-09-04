#if DEBUG
    import Entities
    import RepositoryProtocols

    /// In-memory `CardStatusRepositoryProtocol` double shared by previews,
    /// model tests, and demo mode.
    ///
    /// The mock stands in for the live per-card status source: it holds the
    /// known `CardState` per card id and fans status updates out to the
    /// subscribers of that card's channel. Contract mirrors the live
    /// repository:
    /// - `getCardStatus` answers the latest known state, or `nil` when none
    ///   is known for the card.
    /// - `subscribeToCardStatus` yields the current state first, then every
    ///   state `publish` delivers for that card. Subscribing with an empty
    ///   card id throws `AppError.validationError` — a returned stream means
    ///   "subscribed".
    /// - `publish(_:)` models a backend status push (a `card.events.{id}`
    ///   frame): it stores the state *before* yielding, so once a state has
    ///   been observed on a subscription, `getCardStatus` answers it — the
    ///   same delivery-is-the-happens-before-edge rule the data source uses.
    ///
    /// Failure knobs: `shouldThrowError` throws `thrownError` (default
    /// `.apiConnectionFailed`) from every method before any stream is
    /// handed out; `shouldNeverComplete` parks the call forever (loading
    /// state). `publish` is a server push and is never gated by the knobs.
    @MainActor
    public final class MockStatusRepository: CardStatusRepositoryProtocol {
        /// Latest known state per card id. `private(set)` so tests can read
        /// the store after pushes; mutate only through `publish`.
        public private(set) var statesByCardId: [String: CardState]

        public var shouldThrowError = false
        public var shouldNeverComplete = false
        public var thrownError: AppError = .apiConnectionFailed()

        public private(set) var getCardStatusCallCount = 0
        public private(set) var subscribeToCardStatusCallCount = 0
        /// States pushed via `publish`, oldest first.
        public private(set) var publishedStates: [CardState] = []

        private var nextSubscriberID = 0
        private var subscribers: [String: [Int: AsyncStream<CardState>.Continuation]] = [:]

        /// - Parameter seed: The states known at start, keyed by `cardId`;
        ///   duplicates collapse to the last entry.
        public init(seed: [CardState] = CardState.mockDefaults) {
            statesByCardId = Dictionary(seed.map { ($0.cardId, $0) }, uniquingKeysWith: { _, last in last })
        }

        /// The latest known state for one card, or `nil` when none is known.
        public func getCardStatus(cardId: String) async throws -> CardState? {
            getCardStatusCallCount += 1
            try await checkFailureMode()
            return statesByCardId[cardId]
        }

        /// Subscribes to one card's status; the stream yields the current
        /// state first, then every state `publish` delivers for that card.
        public func subscribeToCardStatus(cardId: String) async throws -> AsyncStream<CardState> {
            subscribeToCardStatusCallCount += 1
            try await checkFailureMode()
            guard !cardId.isEmpty else {
                throw AppError.validationError(
                    field: "cardId",
                    reason: "Card id must not be empty.",
                )
            }
            let (stream, continuation) = AsyncStream<CardState>.makeStream()
            let id = register(cardId: cardId, continuation: continuation)
            continuation.onTermination = { [weak self] _ in
                // Termination can fire away from the main actor; hop back
                // before touching the registry (APISessionManager pattern).
                Task { @MainActor [weak self] in
                    self?.removeSubscriber(id: id, cardId: cardId)
                }
            }
            if let current = statesByCardId[cardId] {
                continuation.yield(current)
            }
            return stream
        }

        /// Stores a new state for its card and yields it to that card's
        /// subscribers — the mock's "the backend pushed a new state".
        public func publish(_ state: CardState) {
            publishedStates.append(state)
            statesByCardId[state.cardId] = state
            let listeners = subscribers[state.cardId].map { Array($0.values) } ?? []
            for continuation in listeners {
                continuation.yield(state)
            }
        }

        private func register(cardId: String, continuation: AsyncStream<CardState>.Continuation) -> Int {
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
