import Foundation

/// User preferences, persisted via SwiftData.
///
/// Deliberately minimal — add a field only when a rule needs it.
public struct Settings: Codable, Sendable, Equatable {
    public var notificationsEnabled: Bool
    public var hapticsEnabled: Bool

    public init(notificationsEnabled: Bool = true, hapticsEnabled: Bool = true) {
        self.notificationsEnabled = notificationsEnabled
        self.hapticsEnabled = hapticsEnabled
    }
}

public extension Settings {
    /// Demo/default preferences for previews and tests.
    static let mockDefaults = Settings()
}
