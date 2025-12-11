import SwiftUI

struct CourseEditView: View {
    @Environment(\.dismiss) var dismiss
    let coursesStore: CoursesStore
    let semester: Semester?

    @State private var course: Course
    @State private var isNewCourse: Bool

    @State private var selectedColor: Color = .accentColor

    init(course: Course?, semester: Semester? = nil, coursesStore: CoursesStore) {
        self.coursesStore = coursesStore
        self.semester = semester

        if let course = course {
            _course = State(initialValue: course)
            _isNewCourse = State(initialValue: false)
            if let colorHex = course.colorHex, let color = Color(hex: colorHex) {
                _selectedColor = State(initialValue: color)
            }
        } else if let semester = semester {
            _course = State(initialValue: Course(
                title: "",
                code: "",
                semesterId: semester.id
            ))
            _isNewCourse = State(initialValue: true)
        } else {
            // Fallback - should not happen
            _course = State(initialValue: Course(
                title: "",
                code: "",
                semesterId: UUID()
            ))
            _isNewCourse = State(initialValue: true)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Course Title", text: $course.title)
                    TextField("Course Code", text: $course.code)
                        .textCase(.uppercase)

                    Picker("Course Type", selection: $course.courseType) {
                        ForEach(CourseType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("Credits & Schedule") {
                    HStack {
                        TextField("Credits", value: $course.credits, format: .number)
                            .frame(width: 100)

                        Picker("Type", selection: $course.creditType) {
                            ForEach(CreditType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .labelsHidden()
                    }

                    TextField("Meeting Times (e.g., MWF 9:00-10:00)", text: Binding(
                        get: { course.meetingTimes ?? "" },
                        set: { course.meetingTimes = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Details") {
                    TextField("Instructor", text: Binding(
                        get: { course.instructor ?? "" },
                        set: { course.instructor = $0.isEmpty ? nil : $0 }
                    ))

                    TextField("Location", text: Binding(
                        get: { course.location ?? "" },
                        set: { course.location = $0.isEmpty ? nil : $0 }
                    ))

                    ColorPicker("Course Color", selection: $selectedColor)
                }

                Section("Additional Information") {
                    TextField("Syllabus URL or Notes", text: Binding(
                        get: { course.syllabus ?? "" },
                        set: { course.syllabus = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(2...4)

                    TextField("Notes", text: Binding(
                        get: { course.notes ?? "" },
                        set: { course.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNewCourse ? "New Course" : "Edit Course")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isNewCourse ? "Add" : "Save") {
                        saveCourse()
                    }
                    .disabled(course.title.isEmpty || course.code.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private func saveCourse() {
        course.colorHex = selectedColor.toHex()

        if isNewCourse {
            coursesStore.addCourse(course)
        } else {
            coursesStore.updateCourse(course)
        }

        dismiss()
    }
}
