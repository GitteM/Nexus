#if DEBUG
    import CardDetail
    import Dashboard
    import Entities
    import Mocks
    import Navigation
    import SwiftUI
    import Transactions

    /// Demo bootstrap for the dashboard UI tests and demos (tasks.md Day
    /// 11–12, architecture.md §10, §11.2).
    ///
    /// Interim app-target root until `AppContainer` lands on Day 14: it
    /// parses the `-demoMode` launch argument (and the `API_ENVIRONMENT =
    /// demo` Debug config) and, when demo, builds the *real* screens over
    /// the shared mock repositories. `-demoState=loading` /
    /// `-demoState=error` drive the card-fetch failure knobs and
    /// `-demoActionState=error` drives the card-action failure knob so UI
    /// tests can assert loading, error, and ready states render (§10). Day
    /// 14 folds this into `AppContainer`'s demo branch — this file is
    /// deleted there.
    ///
    /// Day 12 additions (M5): the mock graph lives for the whole demo
    /// session (`DemoGraph`), so state written by one screen is visible to
    /// the next — freezing a card in detail persists to the shared status
    /// store and the dashboard reflects it on return; `MockCommandCoordinator`
    /// plays the backend echo (a command's follow-up state lands back on the
    /// live channels, appspec §2.2). The navigation stack binds the shared
    /// `Router`, and the route → view mapping (architecture.md §8) composes
    /// `CardDetailView` per destination with a model minted over the same
    /// graph.
    ///
    /// Release builds compile this file to nothing (`#if DEBUG`) and
    /// `NexusApp` falls back to the placeholder, so `-demoMode` is ignored
    /// outside debug builds.
    @MainActor
    struct DemoRootView: View {
        /// Launch-argument state for the dashboard UI tests.
        enum DemoState: String {
            case ready
            case loading
            case error
        }

        /// Launch-argument state for the card-action failure knob (Day 12).
        enum DemoActionState: String {
            case ready
            case error
        }

        /// What the UI-test knobs mean for the mock graph.
        struct LaunchOptions {
            let isDemo: Bool
            let state: DemoState
            let actionState: DemoActionState
            /// When set, the demo root starts with this card's detail pushed
            /// (`-demoOpenCard=<id>`) — UI tests deep-link straight to the
            /// screen instead of tapping through the cold dashboard.
            let openCardID: String?

            init(arguments: [String], environment: String?) {
                isDemo = arguments.contains("-demoMode") || environment == "demo"
                // Accepts both "-demoState error" (separate elements) and
                // "-demoState=error" (one element), like launch args do.
                state = Self.parseState(arguments: arguments)
                actionState = Self.parseActionState(arguments: arguments)
                openCardID = Self.parseOpenCardID(arguments: arguments)
            }

            private static func parseOpenCardID(arguments: [String]) -> String? {
                if let index = arguments.firstIndex(of: "-demoOpenCard"),
                   arguments.indices.contains(index + 1)
                {
                    return arguments[index + 1]
                }
                if let prefixed = arguments.first(where: { $0.hasPrefix("-demoOpenCard=") }) {
                    return String(prefixed.dropFirst("-demoOpenCard=".count))
                }
                return nil
            }

            private static func parseState(arguments: [String]) -> DemoState {
                if let index = arguments.firstIndex(of: "-demoState"),
                   arguments.indices.contains(index + 1),
                   let state = DemoState(rawValue: arguments[index + 1])
                {
                    return state
                }
                if let prefixed = arguments.first(where: { $0.hasPrefix("-demoState=") }),
                   let state = DemoState(rawValue: String(prefixed.dropFirst("-demoState=".count)))
                {
                    return state
                }
                return .ready
            }

            private static func parseActionState(arguments: [String]) -> DemoActionState {
                if let index = arguments.firstIndex(of: "-demoActionState"),
                   arguments.indices.contains(index + 1),
                   let state = DemoActionState(rawValue: arguments[index + 1])
                {
                    return state
                }
                if let prefixed = arguments.first(where: { $0.hasPrefix("-demoActionState=") }),
                   let state = DemoActionState(rawValue: String(prefixed.dropFirst("-demoActionState=".count)))
                {
                    return state
                }
                return .ready
            }

            /// The options of this process, read once per root creation.
            static var current: LaunchOptions {
                LaunchOptions(
                    arguments: ProcessInfo.processInfo.arguments,
                    environment: Bundle.main.infoDictionary?["API_ENVIRONMENT"] as? String,
                )
            }
        }

        private let options: LaunchOptions
        @State private var graph: DemoGraph?
        @State private var router: Router

        init(options: LaunchOptions = .current) {
            self.options = options
            _graph = State(initialValue: options.isDemo ? DemoGraph(options: options) : nil)
            // Deep-link support: start with the requested card's detail
            // already pushed (UI tests skip cold-launch taps, which are
            // flaky on fresh CI simulators).
            let initialRoutes = options.openCardID.map { [Route.cardDetail(cardID: $0)] } ?? []
            _router = State(initialValue: Router(routes: initialRoutes))
        }

        var body: some View {
            if options.isDemo, let graph {
                NavigationStack(path: $router.routes) {
                    DashboardView()
                        .environment(graph.dashboardModel)
                        .navigationDestination(for: Route.self) { route in
                            destination(route, in: graph)
                        }
                }
                .environment(router)
            } else {
                Text("Nexus")
            }
        }

        /// The route → view mapping (architecture.md §8). The only place
        /// that knows both routes and views; Day 14's `AppContainer` takes
        /// this over.
        @ViewBuilder
        private func destination(_ route: Route, in graph: DemoGraph) -> some View {
            switch route {
            case let .cardDetail(cardID):
                CardDetailView()
                    .environment(graph.makeDetailModel(cardID: cardID))
            case let .transactionHistory(cardID):
                TransactionHistoryView()
                    .environment(graph.makeHistoryModel(cardID: cardID))
            case let .transactionDetail(cardID, transactionID):
                TransactionDetailView()
                    .environment(graph.makeDetailModel(cardID: cardID, transactionID: transactionID))
            }
        }
    }

    /// The demo's shared mock graph (architecture.md §9.5, §11.2): one set
    /// of store-backed mock repositories for the whole session, so state
    /// written by any screen is visible to every other screen and survives
    /// navigation. Holds the `-demoState` / `-demoActionState` knob wiring
    /// and installs the `MockCommandCoordinator` backend echo.
    @MainActor
    private final class DemoGraph {
        let cardRepository: MockCardRepository
        let offersRepository: MockOffersRepository
        let statusRepository: MockStatusRepository
        let actionRepository: MockActionRepository
        let balanceRepository: MockBalanceRepository
        let transactionRepository: MockTransactionRepository
        let dashboardModel: DashboardModel
        /// The backend echo stays alive for the demo session — the
        /// coordinator's hook holds it weakly, so the graph owns it.
        private let coordinator: MockCommandCoordinator

        init(options: DemoRootView.LaunchOptions) {
            cardRepository = MockCardRepository(seed: Card.mockDefaults)
            offersRepository = MockOffersRepository(seed: CardOffer.mockDefaults)
            statusRepository = MockStatusRepository(seed: CardState.mockDefaults)
            actionRepository = MockActionRepository()
            balanceRepository = MockBalanceRepository(seed: Balance.mockDefaults)
            transactionRepository = MockTransactionRepository(
                seed: [Card.mockCreditCard.id: Transaction.mockDefaults],
            )
            switch options.state {
            case .ready:
                break
            case .loading:
                // The card fetch never completes: `load()` stays `.loading`.
                cardRepository.shouldNeverComplete = true
            case .error:
                // The card fetch fails: `load()` lands in `.error` with the
                // default `.apiConnectionFailed` surface.
                cardRepository.shouldThrowError = true
            }
            if options.actionState == .error {
                // Card actions fail with a freeze-shaped rejection; the card
                // stays unchanged and the detail screen surfaces the error.
                actionRepository.shouldThrowError = true
                actionRepository.thrownError = .cardActionFailed(
                    action: "Freeze",
                    details: "The freeze was rejected.",
                )
            }
            dashboardModel = DashboardModel(
                cardRepository: cardRepository,
                offersRepository: offersRepository,
                statusRepository: statusRepository,
            )
            coordinator = MockCommandCoordinator(
                actionRepository: actionRepository,
                cardRepository: cardRepository,
                statusRepository: statusRepository,
                offersRepository: offersRepository,
            )
            coordinator.start()
        }

        /// Mints one detail model over the shared graph for a pushed
        /// destination (composition-root responsibility; Day 14 moves this
        /// into `AppContainer`).
        func makeDetailModel(cardID: String) -> CardDetailModel {
            CardDetailModel(
                cardID: cardID,
                cardRepository: cardRepository,
                statusRepository: statusRepository,
                actionRepository: actionRepository,
            )
        }

        /// Mints the per-card account-activity model (Day 13): the live
        /// balance and the transaction feed share the demo store graph, so
        /// pushes made in tests/demo are visible to every screen.
        func makeHistoryModel(cardID: String) -> TransactionHistoryModel {
            TransactionHistoryModel(
                cardID: cardID,
                balanceRepository: balanceRepository,
                transactionRepository: transactionRepository,
            )
        }

        /// Mints the transaction detail model over the same shared feed.
        func makeDetailModel(cardID: String, transactionID: String) -> TransactionDetailModel {
            TransactionDetailModel(
                cardID: cardID,
                transactionID: transactionID,
                transactionRepository: transactionRepository,
            )
        }
    }
#endif
