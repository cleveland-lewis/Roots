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
    @EnvironmentObject var settings: AppSettingsModel
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
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceEndCount: Int? = nil
    @State private var recurrenceEndDate: Date? = nil
    @State private var weekdaySelection: [Int: Bool] = Dictionary(uniqueKeysWithValues: (1...7).map { ($0, false) })
    @State private var urlString: String = ""
    @State private var primaryAlertMinutes: Int? = nil
    @State private var secondaryAlertMinutes: Int? = nil
    @State private var isSaving: Bool = false
    @State private var selectedCalendarID: String = ""

    private var availableCalendars: [EKCalendar] {
        DeviceCalendarManager.shared.store.calendars(for: .event).filter { $0.allowsContentModifications }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar matching Apple Calendar style
            HStack {
                Text("New Event")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Divider()
            
            // Main form content with Apple Calendar-style row layout
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title field - prominent, full-width
                    TextField("Title", text: $title)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .onChange(of: title) { _, new in
                            if !userSelectedCategory {
                                if let parsed = parseCategory(from: new) {
                                    category = parsed
                                } else {
                                    category = .other
                                }
                            }
                        }
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    // Location field with icon
                    HStack(spacing: 12) {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        TextField("Location", text: $location)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    // All-day toggle with icon
                    Toggle(isOn: $isAllDay) {
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("All-day")
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    // Start date/time with proper spacing
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("Starts")
                            .frame(width: 60, alignment: .leading)
                        DatePicker("", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    // End date/time with alignment
                    HStack(spacing: 12) {
                        Spacer()
                            .frame(width: 20)
                        Text("Ends")
                            .frame(width: 60, alignment: .leading)
                        DatePicker("", selection: $endDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    // Repeat/Recurrence with menu picker
                    HStack(spacing: 12) {
                        Image(systemName: "repeat")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("Repeat")
                            .frame(width: 60, alignment: .leading)
                        Picker("", selection: $recurrence) {
                            ForEach(CalendarManager.RecurrenceOption.allCases, id: \.self) { opt in
                                Text(opt.rawValue.capitalized).tag(opt)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    
                    // Advanced recurrence controls - indented and grouped
                    if recurrence != .none {
                        Divider()
                            .padding(.leading, 20)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            // Interval stepper
                            HStack(spacing: 12) {
                                Spacer()
                                    .frame(width: 20)
                                Stepper("Every \(recurrenceInterval)", value: $recurrenceInterval, in: 1...52)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Weekday selection for weekly recurrence
                            if recurrence == .weekly {
                                HStack(spacing: 12) {
                                    Spacer()
                                        .frame(width: 20)
                                    HStack(spacing: 6) {
                                        ForEach(1...7, id: \.self) { idx in
                                            let symbol = Calendar.current.veryShortWeekdaySymbols[(idx - 1 + 7) % 7]
                                            Toggle(symbol, isOn: Binding(get: { weekdaySelection[idx] ?? false }, set: { weekdaySelection[idx] = $0 }))
                                                .toggleStyle(.button)
                                                .controlSize(.small)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    // Calendar picker with school calendar lock support
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("Calendar")
                                .frame(width: 60, alignment: .leading)
                            Picker("", selection: $selectedCalendarID) {
                                ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                    HStack(spacing: 6) {
                                        if let cgColor = calendar.cgColor {
                                            Circle()
                                                .fill(Color(cgColor: cgColor))
                                                .frame(width: 8, height: 8)
                                        }
                                        Text(calendar.title)
                                    }
                                    .tag(calendar.calendarIdentifier)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .disabled(settings.lockCalendarPickerToSchool)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        
                        if settings.lockCalendarPickerToSchool {
                            Text("Calendar locked to school calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 52)
                                .padding(.bottom, 6)
                        }
                    }
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    // Category picker with menu style
                    HStack(spacing: 12) {
                        Image(systemName: "tag")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("Category")
                            .frame(width: 60, alignment: .leading)
                        Picker("", selection: Binding(get: { category }, set: { v in category = v; userSelectedCategory = true })) {
                            ForEach(EventCategory.allCases) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    
                    Divider()
                        .padding(.leading, 20)
                    
                    NotesEditor(title: "Notes", text: $notes, minHeight: 100)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
            }
            
            Divider()
            
            // Bottom action buttons matching Apple style
            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add") {
                    createEvent()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 480, height: 560)
        .onAppear {
            // Initialize calendar selection to school calendar or default
            if let schoolCalendar = getSelectedSchoolCalendar() {
                selectedCalendarID = schoolCalendar.calendarIdentifier
            } else if let defaultCalendar = DeviceCalendarManager.shared.store.defaultCalendarForNewEvents {
                selectedCalendarID = defaultCalendar.calendarIdentifier
            } else if let firstCalendar = availableCalendars.first {
                selectedCalendarID = firstCalendar.calendarIdentifier
            }
        }
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
        func buildRecurrenceRule(option: CalendarManager.RecurrenceOption, interval: Int, weekdays: [Int: Bool], endCount: Int?, endDate: Date?) -> EKRecurrenceRule? {
            guard option != .none else { return nil }
            let frequency: EKRecurrenceFrequency
            switch option {
            case .daily: frequency = .daily
            case .weekly: frequency = .weekly
            case .monthly: frequency = .monthly
            case .none: return nil
            }
            var days: [EKRecurrenceDayOfWeek]? = nil
            if option == .weekly {
                let selected = weekdays.filter { $0.value }.map { (index, _) in
                    EKRecurrenceDayOfWeek(EKWeekday(rawValue: index)!)
                }
                if !selected.isEmpty { days = selected }
            }
            var end: EKRecurrenceEnd? = nil
            if let count = endCount { end = EKRecurrenceEnd(occurrenceCount: count) }
            else if let d = endDate { end = EKRecurrenceEnd(end: d) }
            return EKRecurrenceRule(recurrenceWith: frequency, interval: interval, daysOfTheWeek: days, daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: end)
        }
        Task {
            isSaving = true
            // Title is stored exactly as entered - no category munging
            // Category is managed separately via the category field

            do {
                var alarms: [EKAlarm]? = nil
                var builtAlarms: [EKAlarm] = []
                if let pm = primaryAlertMinutes { builtAlarms.append(EKAlarm(relativeOffset: TimeInterval(-pm * 60))) }
                if let sm = secondaryAlertMinutes { builtAlarms.append(EKAlarm(relativeOffset: TimeInterval(-sm * 60))) }
                if !builtAlarms.isEmpty { alarms = builtAlarms }
                let urlVal = URL(string: urlString)
                let rule = buildRecurrenceRule(option: recurrence, interval: recurrenceInterval, weekdays: weekdaySelection, endCount: recurrenceEndCount, endDate: recurrenceEndDate)
                
                // Use selected calendar from picker
                let targetCalendar = availableCalendars.first(where: { $0.calendarIdentifier == selectedCalendarID })
                
                try await calendarManager.saveEvent(title: title, startDate: startDate, endDate: endDate, isAllDay: isAllDay, location: location, notes: notes, url: urlVal, alarms: alarms, recurrenceRule: rule, calendar: targetCalendar, category: category)
                // refresh device events
                await DeviceCalendarManager.shared.refreshEventsForVisibleRange()
            } catch {
                print("Failed to save event: \(error)")
            }
            isSaving = false
            dismiss()
        }
    }
    
    /// Get the selected school calendar for new events
    /// Returns the calendar if found and writable, otherwise nil (will fallback to default)
    private func getSelectedSchoolCalendar() -> EKCalendar? {
        let selectedID = calendarManager.selectedCalendarID
        guard !selectedID.isEmpty else {
            Task { @MainActor in
                Diagnostics.shared.log(.info, subsystem: .calendar, category: "AddEvent", message: "No school calendar selected, will use system default")
            }
            return nil
        }
        
        let store = DeviceCalendarManager.shared.store
        let calendars = store.calendars(for: .event)
        
        guard let calendar = calendars.first(where: { $0.calendarIdentifier == selectedID }) else {
            Task { @MainActor in
                Diagnostics.shared.log(.warn, subsystem: .calendar, category: "AddEvent", message: "Selected school calendar (ID: \(selectedID)) not found, will use system default")
            }
            return nil
        }
        
        guard calendar.allowsContentModifications else {
            Task { @MainActor in
                Diagnostics.shared.log(.warn, subsystem: .calendar, category: "AddEvent", message: "Selected school calendar '\(calendar.title)' is read-only, will use system default")
            }
            return nil
        }
        
        Task { @MainActor in
            Diagnostics.shared.log(.info, subsystem: .calendar, category: "AddEvent", message: "Using selected school calendar: \(calendar.title)")
        }
        return calendar
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
