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
