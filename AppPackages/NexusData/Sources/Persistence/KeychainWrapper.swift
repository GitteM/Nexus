import Entities
import Foundation
import Security

/// Keychain access for credentials.
///
/// **The only place credentials may live.** Card numbers, CVV, and auth
/// tokens are never persisted in plaintext to SwiftData, caches, configs, or
/// logs — auth tokens go here, in the system Keychain, as generic-password
/// items scoped to `service` + `account`.
///
/// Security posture:
/// - Items are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`:
///   readable only while the device is unlocked, never migrated to iCloud or
///   a backup. The app reads credentials on launch while the device is
///   unlocked, so this is sufficient for the session token.
/// - No value is ever logged or embedded in an `AppError` message — failures
///   carry the OSStatus code only (display-safe).
/// - Reads return raw `Data`; callers decode their own token format.
///
/// The `SecItem*` calls themselves are confined behind
/// `KeychainSessionProtocol` (`SecurityKeychainSession` in production) so
/// the wrapper's logic is testable on platforms where the standalone test
/// runner has no Keychain entitlement (see `KeychainSession` documentation).
/// The wrapper is a stateless `Sendable` value over its session — safe to
/// share across concurrency domains.
public struct KeychainWrapper: Sendable {
    /// The Keychain "service" attribute scoping this wrapper's items (use the
    /// app's bundle id in production; tests pass a unique value).
    public let service: String

    private let session: any KeychainSessionProtocol

    /// Creates a wrapper over the real Keychain (`SecurityKeychainSession`).
    public init(service: String) {
        self.init(service: service, session: SecurityKeychainSession())
    }

    /// Creates a wrapper over a specific session (tests inject a fake).
    public init(service: String, session: any KeychainSessionProtocol) {
        self.service = service
        self.session = session
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
        let status = session.add(attributes: attributes)
        guard status != errSecSuccess else {
            return
        }
        // A duplicate item means the account already exists: update it.
        // Every other status is a real failure.
        guard status == errSecDuplicateItem else {
            throw Self.persistenceError(operation: "keychain_save", status: status)
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let updatedAttributes: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        let updateStatus = session.update(query: query, attributesToUpdate: updatedAttributes)
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
        let (status, result) = session.copyMatching(query: query)
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
        let status = session.delete(query: query)
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
