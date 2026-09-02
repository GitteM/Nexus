/// The logging seam every layer receives via its initializer
/// (architecture.md §4.3).
///
/// `LoggerProtocol` is `Sendable` so a logger can be shared across
/// concurrency domains; the Data layer backs it with OSLog (architecture.md
/// §7.2). Implementations must log display-safe data only — never full card
/// numbers, CVV, or auth tokens.
public protocol LoggerProtocol: Sendable {
    /// Records one message at the given severity.
    func log(_ message: String, level: LogLevel)
}
