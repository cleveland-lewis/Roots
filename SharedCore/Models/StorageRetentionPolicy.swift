import Foundation

public enum StorageRetentionPolicy: String, CaseIterable, Identifiable, Codable {
    case never
    case semester30Days
    case semester90Days
    case oneYear
    case twoYears

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .never: return "Never Delete"
        case .semester30Days: return "30 Days After Semester"
        case .semester90Days: return "90 Days After Semester"
        case .oneYear: return "1 Year"
        case .twoYears: return "2 Years"
        }
    }

    public var detail: String {
        switch self {
        case .never:
            return "Keep all detailed data."
        case .semester30Days:
            return "Remove detailed data 30 days after a semester ends."
        case .semester90Days:
            return "Remove detailed data 90 days after a semester ends."
        case .oneYear:
            return "Remove detailed data after 1 year."
        case .twoYears:
            return "Remove detailed data after 2 years."
        }
    }

    public var isSemesterBased: Bool {
        switch self {
        case .semester30Days, .semester90Days: return true
        case .never, .oneYear, .twoYears: return false
        }
    }

    public func isExpired(primaryDate: Date, semesterEnd: Date?, now: Date = Date()) -> Bool {
        switch self {
        case .never:
            return false
        case .semester30Days:
            let endDate = semesterEnd ?? primaryDate
            return now >= Calendar.current.date(byAdding: .day, value: 30, to: endDate) ?? now
        case .semester90Days:
            let endDate = semesterEnd ?? primaryDate
            return now >= Calendar.current.date(byAdding: .day, value: 90, to: endDate) ?? now
        case .oneYear:
            return now >= Calendar.current.date(byAdding: .year, value: 1, to: primaryDate) ?? now
        case .twoYears:
            return now >= Calendar.current.date(byAdding: .year, value: 2, to: primaryDate) ?? now
        }
    }
}
