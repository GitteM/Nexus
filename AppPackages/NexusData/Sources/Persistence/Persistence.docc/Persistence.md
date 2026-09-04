# ``Persistence``

The durable and in-memory storage layer. `SwiftDataCardRepository` is the SwiftData-backed store for the managed card list (schema and `@Model` records stay internal to the module); `KeychainWrapper` is the only place credentials may live, scoped behind the injectable `KeychainSessionProtocol` seam with its real `SecurityKeychainSession` implementation. `CacheManager` is a bounded, TTL-aware in-memory cache for ephemeral, display-safe live state.

## Topics

### Durable card store

- ``SwiftDataCardRepository``

### Credential storage

- ``KeychainWrapper``
- ``KeychainSessionProtocol``
- ``SecurityKeychainSession``

### In-memory cache

- ``CacheManager``
