import Foundation

enum QuickAction: String, CaseIterable, Identifiable, Codable {
    case add_assignment
    case add_course
    case add_task
    case add_grade
    case quick_note
    case open_new_note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .add_assignment: return "Add Assignment"
        case .add_course: return "Add Course"
        case .add_task: return "Add Task"
        case .add_grade: return "Add Grade"
        case .quick_note: return "Quick Note"
        case .open_new_note: return "New Note"
        }
    }

    var systemImage: String {
        switch self {
        case .add_assignment: return "plus.square.on.square"
        case .add_course: return "book.badge.plus"
        case .add_task: return "checkmark.circle.badge.plus"
        case .add_grade: return "chart.bar.doc.horizontal"
        case .quick_note: return "pencil"
        case .open_new_note: return "square.and.pencil"
        }
    }
}
