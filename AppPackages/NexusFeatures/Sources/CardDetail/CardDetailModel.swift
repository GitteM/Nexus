import Entities
import Foundation
import Observation
import RepositoryProtocols

/// Owns the card detail screen's state and its card's live data
/// (architecture.md §9.1, tasks.md Day 12).
///
/// The "M" of MV for one managed card: it loads the card through the card
/// repository (there is no get-by-id on the boundary — the model fetches
/// the list and picks its card, appspec §2.2), subscribes to that card's
/// live status channel, and executes the card-control commands (freeze /
/// unfreeze / report lost / report stolen / request replacement /
/// set spending limit) through the action repository. It carries no view
/// logic — views switch on `viewState` (§9.3) and trigger one-shot work
/// through `.task`; the model never spawns one-shot tasks itself.
///
/// Action semantics (settled at M5, appspec §2.2):
/// - *Validity* is checked in the model: `freeze` only when `active`,
///   `unfreeze` only when `frozen`, lost/stolen reporting only when the
///   card is neither `expired` nor already `lost`, replacement only after
///   the card is `lost` (and only once), spending-limit changes only for a
///   working card (`active`/`frozen`) and a positive amount. An invalid
///   transition is a silent no-op — the UI never offers it, so nothing is
///   sent.
/// - *In-flight* state is bounded to the `execute` call (`pendingAction`).
///   On success the model applies the resulting status immediately (the
///   repository-store rule: the action is visible right away) and the live
///   subscription reconciles when the stream confirms it; on failure the
///   card is unchanged and the error surfaces as a transient
///   `actionError` — the screen's `viewState` stays `.loaded`.
/// - *Confirmation* arrives through `CardStatusRepositoryProtocol`
///   subscriptions (architecture.md §11.4); demo/test wiring plays the
///   backend echo (`MockCommandCoordinator`). The status ledger and the
///   card's effective status update together and idempotently, so an
///   optimistic apply followed by the stream frame causes no flicker.
@MainActor
@Observable
public final class CardDetailModel {
    /// The explicit screen state — `.loaded` once the card is on screen.
    public private(set) var viewState: CardDetailViewState = .loading

    /// The managed card, with its effective lifecycle status folded in from
    /// live `CardState` updates and optimistic action results.
    public private(set) var card: Card?

    /// The latest live status frame for the card, from the subscription.
    public private(set) var cardState: CardState?

    /// Per-period spending limits set in this session (appspec §2.2: the
    /// wire has no limit-read contract yet, so the model keeps the ledger
    /// it writes and the demo store mirrors the card-level amount).
    public private(set) var spendingLimits: [SpendingLimit] = []

    /// The command currently executing, or `nil` when idle. Views disable
    /// every control while it is set (one card action at a time).
    public private(set) var pendingAction: CardCommandType?

    /// True once a replacement has been requested for this card (the old
    /// card stays `lost`; the replacement offer arrives on the dashboard).
    public private(set) var replacementRequested = false

    /// The last action failure, or `nil` when the last action succeeded (or
    /// none ran). Views surface it in an alert and call
    /// `dismissActionError()`; `viewState` is untouched so a failed action
    /// never blanks loaded content.
    public private(set) var actionError: AppError?

    /// Increments on every successfully completed action — the success
    /// signal views use for haptics (`.sensoryFeedback` trigger).
    public private(set) var lastActionSequence = 0

    private let cardID: String
    private let cardRepository: CardRepositoryProtocol
    private let statusRepository: CardStatusRepositoryProtocol
    private let actionRepository: CardActionRepositoryProtocol

    private let subscriptionBox = CardDetailSubscriptionBox()
    private var isLoadInFlight = false

    public init(
        cardID: String,
        cardRepository: CardRepositoryProtocol,
        statusRepository: CardStatusRepositoryProtocol,
        actionRepository: CardActionRepositoryProtocol,
    ) {
        self.cardID = cardID
        self.cardRepository = cardRepository
        self.statusRepository = statusRepository
        self.actionRepository = actionRepository
    }

    // MARK: - View-facing conveniences

    /// True while a card command is being sent.
    public var isExecuting: Bool {
        pendingAction != nil
    }

    public var canFreeze: Bool {
        card?.status == .active
    }

    public var canUnfreeze: Bool {
        card?.status == .frozen
    }

    public var canReportIssue: Bool {
        guard let status = card?.status else { return false }
        return status != .expired && status != .lost
    }

    public var canRequestReplacement: Bool {
        card?.status == .lost && !replacementRequested
    }

    public var canChangeLimits: Bool {
        guard let status = card?.status else { return false }
        return status == .active || status == .frozen
    }

    /// The per-period limit set this session, or `nil` when none is set.
    public func limit(for period: SpendingLimitPeriod) -> SpendingLimit? {
        spendingLimits.first { $0.period == period }
    }

    // MARK: - Load

    /// Idempotent initial load — safe to refire on every appear; once the
    /// card is on screen it is a no-op, and from `.error` it retries. The
    /// card comes from the managed-card list (no get-by-id boundary), then
    /// the live status subscription starts.
    public func load() async {
        guard !isLoadInFlight, viewState != .loaded else { return }
        isLoadInFlight = true
        defer { isLoadInFlight = false }
        viewState = .loading
        do {
            let cards = try await cardRepository.getCards()
            guard let fetched = cards.first(where: { $0.id == cardID }) else {
                viewState = .error(.cardNotFound(cardId: cardID))
                return
            }
            card = fetched
            startStatusSubscription()
            viewState = .loaded
        } catch is CancellationError {
            // The triggering view task was cancelled (screen disappeared
            // mid-load); keep whatever state was showing — the next appear
            // refires load().
        } catch let error as AppError {
            viewState = .error(error)
        } catch {
            viewState = .error(.unknown(underlying: error))
        }
    }

    // MARK: - Card controls

    /// Freezes the card (transition: `active` → `frozen`).
    public func freeze() async {
        await performStatusTransition(.freeze, allowed: canFreeze, resultingStatus: .frozen)
    }

    /// Unfreezes the card (transition: `frozen` → `active`).
    public func unfreeze() async {
        await performStatusTransition(.unfreeze, allowed: canUnfreeze, resultingStatus: .active)
    }

    /// Reports the card as lost (transition → `lost`). The card is blocked
    /// immediately; a replacement can be requested next.
    public func reportLost() async {
        await performStatusTransition(.reportLost, allowed: canReportIssue, resultingStatus: .lost)
    }

    /// Reports the card as stolen (transition → `lost`; the `reportStolen`
    /// command keeps the backend record distinct even though the domain has
    /// no separate `stolen` status, appspec §2.2).
    public func reportStolen() async {
        await performStatusTransition(.reportStolen, allowed: canReportIssue, resultingStatus: .lost)
    }

    /// Requests a replacement for a lost card (transition: `lost` →
    /// replacement requested, once). The old card stays `lost`; the
    /// replacement arrives as an offer on the dashboard (§4.4 add path).
    public func requestReplacement() async {
        guard canRequestReplacement, !isExecuting else { return }
        pendingAction = .requestReplacement
        actionError = nil
        defer { pendingAction = nil }
        do {
            try await actionRepository.execute(
                CardCommand(cardId: cardID, type: .requestReplacement),
            )
            replacementRequested = true
            lastActionSequence += 1
        } catch is CancellationError {
            // The triggering task was cancelled mid-request; nothing changed.
        } catch let error as AppError {
            actionError = error
        } catch {
            actionError = .unknown(underlying: error)
        }
    }

    /// Sets a per-period spending limit (only for a working card, only for
    /// a positive amount). On success the limit lands in the session ledger
    /// and the card-level current limit reflects it.
    public func setSpendingLimit(period: SpendingLimitPeriod, amount: Decimal) async {
        guard let card, canChangeLimits, amount > 0, !isExecuting else { return }
        pendingAction = .setSpendingLimit
        actionError = nil
        defer { pendingAction = nil }
        do {
            try await actionRepository.execute(
                CardCommand.setSpendingLimit(cardId: cardID, period: period, amount: amount),
            )
            spendingLimits.removeAll { $0.period == period }
            spendingLimits.append(
                SpendingLimit(
                    cardId: cardID,
                    period: period,
                    amount: amount,
                    currency: card.currency,
                ),
            )
            self.card = CardDetailModel.copy(card, spendingLimit: amount)
            lastActionSequence += 1
        } catch is CancellationError {
            // The triggering task was cancelled mid-save; nothing changed.
        } catch let error as AppError {
            actionError = error
        } catch {
            actionError = .unknown(underlying: error)
        }
    }

    /// Clears the surfaced action error (alert dismissal).
    public func dismissActionError() {
        actionError = nil
    }

    // MARK: - Transitions

    /// Runs one status transition: validates the current status, executes
    /// the command, and on success applies the resulting status
    /// optimistically (the stream confirmation reconciles idempotently).
    private func performStatusTransition(
        _ type: CardCommandType,
        allowed: Bool,
        resultingStatus: CardStatus,
    ) async {
        guard allowed, !isExecuting else { return }
        pendingAction = type
        actionError = nil
        defer { pendingAction = nil }
        do {
            try await actionRepository.execute(CardCommand(cardId: cardID, type: type))
            card = card?.withStatus(resultingStatus)
            lastActionSequence += 1
        } catch is CancellationError {
            // The triggering task was cancelled mid-action; nothing changed.
        } catch let error as AppError {
            actionError = error
        } catch {
            actionError = .unknown(underlying: error)
        }
    }

    // MARK: - Live status subscription

    /// Subscribes to the card's status channel; the stream yields the
    /// current state first, then updates. The task is held weakly against
    /// the model (via the subscription box) and ends when the model (or the
    /// task) is cancelled — a subscription that cannot be set up is dropped
    /// silently (§9.1).
    private func startStatusSubscription() {
        subscriptionBox.task?.cancel()
        // Locals, not implicit-self reads: the closure holds the model
        // weakly, so inside the optional-`self` chain it can only touch
        // captured values (the dashboard pattern passes a local card id in).
        let subscribedCardID = cardID
        let repository = statusRepository
        subscriptionBox.task = Task { @MainActor [weak self] in
            guard let stream = try? await repository
                .subscribeToCardStatus(cardId: subscribedCardID)
            else { return }
            for await state in stream {
                guard !Task.isCancelled else { break }
                self?.apply(state)
            }
        }
    }

    /// Records one live `CardState`: updates the raw status ledger and the
    /// card's effective status. Idempotent against the optimistic apply of
    /// the same status, so confirmation frames never flicker the UI (§9.1).
    private func apply(_ state: CardState) {
        cardState = state
        guard state.cardId == cardID else { return }
        card = card?.withStatus(state.status)
    }

    /// A copy of `card` with a new card-level current limit (the `Card`
    /// entity's single spending-limit slot; per-period values live in the
    /// model's ledger until the backend defines the wire read, §2.2).
    private static func copy(_ card: Card, spendingLimit: Decimal?) -> Card {
        Card(
            id: card.id,
            cardholderName: card.cardholderName,
            lastFourDigits: card.lastFourDigits,
            type: card.type,
            status: card.status,
            currency: card.currency,
            spendingLimit: spendingLimit,
        )
    }
}

/// Owns the card's subscription task so it can be cancelled when the model
/// goes away (§9.1: models own and cancel their subscription tasks).
///
/// Deliberately nonisolated: a `deinit` cannot touch a main-actor-isolated
/// property, so the cancellation lives here, in the box's own `deinit`,
/// which runs when the model releases it. The box is private to the model
/// and never shared.
private final class CardDetailSubscriptionBox {
    var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }
}
