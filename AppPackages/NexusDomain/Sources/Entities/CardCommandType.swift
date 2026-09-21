import Foundation

/// The kind of outgoing card action.
///
/// Encoded by its raw value on the wire, e.g. `"freeze"`. Unlike
/// `CardType`/`CardStatus`, unknown wire values decode to `.unknown` instead
/// of throwing — the stub keeps the app running when the backend ships an
/// action this version does not know yet.
public enum CardCommandType: String, Codable, CaseIterable, Sendable, Equatable {
    case freeze
    case unfreeze
    case reportLost
    case reportStolen
    case requestReplacement
    case setSpendingLimit
    case unknown
}

extension CardCommandType {
    /// Stable English diagnostic label for logs and demo data. Not
    /// user-facing copy and intentionally not localized: call sites are
    /// diagnostics, and log output must stay language-independent.
    public var displayName: String {
        switch self {
        case .freeze: "Freeze"
        case .unfreeze: "Unfreeze"
        case .reportLost: "Report Lost"
        case .reportStolen: "Report Stolen"
        case .requestReplacement: "Request Replacement"
        case .setSpendingLimit: "Set Spending Limit"
        case .unknown: "Unknown"
        }
    }
}

extension CardCommandType {
    /// Unknown wire values decode to `.unknown` rather than throwing.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = CardCommandType(rawValue: rawValue) ?? .unknown
    }
}
