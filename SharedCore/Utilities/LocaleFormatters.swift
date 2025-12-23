import Foundation

/// Centralized locale-aware formatting utilities for dates, numbers, and times
enum LocaleFormatters {
    private static func makeDateFormatter(
        dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter
    }

    private static func makeTemplateFormatter(
        _ template: String,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    static func templateFormatter(
        _ template: String,
        locale: Locale,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> DateFormatter {
        makeTemplateFormatter(template, locale: locale, timeZone: timeZone)
    }

    static func timeFormatter(
        use24Hour: Bool,
        includeSeconds: Bool = false,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> DateFormatter {
        let template: String
        if use24Hour {
            template = includeSeconds ? "Hms" : "Hm"
        } else {
            template = includeSeconds ? "jms" : "jm"
        }
        return makeTemplateFormatter(template, locale: locale, timeZone: timeZone)
    }

    static func hourFormatter(
        use24Hour: Bool,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> DateFormatter {
        let template = use24Hour ? "H" : "j"
        return makeTemplateFormatter(template, locale: locale, timeZone: timeZone)
    }
    
    // MARK: - Date Formatters
    
    /// Full date with day name: "Monday, December 23, 2025"
    static var fullDate: DateFormatter {
        makeDateFormatter(dateStyle: .full, timeStyle: .none)
    }
    
    /// Long date: "December 23, 2025"
    static var longDate: DateFormatter {
        makeDateFormatter(dateStyle: .long, timeStyle: .none)
    }
    
    /// Medium date: "Dec 23, 2025"
    static var mediumDate: DateFormatter {
        makeDateFormatter(dateStyle: .medium, timeStyle: .none)
    }
    
    /// Short date: "12/23/25"
    static var shortDate: DateFormatter {
        makeDateFormatter(dateStyle: .short, timeStyle: .none)
    }
    
    /// Short time: "2:30 PM" or "14:30" based on locale
    static var shortTime: DateFormatter {
        makeDateFormatter(dateStyle: .none, timeStyle: .short)
    }
    
    /// Medium time: "2:30:45 PM" or "14:30:45"
    static var mediumTime: DateFormatter {
        makeDateFormatter(dateStyle: .none, timeStyle: .medium)
    }
    
    /// Date and time: "Dec 23, 2025 at 2:30 PM"
    static var dateAndTime: DateFormatter {
        makeDateFormatter(dateStyle: .medium, timeStyle: .short)
    }
    
    /// Month and year: "December 2025"
    static var monthYear: DateFormatter {
        makeTemplateFormatter("MMMM yyyy")
    }
    
    /// Day name: "Monday"
    static var dayName: DateFormatter {
        makeTemplateFormatter("EEEE")
    }
    
    /// Short day name: "Mon"
    static var shortDayName: DateFormatter {
        makeTemplateFormatter("E")
    }
    
    /// Month and day: "Dec 23"
    static var monthDay: DateFormatter {
        makeTemplateFormatter("MMM d")
    }
    
    /// Full month and day: "December 23"
    static var fullMonthDay: DateFormatter {
        makeTemplateFormatter("MMMM d")
    }
    
    /// Day name and date: "Monday, Dec 23"
    static var dayNameAndDate: DateFormatter {
        makeTemplateFormatter("EEEE, MMM d")
    }
    
    /// Short day and date: "Mon, Dec 23"
    static var shortDayAndDate: DateFormatter {
        makeTemplateFormatter("E, MMM d")
    }

    static var dayOfMonth: DateFormatter {
        makeTemplateFormatter("d")
    }

    /// Hour only: "2 PM" or "14"
    static var hour: DateFormatter {
        makeTemplateFormatter("j")
    }
    
    /// Hour with minutes: "2:30 PM" or "14:30"
    static var hourMinute: DateFormatter {
        makeTemplateFormatter("jm")
    }

    static var dayNameAndDateTime: DateFormatter {
        makeTemplateFormatter("EEEE, MMM d jm")
    }
    
    /// ISO 8601 date: "2025-12-23"
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
    
    /// ISO 8601 timestamp for logging
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    // MARK: - Number Formatters
    
    /// Decimal number: "3.14" or "3,14" based on locale
    static var decimal: NumberFormatter {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }
    
    /// Percentage: "85%" or "85 %" based on locale
    static var percentage: NumberFormatter {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .percent
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }
    
    /// GPA with precision: "3.67"
    static var gpa: NumberFormatter {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }
    
    /// Currency (user's locale)
    static var currency: NumberFormatter {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .currency
        return f
    }
    
    /// Integer: "1,234" or "1 234" based on locale
    static var integer: NumberFormatter {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }
    
    // MARK: - Duration Formatting
    
    /// Format seconds as "1h 23m" or "23m 45s"
    static func formatDuration(seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: seconds) ?? "\(Int(seconds))s"
    }
    
    /// Format seconds as "1:23:45" or "23:45"
    static func formatDurationColons(seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
