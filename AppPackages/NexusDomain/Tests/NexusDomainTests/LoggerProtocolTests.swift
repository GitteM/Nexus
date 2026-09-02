import Entities
import ServiceProtocols
import Testing

@Suite("LoggerProtocol")
@MainActor
struct LoggerProtocolTests {
    @Test func `log records the message with its level`() {
        let logger = TestLogger()
        logger.log("card loaded", level: .info)
        logger.log("decode failed", level: .error)

        #expect(logger.entries == [
            LogEntry(message: "card loaded", level: .info),
            LogEntry(message: "decode failed", level: .error),
        ])
    }

    @Test func `log preserves the full level taxonomy`() {
        let logger = TestLogger()
        for level in allLevels {
            logger.log("message", level: level)
        }
        #expect(logger.entries.map(\.level) == allLevels)
    }

    /// The five severities the taxonomy must expose (architecture.md §4.3).
    private var allLevels: [LogLevel] {
        [.debug, .info, .notice, .error, .fault]
    }
}

@Suite("LogLevel")
struct LogLevelTests {
    @Test func `severities are distinct and exhaustively covered`() {
        // The exhaustive switch pins the taxonomy: adding a case breaks the
        // compile until it is named here.
        for level in [LogLevel.debug, .info, .notice, .error, .fault] {
            let name = switch level {
            case .debug: "debug"
            case .info: "info"
            case .notice: "notice"
            case .error: "error"
            case .fault: "fault"
            }
            #expect(!name.isEmpty)
        }
        #expect(LogLevel.debug != .error)
        #expect(LogLevel.notice != .fault)
    }
}
