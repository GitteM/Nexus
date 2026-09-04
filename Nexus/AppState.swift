import Entities
import Foundation

/// The app-level UI state (architecture.md §11.3, tasks.md Day 14).
///
/// Mirrors the screen-level view states at the top: the root view is a pure
/// function of this enum, and each state injects its own environment.
/// `AppError` is `Equatable`, so transitions are testable.
public enum AppState: Equatable {
    case initializing
    case loading
    case ready
    case disconnected
    case error(AppError)
}

public extension AppState {
    /// The `AppError` behind `.error`, or `nil` for every other state.
    var error: AppError? {
        if case let .error(error) = self {
            return error
        }
        return nil
    }
}
