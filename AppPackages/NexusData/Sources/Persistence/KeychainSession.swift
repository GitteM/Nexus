import Foundation
import Security

/// The Keychain Services surface `KeychainWrapper` needs — the seam that
/// keeps the real `SecItem*` calls in one place, the same way
/// `WebSocketClientProtocol` confines `URLSessionWebSocketTask` for the
/// session manager.
///
/// **Why the seam exists.** SwiftData unit tests run on the iOS simulator in
/// standalone XCTest runners that are not signed with an
/// `application-identifier` entitlement, so the real Keychain answers every
/// call with `errSecMissingEntitlement` (-34018). Wrapping the calls behind
/// this protocol lets the wrapper's logic (attribute building, the
/// duplicate→update path, status mapping) be tested on every platform with a
/// scripted/emulating fake, while `SecurityKeychainSession` — the thin real
/// implementation — is exercised by a macOS-gated integration suite whose
/// process is not subject to the entitlement restriction.
///
/// The surface mirrors the four `SecItem*` calls with plain `[String: Any]`
/// attributes (bridged to `CFDictionary` by the real session) so a fake can
/// record or emulate them without touching Core Foundation pointers.
public protocol KeychainSessionProtocol: Sendable {
    /// `SecItemAdd`; returns the item's OSStatus.
    func add(attributes: [String: Any]) -> OSStatus

    /// `SecItemUpdate`; returns the OSStatus.
    func update(query: [String: Any], attributesToUpdate: [String: Any]) -> OSStatus

    /// `SecItemCopyMatching`; returns the OSStatus and, on success, the
    /// matched result (the wrapped value for a `kSecReturnData` query).
    func copyMatching(query: [String: Any]) -> (status: OSStatus, result: CFTypeRef?)

    /// `SecItemDelete`; returns the OSStatus.
    func delete(query: [String: Any]) -> OSStatus
}

/// The real Keychain session: a stateless passthrough to Keychain Services
/// (`import Security`). All `SecItem*` usage in Nexus lives here — nothing
/// else in the Data layer touches the Keychain API directly.
public struct SecurityKeychainSession: KeychainSessionProtocol {
    public init() {}

    public func add(attributes: [String: Any]) -> OSStatus {
        SecItemAdd(attributes as CFDictionary, nil)
    }

    public func update(query: [String: Any], attributesToUpdate: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
    }

    public func copyMatching(query: [String: Any]) -> (status: OSStatus, result: CFTypeRef?) {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result)
    }

    public func delete(query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}
