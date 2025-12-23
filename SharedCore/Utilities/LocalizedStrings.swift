import Foundation

// MARK: - TaskType Localization
extension TaskType {
    /// Localized display name - NEVER use rawValue for UI
    var localizedName: String {
        switch self {
        case .practiceHomework:
            return "task.type.homework".localized
        case .quiz:
            return "task.type.quiz".localized
        case .exam:
            return "task.type.exam".localized
        case .reading:
            return "task.type.reading".localized
        case .review:
            return "task.type.review".localized
        case .project:
            return "task.type.project".localized
        }
    }
}

// MARK: - Timer Mode Localization
extension TimerMode {
    // displayName already exists in TimerModels.swift
    // Keep that implementation to avoid breaking changes
}

// MARK: - Common Localizations Helper
struct CommonLocalizations {
    static let today = "common.today".localized
    static let due = "common.due".localized
    static let noDate = "common.no_date".localized
    static let noCourse = "common.no_course".localized
    static let edit = "common.edit".localized
    static let done = "common.done".localized
    static let menu = "common.menu".localized
    
    static let importance = "attribute.importance".localized
    static let difficulty = "attribute.difficulty".localized
}

// MARK: - Planner Localizations
struct PlannerLocalizations {
    static let today = "planner.today".localized
    static let generate = "planner.generate".localized
    static let howItWorks = "planner.how_it_works".localized
    static let emptyTitle = "planner.empty.title".localized
    static let emptySubtitle = "planner.empty.subtitle".localized
    static let noPlan = "planner.no_plan".localized
    
    static func allowedHours(min: Int, max: Int) -> String {
        String(format: "planner.allowed_hours".localized, min, max)
    }
    
    static func stepsCount(completed: Int, total: Int) -> String {
        String(format: "planner.steps_count".localized, completed, total)
    }
    
    static func minutesTotal(_ minutes: Int) -> String {
        String(format: "planner.minutes_total".localized, minutes)
    }
    
    static func progress(_ percentage: Int) -> String {
        String(format: "planner.progress".localized, percentage)
    }
    
    static func updated(_ timeAgo: String) -> String {
        String(format: "planner.updated".localized, timeAgo)
    }
    
    static func dueDate(_ date: String) -> String {
        String(format: "plans.due_date".localized, date)
    }
}

// MARK: - Dashboard Localizations
struct DashboardLocalizations {
    static let emptyCalendar = "dashboard.empty.calendar".localized
    static let emptyEvents = "dashboard.empty.events".localized
    static let emptyTasks = "dashboard.empty.tasks".localized
}

// MARK: - Quick Add Localizations
struct QuickAddLocalizations {
    static let assignment = "quick_add.assignment".localized
    static let grade = "quick_add.grade".localized
    static let schedule = "quick_add.schedule".localized
}

// MARK: - Menu Localizations
struct MenuLocalizations {
    static let starredTabs = "menu.starred_tabs".localized
    static let starredTabsFooter = "menu.starred_tabs.footer".localized
    static let pinLimit = "menu.pin_limit".localized
}
