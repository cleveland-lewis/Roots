#if !os(macOS)
import Foundation
import SwiftUI
import UIKit

// Minimal stubs for macOS-only types used by shared code when building for iOS.

// Map NSColor to UIColor for cross-platform compatibility
public typealias NSColor = UIColor

// Allow constructing SwiftUI Color from an NSColor-like initializer used in shared code
public extension Color {
    init(nsColor: NSColor) {
        self.init(nsColor)
    }
} 

// Provide commonly used NSColor-like static properties used in code
public extension NSColor {
    static var controlAccentColor: NSColor { UIColor.systemBlue }
    static var controlBackgroundColor: NSColor { UIColor.systemBackground }
    static var separatorColor: NSColor { UIColor.separator }
    static var windowBackgroundColor: NSColor { UIColor.systemBackground }
    static var underPageBackgroundColor: NSColor { UIColor.secondarySystemBackground }
    static var controlHighlightColor: NSColor { UIColor.systemGray }
    static var alternatingContentBackgroundColors: [NSColor] { [UIColor.systemBackground, UIColor.secondarySystemBackground] }
    static var unemphasizedSelectedContentBackgroundColor: NSColor { UIColor.systemGray2 }
}

public struct LocalTimerSession: Identifiable, Codable, Hashable {
    public enum Mode: String, Codable, Hashable {
        case work, breakMode = "break", other
    }

    public let id: UUID
    public var activityID: UUID
    public var mode: Mode
    public var startDate: Date
    public var endDate: Date?
    public var duration: TimeInterval

    public init(id: UUID = UUID(), activityID: UUID, mode: Mode = .other, startDate: Date, endDate: Date? = nil, duration: TimeInterval = 0) {
        self.id = id
        self.activityID = activityID
        self.mode = mode
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
    }
}

public struct LocalTimerActivity: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var category: String
    public var courseCode: String?
    public var assignmentTitle: String?
    public var colorTag: ColorTag
    public var isPinned: Bool
    public var totalTrackedSeconds: TimeInterval
    public var todayTrackedSeconds: TimeInterval

    public init(id: UUID = UUID(), name: String = "", category: String = "", courseCode: String? = nil, assignmentTitle: String? = nil, colorTag: ColorTag = .blue, isPinned: Bool = false, totalTrackedSeconds: TimeInterval = 0, todayTrackedSeconds: TimeInterval = 0) {
        self.id = id
        self.name = name
        self.category = category
        self.courseCode = courseCode
        self.assignmentTitle = assignmentTitle
        self.colorTag = colorTag
        self.isPinned = isPinned
        self.totalTrackedSeconds = totalTrackedSeconds
        self.todayTrackedSeconds = todayTrackedSeconds
    }
}



public enum SettingsToolbarIdentifier: String, CaseIterable, Identifiable {
    case general
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
    public var toolbarItemIdentifier: String { rawValue }
    public var windowTitle: String { "Settings" }
}

public class SettingsWindowController {
    public static let lastPaneKey = "roots.settings.lastSelectedPane"
    public init(appSettings: Any, coursesStore: Any, coordinator: Any) {}
    public func showSettings() {}
}



// Additional lightweight stubs for shared types referenced by iOS target when macOS sources are excluded

public enum RootTab: String, CaseIterable, Identifiable {
    case dashboard, calendar, planner, assignments, courses, grades, timer, decks
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .calendar: return "Calendar"
        case .planner: return "Planner"
        case .assignments: return "Assignments"
        case .courses: return "Courses"
        case .grades: return "Grades"
        case .timer: return "Timer"
        case .decks: return "Decks"
        }
    }

    public var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .calendar: return "calendar"
        case .planner: return "pencil.and.list.clipboard"
        case .assignments: return "slider.horizontal.3"
        case .courses: return "book.closed"
        case .grades: return "number.circle"
        case .timer: return "timer"
        case .decks: return "rectangle.stack"
        }
    }

    public var logKey: String { title.lowercased().replacingOccurrences(of: " ", with: "") }
}

public enum AssignmentCategory: String, CaseIterable, Codable {
    case reading, exam, homework, practiceHomework, quiz, review, project
}

public enum AssignmentUrgency: String, Codable, CaseIterable, Hashable {
    case low, medium, high, critical
}

public struct PlanStep: Codable, Hashable {
    public var title: String
    public var expectedMinutes: Int
    public init(title: String = "", expectedMinutes: Int = 0) { self.title = title; self.expectedMinutes = expectedMinutes }
}

public struct Assignment: Identifiable, Codable, Hashable {
    public let id: UUID
    public var courseId: UUID?
    public var title: String
    public var dueDate: Date
    public var estimatedMinutes: Int
    public var weightPercent: Double?
    public var category: AssignmentCategory
    public var urgency: AssignmentUrgency
    public var isLockedToDueDate: Bool
    public var plan: [PlanStep]

    public init(id: UUID = UUID(), courseId: UUID? = nil, title: String = "", dueDate: Date = Date(), estimatedMinutes: Int = 60, weightPercent: Double? = nil, category: AssignmentCategory = .practiceHomework, urgency: AssignmentUrgency = .medium, isLockedToDueDate: Bool = false, plan: [PlanStep] = []) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.weightPercent = weightPercent
        self.category = category
        self.urgency = urgency
        self.isLockedToDueDate = isLockedToDueDate
        self.plan = plan
    }
}

public enum CalendarViewMode: String, Codable {
    case day, week, month
}

public struct GradeCourseSummary: Hashable {
    public var id: UUID
    public var title: String
}

public struct CalendarEvent: Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var location: String?
    public var notes: String?
    public var url: URL?
    public init(id: UUID = UUID(), title: String = "", startDate: Date = Date(), endDate: Date = Date(), location: String? = nil, notes: String? = nil, url: URL? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.url = url
    }
}

// StoredScheduledSession and StoredOverflowSession are defined in SharedCore/State/PlannerStore.swift; avoid duplicating them here.

// Provide LoadableViewModel protocol similar to macOS implementation
@MainActor
public protocol LoadableViewModel: AnyObject, ObservableObject {
    var isLoading: Bool { get set }
    var loadingMessage: String? { get set }
}

public extension LoadableViewModel {
    func withLoading<T>(message: String? = nil, work: @escaping () async throws -> T) async rethrows -> T {
        await MainActor.run {
            self.isLoading = true
            self.loadingMessage = message
        }
        defer {
            Task { @MainActor in
                self.isLoading = false
                self.loadingMessage = nil
            }
        }
        return try await work()
    }
}

#endif
