import Foundation

/// A navigation destination with the data it needs (architecture.md §8,
/// tasks.md Day 9).
///
/// `Route` is `Hashable` so it can drive a `NavigationStack` path
/// (`navigationDestination(for: Route.self)`), and it carries data
/// (`.cardDetail(cardID:)`) so destination views never reach back into a
/// shared store to find their payload. There is no `.back` case — going back
/// is a router *action*, not a destination.
///
/// The route → view mapping lives in the app target, the only place that
/// knows both routes and views (§11.3); the `Navigation` target itself stays
/// free of Presentation imports and package cycles.
public enum Route: Hashable, Sendable {
    /// The card detail screen for one managed card.
    case cardDetail(cardID: String)

    /// The per-card transaction history (balance header + searchable feed).
    case transactionHistory(cardID: String)

    /// The detail screen for one transaction.
    case transactionDetail(cardID: String, transactionID: String)
}
