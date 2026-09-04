import Foundation

/// Grouping for `AppError` cases: analytics, logging, and policy decisions.
///
/// Encoded by its raw value on the wire, e.g. `"network"`.
public enum ErrorCategory: String, Codable, CaseIterable, Sendable, Equatable {
    case network
    case card
    case account
    case data
    case system
    case initialization
    case unknown
}

public extension ErrorCategory {
    /// Human-readable label for UI and analytics, e.g. "Network".
    var displayName: String {
        switch self {
        case .network: "Network"
        case .card: "Card"
        case .account: "Account"
        case .data: "Data"
        case .system: "System"
        case .initialization: "Initialization"
        case .unknown: "Unknown"
        }
    }
}
