/// How much of a log message may be persisted without redaction.
///
/// Domain names the concept; the Data-layer logger maps it to the platform's
/// privacy annotations. The conservative case is the default at the call site,
/// so a message is only shared when the caller says it is safe.
public enum LogPrivacy: Sendable {
    /// Non-identifying diagnostics — status codes, durations, route templates.
    case visible
    /// Per-user data such as card or session identifiers; kept out of persisted
    /// logs while remaining readable in a live debug console.
    case redacted
    /// Credentials and other secrets.
    case sensitive
}
