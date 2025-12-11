import SwiftUI

struct AddSemesterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coursesStore: CoursesStore

    @State private var term: SemesterType = .fall
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
    @State private var markAsCurrent: Bool = true

    private var computedName: String { "\(term.rawValue) \(year)" }

    var body: some View {
        VStack {
            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("New Semester")
                        .font(.title3.bold())

                    HStack {
                        Text(computedName)
                            .font(DesignSystem.Typography.subHeader)
                        Spacer()
                    }

                    Picker("Term", selection: $term) {
                        ForEach(SemesterType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }

                    Stepper("Year: \(year)", value: $year, in: 2000...2100) { _ in
                        // update start/end defaults when year changes
                        var comps = Calendar.current.dateComponents([.year, .month, .day], from: startDate)
                        comps.year = year
                        switch term {
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
                            startDate = newStart
                            endDate = Calendar.current.date(byAdding: .month, value: 4, to: newStart) ?? newStart
                        }
                    }

                    Text("Start date")
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)

                    Text("End date")
                    DatePicker("End", selection: $endDate, displayedComponents: .date)

                    Toggle("Set as current semester", isOn: $markAsCurrent)

                    HStack {
                        Spacer()
                        Button("Cancel") { dismiss() }
                        Button("Save") {
                            guard endDate >= startDate else { return }
                            let sem = Semester(
                                startDate: startDate,
                                endDate: endDate,
                                isCurrent: markAsCurrent,
                                educationLevel: .college,
                                semesterTerm: term,
                                academicYear: "\(year)-\(year + 1)"
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
            .padding(RootsSpacing.m)
        }
        .frame(width: 420)
    }
}
