import SwiftUI

struct AddSemesterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coursesStore: CoursesStore

    @State private var name: String = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
    @State private var markAsCurrent: Bool = true

    var body: some View {
        VStack {
            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("New Semester")
                        .font(.title3.bold())

                    Text("Name")
                    TextField("Name (e.g. Fall 2025)", text: $name)

                    Text("Start date")
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)

                    Text("End date")
                    DatePicker("End", selection: $endDate, displayedComponents: .date)

                    Toggle("Set as current semester", isOn: $markAsCurrent)

                    HStack {
                        Spacer()
                        Button("Cancel") { dismiss() }
                        Button("Save") {
                            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            guard endDate >= startDate else { return }
                            let sem = Semester(
                                name: name,
                                startDate: startDate,
                                endDate: endDate,
                                isCurrent: markAsCurrent
                            )
                            coursesStore.addSemester(sem)
                            if markAsCurrent { coursesStore.setCurrentSemester(sem) }
                            dismiss()
                        }
                        .buttonStyle(.glassBlueProminent)
                    }
                    .font(.callout)
                }
            }
            .padding(20)
        }
        .frame(width: 420)
    }
}
