#if os(macOS)
import SwiftUI

struct AddAssignmentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coursesStore: CoursesStore

    @State private var title: String = ""
    @State private var due: Date = Date()
    @State private var estimatedMinutes: Int = 60
    @State private var selectedCourseId: UUID? = nil
    @State private var type: TaskType
    @State private var attachments: [Attachment] = []
    @State private var notes: String = ""
    @State private var showDiscardDialog = false
    @State private var showingAddCourse = false
    @State private var lockToDueDate = false
    @State private var weightPercent: Double = 0
    @State private var urgency: AssignmentUrgency = .medium
    @State private var status: AssignmentStatus = .notStarted

    var onSave: (AppTask) -> Void

    init(initialType: TaskType = .project, preselectedCourseId: UUID? = nil, onSave: @escaping (AppTask) -> Void) {
        self.onSave = onSave
        self._type = State(initialValue: initialType)
        self._selectedCourseId = State(initialValue: preselectedCourseId)
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCourseId == nil
    }

    private var hasUnsavedChanges: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || selectedCourseId != nil || !attachments.isEmpty || !notes.isEmpty || due.timeIntervalSince1970 != 0
    }

    var body: some View {
        ZStack {
            AppCard {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero inputs
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Title", text: $title)
                            .font(.title3.weight(.semibold))
                            .textFieldStyle(.plain)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(DesignSystem.Materials.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HStack(spacing: 12) {
                            coursePicker
                            categoryPicker
                        }
                    }

                    // Timing
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TIMING")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        RootsCard(compact: true) {
                            VStack(alignment: .leading, spacing: 12) {
                                DatePicker("Due Date", selection: $due, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.field)

                                HStack(spacing: 12) {
                                    Stepper(value: $estimatedMinutes, in: 15...240, step: 15) {
                                        Text("Duration: \(estimatedMinutes) min")
                                    }
                                    Spacer()
                                    Toggle("Lock to date", isOn: $lockToDueDate)
                                        .toggleStyle(.switch)
                                }
                            }
                        }
                    }

                    // Details
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DETAILS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        RootsCard(compact: true) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Urgency").font(.caption).foregroundStyle(.secondary)
                                    Picker("", selection: $urgency) {
                                        ForEach(AssignmentUrgency.allCases) { u in
                                            Text(u.rawValue.capitalized).tag(u)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Weight %").font(.caption).foregroundStyle(.secondary)
                                    TextField("0", value: $weightPercent, formatter: weightFormatter)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Status").font(.caption).foregroundStyle(.secondary)
                                    Picker("", selection: $status) {
                                        ForEach(AssignmentStatus.allCases) { s in
                                            Text(s.label).tag(s)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                Spacer()
                            }
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $notes)
                        .frame(minHeight: 140)
                        .padding(10)
                        .background(DesignSystem.Materials.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Attachments
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ATTACHMENTS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        AttachmentListView(attachments: $attachments, courseId: selectedCourseId)
                    }

                    // Footer buttons
                    HStack {
                        Button("Cancel") {
                            if hasUnsavedChanges {
                                showDiscardDialog = true
                            } else {
                                dismiss()
                            }
                        }
                        .keyboardShortcut(.cancelAction)

                        Spacer()

                        Button("Save") {
                            saveTask()
                        }
                        .buttonStyle(.glassBlueProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(isSaveDisabled)
                    }
                }
                .padding(20)
            }
            .opacity(showingAddCourse ? 0.3 : 1.0)
            .disabled(showingAddCourse)

            if showingAddCourse {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(DesignSystem.Motion.standardSpring) { showingAddCourse = false }
                    }

                // Placeholder for actual add-course UI
                AddCourseSheet()
                    .frame(maxWidth: 520)
                    .transition(DesignSystem.Motion.scaleTransition)
                    .zIndex(1)
            }
        }
        .animation(DesignSystem.Motion.interactiveSpring, value: showingAddCourse)
        .frame(minWidth: 420)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardDialog,
            titleVisibility: .visible
        ) {
            Button("Save and Close") {
                saveTask()
            }
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Save before closing to avoid losing them.")
        }
    }

    private var weightFormatter: NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 1
        return nf
    }

    private var coursePicker: some View {
        Group {
            if coursesStore.currentSemesterCourses.isEmpty {
                Button {
                    withAnimation(DesignSystem.Motion.standardSpring) { showingAddCourse = true }
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Course")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Picker("Course", selection: $selectedCourseId) {
                    ForEach(coursesStore.currentSemesterCourses, id: \.id) { c in
                        Text("\(c.code) · \(c.title)").tag(Optional(c.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var categoryPicker: some View {
        Picker("Category", selection: $type) {
            ForEach(TaskType.allCases, id: \.self) { t in
                Text(displayName(for: t)).tag(t)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func displayName(for t: TaskType) -> String {
        switch t {
        case .project: return "Project"
        case .exam: return "Exam"
        case .quiz: return "Quiz"
        case .practiceHomework: return "Homework"
        case .reading: return "Reading"
        case .review: return "Review"
        }
    }

    private func preselectCourseIfNeeded() {
        if selectedCourseId == nil, let first = coursesStore.currentSemesterCourses.first {
            selectedCourseId = first.id
        }
    }

    private func saveTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let courseId = selectedCourseId else { return }

        let task = AppTask(id: UUID(), title: trimmed, courseId: courseId, due: due, estimatedMinutes: estimatedMinutes, minBlockMinutes: 20, maxBlockMinutes: 180, difficulty: 0.5, importance: 0.5, type: type, locked: lockToDueDate, attachments: attachments, isCompleted: false)
        onSave(task)
        dismiss()
    }
}
#endif
