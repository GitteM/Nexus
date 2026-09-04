import Entities
import Foundation
import os
import Persistence
import Security
import Testing

/// Behavior-emulating fake for `KeychainSessionProtocol` (test target only):
/// a dictionary-backed store that mirrors the Keychain semantics the wrapper
/// relies on — add/duplicate, update, copy-matching by `service`+`account`,
/// and delete. The real Security calls stay confined behind the seam (see
/// `KeychainSession`); this fake keeps wrapper tests deterministic on every
/// platform, including the simulator gate where the standalone test runner
/// has no Keychain entitlement.
final class FakeKeychainSession: KeychainSessionProtocol {
    private struct Item {
        var data: Data
    }

    private let storage = OSAllocatedUnfairLock(initialState: (items: [String: Item](), forcedStatus: nil as OSStatus?))

    /// When set, `add` returns this status instead of storing (used to
    /// exercise the wrapper's error mapping, e.g. -34018).
    var forcedAddStatus: OSStatus? {
        get { storage.withLock { $0.forcedStatus } }
        set { storage.withLock { $0.forcedStatus = newValue } }
    }

    private func key(service: String?, account: String?) -> String {
        "\(service ?? "").\(account ?? "")"
    }

    func add(attributes: [String: Any]) -> OSStatus {
        if let forced = storage.withLock({ $0.forcedStatus }) {
            return forced
        }
        let service = attributes[kSecAttrService as String] as? String
        let account = attributes[kSecAttrAccount as String] as? String
        guard let data = attributes[kSecValueData as String] as? Data else {
            return errSecParam
        }
        let key = key(service: service, account: account)
        return storage.withLock { state in
            guard state.items[key] == nil else {
                return errSecDuplicateItem
            }
            state.items[key] = Item(data: data)
            return errSecSuccess
        }
    }

    func update(query: [String: Any], attributesToUpdate: [String: Any]) -> OSStatus {
        let service = query[kSecAttrService as String] as? String
        let account = query[kSecAttrAccount as String] as? String
        guard let data = attributesToUpdate[kSecValueData as String] as? Data else {
            return errSecParam
        }
        let key = key(service: service, account: account)
        return storage.withLock { state in
            guard state.items[key] != nil else {
                return errSecItemNotFound
            }
            state.items[key] = Item(data: data)
            return errSecSuccess
        }
    }

    func copyMatching(query: [String: Any]) -> (status: OSStatus, result: CFTypeRef?) {
        let service = query[kSecAttrService as String] as? String
        let account = query[kSecAttrAccount as String] as? String
        let key = key(service: service, account: account)
        let item = storage.withLock { $0.items[key] }
        guard let item else {
            return (errSecItemNotFound, nil)
        }
        return (errSecSuccess, item.data as CFTypeRef)
    }

    func delete(query: [String: Any]) -> OSStatus {
        let service = query[kSecAttrService as String] as? String
        let account = query[kSecAttrAccount as String] as? String
        let key = key(service: service, account: account)
        return storage.withLock { state in
            guard state.items[key] != nil else {
                return errSecItemNotFound
            }
            state.items.removeValue(forKey: key)
            return errSecSuccess
        }
    }
}

/// Logic tests for `KeychainWrapper` over the fake session — they run on
/// every platform, including the iOS simulator gate.
@Suite("KeychainWrapper")
struct KeychainWrapperTests {
    private func makeWrapper() -> (KeychainWrapper, FakeKeychainSession) {
        let session = FakeKeychainSession()
        let wrapper = KeychainWrapper(
            service: "nexus.tests.\(UUID().uuidString)",
            session: session,
        )
        return (wrapper, session)
    }

    private let sampleToken = Data("session-token-abc-123".utf8)

    @Test
    func `save then read round trips`() throws {
        let (wrapper, _) = makeWrapper()
        try wrapper.save(sampleToken, account: "auth-token")
        #expect(try wrapper.data(forAccount: "auth-token") == sampleToken)
    }

    @Test
    func `missing account reads as nil`() throws {
        let (wrapper, _) = makeWrapper()
        #expect(try wrapper.data(forAccount: "never-saved") == nil)
    }

    @Test
    func `delete removes item and is idempotent`() throws {
        let (wrapper, _) = makeWrapper()
        try wrapper.save(sampleToken, account: "auth-token")
        try wrapper.delete(account: "auth-token")
        #expect(try wrapper.data(forAccount: "auth-token") == nil)

        // Deleting again is a no-op, not an error.
        try wrapper.delete(account: "auth-token")
    }

    @Test
    func `overwrite replaces value`() throws {
        let (wrapper, _) = makeWrapper()
        try wrapper.save(Data("old".utf8), account: "auth-token")
        try wrapper.save(Data("new".utf8), account: "auth-token")
        #expect(try wrapper.data(forAccount: "auth-token") == Data("new".utf8))
    }

    @Test
    func `services are isolated`() throws {
        let firstSession = FakeKeychainSession()
        let secondSession = FakeKeychainSession()
        let first = KeychainWrapper(service: "nexus.tests.first", session: firstSession)
        let second = KeychainWrapper(service: "nexus.tests.second", session: secondSession)

        try first.save(Data("first-service".utf8), account: "shared-account")
        try second.save(Data("second-service".utf8), account: "shared-account")
        #expect(try first.data(forAccount: "shared-account") == Data("first-service".utf8))
        #expect(try second.data(forAccount: "shared-account") == Data("second-service".utf8))
    }

    @Test
    func `arbitrary bytes round trip`() throws {
        let (wrapper, _) = makeWrapper()
        // Binary data with zero bytes and high-bit values — Keychain stores
        // opaque Data, never interpreting it as text.
        let bytes = Data([0x00, 0x01, 0x7F, 0x80, 0xFF, 0x42])
        try wrapper.save(bytes, account: "opaque-token")
        #expect(try wrapper.data(forAccount: "opaque-token") == bytes)
    }

    @Test
    func `accounts are isolated under one service`() throws {
        let (wrapper, _) = makeWrapper()
        try wrapper.save(Data("a".utf8), account: "token-a")
        try wrapper.save(Data("b".utf8), account: "token-b")
        #expect(try wrapper.data(forAccount: "token-a") == Data("a".utf8))
        #expect(try wrapper.data(forAccount: "token-b") == Data("b".utf8))
    }

    @Test
    func `keychain rejection surfaces as persistenceError`() throws {
        let (wrapper, session) = makeWrapper()
        // -34018 is exactly what the real Keychain answers in an unentitled
        // standalone iOS test runner — the wrapper must map it, not crash.
        session.forcedAddStatus = OSStatus(errSecMissingEntitlement)

        do {
            try wrapper.save(sampleToken, account: "auth-token")
            Issue.record("Expected the keychain rejection to surface as AppError.")
        } catch let error as AppError {
            #expect(error.category == .data)
            guard case let .persistenceError(operation, details) = error else {
                Issue.record("Expected .persistenceError, got \(error).")
                return
            }
            #expect(operation == "keychain_save")
            #expect(details?.contains("34018") == true)
        } catch {
            Issue.record("Expected AppError, got \(error).")
        }
        #expect(try wrapper.data(forAccount: "auth-token") == nil)
    }
}
