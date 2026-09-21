import os
import ServiceProtocols

/// OSLog-backed implementation of Domain's `LoggerProtocol`.
///
/// The Data layer owns logging infrastructure; Domain only names the seam
/// (`LoggerProtocol` + its own `LogLevel` and `LogPrivacy`). This service maps
/// the Domain `LogLevel` to `OSLogType` and `LogPrivacy` to the unified log's
/// privacy annotation: `visible` → `.public`, `redacted` → `.private`,
/// `sensitive` → `.sensitive`. The default (see `LoggerProtocol`) is
/// `.redacted`, so identifiers stay out of persisted logs unless a caller
/// explicitly marks a message `visible`.
///
/// Every layer receives a `LoggerProtocol` via its initializer — there are
/// no global logging calls in the codebase. A caller can override the
/// default subsystem/category per instance (e.g. `LoggingService(category:
/// "session")`) when a subsystem-level filter is useful in Console.app.
public struct LoggingService: LoggerProtocol {
    /// Bundle-style subsystem used by every default instance.
    public static let defaultSubsystem = "com.nexusbank.app"

    private let logger: Logger

    /// - Parameters:
    ///   - subsystem: The `os.Logger` subsystem (default
    ///     `com.nexusbank.app`); scopes messages in Console.app.
    ///   - category: The `os.Logger` category (default `default`); pass an
    ///     area name to separate concerns in the log stream.
    public init(
        subsystem: String = LoggingService.defaultSubsystem,
        category: String = "default"
    ) {
        logger = Logger(subsystem: subsystem, category: category)
    }

    /// Records one message at the severity and privacy mapped from Domain.
    public func log(_ message: String, level: LogLevel, privacy: LogPrivacy) {
        let type = Self.osLogType(for: level)
        switch privacy {
        case .visible:
            logger.log(level: type, "\(message, privacy: .public)")
        case .redacted:
            logger.log(level: type, "\(message, privacy: .private)")
        case .sensitive:
            logger.log(level: type, "\(message, privacy: .sensitive)")
        }
    }

    /// Maps the Domain `LogLevel` to the `OSLogType` used for the message:
    /// debug → `.debug`, info → `.info`, notice → `.default`,
    /// error → `.error`, fault → `.fault`.
    static func osLogType(for level: LogLevel) -> OSLogType {
        switch level {
        case .debug: .debug
        case .info: .info
        case .notice: .default
        case .error: .error
        case .fault: .fault
        }
    }
}
