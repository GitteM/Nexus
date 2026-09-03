#if DEBUG
    import Entities
    import Mocks

    /// Shared-mock factories for the dashboard (architecture.md §9.5,
    /// tasks.md Day 10).
    ///
    /// Every factory builds the *real* `DashboardModel` over the shared
    /// `Mock*Repository` doubles, so previews, unit tests, and demo mode all
    /// exercise the same orchestration code. The returned models are not
    /// pre-loaded: `DashboardView`'s `.task` fires `load()` when a preview
    /// appears, exactly as in the running app.
    ///
    /// Release builds compile this file to nothing (the `Mocks` module
    /// itself is empty outside DEBUG, Day 8).
    public extension DashboardModel {
        /// Default demo content: `load()` lands in `.loaded` with the mock
        /// card and offer sets.
        static func preview() -> DashboardModel {
            DashboardModel(
                cardRepository: MockCardRepository(seed: Card.mockDefaults),
                offersRepository: MockOffersRepository(seed: CardOffer.mockDefaults),
                statusRepository: MockStatusRepository(seed: CardState.mockDefaults),
            )
        }

        /// Fresh-account preview: `load()` lands in `.empty` (no cards, no
        /// offers).
        static func emptyPreview() -> DashboardModel {
            DashboardModel(
                cardRepository: MockCardRepository(seed: []),
                offersRepository: MockOffersRepository(seed: []),
                statusRepository: MockStatusRepository(seed: []),
            )
        }

        /// Loading preview: the card fetch parks forever
        /// (`shouldNeverComplete`), so `load()` never leaves `.loading`.
        static func loadingPreview() -> DashboardModel {
            let cardRepository = MockCardRepository(seed: Card.mockDefaults)
            cardRepository.shouldNeverComplete = true
            return DashboardModel(
                cardRepository: cardRepository,
                offersRepository: MockOffersRepository(seed: CardOffer.mockDefaults),
                statusRepository: MockStatusRepository(seed: CardState.mockDefaults),
            )
        }

        /// Error preview: the card fetch throws `error` (default
        /// `.apiConnectionFailed`), so `load()` lands in `.error(error)`.
        static func errorPreview(error: AppError = .apiConnectionFailed()) -> DashboardModel {
            let cardRepository = MockCardRepository(seed: Card.mockDefaults)
            cardRepository.shouldThrowError = true
            cardRepository.thrownError = error
            return DashboardModel(
                cardRepository: cardRepository,
                offersRepository: MockOffersRepository(seed: CardOffer.mockDefaults),
                statusRepository: MockStatusRepository(seed: CardState.mockDefaults),
            )
        }
    }
#endif
