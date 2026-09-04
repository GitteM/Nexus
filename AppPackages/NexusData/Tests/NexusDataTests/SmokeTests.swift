import Testing

/// Smoke test: proves the NexusData test target builds and runs.
@Suite("NexusData smoke")
struct NexusDataSmokeTests {
    @Test func `target runs`() {
        #expect(true)
    }
}
