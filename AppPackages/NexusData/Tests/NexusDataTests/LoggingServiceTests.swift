@testable import Logging
import os
import ServiceProtocols
import Testing

/// Tests for the OSLog-backed `LoggingService`.
///
/// Asserting that a message physically reached the unified log is not
/// meaningful in a unit test; what matters is the mapping contract — every
/// Domain `LogLevel` maps to exactly the `OSLogType` that contract names.
/// Message content (display-safe only) is a caller contract covered at the
/// call sites, not here: never log card numbers, CVV, or tokens.
@Suite("LoggingService")
struct LoggingServiceTests {
    /// Parameterized over every `LogLevel`: the mapping must land on the
    /// documented `OSLogType` (debug→.debug, info→.info, notice→.default,
    /// error→.error, fault→.fault).
    @Test(arguments: [
        (LogLevel.debug, OSLogType.debug),
        (.info, OSLogType.info),
        (.notice, OSLogType.default),
        (.error, OSLogType.error),
        (.fault, OSLogType.fault),
    ])
    func `maps every LogLevel to its OSLogType`(level: LogLevel, expectedType: OSLogType) {
        let mapped = LoggingService.osLogType(for: level)
        #expect(mapped == expectedType)
    }
}
