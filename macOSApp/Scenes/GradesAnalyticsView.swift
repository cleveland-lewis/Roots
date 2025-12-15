import SwiftUI
import Charts

/// Grades Analytics page showing charts, trends, and grade insights
struct GradesAnalyticsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var coursesStore: CoursesStore
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                header
                
                chartsSection
            }
            .padding(DesignSystem.Spacing.large)
        }
        .frame(minWidth: 900, minHeight: 700)
        .rootsSystemBackground()
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
                .foregroundStyle(settings.activeAccentColor)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Week", item.week),
                    y: .value("GPA", item.gpa)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            settings.activeAccentColor.opacity(0.3),
                            settings.activeAccentColor.opacity(0.0)
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
                .foregroundStyle(settings.activeAccentColor)
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
