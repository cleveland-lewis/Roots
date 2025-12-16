import Foundation

/// Deterministic blueprint generator (no LLM involvement)
class TestBlueprintGenerator {
    
    // Default banned phrases for all questions
    static let defaultBannedPhrases = [
        "all of the above",
        "none of the above",
        "both a and b",
        "neither a nor b",
        "always",
        "never",
        "all",
        "none"
    ]
    
    /// Generate a test blueprint from request parameters
    static func generateBlueprint(from request: PracticeTestRequest) -> TestBlueprint {
        let questionCount = request.questionCount
        let topics = request.topics.isEmpty ? [request.courseName] : request.topics
        
        // Distribute questions across topics
        let topicQuotas = distributeQuestions(count: questionCount, across: topics)
        
        // Determine difficulty distribution
        let difficultyDistribution = calculateDifficultyDistribution(
            count: questionCount,
            target: request.difficulty
        )
        
        // Determine Bloom's taxonomy distribution
        let bloomDistribution = calculateBloomDistribution(
            count: questionCount,
            difficulty: request.difficulty
        )
        
        // Select template sequence
        let templateSequence = selectTemplateSequence(count: questionCount)
        
        // Create deterministic slots
        let slots = createQuestionSlots(
            count: questionCount,
            topics: topics,
            topicQuotas: topicQuotas,
            difficultyDistribution: difficultyDistribution,
            bloomDistribution: bloomDistribution,
            templateSequence: templateSequence
        )
        
        // Estimate time
        let estimatedTime = estimateTime(questionCount: questionCount, difficulty: request.difficulty)
        
        return TestBlueprint(
            questionCount: questionCount,
            topics: topics,
            topicQuotas: topicQuotas,
            difficultyTarget: request.difficulty,
            difficultyDistribution: difficultyDistribution,
            bloomDistribution: bloomDistribution,
            templateSequence: templateSequence,
            slots: slots,
            estimatedTimeMinutes: estimatedTime
        )
    }
    
    // MARK: - Distribution Algorithms
    
    private static func distributeQuestions(count: Int, across topics: [String]) -> [String: Int] {
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
    
    private static func calculateDifficultyDistribution(
        count: Int,
        target: PracticeTestDifficulty
    ) -> [PracticeTestDifficulty: Int] {
        var distribution: [PracticeTestDifficulty: Int] = [
            .easy: 0,
            .medium: 0,
            .hard: 0
        ]
        
        switch target {
        case .easy:
            // 60% easy, 30% medium, 10% hard
            distribution[.easy] = Int(Double(count) * 0.6)
            distribution[.medium] = Int(Double(count) * 0.3)
            distribution[.hard] = count - distribution[.easy]! - distribution[.medium]!
            
        case .medium:
            // 20% easy, 60% medium, 20% hard
            distribution[.easy] = Int(Double(count) * 0.2)
            distribution[.medium] = Int(Double(count) * 0.6)
            distribution[.hard] = count - distribution[.easy]! - distribution[.medium]!
            
        case .hard:
            // 10% easy, 30% medium, 60% hard
            distribution[.easy] = Int(Double(count) * 0.1)
            distribution[.medium] = Int(Double(count) * 0.3)
            distribution[.hard] = count - distribution[.easy]! - distribution[.medium]!
        }
        
        return distribution
    }
    
    private static func calculateBloomDistribution(
        count: Int,
        difficulty: PracticeTestDifficulty
    ) -> [BloomLevel: Int] {
        var distribution: [BloomLevel: Int] = [:]
        
        switch difficulty {
        case .easy:
            // Focus on Remember and Understand
            distribution[.remember] = Int(Double(count) * 0.4)
            distribution[.understand] = Int(Double(count) * 0.4)
            distribution[.apply] = Int(Double(count) * 0.2)
            
        case .medium:
            // Focus on Understand and Apply
            distribution[.remember] = Int(Double(count) * 0.2)
            distribution[.understand] = Int(Double(count) * 0.3)
            distribution[.apply] = Int(Double(count) * 0.3)
            distribution[.analyze] = Int(Double(count) * 0.2)
            
        case .hard:
            // Focus on Apply and Analyze
            distribution[.understand] = Int(Double(count) * 0.15)
            distribution[.apply] = Int(Double(count) * 0.25)
            distribution[.analyze] = Int(Double(count) * 0.35)
            distribution[.evaluate] = Int(Double(count) * 0.25)
        }
        
        // Ensure we hit exactly count
        let total = distribution.values.reduce(0, +)
        if total < count {
            let diff = count - total
            let maxLevel = distribution.max(by: { $0.value < $1.value })?.key ?? .understand
            distribution[maxLevel, default: 0] += diff
        }
        
        return distribution
    }
    
    private static func selectTemplateSequence(count: Int) -> [QuestionTemplateType] {
        let templates = QuestionTemplateType.allCases
        var sequence: [QuestionTemplateType] = []
        
        for i in 0..<count {
            sequence.append(templates[i % templates.count])
        }
        
        return sequence
    }
    
    private static func createQuestionSlots(
        count: Int,
        topics: [String],
        topicQuotas: [String: Int],
        difficultyDistribution: [PracticeTestDifficulty: Int],
        bloomDistribution: [BloomLevel: Int],
        templateSequence: [QuestionTemplateType]
    ) -> [QuestionSlot] {
        var slots: [QuestionSlot] = []
        
        // Create topic pool
        var topicPool: [String] = []
        for (topic, quota) in topicQuotas {
            topicPool.append(contentsOf: Array(repeating: topic, count: quota))
        }
        topicPool.shuffle()
        
        // Create difficulty pool
        var difficultyPool: [PracticeTestDifficulty] = []
        for (difficulty, quota) in difficultyDistribution {
            difficultyPool.append(contentsOf: Array(repeating: difficulty, count: quota))
        }
        difficultyPool.shuffle()
        
        // Create bloom pool
        var bloomPool: [BloomLevel] = []
        for (bloom, quota) in bloomDistribution {
            bloomPool.append(contentsOf: Array(repeating: bloom, count: quota))
        }
        bloomPool.shuffle()
        
        // Create slots
        for i in 0..<count {
            let slot = QuestionSlot(
                id: "S\(i + 1)",
                topic: topicPool[i],
                bloomLevel: bloomPool[i],
                difficulty: difficultyPool[i],
                templateType: templateSequence[i],
                maxPromptWords: maxPromptWords(for: difficultyPool[i]),
                bannedPhrases: defaultBannedPhrases
            )
            slots.append(slot)
        }
        
        return slots
    }
    
    private static func maxPromptWords(for difficulty: PracticeTestDifficulty) -> Int {
        switch difficulty {
        case .easy: return 50
        case .medium: return 75
        case .hard: return 100
        }
    }
    
    private static func estimateTime(questionCount: Int, difficulty: PracticeTestDifficulty) -> Int {
        let baseTime: Int
        switch difficulty {
        case .easy: baseTime = 2 // 2 minutes per question
        case .medium: baseTime = 3 // 3 minutes per question
        case .hard: baseTime = 4 // 4 minutes per question
        }
        
        return questionCount * baseTime
    }
}
