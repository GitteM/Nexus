import Foundation
import Persistence
import Testing

/// Tests for `KeychainWrapper` over the real Keychain (tasks.md Day 7).
///
/// Every test runs against a UUID-unique `service` so parallel test
/// execution and leftover items from earlier runs can never collide, and
/// each test removes its own items when done.
@Suite("KeychainWrapper")
struct KeychainWrapperTests {
    private func makeWrapper() -> KeychainWrapper {
        KeychainWrapper(service: "nexus.tests.\(UUID().uuidString)")
    }

    private let sampleToken = Data("session-token-abc-123".utf8)

    @Test
    func saveThenReadRoundTrips() throws {
        let wrapper = makeWrapper()
        let account = "auth-token"
        defer { try? wrapper.delete(account: account) }

        try wrapper.save(sampleToken, account: account)
        #expect(try wrapper.data(forAccount: account) == sampleToken)
    }

    @Test
    func missingAccountReadsAsNil() throws {
        let wrapper = makeWrapper()
        #expect(try wrapper.data(forAccount: "never-saved") == nil)
    }

    @Test
    func deleteRemovesItemAndIsIdempotent() throws {
        let wrapper = makeWrapper()
        let account = "auth-token"
        try wrapper.save(sampleToken, account: account)
        try wrapper.delete(account: account)
        #expect(try wrapper.data(forAccount: account) == nil)

        // Deleting again is a no-op, not an error.
        try wrapper.delete(account: account)
    }

    @Test
    func overwriteReplacesValue() throws {
        let wrapper = makeWrapper()
        let account = "auth-token"
        defer { try? wrapper.delete(account: account) }

        try wrapper.save(Data("old".utf8), account: account)
        try wrapper.save(Data("new".utf8), account: account)
        #expect(try wrapper.data(forAccount: account) == Data("new".utf8))
    }

    @Test
    func servicesAreIsolated() throws {
        let first = KeychainWrapper(service: "nexus.tests.first.\(UUID().uuidString)")
        let second = KeychainWrapper(service: "nexus.tests.second.\(UUID().uuidString)")
        let account = "shared-account"
        defer {
            try? first.delete(account: account)
            try? second.delete(account: account)
        }

        try first.save(Data("first-service".utf8), account: account)
        try second.save(Data("second-service".utf8), account: account)
        #expect(try first.data(forAccount: account) == Data("first-service".utf8))
        #expect(try second.data(forAccount: account) == Data("second-service".utf8))
    }

    @Test
    func arbitraryBytesRoundTrip() throws {
        let wrapper = makeWrapper()
        let account = "opaque-token"
        defer { try? wrapper.delete(account: account) }

        // Binary data with zero bytes and high-bit values — Keychain stores
        // opaque Data, never interpreting it as text.
        let bytes = Data([0x00, 0x01, 0x7F, 0x80, 0xFF, 0x42])
        try wrapper.save(bytes, account: account)
        #expect(try wrapper.data(forAccount: account) == bytes)
    }

    @Test
    func accountsAreIsolatedUnderOneService() throws {
        let wrapper = makeWrapper()
        defer {
            try? wrapper.delete(account: "token-a")
            try? wrapper.delete(account: "token-b")
        }

        try wrapper.save(Data("a".utf8), account: "token-a")
        try wrapper.save(Data("b".utf8), account: "token-b")
        #expect(try wrapper.data(forAccount: "token-a") == Data("a".utf8))
        #expect(try wrapper.data(forAccount: "token-b") == Data("b".utf8))
    }
}
