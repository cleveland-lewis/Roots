import Foundation

/// StorageListable implementations for all persisted entities
/// Provides displayTitle with fallback rules for Storage Center

// MARK: - Course

extension Course: StorageListable {
    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        // Fallback: use code if available
        if !code.isEmpty {
            return code
        }
        return "Untitled Course"
    }
    
    public var entityType: StorageEntityType {
        .course
    }
    
    public var contextDescription: String? {
        // Show course code
        if !code.isEmpty {
            return code
        }
        return nil
    }
    
    public var primaryDate: Date {
        // Use current date as fallback since Course doesn't have createdDate
        Date()
    }
    
    public var statusDescription: String? {
        isArchived ? "Archived" : "Active"
    }
}

// MARK: - Semester

extension Semester: StorageListable {
    public var displayTitle: String {
        // Compute from term and year
        let termName = semesterTerm.rawValue
        return "\(termName) \(academicYear)"
    }
    
    public var entityType: StorageEntityType {
        .semester
    }
    
    public var contextDescription: String? {
        educationLevel.rawValue
    }
    
    public var primaryDate: Date {
        startDate
    }
    
    public var statusDescription: String? {
        isCurrent ? "Current" : nil
    }
}

// MARK: - CourseOutlineNode

extension CourseOutlineNode: StorageListable {
    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        // Fallback based on type
        switch type {
        case .module:
            return "Untitled Module"
        case .unit:
            return "Untitled Unit"
        case .section:
            return "Untitled Section"
        case .chapter:
            return "Untitled Chapter"
        case .part:
            return "Untitled Part"
        case .lesson:
            return "Untitled Lesson"
        @unknown default:
            return "Untitled Node"
        }
    }
    
    public var entityType: StorageEntityType {
        .courseOutline
    }
    
    public var contextDescription: String? {
        // Show node type
        type.rawValue
    }
    
    public var primaryDate: Date {
        createdAt
    }
}

// MARK: - CourseFile

extension CourseFile: StorageListable {
    public var displayTitle: String {
        if !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return filename
        }
        // Fallback: extract from URL if available
        if let urlString = localURL, let url = URL(string: urlString) {
            let filename = url.lastPathComponent
            if !filename.isEmpty && filename != "/" {
                return filename
            }
        }
        // Last resort: use type + timestamp
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let timestamp = formatter.string(from: createdAt)
        return "File (\(timestamp))"
    }
    
    public var entityType: StorageEntityType {
        .courseFile
    }
    
    public var contextDescription: String? {
        // Show file type and special flags
        var parts: [String] = []
        if !fileType.isEmpty {
            parts.append(fileType.uppercased())
        }
        if isSyllabus {
            parts.append("Syllabus")
        }
        if isPracticeExam {
            parts.append("Practice Exam")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    
    public var primaryDate: Date {
        createdAt
    }
}

// MARK: - Attachment

extension Attachment: StorageListable {
    public var displayTitle: String {
        if let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        // Fallback: extract from URL
        if let url = localURL {
            let filename = url.lastPathComponent
            if !filename.isEmpty && filename != "/" {
                return filename
            }
        }
        // Fallback by tag
        if let tag = tag {
            return "\(tag.rawValue.capitalized) Attachment"
        }
        return "Untitled Attachment"
    }
    
    public var entityType: StorageEntityType {
        .attachment
    }
    
    public var contextDescription: String? {
        // Show tag if available
        tag?.rawValue.capitalized
    }
    
    public var primaryDate: Date {
        dateAdded ?? Date()
    }
}

// MARK: - CalendarEvent

extension CalendarEvent: StorageListable {
    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        // Fallback: use category + date
        let dateStr = startDate.formatted(date: .abbreviated, time: .omitted)
        return "\(category.rawValue) (\(dateStr))"
    }
    
    public var entityType: StorageEntityType {
        .calendarEvent
    }
    
    public var contextDescription: String? {
        // Show location if available
        location
    }
    
    public var primaryDate: Date {
        startDate
    }
    
    public var searchableText: String {
        var components = [displayTitle, entityType.rawValue]
        if let location = location {
            components.append(location)
        }
        if let notes = notes {
            components.append(notes)
        }
        return components.joined(separator: " ")
    }
}

// MARK: - Fallback Utilities

/// Helper to generate fallback titles with timestamps
internal func fallbackTitle(prefix: String, date: Date?) -> String {
    if let date = date {
        let dateStr = date.formatted(date: .abbreviated, time: .shortened)
        return "\(prefix) (\(dateStr))"
    }
    return "\(prefix) (Unknown Date)"
}

/// Helper to safely extract non-empty string
internal func nonEmptyString(_ str: String?) -> String? {
    guard let str = str else { return nil }
    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
