import Foundation

/// Timeout policy for the UI suites (tasks.md Day 13, PR hardening).
///
/// Every wait in the UI tests goes through `seconds(_:)` so the tuning is
/// one place, not literals scattered through assertions. The base values
/// are chosen for a warm local simulator; slow runners (CI cold starts,
/// shared machines) can override without editing tests:
///
/// - `NEXUS_UI_TEST_TIMEOUT` — absolute seconds for every wait.
/// - `NEXUS_UI_TEST_TIMEOUT_SCALE` — multiplier on the base values
///   (e.g. `2.0` doubles every wait).
///
/// An invalid value falls back to the base (never zero, never negative).
enum UITestTimeout {
    /// The seconds to wait for one step of the base value `base`.
    static func seconds(_ base: TimeInterval) -> TimeInterval {
        let environment = ProcessInfo.processInfo.environment
        if let raw = environment["NEXUS_UI_TEST_TIMEOUT"],
           let absolute = TimeInterval(raw), absolute > 0
        {
            return absolute
        }
        if let raw = environment["NEXUS_UI_TEST_TIMEOUT_SCALE"],
           let scale = TimeInterval(raw), scale > 0
        {
            return base * scale
        }
        return base
    }
}
