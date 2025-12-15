#if os(macOS)
import SwiftUI

struct SemestersSettingsView: View {
    @EnvironmentObject var coursesStore: CoursesStore
    @State private var editingSemester: Semester?
    @State private var showingAddSemester = false

    private var groupedArchivedSemesters: [(year: Int, semesters: [Semester])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: coursesStore.archivedSemesters) { semester in
            calendar.component(.year, from: semester.startDate)
        }

        return groups
            .map { (year: $0.key, semesters: $0.value.sorted { $0.startDate > $1.startDate }) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        Form {
            Section {
                if coursesStore.activeSemesters.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(.tertiary)
                            Text("No semesters defined")
                                .font(DesignSystem.Typography.subHeader)
                                .foregroundStyle(.secondary)
                            Button("Create Your First Semester") {
                                showingAddSemester = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                } else {
                    ForEach(coursesStore.activeSemesters) { semester in
                        SemesterSettingsRow(
                            semester: semester,
                            onToggleCurrent: { coursesStore.toggleCurrentSemester($0) },
                            onEdit: { editingSemester = semester },
                            onArchive: { coursesStore.toggleArchiveSemester(semester) }
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Active Semesters")
                    Spacer()
                    Button {
                        showingAddSemester = true
                    } label: {
                        Label("Add Semester", systemImage: "plus")
                            .font(DesignSystem.Typography.caption)
                    }
                    .buttonStyle(.borderless)
                }
            } footer: {
                Text("Manage your academic semesters. The current semester is used for new courses and appears in the main interface.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if !coursesStore.archivedSemesters.isEmpty {
                Section("Archived Semesters") {
                    ForEach(groupedArchivedSemesters, id: \.year) { group in
                        Text("\(group.year)")
                            .font(DesignSystem.Typography.subHeader)
                            .padding(.vertical, 4)
                        ForEach(group.semesters) { semester in
                            SemesterSettingsRow(
                                semester: semester,
                                onToggleCurrent: { coursesStore.toggleCurrentSemester($0) },
                                onEdit: { editingSemester = semester },
                                onArchive: { coursesStore.toggleArchiveSemester(semester) }
                            )
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingSemester) { semester in
            SemesterEditorView(semesterToEdit: semester)
                .environmentObject(coursesStore)
        }
        .sheet(isPresented: $showingAddSemester) {
            SemesterEditorView(semesterToEdit: nil)
                .environmentObject(coursesStore)
        }
    }
}

// MARK: - Semester Settings Row

struct SemesterSettingsRow: View {
    let semester: Semester
    let onToggleCurrent: (Semester) -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(semester.name)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.primary)

                    if semester.isCurrent {
                        Text("CURRENT")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }

                    if semester.isArchived {
                        Text("ARCHIVED")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary, in: Capsule())
                    }
                }

                HStack(spacing: DesignSystem.Layout.spacing.small) {
                    Text(semester.educationLevel.rawValue)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(semester.semesterTerm.rawValue)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)

                    if let program = semester.gradProgram {
                        Text("•")
                            .foregroundStyle(.tertiary)

                        Text(program.rawValue)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(semester.startDate.formatted(date: .abbreviated, time: .omitted)) – \(semester.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Actions
            HStack(spacing: DesignSystem.Layout.spacing.small) {
                Button {
                    withAnimation(DesignSystem.Motion.interactiveSpring) {
                        onToggleCurrent(semester)
                    }
                } label: {
                    Image(systemName: semester.isCurrent ? "star.fill" : "star")
                        .font(DesignSystem.Typography.body)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
                .help(semester.isCurrent ? "Unset as Current Semester" : "Set as Current Semester")

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(DesignSystem.Typography.body)
                }
                .buttonStyle(.borderless)
                .help("Edit Semester")

                Button {
                    onArchive()
                } label: {
                    Image(systemName: semester.isArchived ? "tray.and.arrow.up" : "archivebox")
                        .font(DesignSystem.Typography.body)
                }
                .buttonStyle(.borderless)
                .help(semester.isArchived ? "Unarchive" : "Archive")
            }
        }
        .padding(.vertical, 6)
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    SemestersSettingsView()
        .environmentObject(CoursesStore())
        .frame(width: 500, height: 600)
}
#endif
#endif
