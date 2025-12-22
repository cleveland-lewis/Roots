#if os(macOS)
import SwiftUI

private struct StorageCenterItem: Identifiable {
    let id: UUID
    let displayTitle: String
    let entityType: StorageEntityType
    let contextDescription: String?
    let primaryDate: Date
    let statusDescription: String?
    let searchText: String
    let editPayload: StorageEditPayload
    let deleteAction: () -> Void
}

private enum StorageEditPayload: Identifiable {
    case course(Course)
    case semester(Semester)
    case assignment(AppTask)
    case practiceTest(PracticeTest)
    case courseFile(CourseFile)
    case outlineNode(CourseOutlineNode)

    var id: UUID {
        switch self {
        case .course(let course): return course.id
        case .semester(let semester): return semester.id
        case .assignment(let task): return task.id
        case .practiceTest(let test): return test.id
        case .courseFile(let file): return file.id
        case .outlineNode(let node): return node.id
        }
    }
}

struct StorageSettingsView: View {
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @State private var practiceStore = PracticeTestStore()
    @StateObject private var index = StorageIndex()

    @State private var searchText = ""
    @State private var selectedTypes: Set<StorageEntityType> = []
    @State private var sortOption: StorageSortOption = .mostRecent
    @State private var activeEdit: StorageEditPayload?
    @State private var detailItem: StorageCenterItem?
    @State private var pendingDelete: StorageCenterItem?

    private var allItems: [StorageCenterItem] {
        var all: [StorageCenterItem] = []
        let semestersById = Dictionary(uniqueKeysWithValues: coursesStore.semesters.map { ($0.id, $0) })
        let coursesById = Dictionary(uniqueKeysWithValues: coursesStore.courses.map { ($0.id, $0) })

        for semester in coursesStore.semesters {
            all.append(
                StorageCenterItem(
                    id: semester.id,
                    displayTitle: semester.displayTitle,
                    entityType: semester.entityType,
                    contextDescription: semester.contextDescription,
                    primaryDate: semester.primaryDate,
                    statusDescription: semester.statusDescription,
                    searchText: semester.searchableText.lowercased(),
                    editPayload: .semester(semester),
                    deleteAction: { coursesStore.permanentlyDeleteSemester(semester.id) }
                )
            )
        }

        for course in coursesStore.courses {
            let semesterTitle = semestersById[course.semesterId]?.displayTitle
            all.append(
                StorageCenterItem(
                    id: course.id,
                    displayTitle: course.displayTitle,
                    entityType: course.entityType,
                    contextDescription: semesterTitle ?? course.contextDescription,
                    primaryDate: course.primaryDate,
                    statusDescription: course.statusDescription,
                    searchText: "\(course.searchableText) \(semesterTitle ?? "")".lowercased(),
                    editPayload: .course(course),
                    deleteAction: { coursesStore.deleteCourse(course) }
                )
            )
        }

        for task in assignmentsStore.tasks {
            let courseTitle = task.courseId.flatMap { coursesById[$0]?.title }
            all.append(
                StorageCenterItem(
                    id: task.id,
                    displayTitle: task.displayTitle,
                    entityType: task.entityType,
                    contextDescription: courseTitle ?? task.contextDescription,
                    primaryDate: task.primaryDate,
                    statusDescription: task.statusDescription,
                    searchText: "\(task.searchableText) \(courseTitle ?? "")".lowercased(),
                    editPayload: .assignment(task),
                    deleteAction: { assignmentsStore.removeTask(id: task.id) }
                )
            )
        }

        for test in practiceStore.tests {
            all.append(
                StorageCenterItem(
                    id: test.id,
                    displayTitle: test.displayTitle,
                    entityType: test.entityType,
                    contextDescription: test.contextDescription,
                    primaryDate: test.primaryDate,
                    statusDescription: test.statusDescription,
                    searchText: test.searchableText.lowercased(),
                    editPayload: .practiceTest(test),
                    deleteAction: { practiceStore.deleteTest(test.id) }
                )
            )
        }

        for node in coursesStore.outlineNodes {
            let courseTitle = coursesById[node.courseId]?.title
            all.append(
                StorageCenterItem(
                    id: node.id,
                    displayTitle: node.displayTitle,
                    entityType: node.entityType,
                    contextDescription: courseTitle ?? node.contextDescription,
                    primaryDate: node.primaryDate,
                    statusDescription: node.statusDescription,
                    searchText: "\(node.searchableText) \(courseTitle ?? "")".lowercased(),
                    editPayload: .outlineNode(node),
                    deleteAction: { coursesStore.deleteOutlineNode(node.id) }
                )
            )
        }

        for file in coursesStore.courseFiles {
            let courseTitle = coursesById[file.courseId]?.title
            all.append(
                StorageCenterItem(
                    id: file.id,
                    displayTitle: file.displayTitle,
                    entityType: file.entityType,
                    contextDescription: courseTitle ?? file.contextDescription,
                    primaryDate: file.primaryDate,
                    statusDescription: file.statusDescription,
                    searchText: "\(file.searchableText) \(courseTitle ?? "")".lowercased(),
                    editPayload: .courseFile(file),
                    deleteAction: { coursesStore.deleteFile(file.id) }
                )
            )
        }

        return all
    }

    private var items: [StorageCenterItem] {
        let sortedIds = index.search(query: searchText, types: selectedTypes, sort: sortOption)
        let map = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        return sortedIds.compactMap { map[$0] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Center")
                .font(.title2.weight(.bold))

            Text("Browse, edit, or delete any saved item. Search by title to find specific data quickly.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Picker("Sort", selection: $sortOption) {
                    ForEach(StorageSortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Menu("Filter") {
                    Button("All Types") {
                        selectedTypes.removeAll()
                    }
                    Divider()
                    ForEach(StorageEntityType.allCases) { entity in
                        Button {
                            toggleType(entity)
                        } label: {
                            Label(entity.displayTypeName, systemImage: selectedTypes.contains(entity) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }

                if !selectedTypes.isEmpty {
                    Text("\(selectedTypes.count) type(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            List(items) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.entityType.icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayTitle)
                            .font(.headline)
                        HStack(spacing: 8) {
                            Text(item.entityType.displayTypeName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let context = item.contextDescription, !context.isEmpty {
                                Text(context)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let status = item.statusDescription {
                                Text(status)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Text(item.primaryDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("View") {
                        detailItem = item
                    }
                    .buttonStyle(.bordered)

                    Button("Edit") {
                        activeEdit = item.editPayload
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Delete") {
                        pendingDelete = item
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.vertical, 6)
            }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search by title")
        }
        .padding(20)
        .onAppear {
            refreshIndex()
        }
        .onChange(of: coursesStore.courses.count) { _, _ in refreshIndex() }
        .onChange(of: coursesStore.semesters.count) { _, _ in refreshIndex() }
        .onChange(of: coursesStore.outlineNodes.count) { _, _ in refreshIndex() }
        .onChange(of: coursesStore.courseFiles.count) { _, _ in refreshIndex() }
        .onChange(of: assignmentsStore.tasks.count) { _, _ in refreshIndex() }
        .onChange(of: practiceStore.tests.count) { _, _ in refreshIndex() }
        .sheet(item: $activeEdit) { payload in
            StorageEditSheet(payload: payload, coursesStore: coursesStore, assignmentsStore: assignmentsStore, practiceStore: practiceStore)
        }
        .sheet(item: $detailItem) { item in
            StorageDetailSheet(
                item: item,
                onEdit: { activeEdit = item.editPayload },
                onDelete: { pendingDelete = item }
            )
        }
        .alert("Delete Item?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                pendingDelete?.deleteAction()
                pendingDelete = nil
            }
        } message: {
            Text("This will permanently remove the selected item.")
        }
    }

    private func toggleType(_ entity: StorageEntityType) {
        if selectedTypes.contains(entity) {
            selectedTypes.remove(entity)
        } else {
            selectedTypes.insert(entity)
        }
    }

    private func refreshIndex() {
        let entries = allItems.map {
            StorageIndexEntry(
                id: $0.id,
                title: $0.displayTitle,
                searchText: $0.searchText,
                entityType: $0.entityType,
                primaryDate: $0.primaryDate
            )
        }
        index.update(with: entries)
    }
}

private struct StorageDetailSheet: View {
    let item: StorageCenterItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.displayTitle)
                .font(.title2.weight(.bold))

            HStack(spacing: 8) {
                Label(item.entityType.displayTypeName, systemImage: item.entityType.icon)
                if let status = item.statusDescription {
                    Text(status)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

            if let context = item.contextDescription, !context.isEmpty {
                Text(context)
                    .foregroundStyle(.secondary)
            }

            Text("Last Updated: \(item.primaryDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Button("Delete", role: .destructive, action: onDelete)
                Spacer()
                Button("Edit", action: onEdit)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 240)
    }
}

private struct StorageEditSheet: View {
    let payload: StorageEditPayload
    let coursesStore: CoursesStore
    let assignmentsStore: AssignmentsStore
    let practiceStore: PracticeTestStore

    var body: some View {
        switch payload {
        case .course(let course):
            CourseEditSheet(course: course, coursesStore: coursesStore)
        case .semester(let semester):
            SemesterEditSheet(semester: semester, coursesStore: coursesStore)
        case .assignment(let task):
            AssignmentEditSheet(task: task, assignmentsStore: assignmentsStore)
        case .practiceTest(let test):
            PracticeTestEditSheet(test: test, practiceStore: practiceStore)
        case .courseFile(let file):
            CourseFileEditSheet(file: file, coursesStore: coursesStore)
        case .outlineNode(let node):
            OutlineNodeEditSheet(node: node, coursesStore: coursesStore)
        }
    }
}

private struct CourseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let course: Course
    let coursesStore: CoursesStore

    @State private var title: String
    @State private var code: String
    @State private var isArchived: Bool

    init(course: Course, coursesStore: CoursesStore) {
        self.course = course
        self.coursesStore = coursesStore
        _title = State(initialValue: course.title)
        _code = State(initialValue: course.code)
        _isArchived = State(initialValue: course.isArchived)
    }

    var body: some View {
        Form {
            TextField("Title", text: $title)
            TextField("Code", text: $code)
            Toggle("Archived", isOn: $isArchived)
        }
        .padding(24)
        .frame(minWidth: 420)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var updated = course
                    updated.title = title
                    updated.code = code
                    updated.isArchived = isArchived
                    coursesStore.updateCourse(updated)
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

private struct SemesterEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let semester: Semester
    let coursesStore: CoursesStore

    @State private var term: SemesterType
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var academicYear: String
    @State private var isArchived: Bool
    @State private var notes: String

    init(semester: Semester, coursesStore: CoursesStore) {
        self.semester = semester
        self.coursesStore = coursesStore
        _term = State(initialValue: semester.semesterTerm)
        _startDate = State(initialValue: semester.startDate)
        _endDate = State(initialValue: semester.endDate)
        _academicYear = State(initialValue: semester.academicYear ?? "")
        _isArchived = State(initialValue: semester.isArchived)
        _notes = State(initialValue: semester.notes ?? "")
    }

    var body: some View {
        Form {
            Picker("Term", selection: $term) {
                ForEach(SemesterType.allCases) { term in
                    Text(term.rawValue).tag(term)
                }
            }
            DatePicker("Start", selection: $startDate, displayedComponents: .date)
            DatePicker("End", selection: $endDate, displayedComponents: .date)
            TextField("Academic Year", text: $academicYear)
            Toggle("Archived", isOn: $isArchived)
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
        .padding(24)
        .frame(minWidth: 460)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var updated = semester
                    updated.semesterTerm = term
                    updated.startDate = startDate
                    updated.endDate = endDate
                    updated.academicYear = academicYear.isEmpty ? nil : academicYear
                    updated.isArchived = isArchived
                    updated.notes = notes.isEmpty ? nil : notes
                    coursesStore.updateSemester(updated)
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

private struct AssignmentEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let task: AppTask
    let assignmentsStore: AssignmentsStore

    @State private var title: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var estimatedMinutes: Int
    @State private var isCompleted: Bool

    init(task: AppTask, assignmentsStore: AssignmentsStore) {
        self.task = task
        self.assignmentsStore = assignmentsStore
        _title = State(initialValue: task.title)
        _dueDate = State(initialValue: task.due ?? Date())
        _hasDueDate = State(initialValue: task.due != nil)
        _estimatedMinutes = State(initialValue: task.estimatedMinutes)
        _isCompleted = State(initialValue: task.isCompleted)
    }

    var body: some View {
        Form {
            TextField("Title", text: $title)
            Toggle("Has Due Date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
            }
            Stepper("Estimated Minutes: \(estimatedMinutes)", value: $estimatedMinutes, in: 5...600, step: 5)
            Toggle("Completed", isOn: $isCompleted)
        }
        .padding(24)
        .frame(minWidth: 440)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var updated = task
                    updated.title = title
                    updated.due = hasDueDate ? dueDate : nil
                    updated.estimatedMinutes = estimatedMinutes
                    updated.isCompleted = isCompleted
                    assignmentsStore.updateTask(updated)
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

private struct PracticeTestEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let test: PracticeTest
    let practiceStore: PracticeTestStore

    @State private var courseName: String
    @State private var topics: String

    init(test: PracticeTest, practiceStore: PracticeTestStore) {
        self.test = test
        self.practiceStore = practiceStore
        _courseName = State(initialValue: test.courseName)
        _topics = State(initialValue: test.topics.joined(separator: ", "))
    }

    var body: some View {
        Form {
            TextField("Course Name", text: $courseName)
            TextField("Topics (comma separated)", text: $topics)
        }
        .padding(24)
        .frame(minWidth: 420)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var updated = test
                    updated.courseName = courseName
                    updated.topics = topics.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    practiceStore.updateTest(updated)
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

private struct CourseFileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let file: CourseFile
    let coursesStore: CoursesStore

    @State private var filename: String
    @State private var fileType: String
    @State private var isSyllabus: Bool
    @State private var isPracticeExam: Bool

    init(file: CourseFile, coursesStore: CoursesStore) {
        self.file = file
        self.coursesStore = coursesStore
        _filename = State(initialValue: file.filename)
        _fileType = State(initialValue: file.fileType)
        _isSyllabus = State(initialValue: file.isSyllabus)
        _isPracticeExam = State(initialValue: file.isPracticeExam)
    }

    var body: some View {
        Form {
            TextField("Filename", text: $filename)
            TextField("File Type", text: $fileType)
            Toggle("Syllabus", isOn: $isSyllabus)
            Toggle("Practice Exam", isOn: $isPracticeExam)
        }
        .padding(24)
        .frame(minWidth: 420)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var updated = file
                    updated.filename = filename
                    updated.fileType = fileType
                    updated.isSyllabus = isSyllabus
                    updated.isPracticeExam = isPracticeExam
                    coursesStore.updateFile(updated)
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

private struct OutlineNodeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let node: CourseOutlineNode
    let coursesStore: CoursesStore

    @State private var title: String

    init(node: CourseOutlineNode, coursesStore: CoursesStore) {
        self.node = node
        self.coursesStore = coursesStore
        _title = State(initialValue: node.title)
    }

    var body: some View {
        Form {
            TextField("Title", text: $title)
        }
        .padding(24)
        .frame(minWidth: 360)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var updated = node
                    updated.title = title
                    coursesStore.updateOutlineNode(updated)
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    StorageSettingsView()
        .environmentObject(CoursesStore())
        .environmentObject(AssignmentsStore.shared)
        .frame(width: 900, height: 650)
}
#endif
#endif
