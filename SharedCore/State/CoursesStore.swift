import Foundation
import SwiftUI
import Combine

@MainActor
final class CoursesStore: ObservableObject {
    static weak var shared: CoursesStore?
    // Publishes course deleted events
    fileprivate let courseDeleted = PassthroughSubject<UUID, Never>()

    @Published private(set) var semesters: [Semester] = []
    @Published private(set) var courses: [Course] = []
    @Published private(set) var outlineNodes: [CourseOutlineNode] = []
    @Published private(set) var courseFiles: [CourseFile] = []
    @Published private(set) var currentGPA: Double = 0

    @Published var currentSemesterId: UUID? {
        didSet {
            markCurrentSemester(currentSemesterId)
            persist()
        }
    }

    private let storageURL: URL
    private let cacheURL: URL

    init(storageURL: URL? = nil) {
        let fm = FileManager.default
        if let storageURL = storageURL {
            self.storageURL = storageURL
            // ensure containing directory exists
            try? fm.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } else {
            let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let folder = dir.appendingPathComponent("RootsCourses", isDirectory: true)
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            self.storageURL = folder.appendingPathComponent("courses.json")
        }
        let cacheFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("RootsCourses", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        self.cacheURL = cacheFolder.appendingPathComponent("courses_cache.json")

        loadCache()
        load()
        cleanupOldData()
        CoursesStore.shared = self
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    // MARK: - Public API

    var currentSemester: Semester? {
        guard let id = currentSemesterId else { return nil }
        return semesters.first(where: { $0.id == id && $0.deletedAt == nil })
    }

    var currentSemesterCourses: [Course] {
        guard let id = currentSemesterId else { return [] }
        return courses.filter { $0.semesterId == id }
    }

    func addSemester(_ semester: Semester) {
        semesters.append(semester)
        if semester.isCurrent {
            currentSemesterId = semester.id
        }
        persist()
    }

    func setCurrentSemester(_ semester: Semester) {
        currentSemesterId = semester.id
    }

    func toggleCurrentSemester(_ semester: Semester) {
        if semester.id == currentSemesterId {
            currentSemesterId = nil
        } else {
            setCurrentSemester(semester)
        }
    }

    func addCourse(title: String, code: String, to semester: Semester) {
        let newCourse = Course(title: title, code: code, semesterId: semester.id, isArchived: false)
        courses.append(newCourse)
        LOG_COURSES(.info, "CourseAdded", "Course added: \(title)", metadata: ["courseId": newCourse.id.uuidString, "semesterId": semester.id.uuidString])
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func resetAll() {
        semesters.removeAll()
        courses.removeAll()
        currentSemesterId = nil
        try? FileManager.default.removeItem(at: storageURL)
        try? FileManager.default.removeItem(at: cacheURL)
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func addCourse(_ course: Course) {
        courses.append(course)
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func updateCourse(_ course: Course) {
        guard let idx = courses.firstIndex(where: { $0.id == course.id }) else { return }
        courses[idx] = course
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func toggleArchiveCourse(_ course: Course) {
        guard let idx = courses.firstIndex(where: { $0.id == course.id }) else { return }
        courses[idx].isArchived.toggle()
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func deleteCourse(_ course: Course) {
        courses.removeAll { $0.id == course.id }
        // Publish course deleted event via Combine for subscribers
        courseDeleted.send(course.id)
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func courses(in semester: Semester) -> [Course] {
        courses.filter { $0.semesterId == semester.id }
    }

    var activeCourses: [Course] {
        courses.filter { !$0.isArchived }
    }

    var archivedCourses: [Course] {
        courses.filter { $0.isArchived }
    }

    // MARK: - Semester Management

    func updateSemester(_ semester: Semester) {
        guard let idx = semesters.firstIndex(where: { $0.id == semester.id }) else { return }
        semesters[idx] = semester
        persist()
    }

    func toggleArchiveSemester(_ semester: Semester) {
        guard let idx = semesters.firstIndex(where: { $0.id == semester.id }) else { return }
        semesters[idx].isArchived.toggle()
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func deleteSemester(_ id: UUID) {
        guard let idx = semesters.firstIndex(where: { $0.id == id }) else { return }
        semesters[idx].deletedAt = Date()
        semesters[idx].isCurrent = false
        if currentSemesterId == id {
            currentSemesterId = nil
        }
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func recoverSemester(_ id: UUID) {
        guard let idx = semesters.firstIndex(where: { $0.id == id }) else { return }
        semesters[idx].deletedAt = nil
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func permanentlyDeleteSemester(_ id: UUID) {
        semesters.removeAll { $0.id == id }
        courses.removeAll { $0.semesterId == id }
        if currentSemesterId == id {
            currentSemesterId = nil
        }
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    var activeSemesters: [Semester] {
        semesters.filter { !$0.isArchived && $0.deletedAt == nil }.sorted { $0.startDate > $1.startDate }
    }

    var archivedSemesters: [Semester] {
        semesters.filter { $0.isArchived && $0.deletedAt == nil }.sorted { $0.startDate > $1.startDate }
    }

    var recentlyDeletedSemesters: [Semester] {
        semesters.compactMap { $0.deletedAt == nil ? nil : $0 }.sorted { ($0.deletedAt ?? Date.distantPast) > ($1.deletedAt ?? Date.distantPast) }
    }

    var futureSemesters: [Semester] {
        let now = Date()
        return semesters.filter { !$0.isArchived && $0.deletedAt == nil && $0.startDate > now }.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Persistence

    private struct PersistedData: Codable {
        var semesters: [Semester]
        var courses: [Course]
        var outlineNodes: [CourseOutlineNode]
        var courseFiles: [CourseFile]
        var currentSemesterId: UUID?
        
        // Custom decoding to handle backward compatibility
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            semesters = try container.decode([Semester].self, forKey: .semesters)
            courses = try container.decode([Course].self, forKey: .courses)
            // Provide default empty array if outlineNodes is missing (backward compatibility)
            outlineNodes = try container.decodeIfPresent([CourseOutlineNode].self, forKey: .outlineNodes) ?? []
            courseFiles = try container.decodeIfPresent([CourseFile].self, forKey: .courseFiles) ?? []
            currentSemesterId = try container.decodeIfPresent(UUID.self, forKey: .currentSemesterId)
        }
        
        // Memberwise init for encoding
        init(semesters: [Semester], courses: [Course], outlineNodes: [CourseOutlineNode], courseFiles: [CourseFile], currentSemesterId: UUID?) {
            self.semesters = semesters
            self.courses = courses
            self.outlineNodes = outlineNodes
            self.courseFiles = courseFiles
            self.currentSemesterId = currentSemesterId
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            LOG_PERSISTENCE(.info, "CoursesLoad", "No persisted courses data found")
            return
        }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode(PersistedData.self, from: data)
            self.semesters = decoded.semesters
            self.courses = decoded.courses
            self.outlineNodes = decoded.outlineNodes
            self.courseFiles = decoded.courseFiles
            self.currentSemesterId = decoded.currentSemesterId
            LOG_PERSISTENCE(.info, "CoursesLoad", "Loaded courses data", metadata: ["semesters": "\(semesters.count)", "courses": "\(courses.count)"])
        } catch {
            LOG_PERSISTENCE(.error, "CoursesLoad", "Failed to decode courses data: \(error.localizedDescription)")
        }
    }

    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            LOG_PERSISTENCE(.debug, "CoursesCache", "No cache file found")
            return
        }
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoded = try JSONDecoder().decode(PersistedData.self, from: data)
            self.semesters = decoded.semesters
            self.courses = decoded.courses
            self.outlineNodes = decoded.outlineNodes
            self.courseFiles = decoded.courseFiles
            self.currentSemesterId = decoded.currentSemesterId
            LOG_PERSISTENCE(.debug, "CoursesCache", "Loaded cache", metadata: ["semesters": "\(semesters.count)", "courses": "\(courses.count)"])
        } catch {
            LOG_PERSISTENCE(.error, "CoursesCache", "Failed to load cache: \(error.localizedDescription)")
        }
    }

    private func persist() {
        let snapshot = PersistedData(
            semesters: semesters,
            courses: courses,
            outlineNodes: outlineNodes,
            courseFiles: courseFiles,
            currentSemesterId: currentSemesterId
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
            try data.write(to: cacheURL, options: [.atomic, .completeFileProtection])
            LOG_PERSISTENCE(.debug, "CoursesSave", "Persisted courses data", metadata: ["semesters": "\(semesters.count)", "courses": "\(courses.count)", "size": "\(data.count)"])
        } catch {
            LOG_PERSISTENCE(.error, "CoursesSave", "Failed to persist courses data: \(error.localizedDescription)")
        }
    }

    // MARK: - GPA recalculation

    @MainActor
    func recalcGPA(tasks: [AppTask]) {
        let gradedCourses = courses.filter { !$0.isArchived }
        currentGPA = GradeCalculator.calculateGPA(courses: gradedCourses, tasks: tasks)
    }

    func cleanupOldData() {
        let threshold = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let expiredIds = semesters.compactMap { semester -> UUID? in
            guard let deletedAt = semester.deletedAt, deletedAt < threshold else { return nil }
            return semester.id
        }

        guard !expiredIds.isEmpty else { return }

        semesters.removeAll { expiredIds.contains($0.id) }
        courses.removeAll { expiredIds.contains($0.semesterId) }
        if let currentId = currentSemesterId, expiredIds.contains(currentId) {
            currentSemesterId = nil
        }

        persist()
    }

    private func markCurrentSemester(_ id: UUID?) {
        semesters = semesters.map { semester in
            var s = semester
            let isTarget = semester.id == id
            s.isCurrent = isTarget && semester.deletedAt == nil
            return s
        }
    }
}

// MARK: - Course Outline Management

extension CoursesStore {
    /// Fetch all outline nodes for a specific course
    func outlineNodes(for courseId: UUID) -> [CourseOutlineNode] {
        outlineNodes.filter { $0.courseId == courseId }
    }
    
    /// Fetch root nodes (no parent) for a course, sorted by sortIndex
    func rootOutlineNodes(for courseId: UUID) -> [CourseOutlineNode] {
        outlineNodes
            .filter { $0.courseId == courseId && $0.parentId == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }
    
    /// Fetch children of a specific parent node, sorted by sortIndex
    func childOutlineNodes(for parentId: UUID) -> [CourseOutlineNode] {
        outlineNodes
            .filter { $0.parentId == parentId }
            .sorted { $0.sortIndex < $1.sortIndex }
    }
    
    /// Add a new outline node
    func addOutlineNode(_ node: CourseOutlineNode) {
        var newNode = node
        newNode.createdAt = Date()
        newNode.updatedAt = Date()
        outlineNodes.append(newNode)
        persist()
    }
    
    /// Update an existing outline node
    func updateOutlineNode(_ node: CourseOutlineNode) {
        guard let index = outlineNodes.firstIndex(where: { $0.id == node.id }) else { return }
        var updatedNode = node
        updatedNode.updatedAt = Date()
        outlineNodes[index] = updatedNode
        persist()
    }
    
    /// Delete an outline node (single node only, orphans children)
    func deleteOutlineNode(_ id: UUID) {
        outlineNodes.removeAll { $0.id == id }
        persist()
    }
    
    /// Delete a node and all its descendants (cascade delete)
    func deleteSubtree(_ nodeId: UUID) {
        // Get all descendants to delete
        let descendantIds = getAllDescendants(of: nodeId)
        
        // Delete the node itself plus all descendants
        var idsToDelete = descendantIds
        idsToDelete.insert(nodeId)
        
        outlineNodes.removeAll { idsToDelete.contains($0.id) }
        persist()
    }
    
    /// Count how many nodes would be deleted (for UI confirmation)
    func countSubtreeNodes(_ nodeId: UUID) -> Int {
        let descendants = getAllDescendants(of: nodeId)
        return descendants.count + 1  // +1 for the node itself
    }
    
    // MARK: - Tree Validation
    
    /// Check if a node can be moved to a new parent without creating a cycle
    func canMoveNode(_ nodeId: UUID, to newParentId: UUID?) -> Bool {
        // Moving to root is always safe
        guard let newParentId = newParentId else { return true }
        
        // Cannot move to itself
        if nodeId == newParentId { return false }
        
        // Cannot move to any of its descendants (would create cycle)
        return !isDescendant(nodeId, of: newParentId)
    }
    
    /// Check if potentialDescendant is in the subtree of ancestorId
    private func isDescendant(_ potentialDescendant: UUID, of ancestorId: UUID) -> Bool {
        // Get all descendants of ancestorId
        let descendants = getAllDescendants(of: ancestorId)
        return descendants.contains(potentialDescendant)
    }
    
    /// Get all descendants (children, grandchildren, etc.) of a node
    private func getAllDescendants(of nodeId: UUID) -> Set<UUID> {
        var descendants = Set<UUID>()
        var toProcess = [nodeId]
        
        while !toProcess.isEmpty {
            let currentId = toProcess.removeFirst()
            let children = outlineNodes.filter { $0.parentId == currentId }
            
            for child in children {
                descendants.insert(child.id)
                toProcess.append(child.id)
            }
        }
        
        return descendants
    }
    
    /// Safely move a node to a new parent (with validation)
    func moveNodeToParent(_ nodeId: UUID, newParentId: UUID?) -> Bool {
        guard canMoveNode(nodeId, to: newParentId) else { return false }
        
        guard let index = outlineNodes.firstIndex(where: { $0.id == nodeId }) else { return false }
        
        let oldParentId = outlineNodes[index].parentId
        
        // Remove from old siblings and reindex
        if oldParentId != newParentId {
            reindexSiblings(parentId: oldParentId)
        }
        
        var node = outlineNodes[index]
        node.parentId = newParentId
        
        // Place at end of new siblings
        let siblings = outlineNodes.filter { $0.parentId == newParentId && $0.id != nodeId }
        node.sortIndex = siblings.isEmpty ? 0 : (siblings.map { $0.sortIndex }.max() ?? 0) + 1
        node.updatedAt = Date()
        
        outlineNodes[index] = node
        persist()
        
        return true
    }
    
    // MARK: - SortIndex Management
    
    /// Reindex all siblings to have sequential sortIndex (0, 1, 2, ...)
    func reindexSiblings(parentId: UUID?) {
        let siblings = outlineNodes
            .filter { $0.parentId == parentId }
            .sorted { $0.sortIndex < $1.sortIndex }
        
        for (index, sibling) in siblings.enumerated() {
            if let nodeIndex = outlineNodes.firstIndex(where: { $0.id == sibling.id }) {
                outlineNodes[nodeIndex].sortIndex = index
            }
        }
        persist()
    }
    
    /// Move a node to a specific position within its siblings
    func moveNode(_ nodeId: UUID, toPosition position: Int) {
        guard let nodeIndex = outlineNodes.firstIndex(where: { $0.id == nodeId }) else { return }
        
        let node = outlineNodes[nodeIndex]
        let siblings = outlineNodes
            .filter { $0.parentId == node.parentId && $0.id != nodeId }
            .sorted { $0.sortIndex < $1.sortIndex }
        
        // Clamp position
        let targetPosition = max(0, min(position, siblings.count))
        
        // Rebuild sibling list with node at new position
        var newSiblings = siblings
        newSiblings.insert(node, at: targetPosition)
        
        // Update sortIndex for all affected nodes
        for (index, sibling) in newSiblings.enumerated() {
            if let idx = outlineNodes.firstIndex(where: { $0.id == sibling.id }) {
                outlineNodes[idx].sortIndex = index
                outlineNodes[idx].updatedAt = Date()
            }
        }
        
        persist()
    }
    
    /// Get next available sortIndex for a parent
    func nextSortIndex(for parentId: UUID?) -> Int {
        let siblings = outlineNodes.filter { $0.parentId == parentId }
        return siblings.isEmpty ? 0 : (siblings.map { $0.sortIndex }.max() ?? 0) + 1
    }
}

// MARK: - Course Files Management

extension CoursesStore {
    /// Get all files for a course
    func courseFiles(for courseId: UUID) -> [CourseFile] {
        courseFiles.filter { $0.courseId == courseId }
    }
    
    /// Get files attached to a specific node
    func nodeFiles(for nodeId: UUID) -> [CourseFile] {
        courseFiles.filter { $0.nodeId == nodeId }
    }
    
    /// Get files attached to course root (no node)
    func rootFiles(for courseId: UUID) -> [CourseFile] {
        courseFiles.filter { $0.courseId == courseId && $0.nodeId == nil }
    }
    
    /// Get syllabus for a course (should be only one)
    func syllabus(for courseId: UUID) -> CourseFile? {
        courseFiles.first { $0.courseId == courseId && $0.isSyllabus }
    }
    
    /// Get practice exams for a course
    func practiceExams(for courseId: UUID) -> [CourseFile] {
        courseFiles.filter { $0.courseId == courseId && $0.isPracticeExam }
    }
    
    /// Add a new file
    func addFile(_ file: CourseFile) {
        var newFile = file
        newFile.createdAt = Date()
        newFile.updatedAt = Date()
        
        // Enforce single syllabus rule
        if newFile.isSyllabus {
            // Unmark any existing syllabus
            for index in courseFiles.indices {
                if courseFiles[index].courseId == newFile.courseId && courseFiles[index].isSyllabus {
                    courseFiles[index].isSyllabus = false
                    courseFiles[index].updatedAt = Date()
                }
            }
        }
        
        courseFiles.append(newFile)
        persist()
    }
    
    /// Update a file
    func updateFile(_ file: CourseFile) {
        guard let index = courseFiles.firstIndex(where: { $0.id == file.id }) else { return }
        
        var updatedFile = file
        updatedFile.updatedAt = Date()
        
        // Enforce single syllabus rule
        if updatedFile.isSyllabus && !courseFiles[index].isSyllabus {
            // Unmark any existing syllabus
            for idx in courseFiles.indices where idx != index {
                if courseFiles[idx].courseId == updatedFile.courseId && courseFiles[idx].isSyllabus {
                    courseFiles[idx].isSyllabus = false
                    courseFiles[idx].updatedAt = Date()
                }
            }
        }
        
        courseFiles[index] = updatedFile
        persist()
    }
    
    /// Delete a file
    func deleteFile(_ id: UUID) {
        courseFiles.removeAll { $0.id == id }
        persist()
    }
    
    /// Attach file to a node
    func attachFile(_ fileId: UUID, to nodeId: UUID?) {
        guard let index = courseFiles.firstIndex(where: { $0.id == fileId }) else { return }
        courseFiles[index].nodeId = nodeId
        courseFiles[index].updatedAt = Date()
        persist()
    }
    
    /// Toggle syllabus designation
    func toggleSyllabus(_ fileId: UUID) {
        guard let index = courseFiles.firstIndex(where: { $0.id == fileId }) else { return }
        let newValue = !courseFiles[index].isSyllabus
        
        if newValue {
            // Unmark any existing syllabus
            let courseId = courseFiles[index].courseId
            for idx in courseFiles.indices where idx != index {
                if courseFiles[idx].courseId == courseId && courseFiles[idx].isSyllabus {
                    courseFiles[idx].isSyllabus = false
                    courseFiles[idx].updatedAt = Date()
                }
            }
            
            // Trigger parsing when marking as syllabus
            Task { @MainActor in
                let parsingStore = SyllabusParsingStore.shared
                let job = parsingStore.createJob(courseId: courseId, fileId: fileId)
                
                // Get file URL from localURL if available
                let fileURL: URL? = if let urlString = courseFiles[index].localURL {
                    URL(fileURLWithPath: urlString)
                } else {
                    nil
                }
                
                parsingStore.startParsing(job: job, fileURL: fileURL)
            }
        }
        
        courseFiles[index].isSyllabus = newValue
        courseFiles[index].updatedAt = Date()
        persist()
    }
    
    /// Toggle practice exam designation
    func togglePracticeExam(_ fileId: UUID) {
        guard let index = courseFiles.firstIndex(where: { $0.id == fileId }) else { return }
        courseFiles[index].isPracticeExam.toggle()
        courseFiles[index].updatedAt = Date()
        persist()
    }
}

// Combine publisher replaces brittle NotificationCenter bridges
extension CoursesStore {
    // Emits courseId when a course is removed
    static var courseDeletedPublisher: AnyPublisher<UUID, Never> {
        guard let s = CoursesStore.shared else { return Empty<UUID, Never>().eraseToAnyPublisher() }
        return s.courseDeleted.eraseToAnyPublisher()
    }
}
