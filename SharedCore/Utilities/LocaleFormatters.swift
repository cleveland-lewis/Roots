import Foundation

/// Centralized locale-aware formatting utilities for dates, numbers, and times
enum LocaleFormatters {
    
    // MARK: - Date Formatters
    
    /// Full date with day name: "Monday, December 23, 2025"
    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()
    
    /// Long date: "December 23, 2025"
    static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()
    
    /// Medium date: "Dec 23, 2025"
    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    /// Short date: "12/23/25"
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()
    
    /// Short time: "2:30 PM" or "14:30" based on locale
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
    
    /// Medium time: "2:30:45 PM" or "14:30:45"
    static let mediumTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()
    
    /// Date and time: "Dec 23, 2025 at 2:30 PM"
    static let dateAndTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    /// Month and year: "December 2025"
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f
    }()
    
    /// Day name: "Monday"
    static let dayName: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f
    }()
    
    /// Short day name: "Mon"
    static let shortDayName: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("E")
        return f
    }()
    
    /// Month and day: "Dec 23"
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMM d")
        return f
    }()
    
    /// Full month and day: "December 23"
    static let fullMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMMM d")
        return f
    }()
    
    /// Day name and date: "Monday, Dec 23"
    static let dayNameAndDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return f
    }()
    
    /// Short day and date: "Mon, Dec 23"
    static let shortDayAndDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("E, MMM d")
        return f
    }()
    
    /// Hour only: "2 PM" or "14"
    static let hour: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("h a")
        return f
    }()
    
    /// Hour with minutes: "2:30 PM" or "14:30"
    static let hourMinute: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("h:mm a")
        return f
    }()
    
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
    static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale.current
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()
    
    /// Percentage: "85%" or "85 %" based on locale
    static let percentage: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale.current
        f.numberStyle = .percent
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }()
    
    /// GPA with precision: "3.67"
    static let gpa: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale.current
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()
    
    /// Currency (user's locale)
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale.current
        f.numberStyle = .currency
        return f
    }()
    
    /// Integer: "1,234" or "1 234" based on locale
    static let integer: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale.current
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()
    
    // MARK: - Duration Formatting
    
    /// Format seconds as "1h 23m" or "23m 45s"
    static func formatDuration(seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
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
