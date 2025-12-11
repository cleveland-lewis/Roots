import SwiftUI

// Adapt DataManager to the existing CoursesStore so the view can reuse the same semantics.
typealias SemesterTerm = SemesterType

struct SemesterEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager

    // The semester being edited (nil if creating new)
    var semesterToEdit: Semester?

    // Local State
    @State private var term: SemesterTerm = .fall
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var level: EducationLevel = .college
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(60*60*24*120) // roughly +4 months
    @State private var showDeleteAlert = false

    // Computed Name
    var computedName: String {
        "\(term.rawValue) \(year)"
    }

    var body: some View {
        RootsPopupContainer(
            title: semesterToEdit == nil ? "New Semester" : "Edit Semester",
            subtitle: "Set the term, year, and dates"
        ) {
            VStack(spacing: DesignSystem.Spacing.large) {

                // 1. Header Section
                headerSection

                // 2. Form Content
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.large) {
                        termAndYearPickers
                        levelPicker
                        dateSection
                    }
                    .padding(.horizontal, 4) // Tiny padding to prevent clipper
                }

                // 3. Footer Actions
                footerSection
            }
            .padding(DesignSystem.Spacing.large)
            .frame(width: 450, height: 600) // Standard popup size
        } footer: {
            EmptyView()
        }
        .onAppear {
            if let s = semesterToEdit {
                term = s.semesterTerm
                year = Calendar.current.component(.year, from: s.startDate)
                level = s.educationLevel
                startDate = s.startDate
                endDate = s.endDate
            }
        }
        .onChange(of: year) { _, _ in updateDatesForSeason() }
        .onChange(of: term) { _, _ in updateDatesForSeason() }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Text(semesterToEdit == nil ? "New Semester" : "Edit Semester")
                .font(DesignSystem.Typography.header)

            Text(computedName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Material.ultraThin)
                .clipShape(Capsule())
        }
    }

    private var termAndYearPickers: some View {
        RootsCard {
            VStack(spacing: DesignSystem.Spacing.medium) {
                HStack {
                    Text("Term")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Term", selection: $term) {
                        ForEach(SemesterTerm.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                Divider()

                HStack {
                    Text("Academic Year")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Year", selection: $year) {
                        ForEach(2020...2030, id: \.self) { y in
                            Text(String(y)).tag(y)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }
            .padding(DesignSystem.Spacing.medium)
        }
    }

    private var levelPicker: some View {
        RootsCard {
            HStack {
                Text("Education Level")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Level", selection: $level) {
                    ForEach(EducationLevel.allCases) { l in
                        Text(l.rawValue).tag(l)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }
            .padding(DesignSystem.Spacing.medium)
        }
    }

    private var dateSection: some View {
        RootsCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                Text("Duration")
                    .font(DesignSystem.Typography.subHeader)

                HStack {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    Spacer()
                }

                HStack {
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                    Spacer()
                }
            }
            .padding(DesignSystem.Spacing.medium)
        }
    }

    private var footerSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Button(action: saveSemester) {
                Text("Save Semester")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(RootsLiquidButtonStyle())

            if let s = semesterToEdit {
                Button("Delete Semester", role: .destructive) {
                    showDeleteAlert = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .opacity(0.8)
                .confirmationDialog("Delete Semester?", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        deleteSemester(id: s.id)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will move the semester to Recently Deleted. You can recover it within 30 days.")
                }
            }

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Logic

    private func updateDatesForSeason() {
        // Only auto-update dates if we are creating a NEW semester to avoid overwriting user edits
        guard semesterToEdit == nil else { return }

        var components = DateComponents()
        components.year = year

        switch term {
        case .fall:
            components.month = 8; components.day = 20
            startDate = Calendar.current.date(from: components) ?? Date()
            components.month = 12; components.day = 15
            endDate = Calendar.current.date(from: components) ?? Date()

        case .spring:
            components.month = 1; components.day = 10
            startDate = Calendar.current.date(from: components) ?? Date()
            components.month = 5; components.day = 10
            endDate = Calendar.current.date(from: components) ?? Date()

        case .summerI:
            components.month = 5; components.day = 20
            startDate = Calendar.current.date(from: components) ?? Date()
            components.month = 7; components.day = 1
            endDate = Calendar.current.date(from: components) ?? Date()

        case .summerII:
            components.month = 7; components.day = 5
            startDate = Calendar.current.date(from: components) ?? Date()
            components.month = 8; components.day = 15
            endDate = Calendar.current.date(from: components) ?? Date()

        case .winter:
            components.month = 12; components.day = 20
            startDate = Calendar.current.date(from: components) ?? Date()
            components.year = year + 1
            components.month = 1; components.day = 15
            endDate = Calendar.current.date(from: components) ?? Date()
        }
    }

    private func saveSemester() {
        if let existing = semesterToEdit {
            var updated = existing
            updated.semesterTerm = term
            updated.educationLevel = level
            updated.startDate = startDate
            updated.endDate = endDate
            dataManager.updateSemester(updated)
        } else {
            let newSemester = Semester(
                id: UUID(),
                startDate: startDate,
                endDate: endDate,
                isCurrent: false,
                educationLevel: level,
                semesterTerm: term,
                gradProgram: nil,
                isArchived: false,
                deletedAt: nil,
                academicYear: nil,
                notes: nil
            )
            dataManager.addSemester(newSemester)
        }
        dismiss()
    }

    private func deleteSemester(id: UUID) {
        dataManager.deleteSemester(id)
        dismiss()
    }
}
