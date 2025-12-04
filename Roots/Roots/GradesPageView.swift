import SwiftUI

// MARK: - Models

struct GradeCourseSummary: Identifiable, Hashable {
    let id: UUID
    var courseCode: String
    var courseTitle: String
    var currentPercentage: Double?
    var targetPercentage: Double?
    var letterGrade: String?
    var creditHours: Int
    var colorTag: ColorTag
}

struct GradeComponent: Identifiable, Hashable {
    let id: UUID
    var name: String
    var weightPercent: Double
    var earnedPercent: Double?
}

struct CourseGradeDetail: Identifiable, Hashable {
    let id: UUID
    var course: GradeCourseSummary
    var components: [GradeComponent]
    var notes: String
}

enum GradeViewSegment: String, CaseIterable, Identifiable {
    case overall, byCourse, scenarios
    var id: String { rawValue }

    var label: String {
        switch self {
        case .overall: return "Overall"
        case .byCourse: return "By Course"
        case .scenarios: return "What-If"
        }
    }
}

// MARK: - Root View

struct GradesPageView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var segment: GradeViewSegment = .overall
    @State private var allCourses: [GradeCourseSummary] = GradesPageView.sampleCourses
    @State private var courseDetails: [CourseGradeDetail] = GradesPageView.sampleCourseDetails
    @State private var selectedCourseDetail: CourseGradeDetail? = nil
    @State private var searchText: String = ""
    @State private var gpaScale: Double = 4.0
    @State private var showEditTargetSheet: Bool = false
    @State private var courseToEditTarget: GradeCourseSummary? = nil
    @State private var whatIfSlider: Double = 90

    private let cardCorner: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    adaptiveColumns(width: proxy.size.width)

                    footer
                }
                .padding(16)
            }
            .rootsSystemBackground()
        }
        .sheet(isPresented: $showEditTargetSheet) {
            if let course = courseToEditTarget {
                EditTargetGradeSheet(course: course) { updatedTarget, letter in
                    updateTarget(for: course, to: updatedTarget, letter: letter)
                }
            }
        }
        .onAppear {
            if selectedCourseDetail == nil {
                selectedCourseDetail = courseDetails.first
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grades")
                    .font(.title2.weight(.semibold))
                Text("Synced from Courses and Assignments")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Picker("Segment", selection: $segment.animation(.spring(response: 0.3, dampingFraction: 0.85))) {
                ForEach(GradeViewSegment.allCases) { seg in
                    Text(seg.label).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            TextField("Search courses", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            Picker("GPA Scale", selection: $gpaScale) {
                Text("4.0").tag(4.0)
                Text("5.0").tag(5.0)
            }
            .pickerStyle(.menu)

            Button {
                // stub export
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Columns

    @ViewBuilder
    private func adaptiveColumns(width: CGFloat) -> some View {
        let isCompact = width < 1100

        if isCompact {
            VStack(spacing: 16) {
                overallColumn
                courseListCard
                detailCard
            }
        } else {
            HStack(alignment: .top, spacing: 16) {
                overallColumn
                    .frame(width: width * 0.25)
                courseListCard
                    .frame(width: width * 0.35)
                detailCard
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var overallColumn: some View {
        VStack(spacing: 12) {
            OverallStatusCard(courses: filteredCourses, gpaScale: gpaScale, emphasize: segment == .overall)
        }
    }

    private var courseListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("By Course")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("Sort", selection: .constant(0)) {
                    Text("Course").tag(0)
                    Text("Grade").tag(1)
                    Text("Credits").tag(2)
                }
                .pickerStyle(.menu)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(filteredCourses) { course in
                        CourseGradeRow(
                            course: course,
                            isSelected: course.id == selectedCourseDetail?.course.id,
                            isScenarioHighlight: segment == .scenarios && isNearThreshold(course),
                            onSelect: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    selectedCourseDetail = courseDetails.first(where: { $0.course.id == course.id })
                                }
                            },
                            onEditTarget: {
                                courseToEditTarget = course
                                showEditTargetSheet = true
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
    }

    private var detailCard: some View {
        GradeDetailCard(
            detail: Binding(
                get: { selectedCourseDetail },
                set: { selectedCourseDetail = $0 }
            ),
            segment: segment,
            whatIfInput: $whatIfSlider,
            onEditTarget: { course in
                courseToEditTarget = course
                showEditTargetSheet = true
            },
            onUpdateNotes: { updated in
                if let idx = courseDetails.firstIndex(where: { $0.id == updated.id }) {
                    courseDetails[idx] = updated
                    if selectedCourseDetail?.id == updated.id {
                        selectedCourseDetail = updated
                    }
                }
            }
        )
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
    }

    private var footer: some View {
        Text("Grades are approximations and may differ from your institution's official system.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Helpers

    private var filteredCourses: [GradeCourseSummary] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return allCourses }
        let q = searchText.lowercased()
        return allCourses.filter { course in
            course.courseCode.lowercased().contains(q) || course.courseTitle.lowercased().contains(q)
        }
    }

    private func isNearThreshold(_ course: GradeCourseSummary) -> Bool {
        guard let percent = course.currentPercentage else { return false }
        let fractional = percent.truncatingRemainder(dividingBy: 10)
        return fractional >= 7
    }

    private func updateTarget(for course: GradeCourseSummary, to target: Double?, letter: String?) {
        // Update course summary
        if let idx = allCourses.firstIndex(where: { $0.id == course.id }) {
            allCourses[idx].targetPercentage = target
            allCourses[idx].letterGrade = letter ?? allCourses[idx].letterGrade
        }
        // Update detail
        if let detailIdx = courseDetails.firstIndex(where: { $0.course.id == course.id }) {
            courseDetails[detailIdx].course.targetPercentage = target
            courseDetails[detailIdx].course.letterGrade = letter ?? courseDetails[detailIdx].course.letterGrade
            selectedCourseDetail = courseDetails[detailIdx]
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCorner, style: .continuous).fill(.thinMaterial)
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
    }
}

// MARK: - Overall Status

struct OverallStatusCard: View {
    var courses: [GradeCourseSummary]
    var gpaScale: Double
    var emphasize: Bool

    var body: some View {
        let overallPercent = weightedOverallPercent
        let gpa = gpaValue(overallPercent: overallPercent)
        VStack(alignment: .leading, spacing: 10) {
            Text("Overall Status")
                .font(.system(size: 14, weight: .semibold))

            Text("GPA \(String(format: "%.2f", gpa)) / \(String(format: "%.1f", gpaScale))")
                .font(.system(size: emphasize ? 28 : 24, weight: .bold))

            Text("Weighted \(String(format: "%.1f", overallPercent))% • \(courses.count) courses")
                .font(.footnote)
                .foregroundColor(.secondary)

            ProgressView(value: overallPercent / 100)
                .progressViewStyle(.linear)

            HStack {
                if let maxCourse = courses.max(by: { ($0.currentPercentage ?? 0) < ($1.currentPercentage ?? 0) }) {
                    Text("Highest: \(maxCourse.courseCode) \(Int(maxCourse.currentPercentage ?? 0))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let minCourse = courses.min(by: { ($0.currentPercentage ?? 0) < ($1.currentPercentage ?? 0) }) {
                    Text("Lowest: \(minCourse.courseCode) \(Int(minCourse.currentPercentage ?? 0))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var weightedOverallPercent: Double {
        let totalCredits = courses.reduce(0) { $0 + $1.creditHours }
        guard totalCredits > 0 else { return 0 }
        let weighted = courses.reduce(0.0) { partial, course in
            let pct = course.currentPercentage ?? 0
            return partial + pct * Double(course.creditHours)
        }
        return weighted / Double(totalCredits)
    }

    private func gpaValue(overallPercent: Double) -> Double {
        // Simple linear mapping: 90-100 -> 4.0, 80-89 -> 3.0, etc.
        let scaled = (overallPercent / 100) * gpaScale
        return min(gpaScale, max(0, scaled))
    }
}

// MARK: - Course Row

struct CourseGradeRow: View {
    var course: GradeCourseSummary
    var isSelected: Bool
    var isScenarioHighlight: Bool
    var onSelect: () -> Void
    var onEditTarget: () -> Void

    private var ringColor: Color { course.colorTag.color }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(ringColor)
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(course.courseCode) · \(course.courseTitle)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let pct = course.currentPercentage {
                            Text("\(String(format: "%.1f", pct))%")
                        } else {
                            Text("No grade yet")
                        }
                        if let letter = course.letterGrade { Text("· \(letter)") }
                        Text("· \(course.creditHours) credits")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    ring
                    if let target = course.targetPercentage {
                        Text("Target \(Int(target))%")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color(nsColor: .controlAccentColor).opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isScenarioHighlight ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit target") { onEditTarget() }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                .frame(width: 44, height: 44)
            if let pct = course.currentPercentage {
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(pct / 100, 0), 1)))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                Text("\(Int(pct))%")
                    .font(.caption2.weight(.semibold))
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Detail Card

struct GradeDetailCard: View {
    @Binding var detail: CourseGradeDetail?
    var segment: GradeViewSegment
    @Binding var whatIfInput: Double
    var onEditTarget: (GradeCourseSummary) -> Void
    var onUpdateNotes: (CourseGradeDetail) -> Void

    var body: some View {
        if let detail {
            VStack(alignment: .leading, spacing: 12) {
                header(detail.course)
                components(detail.components)
                if segment == .scenarios {
                    whatIf(detail)
                }
                notes(detail)
                Text("Grades are approximations and may differ from your institution's official system.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Select a course from the center panel to see its grade breakdown.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func header(_ course: GradeCourseSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Grade Components – \(course.courseCode)")
                .font(.system(size: 14, weight: .semibold))
            Text(course.courseTitle)
                .font(.headline)
            HStack(spacing: 8) {
                if let current = course.currentPercentage {
                    Text("Current: \(String(format: "%.1f", current))%")
                } else { Text("Current: —") }
                if let target = course.targetPercentage {
                    Text("· Target: \(Int(target))%")
                }
                if let letter = course.letterGrade { Text("· \(letter)") }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Button("Edit target") {
                onEditTarget(course)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func components(_ components: [GradeComponent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(components) { comp in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comp.name)
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        if let earned = comp.earnedPercent {
                            Text("\(Int(earned))%")
                                .font(.caption.weight(.semibold))
                        } else {
                            Text("No data yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("Weight: \(Int(comp.weightPercent))%")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let earned = comp.earnedPercent {
                        ProgressView(value: min(max(earned / 100, 0), 1))
                            .tint(progressColor(earned))
                    }
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private func progressColor(_ percent: Double) -> Color {
        switch percent {
        case ..<70: return .red
        case 70..<85: return .yellow
        default: return .green
        }
    }

    private func whatIf(_ detail: CourseGradeDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What-If Scenario")
                .font(.system(size: 14, weight: .semibold))
            Slider(value: $whatIfInput, in: 50...100, step: 1) {
                Text("Expected average on remaining work")
            }
            Text("If you score \(Int(whatIfInput))% on remaining work, your projected final grade is \(String(format: "%.1f", projectedGrade(detail)))%.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private func projectedGrade(_ detail: CourseGradeDetail) -> Double {
        // Simplistic blend: average known earnedPercent weighted, remaining weight uses whatIfInput
        let knownWeight = detail.components.reduce(0) { $0 + ($1.earnedPercent == nil ? 0 : $1.weightPercent) }
        let knownScore = detail.components.reduce(0) { partial, comp in
            guard let earned = comp.earnedPercent else { return partial }
            return partial + earned * (comp.weightPercent / 100)
        }
        let remainingWeight = max(0, 100 - knownWeight)
        let projected = knownScore + whatIfInput * (remainingWeight / 100)
        return projected
    }

    private func notes(_ detail: CourseGradeDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.system(size: 14, weight: .semibold))
            TextEditor(text: Binding(
                get: { detail.notes },
                set: { newValue in
                    var updated = detail
                    updated.notes = newValue
                    onUpdateNotes(updated)
                    self.detail = updated
                }
            ))
            .frame(minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }
}

// MARK: - Edit Target Sheet

struct EditTargetGradeSheet: View {
    var course: GradeCourseSummary
    var onSave: (Double?, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var targetPercent: Double = 90
    @State private var letter: String = "A"

    private let letters = ["A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D", "F"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    Slider(value: $targetPercent, in: 50...100, step: 1) {
                        Text("Target %")
                    }
                    Text("\(Int(targetPercent))%")
                        .font(.headline)
                }

                Section("Letter") {
                    Picker("Letter", selection: $letter) {
                        ForEach(letters, id: \.self) { l in
                            Text(l).tag(l)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text("Targets help scenario calculations and visual indicators. This does not affect official grades.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Target for \(course.courseCode)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(targetPercent, letter)
                        dismiss()
                    }
                }
            }
            .onAppear {
                targetPercent = course.targetPercentage ?? 90
                letter = course.letterGrade ?? "A"
            }
        }
    }
}

// MARK: - Samples

private extension GradesPageView {
    static var sampleCourses: [GradeCourseSummary] {
        [
            GradeCourseSummary(id: UUID(), courseCode: "MA 231", courseTitle: "Calculus II", currentPercentage: 92.3, targetPercentage: 95, letterGrade: "A-", creditHours: 4, colorTag: .blue),
            GradeCourseSummary(id: UUID(), courseCode: "CS 240", courseTitle: "Data Structures", currentPercentage: 88.5, targetPercentage: 92, letterGrade: "B+", creditHours: 3, colorTag: .purple),
            GradeCourseSummary(id: UUID(), courseCode: "BIO 101", courseTitle: "Biology", currentPercentage: 79.8, targetPercentage: 85, letterGrade: "C+", creditHours: 3, colorTag: .green),
            GradeCourseSummary(id: UUID(), courseCode: "HIS 120", courseTitle: "World History", currentPercentage: 85.4, targetPercentage: 90, letterGrade: "B", creditHours: 3, colorTag: .orange)
        ]
    }

    static var sampleCourseDetails: [CourseGradeDetail] {
        sampleCourses.map { course in
            CourseGradeDetail(
                id: UUID(),
                course: course,
                components: [
                    GradeComponent(id: UUID(), name: "Homework", weightPercent: 25, earnedPercent: 90),
                    GradeComponent(id: UUID(), name: "Exams", weightPercent: 40, earnedPercent: 85),
                    GradeComponent(id: UUID(), name: "Labs", weightPercent: 20, earnedPercent: 88),
                    GradeComponent(id: UUID(), name: "Participation", weightPercent: 15, earnedPercent: 95)
                ],
                notes: "Track upcoming exam weight adjustments here."
            )
        }
    }
}

