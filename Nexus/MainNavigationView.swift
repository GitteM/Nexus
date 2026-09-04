import CardDetail
import Dashboard
import Design
import Navigation
import SwiftUI
import Transactions

/// The navigation shell for the ready app (architecture.md §8, §11.3,
/// tasks.md Day 14): binds the shared `Router.routes` to a
/// `NavigationStack` and maps routes to views.
///
/// The route → view mapping lives in the app target — the only place that
/// knows both routes and views. Screen models come from the container
/// (created once per route key), never from the views.
struct MainNavigationView: View {
    @Environment(AppContainer.self) private var container
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.routes) {
            DashboardView()
                .environment(container.dashboardModel)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
            #if DEBUG
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if container.mode == .demo {
                            Button {
                                container.resetDemo()
                            } label: {
                                Label(Strings.App.resetDemo, systemImage: Icons.resetDemo)
                            }
                            .accessibilityLabel(Strings.App.resetDemo)
                        }
                    }
                }
            #endif
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case let .cardDetail(cardID):
            CardDetailView()
                .environment(container.cardDetailModel(cardID: cardID))
        case let .transactionHistory(cardID):
            TransactionHistoryView()
                .environment(container.historyModel(cardID: cardID))
        case let .transactionDetail(cardID, transactionID):
            TransactionDetailView()
                .environment(
                    container.transactionDetailModel(cardID: cardID, transactionID: transactionID),
                )
        }
    }
}
