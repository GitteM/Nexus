import Entities
import Foundation

/// The card detail screen's explicit UI state (architecture.md §9.1–§9.2,
/// tasks.md Day 12).
///
/// Views switch on this enum directly (§9.3): `.loading` while the initial
/// fetch runs, `.loaded` when the card is on screen, and `.error` when the
/// fetch failed (including the card not being found). `AppError` is
/// `Equatable`, so the whole enum is testable — model tests assert exact
/// state transitions against it. There is deliberately no `.empty` case: a
/// detail screen is per-card, and a card that cannot be found is an error,
/// not an empty state.
public enum CardDetailViewState: Equatable {
    case loading
    case loaded
    case error(AppError)
}

public extension CardDetailViewState {
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
