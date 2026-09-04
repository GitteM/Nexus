import CardDetail
import Dashboard
import DataSources
import Entities
import Foundation
import Logging
import Navigation
import Observation
import Persistence
import Repositories
import RepositoryProtocols
import ServiceProtocols
import Session
import Transactions
#if DEBUG
    import Mocks
#endif

/// The composition root (architecture.md §11.1–§11.3, tasks.md Day 14):
/// one `@MainActor @Observable` object that builds every dependency inline,
/// owns the app-level state machine, and injects concrete models into the
/// environment.
///
/// Responsibilities:
/// - Selects **live vs. demo** mode once, at init, from the `-demoMode`
///   launch argument / `API_ENVIRONMENT` config (release builds can never
///   select the DEBUG-only demo graph).
/// - `createDependencies()` builds the graph **inline** with plain
///   initializers (no factory ladder, §12.1): repositories → models → done.
/// - Exposes `appState` and the session-status pass-through; `ContentView`
///   drives `handleSessionStatusChange(_:)` from `.onChange` (observation,
///   never polling, §11.3).
/// - Owns the `Router` and the per-route screen models (created once per
///   route key — destinations are evaluated more than once around a push
///   and must always present the same state; Day 14 makes this ownership
///   explicit).
/// - Demo mode: DEBUG-only mock graph (no network/Keychain/disk), the
///   `-demoState` / `-demoActionState` / `-demoOpenCard` UI-test knobs, and
///   a `resetDemo()` action.
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

    // MARK: - Session (computed pass-through, §11.3)

    private var session: (any SessionManagerProtocol)?
    private var apiSession: APISessionManager?
    #if DEBUG
        private var mockSession: MockSessionManager?
    #endif

    /// The session status as a computed pass-through. `ContentView` reacts
    /// to changes through `.onChange(of: sessionStatus)` — SwiftUI tracks
    /// the concrete `@Observable` session through this read (§11.3).
    public var sessionStatus: SessionStatus {
        session?.sessionStatus ?? .disconnected
    }

    // MARK: - Models

    public private(set) var dashboardModel: DashboardModel!
    private var cardDetailModels: [String: CardDetailModel] = [:]
    private var historyModels: [String: TransactionHistoryModel] = [:]
    private var transactionDetailModels: [String: TransactionDetailModel] = [:]

    // MARK: - Construction inputs

    private let logger: LoggingService
    private let baseURL: URL?
    #if DEBUG
        /// The demo command coordinator (backend echo) — retained for the
        /// demo session's lifetime (its hook holds it weakly).
        private var commandCoordinator: MockCommandCoordinator?
    #endif

    #if DEBUG
        /// Drives the container into a specific state for previews (the
        /// `#Preview`-only entry point, architecture.md §9.5).
        public func configurePreview(state: AppState) {
            appState = state
        }
    #endif

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
        self.baseURL = baseURL ?? APIConfig.baseURL
        router = Router()
        logger = LoggingService()
        buildDependencies()
        #if DEBUG
            if mode == .demo, let openCardID = LaunchArguments.openCardID {
                router.routes = [.cardDetail(cardID: openCardID)]
            }
        #endif
    }

    // MARK: - Graph construction

    /// Builds the repository/model graph inline for the selected mode
    /// (architecture.md §11.2). Called at init and again by `resetDemo()`.
    private func buildDependencies() {
        switch mode {
        case .demo:
            buildDemoDependencies()
        case .live:
            buildLiveDependencies()
        }
    }

    /// Demo mode: the shared in-memory mock store graph (architecture.md
    /// §9.5, §11.2). Same repositories/models as the screens always use —
    /// only the transport/persistence edges are faked, and none of it
    /// touches the network, the Keychain, or disk.
    private func buildDemoDependencies() {
        #if DEBUG
            let cardRepository = MockCardRepository(seed: Card.mockDefaults)
            let offersRepository = MockOffersRepository(seed: CardOffer.mockDefaults)
            let statusRepository = MockStatusRepository(seed: CardState.mockDefaults)
            let actionRepository = MockActionRepository()
            let balanceRepository = MockBalanceRepository(seed: Balance.mockDefaults)
            let transactionRepository = MockTransactionRepository(
                seed: [Card.mockCreditCard.id: Transaction.mockDefaults],
            )

            switch LaunchArguments.state {
            case .ready:
                break
            case .loading:
                cardRepository.shouldNeverComplete = true
            case .error:
                cardRepository.shouldThrowError = true
            }
            if LaunchArguments.actionState == .error {
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

            // The session the demo presents through `sessionStatus`: an
            // in-memory manager that connects instantly (no network).
            let session = MockSessionManager(initialStatus: .disconnected)
            mockSession = session
            self.session = session

            let coordinator = MockCommandCoordinator(
                actionRepository: actionRepository,
                cardRepository: cardRepository,
                statusRepository: statusRepository,
                offersRepository: offersRepository,
            )
            coordinator.start()
            commandCoordinator = coordinator

            storeDemoGraph(
                cardRepository: cardRepository,
                offersRepository: offersRepository,
                statusRepository: statusRepository,
                actionRepository: actionRepository,
                balanceRepository: balanceRepository,
                transactionRepository: transactionRepository,
            )
        #endif
    }

    #if DEBUG
        /// Holds the demo store graph for the screen-model factories.
        private var demoGraph: DemoGraphStorage?

        private struct DemoGraphStorage {
            let cardRepository: MockCardRepository
            let offersRepository: MockOffersRepository
            let statusRepository: MockStatusRepository
            let actionRepository: MockActionRepository
            let balanceRepository: MockBalanceRepository
            let transactionRepository: MockTransactionRepository
        }

        private func storeDemoGraph(
            cardRepository: MockCardRepository,
            offersRepository: MockOffersRepository,
            statusRepository: MockStatusRepository,
            actionRepository: MockActionRepository,
            balanceRepository: MockBalanceRepository,
            transactionRepository: MockTransactionRepository,
        ) {
            demoGraph = DemoGraphStorage(
                cardRepository: cardRepository,
                offersRepository: offersRepository,
                statusRepository: statusRepository,
                actionRepository: actionRepository,
                balanceRepository: balanceRepository,
                transactionRepository: transactionRepository,
            )
        }
    #endif

    /// Live mode: the real Data-layer graph over the API session. The
    /// backend does not exist yet (§11.4), so the base URL is empty in
    /// current builds and `start()` reports the configuration gap instead
    /// of building a session to nowhere.
    private func buildLiveDependencies() {
        // No backend is configured yet (API_BASE_URL empty, §7.1/§11.4):
        // build nothing and leave `session` nil — `start()` reports the
        // configuration gap instead of connecting to a placeholder.
        guard let baseURL else {
            return
        }
        let apiSession = APISessionManager(url: baseURL)
        session = apiSession
        self.apiSession = apiSession
        let eventSubscriptionManager = EventSubscriptionManager(session: apiSession)

        let statusSource = CardStateDataSource(
            eventSubscriptionManager: eventSubscriptionManager,
            logger: logger,
        )
        let offersSource = OffersDataSource(
            eventSubscriptionManager: eventSubscriptionManager,
            logger: logger,
        )
        let actionSource = CardActionDataSource(
            eventSubscriptionManager: eventSubscriptionManager,
            logger: logger,
        )
        let balanceSource = CardBalanceDataSource(
            eventSubscriptionManager: eventSubscriptionManager,
            logger: logger,
        )
        let transactionsSource = CardTransactionsDataSource(
            eventSubscriptionManager: eventSubscriptionManager,
            logger: logger,
        )

        let cardRepository: CardRepositoryProtocol = if let container = try? SwiftDataCardRepository.makeContainer() {
            CardRepository(store: SwiftDataCardRepository(container: container))
        } else {
            // No persistence available (e.g. entitlements in a bare test
            // runner): nothing to manage yet. Recorded in appspec §2.9;
            // the live backend contract (§11.4) defines the real path.
            EmptyCardRepository()
        }

        dashboardModel = DashboardModel(
            cardRepository: cardRepository,
            offersRepository: CardOffersRepository(source: offersSource),
            statusRepository: CardStatusRepository(source: statusSource),
        )
        liveGraph = LiveGraphStorage(
            session: apiSession,
            cardRepository: cardRepository,
            statusRepository: CardStatusRepository(source: statusSource),
            actionRepository: CardActionRepository(source: actionSource),
            balanceRepository: BalanceRepository(source: balanceSource),
            transactionRepository: TransactionsRepository(source: transactionsSource),
        )
    }

    /// Live store graph for the screen-model factories.
    private var liveGraph: LiveGraphStorage?

    private struct LiveGraphStorage {
        let session: APISessionManager
        let cardRepository: CardRepositoryProtocol
        let statusRepository: CardStatusRepositoryProtocol
        let actionRepository: CardActionRepositoryProtocol
        let balanceRepository: BalanceRepositoryProtocol
        let transactionRepository: TransactionRepositoryProtocol
    }

    // MARK: - Screen-model factories (created once per route key)

    /// The card detail model for a route, created on first use.
    func cardDetailModel(cardID: String) -> CardDetailModel {
        if let existing = cardDetailModels[cardID] {
            return existing
        }
        let model: CardDetailModel
        switch mode {
        case .demo:
            #if DEBUG
                guard let graph = demoGraph else {
                    fatalError("demo graph missing")
                }
                model = CardDetailModel(
                    cardID: cardID,
                    cardRepository: graph.cardRepository,
                    statusRepository: graph.statusRepository,
                    actionRepository: graph.actionRepository,
                )
            #else
                fatalError("demo mode is DEBUG-only")
            #endif
        case .live:
            guard let graph = liveGraph else {
                fatalError("live graph missing")
            }
            model = CardDetailModel(
                cardID: cardID,
                cardRepository: graph.cardRepository,
                statusRepository: graph.statusRepository,
                actionRepository: graph.actionRepository,
            )
        }
        cardDetailModels[cardID] = model
        return model
    }

    /// The transaction-history model for a route, created once per card.
    func historyModel(cardID: String) -> TransactionHistoryModel {
        if let existing = historyModels[cardID] {
            return existing
        }
        let model: TransactionHistoryModel
        switch mode {
        case .demo:
            #if DEBUG
                guard let graph = demoGraph else {
                    fatalError("demo graph missing")
                }
                model = TransactionHistoryModel(
                    cardID: cardID,
                    balanceRepository: graph.balanceRepository,
                    transactionRepository: graph.transactionRepository,
                )
            #else
                fatalError("demo mode is DEBUG-only")
            #endif
        case .live:
            guard let graph = liveGraph else {
                fatalError("live graph missing")
            }
            model = TransactionHistoryModel(
                cardID: cardID,
                balanceRepository: graph.balanceRepository,
                transactionRepository: graph.transactionRepository,
            )
        }
        historyModels[cardID] = model
        return model
    }

    /// The transaction-detail model for a route, created once per
    /// (card, transaction) pair.
    func transactionDetailModel(cardID: String, transactionID: String) -> TransactionDetailModel {
        let key = "\(cardID):\(transactionID)"
        if let existing = transactionDetailModels[key] {
            return existing
        }
        let model: TransactionDetailModel
        switch mode {
        case .demo:
            #if DEBUG
                guard let graph = demoGraph else {
                    fatalError("demo graph missing")
                }
                model = TransactionDetailModel(
                    cardID: cardID,
                    transactionID: transactionID,
                    transactionRepository: graph.transactionRepository,
                )
            #else
                fatalError("demo mode is DEBUG-only")
            #endif
        case .live:
            guard let graph = liveGraph else {
                fatalError("live graph missing")
            }
            model = TransactionDetailModel(
                cardID: cardID,
                transactionID: transactionID,
                transactionRepository: graph.transactionRepository,
            )
        }
        transactionDetailModels[key] = model
        return model
    }

    // MARK: - Startup & state transitions

    /// Starts the session and moves the app into its first settled state:
    /// demo connects instantly (in-memory); live requires a configured base
    /// URL, otherwise the app reports the configuration gap.
    public func start() async {
        guard appState != .ready else { return }
        appState = .loading
        do {
            guard let session else {
                throw AppError.initializationFailed(
                    details: "No backend base URL is configured (API_BASE_URL is empty).",
                )
            }
            try await session.connect()
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
        /// network/Keychain/disk (architecture.md §11.2).
        public func resetDemo() {
            guard mode == .demo else { return }
            cardDetailModels.removeAll()
            historyModels.removeAll()
            transactionDetailModels.removeAll()
            router.routes.removeAll()
            buildDependencies()
            appState = .initializing
            Task {
                await start()
            }
        }
    #endif
}

#if DEBUG
    /// The demo UI-test launch knobs (formerly `DemoRootView`), kept in one
    /// place so the composition root can build the matching graph.
    enum LaunchArguments {
        enum DemoState: String {
            case ready
            case loading
            case error
        }

        enum DemoActionState: String {
            case ready
            case error
        }

        static var state: DemoState {
            parse("demoState", as: DemoState.self) ?? .ready
        }

        static var actionState: DemoActionState {
            parse("demoActionState", as: DemoActionState.self) ?? .ready
        }

        static var openCardID: String? {
            value(for: "demoOpenCard")
        }

        private static func parse<Value: RawRepresentable>(_ key: String, as _: Value.Type) -> Value? where Value.RawValue == String {
            guard let raw = value(for: key), let parsed = Value(rawValue: raw) else {
                return nil
            }
            return parsed
        }

        /// Accepts both "-<key> <value>" (separate elements) and
        /// "-<key>=<value>" (one element), like launch args do.
        private static func value(for key: String) -> String? {
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-\(key)"),
               arguments.indices.contains(index + 1)
            {
                return arguments[index + 1]
            }
            let prefix = "-\(key)="
            if let prefixed = arguments.first(where: { $0.hasPrefix(prefix) }) {
                return String(prefixed.dropFirst(prefix.count))
            }
            return nil
        }
    }
#endif

/// A live-mode card store with no cards yet: used when SwiftData cannot be
/// initialized (e.g. entitlements missing in a bare test runner). It never
/// fabricates data — `getCards()` is empty and adds are accepted but not
/// persisted, mirroring the provisional-add contract until the real
/// persistence path is available (appspec §2.9).
private struct EmptyCardRepository: CardRepositoryProtocol {
    func getCards() async throws -> [Card] {
        []
    }

    func addCard(_ offer: CardOffer) async throws -> Card {
        Card(
            id: offer.id,
            cardholderName: "",
            lastFourDigits: "",
            type: offer.type,
            status: .active,
            currency: offer.currency,
            spendingLimit: nil,
        )
    }

    func removeCard(cardId _: String) async throws {}
}
