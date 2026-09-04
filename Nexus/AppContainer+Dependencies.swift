import CardDetail
import Dashboard
import DataSources
import Entities
import Foundation
import Logging
import Persistence
import Repositories
import RepositoryProtocols
import ServiceProtocols
import Session
import Transactions

#if DEBUG
    import Mocks
#endif

/// The resolved repository/model graph for one mode (architecture.md
/// §11.2). Every property is the *protocol* surface models already use, so
/// live and demo differ only in how this struct is built — consumers never
/// switch on the mode.
struct AppDependencies {
    let session: any SessionManagerProtocol
    let cardRepository: CardRepositoryProtocol
    let offersRepository: CardOffersRepositoryProtocol
    let statusRepository: CardStatusRepositoryProtocol
    let actionRepository: CardActionRepositoryProtocol
    let balanceRepository: BalanceRepositoryProtocol
    let transactionRepository: TransactionRepositoryProtocol
    let dashboardModel: DashboardModel
    #if DEBUG
        /// The demo command coordinator (backend echo). Retained here so it
        /// outlives the factory — its hook holds it weakly and the demo
        /// would silently stop echoing without this.
        var commandCoordinator: MockCommandCoordinator?
    #endif
}

/// Builds `AppDependencies` for a mode. Live and demo construction are
/// separate static factories (the demo one is DEBUG-only) so the mode
/// switch happens exactly once, at the composition root.
enum AppDependenciesFactory {
    /// Live mode: the real Data-layer graph over the API session
    /// (architecture.md §11.4). `nil` when no base URL is configured —
    /// `AppContainer.start()` reports the configuration gap instead of
    /// building a session to nowhere.
    @MainActor
    static func live(baseURL: URL?, logger: LoggingService) -> AppDependencies? {
        guard let baseURL else {
            return nil
        }
        let session = APISessionManager(url: baseURL)
        let eventSubscriptionManager = EventSubscriptionManager(session: session)

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

        let offersRepository = CardOffersRepository(source: offersSource)
        let statusRepository = CardStatusRepository(source: statusSource)
        return AppDependencies(
            session: session,
            cardRepository: cardRepository,
            offersRepository: offersRepository,
            statusRepository: statusRepository,
            actionRepository: CardActionRepository(source: actionSource),
            balanceRepository: BalanceRepository(source: balanceSource),
            transactionRepository: TransactionsRepository(source: transactionsSource),
            dashboardModel: DashboardModel(
                cardRepository: cardRepository,
                offersRepository: offersRepository,
                statusRepository: statusRepository,
            ),
        )
    }
}

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
