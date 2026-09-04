#if DEBUG
    import Entities
    import RepositoryProtocols

    /// In-memory `CardRepositoryProtocol` double shared by previews, model
    /// tests, and demo mode (architecture.md §9.5, §11.2; tasks.md Day 8).
    ///
    /// Mocks exist once, in `NexusData/Mocks`, behind `#if DEBUG`: SwiftUI
    /// previews, unit tests, UI tests, and demo mode all exercise the real
    /// orchestration code over these doubles, and a release build compiles
    /// the module to empty.
    ///
    /// Success-path contract mirrors the live repository (architecture.md
    /// §4.2, §6.3):
    /// - `getCards()` returns the seeded list in seed order.
    /// - `addCard(_:)` records the offer and returns a provisional `Card`
    ///   exactly like `CardRepository` does — the offer's id, `.active`,
    ///   empty holder/last-four digits (no PAN is ever fabricated), the
    ///   offer's type and currency, no spending limit. Adding an offer whose
    ///   id is already managed throws `AppError.cardAlreadyExists`.
    /// - `removeCard(cardId:)` removes the card; removing an unknown id is a
    ///   no-op (idempotent, mirroring the store's delete semantics).
    ///
    /// Failure knobs (architecture.md §9.5, §10): `shouldThrowError` throws
    /// `thrownError` (default `.apiConnectionFailed` — the model error
    /// state), `shouldNeverComplete` parks the call forever (the model
    /// loading state; never-complete wins over throwing so a loading mock
    /// cannot also fail). Call counts let model tests assert the model
    /// called the repository exactly once per load.
    @MainActor
    public final class MockCardRepository: CardRepositoryProtocol {
        public private(set) var cards: [Card]

        public var shouldThrowError = false
        public var shouldNeverComplete = false
        /// Error thrown when `shouldThrowError` is set; tests replace it
        /// with a specific case when the model must surface one.
        public var thrownError: AppError = .apiConnectionFailed()

        public private(set) var getCardsCallCount = 0
        public private(set) var addCardCallCount = 0
        public private(set) var removeCardCallCount = 0
        public private(set) var updateCardCallCount = 0
        /// Offers passed to `addCard`, oldest first.
        public private(set) var addedOffers: [CardOffer] = []
        /// Card ids passed to `removeCard`, oldest first.
        public private(set) var removedCardIds: [String] = []

        public init(seed: [Card] = Card.mockDefaults) {
            cards = seed
        }

        public func getCards() async throws -> [Card] {
            getCardsCallCount += 1
            try await checkFailureMode()
            return cards
        }

        public func addCard(_ offer: CardOffer) async throws -> Card {
            addCardCallCount += 1
            addedOffers.append(offer)
            try await checkFailureMode()
            guard !cards.contains(where: { $0.id == offer.id }) else {
                throw AppError.cardAlreadyExists(cardId: offer.id)
            }
            let card = Self.provisionedCard(from: offer)
            cards.append(card)
            return card
        }

        public func removeCard(cardId: String) async throws {
            removeCardCallCount += 1
            removedCardIds.append(cardId)
            try await checkFailureMode()
            cards.removeAll { $0.id == cardId }
        }

        /// Replaces the stored card with `card` (matched by id) so later
        /// reads reflect the change — the demo's way to persist a command
        /// result (e.g. a new spending limit) into the repository store
        /// (appspec §2.2: "execute() applies the change so later reads
        /// reflect it"). No-op for an unknown id, mirroring `removeCard`'s
        /// idempotence.
        public func updateCard(_ card: Card) {
            updateCardCallCount += 1
            guard let index = cards.firstIndex(where: { $0.id == card.id }) else {
                return
            }
            cards[index] = card
        }

        /// The provisional local record for an accepted offer — mirrors
        /// `CardRepository.provisionedCard` so demo behavior matches live
        /// (architecture.md §6.3: only the issuance endpoint can fill the
        /// PAN tail; no card number is ever fabricated).
        private static func provisionedCard(from offer: CardOffer) -> Card {
            Card(
                id: offer.id,
                cardholderName: "",
                lastFourDigits: "",
                type: offer.type,
                status: .active,
                currency: offer.currency,
                spendingLimit: nil,
            )
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
