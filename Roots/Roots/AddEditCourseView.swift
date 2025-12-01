import SwiftUI

struct AddEditCourseView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    var onSave: (Course) -> Void

    enum Mode {
        case new
        case edit(Course)
    }

    @State private var title: String = ""
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
                TextField("Course Title", text: $title)
                TextField("Course Code", text: $code)
                // Instructor/term/credits not used in new Course model — omit

                ColorPicker("Color", selection: $color)

                Toggle("Archived (placeholder)", isOn: $isArchived)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    let trimmed = title.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }

                    let course: Course
                    switch mode {
                    case .new:
                        course = Course(title: trimmed, code: code, semesterId: UUID())
                    case .edit(let existing):
                        course = Course(id: existing.id, title: trimmed, code: code, semesterId: existing.semesterId, colorHex: existing.colorHex)
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
                title = existing.title
                code = existing.code
                // colorHex -> Color mapping not implemented; keep color default
                isArchived = false
            }
        }
    }

    private var titleText: String {
        switch mode {
        case .new: return "Add Course"
        case .edit: return "Edit Course"
        }
    }
}
