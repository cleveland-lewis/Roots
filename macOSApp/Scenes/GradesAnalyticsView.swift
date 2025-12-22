import SwiftUI
import Charts

/// Grades Analytics page showing charts, trends, and grade insights
struct GradesAnalyticsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var coursesStore: CoursesStore
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Filter State
    @State private var selectedCourseId: UUID?
    @State private var showWeightedGPA: Bool = true
    @State private var selectedDateRange: DateRangeFilter = .allTime
    
    // MARK: - What-If Simulator State
    @State private var whatIfMode: Bool = false
    @State private var whatIfAssignments: [UUID: Double] = [:] // taskId -> hypothetical grade
    
    // MARK: - Interaction State
    @State private var selectedChartElement: String?
    @State private var showRiskBreakdown: Bool = false
    @State private var selectedForecastScenario: ForecastScenario = .realistic
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    header
                    
                    // What-If Banner
                    if whatIfMode {
                        whatIfBanner
                    }
                    
                    filterControls
                    
                    chartsSection
                    
                    if showRiskBreakdown {
                        riskBreakdownSection
                    }
                }
                .padding(DesignSystem.Spacing.large)
            }
            .frame(minWidth: 900, minHeight: 700)
            .rootsSystemBackground()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Grade Analytics")
                    .font(.title.bold())
                
                Text("Visualize your academic performance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
    
    // MARK: - What-If Banner
    
    private var whatIfBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.accentColor)
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("What-If Mode Active")
                    .font(.subheadline.weight(.semibold))
                
                Text("Hypothetical grades won't be saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Reset") {
                resetWhatIfMode()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button {
                whatIfMode = false
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Filter Controls
    
    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)
            
            HStack(spacing: 12) {
                // Course Filter
                Menu {
                    Button("All Courses") {
                        selectedCourseId = nil
                    }
                    
                    Divider()
                    
                    ForEach(coursesStore.courses) { course in
                        Button(course.code) {
                            selectedCourseId = course.id
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "book")
                        Text(selectedCourseId == nil ? "All Courses" : coursesStore.courses.first(where: { $0.id == selectedCourseId })?.code ?? "Course")
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                // Date Range Filter
                Menu {
                    ForEach(DateRangeFilter.allCases, id: \.self) { range in
                        Button(range.label) {
                            selectedDateRange = range
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                        Text(selectedDateRange.label)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                // Weighted Toggle
                Toggle(isOn: $showWeightedGPA) {
                    Label("Weighted", systemImage: "scalemass")
                }
                .toggleStyle(.button)
                .controlSize(.regular)
                
                Spacer()
                
                // What-If Mode Toggle
                Button {
                    whatIfMode.toggle()
                    if whatIfMode {
                        whatIfAssignments = [:]
                    }
                } label: {
                    Label("What-If Mode", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .tint(whatIfMode ? .accentColor : .secondary)
                
                // Risk Breakdown Toggle
                Button {
                    showRiskBreakdown.toggle()
                } label: {
                    Label("Risk Analysis", systemImage: "exclamationmark.triangle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(DesignSystem.Materials.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    // MARK: - Charts Section
    
    private var chartsSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Row 1: GPA Trend + Grade Distribution
            HStack(spacing: DesignSystem.Spacing.medium) {
                gpaTrendChart
                    .frame(maxWidth: .infinity)
                
                gradeDistributionChart
                    .frame(maxWidth: .infinity)
            }
            
            // Row 2: Course Performance + Assignment Completion
            HStack(spacing: DesignSystem.Spacing.medium) {
                coursePerformanceChart
                    .frame(maxWidth: .infinity)
                
                assignmentCompletionChart
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Individual Charts
    
    private var gpaTrendChart: some View {
        RootsChartContainer(
            title: "GPA Trend",
            summary: "Your GPA over time"
        ) {
            let data = generateGPATrendData()
            
            Chart(data) { item in
                LineMark(
                    x: .value("Week", item.week),
                    y: .value("GPA", item.gpa)
                )
                .foregroundStyle(.accentColor)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Week", item.week),
                    y: .value("GPA", item.gpa)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .accentColor.opacity(0.3),
                            .accentColor.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...4.0)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
        }
        .accessibilityLabel("GPA Trend Chart")
        .accessibilityValue("Shows GPA progression over recent weeks")
    }
    
    private var gradeDistributionChart: some View {
        RootsChartContainer(
            title: "Grade Distribution",
            summary: "Breakdown by letter grade"
        ) {
            let data = generateGradeDistributionData()
            
            Chart(data) { item in
                BarMark(
                    x: .value("Grade", item.grade),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(colorForGrade(item.grade))
                .cornerRadius(8)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
        }
        .accessibilityLabel("Grade Distribution Chart")
        .accessibilityValue("Shows count of assignments by letter grade")
    }
    
    private var coursePerformanceChart: some View {
        RootsChartContainer(
            title: "Course Performance",
            summary: "Current grade by course"
        ) {
            let data = generateCoursePerformanceData()
            
            Chart(data) { item in
                BarMark(
                    x: .value("Course", item.courseCode),
                    y: .value("Grade", item.percentage)
                )
                .foregroundStyle(.accentColor)
                .cornerRadius(8)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
        }
        .accessibilityLabel("Course Performance Chart")
        .accessibilityValue("Shows current grade percentage for each course")
    }
    
    private var assignmentCompletionChart: some View {
        RootsChartContainer(
            title: "Assignment Completion",
            summary: "Completed vs. pending"
        ) {
            let data = generateAssignmentCompletionData()
            
            Chart(data) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(item.color)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .overlay {
                VStack(spacing: 4) {
                    Text("\(data.first(where: { $0.status == "Completed" })?.count ?? 0)")
                        .font(.title.bold())
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityLabel("Assignment Completion Chart")
        .accessibilityValue("Shows ratio of completed to pending assignments")
    }
    
    // MARK: - Data Generation
    
    private struct GPATrendItem: Identifiable {
        let id = UUID()
        let week: String
        let gpa: Double
    }
    
    private func generateGPATrendData() -> [GPATrendItem] {
        // Generate sample data - in real implementation, this would come from GradeCalculator
        let weeks = ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5", "Week 6", "Week 7", "Week 8"]
        return weeks.enumerated().map { index, week in
            let baseGPA = 3.0
            let variation = Double.random(in: -0.3...0.5)
            return GPATrendItem(week: week, gpa: min(4.0, max(0, baseGPA + variation + Double(index) * 0.05)))
        }
    }
    
    private struct GradeDistributionItem: Identifiable {
        let id = UUID()
        let grade: String
        let count: Int
    }
    
    private func generateGradeDistributionData() -> [GradeDistributionItem] {
        // Calculate actual grade distribution from assignments
        let tasks = assignmentsStore.tasks.filter { $0.isCompleted && $0.gradeEarnedPoints != nil }
        var gradeCounts: [String: Int] = ["A": 0, "B": 0, "C": 0, "D": 0, "F": 0]
        
        for task in tasks {
            if let earned = task.gradeEarnedPoints, let possible = task.gradePossiblePoints, possible > 0 {
                let percentage = (earned / possible) * 100
                let grade: String
                if percentage >= 90 { grade = "A" }
                else if percentage >= 80 { grade = "B" }
                else if percentage >= 70 { grade = "C" }
                else if percentage >= 60 { grade = "D" }
                else { grade = "F" }
                gradeCounts[grade, default: 0] += 1
            }
        }
        
        return ["A", "B", "C", "D", "F"].map { grade in
            GradeDistributionItem(grade: grade, count: gradeCounts[grade] ?? 0)
        }
    }
    
    private struct CoursePerformanceItem: Identifiable {
        let id = UUID()
        let courseCode: String
        let percentage: Double
    }
    
    private func generateCoursePerformanceData() -> [CoursePerformanceItem] {
        // Calculate current grade for each course
        return coursesStore.courses.compactMap { course in
            if let percentage = GradeCalculator.calculateCourseGrade(courseID: course.id, tasks: assignmentsStore.tasks) {
                return CoursePerformanceItem(courseCode: course.code, percentage: percentage)
            }
            return nil
        }
    }
    
    private struct AssignmentCompletionItem: Identifiable {
        let id = UUID()
        let status: String
        let count: Int
        let color: Color
    }
    
    private func generateAssignmentCompletionData() -> [AssignmentCompletionItem] {
        let completed = assignmentsStore.tasks.filter { $0.isCompleted }.count
        let pending = assignmentsStore.tasks.filter { !$0.isCompleted }.count
        
        return [
            AssignmentCompletionItem(status: "Completed", count: completed, color: .green),
            AssignmentCompletionItem(status: "Pending", count: pending, color: .orange)
        ]
    }
    
    // MARK: - Risk Breakdown Section
    
    private var riskBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Risk Analysis")
                    .font(.title3.bold())
                
                Spacer()
                
                Button {
                    showRiskBreakdown = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 12) {
                riskCard(
                    level: "High Risk",
                    courses: getCoursesAtRisk(threshold: 70),
                    color: .red,
                    icon: "exclamationmark.triangle.fill",
                    description: "Courses below 70% need immediate attention"
                )
                
                riskCard(
                    level: "Moderate Risk",
                    courses: getCoursesAtRisk(threshold: 80, max: 70),
                    color: .orange,
                    icon: "exclamationmark.circle.fill",
                    description: "Courses between 70-80% require monitoring"
                )
                
                riskCard(
                    level: "On Track",
                    courses: getCoursesAtRisk(threshold: 100, max: 80),
                    color: .green,
                    icon: "checkmark.circle.fill",
                    description: "Courses above 80% are performing well"
                )
            }
        }
        .padding()
        .background(DesignSystem.Materials.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func riskCard(level: String, courses: [Course], color: Color, icon: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(level)
                        .font(.headline)
                    
                    Text("(\(courses.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !courses.isEmpty {
                    Text(courses.map { $0.code }.joined(separator: ", "))
                        .font(.caption.bold())
                        .foregroundStyle(color)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func getCoursesAtRisk(threshold: Double, max: Double? = nil) -> [Course] {
        return coursesStore.courses.filter { course in
            if let grade = GradeCalculator.calculateCourseGrade(courseID: course.id, tasks: assignmentsStore.tasks) {
                if let max = max {
                    return grade < threshold && grade >= max
                } else {
                    return grade < threshold
                }
            }
            return false
        }
    }
    
    // MARK: - What-If Functions
    
    private func resetWhatIfMode() {
        whatIfAssignments = [:]
    }
    
    // MARK: - Helpers
    
    private func colorForGrade(_ grade: String) -> Color {
        switch grade {
        case "A": return .green
        case "B": return .blue
        case "C": return .yellow
        case "D": return .orange
        case "F": return .red
        default: return .gray
        }
    }
}

// MARK: - Supporting Types

enum DateRangeFilter: CaseIterable {
    case allTime
    case thisMonth
    case thisQuarter
    case thisSemester
    
    var label: String {
        switch self {
        case .allTime: return "All Time"
        case .thisMonth: return "This Month"
        case .thisQuarter: return "This Quarter"
        case .thisSemester: return "This Semester"
        }
    }
}

enum ForecastScenario: CaseIterable {
    case optimistic
    case realistic
    case pessimistic
    
    var label: String {
        switch self {
        case .optimistic: return "Optimistic"
        case .realistic: return "Realistic"
        case .pessimistic: return "Pessimistic"
        }
    }
}

// MARK: - Preview

#Preview {
    let settings = AppSettings()
    let assignmentsStore = AssignmentsStore.shared
    let coursesStore = CoursesStore(storageURL: nil)
    
    return GradesAnalyticsView()
        .environmentObject(settings)
        .environmentObject(assignmentsStore)
        .environmentObject(coursesStore)
}
