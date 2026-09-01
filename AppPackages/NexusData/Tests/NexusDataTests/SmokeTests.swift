import Testing

/// Day 1 (M0) smoke test: proves the NexusData test target builds and runs.
/// Replaced by real suite coverage from M2 (tasks.md Day 5).
@Suite("NexusData smoke")
struct NexusDataSmokeTests {
    @Test func `target runs`() {
        #expect(true)
    }
}
