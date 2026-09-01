import Foundation

/// Reads build-configuration values that flow xcconfig → Info.plist → Bundle
/// (architecture.md §7.1). No secrets live here; credentials are held in the
/// Keychain at runtime.
public extension Bundle {
    static let apiBaseURL: URL = {
        guard let string = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
              let url = URL(string: string)
        else {
            fatalError("API_BASE_URL missing from Info.plist")
        }
        return url
    }()
}
