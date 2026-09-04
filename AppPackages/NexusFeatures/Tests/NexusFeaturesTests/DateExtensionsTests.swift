import Foundation
import SharedUI
import Testing

/// `Date+Extensions` formatting wrappers. Locale/time zone are pinned so
/// expectations are deterministic.
@Suite("Date formatting helpers")
struct DateExtensionsTests {
    /// 2026-01-12 12:00:00 UTC — mid-day so no calendar-day boundary issues.
    private var noonJanuary12: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(
            from: DateComponents(
                timeZone: TimeZone(secondsFromGMT: 0),
                year: 2026, month: 1, day: 12, hour: 12, minute: 0,
            ),
        )!
    }

    @Test func `medium date formats with pinned locale`() throws {
        let locale = Locale(identifier: "en_US")
        let timeZone = try #require(TimeZone(secondsFromGMT: 0))

        #expect(noonJanuary12.formattedMediumDate(locale: locale, timeZone: timeZone) == "Jan 12, 2026")
    }

    @Test func `short time formats with pinned locale`() throws {
        let locale = Locale(identifier: "en_US")
        let timeZone = try #require(TimeZone(secondsFromGMT: 0))

        let formatted = noonJanuary12.formattedShortTime(locale: locale, timeZone: timeZone)
        // en_US uses a 12-hour clock; ICU separates the meridiem with a
        // narrow no-break space (U+202F), so assert hour/minute and meridiem
        // rather than one exact whitespace variant.
        #expect(formatted.hasPrefix("12:00"))
        #expect(formatted.hasSuffix("PM"))
    }

    @Test func `distant date is not in today`() {
        #expect(!Date().addingTimeInterval(3 * 24 * 60 * 60).isInToday)
    }
}
