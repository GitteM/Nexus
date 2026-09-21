/// The logging seam every layer receives via its initializer.
///
/// `LoggerProtocol` is `Sendable` so a logger can be shared across
/// concurrency domains; the Data layer backs it with OSLog.
///
/// `privacy` tells the implementation how much of the message may be persisted
/// without redaction. Prefer the two-argument form — it redacts — unless the
/// message is provably non-identifying.
public protocol LoggerProtocol: Sendable {
    /// Records one message at the given severity and privacy.
    func log(_ message: String, level: LogLevel, privacy: LogPrivacy)
}

extension LoggerProtocol {
    /// Records one message at the given severity, redacted by default.
    public func log(_ message: String, level: LogLevel) {
        log(message, level: level, privacy: .redacted)
    }
}
