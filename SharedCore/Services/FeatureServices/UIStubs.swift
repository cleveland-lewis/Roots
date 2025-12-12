import SwiftUI
import EventKit

// Lightweight stubs for missing design components used throughout the app.
// These are minimal implementations to allow the project to compile; substitute
// the real design-system components in the main app.

struct EmptyStateView: View {
    let icon: String
    var body: some View {
        VStack(spacing: DesignSystem.Layout.spacing.small) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.display)
            Text(DesignSystem.emptyStateMessage)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: DesignSystem.Cards.cardMinHeight)
    }
}

struct GlassLoadingCard: View {
    let title: String
    let message: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Cards.cardCornerRadius, style: .continuous)
                .fill(.thinMaterial)
            VStack(alignment: .leading) {
                Text(title).font(DesignSystem.Typography.subHeader)
                if let m = message { Text(m).font(DesignSystem.Typography.caption).foregroundStyle(.secondary) }
            }
            .padding(DesignSystem.Layout.padding.card)
        }
        .frame(minHeight: DesignSystem.Cards.cardMinHeight)
    }
}

extension View {
    func loadingHUD(isVisible: Binding<Bool>, title: String = "", message: String? = nil) -> some View {
        // No-op wrapper for now — production app will overlay a HUD.
        self
    }
}


// MARK: - Missing model + view shells

// Use the Attachment model from Models/Attachment.swift to avoid duplicate definitions.
// Provide a module-local alias if the models are in a different module; here assume same target.
// If the external model isn't visible, add a minimal alias to match expected shape.

// UI stubs rely on the shared Attachment model in Models/Attachment.swift; no fallback needed.

/// Simple list view for attachments to unblock builds.
struct AttachmentListView: View {
    @Binding var attachments: [Attachment]
    var courseId: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(attachments) { attachment in
                HStack {
                    Image(systemName: "paperclip")
                    Text(attachment.name ?? "Attachment")
                    Spacer()
                }
            }
            Button {
                attachments.append(Attachment(name: "New Attachment"))
            } label: {
                Label("Add Attachment", systemImage: "plus")
            }
        }
    }
}

// Flashcard models to satisfy manager usage.
enum FlashcardDifficulty: String, Codable, CaseIterable {
    case easy, medium, hard
}

struct Flashcard: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var frontText: String
    var backText: String
    var difficulty: FlashcardDifficulty
    var dueDate: Date
    var repetition: Int = 0
    var interval: Int = 0
    var easeFactor: Double = 2.5
    var lastReviewed: Date? = nil
}

struct FlashcardDeck: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var courseID: UUID?
    var cards: [Flashcard] = []
}

// Fan-out menu shell to keep dashboard compiling.
struct FanOutMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let action: () -> Void

    // Backwards-compatible initializer using 'label' as many call sites expect.
    init(icon: String, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = label
        self.action = action
    }

    // Primary initializer using 'title'.
    init(icon: String, title: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.action = action
    }
}

struct RootsFanOutMenu: View {
    let items: [FanOutMenuItem]
    var body: some View {
        HStack(spacing: 12) {
            ForEach(items) { item in
                Button(action: item.action) {
                    Label(item.title, systemImage: item.icon)
                }
            }
        }
    }
}

struct FlashcardDashboard: View {
    var body: some View {
        Text("Flashcards")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Calendar shells
struct CalendarDayView: View {
    let date: Date
    let events: [EKEvent]
    var onSelectEvent: ((EKEvent) -> Void)?
    var body: some View { Text("Day: \(date.formatted())") }
}
struct CalendarWeekView: View {
    let currentDate: Date
    let events: [EKEvent]
    var onSelectEvent: ((EKEvent) -> Void)?
    var body: some View { Text("Week: \(currentDate.formatted())") }
}
struct CalendarYearView: View {
    let currentYear: Date
    var body: some View { Text("Year: \(currentYear.formatted())") }
}
struct CalendarGrid: View {
    @Binding var currentMonth: Date
    let events: [EKEvent]
    var body: some View { Text("Grid for \(currentMonth.formatted())") }
}
struct CalendarHeader: View {
    @Binding var viewMode: CalendarViewMode
    @Binding var currentMonth: Date
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}
    var onToday: () -> Void = {}
    var onSearch: ((String) -> Void)? = nil

    var body: some View { Text("Calendar Header") }
}
enum EventCategory: String, CaseIterable, Identifiable {
    case study = "Study"
    case review = "Review"
    case homework = "Homework"
    case reading = "Reading"
    case exam = "Exam"
    case `class` = "Class"
    case lab = "Lab"
    case other = "Other"
    var id: String { rawValue }
}

// Shared category parsing & colors
func parseEventCategory(from title: String) -> EventCategory? {
    let t = title.lowercased()
    if t.contains("exam") || t.contains("final") || t.contains("quiz") || t.contains("midterm") { return .exam }
    if t.contains("lab") { return .lab }
    if t.contains("class") || t.contains("lecture") { return .class }
    if t.contains("homework") || t.contains("assignment") || t.contains("problem set") || t.contains("ps") { return .homework }
    if t.contains("study") { return .study }
    if t.contains("review") { return .review }
    if t.contains("read") || t.contains("reading") { return .reading }
    return nil
}

extension EventCategory {
    var color: Color {
        switch self {
        case .study: return Color(hue: 0.55, saturation: 0.85, brightness: 0.8) // blue
        case .review: return Color(hue: 0.78, saturation: 0.65, brightness: 0.85) // purple
        case .homework: return Color(hue: 0.33, saturation: 0.6, brightness: 0.85) // green
        case .reading: return Color(hue: 0.08, saturation: 0.7, brightness: 0.9) // orange
        case .exam: return Color(hue: 0.02, saturation: 0.75, brightness: 0.9) // red
        case .class: return Color(hue: 0.6, saturation: 0.5, brightness: 0.8) // teal
        case .lab: return Color(hue: 0.48, saturation: 0.6, brightness: 0.85) // cyan
        case .other: return Color.secondary.opacity(0.85)
        }
    }
}

// New shared Add Event popup used throughout the app
struct AddEventPopup: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var category: EventCategory = .other
    @State private var userSelectedCategory: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var recurrence: CalendarManager.RecurrenceOption = .none
    @State private var isSaving: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("New Event")
                    .font(.title2.weight(.bold))
                Spacer()
                Button("Close") { dismiss() }
            }

            Form {
                TextField("Title", text: $title)
                    .onChange(of: title) { new in
                        // If user has not explicitly selected category, parse from title
                        if !userSelectedCategory {
                            if let parsed = parseCategory(from: new) {
                                category = parsed
                            } else {
                                category = .other
                            }
                        }
                    }

                Picker("Category", selection: Binding(get: { category }, set: { v in category = v; userSelectedCategory = true })) {
                    ForEach(EventCategory.allCases) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("All-day", isOn: $isAllDay)
                DatePicker("Starts", selection: $startDate)
                DatePicker("Ends", selection: $endDate)
                TextField("Location", text: $location)
                TextEditor(text: $notes).frame(height: 120)

                Picker("Repeat", selection: $recurrence) {
                    ForEach(CalendarManager.RecurrenceOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue.capitalized).tag(opt)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Create") {
                    createEvent()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 360)
    }

    private func parseCategory(from title: String) -> EventCategory? {
        let t = title.lowercased()
        if t.contains("exam") || t.contains("final") || t.contains("quiz") || t.contains("midterm") { return .exam }
        if t.contains("lab") { return .lab }
        if t.contains("class") || t.contains("lecture") { return .class }
        if t.contains("homework") || t.contains("assignment") || t.contains("problem set") || t.contains("ps") { return .homework }
        if t.contains("study") { return .study }
        if t.contains("review") { return .review }
        if t.contains("read") || t.contains("reading") { return .reading }
        return nil
    }

    private func createEvent() {
        Task {
            isSaving = true
            // If category not explicitly chosen, ensure title contains category keyword to surface label parsing
            var finalTitle = title
            if !userSelectedCategory {
                if category != .other && !title.lowercased().contains(category.rawValue.lowercased()) {
                    finalTitle = "\(category.rawValue) \(title)"
                }
            }

            do {
                try await calendarManager.saveEvent(title: finalTitle, startDate: startDate, endDate: endDate, isAllDay: isAllDay, location: location, notes: notes, calendar: nil)
                // refresh device events
                await DeviceCalendarManager.shared.refreshEventsForVisibleRange()
            } catch {
                print("Failed to save event: \(error)")
            }
            isSaving = false
            dismiss()
        }
    }
}

// Backwards compatibility alias
//struct AddEventPopup: View { var body: some View { Text("Add Event") } }

// Grades + analytics shells
struct GPABreakdownCard: View {
    var currentGPA: Double
    var academicYearGPA: Double
    var cumulativeGPA: Double
    var isLoading: Bool
    var courseCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GPA Overview")
                .font(.headline)
            Text("Current: \(currentGPA, specifier: "%.2f")")
            Text("Year: \(academicYearGPA, specifier: "%.2f")")
            Text("Cumulative: \(cumulativeGPA, specifier: "%.2f")")
            Text("Courses: \(courseCount)")
            if isLoading {
                ProgressView().progressViewStyle(.circular)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct AddGradeSheet: View {
    var assignments: [AppTask]
    var courses: [GradeCourseSummary]
    var onSave: (AppTask) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Add Grade")
                .font(.headline)
            if let first = assignments.first {
                Button("Save Sample Grade") {
                    onSave(first)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("No assignments available yet.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 320, minHeight: 200)
    }
}

// Charts used in timer
enum TimerChartRange {
    case today, thisWeek, thisMonth
}

struct CategoryPieChart: View {
    var initialRange: TimerChartRange

    var body: some View {
        VStack {
            Text("Category Chart")
            Text("Range: \(label(for: initialRange))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func label(for range: TimerChartRange) -> String {
        switch range {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        }
    }
}

struct StudyHistoryBarChart: View {
    var initialRange: TimerChartRange

    var body: some View {
        VStack {
            Text("History Chart")
            Text("Range: \(label(for: initialRange))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func label(for range: TimerChartRange) -> String {
        switch range {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        }
    }
}

// Privacy settings shell
struct PrivacySettingsView: View { var body: some View { Text("Privacy Settings") } }
