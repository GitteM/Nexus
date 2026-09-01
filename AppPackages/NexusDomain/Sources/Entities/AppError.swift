import Foundation

/// The single error type for the whole app (architecture.md §5).
///
/// Every layer throws or returns `AppError` — never raw `Error`, `NSError`,
/// or SDK-specific types across boundaries. Cases are grouped by feature
/// area; each one maps to an `ErrorCategory` and carries the four computed
/// surfaces (`errorDescription`, `failureReason`, `recoverySuggestion`,
/// `category`) plus the policy flags (`isRecoverable`, `shouldReport`).
public enum AppError: Error, Sendable, LocalizedError {
    // MARK: - Network

    case apiConnectionFailed(details: String? = nil)
    case requestTimedOut

    // MARK: - Card

    case cardNotFound(cardId: String)
    case cardAlreadyExists(cardId: String)
    case cardActionFailed(action: String, details: String? = nil)

    // MARK: - Account

    case insufficientFunds(amount: Decimal)

    // MARK: - Data

    case persistenceError(operation: String, details: String? = nil)
    case serializationError(type: String, details: String? = nil)
    case deserializationError(type: String, details: String? = nil)
    case validationError(field: String, reason: String)

    // MARK: - System

    case systemUnavailable(details: String? = nil)

    // MARK: - Initialization

    case initializationFailed(details: String? = nil)

    // MARK: - Unknown

    case unknown(underlying: Error? = nil)
}

public extension AppError {
    /// User-facing message.
    var errorDescription: String? {
        switch self {
        case .apiConnectionFailed: "We couldn't reach the server."
        case .requestTimedOut: "The request took too long."
        case .cardNotFound: "This card couldn't be found."
        case .cardAlreadyExists: "This card is already in your wallet."
        case let .cardActionFailed(action, _): "The '\(action)' action failed."
        case .insufficientFunds: "There aren't enough funds for this payment."
        case .persistenceError: "Your data couldn't be saved."
        case .serializationError: "Something went wrong while preparing your data."
        case .deserializationError: "We couldn't read the data we received."
        case .validationError: "Some of the information you entered isn't valid."
        case .systemUnavailable: "A system service isn't available right now."
        case .initializationFailed: "The app couldn't finish starting up."
        case .unknown: "Something went wrong."
        }
    }

    /// Short technical reason.
    var failureReason: String? {
        switch self {
        case let .apiConnectionFailed(details): details ?? "The connection to the server failed."
        case .requestTimedOut: "The request exceeded the timeout."
        case let .cardNotFound(cardId): "No card with id \(cardId) exists."
        case let .cardAlreadyExists(cardId): "Card \(cardId) is already managed."
        case let .cardActionFailed(action, details): details ?? "The '\(action)' action was rejected."
        case .insufficientFunds: "The account balance is below the requested amount."
        case let .persistenceError(operation, details): details ?? "Operation '\(operation)' failed."
        case let .serializationError(type, details): details ?? "Encoding '\(type)' failed."
        case let .deserializationError(type, details): details ?? "Decoding '\(type)' failed."
        case let .validationError(field, reason): "'\(field)': \(reason)"
        case let .systemUnavailable(details): details ?? "A required system service is unavailable."
        case let .initializationFailed(details): details ?? "Initialization did not complete."
        case let .unknown(underlying): underlying.map { "\($0)" } ?? "An unknown error occurred."
        }
    }

    /// The action a user could take.
    var recoverySuggestion: String? {
        switch self {
        case .apiConnectionFailed: "Check your connection and try again."
        case .requestTimedOut: "Try again in a moment."
        case .cardNotFound: "Refresh your cards and try again."
        case .cardAlreadyExists: "Nothing to do — the card is already added."
        case .cardActionFailed: "Try the action again."
        case .insufficientFunds: "Add funds or use a different card."
        case .persistenceError: "Try saving again."
        case .serializationError: "Try the request again."
        case .deserializationError: "Refresh and try again."
        case .validationError: "Review the highlighted fields and try again."
        case .systemUnavailable: "Restart the app and try again."
        case .initializationFailed: "Restart the app to try again."
        case .unknown: "Try again. If it keeps happening, contact support."
        }
    }

    /// Analytics/grouping bucket.
    var category: ErrorCategory {
        switch self {
        case .apiConnectionFailed, .requestTimedOut: .network
        case .cardNotFound, .cardAlreadyExists, .cardActionFailed: .card
        case .insufficientFunds: .account
        case .persistenceError, .serializationError, .deserializationError, .validationError: .data
        case .systemUnavailable: .system
        case .initializationFailed: .initialization
        case .unknown: .unknown
        }
    }

    /// Whether retrying the same operation can plausibly succeed.
    var isRecoverable: Bool {
        switch self {
        case .apiConnectionFailed, .requestTimedOut, .cardActionFailed: true
        case .persistenceError, .validationError, .initializationFailed: true
        case .cardNotFound, .cardAlreadyExists, .insufficientFunds: false
        case .serializationError, .deserializationError, .systemUnavailable: false
        case .unknown: false
        }
    }

    /// Whether this error is worth reporting to analytics/support.
    var shouldReport: Bool {
        switch self {
        case .apiConnectionFailed, .requestTimedOut: false
        case .cardNotFound, .cardAlreadyExists, .cardActionFailed: false
        case .insufficientFunds, .validationError: false
        case .persistenceError, .serializationError, .deserializationError: true
        case .systemUnavailable, .initializationFailed, .unknown: true
        }
    }
}

extension AppError: Equatable {
    /// Hand-written comparison: Swift enums with associated values get
    /// synthesis only if the payloads are `Equatable`, and `Error?` payloads
    /// are not (architecture.md §5).
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case let (.apiConnectionFailed(a), .apiConnectionFailed(b)): a == b
        case (.requestTimedOut, .requestTimedOut): true
        case let (.cardNotFound(a), .cardNotFound(b)): a == b
        case let (.cardAlreadyExists(a), .cardAlreadyExists(b)): a == b
        case let (.cardActionFailed(a1, a2), .cardActionFailed(b1, b2)): a1 == b1 && a2 == b2
        case let (.insufficientFunds(a), .insufficientFunds(b)): a == b
        case let (.persistenceError(a1, a2), .persistenceError(b1, b2)): a1 == b1 && a2 == b2
        case let (.serializationError(a1, a2), .serializationError(b1, b2)): a1 == b1 && a2 == b2
        case let (.deserializationError(a1, a2), .deserializationError(b1, b2)): a1 == b1 && a2 == b2
        case let (.validationError(a1, a2), .validationError(b1, b2)): a1 == b1 && a2 == b2
        case let (.systemUnavailable(a), .systemUnavailable(b)): a == b
        case let (.initializationFailed(a), .initializationFailed(b)): a == b
        // `Error?` payloads are compared by presence only — underlying errors
        // have no stable equality contract.
        case let (.unknown(a), .unknown(b)): (a == nil) == (b == nil)
        default: false
        }
    }
}
