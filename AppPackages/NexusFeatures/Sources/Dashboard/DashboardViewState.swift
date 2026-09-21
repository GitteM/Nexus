import Entities
import Foundation

/// The dashboard screen's explicit UI state.
///
/// Views switch on this enum directly: `.loading` while the initial
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

extension DashboardViewState {
    /// The `AppError` behind `.error`, or `nil` for every other state.
    public var error: AppError? {
        if case let .error(error) = self {
            return error
        }
        return nil
    }
}
