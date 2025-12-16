import XCTest
@testable import Roots

/// Tests for deterministic blueprint generation
class BlueprintDeterminismTests: XCTestCase {
    
    var builders: TestBuilders!
    
    override func setUp() {
        super.setUp()
        builders = TestBuilders(seed: 42)
    }
    
    // MARK: - Determinism Tests
    
    func testSameInputsProduceIdenticalBlueprints() {
        let request1 = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Biology 101",
            topics: ["Cells", "DNA"],
            difficulty: .medium,
            questionCount: 10
        )
        
        let request2 = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Biology 101",
            topics: ["Cells", "DNA"],
            difficulty: .medium,
            questionCount: 10
        )
        
        let blueprint1 = TestBlueprintGenerator.generateBlueprint(from: request1)
        let blueprint2 = TestBlueprintGenerator.generateBlueprint(from: request2)
        
        // Core properties must match
        XCTAssertEqual(blueprint1.questionCount, blueprint2.questionCount)
        XCTAssertEqual(blueprint1.topics, blueprint2.topics)
        XCTAssertEqual(blueprint1.topicQuotas, blueprint2.topicQuotas)
        XCTAssertEqual(blueprint1.difficultyTarget, blueprint2.difficultyTarget)
        XCTAssertEqual(blueprint1.difficultyDistribution, blueprint2.difficultyDistribution)
        XCTAssertEqual(blueprint1.bloomDistribution, blueprint2.bloomDistribution)
        XCTAssertEqual(blueprint1.estimatedTimeMinutes, blueprint2.estimatedTimeMinutes)
        
        // Slots should match in structure (though order may vary due to shuffle)
        XCTAssertEqual(blueprint1.slots.count, blueprint2.slots.count)
    }
    
    func testQuotaAccountingAddsUpCorrectly() {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test Course",
            topics: ["Topic A", "Topic B", "Topic C"],
            difficulty: .medium,
            questionCount: 10
        )
        
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
        
        // Topic quotas must sum to total
        let topicSum = blueprint.topicQuotas.values.reduce(0, +)
        XCTAssertEqual(topicSum, blueprint.questionCount,
                      "Topic quotas must sum to question count")
        
        // Difficulty quotas must sum to total
        let difficultySum = blueprint.difficultyDistribution.values.reduce(0, +)
        XCTAssertEqual(difficultySum, blueprint.questionCount,
                      "Difficulty distribution must sum to question count")
        
        // Bloom quotas must sum to total
        let bloomSum = blueprint.bloomDistribution.values.reduce(0, +)
        XCTAssertEqual(bloomSum, blueprint.questionCount,
                      "Bloom distribution must sum to question count")
    }
    
    func testBloomDistributionMatchesDifficultyTarget() {
        let easyRequest = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .easy,
            questionCount: 10
        )
        
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: easyRequest)
        
        // Easy should focus on Remember and Understand
        let rememberCount = blueprint.bloomDistribution[.remember] ?? 0
        let understandCount = blueprint.bloomDistribution[.understand] ?? 0
        let lowerLevels = rememberCount + understandCount
        
        XCTAssertGreaterThanOrEqual(lowerLevels, 6,
                                   "Easy tests should have mostly Remember/Understand")
    }
    
    func testDifficultyDistributionMatchesTarget() {
        let mediumRequest = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .medium,
            questionCount: 10
        )
        
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: mediumRequest)
        
        // Medium should have majority medium difficulty
        let mediumCount = blueprint.difficultyDistribution[.medium] ?? 0
        XCTAssertGreaterThanOrEqual(mediumCount, 5,
                                   "Medium target should have majority medium questions")
    }
    
    func testTemplateSequenceRotatesThroughAllTypes() {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .medium,
            questionCount: 10
        )
        
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
        
        let uniqueTemplates = Set(blueprint.templateSequence)
        XCTAssertGreaterThanOrEqual(uniqueTemplates.count, 3,
                                   "Should use multiple template types")
    }
    
    func testSlotsMatchBlueprintDistributions() {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["A", "B"],
            difficulty: .medium,
            questionCount: 10
        )
        
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
        
        // Count actual slot distributions
        var topicCounts: [String: Int] = [:]
        var difficultyCounts: [PracticeTestDifficulty: Int] = [:]
        var bloomCounts: [BloomLevel: Int] = [:]
        
        for slot in blueprint.slots {
            topicCounts[slot.topic, default: 0] += 1
            difficultyCounts[slot.difficulty, default: 0] += 1
            bloomCounts[slot.bloomLevel, default: 0] += 1
        }
        
        // Verify they match blueprint
        XCTAssertEqual(topicCounts, blueprint.topicQuotas)
        XCTAssertEqual(difficultyCounts, blueprint.difficultyDistribution)
        XCTAssertEqual(bloomCounts, blueprint.bloomDistribution)
    }
    
    func testEstimatedTimeScalesWithQuestionCount() {
        let small = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .easy,
            questionCount: 5
        )
        
        let large = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .easy,
            questionCount: 20
        )
        
        let smallBlueprint = TestBlueprintGenerator.generateBlueprint(from: small)
        let largeBlueprint = TestBlueprintGenerator.generateBlueprint(from: large)
        
        XCTAssertLessThan(smallBlueprint.estimatedTimeMinutes,
                         largeBlueprint.estimatedTimeMinutes,
                         "Estimated time should scale with question count")
        
        // Should be roughly proportional
        let ratio = Double(largeBlueprint.estimatedTimeMinutes) /
                   Double(smallBlueprint.estimatedTimeMinutes)
        XCTAssertGreaterThan(ratio, 2.0)
        XCTAssertLessThan(ratio, 6.0)
    }
    
    func testEstimatedTimeAccountsForDifficulty() {
        let easy = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .easy,
            questionCount: 10
        )
        
        let hard = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Topic"],
            difficulty: .hard,
            questionCount: 10
        )
        
        let easyBlueprint = TestBlueprintGenerator.generateBlueprint(from: easy)
        let hardBlueprint = TestBlueprintGenerator.generateBlueprint(from: hard)
        
        XCTAssertLessThan(easyBlueprint.estimatedTimeMinutes,
                         hardBlueprint.estimatedTimeMinutes,
                         "Hard tests should take more time than easy tests")
    }
    
    func testEmptyTopicsUsesCourseName() {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Biology 101",
            topics: [],
            difficulty: .medium,
            questionCount: 5
        )
        
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
        
        XCTAssertEqual(blueprint.topics, ["Biology 101"],
                      "Should use course name when no topics provided")
        XCTAssertEqual(blueprint.topicQuotas["Biology 101"], 5)
    }
    
    func testSingleTopicGetsAllQuestions() {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["Single Topic"],
            difficulty: .medium,
            questionCount: 10
        )
        
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
        
        XCTAssertEqual(blueprint.topicQuotas["Single Topic"], 10)
        XCTAssertEqual(blueprint.slots.filter { $0.topic == "Single Topic" }.count, 10)
    }
    
    func testMultipleTopicsDistributedEvenly() {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["A", "B", "C"],
            difficulty: .medium,
            questionCount: 9
        )
        
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
        
        // Should distribute evenly (3, 3, 3)
        XCTAssertEqual(blueprint.topicQuotas["A"], 3)
        XCTAssertEqual(blueprint.topicQuotas["B"], 3)
        XCTAssertEqual(blueprint.topicQuotas["C"], 3)
    }
    
    func testUnevenDistributionHandlesRemainder() {
        let request = PracticeTestRequest(
            courseId: UUID(),
            courseName: "Test",
            topics: ["A", "B", "C"],
            difficulty: .medium,
            questionCount: 10
        )
        
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
        
        // 10 / 3 = 3 remainder 1, so should be 4, 3, 3 or similar
        let quotas = Array(blueprint.topicQuotas.values).sorted()
        XCTAssertEqual(quotas, [3, 3, 4])
    }
}
