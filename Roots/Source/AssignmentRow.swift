import SwiftUI

struct AssignmentRow: View {
    let task: AppTask

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(task.title)
                    .font(DesignSystem.Typography.body)
                if let due = task.due {
                    // Use app-wide time formatting via shared settings
                    Text(AppSettingsModel.shared.formattedTime(due))
                        .font(DesignSystem.Typography.caption)
                }
            }
            Spacer()
            Text("\(task.estimatedMinutes) min")
                .font(DesignSystem.Typography.caption)
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .contextMenu {
            Button("Edit") {
                // TODO: wire edit
            }
            Button("Delete") {
                AssignmentsStore.shared.removeTask(id: task.id)
            }
        }
    }
}