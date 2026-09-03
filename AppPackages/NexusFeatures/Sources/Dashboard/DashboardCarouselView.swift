import Design
import Entities
import SharedUI
import SwiftUI

/// The swipeable card carousel on the loaded dashboard (architecture.md
/// §9.3, tasks.md Day 11).
///
/// A paged `TabView`: one `CardFrontView` per managed card, in repository
/// order (no reordering in v1.0), with custom page dots below the art. The
/// front reads the card's *effective* status, so live `CardState` updates
/// from the model's subscriptions repaint the status chip without a reload.
///
/// Accessibility (features.md §UX, tasks.md Day 11): each front is one
/// combined element — label "Credit card ending in 4821, Active", value
/// "Card 1 of 6" — with an adjustable action (VoiceOver swipe up/down) to
/// move between pages; the decorative dots are hidden from VoiceOver
/// because the pager itself already announces position.
struct DashboardCarouselView: View {
    private let cards: [Card]

    @State private var selection: String?
    /// Art height at the default text size. `@ScaledMetric` grows it with
    /// Dynamic Type so the card front (and its text) scales honestly
    /// instead of clipping; the default value keeps a physical-card aspect
    /// ratio on a standard-width screen (architecture.md §9.4).
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 216

    /// Page-dot metrics (points): the active dot is a wide capsule, the
    /// inactive dots small circles.
    private let pageDotSize: CGFloat = 7
    private let selectedPageDotWidth: CGFloat = 20

    init(cards: [Card]) {
        self.cards = cards
        _selection = State(initialValue: cards.first?.id)
    }

    private var selectedIndex: Int {
        cards.firstIndex { $0.id == selection } ?? 0
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            TabView(selection: $selection) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    CardFrontView(
                        card: card,
                        pageIndex: index,
                        pageCount: cards.count,
                        onSelectPage: selectPage,
                    )
                    .tag(card.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: cardHeight)

            if cards.count > 1 {
                pageDots
            }
        }
        .accessibilityIdentifier(DashboardAccessibility.carousel)
    }

    private var pageDots: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, _ in
                Capsule()
                    .fill(index == selectedIndex ? ColorPalette.brand : ColorPalette.separator)
                    .frame(
                        width: index == selectedIndex ? selectedPageDotWidth : pageDotSize,
                        height: pageDotSize,
                    )
                    .padding(.vertical, Spacing.xs)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy) {
                            selectPage(index)
                        }
                    }
            }
        }
        // Decorative: the pager's own VoiceOver semantics carry position.
        .accessibilityHidden(true)
    }

    private func selectPage(_ index: Int) {
        guard cards.indices.contains(index) else { return }
        withAnimation(.snappy) {
            selection = cards[index].id
        }
    }
}

/// The front of one managed card, drawn as card art (architecture.md §9.4,
/// tasks.md Day 11): a per-type gradient, brand wordmark, masked number
/// (display-safe: only the last four digits, never the PAN), cardholder,
/// and a status chip that reflects the card's current lifecycle status.
///
/// The front is a stylized physical card, so its art is fixed per
/// appearance while the screen around it adapts (features.md §UX).
private struct CardFrontView: View {
    private let card: Card
    private let pageIndex: Int
    private let pageCount: Int
    private let onSelectPage: (Int) -> Void

    init(card: Card, pageIndex: Int, pageCount: Int, onSelectPage: @escaping (Int) -> Void) {
        self.card = card
        self.pageIndex = pageIndex
        self.pageCount = pageCount
        self.onSelectPage = onSelectPage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text(Strings.App.title)
                    .font(.headline.weight(.bold))
                    .tracking(1.2)
                    .accessibilityHidden(true)
                Spacer(minLength: Spacing.md)
                Image(systemName: card.type.icon)
                    .font(.subheadline.weight(.semibold))
                    .padding(Spacing.xs + 2)
                    .background(CardArtwork.foreground.opacity(0.18), in: Circle())
                    .accessibilityHidden(true)
            }

            Spacer(minLength: Spacing.md)

            Text(maskedNumber)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: Spacing.md)

            HStack(alignment: .center, spacing: Spacing.md) {
                if !card.cardholderName.isEmpty {
                    Text(card.cardholderName)
                        .font(.footnote.weight(.medium))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: Spacing.sm)
                StatusChip(status: card.status)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(CardArtwork.foreground)
        .background(
            CardArtwork.gradient(for: card.type),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous),
        )
        .padding(.horizontal, Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(Strings.Dashboard.cardPage(pageIndex + 1, of: pageCount))
        .accessibilityAdjustableAction(adjust)
        .accessibilityIdentifier(DashboardAccessibility.card(card.id))
    }

    /// Display-safe number area: only the tail is shown, and a provisioned
    /// card with no number yet (Day 7 `addCard`) falls back to its type
    /// name — no PAN is ever fabricated.
    private var maskedNumber: String {
        card.lastFourDigits.isEmpty
            ? card.type.displayName.uppercased()
            : "•••• \(card.lastFourDigits)"
    }

    private var accessibilityLabel: String {
        let typeName = card.type.displayName
        if card.lastFourDigits.isEmpty {
            return "\(typeName) card, \(card.status.displayName)"
        }
        return "\(typeName) card ending in \(card.lastFourDigits), \(card.status.displayName)"
    }

    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment where pageIndex + 1 < pageCount:
            onSelectPage(pageIndex + 1)
        case .decrement where pageIndex > 0:
            onSelectPage(pageIndex - 1)
        default:
            break
        }
    }
}

/// The lifecycle pill drawn on the card art. Its meaning comes from the
/// domain icon plus the status name; the combined card front above already
/// reads the status through its explicit label, so the chip never surfaces
/// as a separate VoiceOver element.
private struct StatusChip: View {
    private let status: CardStatus

    init(status: CardStatus) {
        self.status = status
    }

    var body: some View {
        Label(status.displayName, systemImage: status.icon)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs)
            .background(CardArtwork.foreground.opacity(0.18), in: Capsule())
    }
}

#if DEBUG
    #Preview("Carousel — default cards") {
        VStack(alignment: .leading) {
            DashboardCarouselView(cards: Card.mockDefaults)
        }
        .background(ColorPalette.background)
    }

    #Preview("Carousel — dark") {
        VStack(alignment: .leading) {
            DashboardCarouselView(cards: Card.mockDefaults)
        }
        .background(ColorPalette.background)
        .preferredColorScheme(.dark)
    }

    #Preview("Carousel — large type") {
        VStack(alignment: .leading) {
            DashboardCarouselView(cards: Card.mockDefaults)
        }
        .background(ColorPalette.background)
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
#endif
