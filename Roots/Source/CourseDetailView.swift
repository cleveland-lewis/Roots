import SwiftUI
import UniformTypeIdentifiers

struct CourseDetailView: View {
    let course: Course
    let semester: Semester

    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var dataManager: CoursesStore
    @State private var draftCourse: Course
    @State private var showingSyllabusImporter = false

    private var courseAssignments: [AppTask] {
        assignmentsStore.tasks.filter { $0.courseId == draftCourse.id && $0.type != .exam }
    }

    private var courseExams: [AppTask] {
        assignmentsStore.tasks.filter { $0.courseId == draftCourse.id && $0.type == .exam }
    }

    private var upcomingCourseTasks: [AppTask] {
        assignmentsStore.tasks
            .filter { $0.courseId == draftCourse.id && !$0.isCompleted }
            .sorted { ($0.due ?? Date.distantFuture) < ($1.due ?? Date.distantFuture) }
    }

    init(course: Course, semester: Semester) {
        self.course = course
        self.semester = semester
        _draftCourse = State(initialValue: course)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                CardGrid {
                    assignmentsCard
                    examsCard
                    materialsCard
                    upcomingDeadlinesCard
                    modulesCard
                    practiceQuizzesCard
                }
            }
            .padding(DesignSystem.Layout.padding.window) // unified token (no-op but ensures presence)
        }
        .onChange(of: draftCourse.attachments) { _, _ in
            dataManager.updateCourse(draftCourse)
        }
        .fileImporter(
            isPresented: $showingSyllabusImporter,
            allowedContentTypes: [.pdf, .plainText, .content, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importSyllabus(url: url)
            case .failure:
                break
            }
        }
    }

    private var upcomingDeadlinesCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                Text("Upcoming Deadlines")
                    .font(DesignSystem.Typography.subHeader)
                if upcomingCourseTasks.isEmpty {
                    Text("No upcoming deadlines.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(upcomingCourseTasks.prefix(5), id: \.id) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.subheadline)
                                if let due = task.due {
                                    Text(due, style: .date)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if task.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(draftCourse.title)
                .font(.largeTitle.bold())

            Text("\(draftCourse.code) · \(semester.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var assignmentsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                Text("Assignments")
                    .font(DesignSystem.Typography.subHeader)

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
                                        .font(DesignSystem.Typography.caption)
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
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                Text("Exams")
                    .font(DesignSystem.Typography.subHeader)

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
                                        .font(DesignSystem.Typography.caption)
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

    private var materialsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                HStack {
                    Text("Course Materials & Syllabus")
                        .font(DesignSystem.Typography.subHeader)
                    Spacer()
                    Button {
                        showingSyllabusImporter = true
                    } label: {
                        Label("Import Syllabus", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }

                AttachmentListView(attachments: $draftCourse.attachments, courseId: draftCourse.id)
            }
        }
    }

    private var modulesCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                Text("Modules")
                    .font(DesignSystem.Typography.subHeader)

                if groupedAttachments.isEmpty {
                    Text("No module files yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groupedAttachments.keys.sorted(), id: \.self) { moduleNum in
                        DisclosureGroup("Module \(moduleNum)") {
                            ForEach(groupedAttachments[moduleNum] ?? []) { file in
                                HStack(spacing: 10) {
                                    Image(systemName: file.tag.icon)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.name)
                                        Text(file.taskType.rawValue)
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var practiceQuizzesCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                Text("Practice Quizzes")
                    .font(DesignSystem.Typography.subHeader)
                Text("No practice quizzes yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func importSyllabus(url: URL) {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = docs.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        do {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: url, to: destURL)
            let attachment = Attachment(name: url.lastPathComponent, localURL: destURL, tag: .syllabus)
            draftCourse.attachments.append(attachment)
        } catch {
            print("Failed to import syllabus: \(error)")
        }
    }

    private var groupedAttachments: [Int: [Attachment]] {
        let withModule = draftCourse.attachments.compactMap { attachment -> (Int, Attachment)? in
            guard let module = attachment.moduleNumber else { return nil }
            return (module, attachment)
        }
        return Dictionary(grouping: withModule, by: { $0.0 }).mapValues { $0.map { $0.1 } }
    }
}
