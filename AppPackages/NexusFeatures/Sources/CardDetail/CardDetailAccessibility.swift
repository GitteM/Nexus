import Entities
import Foundation

/// The stable accessibility-identifier contract for the card detail screen.
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
public enum CardDetailAccessibility {
    /// The card detail screen container.
    public static let screen = "cardDetail.screen"

    /// The element that announces the card's current lifecycle status
    /// ("Active", "Frozen", …) — UI tests assert the freeze round trip
    /// against its label/value.
    public static let status = "cardDetail.status"

    /// The freeze action (visible on an active card).
    public static let freeze = "cardDetail.freeze"

    /// The unfreeze action (visible on a frozen card).
    public static let unfreeze = "cardDetail.unfreeze"

    /// The "report lost or stolen" entry point.
    public static let reportLostOrStolen = "cardDetail.reportLostOrStolen"

    /// The "request replacement" action (visible on a lost card).
    public static let requestReplacement = "cardDetail.requestReplacement"

    /// The per-period spending-limit row, e.g. "cardDetail.limit.daily".
    public static func limitRow(_ period: SpendingLimitPeriod) -> String {
        "cardDetail.limit.\(period.rawValue)"
    }

    /// The "Transactions" activity row, the entry to account activity.
    public static let transactions = "cardDetail.transactions"
}
