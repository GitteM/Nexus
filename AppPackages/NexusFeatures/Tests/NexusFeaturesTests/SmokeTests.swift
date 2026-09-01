import Testing

/// Day 1 (M0) smoke test: proves the NexusFeatures test target builds and runs.
/// Replaced by real suite coverage from M3 (tasks.md Day 9).
@Suite("NexusFeatures smoke")
struct NexusFeaturesSmokeTests {
    @Test func targetRuns() {
        #expect(true)
    }
}
