import Entities
import Foundation
import Testing

@Suite("Settings")
struct SettingsTests {
    // MARK: - Construction

    @Test func `defaults enable notifications and haptics`() {
        let settings = Settings()
        #expect(settings.notificationsEnabled)
        #expect(settings.hapticsEnabled)
    }

    @Test func `memberwise init sets all properties`() {
        let settings = Settings(notificationsEnabled: false, hapticsEnabled: false)
        #expect(!settings.notificationsEnabled)
        #expect(!settings.hapticsEnabled)
    }

    // MARK: - Equality

    @Test func `equality compares all properties`() {
        #expect(Settings() == Settings())
        #expect(Settings(notificationsEnabled: true, hapticsEnabled: true) != Settings(notificationsEnabled: false, hapticsEnabled: true))
    }

    // MARK: - Codable

    @Test func `codable round trip preserves all fields`() throws {
        let settings = Settings(notificationsEnabled: false, hapticsEnabled: true)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        #expect(decoded == settings)
    }

    // MARK: - Mocks

    @Test func `mock defaults match defaults`() {
        #expect(Settings.mockDefaults == Settings())
    }
}
