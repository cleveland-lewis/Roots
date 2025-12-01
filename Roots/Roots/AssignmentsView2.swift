import SwiftUI

struct AssignmentsView2: View {
    @State private var filter: AssignmentsView.Filter = .all
    @EnvironmentObject var assignmentsStore: AssignmentsStore
    @State private var showingAddSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                HStack {
                    Text("Assignments").font(DesignSystem.Typography.title)
                    Spacer()
                    Button { showingAddSheet = true } label: { Label("Add Assignment", systemImage: "plus") }
                        .buttonStyle(.borderedProminent)
                }

                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    // Simple combined list for now
                    if assignmentsStore.tasks.isEmpty {
                        DesignCard(imageName: "Tahoe", material: .constant(DesignSystem.materials.first?.material ?? Material.regularMaterial)) {
                            VStack(spacing: DesignSystem.Spacing.small) {
                                Image(systemName: "tray")
                                    .imageScale(.large)
                                Text("Assignments")
                                    .font(DesignSystem.Typography.title)
                                Text(DesignSystem.emptyStateMessage)
                                    .font(DesignSystem.Typography.body)
                            }
                        }
                        .frame(minHeight: DesignSystem.Cards.defaultHeight)
                    } else {
                        ForEach(assignmentsStore.tasks, id: \.id) { t in
                            AssignmentRow(task: t)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.large)
        }
        .background(DesignSystem.background(for: .light))
        .sheet(isPresented: $showingAddSheet) {
            AddAssignmentView { task in
                AssignmentsStore.shared.addTask(task)
            }
        }
    }
}

struct AssignmentsView2_Previews: PreviewProvider {
    static var previews: some View {
        AssignmentsView2().environmentObject(AssignmentsStore.shared)
    }
}
