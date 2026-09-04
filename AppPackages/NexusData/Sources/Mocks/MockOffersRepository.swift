#if DEBUG
    import Entities
    import RepositoryProtocols

    /// In-memory `CardOffersRepositoryProtocol` double shared by previews,
    /// model tests, and demo mode.
    ///
    /// The mock stands in for the `card.offers` snapshot source: it holds
    /// the current offer list and fans full-list replacements out to every
    /// subscriber. `publish(_:)` models a backend snapshot push — the demo
    /// event generator and tests use it to drive live updates; the stream
    /// yield order mirrors the real repository (current list first, then
    /// every replacement).
    ///
    /// Failure knobs: `shouldThrowError` throws `thrownError` (default
    /// `.apiConnectionFailed`), `shouldNeverComplete` parks the call forever
    /// (loading state). `getAvailableOffers()` returning `[]` is the
    /// legitimate "no offers known" empty state, not an error.
    @MainActor
    public final class MockOffersRepository: CardOffersRepositoryProtocol {
        public private(set) var offers: [CardOffer]

        public var shouldThrowError = false
        public var shouldNeverComplete = false
        public var thrownError: AppError = .apiConnectionFailed()

        public private(set) var getAvailableOffersCallCount = 0
        public private(set) var subscribeToOffersCallCount = 0
        /// Snapshot lists pushed via `publish`, oldest first.
        public private(set) var publishedSnapshots: [[CardOffer]] = []

        private var nextSubscriberID = 0
        private var subscribers: [Int: AsyncStream<[CardOffer]>.Continuation] = [:]

        public init(seed: [CardOffer] = CardOffer.mockDefaults) {
            offers = seed
        }

        /// The current offer list. `[]` means no fresh offers are known.
        public func getAvailableOffers() async throws -> [CardOffer] {
            getAvailableOffersCallCount += 1
            try await checkFailureMode()
            return offers
        }

        /// Subscribes to the offer list; the stream yields the current list
        /// first, then every snapshot `publish` delivers.
        public func subscribeToOffers() async throws -> AsyncStream<[CardOffer]> {
            subscribeToOffersCallCount += 1
            try await checkFailureMode()
            let (stream, continuation) = AsyncStream<[CardOffer]>.makeStream()
            let id = register(continuation)
            continuation.onTermination = { [weak self] _ in
                // Termination can fire away from the main actor; hop back
                // before touching the registry (APISessionManager pattern).
                Task { @MainActor [weak self] in
                    self?.removeSubscriber(id)
                }
            }
            continuation.yield(offers)
            return stream
        }

        /// Replaces the current list and fans the snapshot out to every
        /// subscriber — the mock's "the backend published a new offer list".
        public func publish(_ snapshot: [CardOffer]) {
            publishedSnapshots.append(snapshot)
            offers = snapshot
            for continuation in subscribers.values {
                continuation.yield(snapshot)
            }
        }

        private func register(_ continuation: AsyncStream<[CardOffer]>.Continuation) -> Int {
            let id = nextSubscriberID
            nextSubscriberID += 1
            subscribers[id] = continuation
            return id
        }

        private func removeSubscriber(_ id: Int) {
            subscribers[id] = nil
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
