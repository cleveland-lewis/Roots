import SwiftUI

struct CourseDetailView: View {
    let course: Course
    let semester: Semester

    @EnvironmentObject private var assignmentsStore: AssignmentsStore

    private var courseAssignments: [AppTask] {
        assignmentsStore.tasks.filter { $0.courseId == course.id && $0.type != .examPrep }
    }

    private var courseExams: [AppTask] {
        assignmentsStore.tasks.filter { $0.courseId == course.id && $0.type == .examPrep }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                CardGrid {
                    assignmentsCard
                    examsCard
                    documentsCard
                    practiceQuizzesCard
                }
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(course.title)
                .font(.largeTitle.bold())

            Text("\\(course.code) · \\(semester.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var assignmentsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Assignments")
                    .font(.headline)

                if courseAssignments.isEmpty {
                    Text("No assignments linked to this course yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(courseAssignments, id: \.id) { assignment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assignment.title)
                                    .font(.subheadline)
                                if let due = assignment.due {
                                    Text(due, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var examsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Exams")
                    .font(.headline)

                if courseExams.isEmpty {
                    Text("No exams linked to this course yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(courseExams, id: \.id) { exam in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exam.title)
                                    .font(.subheadline)
                                if let due = exam.due {
                                    Text(due, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var documentsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Documents")
                    .font(.headline)
                Text("No documents added.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var practiceQuizzesCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Practice Quizzes")
                    .font(.headline)
                Text("No practice quizzes yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
