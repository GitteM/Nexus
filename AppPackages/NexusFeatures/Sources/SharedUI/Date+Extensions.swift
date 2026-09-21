import Foundation

/// Shared date formatting used across screens.
///
/// Wrappers exist so transaction history, balances and card screens format
/// dates identically. Locale/time zone default to the user's settings but
/// are parameterized so tests can pin them.
extension Date {
    /// Medium date, e.g. "Jan 12, 2026".
    public func formattedMediumDate(
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        Date.FormatStyle(
            date: .abbreviated,
            time: .omitted,
            locale: locale,
            timeZone: timeZone
        )
        .format(self)
    }

    /// Short time, e.g. "12:00 PM".
    public func formattedShortTime(
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        Date.FormatStyle(
            date: .omitted,
            time: .shortened,
            locale: locale,
            timeZone: timeZone
        )
        .format(self)
    }

    /// Whether this instant falls on today's calendar day (current calendar).
    public var isInToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}
