import XCTest
@testable import Roots

final class LocaleFormattersTests: XCTestCase {
    func testTimeFormatterUsesLocale() {
        let date = Date(timeIntervalSince1970: 1735823100) // 2025-01-02 13:05:00 UTC
        let enUS = Locale(identifier: "en_US")
        let frFR = Locale(identifier: "fr_FR")
        let utc = TimeZone(secondsFromGMT: 0)!

        let enFormatter = LocaleFormatters.timeFormatter(use24Hour: false, locale: enUS, timeZone: utc)
        let frFormatter = LocaleFormatters.timeFormatter(use24Hour: true, locale: frFR, timeZone: utc)

        let enString = enFormatter.string(from: date)
        let frString = frFormatter.string(from: date)

        XCTAssertTrue(enString.localizedCaseInsensitiveContains("AM") || enString.localizedCaseInsensitiveContains("PM"))
        XCTAssertFalse(frString.localizedCaseInsensitiveContains("AM") || frString.localizedCaseInsensitiveContains("PM"))
    }

    func testMonthDayOrderingByLocale() {
        let date = Date(timeIntervalSince1970: 1736030400) // 2025-01-04 00:00:00 UTC
        let enUS = Locale(identifier: "en_US")
        let frFR = Locale(identifier: "fr_FR")
        let utc = TimeZone(secondsFromGMT: 0)!

        let enFormatter = LocaleFormatters.templateFormatter("MMM d", locale: enUS, timeZone: utc)
        let frFormatter = LocaleFormatters.templateFormatter("MMM d", locale: frFR, timeZone: utc)

        let enString = enFormatter.string(from: date).trimmingCharacters(in: .whitespacesAndNewlines)
        let frString = frFormatter.string(from: date).trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertTrue(enString.hasPrefix("Jan") || enString.hasPrefix("jan"))
        XCTAssertTrue(frString.hasPrefix("4"))
    }

    func testDayNameLocalization() {
        let date = Date(timeIntervalSince1970: 1736030400) // 2025-01-04 00:00:00 UTC
        let enUS = Locale(identifier: "en_US")
        let zhHans = Locale(identifier: "zh_Hans")
        let utc = TimeZone(secondsFromGMT: 0)!

        let enFormatter = LocaleFormatters.templateFormatter("EEEE", locale: enUS, timeZone: utc)
        let zhFormatter = LocaleFormatters.templateFormatter("EEEE", locale: zhHans, timeZone: utc)

        let enString = enFormatter.string(from: date)
        let zhString = zhFormatter.string(from: date)

        XCTAssertNotEqual(enString, zhString)
    }
}
