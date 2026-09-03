import Entities
import Foundation
import Security

/// Keychain access for credentials (architecture.md §6.4, tasks.md Day 7).
///
/// **The only place credentials may live.** Card numbers, CVV, and auth
/// tokens are never persisted in plaintext to SwiftData, caches, configs, or
/// logs (architecture.md §6.4, §7.2) — auth tokens go here, in the system
/// Keychain, as generic-password items scoped to `service` + `account`.
///
/// Security posture:
/// - Items are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`:
///   readable only while the device is unlocked, never migrated to iCloud or
///   a backup. The app reads credentials on launch while the device is
///   unlocked, so this is sufficient for the v1.0 session token.
/// - No value is ever logged or embedded in an `AppError` message — failures
///   carry the OSStatus code only (display-safe, architecture.md §7.2).
/// - Reads return raw `Data`; callers decode their own token format.
///
/// Thread-safety: `SecItem*` calls are thread-safe, and the wrapper is a
/// stateless `Sendable` value — safe to share across concurrency domains.
public struct KeychainWrapper: Sendable {
    /// The Keychain "service" attribute scoping this wrapper's items (use the
    /// app's bundle id in production; tests pass a unique value).
    public let service: String

    public init(service: String) {
        self.service = service
    }

    // MARK: - Public API

    /// Stores `data` under `account`, replacing any existing item for the
    /// same `service` + `account`.
    ///
    /// Throws `AppError.persistenceError(operation: "keychain_save")` when
    /// the Keychain rejects the write.
    public func save(_ data: Data, account: String) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status != errSecSuccess else {
            return
        }
        // A duplicate item means the account already exists: update it.
        // Every other status is a real failure.
        guard status == errSecDuplicateItem else {
            throw Self.persistenceError(operation: "keychain_save", status: status)
        }
        let update: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let updatedAttributes: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        let updateStatus = SecItemUpdate(update as CFDictionary, updatedAttributes as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw Self.persistenceError(operation: "keychain_save", status: updateStatus)
        }
    }

    /// The stored data for `account`, or `nil` when no item exists.
    ///
    /// Throws `AppError.persistenceError(operation: "keychain_read")` only on
    /// real Keychain failures — a missing item is `nil`, not an error.
    public func data(forAccount account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else {
            return nil
        }
        guard status == errSecSuccess else {
            throw Self.persistenceError(operation: "keychain_read", status: status)
        }
        return result as? Data
    }

    /// Removes the item for `account`. Removing an unknown account is a
    /// no-op (idempotent cleanup).
    ///
    /// Throws `AppError.persistenceError(operation: "keychain_delete")` when
    /// the Keychain rejects the deletion.
    public func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Self.persistenceError(operation: "keychain_delete", status: status)
        }
    }

    // MARK: - Error mapping

    /// Maps a Keychain `OSStatus` to `AppError.persistenceError` with the
    /// operation context. The message carries the status code and the
    /// system's description — never any credential data.
    private static func persistenceError(operation: String, status: OSStatus) -> AppError {
        let details = if let message = SecCopyErrorMessageString(status, nil) as String? {
            "Keychain status \(status): \(message)"
        } else {
            "Keychain status \(status)"
        }
        return AppError.persistenceError(operation: operation, details: details)
    }
}
