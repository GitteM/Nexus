import Design
import Entities
import Navigation
import SharedUI
import SwiftUI

/// The dashboard screen (architecture.md §9.3, tasks.md Day 10–11).
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
    @Environment(Router.self) private var router

    public init() {}

    public var body: some View {
        content
            .navigationTitle(Strings.Dashboard.title)
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
            DashboardContentView(model: model) { card in
                router.navigateTo(.cardDetail(cardID: card.id))
            }
        }
    }
}

/// The loaded dashboard (tasks.md Day 11): the swipeable card carousel and
/// the offers row, each under a section header, in one scroll view. This is
/// the content restyle of the Day 10 scaffold; the model contract it
/// renders — `cards`, `offeredCards`, and effective card status folded in
/// from live `CardState` updates — is unchanged.
///
/// The action surfaces live here: adding an offer is the dashboard's one
/// card action in M4, so success and failure haptics ride the model's
/// `lastAddedCardID` / `addOfferError` signals, and a failed add surfaces
/// the `AppError` in an alert without touching the loaded content
/// (features.md §UX, architecture.md §9.3).
private struct DashboardContentView: View {
    private let model: DashboardModel
    private let onSelectCard: (Card) -> Void

    init(model: DashboardModel, onSelectCard: @escaping (Card) -> Void) {
        self.model = model
        self.onSelectCard = onSelectCard
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section1) {
                if !model.cards.isEmpty {
                    section(Strings.Dashboard.cardsSection) {
                        DashboardCarouselView(cards: model.cards, onSelectCard: onSelectCard)
                    }
                }
                if !model.offeredCards.isEmpty {
                    section(Strings.Dashboard.offersSection) {
                        OffersSectionView(model: model)
                    }
                }
            }
            .padding(.vertical, Spacing.xl)
        }
        .sensoryFeedback(.success, trigger: model.lastAddedCardID)
        .sensoryFeedback(.error, trigger: model.addOfferError) { _, newValue in
            newValue != nil
        }
        .alert(
            Strings.Dashboard.addOfferFailedTitle,
            isPresented: addErrorPresented,
            presenting: model.addOfferError,
        ) { _ in
            Button(Strings.Common.ok) {
                model.dismissAddOfferError()
            }
        } message: { error in
            Text(alertMessage(for: error))
        }
    }

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

    /// The alert's dismissal clears the model's transient error so the next
    /// failure can present again (architecture.md §9.1: views mutate model
    /// state through model methods).
    private var addErrorPresented: Binding<Bool> {
        Binding(
            get: { model.addOfferError != nil },
            set: { presented in
                if !presented {
                    model.dismissAddOfferError()
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
}

#if DEBUG
    #Preview("Loaded") {
        DashboardView()
            .environment(DashboardModel.preview())
            .environment(Router())
    }

    #Preview("Empty") {
        DashboardView()
            .environment(DashboardModel.emptyPreview())
            .environment(Router())
    }

    #Preview("Loading") {
        DashboardView()
            .environment(DashboardModel.loadingPreview())
            .environment(Router())
    }

    #Preview("Error") {
        DashboardView()
            .environment(DashboardModel.errorPreview())
            .environment(Router())
    }
#endif
