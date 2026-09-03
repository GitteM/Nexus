import Entities
import Observation
import RepositoryProtocols

/// Owns the dashboard screen's state and its live data (architecture.md
/// §9.1, tasks.md Day 10).
///
/// The "M" of MV: it orchestrates the three repositories the dashboard
/// reads (managed cards, available offers, per-card status), publishes an
/// explicit `DashboardViewState`, and owns the per-card live subscription
/// `Task`s that keep card status current. It carries no business rules and
/// no view logic — views switch on `viewState` (§9.3) and trigger one-shot
/// work through `.task` / `.refreshable`; the model never spawns one-shot
/// tasks itself.
///
/// Loading contract:
/// - `load()` is the idempotent initial load. It is safe to refire on every
///   appear: once content is on screen (`.loaded`/`.empty`) it is a no-op,
///   and from `.error` it retries. A load already in flight is never
///   doubled.
/// - `refresh()` is the explicit force reload behind pull-to-refresh. It
///   never blanks content that is already on screen, and when the refresh
///   fails it keeps the last good data instead of dropping to `.error`.
@MainActor
@Observable
public final class DashboardModel {
    public private(set) var viewState: DashboardViewState = .loading
    public private(set) var cards: [Card] = []
    public private(set) var offeredCards: [CardOffer] = []
    /// Latest live state per managed card id, filled by the subscriptions
    /// `load()` starts. `cards` also reflects the effective status so views
    /// can read either surface (§9.1).
    public private(set) var cardStates: [String: CardState] = [:]

    /// Offer ids with an `addOffer` call in flight — the offers row disables
    /// the matching row (and prevents duplicate taps) while the id is set.
    public private(set) var offersBeingAdded: Set<String> = []

    /// The last add-offer failure, or `nil` when the last add succeeded (or
    /// none has run). Views surface it and call `dismissAddOfferError()`;
    /// the dashboard's main `viewState` is untouched so a failed add never
    /// blanks content that is already on screen.
    public private(set) var addOfferError: AppError?

    /// Id of the card most recently created from an offer — the success
    /// signal views use for haptics (`.sensoryFeedback` trigger).
    public private(set) var lastAddedCardID: String?

    private let cardRepository: CardRepositoryProtocol
    private let offersRepository: CardOffersRepositoryProtocol
    private let statusRepository: CardStatusRepositoryProtocol

    /// One long-lived task per subscribed card; cancelled and pruned when
    /// the card leaves the list or the model deallocates (§9.1).
    private let subscriptionTasks = SubscriptionTaskStore()
    private var isLoadInFlight = false

    public init(
        cardRepository: CardRepositoryProtocol,
        offersRepository: CardOffersRepositoryProtocol,
        statusRepository: CardStatusRepositoryProtocol,
    ) {
        self.cardRepository = cardRepository
        self.offersRepository = offersRepository
        self.statusRepository = statusRepository
    }

    /// Idempotent initial load — see type documentation. Safe to refire on
    /// every appear; only the first call (or a retry after `.error`)
    /// actually fetches.
    public func load() async {
        guard !isLoadInFlight, viewState != .loaded, viewState != .empty else { return }
        await performLoad(keepContentOnScreen: false)
    }

    /// Force reload — see type documentation. Used by `.refreshable` and the
    /// empty state's refresh action.
    public func refresh() async {
        guard !isLoadInFlight else { return }
        await performLoad(keepContentOnScreen: true)
    }

    // MARK: - Load

    private func performLoad(keepContentOnScreen: Bool) async {
        isLoadInFlight = true
        defer { isLoadInFlight = false }

        let hasContent = !cards.isEmpty || !offeredCards.isEmpty
        if !keepContentOnScreen || !hasContent {
            viewState = .loading
        }

        do {
            // Both fetches run in parallel through `async let`: the
            // repository protocols are `Sendable` (§4.2), so the child
            // tasks may carry them; the results are still published
            // together below.
            async let fetchedCards = cardRepository.getCards()
            async let fetchedOffers = offersRepository.getAvailableOffers()
            let (cards, offers) = try await (fetchedCards, fetchedOffers)
            self.cards = cards
            offeredCards = offers
            syncSubscriptions(to: cards)
            viewState = cards.isEmpty && offers.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            // The triggering view task was cancelled (screen disappeared
            // mid-load); keep whatever state was showing — the next appear
            // refires load().
        } catch let error as AppError {
            guard !hasContent else { return } // refresh failed behind content
            viewState = .error(error)
        } catch {
            guard !hasContent else { return }
            viewState = .error(.unknown(underlying: error))
        }
    }

    // MARK: - Adding an offer (architecture.md §4.4: one model method over

    // one repository — `CardRepositoryProtocol.addCard`)

    /// Turns an accepted offer into a managed card: the repository creates
    /// the card (the duplicate rule's owner — it throws
    /// `AppError.cardAlreadyExists` for an offer that is already managed),
    /// then the model appends it to `cards`, starts its live status
    /// subscription, and drops the offer from the catalog. A second tap
    /// while an add is in flight is a no-op; the offers row disables itself
    /// on the same in-flight signal and for offers already in `cards`.
    public func addOffer(_ offer: CardOffer) async {
        guard !offersBeingAdded.contains(offer.id) else { return }
        guard offeredCards.contains(where: { $0.id == offer.id }) else { return }

        offersBeingAdded.insert(offer.id)
        addOfferError = nil
        defer { offersBeingAdded.remove(offer.id) }

        do {
            let card = try await cardRepository.addCard(offer)
            cards.append(card)
            offeredCards.removeAll { $0.id == offer.id }
            syncSubscriptions(to: cards)
            lastAddedCardID = card.id
        } catch is CancellationError {
            // The triggering view task was cancelled mid-add; nothing
            // changed, and the next tap simply tries again.
        } catch let error as AppError {
            addOfferError = error
        } catch {
            addOfferError = .unknown(underlying: error)
        }
    }

    /// Clears the surfaced add-offer error (alert dismissal).
    public func dismissAddOfferError() {
        addOfferError = nil
    }

    // MARK: - Live subscriptions

    /// Reconciles the per-card subscription tasks with the current card
    /// list: cancels tasks for cards that left the list and starts one for
    /// each card that does not have one yet (§9.1).
    private func syncSubscriptions(to cards: [Card]) {
        let managedCardIDs = Set(cards.map(\.id))

        let removedCardIDs = subscriptionTasks.tasks.keys.filter { !managedCardIDs.contains($0) }
        for cardID in removedCardIDs {
            subscriptionTasks.tasks[cardID]?.cancel()
            subscriptionTasks.tasks.removeValue(forKey: cardID)
        }
        cardStates = cardStates.filter { managedCardIDs.contains($0.key) }

        for card in cards where subscriptionTasks.tasks[card.id] == nil {
            startLiveSubscription(for: card)
        }
    }

    /// Subscribes one card to its status channel. The subscription task is
    /// held weakly against the model: it writes through `apply` while the
    /// model lives and ends when the model (or the card's task) is
    /// cancelled — a subscription that cannot be set up is dropped silently
    /// so one bad channel never takes the dashboard down (§9.1 sketch).
    private func startLiveSubscription(for card: Card) {
        let cardID = card.id
        let task = Task { @MainActor [weak self] in
            guard let stream = try? await self?.statusRepository
                .subscribeToCardStatus(cardId: cardID)
            else { return }
            for await state in stream {
                guard !Task.isCancelled else { break }
                self?.apply(state)
            }
        }
        subscriptionTasks.tasks[card.id] = task
    }

    /// Records one live `CardState`: updates the raw state ledger and the
    /// matching card's effective status so the UI stays current without a
    /// reload (§9.1: subscriptions write straight into observable state).
    private func apply(_ state: CardState) {
        cardStates[state.cardId] = state
        guard let index = cards.firstIndex(where: { $0.id == state.cardId }) else { return }
        cards[index] = cards[index].withStatus(state.status)
    }
}

/// Owns the per-card subscription tasks so they can be cancelled when the
/// model goes away (§9.1: models own and cancel their subscription tasks).
///
/// Deliberately nonisolated: a `deinit` cannot touch a main-actor-isolated
/// property, so the cancellation lives here, in the store's own `deinit`,
/// which runs when the model releases it. The store is private to the
/// model and never shared — the model mutates it only on the main actor,
/// and the store's deinit is the single access from elsewhere.
private final class SubscriptionTaskStore {
    var tasks: [String: Task<Void, Never>] = [:]

    deinit {
        for task in tasks.values {
            task.cancel()
        }
    }
}
