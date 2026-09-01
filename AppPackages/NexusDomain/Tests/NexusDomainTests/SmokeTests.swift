import Testing

/// Day 1 (M0) smoke test: proves the NexusDomain test target builds and runs.
/// Replaced by real suite coverage from M1 (tasks.md Day 2).
@Suite("NexusDomain smoke")
struct NexusDomainSmokeTests {
    @Test func targetRuns() {
        #expect(true)
    }
}
