import Testing

/// Smoke test: proves the NexusDomain test target builds and runs.
@Suite("NexusDomain smoke")
struct NexusDomainSmokeTests {
    @Test func `target runs`() {
        #expect(true)
    }
}
