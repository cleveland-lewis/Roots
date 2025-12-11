#if false
import SwiftUI

struct SemesterEditView: View {
    @Environment(\.dismiss) var dismiss
    let coursesStore: CoursesStore

    @State private var semester: Semester
    @State private var isNewSemester: Bool
    @State private var showDeleteConfirmation = false

    init(semester: Semester?, coursesStore: CoursesStore) {
        self.coursesStore = coursesStore

        if let semester = semester {
            _semester = State(initialValue: semester)
            _isNewSemester = State(initialValue: false)
        } else {
            // Create a new semester with default dates
            let calendar = Calendar.current
            let now = Date()
            // Default: current year start
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.month = 8
            components.day = 20
            let startDate = calendar.date(from: components) ?? now
            let endDate = calendar.date(byAdding: .month, value: 4, to: startDate) ?? now

            _semester = State(initialValue: Semester(
                startDate: startDate,
                endDate: endDate,
                educationLevel: .college,
                semesterTerm: .fall
            ))
            _isNewSemester = State(initialValue: true)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(semester.defaultName)
                            .font(DesignSystem.Typography.subHeader)
                        Spacer()
                        // Optional edit override
                        Button("Edit") {
                            // Reveal manual editing - not implemented (keeps minimal for now)
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Academic Year (Optional)", text: Binding(
                        get: { semester.academicYear ?? "" },
                        set: { semester.academicYear = $0.isEmpty ? nil : $0 }
                    ))
                    .help("e.g., 2024-2025")
                }

                Section("Education Level") {
                    Picker("Level", selection: $semester.educationLevel) {
                        ForEach(EducationLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .onChange(of: semester.educationLevel) { _, newLevel in
                        // Reset grad program if not grad
                        if newLevel != .gradSchool { semester.gradProgram = nil }
                    }

                    Picker("Term", selection: $semester.semesterTerm) {
                        ForEach(SemesterType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    // Year picker via Stepper
                    HStack {
                        Text("Year")
                        Spacer()
                        Stepper(value: Binding(get: {
                            Calendar.current.component(.year, from: semester.startDate)
                        }, set: { newYear in
                            var comps = Calendar.current.dateComponents([.year, .month, .day], from: semester.startDate)
                            comps.year = newYear
                            // pick sensible defaults for month/day depending on term
                            switch semester.semesterTerm {
                            case .fall:
                                comps.month = 9; comps.day = 1
                            case .winter:
                                comps.month = 1; comps.day = 6
                            case .spring:
                                comps.month = 1; comps.day = 15
                            case .summerI:
                                comps.month = 6; comps.day = 1
                            case .summerII:
                                comps.month = 7; comps.day = 1
                            }
                            if let newStart = Calendar.current.date(from: comps) {
                                semester.startDate = newStart
                                semester.endDate = Calendar.current.date(byAdding: .month, value: 4, to: newStart) ?? newStart
                            }
                        }, .m), in: 2000...2100)
                    }

                    if semester.educationLevel == .gradSchool {
                        Picker("Graduate Program", selection: Binding(
                            get: { semester.gradProgram ?? .masters },
                            set: { semester.gradProgram = $0 }
                        )) {
                            ForEach(GradSchoolProgram.allCases) { program in
                                Text(program.rawValue).tag(program)
                            }
                        }
                    }
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $semester.startDate, displayedComponents: .date)

                    DatePicker("End Date", selection: $semester.endDate, displayedComponents: .date)
                        .onChange(of: semester.startDate) { _, newStart in
                            if newStart > semester.endDate {
                                semester.endDate = Calendar.current.date(byAdding: .month, value: 4, to: newStart) ?? newStart
                            }
                        }

                    if semester.endDate < semester.startDate {
                        Text("End date must be after start date")
                            .foregroundStyle(.red)
                            .font(DesignSystem.Typography.caption)
                    }
                }

                Section("Status") {
                    Toggle("Set as Current Semester", isOn: $semester.isCurrent)
                        .help("Mark this as your active semester")

                    if !isNewSemester {
                        Toggle("Archived", isOn: $semester.isArchived)
                            .help("Archive this semester to hide it from the main view")
                    }
                }

                Section("Notes") {
                    TextField("Notes (Optional)", text: Binding(
                        get: { semester.notes ?? "" },
                        set: { semester.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }

                // Preview
                Section("Preview") {
                    VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                        HStack {
                            Text(semester.name.isEmpty ? "Semester Name" : semester.name)
                                .font(DesignSystem.Typography.subHeader)

                            if semester.isCurrent {
                                Text("CURRENT")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor, in: Capsule())
                            }
                        }

                        HStack(spacing: 12) {
                            Label(semester.educationLevel.rawValue, systemImage: "graduationcap")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(.secondary)

                            Label(semester.semesterTerm.rawValue, systemImage: "calendar")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(.secondary)

                            if let program = semester.gradProgram {
                                Label(program.rawValue, systemImage: "brain.head.profile")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("\(semester.startDate.formatted(date: .abbreviated, time: .omitted)) - \(semester.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.tertiary)

                        if let academicYear = semester.academicYear, !academicYear.isEmpty {
                            Text("Academic Year: \(academicYear)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !isNewSemester {
                    Section {
                        Button("Delete Semester", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNewSemester ? "New Semester" : "Edit Semester")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isNewSemester ? "Create" : "Save") {
                        saveSemester()
                    }
                    .disabled(semester.name.isEmpty || semester.endDate < semester.startDate)
                }
            }
        }
        .frame(minWidth: 550, minHeight: 700)
        .alert("Delete Semester?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSemester()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move the semester to Recently Deleted. You can recover it within 30 days.")
        }
    }

    private func saveSemester() {
        if isNewSemester {
            coursesStore.addSemester(semester)
        } else {
            coursesStore.updateSemester(semester)
        }

        dismiss()
    }

    private func deleteSemester() {
        coursesStore.deleteSemester(semester.id)
        dismiss()
    }
}

#Preview {
    SemesterEditView(semester: nil, coursesStore: CoursesStore())
        .frame(width: 600, height: 700)
}
#endif
