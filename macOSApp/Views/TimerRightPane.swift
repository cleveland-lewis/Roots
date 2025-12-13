#if os(macOS)
import SwiftUI
import Charts

struct TimerRightPane: View {
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var appModel: AppModel
    var activities: [LocalTimerActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                Text("Study Summary")
                    .font(.headline)
                
                TodayStudyStackedBarChart(activities: activities)
                    .frame(height: 220)
            }
            .padding(DesignSystem.Layout.padding.card)
            .glassCard(cornerRadius: 24)

            AssignmentsDueTodayCompactList(assignmentsStore: assignmentsStore) { task in
                // navigate to Assignments page and focus date
                appModel.selectedPage = .assignments
                if let due = task.due {
                    appModel.requestedAssignmentDueDate = due
                }
            }

            Spacer()
        }
    }
}
#endif
