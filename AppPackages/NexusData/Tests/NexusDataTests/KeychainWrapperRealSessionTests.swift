import Foundation
import Persistence
import Testing

/// Real-Keychain integration suite.
///
/// Runs only where the process holds a Keychain entitlement: standalone iOS
/// test runners (SPM package tests in the workspace TestPlan) are not signed
/// with an `application-identifier` entitlement, so the simulator Keychain
/// answers every `SecItem*` call with `errSecMissingEntitlement` (-34018).
/// On macOS the `swift test` runner is not subject to that restriction, so
/// this suite proves the real `SecurityKeychainSession` passthrough and the
/// actual Keychain round-trip there. The wrapper's logic itself is covered
/// on every platform by `KeychainWrapperTests` over `FakeKeychainSession`.
private enum RealKeychainAvailability {
    #if os(macOS)
        static let available = true
    #else
        static let available = false
    #endif
}

@Suite("KeychainWrapper (real Keychain)", .enabled(if: RealKeychainAvailability.available))
struct KeychainWrapperRealSessionTests {
    private func makeWrapper() -> KeychainWrapper {
        KeychainWrapper(service: "nexus.tests.real.\(UUID().uuidString)")
    }

    @Test
    func `real keychain save read delete round trip`() throws {
        let wrapper = makeWrapper()
        let token = Data("real-session-token-123".utf8)
        defer { try? wrapper.delete(account: "auth-token") }

        try wrapper.save(token, account: "auth-token")
        #expect(try wrapper.data(forAccount: "auth-token") == token)

        try wrapper.delete(account: "auth-token")
        #expect(try wrapper.data(forAccount: "auth-token") == nil)
    }

    @Test
    func `real keychain missing account reads as nil`() throws {
        let wrapper = makeWrapper()
        #expect(try wrapper.data(forAccount: "never-saved") == nil)
    }

    @Test
    func `real keychain overwrite replaces value`() throws {
        let wrapper = makeWrapper()
        defer { try? wrapper.delete(account: "auth-token") }

        try wrapper.save(Data("old".utf8), account: "auth-token")
        try wrapper.save(Data("new".utf8), account: "auth-token")
        #expect(try wrapper.data(forAccount: "auth-token") == Data("new".utf8))
    }
}
