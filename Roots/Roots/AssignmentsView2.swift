import SwiftUI

struct AssignmentsView2: View {
    @EnvironmentObject var assignmentsStore: AssignmentsStore
    @State private var showingAddSheet = false

    var body: some View {
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                HStack {
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Add Assignment")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                }

                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    // Simple combined list for now
                    if assignmentsStore.tasks.isEmpty {
                        AppCard {
                            VStack(spacing: DesignSystem.Spacing.small) {
                                Image(systemName: "tray")
                                    .imageScale(.large)
                                Text("Assignments")
                                    .font(DesignSystem.Typography.title)
                                Text(DesignSystem.emptyStateMessage)
                                    .font(DesignSystem.Typography.body)
                            }
                        }
                        .frame(minHeight: DesignSystem.Cards.cardMinHeight)
                    } else {
                        ForEach(assignmentsStore.tasks, id: \.id) { t in
                            AssignmentRow(task: t)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.large)
        }
        .rootsSystemBackground()
        .sheet(isPresented: $showingAddSheet) {
            AddAssignmentView(initialType: .reading, onSave: { task in
                AssignmentsStore.shared.addTask(task)
            })
        }
    }
}

struct AssignmentsView2_Previews: PreviewProvider {
    static var previews: some View {
        AssignmentsView2().environmentObject(AssignmentsStore.shared)
    }
}
