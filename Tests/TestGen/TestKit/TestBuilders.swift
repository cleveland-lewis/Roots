import Foundation
@testable import Roots

/// Builders for test data structures
class TestBuilders {
    let random: SeededRandom
    
    init(seed: UInt64 = 42) {
        self.random = SeededRandom(seed: seed)
    }
    
    // MARK: - Blueprint Builders
    
    func buildBlueprint(
        questionCount: Int = 10,
        topics: [String]? = nil,
        difficulty: PracticeTestDifficulty = .medium
    ) -> TestBlueprint {
        let actualTopics = topics ?? ["Topic A", "Topic B"]
        
        let topicQuotas = TestBlueprintGenerator.distributeQuestions(
            count: questionCount,
            across: actualTopics
        )
        
        let difficultyDist = TestBlueprintGenerator.calculateDifficultyDistribution(
            count: questionCount,
            target: difficulty
        )
        
        let bloomDist = TestBlueprintGenerator.calculateBloomDistribution(
            count: questionCount,
            difficulty: difficulty
        )
        
        let templates = TestBlueprintGenerator.selectTemplateSequence(count: questionCount)
        
        let slots = TestBlueprintGenerator.createQuestionSlots(
            count: questionCount,
            topics: actualTopics,
            topicQuotas: topicQuotas,
            difficultyDistribution: difficultyDist,
            bloomDistribution: bloomDist,
            templateSequence: templates
        )
        
        return TestBlueprint(
            questionCount: questionCount,
            topics: actualTopics,
            topicQuotas: topicQuotas,
            difficultyTarget: difficulty,
            difficultyDistribution: difficultyDist,
            bloomDistribution: bloomDist,
            templateSequence: templates,
            slots: slots,
            estimatedTimeMinutes: questionCount * 3
        )
    }
    
    // MARK: - Slot Builders
    
    func buildSlot(
        id: String = "S1",
        topic: String = "Test Topic",
        bloomLevel: BloomLevel = .understand,
        difficulty: PracticeTestDifficulty = .medium,
        templateType: QuestionTemplateType = .conceptIdentification
    ) -> QuestionSlot {
        return QuestionSlot(
            id: id,
            topic: topic,
            bloomLevel: bloomLevel,
            difficulty: difficulty,
            templateType: templateType,
            maxPromptWords: 100,
            bannedPhrases: TestBlueprintGenerator.defaultBannedPhrases
        )
    }
    
    // MARK: - Question Draft Builders
    
    func buildValidDraft(
        for slot: QuestionSlot,
        correctIndex: Int = 0
    ) -> QuestionDraft {
        let choices = [
            "Correct answer for \(slot.topic)",
            "Incorrect option A",
            "Incorrect option B",
            "Incorrect option C"
        ]
        
        return QuestionDraft(
            prompt: "What is a key concept in \(slot.topic)?",
            choices: choices,
            correctAnswer: choices[correctIndex],
            correctIndex: correctIndex,
            rationale: "This is correct because it accurately represents \(slot.topic) at the \(slot.bloomLevel.rawValue) level. The concept is fundamental to understanding this topic area.",
            topic: slot.topic,
            bloomLevel: slot.bloomLevel.rawValue,
            difficulty: slot.difficulty.rawValue,
            templateType: slot.templateType.rawValue
        )
    }
    
    func buildInvalidDraft(
        for slot: QuestionSlot,
        violation: DraftViolation
    ) -> QuestionDraft {
        var draft = buildValidDraft(for: slot)
        
        switch violation {
        case .missingPrompt:
            draft.prompt = ""
            
        case .missingRationale:
            draft.rationale = ""
            
        case .shortRationale:
            draft.rationale = "Too short"
            
        case .wrongChoiceCount:
            draft.choices = ["A", "B", "C"]
            
        case .duplicateChoices:
            draft.choices = ["Same", "Same", "Different", "Another"]
            
        case .wrongTopic:
            draft.topic = "Wrong Topic"
            
        case .wrongDifficulty:
            draft.difficulty = "Hard"
            
        case .wrongBloomLevel:
            draft.bloomLevel = "Create"
            
        case .bannedPhrase:
            draft.choices = [
                "All of the above",
                "Option B",
                "Option C",
                "Option D"
            ]
            
        case .tooLongPrompt:
            draft.prompt = String(repeating: "word ", count: slot.maxPromptWords + 10)
            
        case .wrongCorrectIndex:
            draft.correctIndex = 5
            
        case .mismatchedAnswer:
            draft.correctAnswer = "Not in choices"
        }
        
        return draft
    }
    
    enum DraftViolation {
        case missingPrompt
        case missingRationale
        case shortRationale
        case wrongChoiceCount
        case duplicateChoices
        case wrongTopic
        case wrongDifficulty
        case wrongBloomLevel
        case bannedPhrase
        case tooLongPrompt
        case wrongCorrectIndex
        case mismatchedAnswer
    }
    
    // MARK: - JSON Builders
    
    func buildValidJSON(for slot: QuestionSlot, correctIndex: Int = 0) -> String {
        let draft = buildValidDraft(for: slot, correctIndex: correctIndex)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(draft),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return json
    }
    
    func buildInvalidJSON(type: InvalidJSONType) -> String {
        switch type {
        case .notJSON:
            return "This is not JSON at all"
            
        case .trailingComma:
            return """
            {
                "prompt": "Test",
                "choices": ["A", "B", "C", "D"],
            }
            """
            
        case .singleQuotes:
            return "{'prompt': 'Test', 'choices': ['A']}"
            
        case .missingBracket:
            return """
            {
                "prompt": "Test",
                "choices": ["A", "B", "C", "D"
            """
            
        case .extraField:
            return """
            {
                "prompt": "Test",
                "choices": ["A", "B", "C", "D"],
                "correctAnswer": "A",
                "correctIndex": 0,
                "rationale": "Test",
                "topic": "Test",
                "bloomLevel": "Understand",
                "difficulty": "Medium",
                "templateType": "concept_id",
                "extraField": "should be rejected"
            }
            """
            
        case .wrongType:
            return """
            {
                "prompt": "Test",
                "choices": "should be array",
                "correctAnswer": "A",
                "correctIndex": 0,
                "rationale": "Test",
                "topic": "Test",
                "bloomLevel": "Understand",
                "difficulty": "Medium",
                "templateType": "concept_id"
            }
            """
        }
    }
    
    enum InvalidJSONType {
        case notJSON
        case trailingComma
        case singleQuotes
        case missingBracket
        case extraField
        case wrongType
    }
    
    // MARK: - Generation Context Builder
    
    func buildContext(
        courseName: String = "Test Course",
        existingHashes: Set<String> = [],
        generatedCount: Int = 0,
        totalCount: Int = 10
    ) -> GenerationContext {
        return GenerationContext(
            courseName: courseName,
            existingQuestionHashes: existingHashes,
            generatedCount: generatedCount,
            totalCount: totalCount
        )
    }
}

// MARK: - TestBlueprintGenerator Extensions (Make Methods Public for Testing)

extension TestBlueprintGenerator {
    static func distributeQuestions(count: Int, across topics: [String]) -> [String: Int] {
        guard !topics.isEmpty else { return [:] }
        
        var quotas: [String: Int] = [:]
        let baseQuota = count / topics.count
        var remainder = count % topics.count
        
        for topic in topics {
            let quota = baseQuota + (remainder > 0 ? 1 : 0)
            quotas[topic] = quota
            if remainder > 0 {
                remainder -= 1
            }
        }
        
        return quotas
    }
    
    static func calculateDifficultyDistribution(
        count: Int,
        target: PracticeTestDifficulty
    ) -> [PracticeTestDifficulty: Int] {
        var distribution: [PracticeTestDifficulty: Int] = [.easy: 0, .medium: 0, .hard: 0]
        
        switch target {
        case .easy:
            distribution[.easy] = Int(Double(count) * 0.6)
            distribution[.medium] = Int(Double(count) * 0.3)
            distribution[.hard] = count - distribution[.easy]! - distribution[.medium]!
        case .medium:
            distribution[.easy] = Int(Double(count) * 0.2)
            distribution[.medium] = Int(Double(count) * 0.6)
            distribution[.hard] = count - distribution[.easy]! - distribution[.medium]!
        case .hard:
            distribution[.easy] = Int(Double(count) * 0.1)
            distribution[.medium] = Int(Double(count) * 0.3)
            distribution[.hard] = count - distribution[.easy]! - distribution[.medium]!
        }
        
        return distribution
    }
    
    static func calculateBloomDistribution(
        count: Int,
        difficulty: PracticeTestDifficulty
    ) -> [BloomLevel: Int] {
        var distribution: [BloomLevel: Int] = [:]
        
        switch difficulty {
        case .easy:
            distribution[.remember] = Int(Double(count) * 0.4)
            distribution[.understand] = Int(Double(count) * 0.4)
            distribution[.apply] = Int(Double(count) * 0.2)
        case .medium:
            distribution[.remember] = Int(Double(count) * 0.2)
            distribution[.understand] = Int(Double(count) * 0.3)
            distribution[.apply] = Int(Double(count) * 0.3)
            distribution[.analyze] = Int(Double(count) * 0.2)
        case .hard:
            distribution[.understand] = Int(Double(count) * 0.15)
            distribution[.apply] = Int(Double(count) * 0.25)
            distribution[.analyze] = Int(Double(count) * 0.35)
            distribution[.evaluate] = Int(Double(count) * 0.25)
        }
        
        let total = distribution.values.reduce(0, +)
        if total < count {
            let diff = count - total
            let maxLevel = distribution.max(by: { $0.value < $1.value })?.key ?? .understand
            distribution[maxLevel, default: 0] += diff
        }
        
        return distribution
    }
    
    static func selectTemplateSequence(count: Int) -> [QuestionTemplateType] {
        let templates = QuestionTemplateType.allCases
        var sequence: [QuestionTemplateType] = []
        
        for i in 0..<count {
            sequence.append(templates[i % templates.count])
        }
        
        return sequence
    }
    
    static func createQuestionSlots(
        count: Int,
        topics: [String],
        topicQuotas: [String: Int],
        difficultyDistribution: [PracticeTestDifficulty: Int],
        bloomDistribution: [BloomLevel: Int],
        templateSequence: [QuestionTemplateType]
    ) -> [QuestionSlot] {
        var slots: [QuestionSlot] = []
        
        var topicPool: [String] = []
        for (topic, quota) in topicQuotas {
            topicPool.append(contentsOf: Array(repeating: topic, count: quota))
        }
        topicPool.shuffle()
        
        var difficultyPool: [PracticeTestDifficulty] = []
        for (difficulty, quota) in difficultyDistribution {
            difficultyPool.append(contentsOf: Array(repeating: difficulty, count: quota))
        }
        difficultyPool.shuffle()
        
        var bloomPool: [BloomLevel] = []
        for (bloom, quota) in bloomDistribution {
            bloomPool.append(contentsOf: Array(repeating: bloom, count: quota))
        }
        bloomPool.shuffle()
        
        for i in 0..<count {
            let slot = QuestionSlot(
                id: "S\(i + 1)",
                topic: topicPool[i],
                bloomLevel: bloomPool[i],
                difficulty: difficultyPool[i],
                templateType: templateSequence[i],
                maxPromptWords: 100,
                bannedPhrases: defaultBannedPhrases
            )
            slots.append(slot)
        }
        
        return slots
    }
}
