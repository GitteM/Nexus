import CardDetail
import Dashboard
import Entities
import Foundation
import Logging
import Navigation
import Observation
import ServiceProtocols
import Transactions

/// The composition root (architecture.md §11.1–§11.3, tasks.md Day 14):
/// selects live vs. demo mode once at init, owns the app-level state
/// machine, and exposes concrete models for the environment.
///
/// Graph construction itself lives in `AppDependenciesFactory`
/// (`AppContainer+Dependencies.swift`, demo variant DEBUG-only), so this
/// file stays about *state*, not wiring.
@MainActor
@Observable
public final class AppContainer {
    public enum Mode: Equatable {
        case live
        case demo
    }

    // MARK: - State machine

    public private(set) var appState: AppState = .initializing
    public let mode: Mode
    public let router: Router
    public private(set) var dashboardModel: DashboardModel!

    /// The resolved repository/model graph for the selected mode. `nil`
    /// only when live mode has no backend configured yet (the state
    /// machine reports that gap instead of building a session to nowhere).
    /// Internal so the screen-model extension can read it; mutated only
    /// here and in `resetDemo()`.
    var dependencies: AppDependencies?

    // MARK: - Session (computed pass-through, §11.3)

    /// The session status as a computed pass-through. `ContentView` reacts
    /// to changes through `.onChange(of: sessionStatus)` — SwiftUI tracks
    /// the concrete `@Observable` session through this read (§11.3).
    public var sessionStatus: SessionStatus {
        dependencies?.session.sessionStatus ?? .disconnected
    }

    // MARK: - Screen models (created once per route key)

    var cardDetailModels: [String: CardDetailModel] = [:]
    var historyModels: [String: TransactionHistoryModel] = [:]
    var transactionDetailModels: [String: TransactionDetailModel] = [:]

    // MARK: - Init

    private let logger = LoggingService()

    /// The mode the app starts in: demo when launched with `-demoMode` or
    /// configured with `API_ENVIRONMENT = demo` (Debug builds); live
    /// otherwise. Release builds ignore `-demoMode` entirely and can never
    /// reach the DEBUG-only mock graph.
    public static func defaultMode() -> Mode {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demoMode") {
                return .demo
            }
        #endif
        if APIConfig.environment == "demo" {
            return .demo
        }
        return .live
    }

    /// Builds the container for the given mode and base URL.
    ///
    /// - Parameters:
    ///   - mode: The mode to build (defaults to `defaultMode()`).
    ///   - baseURL: Overrides `APIConfig.baseURL` (tests inject a URL for
    ///     the live graph; the app passes `nil` to read the config).
    public init(mode: Mode = AppContainer.defaultMode(), baseURL: URL? = nil) {
        self.mode = mode
        router = Router()
        switch mode {
        case .demo:
            #if DEBUG
                dependencies = AppDependenciesFactory.demo(logger: logger)
                if let openCardID = LaunchArguments.openCardID {
                    router.routes = [.cardDetail(cardID: openCardID)]
                }
            #else
                // Release cannot reach `.demo` via `defaultMode()`; if a
                // caller forces it anyway, degrade to the live
                // configuration-gap error state instead of crashing.
                dependencies = nil
            #endif
        case .live:
            dependencies = AppDependenciesFactory.live(baseURL: baseURL ?? APIConfig.baseURL, logger: logger)
        }
        dashboardModel = dependencies?.dashboardModel
        if mode == .live, dependencies == nil {
            logger.log(
                "Live mode without a backend base URL (API_BASE_URL empty); "
                    + "start() will report the configuration gap.",
                level: .notice,
            )
        }
    }

    // MARK: - Startup & state transitions

    /// Starts the session and moves the app into its first settled state:
    /// demo connects instantly (in-memory); live requires a configured base
    /// URL, otherwise the app reports the configuration gap.
    public func start() async {
        guard appState != .ready else { return }
        guard let dependencies else {
            appState = .error(
                .initializationFailed(
                    details: "No backend base URL is configured (API_BASE_URL is empty).",
                ),
            )
            return
        }
        appState = .loading
        do {
            try await dependencies.session.connect()
            // The session status is already `.connected`; the `.onChange`
            // path would also land here, but set the state directly so the
            // first frame is deterministic.
            appState = .ready
        } catch is CancellationError {
            // The start task was cancelled; keep the current state — the
            // next `.task` refire retries.
        } catch let error as AppError {
            appState = .error(error)
        } catch {
            appState = .error(.unknown(underlying: error))
        }
    }

    /// Maps a session-status change to the app state (called from
    /// `.onChange(of: sessionStatus)` in `ContentView`, §11.3).
    public func handleSessionStatusChange(_ status: SessionStatus) {
        switch status {
        case .connecting:
            if appState == .initializing || appState == .disconnected || appState.error != nil {
                appState = .loading
            }
        case .connected:
            appState = .ready
        case .disconnected, .error:
            if appState == .ready || appState == .loading {
                appState = .disconnected
            }
        }
    }

    /// Retry after an error state: return to `.loading` and reconnect.
    public func retry() {
        guard appState.error != nil || appState == .disconnected else { return }
        Task {
            await start()
        }
    }

    #if DEBUG
        /// Resets the demo to its default state: rebuilds the in-memory
        /// store graph, clears navigation, and reconnects. Never touches
        /// network/Keychain/disk (architecture.md §11.2). Async so the
        /// rebuild + reconnect happen on the caller's task rather than an
        /// unstructured one (no racing reconnects).
        public func resetDemo() async {
            guard mode == .demo else { return }
            cardDetailModels.removeAll()
            historyModels.removeAll()
            transactionDetailModels.removeAll()
            router.routes.removeAll()
            dependencies = AppDependenciesFactory.demo(logger: logger)
            dashboardModel = dependencies?.dashboardModel
            appState = .initializing
            await start()
        }
    #endif

    #if DEBUG
        /// Drives the container into a specific state for previews (the
        /// `#Preview`-only entry point, architecture.md §9.5).
        public func configurePreview(state: AppState) {
            appState = state
        }
    #endif
}
