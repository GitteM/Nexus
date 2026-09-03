@testable import Logging
import os
import ServiceProtocols
import Testing

/// Day 8 tests for the OSLog-backed `LoggingService` (architecture.md §7.2).
///
/// Asserting that a message physically reached the unified log is not
/// meaningful in a unit test; what matters is the mapping contract — every
/// Domain `LogLevel` maps to exactly the `OSLogType` the architecture names
/// — and that logging at every level executes without error. Message
/// content (display-safe only) is a caller contract covered at the call
/// sites, not here (architecture.md §7.2: never log card numbers, CVV, or
/// tokens).
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

    @Test
    func `logs a display-safe message at every level without error`() {
        let logger = LoggingService()
        for level in [LogLevel.debug, .info, .notice, .error, .fault] {
            logger.log("display-safe test message", level: level)
        }
    }

    @Test
    func `exposes the architecture's default subsystem`() {
        #expect(LoggingService.defaultSubsystem == "com.nexusbank.app")
    }

    @Test
    func `scopes instances with a category`() {
        let logger = LoggingService(subsystem: "com.nexusbank.app", category: "session")
        logger.log("session scoped", level: .debug)
    }
}
