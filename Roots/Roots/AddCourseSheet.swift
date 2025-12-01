import SwiftUI

struct AddCourseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coursesStore: CoursesStore

    @State private var title: String = ""
    @State private var code: String = ""

    var body: some View {
        VStack {
            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("New Course")
                        .font(.title3.bold())

                    TextField("Title (e.g. Neurobiology)", text: $title)
                    TextField("Code (e.g. BIO 440)", text: $code)

                    HStack {
                        Spacer()
                        Button("Cancel") { dismiss() }
                        Button("Save") {
                            guard let semester = coursesStore.currentSemester else { return }
                            guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

                            coursesStore.addCourse(title: title, code: code, to: semester)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .font(.callout)
                }
            }
            .padding(20)
        }
        .frame(width: 420)
    }
}
