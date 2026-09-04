import Entities
import Foundation

/// The transaction history screen's explicit UI state.
///
/// Views switch on this enum directly: `.loading` while the initial
/// fetch runs, `.loaded` when the card's balance and transaction list are
/// on screen, and `.error` when the fetch failed. `AppError` is
/// `Equatable`, so the whole enum is testable.
public enum TransactionHistoryViewState: Equatable {
    case loading
    case loaded
    case error(AppError)
}

public extension TransactionHistoryViewState {
    /// The `AppError` behind `.error`, or `nil` for every other state.
    var error: AppError? {
        if case let .error(error) = self {
            return error
        }
        return nil
    }

    var errorMessage: String? {
        error?.errorDescription
    }

    var recoverySuggestion: String? {
        error?.recoverySuggestion
    }
}
