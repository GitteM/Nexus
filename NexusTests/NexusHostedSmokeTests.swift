import Foundation
import Testing

/// Day 1 (M0) smoke test: proves the hosted NexusTests bundle loads against
/// the Nexus app and that the app's bundle identifier is injected correctly.
/// Replaced by integration suites from M7 (tasks.md Day 14).
@Suite("NexusTests smoke")
struct NexusHostedSmokeTests {
    @Test func appBundleIsInjected() {
        #expect(Bundle.main.bundleIdentifier == "com.nexusbank.app")
    }
}
