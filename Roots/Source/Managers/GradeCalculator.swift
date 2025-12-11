import Foundation

enum GradeCalculator {
    /// Computes a weighted percentage grade for a course based on completed tasks.
    /// - Parameters:
    ///   - courseID: Course identifier to filter tasks.
    ///   - tasks: List of tasks (assignments/exams) with grade metadata.
    /// - Returns: Percentage 0...100 if any graded work exists, otherwise nil.
    static func calculateCourseGrade(courseID: UUID, tasks: [AppTask]) -> Double? {
        let graded = tasks.filter { task in
            task.courseId == courseID &&
            task.isCompleted &&
            task.gradeEarnedPoints != nil &&
            task.gradePossiblePoints ?? 0 > 0
        }
        guard !graded.isEmpty else { return nil }

        var totalWeighted: Double = 0
        var totalWeights: Double = 0

        for task in graded {
            let weight = task.gradeWeightPercent ?? 0
            guard weight > 0 else { continue }
            let earned = task.gradeEarnedPoints ?? 0
            let possible = task.gradePossiblePoints ?? 0
            guard possible > 0 else { continue }
            let percent = (earned / possible) * 100
            totalWeighted += percent * weight
            totalWeights += weight
        }

        guard totalWeights > 0 else { return nil }
        return totalWeighted / totalWeights
    }

    /// Computes GPA across courses, mapped to 4.0 scale.
    /// - Parameters:
    ///   - courses: All courses to include.
    ///   - tasks: Tasks containing grade metadata.
    /// - Returns: GPA on a 4.0 scale (0 if no graded courses).
    static func calculateGPA(courses: [Course], tasks: [AppTask]) -> Double {
        var total: Double = 0
        var creditSum: Double = 0

        for course in courses {
            guard let percent = calculateCourseGrade(courseID: course.id, tasks: tasks) else { continue }
            let gpaValue = mapPercentToGPA(percent)
            let credits = course.credits ?? 1
            total += gpaValue * credits
            creditSum += credits
        }

        guard creditSum > 0 else { return 0 }
        return total / creditSum
    }

    /// Maps percentage grade to GPA scale.
    private static func mapPercentToGPA(_ percent: Double) -> Double {
        switch percent {
        case 93...: return 4.0
        case 90..<93: return 3.7
        case 87..<90: return 3.3
        case 83..<87: return 3.0
        case 80..<83: return 2.7
        case 77..<80: return 2.3
        case 73..<77: return 2.0
        case 70..<73: return 1.7
        case 67..<70: return 1.3
        case 63..<67: return 1.0
        case 60..<63: return 0.7
        default: return 0.0
        }
    }

    /// Converts a percentage score to a letter grade.
    static func letterGrade(for percent: Double) -> String {
        switch percent {
        case 93...: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 63..<67: return "D"
        case 60..<63: return "D-"
        default: return "F"
        }
    }
}
