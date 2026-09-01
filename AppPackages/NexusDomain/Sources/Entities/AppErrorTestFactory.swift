import Foundation

#if DEBUG
    /// Factory methods for every `AppError` case — tests and previews construct
    /// errors without stringly code (architecture.md §5).
    ///
    /// Every factory takes representative payloads with defaults, so callers can
    /// write `AppErrorTestFactory.cardNotFound()` for the canonical instance or
    /// pass a payload to pin a specific value.
    public enum AppErrorTestFactory {
        public static func apiConnectionFailed(details: String? = "Connection reset by peer") -> AppError {
            .apiConnectionFailed(details: details)
        }

        public static func requestTimedOut() -> AppError {
            .requestTimedOut
        }

        public static func cardNotFound(cardId: String = "card-test-001") -> AppError {
            .cardNotFound(cardId: cardId)
        }

        public static func cardAlreadyExists(cardId: String = "card-test-001") -> AppError {
            .cardAlreadyExists(cardId: cardId)
        }

        public static func cardActionFailed(
            action: String = "freeze",
            details: String? = "Command rejected",
        ) -> AppError {
            .cardActionFailed(action: action, details: details)
        }

        public static func insufficientFunds(amount: Decimal = 1250.75) -> AppError {
            .insufficientFunds(amount: amount)
        }

        public static func persistenceError(
            operation: String = "save_card",
            details: String? = "Write failed",
        ) -> AppError {
            .persistenceError(operation: operation, details: details)
        }

        public static func serializationError(
            type: String = "Card",
            details: String? = "Invalid key",
        ) -> AppError {
            .serializationError(type: type, details: details)
        }

        public static func deserializationError(
            type: String = "CardState",
            details: String? = "Type mismatch at 'status'",
        ) -> AppError {
            .deserializationError(type: type, details: details)
        }

        public static func validationError(field: String = "amount", reason: String = "must be positive") -> AppError {
            .validationError(field: field, reason: reason)
        }

        public static func systemUnavailable(details: String? = "Biometrics unavailable") -> AppError {
            .systemUnavailable(details: details)
        }

        public static func initializationFailed(details: String? = "Container setup failed") -> AppError {
            .initializationFailed(details: details)
        }

        public static func unknown(underlying: Error? = nil) -> AppError {
            .unknown(underlying: underlying)
        }
    }
#endif
