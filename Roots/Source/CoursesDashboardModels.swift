import Foundation
import SwiftUI

// MARK: - Enhanced Course Model for Dashboard

struct CourseDashboard: Identifiable, Hashable {
    let id: UUID
    var semesterId: UUID?
    var title: String
    var code: String
    var instructor: String
    var credits: Double
    var currentGrade: Double // 0.0 - 100.0
    var progress: Double // 0.0 - 1.0
    var colorHex: String
    var term: String
    var location: String?
    var meetings: [DashboardCourseMeeting]
    var syllabusWeights: SyllabusWeights
    var analytics: CourseAnalytics
    var instructorNotes: String?
    var upcomingDeadlines: [CourseDeadline]

    init(id: UUID = UUID(),
         title: String,
         code: String,
         instructor: String,
         credits: Double,
         currentGrade: Double,
         progress: Double = 0.65,
         colorHex: String,
         term: String = "Fall 2025",
         location: String? = nil,
         meetings: [DashboardCourseMeeting] = [],
         syllabusWeights: SyllabusWeights = SyllabusWeights(),
         analytics: CourseAnalytics = CourseAnalytics(),
         instructorNotes: String? = nil,
         upcomingDeadlines: [CourseDeadline] = []) {
        self.id = id
        self.title = title
        self.code = code
        self.instructor = instructor
        self.credits = credits
        self.currentGrade = currentGrade
        self.progress = progress
        self.colorHex = colorHex
        self.term = term
        self.location = location
        self.meetings = meetings
        self.syllabusWeights = syllabusWeights
        self.analytics = analytics
        self.instructorNotes = instructorNotes
        self.upcomingDeadlines = upcomingDeadlines
    }

    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    var gradePercentage: String {
        String(format: "%.1f%%", currentGrade)
    }

    var letterGrade: String {
        switch currentGrade {
        case 93...100: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 60..<67: return "D"
        default: return "F"
        }
    }
}

struct DashboardCourseMeeting: Identifiable, Hashable {
    let id = UUID()
    var days: [DayOfWeek]
    var startTime: String
    var endTime: String

    var formattedDays: String {
        days.map { $0.abbreviation }.joined(separator: "/")
    }

    var formattedTime: String {
        "\(startTime) - \(endTime)"
    }
}

enum DayOfWeek: String, CaseIterable, Hashable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"

    var abbreviation: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
}

struct SyllabusWeights: Hashable {
    var homework: Double = 0.25
    var projects: Double = 0.35
    var exams: Double = 0.40

    var homeworkProgress: Double = 0.85
    var projectsProgress: Double = 0.60
    var examsProgress: Double = 0.45

    var homeworkPercentage: String {
        String(format: "%.0f%%", homework * 100)
    }

    var projectsPercentage: String {
        String(format: "%.0f%%", projects * 100)
    }

    var examsPercentage: String {
        String(format: "%.0f%%", exams * 100)
    }
}

struct CourseAnalytics: Hashable {
    var assignmentsCompleted: Int = 12
    var assignmentsTotal: Int = 18
    var averageScore: Double = 87.5
    var attendanceRate: Double = 0.95
    var hoursStudied: Double = 24.5

    var completionRate: Double {
        guard assignmentsTotal > 0 else { return 0 }
        return Double(assignmentsCompleted) / Double(assignmentsTotal)
    }
}

struct CourseDeadline: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var dueDate: Date
    var type: DeadlineType

    enum DeadlineType: String, Hashable {
        case assignment = "Assignment"
        case exam = "Exam"
        case project = "Project"
        case quiz = "Quiz"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
}

// MARK: - Sample Data

extension CourseDashboard {
    static var dummyData: [CourseDashboard] {
        [
            CourseDashboard(
                title: "Calculus II",
                code: "MA 231",
                instructor: "Dr. Sarah Chen",
                credits: 4.0,
                currentGrade: 92.5,
                colorHex: "4A90E2",
                location: "Biltmore Hall 204",
                meetings: [
                    DashboardCourseMeeting(days: [.monday, .wednesday, .friday], startTime: "9:00 AM", endTime: "9:50 AM")
                ],
                syllabusWeights: SyllabusWeights(
                    homework: 0.25,
                    projects: 0.35,
                    exams: 0.40,
                    homeworkProgress: 0.90,
                    projectsProgress: 0.75,
                    examsProgress: 0.85
                ),
                analytics: CourseAnalytics(
                    assignmentsCompleted: 15,
                    assignmentsTotal: 18,
                    averageScore: 92.5,
                    attendanceRate: 0.98,
                    hoursStudied: 32.5
                ),
                instructorNotes: "Office hours: Tuesdays 2-4pm. Midterm exam on Oct 15.",
                upcomingDeadlines: [
                    CourseDeadline(title: "Problem Set 7", dueDate: Date().addingTimeInterval(86400 * 2), type: .assignment),
                    CourseDeadline(title: "Midterm Exam", dueDate: Date().addingTimeInterval(86400 * 7), type: .exam)
                ]
            ),
            CourseDashboard(
                title: "Data Structures",
                code: "CS 316",
                instructor: "Prof. Michael Torres",
                credits: 3.0,
                currentGrade: 88.3,
                colorHex: "50C878",
                location: "Engineering Building 301",
                meetings: [
                    DashboardCourseMeeting(days: [.tuesday, .thursday], startTime: "11:00 AM", endTime: "12:15 PM")
                ],
                syllabusWeights: SyllabusWeights(
                    homework: 0.30,
                    projects: 0.40,
                    exams: 0.30,
                    homeworkProgress: 0.85,
                    projectsProgress: 0.60,
                    examsProgress: 0.90
                ),
                analytics: CourseAnalytics(
                    assignmentsCompleted: 10,
                    assignmentsTotal: 14,
                    averageScore: 88.3,
                    attendanceRate: 0.92,
                    hoursStudied: 28.0
                ),
                instructorNotes: "Lab sessions on Fridays. Final project due Dec 10.",
                upcomingDeadlines: [
                    CourseDeadline(title: "Binary Trees Lab", dueDate: Date().addingTimeInterval(86400 * 3), type: .assignment),
                    CourseDeadline(title: "Project Milestone 2", dueDate: Date().addingTimeInterval(86400 * 10), type: .project)
                ]
            ),
            CourseDashboard(
                title: "Organic Chemistry",
                code: "CH 223",
                instructor: "Dr. Emily Rodriguez",
                credits: 4.0,
                currentGrade: 85.7,
                colorHex: "E94B3C",
                location: "Science Center 112",
                meetings: [
                    DashboardCourseMeeting(days: [.monday, .wednesday], startTime: "2:30 PM", endTime: "3:45 PM"),
                    DashboardCourseMeeting(days: [.friday], startTime: "1:00 PM", endTime: "3:50 PM")
                ],
                syllabusWeights: SyllabusWeights(
                    homework: 0.20,
                    projects: 0.30,
                    exams: 0.50,
                    homeworkProgress: 0.80,
                    projectsProgress: 0.70,
                    examsProgress: 0.75
                ),
                analytics: CourseAnalytics(
                    assignmentsCompleted: 12,
                    assignmentsTotal: 16,
                    averageScore: 85.7,
                    attendanceRate: 0.88,
                    hoursStudied: 35.0
                ),
                instructorNotes: "Lab reports due Mondays. Study group on Thursdays 5pm.",
                upcomingDeadlines: [
                    CourseDeadline(title: "Lab Report 5", dueDate: Date().addingTimeInterval(86400 * 1), type: .assignment),
                    CourseDeadline(title: "Quiz 3", dueDate: Date().addingTimeInterval(86400 * 5), type: .quiz)
                ]
            ),
            CourseDashboard(
                title: "Modern American History",
                code: "HI 340",
                instructor: "Prof. James Patterson",
                credits: 3.0,
                currentGrade: 91.2,
                colorHex: "F5A623",
                location: "Liberal Arts 220",
                meetings: [
                    DashboardCourseMeeting(days: [.tuesday, .thursday], startTime: "3:30 PM", endTime: "4:45 PM")
                ],
                syllabusWeights: SyllabusWeights(
                    homework: 0.30,
                    projects: 0.40,
                    exams: 0.30,
                    homeworkProgress: 0.95,
                    projectsProgress: 0.85,
                    examsProgress: 0.88
                ),
                analytics: CourseAnalytics(
                    assignmentsCompleted: 14,
                    assignmentsTotal: 15,
                    averageScore: 91.2,
                    attendanceRate: 1.0,
                    hoursStudied: 18.5
                ),
                instructorNotes: "Research paper due Nov 20. Citations required.",
                upcomingDeadlines: [
                    CourseDeadline(title: "Chapter 8 Essay", dueDate: Date().addingTimeInterval(86400 * 4), type: .assignment),
                    CourseDeadline(title: "Research Paper", dueDate: Date().addingTimeInterval(86400 * 21), type: .project)
                ]
            ),
            CourseDashboard(
                title: "Statistics & Probability",
                code: "ST 311",
                instructor: "Dr. Lisa Wang",
                credits: 3.0,
                currentGrade: 89.8,
                colorHex: "9B59B6",
                location: "Mathematics Hall 150",
                meetings: [
                    DashboardCourseMeeting(days: [.monday, .wednesday, .friday], startTime: "10:00 AM", endTime: "10:50 AM")
                ],
                syllabusWeights: SyllabusWeights(
                    homework: 0.25,
                    projects: 0.25,
                    exams: 0.50,
                    homeworkProgress: 0.88,
                    projectsProgress: 0.80,
                    examsProgress: 0.92
                ),
                analytics: CourseAnalytics(
                    assignmentsCompleted: 13,
                    assignmentsTotal: 16,
                    averageScore: 89.8,
                    attendanceRate: 0.96,
                    hoursStudied: 22.0
                ),
                instructorNotes: "R programming required. Office hours Mon/Wed 3-4pm.",
                upcomingDeadlines: [
                    CourseDeadline(title: "Problem Set 6", dueDate: Date().addingTimeInterval(86400 * 2), type: .assignment)
                ]
            )
        ]
    }
}
