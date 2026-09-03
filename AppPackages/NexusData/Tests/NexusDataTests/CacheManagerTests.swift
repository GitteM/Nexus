import Foundation
import Persistence
import Testing

/// Integration tests over the real `CacheManager` (tasks.md Day 7: "integration
/// tests over real `CacheManager` + repository") — no mocks, real actor and
/// real backing `NSCache`.
///
/// Deterministic policy (TTL expiry, the item cap) is actor-enforced, so the
/// tests assert exact behavior; the `NSCache` byte budget is a best-effort
/// hint under memory pressure and is deliberately not asserted.
@Suite("CacheManager")
struct CacheManagerTests {
    // MARK: - Basics

    @Test
    func `set and get round trip`() async {
        let cache = CacheManager()
        await cache.set("hello", forKey: "greeting")
        let value: String? = await cache.value(forKey: "greeting")
        #expect(value == "hello")
    }

    @Test
    func `missing key returns nil`() async {
        let cache = CacheManager()
        let value: String? = await cache.value(forKey: "absent")
        #expect(value == nil)
    }

    @Test
    func `wrong type reads as nil`() async {
        let cache = CacheManager()
        await cache.set(42, forKey: "number")
        let asString: String? = await cache.value(forKey: "number")
        let asInt: Int? = await cache.value(forKey: "number")
        #expect(asString == nil)
        #expect(asInt == 42)
    }

    @Test
    func `overwrite replaces value`() async {
        let cache = CacheManager()
        await cache.set("first", forKey: "key")
        await cache.set("second", forKey: "key")
        let value: String? = await cache.value(forKey: "key")
        #expect(value == "second")
        let count = await cache.count
        #expect(count == 1)
    }

    @Test
    func `remove and remove all`() async {
        let cache = CacheManager()
        await cache.set(1, forKey: "a")
        await cache.set(2, forKey: "b")
        await cache.remove(key: "a")
        #expect(await cache.value(forKey: "a") == Int?.none)
        #expect(await cache.value(forKey: "b") == 2)

        await cache.removeAll()
        #expect(await cache.value(forKey: "b") == Int?.none)
        #expect(await cache.count == 0)
    }

    // MARK: - TTL

    @Test
    func `entry expires after per set TTL`() async throws {
        let cache = CacheManager()
        await cache.set("fresh", forKey: "key", ttl: 0.05)
        #expect(await cache.value(forKey: "key") == "fresh")

        try await Task.sleep(for: .milliseconds(120))
        let value: String? = await cache.value(forKey: "key")
        #expect(value == nil)
    }

    @Test
    func `expired read removes entry`() async throws {
        let cache = CacheManager()
        await cache.set("fresh", forKey: "key", ttl: 0.05)
        try await Task.sleep(for: .milliseconds(120))
        _ = await cache.value(forKey: "key") as String?
        #expect(await cache.count == 0)
    }

    @Test
    func `default TTL applies when set omits TTL`() async throws {
        let cache = CacheManager(defaultTTL: 0.05)
        await cache.set("fresh", forKey: "key")
        #expect(await cache.value(forKey: "key") == "fresh")

        try await Task.sleep(for: .milliseconds(120))
        let value: String? = await cache.value(forKey: "key")
        #expect(value == nil)
    }

    @Test
    func `overwrite resets expiry`() async throws {
        let cache = CacheManager()
        await cache.set("short-lived", forKey: "key", ttl: 0.05)
        // The replacement is stored with no expiry (manager default is nil).
        await cache.set("long-lived", forKey: "key")
        try await Task.sleep(for: .milliseconds(120))
        let value: String? = await cache.value(forKey: "key")
        #expect(value == "long-lived")
    }

    @Test
    func `entry without TTL does not expire`() async throws {
        let cache = CacheManager()
        await cache.set("persistent", forKey: "key")
        try await Task.sleep(for: .milliseconds(120))
        let value: String? = await cache.value(forKey: "key")
        #expect(value == "persistent")
    }

    // MARK: - Item cap (actor-enforced LRU)

    @Test
    func `item cap evicts least recently used`() async {
        let cache = CacheManager(itemLimit: 3)
        await cache.set("a", forKey: "a")
        await cache.set("b", forKey: "b")
        await cache.set("c", forKey: "c")
        // Touch "a" so "b" becomes the least-recently-used.
        #expect(await cache.value(forKey: "a") == "a")
        await cache.set("d", forKey: "d")

        #expect(await cache.value(forKey: "a") == "a")
        #expect(await cache.value(forKey: "b") == String?.none)
        #expect(await cache.value(forKey: "c") == "c")
        #expect(await cache.value(forKey: "d") == "d")
        #expect(await cache.count == 3)
    }

    @Test
    func `overwriting keeps count flat`() async {
        let cache = CacheManager(itemLimit: 3)
        await cache.set("a", forKey: "a")
        await cache.set("b", forKey: "b")
        await cache.set("a", forKey: "a")
        #expect(await cache.count == 2)
    }

    @Test
    func `bulk writes stay within cap`() async {
        let cache = CacheManager(itemLimit: 50)
        for index in 0 ..< 200 {
            await cache.set(index, forKey: "key-\(index)")
        }
        #expect(await cache.count == 50)
        // The first 150 keys are gone (LRU), the last 50 remain.
        #expect(await cache.value(forKey: "key-0") == Int?.none)
        #expect(await cache.value(forKey: "key-199") == 199)
    }

    // MARK: - Cost parameter

    @Test
    func `cost parameter is accepted and value readable`() async {
        let cache = CacheManager()
        let payload = String(repeating: "x", count: 4096)
        await cache.set(payload, forKey: "large", cost: 4096)
        let value: String? = await cache.value(forKey: "large")
        #expect(value == payload)
    }

    // MARK: - Concurrency smoke

    @Test
    func `concurrent writes are race free`() async {
        let cache = CacheManager(itemLimit: 1000)
        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 200 {
                group.addTask {
                    await cache.set(index, forKey: "key-\(index)")
                }
            }
            await group.waitForAll()
        }
        #expect(await cache.count == 200)
        #expect(await cache.value(forKey: "key-42") == 42)
    }
}
