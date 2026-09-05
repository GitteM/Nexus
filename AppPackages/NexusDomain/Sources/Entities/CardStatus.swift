import Foundation

/// The lifecycle status of a card.
///
/// Encoded by its raw value on the wire, e.g. `"frozen"`.
public enum CardStatus: String, Codable, CaseIterable, Sendable, Equatable {
    case active
    case frozen
    case expired
    case lost
}

public extension CardStatus {
    /// Human-readable label for UI, e.g. "Frozen". Localized through the
    /// app's String Catalog at lookup time.
    var displayName: String {
        switch self {
        case .active: String(localized: "Active")
        case .frozen: String(localized: "Frozen")
        case .expired: String(localized: "Expired")
        case .lost: String(localized: "Lost")
        }
    }

    /// SF Symbol name used by the UI for this status.
    var icon: String {
        switch self {
        case .active: "checkmark.circle.fill"
        case .frozen: "snowflake"
        case .expired: "clock.badge.exclamationmark"
        case .lost: "exclamationmark.triangle.fill"
        }
    }
}
