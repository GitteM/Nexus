import CardDetail
import Entities
import Foundation
import Mocks
import RepositoryProtocols
import Testing

/// `CardDetailModel` orchestration (architecture.md §9.1, tasks.md Day 12):
/// load transitions, the card-control transition matrix (freeze/unfreeze /
/// lost / stolen / replacement / spending limits), optimistic action
/// application with stream reconciliation, and the failure paths that must
/// leave the card unchanged.
///
/// The model and the tests share the main actor, so a poll helper yields
/// between assertions to let the spawned subscription task and stream
/// deliveries make progress deterministically (DashboardModelTests
/// convention).
@Suite("Card detail model")
@MainActor
struct CardDetailModelTests {
    // MARK: - Helpers

    private func makeModel(
        cardID: String = Card.mockCreditCard.id,
        cards: [Card] = Card.mockDefaults,
        states: [CardState] = CardState.mockDefaults,
    ) -> (
        model: CardDetailModel,
        cardRepository: MockCardRepository,
        statusRepository: MockStatusRepository,
        actionRepository: MockActionRepository,
    ) {
        let cardRepository = MockCardRepository(seed: cards)
        let statusRepository = MockStatusRepository(seed: states)
        let actionRepository = MockActionRepository()
        let model = CardDetailModel(
            cardID: cardID,
            cardRepository: cardRepository,
            statusRepository: statusRepository,
            actionRepository: actionRepository,
        )
        return (model, cardRepository, statusRepository, actionRepository)
    }

    // MARK: - Initial state & load

    @Test func `starts in the loading state with no card`() {
        let (model, _, _, _) = makeModel()

        #expect(model.viewState == .loading)
        #expect(model.card == nil)
        #expect(model.cardState == nil)
        #expect(model.pendingAction == nil)
    }

    @Test func `load lands loaded with the matching card and its live status`() async {
        let (model, cardRepository, statusRepository, _) = makeModel()

        await model.load()

        #expect(model.viewState == .loaded)
        #expect(model.card == Card.mockCreditCard)
        #expect(cardRepository.getCardsCallCount == 1)
        // The status subscription seeds the current state (active).
        await waitUntil { model.cardState == .mockActiveState }
        #expect(statusRepository.subscribeToCardStatusCallCount == 1)
    }

    @Test func `load is idempotent once the card is on screen`() async {
        let (model, cardRepository, _, _) = makeModel()

        await model.load()
        await model.load()

        #expect(model.viewState == .loaded)
        #expect(cardRepository.getCardsCallCount == 1)
    }

    @Test func `load lands in the error state when the fetch fails`() async {
        let (model, cardRepository, _, _) = makeModel()
        cardRepository.shouldThrowError = true
        cardRepository.thrownError = .apiConnectionFailed()

        await model.load()

        #expect(model.viewState == .error(.apiConnectionFailed()))
        #expect(model.card == nil)
    }

    @Test func `load retries from the error state once the failure clears`() async {
        let (model, cardRepository, _, _) = makeModel()
        cardRepository.shouldThrowError = true

        await model.load()
        #expect(model.viewState == .error(.apiConnectionFailed()))

        cardRepository.shouldThrowError = false
        await model.load()

        #expect(model.viewState == .loaded)
        #expect(model.card == Card.mockCreditCard)
        #expect(cardRepository.getCardsCallCount == 2)
    }

    @Test func `load maps an unknown card id to cardNotFound`() async {
        let (model, _, _, _) = makeModel(cardID: "card-unknown")

        await model.load()

        #expect(model.viewState == .error(.cardNotFound(cardId: "card-unknown")))
    }

    @Test func `the live subscription folds a published status into the card`() async {
        let (model, _, statusRepository, _) = makeModel()
        await model.load()

        let frozen = CardState(cardId: Card.mockCreditCard.id, status: .frozen)
        statusRepository.publish(frozen)

        await waitUntil { model.cardState == frozen }
        #expect(model.card?.status == .frozen)
    }

    // MARK: - Freeze / unfreeze

    @Test func `freezing an active card executes the command and applies frozen`() async {
        let (model, _, _, actionRepository) = makeModel()

        await model.load()
        await model.freeze()

        #expect(actionRepository.executeCallCount == 1)
        #expect(actionRepository.lastCommand == .freeze(cardId: Card.mockCreditCard.id))
        // Optimistic apply: the control reflects the new status immediately…
        #expect(model.card?.status == .frozen)
        #expect(model.pendingAction == nil)
        #expect(model.actionError == nil)
        // …and the success signal fired for haptics.
        #expect(model.lastActionSequence == 1)
    }

    @Test func `the stream confirmation of a freeze reconciles without flicker`() async {
        let (model, _, statusRepository, _) = makeModel()
        await model.load()

        await model.freeze()
        #expect(model.card?.status == .frozen)

        // The backend echo lands after the optimistic apply: same status,
        // so the card and ledger stay put and the frame is recorded.
        let frozen = CardState(cardId: Card.mockCreditCard.id, status: .frozen)
        statusRepository.publish(frozen)
        await waitUntil { model.cardState == frozen }
        #expect(model.card?.status == .frozen)
    }

    @Test func `freeze is a no-op when the card is not active`() async {
        let (model, _, _, actionRepository) = makeModel(cardID: Card.mockFrozenCard.id)

        await model.load()
        await model.freeze()

        #expect(actionRepository.executeCallCount == 0)
        #expect(model.card?.status == .frozen)
    }

    @Test func `unfreezing a frozen card executes the command and applies active`() async {
        let (model, _, _, actionRepository) = makeModel(cardID: Card.mockFrozenCard.id)

        await model.load()
        await model.unfreeze()

        #expect(actionRepository.lastCommand == .unfreeze(cardId: Card.mockFrozenCard.id))
        #expect(model.card?.status == .active)
        #expect(model.lastActionSequence == 1)
    }

    @Test func `unfreeze is a no-op when the card is not frozen`() async {
        let (model, _, _, actionRepository) = makeModel()

        await model.load()
        await model.unfreeze()

        #expect(actionRepository.executeCallCount == 0)
        #expect(model.card?.status == .active)
    }

    @Test func `a second action is refused while one is in flight`() async {
        let (model, _, _, actionRepository) = makeModel()
        await model.load()

        actionRepository.shouldNeverComplete = true
        let first = Task { await model.freeze() }
        await waitUntil { model.pendingAction == .freeze }

        await model.freeze() // second tap while the first is parked
        #expect(actionRepository.executeCallCount == 1)

        first.cancel()
        await waitUntil { model.pendingAction == nil }
    }

    @Test func `a failed freeze surfaces the error and leaves the card active`() async {
        let (model, _, _, actionRepository) = makeModel()
        await model.load()

        actionRepository.shouldThrowError = true
        actionRepository.thrownError = .cardActionFailed(action: "freeze", details: "rejected")
        await model.freeze()

        #expect(model.actionError == .cardActionFailed(action: "freeze", details: "rejected"))
        #expect(model.card?.status == .active) // unchanged on failure
        #expect(model.viewState == .loaded) // error never blanks content
        #expect(model.pendingAction == nil)
        #expect(model.lastActionSequence == 0)
    }

    @Test func `dismissActionError clears the surfaced failure`() async {
        let (model, _, _, actionRepository) = makeModel()
        await model.load()
        actionRepository.shouldThrowError = true

        await model.freeze()
        #expect(model.actionError != nil)

        model.dismissActionError()
        #expect(model.actionError == nil)
    }

    // MARK: - Report lost / stolen

    @Test func `reporting lost from an active card blocks it`() async {
        let (model, _, _, actionRepository) = makeModel()

        await model.load()
        await model.reportLost()

        #expect(actionRepository.lastCommand == CardCommand(cardId: Card.mockCreditCard.id, type: .reportLost))
        #expect(model.card?.status == .lost)
    }

    @Test func `reporting stolen keeps the backend record distinct`() async {
        let (model, _, _, actionRepository) = makeModel()

        await model.load()
        await model.reportStolen()

        #expect(actionRepository.lastCommand == CardCommand(cardId: Card.mockCreditCard.id, type: .reportStolen))
        #expect(model.card?.status == .lost)
    }

    @Test func `reporting is allowed from a frozen card`() async {
        let (model, _, _, actionRepository) = makeModel(cardID: Card.mockFrozenCard.id)

        await model.load()
        await model.reportLost()

        #expect(actionRepository.executeCallCount == 1)
        #expect(model.card?.status == .lost)
    }

    @Test func `reporting is refused once the card is already lost`() async {
        let (model, _, _, actionRepository) = makeModel(cardID: Card.mockLostCard.id)

        await model.load()
        await model.reportLost()
        await model.reportStolen()

        #expect(actionRepository.executeCallCount == 0)
        #expect(model.card?.status == .lost)
    }

    @Test func `reporting is refused for an expired card`() async {
        let (model, _, _, actionRepository) = makeModel(cardID: Card.mockExpiredCard.id)

        await model.load()
        await model.reportLost()

        #expect(actionRepository.executeCallCount == 0)
        #expect(model.card?.status == .expired)
    }

    // MARK: - Replacement

    @Test func `requesting a replacement requires a lost card`() async {
        let (model, _, _, actionRepository) = makeModel()

        await model.load()
        await model.requestReplacement()

        #expect(actionRepository.executeCallCount == 0)
        #expect(model.replacementRequested == false)
    }

    @Test func `requesting a replacement after loss executes once`() async {
        let (model, _, _, actionRepository) = makeModel(cardID: Card.mockLostCard.id)

        await model.load()
        await model.requestReplacement()
        await model.requestReplacement() // second request refused

        #expect(actionRepository.executeCallCount == 1)
        #expect(actionRepository.lastCommand == CardCommand(cardId: Card.mockLostCard.id, type: .requestReplacement))
        #expect(model.replacementRequested == true)
        #expect(model.card?.status == .lost) // the old card stays lost
        #expect(model.lastActionSequence == 1)
    }

    @Test func `a failed replacement request surfaces the error and stays unrequested`() async {
        let (model, _, _, actionRepository) = makeModel(cardID: Card.mockLostCard.id)
        await model.load()

        actionRepository.shouldThrowError = true
        await model.requestReplacement()

        #expect(model.actionError != nil)
        #expect(model.replacementRequested == false)
        #expect(model.card?.status == .lost)
    }

    // MARK: - Spending limits

    @Test func `setting a limit executes the command and records the ledger entry`() async {
        let (model, _, _, actionRepository) = makeModel()

        await model.load()
        await model.setSpendingLimit(period: .daily, amount: 250)

        #expect(actionRepository.lastCommand == .setSpendingLimit(cardId: Card.mockCreditCard.id, period: .daily, amount: 250))
        #expect(model.limit(for: .daily) == SpendingLimit(cardId: Card.mockCreditCard.id, period: .daily, amount: 250, currency: "EUR"))
        #expect(model.card?.spendingLimit == 250) // card-level current limit mirrors it
        #expect(model.lastActionSequence == 1)
    }

    @Test func `limits for different periods coexist in the ledger`() async {
        let (model, _, _, _) = makeModel()

        await model.load()
        await model.setSpendingLimit(period: .daily, amount: 100)
        await model.setSpendingLimit(period: .weekly, amount: 500)

        #expect(model.limit(for: .daily)?.amount == 100)
        #expect(model.limit(for: .weekly)?.amount == 500)
        #expect(model.spendingLimits.count == 2)
    }

    @Test func `setting a limit again replaces the same period`() async {
        let (model, _, _, _) = makeModel()

        await model.load()
        await model.setSpendingLimit(period: .daily, amount: 100)
        await model.setSpendingLimit(period: .daily, amount: 150)

        #expect(model.spendingLimits.count == 1)
        #expect(model.limit(for: .daily)?.amount == 150)
    }

    @Test func `a zero or negative amount never reaches the repository`() async {
        let (model, _, _, actionRepository) = makeModel()

        await model.load()
        await model.setSpendingLimit(period: .daily, amount: 0)
        await model.setSpendingLimit(period: .daily, amount: -5)

        #expect(actionRepository.executeCallCount == 0)
        #expect(model.spendingLimits.isEmpty)
    }

    @Test func `a failed limit save surfaces the error and leaves the ledger empty`() async {
        let (model, _, _, actionRepository) = makeModel()
        await model.load()

        actionRepository.shouldThrowError = true
        await model.setSpendingLimit(period: .daily, amount: 250)

        #expect(model.actionError != nil)
        #expect(model.spendingLimits.isEmpty)
        #expect(model.card?.spendingLimit == Card.mockCreditCard.spendingLimit) // unchanged
        #expect(model.viewState == .loaded)
    }
}

@MainActor
private func waitUntil(_ condition: @MainActor () -> Bool) async {
    for _ in 0 ..< 200 {
        if condition() {
            return
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
}
