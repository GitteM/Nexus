/// Severity taxonomy for log messages (architecture.md §4.3).
///
/// Domain defines its own level enum instead of importing OSLog; the
/// Data-layer `LoggingService` maps these to `OSLogType` behind
/// `LoggerProtocol` (architecture.md §7.2).
public enum LogLevel: Sendable, Equatable {
    case debug
    case info
    case notice
    case error
    case fault
}
