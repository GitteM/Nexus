#if DEBUG
    import Dashboard
    import Entities
    import Mocks
    import SwiftUI

    /// Demo bootstrap for the dashboard UI tests and demos (tasks.md Day
    /// 11, architecture.md §10, §11.2).
    ///
    /// Interim app-target root until `AppContainer` lands on Day 14: it
    /// parses the `-demoMode` launch argument (and the `API_ENVIRONMENT =
    /// demo` Debug config) and, when demo, builds the *real* `DashboardView`
    /// over the shared mock repositories. `-demoState=loading` /
    /// `-demoState=error` drive the mock failure knobs so UI tests can
    /// assert loading, error, and ready states render (§10). Day 14 folds
    /// this into `AppContainer`'s demo branch — this file is deleted there.
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

        /// What the UI-test knobs mean for the mock graph.
        struct LaunchOptions {
            let isDemo: Bool
            let state: DemoState

            init(arguments: [String], environment: String?) {
                isDemo = arguments.contains("-demoMode") || environment == "demo"
                // Accepts both "-demoState error" (separate elements) and
                // "-demoState=error" (one element), like launch args do.
                state = Self.parseState(arguments: arguments)
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

            /// The options of this process, read once per root creation.
            static var current: LaunchOptions {
                LaunchOptions(
                    arguments: ProcessInfo.processInfo.arguments,
                    environment: Bundle.main.infoDictionary?["API_ENVIRONMENT"] as? String,
                )
            }
        }

        private let options: LaunchOptions
        private let model: DashboardModel

        init(options: LaunchOptions = .current) {
            self.options = options
            model = Self.makeModel(state: options.state)
        }

        var body: some View {
            if options.isDemo {
                NavigationStack {
                    DashboardView()
                        .environment(model)
                }
            } else {
                Text("Nexus")
            }
        }

        /// The demo graph: shared mocks, tuned per `-demoState` (the ready
        /// default seeds the standard demo content).
        private static func makeModel(state: DemoState) -> DashboardModel {
            let cardRepository = MockCardRepository(seed: Card.mockDefaults)
            switch state {
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
            return DashboardModel(
                cardRepository: cardRepository,
                offersRepository: MockOffersRepository(seed: CardOffer.mockDefaults),
                statusRepository: MockStatusRepository(seed: CardState.mockDefaults),
            )
        }
    }
#endif
