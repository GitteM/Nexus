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

extension CardStatus {
    /// Human-readable label for UI, e.g. "Frozen". Localized through the
    /// app's String Catalog at lookup time.
    public var displayName: String {
        switch self {
        case .active: String(localized: "Active")
        case .frozen: String(localized: "Frozen")
        case .expired: String(localized: "Expired")
        case .lost: String(localized: "Lost")
        }
    }

    /// SF Symbol name used by the UI for this status.
    public var icon: String {
        switch self {
        case .active: "checkmark.circle.fill"
        case .frozen: "snowflake"
        case .expired: "clock.badge.exclamationmark"
        case .lost: "exclamationmark.triangle.fill"
        }
    }
}

extension CardStatus {
    /// Whether a card in this status may run `command` — the lifecycle
    /// legality `CardDetailModel` enforces and the card-detail view reflects.
    ///
    /// Pure domain knowledge, deliberately free of session state: a caller
    /// holding extra context (e.g. "a replacement was already requested")
    /// layers that on top of this rule rather than duplicating it.
    public func permits(_ command: CardCommandType) -> Bool {
        switch command {
        case .freeze:
            self == .active
        case .unfreeze:
            self == .frozen
        case .reportLost, .reportStolen:
            self != .expired && self != .lost
        case .requestReplacement:
            self == .lost
        case .setSpendingLimit:
            self == .active || self == .frozen
        case .unknown:
            false
        }
    }
}
