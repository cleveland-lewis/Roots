//
//  ParsedAssignmentsReviewTests.swift
//  RootsTests
//
//  Created for issue #180
//

import Testing
import Foundation
@testable import Roots

@MainActor
struct ParsedAssignmentsReviewTests {
    
    @Test func testParsedAssignmentCreation() async throws {
        let jobId = UUID()
        let courseId = UUID()
        
        let parsed = ParsedAssignment(
            jobId: jobId,
            courseId: courseId,
            title: "Test Assignment",
            dueDate: Date(),
            inferredType: "Homework"
        )
        
        #expect(parsed.title == "Test Assignment")
        #expect(parsed.inferredType == "Homework")
        #expect(parsed.isImported == false)
    }
    
    @Test func testParsingStoreAddAndRetrieve() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_parsing_\(UUID().uuidString).json")
        
        let store = SyllabusParsingStore(storageURL: tempURL)
        let courseId = UUID()
        let fileId = UUID()
        
        let job = store.createJob(courseId: courseId, fileId: fileId)
        
        let assignment = ParsedAssignment(
            jobId: job.id,
            courseId: courseId,
            title: "Test Assignment",
            dueDate: Date(),
            inferredType: "Homework"
        )
        
        store.addParsedAssignment(assignment)
        
        let retrieved = store.parsedAssignmentsByCourse(courseId)
        #expect(retrieved.count == 1)
        #expect(retrieved.first?.title == "Test Assignment")
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test func testMarkAsImported() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_parsing_\(UUID().uuidString).json")
        
        let store = SyllabusParsingStore(storageURL: tempURL)
        let courseId = UUID()
        let fileId = UUID()
        
        let job = store.createJob(courseId: courseId, fileId: fileId)
        
        let assignment = ParsedAssignment(
            jobId: job.id,
            courseId: courseId,
            title: "Test Assignment",
            dueDate: Date(),
            inferredType: "Homework"
        )
        
        store.addParsedAssignment(assignment)
        
        let taskId = UUID()
        store.markAsImported(assignment.id, taskId: taskId)
        
        // After marking as imported, should not appear in unimported list
        let unimported = store.parsedAssignmentsByCourse(courseId)
        #expect(unimported.isEmpty)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test func testUpdateParsedAssignment() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_parsing_\(UUID().uuidString).json")
        
        let store = SyllabusParsingStore(storageURL: tempURL)
        let courseId = UUID()
        let fileId = UUID()
        
        let job = store.createJob(courseId: courseId, fileId: fileId)
        
        var assignment = ParsedAssignment(
            jobId: job.id,
            courseId: courseId,
            title: "Original Title",
            dueDate: Date(),
            inferredType: "Homework"
        )
        
        store.addParsedAssignment(assignment)
        
        // Update the assignment
        assignment.title = "Updated Title"
        store.updateParsedAssignment(assignment)
        
        let retrieved = store.parsedAssignmentsByCourse(courseId)
        #expect(retrieved.first?.title == "Updated Title")
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
}
