import Design
import Entities
import SharedUI
import SwiftUI

#if DEBUG
    import Mocks
#endif

/// The offers row on the loaded dashboard (architecture.md §9.3, §4.4
/// example; tasks.md Day 11).
///
/// A horizontal scroll of offer cards. Each card shows the offer's type as
/// art and its marketing copy, with an explicit add action that runs
/// `DashboardModel.addOffer` — the offer becomes a managed card through
/// `CardRepositoryProtocol.addCard` (architecture.md §4.4: one model
/// method over one repository) and disappears from the catalog.
///
/// Row states mirror the model's signals:
/// - offer already managed (its id is in `cards`) → an "Added" checkmark,
///   no button — the catalog can list an offer that is already a card
///   after a refresh, and the repository is the duplicate rule's owner;
/// - add in flight → the button shows a spinner and is disabled
///   (the model refuses a second add of the same offer anyway);
/// - otherwise the "Add" button, whose VoiceOver label names the offer.
struct OffersSectionView: View {
    private let model: DashboardModel

    init(model: DashboardModel) {
        self.model = model
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: Spacing.md) {
                ForEach(model.offeredCards) { offer in
                    OfferCardView(model: model, offer: offer)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xs)
        }
    }
}

/// One offer in the row: type art header, marketing copy, add action.
private struct OfferCardView: View {
    /// Corner radius of the card and its art header; they share the shape so
    /// the header gradient matches the card's corners.
    private static let cornerRadius: CGFloat = 16

    private let model: DashboardModel
    private let offer: CardOffer

    @ScaledMetric(relativeTo: .headline) private var artHeight: CGFloat = 64

    init(model: DashboardModel, offer: CardOffer) {
        self.model = model
        self.offer = offer
    }

    private var isManaged: Bool {
        model.cards.contains { $0.id == offer.id }
    }

    private var isAdding: Bool {
        model.offersBeingAdded.contains(offer.id)
    }

    private var addButton: some View {
        Button {
            Task { await model.addOffer(offer) }
        } label: {
            Label(Strings.Common.add, systemImage: Icons.add)
                .frame(maxWidth: .infinity)
                // The spinner replaces the label while an add is in flight
                // (never layered over it); .disabled(isAdding) blocks a
                // redundant second tap.
                .opacity(isAdding ? 0 : 1)
                .overlay {
                    if isAdding {
                        ProgressView()
                            .controlSize(.small)
                            .tint(ColorPalette.brand)
                    }
                }
        }
        .buttonStyle(.borderedProminent)
        .tint(ColorPalette.brand)
        .disabled(isAdding)
        .accessibilityLabel(Strings.Dashboard.addOffer(offer.title))
        .accessibilityIdentifier(DashboardAccessibility.addOffer(offer.id))
    }

    /// A geometry-only copy of `addButton`: invisible and out of VoiceOver,
    /// but it keeps the exact button layout so a managed card reserves the
    /// same slot as an addable one.
    private var placeholderAddButton: some View {
        addButton
            .hidden()
            .accessibilityHidden(true)
            .disabled(true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ZStack {
                CardArtwork.gradient(for: offer.type)
                Label(offer.type.displayName, systemImage: offer.type.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CardArtwork.foreground)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: artHeight)
            .frame(maxWidth: .infinity)
            // `CardArtwork.gradient` is a plain fill — the rounded corners
            // come from this shape, matching the card's own radius.
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(offer.title)
                    .font(.headline)
                    .foregroundStyle(ColorPalette.label)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                // The subtitle block always reserves two caption lines: a
                // hidden, accessibility-deaf placeholder sizes it, so every
                // card is the same height whether the subtitle wraps once or
                // twice.
                ZStack(alignment: .topLeading) {
                    Text(" ")
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .accessibilityHidden(true)
                    Text(offer.subtitle)
                        .font(.caption)
                        .foregroundStyle(ColorPalette.secondaryLabel)
                        .lineLimit(2)
                }
            }

            if isManaged {
                // A hidden copy of the Add button reserves identical
                // geometry, so a managed card keeps the addable card's height
                // — the "Added" label fills the same slot.
                ZStack {
                    placeholderAddButton
                    Label(Strings.Common.added, systemImage: Icons.added)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ColorPalette.success)
                        .accessibilityLabel(Strings.Dashboard.addOffer(offer.title))
                        .accessibilityIdentifier(DashboardAccessibility.addedOffer(offer.id))
                }
            } else {
                addButton
            }
        }
        .padding(Spacing.md)
        .frame(width: 248, alignment: .leading)
        .background(
            ColorPalette.secondaryBackground,
            in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous),
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(DashboardAccessibility.offer(offer.id))
    }
}

#if DEBUG
    /// Loads the section's model before showing it. `DashboardView` owns the
    /// `load()` call in its `.task` (architecture.md §9.1); a section preview
    /// has no such parent, so without this `offeredCards` stays empty and the
    /// row renders nothing.
    private struct OffersSectionPreview: View {
        private let model: DashboardModel

        init(model: DashboardModel) {
            self.model = model
        }

        var body: some View {
            OffersSectionView(model: model)
                .background(ColorPalette.background)
                .task { await model.load() }
        }
    }

    #Preview("Offers — addable") {
        OffersSectionPreview(model: DashboardModel.preview())
    }

    #Preview("Offers — added state") {
        // Seeds a model whose card list already contains the offer's id, so
        // the row renders the "Added" state (out-of-sync catalog case).
        let alreadyManagedCard = Card(
            id: CardOffer.mockCashbackOffer.id,
            cardholderName: "",
            lastFourDigits: "",
            type: CardOffer.mockCashbackOffer.type,
            status: .active,
            currency: "EUR",
            spendingLimit: nil,
        )
        let cardRepository = MockCardRepository(seed: [alreadyManagedCard] + Card.mockDefaults)
        let model = DashboardModel(
            cardRepository: cardRepository,
            offersRepository: MockOffersRepository(seed: CardOffer.mockDefaults),
            statusRepository: MockStatusRepository(seed: CardState.mockDefaults),
        )
        return OffersSectionPreview(model: model)
    }

    #Preview("Offers — dark") {
        OffersSectionPreview(model: DashboardModel.preview())
            .preferredColorScheme(.dark)
    }
#endif
