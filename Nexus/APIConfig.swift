import Foundation

/// Build configuration access for the app target (architecture.md §7.1,
/// tasks.md Day 14).
///
/// Reads the `API_ENVIRONMENT` / `API_BASE_URL` values from Info.plist
/// (injected from `Debug.xcconfig` / `Release.xcconfig`). Debug builds run
/// in the `demo` environment with an empty base URL until a backend exists;
/// Release builds are `sandbox` and must never select the DEBUG-only mock
/// graph.
public enum APIConfig {
    /// The `API_ENVIRONMENT` value from Info.plist (`demo`, `sandbox`, …).
    public static let environment: String? =
        Bundle.main.infoDictionary?["API_ENVIRONMENT"] as? String

    /// The configured backend base URL, or `nil` when none is set.
    public static var baseURL: URL? {
        guard let raw = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
              !raw.isEmpty
        else {
            return nil
        }
        return URL(string: raw)
    }
}
