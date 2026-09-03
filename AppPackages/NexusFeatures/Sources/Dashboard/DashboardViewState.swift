import Entities
import Foundation

/// The dashboard screen's explicit UI state (architecture.md §9.1–§9.2,
/// tasks.md Day 10).
///
/// Views switch on this enum directly (§9.3): `.loading` while the initial
/// fetch runs, `.loaded` when cards or offers are on screen, `.empty` when
/// a fresh account has nothing to show yet, and `.error` when the fetch
/// failed. `AppError` is `Equatable`, so the whole enum is testable —
/// model tests assert exact state transitions against it.
public enum DashboardViewState: Equatable {
    case loading
    case loaded
    case empty
    case error(AppError)
}

public extension DashboardViewState {
    /// The `AppError` behind `.error`, or `nil` for every other state.
    var error: AppError? {
        if case let .error(error) = self {
            return error
        }
        return nil
    }

    /// User-facing headline for the `.error` state, forwarded from the
    /// error's own surface (§5); `nil` unless the state is `.error`.
    var errorMessage: String? {
        error?.errorDescription
    }

    /// Recovery guidance for the `.error` state, forwarded from the error's
    /// own surface (§5); `nil` unless the state is `.error`.
    var recoverySuggestion: String? {
        error?.recoverySuggestion
    }
}
