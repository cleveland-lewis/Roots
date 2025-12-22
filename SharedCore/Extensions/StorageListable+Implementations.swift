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
        return "\(termName) \(academicYear ?? "")"
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
        #if os(macOS)
        let cat = category.rawValue
        #else
        let cat = category?.rawValue ?? "Event"
        #endif
        return "\(cat) (\(dateStr))"
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

// MARK: - AppTask (Assignments)

extension AppTask: StorageListable {
    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return "Untitled Assignment"
    }

    public var entityType: StorageEntityType { .assignment }

    public var contextDescription: String? {
        due?.formatted(date: .abbreviated, time: .omitted)
    }

    public var primaryDate: Date {
        due ?? Date()
    }

    public var statusDescription: String? {
        isCompleted ? "Completed" : nil
    }
}

// MARK: - PracticeTest

extension PracticeTest: StorageListable {
    public var displayTitle: String {
        let topic = topics.first ?? "Practice Test"
        return "\(courseName) - \(topic)"
    }

    public var entityType: StorageEntityType { .practiceTest }

    public var contextDescription: String? {
        status.rawValue
    }

    public var primaryDate: Date {
        createdAt
    }

    public var statusDescription: String? {
        status.rawValue
    }
}

// MARK: - GradeEntry

extension GradeEntry: StorageListable {
    public var displayTitle: String {
        if let letter, !letter.isEmpty {
            return "Grade: \(letter)"
        }
        if let percent {
            return String(format: "Grade: %.1f%%", percent)
        }
        return "Grade Entry"
    }

    public var entityType: StorageEntityType { .grade }

    public var contextDescription: String? {
        if let letter, !letter.isEmpty { return letter }
        if let percent { return String(format: "%.1f%%", percent) }
        return nil
    }

    public var primaryDate: Date { updatedAt }
}

// MARK: - Planner Sessions

extension StoredScheduledSession: StorageListable {
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Planner Block" : trimmed
    }

    public var entityType: StorageEntityType { .plannerBlock }

    public var contextDescription: String? {
        "\(start.formatted(date: .abbreviated, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }

    public var primaryDate: Date { start }

    public var statusDescription: String? {
        isLocked ? "Locked" : nil
    }
}

extension StoredOverflowSession: StorageListable {
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Overflow Block" : trimmed
    }

    public var entityType: StorageEntityType { .plannerBlock }

    public var contextDescription: String? {
        dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    public var primaryDate: Date { dueDate }

    public var statusDescription: String? { "Overflow" }
}

// MARK: - AssignmentPlan

extension AssignmentPlan: StorageListable {
    public var displayTitle: String {
        "Assignment Plan"
    }

    public var entityType: StorageEntityType { .assignmentPlan }

    public var contextDescription: String? {
        status.rawValue.capitalized
    }

    public var primaryDate: Date { generatedAt }

    public var statusDescription: String? {
        status.rawValue.capitalized
    }
}

// MARK: - FocusSession / Timer Sessions

extension FocusSession: StorageListable {
    public var displayTitle: String {
        let duration = actualDuration ?? plannedDuration
        if let duration {
            let minutes = Int(duration / 60)
            return "Focus: \(minutes)m"
        }
        return "Focus Session"
    }

    public var entityType: StorageEntityType { .focusSession }

    public var contextDescription: String? {
        mode.displayName
    }

    public var primaryDate: Date {
        startedAt ?? Date()
    }

    public var statusDescription: String? {
        state.rawValue.capitalized
    }
}

extension LocalTimerSession: StorageListable {
    public var displayTitle: String {
        let minutes = Int(duration / 60)
        return "Timer: \(minutes)m"
    }

    public var entityType: StorageEntityType { .timerSession }

    public var contextDescription: String? {
        mode.label
    }

    public var primaryDate: Date { startDate }

    public var statusDescription: String? {
        isBreakSession ? "Break" : nil
    }
}

// MARK: - TestBlueprint

extension TestBlueprint: Identifiable {}

extension TestBlueprint: StorageListable {
    public var displayTitle: String {
        if let topic = topics.first, !topic.isEmpty {
            return "Blueprint: \(topic)"
        }
        return "Test Blueprint"
    }

    public var entityType: StorageEntityType { .testBlueprint }

    public var contextDescription: String? {
        difficultyTarget.rawValue
    }

    public var primaryDate: Date { createdAt }
}

// MARK: - Syllabus Parsing

extension SyllabusParsingJob: StorageListable {
    public var displayTitle: String {
        "Syllabus Parsing"
    }

    public var entityType: StorageEntityType { .syllabus }

    public var contextDescription: String? {
        status.rawValue
    }

    public var primaryDate: Date { createdAt }

    public var statusDescription: String? {
        status.rawValue
    }
}

extension ParsedAssignment: StorageListable {
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Parsed Assignment" : trimmed
    }

    public var entityType: StorageEntityType { .parsedAssignment }

    public var contextDescription: String? {
        inferredType
    }

    public var primaryDate: Date {
        dueDate ?? createdAt
    }

    public var statusDescription: String? {
        isImported ? "Imported" : nil
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
