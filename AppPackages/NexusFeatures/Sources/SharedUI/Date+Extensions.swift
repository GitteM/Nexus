import Foundation

/// Shared date formatting used across screens (architecture.md §9.4,
/// tasks.md Day 9).
///
/// Wrappers exist so transaction history, balances and card screens format
/// dates identically. Locale/time zone default to the user's settings but
/// are parameterized so tests can pin them.
public extension Date {
    /// Medium date, e.g. "Jan 12, 2026".
    func formattedMediumDate(
        locale: Locale = .current,
        timeZone: TimeZone = .current,
    ) -> String {
        Date.FormatStyle(
            date: .abbreviated,
            time: .omitted,
            locale: locale,
            timeZone: timeZone,
        )
        .format(self)
    }

    /// Short time, e.g. "12:00 PM".
    func formattedShortTime(
        locale: Locale = .current,
        timeZone: TimeZone = .current,
    ) -> String {
        Date.FormatStyle(
            date: .omitted,
            time: .shortened,
            locale: locale,
            timeZone: timeZone,
        )
        .format(self)
    }

    /// Whether this instant falls on today's calendar day (current calendar).
    var isInToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}
