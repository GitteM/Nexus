import Design
import Entities
import Navigation
import SharedUI
import SwiftUI

/// The dashboard screen.
///
/// A thin switch over the model's `viewState`: the loading / error / empty
/// surfaces come from SharedUI components and the loaded screen delegates
/// to `DashboardContentView`. The model comes from the environment — the
/// composition root injects it, it is never created in a view — and
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

/// The loaded dashboard: the swipeable card carousel and the offers row,
/// each under a section header, in one scroll view. It renders the model's
/// `cards`, `offeredCards`, and effective card status folded in from live
/// `CardState` updates.
///
/// The action surfaces live here: adding an offer is the dashboard's one
/// card action, so success and failure haptics ride the model's
/// `lastAddedCardID` / `addOfferError` signals, and a failed add surfaces
/// the `AppError` in an alert without touching the loaded content.
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
    /// failure can present again (views mutate model state through model
    /// methods).
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

    /// Alert copy reuses the `AppError` surfaces, matching `ErrorView`'s
    /// order: the headline first, the recovery guidance below.
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
