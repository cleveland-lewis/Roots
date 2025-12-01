import SwiftUI

struct AddAssignmentView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var coursesStore: CoursesStore

    @State private var title: String = ""
    @State private var due: Date = Date()
    @State private var estimatedMinutes: Int = 60
    @State private var selectedCourseId: UUID? = nil
    @State private var type: TaskType = .reading

    var onSave: (Task) -> Void

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCourseId == nil
    }

    var body: some View {
        VStack(spacing: 12) {
            // Card container
            VStack(alignment: .leading, spacing: 12) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("New Assignment")
                        .font(.title3).bold()
                    Text("Title, due date, course, and type are required.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Core
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title").font(.subheadline).bold()
                    TextField("e.g. Read Chapter 3", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                // Schedule
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedule").font(.subheadline).bold()

                    DatePicker("Due date", selection: $due, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.field)

                    Stepper(value: $estimatedMinutes, in: 15...240, step: 15) {
                        Text("Estimated: \(estimatedMinutes) min")
                    }
                }

                // Context
                VStack(alignment: .leading, spacing: 8) {
                    Text("Context").font(.subheadline).bold()

                    // Course picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Course").font(.caption)
                        if coursesStore.currentSemesterId == nil {
                            Text("Select a current semester in Courses before adding assignments.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Picker("Course", selection: $selectedCourseId) {
                                Text("No courses").tag(Optional<UUID>(nil))
                            }
                            .disabled(true)
                        } else {
                            if coursesStore.currentSemesterCourses.isEmpty {
                                Text("No courses in the current semester. Add courses and mark the semester as current first.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Picker("Course", selection: $selectedCourseId) {
                                    Text("No courses").tag(Optional<UUID>(nil))
                                }
                                .disabled(true)
                            } else {
                                Picker("Course", selection: $selectedCourseId) {
                                    ForEach(coursesStore.currentSemesterCourses, id: \.id) { c in
                                        Text("\(c.code) — \(c.name)").tag(Optional(c.id))
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }

                    // Type picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type").font(.caption)
                        Picker("Type", selection: $type) {
                            ForEach(TaskType.allCases, id: \.self) { t in
                                Text(displayName(for: t)).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Footer buttons
                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Save") {
                        let task = Task(id: UUID(), title: title.trimmingCharacters(in: .whitespacesAndNewlines), courseId: selectedCourseId, due: due, estimatedMinutes: estimatedMinutes, minBlockMinutes: 20, maxBlockMinutes: 180, difficulty: 0.5, importance: 0.5, type: type, locked: false)
                        onSave(task)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaveDisabled || coursesStore.currentSemesterId == nil)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.thinMaterial)
                    .shadow(radius: 8)
            )
            .padding()
        }
        .frame(minWidth: 420)
    }

    private func displayName(for t: TaskType) -> String {
        switch t {
        case .reading: return "Reading"
        case .problemSet: return "Problemset"
        case .project: return "Project"
        case .examPrep: return "Exam Prep"
        case .other: return "Other"
        }
    }
}
