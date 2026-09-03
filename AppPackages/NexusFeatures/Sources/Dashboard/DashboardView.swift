import Design
import Entities
import SharedUI
import SwiftUI

/// The dashboard screen (architecture.md §9.3, tasks.md Day 10).
///
/// A thin switch over the model's `viewState`: the loading / error / empty
/// surfaces come from SharedUI components and the loaded screen delegates
/// to `DashboardContentView`. The model comes from the environment — the
/// composition root injects it (§11.3), it is never created in a view — and
/// one-shot work is view-triggered: `.task` fires `load()` on every appear
/// (idempotent once content is on screen) and `.refreshable` forces
/// `refresh()`.
public struct DashboardView: View {
    @Environment(DashboardModel.self) private var model

    public init() {}

    public var body: some View {
        content
            .task { await model.load() }
            .refreshable { await model.refresh() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            LoadingView(message: Strings.Dashboard.loadingMessage)
        case .empty:
            EmptyStateView(
                systemImage: Icons.card,
                title: Strings.Dashboard.emptyTitle,
                message: Strings.Dashboard.emptyMessage,
                actionTitle: Strings.Common.refresh,
                action: { Task { await model.refresh() } },
            )
        case let .error(error):
            ErrorView(error: error) {
                Task { await model.load() }
            }
        case .loaded:
            DashboardContentView(model: model)
        }
    }
}

/// The Day 10 loaded dashboard: cards and offers as grouped rows in a
/// scroll view. This is the minimal placeholder content that Day 11 (M4)
/// restyles into the swipeable card carousel and offers row; the model
/// contract it renders — `cards`, `offeredCards`, and effective card status
/// folded in from live `CardState` updates — is final.
private struct DashboardContentView: View {
    private let model: DashboardModel

    init(model: DashboardModel) {
        self.model = model
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section1) {
                if !model.cards.isEmpty {
                    DashboardSection(title: Strings.Dashboard.cardsSection) {
                        ForEach(model.cards) { card in
                            CardRow(card: card)
                                .overlay(alignment: .bottom) { Divider() }
                        }
                    }
                }
                if !model.offeredCards.isEmpty {
                    DashboardSection(title: Strings.Dashboard.offersSection) {
                        ForEach(model.offeredCards) { offer in
                            OfferRow(offer: offer)
                                .overlay(alignment: .bottom) { Divider() }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }
}

/// Titled, rounded group of rows (dashboard content scaffolding).
private struct DashboardSection<Content: View>: View {
    private let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(ColorPalette.label)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                content
            }
            .background(
                ColorPalette.secondaryBackground,
                in: RoundedRectangle(cornerRadius: 12),
            )
        }
    }
}

/// One managed card row: type icon, masked number, holder, live status.
private struct CardRow: View {
    private let card: Card

    init(card: Card) {
        self.card = card
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: card.type.icon)
                .font(.title3)
                .foregroundStyle(ColorPalette.brand)
                .frame(width: Spacing.xl)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(maskedNumber)
                    .font(.body.weight(.medium))
                    .foregroundStyle(ColorPalette.label)
                Text(card.cardholderName)
                    .font(.caption)
                    .foregroundStyle(ColorPalette.secondaryLabel)
            }
            Spacer(minLength: Spacing.md)
            StatusBadge(status: card.status)
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Only the display-safe tail is shown; a provisioned card with no
    /// number yet (Day 7, empty last-four) falls back to its type name.
    private var maskedNumber: String {
        card.lastFourDigits.isEmpty ? card.type.displayName : "•••• \(card.lastFourDigits)"
    }

    private var accessibilityLabel: String {
        card.lastFourDigits.isEmpty
            ? "\(card.type.displayName) card, \(card.status.displayName)"
            : "Card ending in \(card.lastFourDigits), \(card.status.displayName)"
    }
}

/// One offer row: type icon, marketing title and subtitle. The add-offer
/// action lands with the Day 11 offers row.
private struct OfferRow: View {
    private let offer: CardOffer

    init(offer: CardOffer) {
        self.offer = offer
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: offer.type.icon)
                .font(.title3)
                .foregroundStyle(ColorPalette.brand)
                .frame(width: Spacing.xl)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(offer.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(ColorPalette.label)
                Text(offer.subtitle)
                    .font(.caption)
                    .foregroundStyle(ColorPalette.secondaryLabel)
            }
            Spacer(minLength: Spacing.md)
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .combine)
    }
}

/// Small colored pill showing a card's lifecycle status.
private struct StatusBadge: View {
    private let status: CardStatus

    init(status: CardStatus) {
        self.status = status
    }

    var body: some View {
        Label(status.displayName, systemImage: status.icon)
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityHidden(true) // the row already reads the status
    }

    private var tint: Color {
        switch status {
        case .active: ColorPalette.success
        case .frozen: ColorPalette.warning
        case .expired, .lost: ColorPalette.destructive
        }
    }
}

#if DEBUG
    #Preview("Loaded") {
        DashboardView()
            .environment(DashboardModel.preview())
    }

    #Preview("Empty") {
        DashboardView()
            .environment(DashboardModel.emptyPreview())
    }

    #Preview("Loading") {
        DashboardView()
            .environment(DashboardModel.loadingPreview())
    }

    #Preview("Error") {
        DashboardView()
            .environment(DashboardModel.errorPreview())
    }
#endif
