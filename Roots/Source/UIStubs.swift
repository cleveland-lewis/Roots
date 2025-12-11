import SwiftUI

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
struct CalendarDayView: View { var body: some View { Text("Day") } }
struct CalendarWeekView: View { var body: some View { Text("Week") } }
struct CalendarYearView: View { var body: some View { Text("Year") } }
struct CalendarGrid: View { var body: some View { Text("Grid") } }
struct CalendarHeader: View { var body: some View { Text("Calendar") } }
struct AddEventPopup: View { var body: some View { Text("Add Event") } }

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
