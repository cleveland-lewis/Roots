import SwiftUI

struct AssignmentsView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case dueSoon = "Due Soon"
        case overdue = "Overdue"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .all

    @EnvironmentObject var assignmentsStore: AssignmentsStore

    @State private var showingAddSheet: Bool = false
    @State private var editingTask: AppTask? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                // Toolbar (title removed)
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Spacer()

                    HStack(spacing: DesignSystem.Spacing.small) {
                        Button(action: { showingAddSheet = true }) {
                            Label("Add Assignment", systemImage: "plus")
                        }
                        .buttonStyle(.glassBlueProminent)

                        Picker("Filter", selection: $filter) {
                            ForEach(Filter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    // Due Today
                    Section(header: Text("Due Today").font(DesignSystem.Typography.body)) {
                        let tasks = assignmentsStore.tasks.filter { $0.due != nil && Calendar.current.isDateInToday($0.due!) }
                        if tasks.isEmpty {
                            AppCard {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    Image(systemName: "doc.text")
                                        .imageScale(.large)
                                    Text("Due Today")
                                        .font(DesignSystem.Typography.title)
                                    Text(DesignSystem.emptyStateMessage)
                                        .font(DesignSystem.Typography.body)
                                }
                            }
                            .frame(minHeight: DesignSystem.Cards.defaultHeight)
                        } else {
                            ForEach(tasks, id: \.id) { t in
                                AssignmentRow(task: t)
                            }
                        }
                    }

                    // Due This Week
                    Section(header: Text("Due This Week").font(DesignSystem.Typography.body)) {
                        let tasks = assignmentsStore.tasks.filter { t in
                            if let d = t.due { return Calendar.current.isDate(d, equalTo: Date(), toGranularity: .weekOfYear) }
                            return false
                        }
                        if tasks.isEmpty {
                            AppCard {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    Image(systemName: "calendar")
                                        .imageScale(.large)
                                    Text("Due This Week")
                                        .font(DesignSystem.Typography.title)
                                    Text(DesignSystem.emptyStateMessage)
                                        .font(DesignSystem.Typography.body)
                                }
                            }
                            .frame(minHeight: DesignSystem.Cards.defaultHeight)
                        } else {
                            ForEach(tasks, id: \.id) { t in
                                AssignmentRow(task: t)
                            }
                        }
                    }

                    // Upcoming
                    Section(header: Text("Upcoming").font(DesignSystem.Typography.body)) {
                        let tasks = assignmentsStore.tasks.filter { $0.due == nil }
                        if tasks.isEmpty {
                            AppCard {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    Image(systemName: "clock")
                                        .imageScale(.large)
                                    Text("Upcoming")
                                        .font(DesignSystem.Typography.title)
                                    Text(DesignSystem.emptyStateMessage)
                                        .font(DesignSystem.Typography.body)
                                }
                            }
                            .frame(minHeight: DesignSystem.Cards.defaultHeight)
                        } else {
                            ForEach(tasks, id: \.id) { t in
                                AssignmentRow(task: t)
                            }
                        }
                    }

                    // Overdue
                    Section(header: Text("Overdue").font(DesignSystem.Typography.body)) {
                        let tasks = assignmentsStore.tasks.filter { t in
                            if let d = t.due { return d < Date() }
                            return false
                        }
                        if tasks.isEmpty {
                            AppCard {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    Image(systemName: "clock.badge.exclamationmark")
                                        .imageScale(.large)
                                    Text("Overdue")
                                        .font(DesignSystem.Typography.title)
                                    Text(DesignSystem.emptyStateMessage)
                                        .font(DesignSystem.Typography.body)
                                }
                            }
                            .frame(minHeight: DesignSystem.Cards.defaultHeight)
                        } else {
                            ForEach(tasks, id: \.id) { t in
                                AssignmentRow(task: t)
                            }
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.large)
        }
        .rootsSystemBackground()
        .sheet(isPresented: $showingAddSheet) {
            // wrap to avoid ambiguity with trailing closure initializers
            AddAssignmentView(initialType: .reading, onSave: { task in
                AssignmentsStore.shared.addTask(task)
            })
        }
    }
}

struct AssignmentsView_Previews: PreviewProvider {
    static var previews: some View {
        AssignmentsView().environmentObject(AssignmentsStore.shared)
    }
}
