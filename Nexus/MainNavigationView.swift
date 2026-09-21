import CardDetail
import Dashboard
import Design
import Navigation
import SharedUI
import SwiftUI
import Transactions

/// The navigation shell for the ready app: binds the shared `Router.routes`
/// to a `NavigationStack` and maps routes to views.
///
/// The route → view mapping lives in the app target — the only place that
/// knows both routes and views. Screen models come from the container, which
/// materializes them off the body path (the `.onChange(of: router.routes)`
/// below) and evicts them when their route is popped — never from the views.
struct MainNavigationView: View {
    @Environment(AppContainer.self) private var container
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.routes) {
            DashboardView()
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
            #if DEBUG
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if container.mode == .demo {
                            Button {
                                Task { await container.resetDemo() }
                            } label: {
                                Label(Strings.App.resetDemo, systemImage: Icons.resetDemo)
                            }
                            .accessibilityLabel(Strings.App.resetDemo)
                        }
                    }
                }
            #endif
        }
        // Materialize the route models outside body evaluation. `initial: true`
        // also covers routes seeded before the shell appears (`-openCardID`, a
        // demo reset), so no destination ever renders against an unprepared
        // stack.
        .onChange(of: router.routes, initial: true) { _, routes in
            container.prepareScreenModels(for: routes)
        }
    }

    /// The destination for one route. Its model was prepared by the `.onChange`
    /// above and is looked up — never built — here, so a route whose model is
    /// not ready yet shows the loading surface for a frame instead of mutating
    /// container state mid-render or crashing.
    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case let .cardDetail(cardID):
            if let model = container.cardDetailModel(cardID: cardID) {
                CardDetailView().environment(model)
            } else {
                AppLoadingView()
            }
        case let .transactionHistory(cardID):
            if let model = container.historyModel(cardID: cardID) {
                TransactionHistoryView().environment(model)
            } else {
                AppLoadingView()
            }
        case let .transactionDetail(cardID, transactionID):
            if let model = container.transactionDetailModel(
                cardID: cardID,
                transactionID: transactionID
            ) {
                TransactionDetailView().environment(model)
            } else {
                AppLoadingView()
            }
        }
    }
}
