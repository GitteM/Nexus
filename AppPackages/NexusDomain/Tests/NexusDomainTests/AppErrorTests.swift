import Entities
import Foundation
import Testing

@Suite("AppError")
struct AppErrorTests {
    /// One error per case, built through the DEBUG-only test factory.
    private var allErrors: [AppError] {
        [
            AppErrorTestFactory.apiConnectionFailed(),
            AppErrorTestFactory.requestTimedOut(),
            AppErrorTestFactory.cardNotFound(),
            AppErrorTestFactory.cardAlreadyExists(),
            AppErrorTestFactory.cardActionFailed(),
            AppErrorTestFactory.insufficientFunds(),
            AppErrorTestFactory.persistenceError(),
            AppErrorTestFactory.serializationError(),
            AppErrorTestFactory.deserializationError(),
            AppErrorTestFactory.validationError(),
            AppErrorTestFactory.systemUnavailable(),
            AppErrorTestFactory.initializationFailed(),
            AppErrorTestFactory.unknown(),
        ]
    }

    // MARK: - Construction

    @Test func `factory constructs every case`() {
        let errors = allErrors
        // The exhaustive switch below forces a case for every AppError, so
        // adding a case breaks this test until it is covered here.
        #expect(errors.count == 13)
        for error in errors {
            let name = switch error {
            case .apiConnectionFailed: "apiConnectionFailed"
            case .requestTimedOut: "requestTimedOut"
            case .cardNotFound: "cardNotFound"
            case .cardAlreadyExists: "cardAlreadyExists"
            case .cardActionFailed: "cardActionFailed"
            case .insufficientFunds: "insufficientFunds"
            case .persistenceError: "persistenceError"
            case .serializationError: "serializationError"
            case .deserializationError: "deserializationError"
            case .validationError: "validationError"
            case .systemUnavailable: "systemUnavailable"
            case .initializationFailed: "initializationFailed"
            case .unknown: "unknown"
            }
            #expect(!name.isEmpty)
        }
    }

    @Test func `factory preserves payloads`() {
        #expect(AppErrorTestFactory.cardNotFound(cardId: "c-42") == .cardNotFound(cardId: "c-42"))
        #expect(AppErrorTestFactory.validationError(field: "amount") == .validationError(field: "amount", reason: "must be positive"))
        #expect(AppErrorTestFactory.insufficientFunds(amount: 99.50) == .insufficientFunds(amount: 99.50))
        #expect(AppErrorTestFactory.unknown(underlying: nil) == .unknown(underlying: nil))
    }

    @Test func `factory returns the right case`() {
        // Pins factory→case mapping: a wiring bug that swaps two
        // same-category factories would otherwise pass the construction,
        // category, and policy suites undetected.
        #expect(AppErrorTestFactory.apiConnectionFailed() == .apiConnectionFailed(details: "Connection reset by peer"))
        #expect(AppErrorTestFactory.requestTimedOut() == .requestTimedOut)
        #expect(AppErrorTestFactory.cardNotFound() == .cardNotFound(cardId: "card-test-001"))
        #expect(AppErrorTestFactory.cardAlreadyExists() == .cardAlreadyExists(cardId: "card-test-001"))
        #expect(AppErrorTestFactory.cardActionFailed() == .cardActionFailed(action: "freeze", details: "Command rejected"))
        #expect(AppErrorTestFactory.insufficientFunds() == .insufficientFunds(amount: 1250.75))
        #expect(AppErrorTestFactory.persistenceError() == .persistenceError(operation: "save_card", details: "Write failed"))
        #expect(AppErrorTestFactory.serializationError() == .serializationError(type: "Card", details: "Invalid key"))
        #expect(AppErrorTestFactory.deserializationError() == .deserializationError(type: "CardState", details: "Type mismatch at 'status'"))
        #expect(AppErrorTestFactory.validationError() == .validationError(field: "amount", reason: "must be positive"))
        #expect(AppErrorTestFactory.systemUnavailable() == .systemUnavailable(details: "Biometrics unavailable"))
        #expect(AppErrorTestFactory.initializationFailed() == .initializationFailed(details: "Container setup failed"))
        // Equatable compares `.unknown` by underlying presence only, so pin
        // the default explicitly.
        if case let .unknown(underlying) = AppErrorTestFactory.unknown() {
            #expect(underlying == nil)
        }
    }

    // MARK: - Category grouping

    @Test func `category groups cases by feature area`() {
        #expect(AppErrorTestFactory.apiConnectionFailed().category == .network)
        #expect(AppErrorTestFactory.requestTimedOut().category == .network)
        #expect(AppErrorTestFactory.cardNotFound().category == .card)
        #expect(AppErrorTestFactory.cardAlreadyExists().category == .card)
        #expect(AppErrorTestFactory.cardActionFailed().category == .card)
        #expect(AppErrorTestFactory.insufficientFunds().category == .account)
        #expect(AppErrorTestFactory.persistenceError().category == .data)
        #expect(AppErrorTestFactory.serializationError().category == .data)
        #expect(AppErrorTestFactory.deserializationError().category == .data)
        #expect(AppErrorTestFactory.validationError().category == .data)
        #expect(AppErrorTestFactory.systemUnavailable().category == .system)
        #expect(AppErrorTestFactory.initializationFailed().category == .initialization)
        #expect(AppErrorTestFactory.unknown().category == .unknown)
    }

    @Test func `category covers all feature areas`() {
        #expect(
            ErrorCategory.allCases
                == [.network, .card, .account, .data, .system, .initialization, .unknown],
        )
    }

    @Test func `every category has at least one case`() {
        #expect(Set(allErrors.map(\.category)) == Set(ErrorCategory.allCases))
    }

    @Test func `category display names are non empty`() {
        for category in ErrorCategory.allCases {
            #expect(!category.displayName.isEmpty)
        }
    }

    // MARK: - Helpers

    @Test func `every case exposes all user surfaces`() {
        for error in allErrors {
            #expect(error.errorDescription?.isEmpty == false, "\(error): errorDescription")
            #expect(error.failureReason?.isEmpty == false, "\(error): failureReason")
            #expect(error.recoverySuggestion?.isEmpty == false, "\(error): recoverySuggestion")
        }
    }

    @Test func `payloads flow into surfaces`() {
        let notFound = AppErrorTestFactory.cardNotFound(cardId: "c-42")
        #expect(notFound.failureReason == "No card with id c-42 exists.")
        #expect(notFound.errorDescription == "This card couldn't be found.")

        let validation = AppErrorTestFactory.validationError(field: "amount", reason: "must be positive")
        #expect(validation.failureReason == "'amount': must be positive")

        let api = AppErrorTestFactory.apiConnectionFailed(details: "host unreachable")
        #expect(api.failureReason == "host unreachable")
    }

    @Test func `recoverability policy`() {
        #expect(AppErrorTestFactory.apiConnectionFailed().isRecoverable)
        #expect(AppErrorTestFactory.requestTimedOut().isRecoverable)
        #expect(!AppErrorTestFactory.cardNotFound().isRecoverable)
        #expect(!AppErrorTestFactory.cardAlreadyExists().isRecoverable)
        #expect(AppErrorTestFactory.cardActionFailed().isRecoverable)
        #expect(!AppErrorTestFactory.insufficientFunds().isRecoverable)
        #expect(AppErrorTestFactory.persistenceError().isRecoverable)
        #expect(!AppErrorTestFactory.serializationError().isRecoverable)
        #expect(!AppErrorTestFactory.deserializationError().isRecoverable)
        #expect(AppErrorTestFactory.validationError().isRecoverable)
        #expect(!AppErrorTestFactory.systemUnavailable().isRecoverable)
        #expect(AppErrorTestFactory.initializationFailed().isRecoverable)
        #expect(!AppErrorTestFactory.unknown().isRecoverable)
    }

    @Test func `reporting policy`() {
        #expect(!AppErrorTestFactory.apiConnectionFailed().shouldReport)
        #expect(!AppErrorTestFactory.requestTimedOut().shouldReport)
        #expect(!AppErrorTestFactory.cardNotFound().shouldReport)
        #expect(!AppErrorTestFactory.cardAlreadyExists().shouldReport)
        #expect(!AppErrorTestFactory.cardActionFailed().shouldReport)
        #expect(!AppErrorTestFactory.insufficientFunds().shouldReport)
        #expect(AppErrorTestFactory.persistenceError().shouldReport)
        #expect(AppErrorTestFactory.serializationError().shouldReport)
        #expect(AppErrorTestFactory.deserializationError().shouldReport)
        #expect(!AppErrorTestFactory.validationError().shouldReport)
        #expect(AppErrorTestFactory.systemUnavailable().shouldReport)
        #expect(AppErrorTestFactory.initializationFailed().shouldReport)
        #expect(AppErrorTestFactory.unknown().shouldReport)
    }

    // MARK: - LocalizedError

    @Test func `localized description surfaces the error description`() {
        for error in allErrors {
            #expect(error.localizedDescription == error.errorDescription, "\(error)")
        }
    }

    // MARK: - Equatable

    @Test func `equal payloads compare equal`() {
        #expect(AppError.apiConnectionFailed(details: "x") == AppError.apiConnectionFailed(details: "x"))
        #expect(AppError.apiConnectionFailed(details: nil) == AppError.apiConnectionFailed(details: nil))
        #expect(AppError.requestTimedOut == AppError.requestTimedOut)
        #expect(AppError.cardNotFound(cardId: "c1") == AppError.cardNotFound(cardId: "c1"))
        #expect(AppError.insufficientFunds(amount: 10) == AppError.insufficientFunds(amount: 10))
        #expect(
            AppError.validationError(field: "amount", reason: "must be positive")
                == AppError.validationError(field: "amount", reason: "must be positive"),
        )
    }

    @Test func `different payloads compare different`() {
        #expect(AppError.apiConnectionFailed(details: "a") != AppError.apiConnectionFailed(details: "b"))
        #expect(AppError.apiConnectionFailed(details: "a") != AppError.apiConnectionFailed(details: nil))
        #expect(AppError.cardNotFound(cardId: "c1") != AppError.cardNotFound(cardId: "c2"))
        #expect(AppError.insufficientFunds(amount: 10) != AppError.insufficientFunds(amount: 20))
        #expect(
            AppError.validationError(field: "amount", reason: "must be positive")
                != AppError.validationError(field: "amount", reason: "must be negative"),
        )
    }

    @Test func `different cases compare different`() {
        #expect(AppError.cardNotFound(cardId: "c1") != AppError.cardAlreadyExists(cardId: "c1"))
        #expect(AppError.apiConnectionFailed() != AppError.requestTimedOut)
        #expect(AppError.serializationError(type: "Card") != AppError.deserializationError(type: "Card"))
    }

    @Test func `unknown compares underlying errors by presence only`() {
        // `Error?` payloads have no stable equality contract — compare
        // presence only.
        #expect(AppError.unknown(underlying: nil) == AppError.unknown(underlying: nil))
        #expect(
            AppError.unknown(underlying: NSError(domain: "a", code: 1))
                == AppError.unknown(underlying: NSError(domain: "b", code: 2)),
        )
        #expect(AppError.unknown(underlying: nil) != AppError.unknown(underlying: NSError(domain: "a", code: 1)))
    }
}
