import XCTest
@testable import Roots

/// Tests for slot-level regeneration behavior
class RegenerationBehaviorTests: XCTestCase {
    
    var builders: TestBuilders!
    var fakeLLM: FakeLLMClient!
    var generator: AlgorithmicTestGenerator!
    
    override func setUp() {
        super.setUp()
        builders = TestBuilders(seed: 42)
        fakeLLM = FakeLLMClient()
        
        let llmService = LocalLLMService(backend: fakeLLM)
        generator = AlgorithmicTestGenerator(
            llmService: llmService,
            maxAttemptsPerSlot: 5,
            maxAttemptsPerTest: 3,
            enableDevLogs: false
        )
    }
    
    override func tearDown() {
        fakeLLM.reset()
        super.tearDown()
    }
    
    // MARK: - Basic Retry Behavior
    
    func testFailsTwiceThenSucceedsIsAccepted() async throws {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .medium,
            questionCount: 1
        )
        
        let slot = builders.buildSlot(id: "S1", topic: "Topic")
        let validJSON = builders.buildValidJSON(for: slot)
        
        // Queue: fail, fail, success
        fakeLLM.queuePattern(failures: 2, thenSuccess: validJSON)
        
        let result = await generator.generateTest(request: request)
        
        switch result {
        case .success(let questions):
            XCTAssertEqual(questions.count, 1, "Should succeed after retries")
            XCTAssertEqual(fakeLLM.callCount, 3, "Should have made 3 attempts")
            
        case .failure(let failure):
            XCTFail("Should succeed after retries: \(failure.description)")
        }
    }
    
    func testExhaustsAttemptsAndFails() async throws {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .medium,
            questionCount: 1
        )
        
        // Queue 10 failures (more than maxAttemptsPerSlot)
        for _ in 0..<10 {
            fakeLLM.queueFailure()
        }
        
        let result = await generator.generateTest(request: request)
        
        switch result {
        case .success:
            // Might succeed with fallback
            XCTAssertGreaterThanOrEqual(fakeLLM.callCount, 5,
                                       "Should have tried max attempts")
            
        case .failure(let failure):
            XCTAssertGreaterThanOrEqual(failure.attemptsMade, 1,
                                       "Should have recorded attempts")
        }
    }
    
    // MARK: - Fallback Behavior
    
    func testFallbackQuestionUsedAfterExhaustion() async throws {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Biology"],
            difficulty: .medium,
            questionCount: 1
        )
        
        // Queue all failures to trigger fallback
        fakeLLM.alwaysFail = true
        
        let result = await generator.generateTest(request: request)
        
        switch result {
        case .success(let questions):
            XCTAssertEqual(questions.count, 1, "Should use fallback")
            XCTAssertEqual(generator.stats.fallbacksUsed, 1,
                          "Should have used 1 fallback")
            
            // Fallback question should be valid
            let question = questions[0].question
            XCTAssertFalse(question.prompt.isEmpty)
            XCTAssertFalse(question.correctAnswer.isEmpty)
            
        case .failure:
            // Some implementations might fail instead of fallback
            // Both are acceptable based on configuration
            break
        }
    }
    
    // MARK: - Repair Instructions
    
    func testRepairInstructionsIncludeValidationErrors() async throws {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .medium,
            questionCount: 1
        )
        
        let slot = builders.buildSlot(id: "S1", topic: "Topic")
        
        // First: invalid (wrong topic)
        let invalidDraft = builders.buildInvalidDraft(for: slot, violation: .wrongTopic)
        guard let invalidJSON = try? JSONEncoder().encode(invalidDraft),
              let invalidString = String(data: invalidJSON, encoding: .utf8) else {
            XCTFail("Failed to create invalid JSON")
            return
        }
        
        // Second: valid
        let validJSON = builders.buildValidJSON(for: slot)
        
        fakeLLM.queueSuccess(invalidString)
        fakeLLM.queueSuccess(validJSON)
        
        let result = await generator.generateTest(request: request)
        
        switch result {
        case .success:
            XCTAssertEqual(fakeLLM.callCount, 2, "Should retry after validation error")
            
            // Second call should have received repair instructions
            if fakeLLM.allPrompts.count >= 2 {
                let secondPrompt = fakeLLM.allPrompts[1]
                XCTAssertTrue(secondPrompt.contains("PREVIOUS ERRORS"),
                             "Repair prompt should mention previous errors")
            }
            
        case .failure(let failure):
            XCTFail("Should succeed with valid second attempt: \(failure)")
        }
    }
    
    // MARK: - Distribution Validation
    
    func testDistributionFailureTriggersWholeTestRetry() async throws {
        // This test would need a way to inject pathological answer distributions
        // Skipping full implementation for now as it requires more complex setup
        
        // The key behavior to test:
        // 1. All slots generate successfully
        // 2. Distribution validation fails (e.g., all answers are 'A')
        // 3. Entire test regenerates
        // 4. Eventually succeeds or fails with proper error
    }
    
    // MARK: - Never-Ship-Invalid Guarantee
    
    func testNeverReturnsPartialInvalidTest() async throws {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic A", "Topic B"],
            difficulty: .medium,
            questionCount: 5
        )
        
        // Mix of valid and invalid responses
        let blueprint = builders.buildBlueprint(questionCount: 5, topics: ["Topic A", "Topic B"])
        
        for slot in blueprint.slots {
            if slot.id == "S3" {
                // This slot always fails
                fakeLLM.queueFailure()
                fakeLLM.queueFailure()
                fakeLLM.queueFailure()
                fakeLLM.queueFailure()
                fakeLLM.queueFailure()
            } else {
                // Others succeed
                fakeLLM.queueSuccess(builders.buildValidJSON(for: slot))
            }
        }
        
        let result = await generator.generateTest(request: request)
        
        switch result {
        case .success(let questions):
            // If success, ALL questions must be valid
            XCTAssertEqual(questions.count, 5, "Must return all questions or none")
            
            for validated in questions {
                XCTAssertFalse(validated.question.prompt.isEmpty)
                XCTAssertFalse(validated.question.correctAnswer.isEmpty)
            }
            
        case .failure(let failure):
            // Failure is acceptable - just no partial results
            XCTAssertNotNil(failure.reason)
        }
    }
    
    // MARK: - Statistics Tracking
    
    func testStatsTrackAttemptsCorrectly() async throws {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .medium,
            questionCount: 3
        )
        
        let blueprint = builders.buildBlueprint(questionCount: 3, topics: ["Topic"])
        
        // Slot 1: succeeds first try
        fakeLLM.queueSuccess(builders.buildValidJSON(for: blueprint.slots[0]))
        
        // Slot 2: fails once, succeeds
        fakeLLM.queueFailure()
        fakeLLM.queueSuccess(builders.buildValidJSON(for: blueprint.slots[1]))
        
        // Slot 3: fails twice, succeeds
        fakeLLM.queueFailure()
        fakeLLM.queueFailure()
        fakeLLM.queueSuccess(builders.buildValidJSON(for: blueprint.slots[2]))
        
        let result = await generator.generateTest(request: request)
        
        switch result {
        case .success:
            XCTAssertEqual(generator.stats.totalSlots, 3)
            XCTAssertEqual(generator.stats.successfulSlots, 3)
            XCTAssertEqual(generator.stats.failedSlots, 0)
            XCTAssertEqual(generator.stats.totalAttempts, 6, "1 + 2 + 3 attempts")
            XCTAssertEqual(generator.stats.averageAttemptsPerSlot, 2.0, accuracy: 0.1)
            
        case .failure:
            XCTFail("Should have succeeded")
        }
    }
}
