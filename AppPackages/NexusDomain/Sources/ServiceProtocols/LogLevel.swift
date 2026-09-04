/// Severity taxonomy for log messages.
///
/// Domain defines its own level enum instead of importing OSLog; the
/// Data-layer `LoggingService` maps these to `OSLogType` behind
/// `LoggerProtocol`.
public enum LogLevel: Sendable, Equatable {
    case debug
    case info
    case notice
    case error
    case fault
}
