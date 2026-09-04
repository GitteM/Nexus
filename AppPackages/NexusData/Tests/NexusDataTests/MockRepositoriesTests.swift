import Entities
import Mocks
import RepositoryProtocols
import Testing

/// Tests for the shared mock repositories: seed behavior, contract
/// fidelity, failure knobs, and call counts.
///
/// Model tests drive loading/error states through
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

    // MARK: - MockCardRepository.updateCard

    @Test
    func `updateCard replaces a stored card and counts the call`() {
        let mock = MockCardRepository(seed: Card.mockDefaults)
        let updated = Card.mockFrozenCard.withStatus(.lost)

        mock.updateCard(updated)

        #expect(mock.cards.first { $0.id == updated.id } == updated)
        #expect(mock.updateCardCallCount == 1)
        // Every other card is untouched.
        #expect(mock.cards.count == Card.mockDefaults.count)
    }

    @Test
    func `updateCard is a no-op for an unknown id`() {
        let mock = MockCardRepository(seed: Card.mockDefaults)
        let unknown = Card(
            id: "card-unknown",
            cardholderName: "Nobody",
            lastFourDigits: "0000",
            type: .credit,
            status: .active,
            currency: "EUR",
            spendingLimit: nil,
        )

        mock.updateCard(unknown)

        #expect(mock.cards == Card.mockDefaults)
        #expect(mock.updateCardCallCount == 1)
    }

    // MARK: - MockActionRepository.onExecute

    @Test
    func `onExecute fires after a successful execute with the command`() async throws {
        let mock = MockActionRepository()
        var observed: [CardCommand] = []
        mock.onExecute = { command in
            observed.append(command)
        }

        let freeze = CardCommand.freeze(cardId: "card-credit-001")
        try await mock.execute(freeze)
        try await mock.execute(.unfreeze(cardId: "card-credit-001"))

        #expect(observed == [freeze, .unfreeze(cardId: "card-credit-001")])
        #expect(mock.executeCallCount == 2)
    }

    @Test
    func `onExecute does not fire when execute throws`() async {
        let mock = MockActionRepository()
        var observed: [CardCommand] = []
        mock.onExecute = { command in
            observed.append(command)
        }
        mock.shouldThrowError = true

        await #expect(throws: AppError.cardActionFailed(action: "cardAction")) {
            try await mock.execute(.freeze(cardId: "card-credit-001"))
        }

        #expect(observed.isEmpty)
    }

    // MARK: - MockCommandCoordinator

    @Test
    func `coordinator echoes freeze onto the store and the status channel`() async throws {
        let graph = makeCoordinatorGraph()

        try await graph.action.execute(CardCommand.freeze(cardId: Card.mockCreditCard.id))

        // The store keeps the new state (reloads read it)…
        #expect(graph.card.cards.first { $0.id == Card.mockCreditCard.id }?.status == .frozen)
        // …and the status channel published it (subscriptions reconcile).
        #expect(graph.status.statesByCardId[Card.mockCreditCard.id]?.status == .frozen)
    }

    @Test
    func `coordinator echoes unfreeze and lost reports onto the status channel`() async throws {
        let graph = makeCoordinatorGraph()

        try await graph.action.execute(.unfreeze(cardId: Card.mockFrozenCard.id))
        #expect(graph.status.statesByCardId[Card.mockFrozenCard.id]?.status == .active)
        #expect(graph.card.cards.first { $0.id == Card.mockFrozenCard.id }?.status == .active)

        try await graph.action.execute(CardCommand(cardId: Card.mockCreditCard.id, type: .reportLost))
        #expect(graph.status.statesByCardId[Card.mockCreditCard.id]?.status == .lost)

        try await graph.action.execute(CardCommand(cardId: Card.mockDebitCard.id, type: .reportStolen))
        #expect(graph.status.statesByCardId[Card.mockDebitCard.id]?.status == .lost)
    }

    @Test
    func `coordinator persists a set spending limit onto the stored card`() async throws {
        let graph = makeCoordinatorGraph()

        try await graph.action.execute(
            CardCommand.setSpendingLimit(cardId: Card.mockCreditCard.id, period: .daily, amount: 250),
        )

        #expect(graph.card.cards.first { $0.id == Card.mockCreditCard.id }?.spendingLimit == 250)
        // The status channel is untouched by a limit change.
        #expect(graph.status.statesByCardId[Card.mockCreditCard.id]?.status == .active)
    }

    @Test
    func `coordinator mints a replacement offer for a lost card`() async throws {
        let graph = makeCoordinatorGraph()

        try await graph.action.execute(CardCommand(cardId: Card.mockLostCard.id, type: .requestReplacement))

        let replacement = graph.offers.offers.first { $0.id == "offer-replacement-\(Card.mockLostCard.id)" }
        #expect(replacement != nil)
        #expect(replacement?.type == Card.mockLostCard.type)
        #expect(replacement?.currency == Card.mockLostCard.currency)
        // The lost card stays lost; the existing offers stay listed.
        #expect(graph.status.statesByCardId[Card.mockLostCard.id]?.status == .lost)
        #expect(graph.offers.offers.count == CardOffer.mockDefaults.count + 1)

        // A second request is a no-op — the offer already exists.
        try await graph.action.execute(CardCommand(cardId: Card.mockLostCard.id, type: .requestReplacement))
        #expect(graph.offers.offers.count == CardOffer.mockDefaults.count + 1)
    }

    @Test
    func `coordinator ignores commands for unknown cards and unknown types`() async throws {
        let graph = makeCoordinatorGraph()

        try await graph.action.execute(CardCommand(cardId: "card-unknown", type: .freeze))
        try await graph.action.execute(CardCommand(cardId: Card.mockCreditCard.id, type: .unknown))

        #expect(graph.status.publishedStates.isEmpty)
        #expect(graph.card.updateCardCallCount == 0)
    }

    @Test
    func `a failing command never echoes through the coordinator`() async {
        let graph = makeCoordinatorGraph()
        graph.action.shouldThrowError = true

        await #expect(throws: AppError.cardActionFailed(action: "cardAction")) {
            try await graph.action.execute(CardCommand.freeze(cardId: Card.mockCreditCard.id))
        }

        #expect(graph.status.publishedStates.isEmpty)
        #expect(graph.card.cards.first { $0.id == Card.mockCreditCard.id }?.status == .active)
    }

    // MARK: - Coordinator graph helper

    /// Builds the store graph with the coordinator installed. The tuple
    /// holds the coordinator so it stays alive for the test's scope — the
    /// hook holds it weakly, so the *owner* (here, the test; in demo mode,
    /// `DemoGraph`) must retain it.
    private func makeCoordinatorGraph() -> (
        action: MockActionRepository,
        card: MockCardRepository,
        status: MockStatusRepository,
        offers: MockOffersRepository,
        coordinator: MockCommandCoordinator,
    ) {
        let card = MockCardRepository(seed: Card.mockDefaults)
        let status = MockStatusRepository(seed: CardState.mockDefaults)
        let offers = MockOffersRepository(seed: CardOffer.mockDefaults)
        let action = MockActionRepository()
        let coordinator = MockCommandCoordinator(
            actionRepository: action,
            cardRepository: card,
            statusRepository: status,
            offersRepository: offers,
        )
        coordinator.start()
        return (action, card, status, offers, coordinator)
    }

    // MARK: - MockBalanceRepository

    @Test
    func `balance repository serves seeds and publishes live values`() async throws {
        let mock = MockBalanceRepository(seed: Balance.mockDefaults)

        #expect(try await mock.getBalance(cardId: Card.mockCreditCard.id) == .mockCreditBalance)
        #expect(try await mock.getBalance(cardId: "card-unknown") == nil)

        let stream = try await mock.subscribeToBalance(cardId: Card.mockCreditCard.id)
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == .mockCreditBalance) // seeds current first

        let updated = Balance(cardId: Card.mockCreditCard.id, current: 900, available: 900, creditLimit: 2500, currency: "EUR")
        mock.publish(updated)
        #expect(await iterator.next() == updated)
        #expect(mock.balancesByCardId[Card.mockCreditCard.id] == updated) // store updated
        #expect(mock.publishedBalances == [updated])
    }

    @Test
    func `balance repository rejects an empty card id like the live boundary`() async {
        let mock = MockBalanceRepository()

        await #expect(throws: AppError.validationError(field: "cardId", reason: "Card id must not be empty.")) {
            _ = try await mock.getBalance(cardId: "")
        }
        await #expect(throws: AppError.validationError(field: "cardId", reason: "Card id must not be empty.")) {
            _ = try await mock.subscribeToBalance(cardId: "")
        }
    }

    // MARK: - MockTransactionRepository

    @Test
    func `transaction repository serves seeds and folds publishes newest-first`() async throws {
        let mock = MockTransactionRepository(seed: [Card.mockCreditCard.id: Transaction.mockDefaults])

        #expect(try await mock.getTransactions(cardId: Card.mockCreditCard.id) == Transaction.mockDefaults)
        #expect(try await mock.getTransactions(cardId: Card.mockDebitCard.id) == [])

        let stream = try await mock.subscribeToTransactions(cardId: Card.mockCreditCard.id)
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == Transaction.mockDefaults) // seeds current first

        // A newer purchase lands at the front of the folded list.
        let newer = Transaction(
            id: "txn-newest",
            cardId: Card.mockCreditCard.id,
            date: .now,
            merchant: "New Shop",
            amount: -20,
            currency: "EUR",
            category: .shopping,
            status: .pending,
            location: nil,
        )
        mock.publish(newer)
        let folded = await iterator.next()
        #expect(folded?.first == newer)
        #expect(folded?.count == Transaction.mockDefaults.count + 1)
        #expect(mock.transactionsByCardId[Card.mockCreditCard.id] == folded)
    }

    @Test
    func `transaction repository publish replaces a same-id frame`() async throws {
        let mock = MockTransactionRepository(seed: [Card.mockCreditCard.id: Transaction.mockDefaults])
        let cleared = Transaction(
            id: Transaction.mockCoffeePurchase.id,
            cardId: Card.mockCreditCard.id,
            date: Transaction.mockCoffeePurchase.date,
            merchant: Transaction.mockCoffeePurchase.merchant,
            amount: Transaction.mockCoffeePurchase.amount,
            currency: "EUR",
            category: .dining,
            status: .cleared,
            location: "Berlin",
        )

        mock.publish(cleared)

        let list = try await mock.getTransactions(cardId: Card.mockCreditCard.id)
        #expect(list.count == Transaction.mockDefaults.count) // replaced, not appended
        #expect(list.contains { $0.id == Transaction.mockCoffeePurchase.id && $0.status == .cleared })
    }
}
