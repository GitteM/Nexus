import Foundation

/// The connection state of the app session (architecture.md §4.1).
///
/// Exposed by `SessionManagerProtocol.sessionStatus` and consumed by the UI:
/// `SessionStatusIndicator` renders it and `AppContainer` reacts to changes
/// (architecture.md §9.4, §11.2). `.connecting` covers the in-flight
/// `connect()` handshake; `.error` means the last attempt failed and the
/// session is not usable.
public enum SessionStatus: String, Codable, CaseIterable, Sendable, Equatable {
    case connecting
    case connected
    case disconnected
    case error
}

public extension SessionStatus {
    /// Human-readable label for UI, e.g. "Connected".
    var displayName: String {
        switch self {
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        case .error: "Connection Error"
        }
    }

    /// SF Symbol name used by the UI for this status.
    var icon: String {
        switch self {
        case .connecting: "arrow.triangle.2.circlepath"
        case .connected: "checkmark.circle.fill"
        case .disconnected: "wifi.slash"
        case .error: "exclamationmark.triangle.fill"
        }
    }
}
