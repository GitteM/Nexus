import Foundation
import Testing

/// Smoke test: proves the hosted NexusTests bundle loads against
/// the Nexus app and that the app's bundle identifier is injected correctly.
@Suite("NexusTests smoke")
struct NexusHostedSmokeTests {
    @Test func `app bundle is injected`() {
        #expect(Bundle.main.bundleIdentifier == "com.nexusbank.app")
    }
}
