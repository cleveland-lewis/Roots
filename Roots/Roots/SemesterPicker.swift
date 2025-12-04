import SwiftUI

struct SemesterPicker: View {
    @EnvironmentObject private var coursesStore: CoursesStore
    @Binding var selectedSemesterId: UUID?

    var body: some View {
        Menu {
            // Recent section
            if !coursesStore.semesters.isEmpty {
                Section(header: Text("Recent")) {
                    ForEach(Array(coursesStore.semesters.sorted { $0.startDate > $1.startDate }.prefix(2))) { sem in
                        Button(sem.name) {
                            selectedSemesterId = sem.id
                        }
                    }
                }

                Section(header: Text("All")) {
                    ForEach(coursesStore.semesters.sorted { $0.startDate > $1.startDate }) { sem in
                        Button(sem.name) {
                            selectedSemesterId = sem.id
                        }
                    }
                }
            } else {
                Button("No semesters") {}
            }
        } label: {
            HStack {
                Text(selectedSemesterId.flatMap { id in coursesStore.semesters.first(where: { $0.id == id })?.name } ?? "Select semester")
                Image(systemName: "chevron.down")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }
}
