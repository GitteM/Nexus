import Entities
import Mocks
import RepositoryProtocols
import Testing

/// Day 8 tests for the shared mock repositories (architecture.md §9.5,
/// §11.2): seed behavior, contract fidelity, failure knobs, and call counts.
///
/// Model tests (Day 10+) drive loading/error states through
/// `shouldNeverComplete`/`shouldThrowError` and assert orchestration through
/// the call counts; these tests pin the mock contract itself so the models
/// can rely on it.
@Suite("Mock repositories")
@MainActor
struct MockRepositoriesTests {
    // MARK: - MockCardRepository

    @Test
    func `seeds cards and returns them on getCards`() async throws {
        let mock = MockCardRepository(seed: Card.mockDefaults)
        let cards = try await mock.getCards()
        #expect(cards == Card.mockDefaults)
        #expect(mock.getCardsCallCount == 1)
    }

    @Test
    func `addCard records the offer and returns a provisional card`() async throws {
        let mock = MockCardRepository(seed: [])
        let card = try await mock.addCard(CardOffer.mockCashbackOffer)

        #expect(card.id == CardOffer.mockCashbackOffer.id)
        #expect(card.status == .active)
        #expect(card.lastFourDigits.isEmpty) // no PAN fabricated
        #expect(card.type == CardOffer.mockCashbackOffer.type)
        #expect(try await mock.getCards() == [card])
        #expect(mock.addCardCallCount == 1)
        #expect(mock.addedOffers == [CardOffer.mockCashbackOffer])
    }

    @Test
    func `addCard rejects an offer that is already managed`() async throws {
        let mock = MockCardRepository(seed: [])
        // Adding the offer once makes its id managed (the provisional card
        // shares the offer id); a second add must be rejected.
        _ = try await mock.addCard(CardOffer.mockCashbackOffer)
        await #expect(throws: AppError.cardAlreadyExists(cardId: CardOffer.mockCashbackOffer.id)) {
            try await mock.addCard(CardOffer.mockCashbackOffer)
        }
        #expect(mock.cards.count == 1) // nothing duplicated in the store
    }

    @Test
    func `removeCard removes and is idempotent for unknown ids`() async throws {
        let mock = MockCardRepository(seed: Card.mockDefaults)
        try await mock.removeCard(cardId: Card.mockCreditCard.id)
        #expect(try await mock.getCards().contains { $0.id == Card.mockCreditCard.id } == false)
        #expect(mock.removedCardIds == [Card.mockCreditCard.id])

        // Removing an unknown id is a no-op, not an error.
        try await mock.removeCard(cardId: "card-unknown-001")
        #expect(mock.removeCardCallCount == 2)
        #expect(try await mock.getCards().count == Card.mockDefaults.count - 1)
    }

    @Test
    func `shouldThrowError fails every card repository call`() async {
        let mock = MockCardRepository(seed: Card.mockDefaults)
        mock.shouldThrowError = true

        await #expect(throws: AppError.apiConnectionFailed()) {
            _ = try await mock.getCards()
        }
        await #expect(throws: AppError.apiConnectionFailed()) {
            _ = try await mock.addCard(CardOffer.mockTravelOffer)
        }
        await #expect(throws: AppError.apiConnectionFailed()) {
            try await mock.removeCard(cardId: Card.mockCreditCard.id)
        }
        // Calls still count so model tests can tell the failure was reached.
        #expect(mock.getCardsCallCount == 1)
        #expect(mock.addCardCallCount == 1)
        #expect(mock.removeCardCallCount == 1)
    }

    @Test
    func `a custom thrownError surfaces instead of the default`() async {
        let mock = MockCardRepository()
        mock.shouldThrowError = true
        mock.thrownError = .cardNotFound(cardId: "card-credit-001")
        await #expect(throws: AppError.cardNotFound(cardId: "card-credit-001")) {
            _ = try await mock.getCards()
        }
    }

    @Test
    func `shouldNeverComplete parks a call in the loading state`() async {
        let mock = MockCardRepository(seed: Card.mockDefaults)
        mock.shouldNeverComplete = true

        let task = Task { try await mock.getCards() }
        // Give the call a chance to either return (knob broken) or park.
        try? await Task.sleep(for: .milliseconds(100))
        #expect(mock.getCardsCallCount == 1) // the call was entered…
        #expect(!task.isCancelled)
        task.cancel() // …and is still parked, not completed.
        _ = task
    }

    // MARK: - MockOffersRepository

    @Test
    func `offers repository serves and publishes full-list snapshots`() async throws {
        let mock = MockOffersRepository(seed: [CardOffer.mockCashbackOffer])
        #expect(try await mock.getAvailableOffers() == [CardOffer.mockCashbackOffer])

        let stream = try await mock.subscribeToOffers()
        mock.publish([CardOffer.mockCashbackOffer, CardOffer.mockTravelOffer])

        #expect(try await mock.getAvailableOffers() == [CardOffer.mockCashbackOffer, CardOffer.mockTravelOffer])
        #expect(mock.getAvailableOffersCallCount == 2)
        #expect(mock.subscribeToOffersCallCount == 1)
        #expect(mock.publishedSnapshots == [[CardOffer.mockCashbackOffer, CardOffer.mockTravelOffer]])

        // The subscription saw the current list first, then the replacement.
        // (Collection is bounded: mock streams stay open until terminated.)
        var collected: [[CardOffer]] = []
        for await snapshot in stream {
            collected.append(snapshot)
            if collected.count == 2 {
                break
            }
        }
        #expect(collected == [
            [CardOffer.mockCashbackOffer],
            [CardOffer.mockCashbackOffer, CardOffer.mockTravelOffer],
        ])
    }

    @Test
    func `offers repository failure knob reaches both calls`() async {
        let mock = MockOffersRepository()
        mock.shouldThrowError = true
        mock.thrownError = .apiConnectionFailed(details: "demo failure")

        await #expect(throws: AppError.apiConnectionFailed(details: "demo failure")) {
            _ = try await mock.getAvailableOffers()
        }
        await #expect(throws: AppError.apiConnectionFailed(details: "demo failure")) {
            _ = try await mock.subscribeToOffers()
        }
    }

    // MARK: - MockStatusRepository

    @Test
    func `status repository answers known and unknown cards`() async throws {
        let mock = MockStatusRepository(seed: CardState.mockDefaults)
        #expect(try await mock.getCardStatus(cardId: "card-credit-001") == .mockActiveState)
        #expect(try await mock.getCardStatus(cardId: "card-unknown-001") == nil)
        #expect(mock.getCardStatusCallCount == 2)
    }

    @Test
    func `status repository publishes updates to subscribers and its store`() async throws {
        let mock = MockStatusRepository(seed: [.mockActiveState])
        let stream = try await mock.subscribeToCardStatus(cardId: "card-credit-001")

        let frozen = CardState(cardId: "card-credit-001", status: .frozen)
        mock.publish(frozen)

        // Store updated before any consumer is woken (delivery edge).
        #expect(try await mock.getCardStatus(cardId: "card-credit-001") == frozen)
        #expect(mock.publishedStates == [frozen])

        // The subscription yielded the seeded state first, then the update.
        // (Collection is bounded: mock streams stay open until terminated.)
        var collected: [CardState] = []
        for await state in stream {
            collected.append(state)
            if collected.count == 2 {
                break
            }
        }
        #expect(collected == [.mockActiveState, frozen])
    }

    @Test
    func `status repository subscription only reaches its own card`() async throws {
        let mock = MockStatusRepository(seed: [.mockActiveState])
        // A subscription to a card no state is known for yet.
        let stream = try await mock.subscribeToCardStatus(cardId: "card-credit-002")

        // Updates for *other* cards must never be delivered on it.
        mock.publish(.mockLostState) // card-credit-004
        mock.publish(CardState(cardId: "card-credit-001", status: .frozen))

        // The first element this subscription ever sees is its own card's
        // first update — proving the misrouted frames above were dropped.
        let ownUpdate = CardState(cardId: "card-credit-002", status: .lost)
        mock.publish(ownUpdate)

        var collected: [CardState] = []
        for await state in stream {
            collected.append(state)
            break
        }
        #expect(collected == [ownUpdate])
    }

    @Test
    func `status repository rejects an empty card id like the live boundary`() async {
        let mock = MockStatusRepository()
        await #expect(throws: AppError.validationError(field: "cardId", reason: "Card id must not be empty.")) {
            _ = try await mock.subscribeToCardStatus(cardId: "")
        }
    }

    @Test
    func `status repository failure knob throws before any stream exists`() async {
        let mock = MockStatusRepository()
        mock.shouldThrowError = true
        await #expect(throws: AppError.apiConnectionFailed()) {
            _ = try await mock.getCardStatus(cardId: "card-credit-001")
        }
        await #expect(throws: AppError.apiConnectionFailed()) {
            _ = try await mock.subscribeToCardStatus(cardId: "card-credit-001")
        }
        #expect(mock.subscribeToCardStatusCallCount == 1)
    }

    // MARK: - MockActionRepository

    @Test
    func `action repository records executed commands`() async throws {
        let mock = MockActionRepository()
        let freeze = CardCommand.freeze(cardId: "card-credit-001")
        try await mock.execute(freeze)
        try await mock.execute(.unfreeze(cardId: "card-credit-001"))

        #expect(mock.executeCallCount == 2)
        #expect(mock.executedCommands == [freeze, .unfreeze(cardId: "card-credit-001")])
        #expect(mock.lastCommand == .unfreeze(cardId: "card-credit-001"))
    }

    @Test
    func `action repository failure knob throws cardActionFailed`() async {
        let mock = MockActionRepository()
        mock.shouldThrowError = true
        await #expect(throws: AppError.cardActionFailed(action: "cardAction")) {
            try await mock.execute(.freeze(cardId: "card-credit-001"))
        }
        #expect(mock.executeCallCount == 1) // recorded before the failure
    }

    @Test
    func `mock seeds mirror the domain mockDefaults sets`() {
        #expect(MockCardRepository().cards == Card.mockDefaults)
        #expect(MockOffersRepository().offers == CardOffer.mockDefaults)
        #expect(MockStatusRepository().statesByCardId["card-credit-001"] == CardState.mockActiveState)
    }
}
