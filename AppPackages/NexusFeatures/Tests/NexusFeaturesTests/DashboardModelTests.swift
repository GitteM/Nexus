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
}

/// Bounded main-actor spin: yields until `condition` holds or the budget
/// runs out. The model, the mocks, and the tests share the main actor, so
/// suspending here lets spawned subscription tasks and stream deliveries
/// run.
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0 ..< 200 {
        if condition() {
            return
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
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
