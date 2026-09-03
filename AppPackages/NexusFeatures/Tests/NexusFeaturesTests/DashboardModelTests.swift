import Dashboard
import Entities
import Foundation
import Mocks
import RepositoryProtocols
import Testing

/// `DashboardModel` orchestration (architecture.md §9.1, tasks.md Day 10):
/// state transitions, load idempotence, repository call counts, the
/// loading/error knobs, and the per-card live subscriptions the model owns.
///
/// The model and the tests share the main actor, so a poll helper yields
/// between assertions to let spawned subscription tasks and stream
/// deliveries make progress deterministically.
@Suite("Dashboard model")
@MainActor
struct DashboardModelTests {
    // MARK: - Helpers

    private func makeModel(
        cards: [Card] = Card.mockDefaults,
        offers: [CardOffer] = CardOffer.mockDefaults,
        states: [CardState] = CardState.mockDefaults,
    ) -> (model: DashboardModel, cardRepository: MockCardRepository, offersRepository: MockOffersRepository, statusRepository: MockStatusRepository) {
        let cardRepository = MockCardRepository(seed: cards)
        let offersRepository = MockOffersRepository(seed: offers)
        let statusRepository = MockStatusRepository(seed: states)
        let model = DashboardModel(
            cardRepository: cardRepository,
            offersRepository: offersRepository,
            statusRepository: statusRepository,
        )
        return (model, cardRepository, offersRepository, statusRepository)
    }

    // MARK: - Initial state

    @Test func `starts in the loading state with no data`() {
        let (model, _, _, _) = makeModel()

        #expect(model.viewState == .loading)
        #expect(model.cards.isEmpty)
        #expect(model.offeredCards.isEmpty)
        #expect(model.cardStates.isEmpty)
    }

    // MARK: - Load

    @Test func `load fetches cards and offers then lands loaded`() async {
        let (model, cardRepository, offersRepository, statusRepository) = makeModel()

        await model.load()

        #expect(model.viewState == .loaded)
        #expect(model.cards == Card.mockDefaults)
        #expect(model.offeredCards == CardOffer.mockDefaults)
        #expect(cardRepository.getCardsCallCount == 1)
        #expect(offersRepository.getAvailableOffersCallCount == 1)

        // One live subscription per managed card…
        await waitUntil { statusRepository.subscribeToCardStatusCallCount == Card.mockDefaults.count }
        // …and each seeded state lands in the ledger.
        await waitUntil {
            model.cardStates["card-credit-001"] == .mockActiveState
                && model.cardStates["card-credit-002"] == .mockFrozenState
                && model.cardStates["card-credit-004"] == .mockLostState
        }
    }

    @Test func `load is idempotent once content is on screen`() async {
        let (model, cardRepository, offersRepository, _) = makeModel()

        await model.load()
        await model.load()

        #expect(model.viewState == .loaded)
        #expect(cardRepository.getCardsCallCount == 1)
        #expect(offersRepository.getAvailableOffersCallCount == 1)
    }

    @Test func `load lands empty on a fresh account with no subscriptions`() async {
        let (model, _, _, statusRepository) = makeModel(cards: [], offers: [])

        await model.load()

        #expect(model.viewState == .empty)
        #expect(model.cards.isEmpty)
        #expect(model.offeredCards.isEmpty)
        #expect(statusRepository.subscribeToCardStatusCallCount == 0)
    }

    @Test func `load is a no-op from the empty state`() async {
        let (model, cardRepository, offersRepository, _) = makeModel(cards: [], offers: [])

        await model.load()
        await model.load()

        #expect(model.viewState == .empty)
        #expect(cardRepository.getCardsCallCount == 1)
        #expect(offersRepository.getAvailableOffersCallCount == 1)
    }

    @Test func `load lands in the error state when a repository fails`() async {
        let (model, cardRepository, _, _) = makeModel()
        cardRepository.shouldThrowError = true
        cardRepository.thrownError = .cardNotFound(cardId: "card-credit-001")

        await model.load()

        #expect(model.viewState == .error(.cardNotFound(cardId: "card-credit-001")))
        #expect(model.cards.isEmpty) // nothing partial on screen
        #expect(model.offeredCards.isEmpty)
    }

    @Test func `load retries from the error state once the failure clears`() async {
        let (model, cardRepository, _, _) = makeModel()
        cardRepository.shouldThrowError = true

        await model.load()
        #expect(model.viewState == .error(.apiConnectionFailed()))

        cardRepository.shouldThrowError = false
        await model.load()

        #expect(model.viewState == .loaded)
        #expect(model.cards == Card.mockDefaults)
        #expect(cardRepository.getCardsCallCount == 2)
    }

    @Test func `non AppError failures map to the unknown error state`() async {
        // A double that throws a plain Error — impossible through the
        // AppError-only mocks — pins the model's catch-all mapping.
        let cardRepository = UnknownErrorCardRepository()
        let offersRepository = MockOffersRepository(seed: [])
        let statusRepository = MockStatusRepository(seed: [])
        let model = DashboardModel(
            cardRepository: cardRepository,
            offersRepository: offersRepository,
            statusRepository: statusRepository,
        )

        await model.load()

        // .unknown equality compares the underlying error's presence only.
        #expect(model.viewState == .error(.unknown(underlying: URLError(.badServerResponse))))
    }

    // MARK: - Loading knob

    @Test func `a load that never completes stays in the loading state`() async {
        let (model, cardRepository, _, _) = makeModel()
        cardRepository.shouldNeverComplete = true

        let loadTask = Task { await model.load() }
        await waitUntil { cardRepository.getCardsCallCount == 1 }

        #expect(model.viewState == .loading)
        loadTask.cancel()
    }

    @Test func `load refuses to double a load that is already in flight`() async {
        let (model, cardRepository, offersRepository, _) = makeModel()
        cardRepository.shouldNeverComplete = true

        let firstLoad = Task { await model.load() }
        await waitUntil { cardRepository.getCardsCallCount == 1 }

        await model.load() // second fire while the first is parked

        // The first load's async-let children started both fetches (offers
        // completes because only the card repository parks); the second
        // load added nothing on top.
        #expect(cardRepository.getCardsCallCount == 1)
        #expect(offersRepository.getAvailableOffersCallCount == 1)
        firstLoad.cancel()
    }

    // MARK: - Refresh

    @Test func `refresh reloads content that is already on screen`() async {
        let (model, cardRepository, offersRepository, _) = makeModel()

        await model.load()
        await model.refresh()

        #expect(model.viewState == .loaded)
        #expect(model.cards == Card.mockDefaults)
        #expect(cardRepository.getCardsCallCount == 2)
        #expect(offersRepository.getAvailableOffersCallCount == 2)
    }

    @Test func `refresh after an empty account picks up new offers`() async {
        let (model, _, offersRepository, _) = makeModel(cards: [], offers: [])
        await model.load()
        #expect(model.viewState == .empty)

        // A backend snapshot publishes an offer list the next fetch returns.
        offersRepository.publish([CardOffer.mockCashbackOffer])
        await model.refresh()

        #expect(model.viewState == .loaded)
        #expect(model.offeredCards == [CardOffer.mockCashbackOffer])
    }

    @Test func `refresh failure keeps the last good content on screen`() async {
        let (model, cardRepository, _, _) = makeModel()
        await model.load()

        cardRepository.shouldThrowError = true
        await model.refresh()

        #expect(model.viewState == .loaded) // no drop to .error
        #expect(model.cards == Card.mockDefaults) // content untouched
        #expect(cardRepository.getCardsCallCount == 2)
    }

    // MARK: - Live subscriptions

    @Test func `live status updates flow into cardStates and the card list`() async {
        let (model, _, _, statusRepository) = makeModel()
        await model.load()
        await waitUntil { statusRepository.subscribeToCardStatusCallCount == Card.mockDefaults.count }

        let frozen = CardState(cardId: "card-credit-001", status: .frozen)
        statusRepository.publish(frozen)

        await waitUntil { model.cardStates["card-credit-001"] == frozen }
        #expect(model.cards.first { $0.id == "card-credit-001" }?.status == .frozen)
        #expect(model.cards.first { $0.id == "card-credit-002" }?.status == .frozen) // untouched card
    }

    @Test func `refresh stops following cards that left the list`() async throws {
        let (model, cardRepository, _, statusRepository) = makeModel()
        await model.load()
        await waitUntil { statusRepository.subscribeToCardStatusCallCount == Card.mockDefaults.count }

        try await cardRepository.removeCard(cardId: Card.mockCreditCard.id)
        await model.refresh()

        #expect(model.cards.contains { $0.id == Card.mockCreditCard.id } == false)
        #expect(model.cardStates[Card.mockCreditCard.id] == nil) // pruned with the card

        // Pushes for the removed card no longer land in the ledger.
        statusRepository.publish(CardState(cardId: Card.mockCreditCard.id, status: .frozen))
        try? await Task.sleep(for: .milliseconds(20))
        #expect(model.cardStates[Card.mockCreditCard.id] == nil)
    }

    @Test func `refresh starts subscriptions for cards that joined the list`() async throws {
        let (model, cardRepository, _, statusRepository) = makeModel()
        await model.load()
        await waitUntil { statusRepository.subscribeToCardStatusCallCount == Card.mockDefaults.count }

        _ = try await cardRepository.addCard(CardOffer.mockCashbackOffer)
        await model.refresh()

        #expect(model.cards.contains { $0.id == CardOffer.mockCashbackOffer.id })
        #expect(model.cards.count == Card.mockDefaults.count + 1)
        // The new card subscribes; existing cards keep their subscriptions.
        await waitUntil {
            statusRepository.subscribeToCardStatusCallCount == Card.mockDefaults.count + 1
        }
    }

    // MARK: - Adding an offer

    @Test func `adding an offer creates a managed card and drops the offer`() async {
        let (model, cardRepository, _, statusRepository) = makeModel()
        await model.load()
        await waitUntil { statusRepository.subscribeToCardStatusCallCount == Card.mockDefaults.count }

        await model.addOffer(CardOffer.mockCashbackOffer)

        // The card lands in the carousel list, the offer leaves the catalog…
        #expect(model.cards.count == Card.mockDefaults.count + 1)
        #expect(model.cards.last?.id == CardOffer.mockCashbackOffer.id)
        #expect(model.cards.last?.status == .active)
        #expect(model.offeredCards.contains { $0.id == CardOffer.mockCashbackOffer.id } == false)
        // …the repository was asked exactly once with the offer…
        #expect(cardRepository.addCardCallCount == 1)
        #expect(cardRepository.addedOffers == [CardOffer.mockCashbackOffer])
        // …and the new card got its own live status subscription.
        await waitUntil {
            statusRepository.subscribeToCardStatusCallCount == Card.mockDefaults.count + 1
        }
        #expect(model.addOfferError == nil)
        #expect(model.lastAddedCardID == CardOffer.mockCashbackOffer.id)
        #expect(model.viewState == .loaded)
    }

    @Test func `an in-flight add refuses a second add of the same offer`() async {
        let (model, cardRepository, _, _) = makeModel()
        await model.load()

        cardRepository.shouldNeverComplete = true
        let firstAdd = Task { await model.addOffer(CardOffer.mockTravelOffer) }
        await waitUntil { model.offersBeingAdded.contains(CardOffer.mockTravelOffer.id) }

        await model.addOffer(CardOffer.mockTravelOffer) // second tap while parked

        #expect(cardRepository.addCardCallCount == 1)
        firstAdd.cancel()
        // The cancelled task's defer removes the in-flight marker once it
        // unwinds on the main actor.
        await waitUntil { model.offersBeingAdded.isEmpty }
        #expect(model.offersBeingAdded.isEmpty)
    }

    @Test func `a failed add surfaces the error and keeps the dashboard content`() async {
        let (model, cardRepository, _, _) = makeModel()
        await model.load()
        let cardsBefore = model.cards
        let offersBefore = model.offeredCards

        cardRepository.shouldThrowError = true
        cardRepository.thrownError = .apiConnectionFailed()
        await model.addOffer(CardOffer.mockTravelOffer)

        #expect(model.addOfferError == .apiConnectionFailed())
        #expect(model.cards == cardsBefore) // nothing partial on screen
        #expect(model.offeredCards == offersBefore)
        #expect(model.viewState == .loaded) // the screen error surface stays untouched
        #expect(model.lastAddedCardID == nil)
    }

    @Test func `dismissing the add error clears it for the next attempt`() async {
        let (model, cardRepository, _, _) = makeModel()
        await model.load()
        cardRepository.shouldThrowError = true

        await model.addOffer(CardOffer.mockTravelOffer)
        #expect(model.addOfferError == .apiConnectionFailed())

        model.dismissAddOfferError()
        #expect(model.addOfferError == nil)

        cardRepository.shouldThrowError = false
        await model.addOffer(CardOffer.mockTravelOffer)
        #expect(model.cards.last?.id == CardOffer.mockTravelOffer.id)
        #expect(model.addOfferError == nil)
    }

    @Test func `adding an offer that is already managed surfaces cardAlreadyExists`() async {
        // An out-of-sync catalog still lists an offer whose card already
        // exists locally; the repository is the duplicate rule's owner and
        // the model surfaces its verdict.
        let alreadyManaged = Card(
            id: CardOffer.mockCashbackOffer.id,
            cardholderName: "Jordan Avery",
            lastFourDigits: "4821",
            type: .credit,
            status: .active,
            currency: "EUR",
            spendingLimit: nil,
        )
        let (model, cardRepository, _, _) = makeModel(cards: [alreadyManaged], offers: CardOffer.mockDefaults)
        await model.load()
        #expect(model.cards.count == 1)

        await model.addOffer(CardOffer.mockCashbackOffer)

        #expect(cardRepository.addCardCallCount == 1)
        #expect(model.addOfferError == .cardAlreadyExists(cardId: CardOffer.mockCashbackOffer.id))
        #expect(model.cards.count == 1)
        #expect(model.offeredCards.count == CardOffer.mockDefaults.count)
    }

    @Test func `addOffer refuses an offer that is no longer in the catalog`() async {
        let (model, cardRepository, _, _) = makeModel(offers: [])
        await model.load()
        #expect(model.viewState == .loaded) // cards on screen, no offers

        await model.addOffer(CardOffer.mockCashbackOffer)

        #expect(cardRepository.addCardCallCount == 0) // never asked the backend
        #expect(model.addOfferError == nil)
    }
}

/// Bounded main-actor spin: yields until `condition` holds or the budget
/// runs out. The model, the mocks, and the tests share the main actor, so
/// suspending here lets spawned subscription tasks and stream deliveries
/// run. When the budget expires the helper records an issue, so a stale
/// wait surfaces a diagnostic at the poll instead of only as a confusing
/// follow-up expectation failure.
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0 ..< 200 {
        if condition() {
            return
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Timed out waiting for the condition after a 1 s budget.")
}

/// A `CardRepositoryProtocol` double that throws a plain `Error` instead of
/// an `AppError` — only reachable through a hand-rolled double, which is
/// exactly its purpose (see `non AppError failures map to the unknown
/// error state`).
private struct UnknownErrorCardRepository: CardRepositoryProtocol {
    func getCards() async throws -> [Card] {
        throw URLError(.badServerResponse)
    }

    func addCard(_: CardOffer) async throws -> Card {
        throw URLError(.badServerResponse)
    }

    func removeCard(cardId _: String) async throws {
        throw URLError(.badServerResponse)
    }
}
