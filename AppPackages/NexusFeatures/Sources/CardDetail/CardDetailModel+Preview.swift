#if DEBUG
    import Entities
    import Mocks

    /// Shared-mock factories for the card detail screen.
    ///
    /// Every factory builds the *real* `CardDetailModel` over the shared
    /// `Mock*Repository` doubles, so previews, unit tests, and demo mode all
    /// exercise the same orchestration code. The returned models are not
    /// pre-loaded: `CardDetailView`'s `.task` fires `load()` when a preview
    /// appears, exactly as in the running app.
    ///
    /// Release builds compile this file to nothing: the `Mocks` module
    /// itself is empty outside DEBUG.
    public extension CardDetailModel {
        /// Default demo content for one card: `load()` lands in `.loaded`
        /// with the mock card set and the standard per-card status seeds.
        static func preview(cardID: String) -> CardDetailModel {
            detailModel(cardID: cardID, seed: Card.mockDefaults, states: CardState.mockDefaults)
        }

        /// Loading preview: the card fetch parks forever
        /// (`shouldNeverComplete`), so `load()` never leaves `.loading`.
        static func loadingPreview(cardID: String) -> CardDetailModel {
            let cardRepository = MockCardRepository(seed: Card.mockDefaults)
            cardRepository.shouldNeverComplete = true
            return CardDetailModel(
                cardID: cardID,
                cardRepository: cardRepository,
                statusRepository: MockStatusRepository(seed: CardState.mockDefaults),
                actionRepository: MockActionRepository(),
            )
        }

        /// Error preview: the card fetch throws `error` (default
        /// `.apiConnectionFailed`), so `load()` lands in `.error(error)`.
        static func errorPreview(
            cardID: String,
            error: AppError = .apiConnectionFailed(),
        ) -> CardDetailModel {
            let cardRepository = MockCardRepository(seed: Card.mockDefaults)
            cardRepository.shouldThrowError = true
            cardRepository.thrownError = error
            return CardDetailModel(
                cardID: cardID,
                cardRepository: cardRepository,
                statusRepository: MockStatusRepository(seed: CardState.mockDefaults),
                actionRepository: MockActionRepository(),
            )
        }

        /// Builds the shared-mock graph for one card's detail model.
        private static func detailModel(
            cardID: String,
            seed: [Card],
            states: [CardState],
        ) -> CardDetailModel {
            CardDetailModel(
                cardID: cardID,
                cardRepository: MockCardRepository(seed: seed),
                statusRepository: MockStatusRepository(seed: states),
                actionRepository: MockActionRepository(),
            )
        }
    }
#endif
