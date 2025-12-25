#if os(iOS)
import SwiftUI

struct RecentSessionsView: View {
    @ObservedObject var viewModel: TimerPageViewModel
    @State private var editingSession: FocusSession?
    @State private var sessionToDelete: FocusSession?
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedSectionDates, id: \.self) { date in
                    Section(header: Text(sectionTitle(for: date))) {
                        ForEach(groupedSessions[date] ?? []) { session in
                            SessionRow(
                                session: session,
                                activityName: activityName(for: session),
                                onEdit: { editingSession = session },
                                onDelete: {
                                    sessionToDelete = session
                                    showDeleteConfirm = true
                                }
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Recent Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingSession) { session in
                EditSessionSheet(session: session, viewModel: viewModel)
            }
            .alert("Delete Session?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {
                    sessionToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        viewModel.deleteSessions(ids: [session.id])
                    }
                    sessionToDelete = nil
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private var groupedSessions: [Date: [FocusSession]] {
        let calendar = Calendar.current
        let sessions = viewModel.pastSessions
        return Dictionary(grouping: sessions) { session in
            let date = session.startedAt ?? session.endedAt ?? Date()
            return calendar.startOfDay(for: date)
        }
    }

    private var sortedSectionDates: [Date] {
        groupedSessions.keys.sorted(by: >)
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return dateFormatter.string(from: date)
        }
    }

    private func activityName(for session: FocusSession) -> String {
        guard let id = session.activityID,
              let activity = viewModel.activities.first(where: { $0.id == id }) else {
            return "None"
        }
        return activity.name
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

private struct SessionRow: View {
    let session: FocusSession
    let activityName: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: session.mode.systemImage)
                        .foregroundColor(.accentColor)
                    Text(session.mode.displayName)
                        .font(.headline)
                    Spacer()
                    Text(durationString)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Text(activityName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let startedAt = session.startedAt {
                    Text(timeFormatter.string(from: startedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            VStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(.borderless)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }

    private var durationString: String {
        let duration = session.actualDuration
            ?? session.plannedDuration
            ?? (session.endedAt.flatMap { end in session.startedAt.map { end.timeIntervalSince($0) } } ?? 0)
        let total = max(Int(duration.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
}
#endif
