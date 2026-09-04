import Design
import Entities
import SharedUI
import SwiftUI

/// The card detail screen (architecture.md §9.3, tasks.md Day 12).
///
/// A thin switch over the model's `viewState`: loading and error surfaces
/// come from SharedUI and the loaded screen delegates to
/// `CardDetailContentView`. The model comes from the environment — the
/// composition root injects it (§11.3), it is never created in a view —
/// and one-shot work is view-triggered: `.task` fires `load()` on every
/// appear (idempotent once the card is on screen).
public struct CardDetailView: View {
    @Environment(CardDetailModel.self) private var model

    public init() {}

    public var body: some View {
        content
            .navigationTitle(
                model.card.map { Strings.CardDetail.title(lastFour: $0.lastFourDigits) }
                    ?? Strings.App.title,
            )
            .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            LoadingView(message: Strings.CardDetail.loadingMessage)
        case let .error(error):
            ErrorView(error: error) {
                Task { await model.load() }
            }
        case .loaded:
            CardDetailContentView(model: model)
        }
    }
}

/// The loaded card detail (tasks.md Day 12): the card front with its live
/// status, the card-control actions (freeze/unfreeze, report lost or
/// stolen, request replacement) and the per-period spending-limit rows —
/// each section a list of actions that mutate the model. Confirmation
/// dialogs and the action-error alert live here, driven by view-local
/// state; haptics ride the model's success/failure signals.
private struct CardDetailContentView: View {
    private let model: CardDetailModel

    init(model: CardDetailModel) {
        self.model = model
    }

    @State private var confirmAction: ConfirmAction?
    @State private var limitDraft: LimitDraft?
    @State private var showReportDialog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section1) {
                if let card = model.card {
                    header(for: card)
                    controlsSection(for: card)
                    if model.replacementRequested {
                        InfoRow(
                            title: Strings.CardDetail.replacementRequestedTitle,
                            message: Strings.CardDetail.replacementRequestedMessage,
                        )
                        .padding(.horizontal, Spacing.lg)
                    }
                    limitsSection(for: card)
                }
            }
            .padding(.vertical, Spacing.xl)
            // Dialog and item-alert live on this content node; the
            // error alert and sheet on the scroll view — two alerts on the
            // same node can shadow each other, separate nodes cannot.
            .confirmationDialog(
                Strings.CardDetail.reportConfirmTitle,
                isPresented: $showReportDialog,
                titleVisibility: .visible,
            ) {
                Button(Strings.CardDetail.reportLost, role: .destructive) {
                    Task { await model.reportLost() }
                }
                Button(Strings.CardDetail.reportStolen, role: .destructive) {
                    Task { await model.reportStolen() }
                }
                Button(Strings.Common.cancel, role: .cancel) {}
            } message: {
                Text(Strings.CardDetail.reportConfirmMessage)
            }
            .alert(item: $confirmAction) { action in
                confirmAlert(for: action)
            }
        }
        .accessibilityIdentifier(CardDetailAccessibility.screen)
        .sensoryFeedback(.success, trigger: model.lastActionSequence)
        .sensoryFeedback(.error, trigger: model.actionError) { _, newValue in
            newValue != nil
        }
        .alert(
            Strings.CardDetail.actionFailedTitle,
            isPresented: actionErrorPresented,
            presenting: model.actionError,
        ) { _ in
            Button(Strings.Common.ok) {
                model.dismissActionError()
            }
        } message: { error in
            Text(alertMessage(for: error))
        }
        .sheet(item: $limitDraft) { draft in
            LimitSetterSheet(
                period: draft.period,
                currency: model.card?.currency ?? "",
                currentLimit: model.limit(for: draft.period)?.amount,
            ) { amount in
                limitDraft = nil
                Task { await model.setSpendingLimit(period: draft.period, amount: amount) }
            }
        }
    }

    // MARK: - Card header

    private func header(for card: Card) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DetailCardFront(card: card)
                .padding(.horizontal, Spacing.lg)
            StatusLine(status: card.status)
                .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Controls

    private func controlsSection(for card: Card) -> some View {
        section(Strings.CardDetail.controlsSection) {
            if card.status == .active || card.status == .frozen {
                primaryControl(for: card)
            }
            if model.canReportIssue {
                DestructiveButton(
                    title: Strings.CardDetail.reportLostOrStolen,
                    action: { showReportDialog = true },
                )
                .disabled(model.isExecuting)
                .accessibilityIdentifier(CardDetailAccessibility.reportLostOrStolen)
            } else if card.status == .lost {
                lostCardContent(for: card)
            }
        }
    }

    @ViewBuilder
    private func primaryControl(for card: Card) -> some View {
        switch card.status {
        case .active:
            ActionButton(
                title: Strings.CardDetail.freeze,
                systemImage: Icons.card,
                identifier: CardDetailAccessibility.freeze,
                isPending: model.pendingAction == .freeze,
                disabled: model.isExecuting,
            ) {
                confirmAction = .freeze
            }
        case .frozen:
            ActionButton(
                title: Strings.CardDetail.unfreeze,
                systemImage: "snowflake",
                identifier: CardDetailAccessibility.unfreeze,
                isPending: model.pendingAction == .unfreeze,
                disabled: model.isExecuting,
            ) {
                confirmAction = .unfreeze
            }
        default:
            EmptyView()
        }
    }

    private func lostCardContent(for _: Card) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            InfoRow(
                title: Strings.CardDetail.lostCardTitle,
                message: Strings.CardDetail.lostCardMessage,
            )
            if model.canRequestReplacement {
                ActionButton(
                    title: Strings.CardDetail.requestReplacement,
                    systemImage: Icons.add,
                    identifier: CardDetailAccessibility.requestReplacement,
                    isPending: model.pendingAction == .requestReplacement,
                    disabled: model.isExecuting,
                ) {
                    confirmAction = .requestReplacement
                }
            }
        }
    }

    // MARK: - Spending limits

    private func limitsSection(for card: Card) -> some View {
        section(Strings.CardDetail.limitsSection) {
            currentLimitRow(for: card)
            ForEach(SpendingLimitPeriod.allCases, id: \.self) { period in
                limitRow(for: period)
            }
        }
    }

    private func currentLimitRow(for card: Card) -> some View {
        HStack {
            Text(Strings.CardDetail.currentLimit)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ColorPalette.label)
            Spacer()
            Text(formattedLimit(card.spendingLimit, currency: card.currency))
                .font(.subheadline)
                .foregroundStyle(ColorPalette.secondaryLabel)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private func limitRow(for period: SpendingLimitPeriod) -> some View {
        Button {
            limitDraft = LimitDraft(period: period)
        } label: {
            HStack {
                Text(period.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ColorPalette.label)
                Spacer()
                Text(formattedLimit(model.limit(for: period)?.amount, currency: model.card?.currency ?? ""))
                    .font(.subheadline)
                    .foregroundStyle(ColorPalette.secondaryLabel)
                Image(systemName: Icons.chevronRight)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ColorPalette.secondaryLabel)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!model.canChangeLimits || model.isExecuting)
        .accessibilityIdentifier(CardDetailAccessibility.limitRow(period))
    }

    private func formattedLimit(_ amount: Decimal?, currency: String) -> String {
        guard let amount else {
            return Strings.CardDetail.notSet
        }
        return amount.formatted(.currency(code: currency))
    }

    // MARK: - Confirmations

    private func confirmAlert(for action: ConfirmAction) -> Alert {
        switch action {
        case .freeze:
            Alert(
                title: Text(Strings.CardDetail.freezeConfirmTitle),
                message: Text(Strings.CardDetail.freezeConfirmMessage),
                primaryButton: .default(Text(Strings.CardDetail.freeze)) {
                    Task { await model.freeze() }
                },
                secondaryButton: .cancel(),
            )
        case .unfreeze:
            Alert(
                title: Text(Strings.CardDetail.unfreezeConfirmTitle),
                message: Text(Strings.CardDetail.unfreezeConfirmMessage),
                primaryButton: .default(Text(Strings.CardDetail.unfreeze)) {
                    Task { await model.unfreeze() }
                },
                secondaryButton: .cancel(),
            )
        case .requestReplacement:
            Alert(
                title: Text(Strings.CardDetail.requestReplacementConfirmTitle),
                message: Text(Strings.CardDetail.requestReplacementConfirmMessage),
                primaryButton: .default(Text(Strings.CardDetail.requestReplacement)) {
                    Task { await model.requestReplacement() }
                },
                secondaryButton: .cancel(),
            )
        }
    }

    // MARK: - Error alert

    private var actionErrorPresented: Binding<Bool> {
        Binding(
            get: { model.actionError != nil },
            set: { presented in
                if !presented {
                    model.dismissActionError()
                }
            },
        )
    }

    /// Alert copy reuses the `AppError` surfaces: the headline first, the
    /// recovery guidance below (ErrorView order, §5).
    private func alertMessage(for error: AppError) -> String {
        var parts: [String] = []
        if let description = error.errorDescription {
            parts.append(description)
        }
        if let suggestion = error.recoverySuggestion {
            parts.append(suggestion)
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Layout helpers

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(ColorPalette.label)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Spacing.lg)
            content()
        }
    }
}

/// A card-control action button with an in-flight spinner. The model
/// disables every control while one action runs (`isExecuting`), so only
/// the pending action's own button shows the spinner.
private struct ActionButton: View {
    private let title: String
    private let systemImage: String
    private let identifier: String
    private let isPending: Bool
    private let disabled: Bool
    private let action: () -> Void

    init(
        title: String,
        systemImage: String,
        identifier: String,
        isPending: Bool,
        disabled: Bool,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.systemImage = systemImage
        self.identifier = identifier
        self.isPending = isPending
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isPending {
                    ProgressView()
                        .tint(ColorPalette.label)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(disabled)
        .accessibilityIdentifier(identifier)
    }
}

/// The status announcement line below the card front — one VoiceOver
/// element whose label names the status (UI tests assert the freeze round
/// trip against `CardDetailAccessibility.status`).
private struct StatusLine: View {
    private let status: CardStatus

    init(status: CardStatus) {
        self.status = status
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: status.icon)
                .accessibilityHidden(true)
            Text(status.displayName)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(ColorPalette.label)
        .padding(.horizontal, Spacing.sm + 2)
        .padding(.vertical, Spacing.xs)
        .background(ColorPalette.separator.opacity(0.6), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(status.displayName)")
        .accessibilityIdentifier(CardDetailAccessibility.status)
    }
}

/// A compact physical-card front for the detail header, sharing the art
/// vocabulary (`CardArtwork`) with the dashboard carousel (architecture.md
/// §9.4). Only display-safe data is drawn: the last four digits, never a
/// PAN.
private struct DetailCardFront: View {
    private let card: Card

    init(card: Card) {
        self.card = card
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(Strings.App.title)
                    .font(.headline.weight(.bold))
                    .tracking(1.2)
                Spacer()
                Image(systemName: card.type.icon)
                    .font(.subheadline.weight(.semibold))
                    .padding(Spacing.xs + 2)
                    .background(CardArtwork.foreground.opacity(0.18), in: Circle())
            }
            Spacer(minLength: Spacing.md)
            Text(maskedNumber)
                .font(.title.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: Spacing.md)
            if !card.cardholderName.isEmpty {
                Text(card.cardholderName)
                    .font(.footnote.weight(.medium))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(Spacing.lg)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(maxWidth: .infinity)
        .aspectRatio(1.586, contentMode: .fit)
        .foregroundStyle(CardArtwork.foreground)
        .background(
            CardArtwork.gradient(for: card.type),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous),
        )
        .accessibilityHidden(true)
    }

    private var maskedNumber: String {
        card.lastFourDigits.isEmpty
            ? card.type.displayName.uppercased()
            : "•••• \(card.lastFourDigits)"
    }
}

/// The per-period set-limit sheet: an amount field in the card's currency.
/// Saving is disabled until the amount parses to a positive `Decimal`.
private struct LimitSetterSheet: View {
    private let period: SpendingLimitPeriod
    private let currency: String
    private let currentLimit: Decimal?
    private let onSave: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""

    init(
        period: SpendingLimitPeriod,
        currency: String,
        currentLimit: Decimal?,
        onSave: @escaping (Decimal) -> Void,
    ) {
        self.period = period
        self.currency = currency
        self.currentLimit = currentLimit
        self.onSave = onSave
    }

    private var parsedAmount: Decimal? {
        let value = Decimal(string: amountText, locale: .current)
        guard let value, value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(Strings.CardDetail.amountPlaceholder, text: $amountText)
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                } header: {
                    Text(Strings.CardDetail.setLimitTitle(period: period.displayName))
                } footer: {
                    if let currentLimit {
                        Text(formatted(currentLimit))
                    }
                }
            }
            .navigationTitle(Strings.CardDetail.setLimitTitle(period: period.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.Common.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.CardDetail.save) {
                        guard let amount = parsedAmount else { return }
                        onSave(amount)
                    }
                    .disabled(parsedAmount == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatted(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currency))
    }
}

private enum ConfirmAction: Hashable, Identifiable {
    case freeze
    case unfreeze
    case requestReplacement

    var id: Self {
        self
    }
}

private struct LimitDraft: Identifiable {
    let period: SpendingLimitPeriod
    var id: SpendingLimitPeriod {
        period
    }
}

#if DEBUG
    #Preview("Active card") {
        CardDetailView()
            .environment(CardDetailModel.preview(cardID: Card.mockCreditCard.id))
    }

    #Preview("Frozen card") {
        CardDetailView()
            .environment(CardDetailModel.preview(cardID: Card.mockFrozenCard.id))
    }

    #Preview("Lost card — replacement available") {
        CardDetailView()
            .environment(CardDetailModel.preview(cardID: Card.mockLostCard.id))
    }

    #Preview("Loading") {
        CardDetailView()
            .environment(CardDetailModel.loadingPreview(cardID: Card.mockCreditCard.id))
    }

    #Preview("Error") {
        CardDetailView()
            .environment(CardDetailModel.errorPreview(cardID: Card.mockCreditCard.id))
    }
#endif
