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
    /// Human-readable label for UI, e.g. "Frozen".
    var displayName: String {
        switch self {
        case .active: "Active"
        case .frozen: "Frozen"
        case .expired: "Expired"
        case .lost: "Lost"
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
