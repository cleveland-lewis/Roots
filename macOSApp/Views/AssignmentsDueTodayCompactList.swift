#if os(macOS)
import SwiftUI

struct AssignmentsDueTodayCompactList: View {
    @ObservedObject var assignmentsStore: AssignmentsStore
    var onSelect: (AppTask) -> Void

    private var todayTasks: [AppTask] {
        let cal = Calendar.current
        return assignmentsStore.tasks.filter { task in
            guard let due = task.due else { return false }
            return cal.isDateInToday(due)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assignments Due Today")
                .font(.headline)

            if todayTasks.isEmpty {
                Text("No assignments due today.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassChrome(cornerRadius: 10)
            } else {
                VStack(spacing: 6) {
                    ForEach(todayTasks, id: \.id) { task in
                        HStack(spacing: 10) {
                            Button(action: {
                                var updated = task
                                updated.isCompleted.toggle()
                                assignmentsStore.updateTask(updated)
                            }) {
                                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                                    .foregroundColor(task.isCompleted ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if let cid = task.courseId {
                                    Text("Course: \(cid.uuidString.prefix(6))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else if let due = task.due {
                                    Text(due, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(DesignSystem.Materials.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onTapGesture { onSelect(task) }
                    }
                }
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .glassCard(cornerRadius: 16)
    }
}
#endif
