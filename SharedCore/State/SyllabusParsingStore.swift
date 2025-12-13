import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
final class SyllabusParsingStore: ObservableObject {
    static let shared = SyllabusParsingStore()
    
    @Published private(set) var parsingJobs: [SyllabusParsingJob] = []
    @Published private(set) var parsedAssignments: [ParsedAssignment] = []
    
    private let storageURL: URL
    
    init(storageURL: URL? = nil) {
        if let storageURL = storageURL {
            self.storageURL = storageURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("Roots", isDirectory: true)
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            self.storageURL = appDir.appendingPathComponent("syllabus_parsing.json")
        }
        load()
    }
    
    // MARK: - Job Management
    
    func createJob(courseId: UUID, fileId: UUID) -> SyllabusParsingJob {
        let job = SyllabusParsingJob(courseId: courseId, fileId: fileId)
        parsingJobs.append(job)
        persist()
        return job
    }
    
    func updateJobStatus(_ jobId: UUID, status: ParsingJobStatus, errorMessage: String? = nil) {
        guard let index = parsingJobs.firstIndex(where: { $0.id == jobId }) else { return }
        
        parsingJobs[index].status = status
        parsingJobs[index].errorMessage = errorMessage
        
        switch status {
        case .running:
            parsingJobs[index].startedAt = Date()
        case .succeeded, .failed:
            parsingJobs[index].completedAt = Date()
        default:
            break
        }
        
        persist()
    }
    
    func job(for fileId: UUID) -> SyllabusParsingJob? {
        parsingJobs.first { $0.fileId == fileId }
    }
    
    // MARK: - Parsed Assignments
    
    func addParsedAssignment(_ assignment: ParsedAssignment) {
        parsedAssignments.append(assignment)
        persist()
    }
    
    func parsedAssignmentsByCourse(_ courseId: UUID) -> [ParsedAssignment] {
        parsedAssignments.filter { $0.courseId == courseId && !$0.isImported }
    }
    
    func parsedAssignmentsByJob(_ jobId: UUID) -> [ParsedAssignment] {
        parsedAssignments.filter { $0.jobId == jobId }
    }
    
    func markAsImported(_ assignmentId: UUID, taskId: UUID) {
        guard let index = parsedAssignments.firstIndex(where: { $0.id == assignmentId }) else { return }
        parsedAssignments[index].isImported = true
        parsedAssignments[index].importedTaskId = taskId
        persist()
    }
    
    // MARK: - Parsing Logic
    
    func startParsing(job: SyllabusParsingJob, fileURL: URL?) {
        updateJobStatus(job.id, status: .running)
        
        // Simulate parsing with basic heuristics
        Task {
            do {
                let assignments = try await parseFile(fileURL: fileURL, jobId: job.id, courseId: job.courseId)
                
                for assignment in assignments {
                    addParsedAssignment(assignment)
                }
                
                updateJobStatus(job.id, status: .succeeded)
                
                // Send completion notification
                await sendCompletionNotification(courseId: job.courseId)
            } catch {
                updateJobStatus(job.id, status: .failed, errorMessage: error.localizedDescription)
            }
        }
    }
    
    private func parseFile(fileURL: URL?, jobId: UUID, courseId: UUID) async throws -> [ParsedAssignment] {
        // Simple algorithmic parser (no LLM)
        // This is a placeholder - real implementation would parse PDF/text
        
        guard let fileURL = fileURL else {
            throw NSError(domain: "SyllabusParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "File URL not provided"])
        }
        
        // Simulate parsing delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Return sample parsed assignments
        return [
            ParsedAssignment(
                jobId: jobId,
                courseId: courseId,
                title: "Assignment 1",
                dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                inferredType: "Homework",
                provenanceAnchor: "Assignment 1 - Due Week 2"
            ),
            ParsedAssignment(
                jobId: jobId,
                courseId: courseId,
                title: "Midterm Exam",
                dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                inferredType: "Exam",
                provenanceAnchor: "Midterm - Week 5"
            )
        ]
    }
    
    private func sendCompletionNotification(courseId: UUID) async {
        #if os(macOS)
        let content = UNMutableNotificationContent()
        content.title = "Syllabus Parsing: Complete"
        content.body = "Click to review homework"
        content.sound = .default
        content.userInfo = ["type": "syllabus_parsing_complete", "courseId": courseId.uuidString]
        
        let request = UNNotificationRequest(
            identifier: "syllabus_parsing_\(courseId.uuidString)",
            content: content,
            trigger: nil  // Immediate
        )
        
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }
    
    // MARK: - Persistence
    
    private struct PersistedData: Codable {
        var parsingJobs: [SyllabusParsingJob]
        var parsedAssignments: [ParsedAssignment]
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode(PersistedData.self, from: data)
            self.parsingJobs = decoded.parsingJobs
            self.parsedAssignments = decoded.parsedAssignments
        } catch {
            print("Failed to load syllabus parsing data: \(error)")
        }
    }
    
    private func persist() {
        let snapshot = PersistedData(
            parsingJobs: parsingJobs,
            parsedAssignments: parsedAssignments
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("Failed to persist syllabus parsing data: \(error)")
        }
    }
}
