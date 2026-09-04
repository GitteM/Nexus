import Foundation

/// The stable accessibility-identifier contract for the dashboard screens.
///
/// Views set `.accessibilityIdentifier` from this namespace and the UI tests
/// (`NexusUITests`) reference the same helpers — never literal strings in
/// either place. Because both sides share the source, renaming an identifier
/// or changing its format breaks the *build*, not just the test run.
/// Identifiers are a UI contract, so they deliberately do not follow copy:
/// they stay stable while user-facing strings localize.
///
/// Rule: keep the emitted values stable once a feature ships; change them
/// here (and only here) when a screen structure genuinely changes.
public enum DashboardAccessibility {
    /// The swipeable managed-card carousel container.
    public static let carousel = "dashboard.carousel"

    /// One card front in the carousel.
    public static func card(_ cardID: String) -> String {
        "dashboard.card.\(cardID)"
    }

    /// One offer card in the offers row.
    public static func offer(_ offerID: String) -> String {
        "dashboard.offer.\(offerID)"
    }

    /// The add action on an offer card.
    public static func addOffer(_ offerID: String) -> String {
        "dashboard.offer.add.\(offerID)"
    }

    /// The "added" state marker on an offer card whose offer is already
    /// managed.
    public static func addedOffer(_ offerID: String) -> String {
        "dashboard.offer.added.\(offerID)"
    }
}
