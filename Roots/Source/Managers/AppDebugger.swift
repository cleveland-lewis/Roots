import Foundation
import EventKit

struct DiagnosticIssue: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let details: String
    let prescription: String
}

struct DiagnosticReport {
    let issues: [DiagnosticIssue]

    var formattedSummary: String {
        issues.map { "\($0.title): \($0.details) – \($0.prescription)" }.joined(separator: "\n")
    }
}

@MainActor
final class AppDebugger {
    static let shared = AppDebugger()

    private let defaultDataManager: CoursesStore
    private let defaultCalendarManager: CalendarManager
    private let defaultAssignmentsStore: AssignmentsStore
    private let defaultDocumentsDirectory: URL
    private let defaultTasksFileURL: URL
    private let defaultCoursesFileURL: URL
    private let defaultAuthProvider: () -> (EKAuthorizationStatus, EKAuthorizationStatus)

    init(
        dataManager: CoursesStore? = nil,
        calendarManager: CalendarManager? = nil,
        assignmentsStore: AssignmentsStore? = nil,
        documentsDirectory: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
        tasksFileURL: URL? = nil,
        coursesFileURL: URL? = nil,
        authorizationStatusProvider: @escaping () -> (EKAuthorizationStatus, EKAuthorizationStatus) = {
            (EKEventStore.authorizationStatus(for: .event), EKEventStore.authorizationStatus(for: .reminder))
        }
    ) {
        // Initialize defaults on the main actor to avoid calling actor-isolated initializers at global scope
        let dm = dataManager ?? CoursesStore()
        let cm = calendarManager ?? CalendarManager.shared
        let asg = assignmentsStore ?? AssignmentsStore.shared
        let docsDir = documentsDirectory ?? FileManager.default.temporaryDirectory

        self.defaultDataManager = dm
        self.defaultCalendarManager = cm
        self.defaultAssignmentsStore = asg
        self.defaultDocumentsDirectory = docsDir
        self.defaultTasksFileURL = tasksFileURL ?? docsDir.appendingPathComponent("tasks.json")
        self.defaultCoursesFileURL = coursesFileURL ?? docsDir.appendingPathComponent("courses.json")
        self.defaultAuthProvider = authorizationStatusProvider
    }

    func runFullDiagnostic(
        dataManager: CoursesStore? = nil,
        calendarManager: CalendarManager? = nil,
        assignmentsStore: AssignmentsStore? = nil,
        documentsDirectory: URL? = nil,
        tasksFileURL: URL? = nil,
        coursesFileURL: URL? = nil,
        authorizationStatusProvider: (() -> (EKAuthorizationStatus, EKAuthorizationStatus))? = nil
    ) -> DiagnosticReport {
        let dm = dataManager ?? defaultDataManager
        let cm = calendarManager ?? defaultCalendarManager
        let asg = assignmentsStore ?? defaultAssignmentsStore
        let docsDir = documentsDirectory ?? defaultDocumentsDirectory
        let tasksURL = tasksFileURL ?? defaultTasksFileURL
        let coursesURL = coursesFileURL ?? defaultCoursesFileURL
        let authProvider = authorizationStatusProvider ?? defaultAuthProvider

        var issues: [DiagnosticIssue] = []

        if let orphanIssue = checkOrphanTasks(assignmentsStore: asg, dataManager: dm) {
            issues.append(orphanIssue)
        }

        if let permissionIssue = checkPermissionState(calendarManager: cm, authProvider: authProvider) {
            issues.append(permissionIssue)
        }

        if let fsIssue = checkFileSystemIntegrity(documentsDirectory: docsDir, tasksURL: tasksURL, coursesURL: coursesURL) {
            issues.append(fsIssue)
        }

        if let dateIssue = checkSemesterDates(dataManager: dm) {
            issues.append(dateIssue)
        }

        return DiagnosticReport(issues: issues)
    }

    private func checkOrphanTasks(assignmentsStore: AssignmentsStore, dataManager: CoursesStore) -> DiagnosticIssue? {
        let coursesById = Dictionary(uniqueKeysWithValues: dataManager.courses.map { ($0.id, $0) })
        let semesterIds = Set(dataManager.semesters.map { $0.id })

        let orphanTasks = assignmentsStore.tasks.filter { task in
            guard let courseId = task.courseId else { return false }
            guard let course = coursesById[courseId] else { return true }
            return !semesterIds.contains(course.semesterId)
        }

        guard !orphanTasks.isEmpty else { return nil }
        let ids = orphanTasks.map { $0.id.uuidString }.joined(separator: ", ")
        return DiagnosticIssue(
            title: "Orphan Tasks",
            details: "Found tasks linked to missing Course/Semester",
            prescription: "Found orphan tasks. Fix: Delete tasks [\(ids)] or restore missing Course."
        )
    }

    private func checkPermissionState(
        calendarManager: CalendarManager,
        authProvider: () -> (EKAuthorizationStatus, EKAuthorizationStatus)
    ) -> DiagnosticIssue? {
        let (eventStatus, reminderStatus) = authProvider()
        let actualAuthorized = (eventStatus == .fullAccess || eventStatus == .writeOnly) ||
        (reminderStatus == .fullAccess || reminderStatus == .writeOnly)

        guard actualAuthorized == calendarManager.isAuthorized else {
            return DiagnosticIssue(
                title: "Permission De-sync",
                details: "App authorization \(calendarManager.isAuthorized) != OS status \(actualAuthorized)",
                prescription: "Permission De-sync. Fix: Force call checkPermissionsOnStartup()."
            )
        }
        return nil
    }

    private func checkFileSystemIntegrity(documentsDirectory: URL, tasksURL: URL, coursesURL: URL) -> DiagnosticIssue? {
        let fm = FileManager.default
        let probeURL = documentsDirectory.appendingPathComponent("write_test_\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
            try "ping".data(using: .utf8)?.write(to: probeURL)
            try fm.removeItem(at: probeURL)
        } catch {
            return DiagnosticIssue(
                title: "File System Error",
                details: "Documents directory not writable: \(error.localizedDescription)",
                prescription: "Data file corrupt. Fix: Nuke local file or restore from backup."
            )
        }

        let pathsToCheck: [URL] = [tasksURL, coursesURL]
        let failedFiles = pathsToCheck.compactMap { url -> String? in
            guard fm.fileExists(atPath: url.path) else { return url.lastPathComponent }
            do {
                let data = try Data(contentsOf: url)
                _ = try JSONSerialization.jsonObject(with: data, options: [])
                return nil
            } catch {
                let fileName = url.lastPathComponent
                let errorMsg = error.localizedDescription
                return "\(fileName) (\(errorMsg))"
            }
        }

        guard failedFiles.isEmpty else {
            return DiagnosticIssue(
                title: "Data File Corrupt",
                details: "Failed JSON validation for: \(failedFiles.joined(separator: ", "))",
                prescription: "Data file corrupt. Fix: Nuke local file or restore from backup."
            )
        }

        return nil
    }

    private func checkSemesterDates(dataManager: CoursesStore) -> DiagnosticIssue? {
        let paradoxes = dataManager.semesters.filter { $0.endDate < $0.startDate }
        guard !paradoxes.isEmpty else { return nil }
        let names = paradoxes.map { $0.name }.joined(separator: ", ")
        return DiagnosticIssue(
            title: "Time Paradox",
            details: "Semesters with endDate before startDate: \(names)",
            prescription: "Time Paradox detected in Semester [\(names)]. Fix: Swap start/end dates."
        )
    }
}
