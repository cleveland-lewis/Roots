import XCTest
@testable import Roots

/// Integration test: 100 consecutive generations with mixed success/failure
class HundredRunIntegrationTests: XCTestCase {
    
    var builders: TestBuilders!
    var random: SeededRandom!
    
    override func setUp() {
        super.setUp()
        builders = TestBuilders(seed: 42)
        random = SeededRandom(seed: 42)
    }
    
    // MARK: - 100-Run Test
    
    func test100ConsecutiveGenerations() async throws {
        var successCount = 0
        var failureCount = 0
        var totalValidationErrors = 0
        var totalRepairAttempts = 0
        var totalFallbacksUsed = 0
        
        let startTime = Date()
        
        for i in 1...100 {
            autoreleasepool {
                Task {
                    let result = await runSingleGeneration(iteration: i)
                    
                    switch result {
                    case .success(let stats):
                        successCount += 1
                        totalValidationErrors += stats.validationErrorCount
                        totalRepairAttempts += stats.repairAttempts
                        totalFallbacksUsed += stats.fallbacksUsed
                        
                    case .failure:
                        failureCount += 1
                    }
                }
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Assertions
        XCTAssertGreaterThan(successCount, 0, "Should have at least some successes")
        
        // With good configuration, failure rate should be low
        let failureRate = Double(failureCount) / 100.0
        XCTAssertLessThan(failureRate, 0.2, "Failure rate should be < 20%")
        
        // Log summary
        print("""
        
        ===== 100-Run Test Summary =====
        Total Time: \(String(format: "%.2f", elapsed))s
        Avg Time per Test: \(String(format: "%.2f", elapsed / 100.0))s
        
        Results:
        - Successes: \(successCount)
        - Failures: \(failureCount)
        - Success Rate: \(String(format: "%.1f", Double(successCount) * 100.0 / 100.0))%
        
        Quality Metrics:
        - Total Validation Errors: \(totalValidationErrors)
        - Total Repair Attempts: \(totalRepairAttempts)
        - Total Fallbacks Used: \(totalFallbacksUsed)
        - Avg Validation Errors per Success: \(Double(totalValidationErrors) / max(Double(successCount), 1.0))
        ===============================
        
        """)
        
        // Time budget assertion (should not take > 5 minutes)
        XCTAssertLessThan(elapsed, 300, "100 generations should complete in < 5 minutes")
    }
    
    private func runSingleGeneration(iteration: Int) async -> Result<GenerationStats, Error> {
        // Create a fake LLM with mixed behavior
        let fakeLLM = FakeLLMClient()
        
        // Configure failure rate based on iteration
        // Make some iterations harder than others
        let failureRate: Double
        switch iteration % 10 {
        case 0...7:
            failureRate = 0.1  // 10% failure rate
        case 8:
            failureRate = 0.3  // 30% failure rate
        case 9:
            failureRate = 0.5  // 50% failure rate
        default:
            failureRate = 0.1
        }
        
        fakeLLM.failureRate = failureRate
        
        // Generate test configuration
        let questionCount = random.int(in: 5...15)
        let topics = generateRandomTopics(count: random.int(in: 1...3))
        let difficulty: PracticeTestDifficulty = random.element(from: [.easy, .medium, .hard]) ?? .medium
        
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test Course \(iteration)",
            topics: topics,
            difficulty: difficulty,
            questionCount: questionCount
        )
        
        // Generate blueprint and queue responses
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
        
        for slot in blueprint.slots {
            if Double.random(in: 0...1) < failureRate {
                fakeLLM.queueFailure()
            } else {
                fakeLLM.queueSuccess(builders.buildValidJSON(for: slot))
            }
        }
        
        // Run generation
        let llmService = LocalLLMService(backend: fakeLLM)
        let generator = AlgorithmicTestGenerator(
            llmService: llmService,
            maxAttemptsPerSlot: 5,
            maxAttemptsPerTest: 3,
            enableDevLogs: false
        )
        
        let result = await generator.generateTest(request: request)
        
        switch result {
        case .success(let questions):
            // Verify all questions are valid
            for validated in questions {
                guard validateQuestion(validated.question) else {
                    return .failure(NSError(domain: "TestGen", code: -1,
                                           userInfo: [NSLocalizedDescriptionKey: "Invalid question in result"]))
                }
            }
            
            return .success(GenerationStats(
                totalSlots: generator.stats.totalSlots,
                successfulSlots: generator.stats.successfulSlots,
                failedSlots: generator.stats.failedSlots,
                totalAttempts: generator.stats.totalAttempts,
                averageAttemptsPerSlot: generator.stats.averageAttemptsPerSlot,
                validationErrors: generator.stats.validationErrors,
                repairAttempts: generator.stats.repairAttempts,
                fallbacksUsed: generator.stats.fallbacksUsed
            ))
            
        case .failure(let failure):
            return .failure(failure)
        }
    }
    
    private func generateRandomTopics(count: Int) -> [String] {
        var topics: [String] = []
        for _ in 0..<count {
            topics.append(random.topicName())
        }
        return topics
    }
    
    private func validateQuestion(_ question: PracticeQuestion) -> Bool {
        // Basic validation
        guard !question.prompt.isEmpty else { return false }
        guard !question.correctAnswer.isEmpty else { return false }
        guard !question.explanation.isEmpty else { return false }
        
        // MCQ validation
        if question.format == .multipleChoice {
            guard let options = question.options else { return false }
            guard options.count == 4 else { return false }
            guard options.contains(question.correctAnswer) else { return false }
        }
        
        return true
    }
    
    // MARK: - Specific Invariant Tests
    
    func testNoSchemaFailuresEscapeValidation() async throws {
        var escapedFailures = 0
        
        for _ in 1...50 {
            let fakeLLM = FakeLLMClient()
            let request = PracticeTestRequest(
                courseId: UUID(),
                courseName: "Test",
                topics: ["Topic"],
                difficulty: .medium,
                questionCount: 5
            )
            
            let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
            
            for slot in blueprint.slots {
                if random.bool() {
                    // Valid question
                    fakeLLM.queueSuccess(builders.buildValidJSON(for: slot))
                } else {
                    // Invalid question (should be caught)
                    let invalidType: TestBuilders.InvalidJSONType = random.element(from: [
                        .notJSON, .trailingComma, .wrongType
                    ]) ?? .notJSON
                    
                    fakeLLM.queueSuccess(builders.buildInvalidJSON(type: invalidType))
                }
            }
            
            let llmService = LocalLLMService(backend: fakeLLM)
            let generator = AlgorithmicTestGenerator(
                llmService: llmService,
                maxAttemptsPerSlot: 2,
                enableDevLogs: false
            )
            
            let result = await generator.generateTest(request: request)
            
            switch result {
            case .success(let questions):
                // If successful, verify no invalid questions
                for validated in questions {
                    if !validateQuestion(validated.question) {
                        escapedFailures += 1
                    }
                }
                
            case .failure:
                // Failure is OK
                break
            }
        }
        
        XCTAssertEqual(escapedFailures, 0, "No schema failures should escape validation")
    }
    
    func testCorrectAnswerIndexDistributionIsNonPathological() async throws {
        var allIndexCounts: [Int: Int] = [0: 0, 1: 0, 2: 0, 3: 0]
        var totalMCQs = 0
        
        for _ in 1...20 {
            let fakeLLM = FakeLLMClient()
            let request = PracticeTestRequest(
                courseId: UUID(),
                courseName: "Test",
                topics: ["Topic"],
                difficulty: .medium,
                questionCount: 10
            )
            
            let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
            
            for slot in blueprint.slots {
                let correctIndex = random.int(in: 0...3)
                fakeLLM.queueSuccess(builders.buildValidJSON(for: slot, correctIndex: correctIndex))
            }
            
            let llmService = LocalLLMService(backend: fakeLLM)
            let generator = AlgorithmicTestGenerator(
                llmService: llmService,
                enableDevLogs: false
            )
            
            let result = await generator.generateTest(request: request)
            
            if case .success(let questions) = result {
                for validated in questions {
                    if let options = validated.question.options,
                       let index = options.firstIndex(of: validated.question.correctAnswer) {
                        allIndexCounts[index, default: 0] += 1
                        totalMCQs += 1
                    }
                }
            }
        }
        
        // Check distribution
        for (index, count) in allIndexCounts {
            let percentage = Double(count) / Double(totalMCQs)
            XCTAssertLessThanOrEqual(percentage, 0.4,
                                    "Index \(index) appears in \(Int(percentage * 100))% of questions (should be ≤40%)")
        }
    }
}

extension GenerationStats {
    var validationErrorCount: Int { validationErrors.count }
}
