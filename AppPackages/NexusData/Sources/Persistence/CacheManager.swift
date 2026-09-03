import Foundation

/// Bounded in-memory cache for ephemeral live state (architecture.md §6.4,
/// tasks.md Day 7: "`CacheManager` actor (NSCache, 50 items / 25 MB, TTL) for
/// ephemeral live state").
///
/// Two guarantees, enforced at different layers:
///
/// - **Policy that must be deterministic** — the 50-item cap and per-entry
///   TTL — is enforced by the actor itself, mirroring the per-id LRU policy
///   `CardStateDataSource` already uses (architecture.md §6.1): the actor
///   keeps a recency list, evicts the least-recently-used entry past the
///   cap, and drops expired entries on read (an expired entry is reported
///   missing and removed, never served).
/// - **Memory pressure** is delegated to an `NSCache` (`countLimit` 50,
///   `totalCostLimit` 25 MB) as the architecture prescribes. `NSCache`
///   eviction is a *hint* — it may drop entries early under memory pressure
///   and its byte accounting is approximate — so callers must treat the
///   cache as lossy either way, which an ephemeral cache is allowed to be.
///   Callers storing large payloads pass an estimated byte `cost` so the
///   byte budget means something; the default cost of 1 keeps tiny values
///   out of the byte accounting.
///
/// The cache stores **display-safe data only** (architecture.md §6.4): last
/// four digits, balances, preferences. Never card numbers, CVV, or auth
/// tokens — credentials belong in `KeychainWrapper`.
///
/// Why not `@unchecked Sendable` to share the `NSCache`? The actor *is* the
/// synchronization: `NSCache` is not `Sendable`, so it never leaves this
/// actor's isolation domain (architecture.md §6.2: actor isolation is the
/// synchronization — no `DispatchQueue` barriers, no `@unchecked Sendable`).
public actor CacheManager {
    /// Default maximum number of cached entries (architecture.md §6.4: 50).
    public static let defaultItemLimit = 50

    /// Default byte budget for cached entries (architecture.md §6.4: 25 MB).
    public static let defaultTotalCostLimit = 25 * 1024 * 1024

    /// An `NSCache` requires class instances; the box keeps the value opaque
    /// to `NSCache` while the actor stays the only reader of its payload.
    private final class CacheBox {
        let value: any Sendable

        init(value: any Sendable) {
            self.value = value
        }
    }

    private struct Metadata {
        /// When the entry expires; `nil` means it never does.
        var expiresAt: Date?
    }

    private let cache: NSCache<NSString, CacheBox>
    private let itemLimit: Int
    private let defaultTTL: TimeInterval?

    /// Entry bookkeeping the actor enforces deterministically.
    /// `keysByRecency` is most-recently-used first (identical to
    /// `CardStateDataSource`'s LRU list).
    private var metadataByKey: [String: Metadata] = [:]
    private var keysByRecency: [String] = []

    /// - Parameters:
    ///   - itemLimit: Hard cap on entries, enforced by LRU eviction. Defaults
    ///     to `defaultItemLimit` (50).
    ///   - totalCostLimit: Byte budget passed to the backing `NSCache`
    ///     (`totalCostLimit`); eviction under it is best-effort. Defaults to
    ///     `defaultTotalCostLimit` (25 MB).
    ///   - defaultTTL: Freshness window applied to entries stored without an
    ///     explicit `ttl`. `nil` (the default) means entries never expire on
    ///     their own — they live until evicted by the cap, memory pressure,
    ///     or an explicit `remove`.
    public init(
        itemLimit: Int = CacheManager.defaultItemLimit,
        totalCostLimit: Int = CacheManager.defaultTotalCostLimit,
        defaultTTL: TimeInterval? = nil,
    ) {
        let cache = NSCache<NSString, CacheBox>()
        cache.countLimit = itemLimit
        cache.totalCostLimit = totalCostLimit
        self.cache = cache
        self.itemLimit = itemLimit
        self.defaultTTL = defaultTTL
    }

    // MARK: - Public API

    /// Stores one value under `key`, replacing any previous entry.
    ///
    /// - Parameters:
    ///   - value: The value to cache. Must be `Sendable` so the cache can
    ///     hold it safely behind the actor.
    ///   - key: Cache key (e.g. `"cards.4821"`).
    ///   - cost: Estimated byte cost of the value, charged against the
    ///     `totalCostLimit`. Defaults to 1 (out of the byte accounting).
    ///     The accounting is approximate: `NSCache` charges the number you
    ///     pass without measuring the value, and eviction under the byte
    ///     budget is best-effort (see the type documentation) — cost is a
    ///     hint for large payloads, not a hard byte bound.
    ///   - ttl: Freshness window for this entry; `nil` falls back to the
    ///     manager's `defaultTTL`.
    public func set(
        _ value: some Sendable,
        forKey key: String,
        cost: Int = 1,
        ttl: TimeInterval? = nil,
    ) {
        purgeExpiredIfNeeded()
        let effectiveTTL = ttl ?? defaultTTL
        metadataByKey[key] = Metadata(expiresAt: effectiveTTL.map { Date().addingTimeInterval($0) })
        cache.setObject(
            CacheBox(value: value),
            forKey: key as NSString,
            cost: max(cost, 1),
        )
        touch(key)
        enforceItemLimit()
    }

    /// The cached value for `key`, or `nil` when the entry is missing,
    /// expired, or holds a value of a different type.
    ///
    /// Reading an expired entry removes it — an expired cache entry is never
    /// served and never retained (the same rule
    /// `OffersDataSource.freshSnapshot` applies to stale offers,
    /// architecture.md §6.1).
    public func value<Value: Sendable>(forKey key: String) -> Value? {
        guard let box = cache.object(forKey: key as NSString) else {
            // The backing cache dropped the entry (memory pressure). Clean up
            // the actor-side bookkeeping so both views agree.
            metadataByKey.removeValue(forKey: key)
            keysByRecency.removeAll { $0 == key }
            return nil
        }
        guard let metadata = metadataByKey[key], !isExpired(metadata) else {
            remove(key: key)
            return nil
        }
        touch(key)
        return box.value as? Value
    }

    /// Removes one entry, if present.
    public func remove(key: String) {
        cache.removeObject(forKey: key as NSString)
        metadataByKey.removeValue(forKey: key)
        keysByRecency.removeAll { $0 == key }
    }

    /// Removes every entry (used by demo reset and cache invalidation).
    public func removeAll() {
        cache.removeAllObjects()
        metadataByKey.removeAll()
        keysByRecency.removeAll()
    }

    /// Number of entries the actor currently tracks (excluding entries the
    /// backing cache already dropped under memory pressure — those are
    /// cleaned lazily on access).
    public var count: Int {
        metadataByKey.count
    }

    // MARK: - Actor-enforced policy

    private func isExpired(_ metadata: Metadata) -> Bool {
        guard let expiresAt = metadata.expiresAt else {
            return false
        }
        return Date() >= expiresAt
    }

    /// Drops expired entries in bulk when a write arrives, so a long-lived
    /// cache does not fill with entries nobody read back. O(n) in the entry
    /// count; only runs on writes, and the count is capped at `itemLimit`.
    private func purgeExpiredIfNeeded() {
        let expired = metadataByKey.filter { isExpired($0.value) }.keys
        for key in expired {
            remove(key: key)
        }
    }

    /// Marks `key` as most-recently-used (matching `CardStateDataSource`
    /// recency semantics so the two caches evict alike).
    private func touch(_ key: String) {
        keysByRecency.removeAll { $0 == key }
        keysByRecency.insert(key, at: 0)
    }

    /// Evicts the least-recently-used entry while the actor-side count is
    /// over `itemLimit`. The backing cache's own `countLimit` is the same
    /// number, but `NSCache` eviction is a hint — the actor enforces the
    /// deterministic bound.
    private func enforceItemLimit() {
        while metadataByKey.count > itemLimit, let evicted = keysByRecency.last {
            remove(key: evicted)
        }
    }
}
