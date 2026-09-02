import Foundation

/// User preferences, persisted via SwiftData (architecture.md §4.1, §6.4).
///
/// Deliberately minimal — add a field only when a rule needs it
/// (architecture.md §12.3).
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
