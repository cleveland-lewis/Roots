import SwiftUI

struct AddEditCourseView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    var onSave: (Course) -> Void

    enum Mode {
        case new
        case edit(Course)
    }

    @State private var name: String = ""
    @State private var code: String = ""
    @State private var instructor: String = ""
    @State private var term: String = ""
    @State private var credits: Int = 3
    @State private var color: Color = .accentColor
    @State private var isArchived: Bool = false

    init(mode: Mode, onSave: @escaping (Course) -> Void) {
        self.mode = mode
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.bold())

            Form {
                TextField("Course Name", text: $name)
                TextField("Course Code", text: $code)
                TextField("Instructor", text: $instructor)
                TextField("Term (e.g. Fall 2025)", text: $term)

                Stepper(value: $credits, in: 1...8) {
                    Text("Credits: \(credits)")
                }

                ColorPicker("Color", selection: $color)

                Toggle("Archived", isOn: $isArchived)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }

                    let course: Course
                    switch mode {
                    case .new:
                        course = Course(id: UUID(), name: trimmed, code: code, instructor: instructor, term: term, color: color, credits: credits, isArchived: isArchived)
                    case .edit(let existing):
                        course = Course(id: existing.id, name: trimmed, code: code, instructor: instructor, term: term, color: color, credits: credits, isArchived: isArchived)
                    }

                    onSave(course)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 420)
        .onAppear {
            if case .edit(let existing) = mode {
                name = existing.name
                code = existing.code
                instructor = existing.instructor
                term = existing.term
                credits = existing.credits
                color = existing.color
                isArchived = existing.isArchived
            }
        }
    }

    private var title: String {
        switch mode {
        case .new: return "Add Course"
        case .edit: return "Edit Course"
        }
    }
}
