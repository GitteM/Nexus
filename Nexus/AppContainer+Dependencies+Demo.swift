#if DEBUG
    import CardDetail
    import Dashboard
    import Entities
    import Foundation
    import Logging
    import Mocks
    import RepositoryProtocols
    import ServiceProtocols
    import Transactions

    extension AppDependenciesFactory {
        /// Demo mode: the shared in-memory mock store graph (architecture.md
        /// §9.5, §11.2). Same repositories/models the screens always use —
        /// only the transport/persistence edges are faked, and none of it
        /// touches the network, the Keychain, or disk.
        @MainActor
        static func demo(logger _: LoggingService) -> AppDependencies {
            let cardRepository = MockCardRepository(seed: Card.mockDefaults)
            let offersRepository = MockOffersRepository(seed: CardOffer.mockDefaults)
            let statusRepository = MockStatusRepository(seed: CardState.mockDefaults)
            let actionRepository = MockActionRepository()
            let balanceRepository = MockBalanceRepository(seed: Balance.mockDefaults)
            let transactionRepository = MockTransactionRepository(
                seed: [Card.mockCreditCard.id: Transaction.mockDefaults],
            )

            // UI-test launch knobs drive the failure/loading surfaces.
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

            let session = MockSessionManager(initialStatus: .disconnected)

            // The backend echo (freeze → frozen etc.) is retained for the
            // demo session's lifetime — its hook holds it weakly.
            let coordinator = MockCommandCoordinator(
                actionRepository: actionRepository,
                cardRepository: cardRepository,
                statusRepository: statusRepository,
                offersRepository: offersRepository,
            )
            coordinator.start()

            return AppDependencies(
                session: session,
                cardRepository: cardRepository,
                offersRepository: offersRepository,
                statusRepository: statusRepository,
                actionRepository: actionRepository,
                balanceRepository: balanceRepository,
                transactionRepository: transactionRepository,
                dashboardModel: DashboardModel(
                    cardRepository: cardRepository,
                    offersRepository: offersRepository,
                    statusRepository: statusRepository,
                ),
                commandCoordinator: coordinator,
            )
        }
    }

    /// The demo UI-test launch knobs, parsed from the process arguments
    /// (`-demoState`, `-demoActionState`, `-demoOpenCard`).
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
