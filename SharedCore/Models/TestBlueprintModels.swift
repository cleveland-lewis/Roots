import Foundation

// MARK: - Blueprint-First Generation Models

/// Template type for question generation
enum QuestionTemplateType: String, Codable, CaseIterable {
    case conceptIdentification = "concept_id"
    case causeEffect = "cause_effect"
    case scenarioChange = "scenario_change"
    case dataInterpretation = "data_interpretation"
    case compareContrast = "compare_contrast"
}

/// Bloom's taxonomy level
enum BloomLevel: String, Codable, CaseIterable {
    case remember = "Remember"
    case understand = "Understand"
    case apply = "Apply"
    case analyze = "Analyze"
    case evaluate = "Evaluate"
    case create = "Create"
    
    var order: Int {
        switch self {
        case .remember: return 1
        case .understand: return 2
        case .apply: return 3
        case .analyze: return 4
        case .evaluate: return 5
        case .create: return 6
        }
    }
}

/// A single question slot specification (deterministic)
struct QuestionSlot: Identifiable, Codable, Hashable {
    var id: String // e.g., "S1", "S2", etc.
    var topic: String
    var bloomLevel: BloomLevel
    var difficulty: PracticeTestDifficulty
    var templateType: QuestionTemplateType
    var maxPromptWords: Int
    var bannedPhrases: [String]
    
    init(
        id: String,
        topic: String,
        bloomLevel: BloomLevel,
        difficulty: PracticeTestDifficulty,
        templateType: QuestionTemplateType,
        maxPromptWords: Int = 100,
        bannedPhrases: [String] = []
    ) {
        self.id = id
        self.topic = topic
        self.bloomLevel = bloomLevel
        self.difficulty = difficulty
        self.templateType = templateType
        self.maxPromptWords = maxPromptWords
        self.bannedPhrases = bannedPhrases
    }
}

/// Test blueprint (deterministically generated before LLM involvement)
struct TestBlueprint: Codable {
    var id: UUID
    var questionCount: Int
    var topics: [String]
    var topicQuotas: [String: Int] // topic -> question count
    var difficultyTarget: PracticeTestDifficulty
    var difficultyDistribution: [PracticeTestDifficulty: Int] // difficulty -> count
    var bloomDistribution: [BloomLevel: Int] // bloom level -> count
    var templateSequence: [QuestionTemplateType] // ordered templates
    var slots: [QuestionSlot] // deterministic slot plan
    var estimatedTimeMinutes: Int
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        questionCount: Int,
        topics: [String],
        topicQuotas: [String: Int],
        difficultyTarget: PracticeTestDifficulty,
        difficultyDistribution: [PracticeTestDifficulty: Int],
        bloomDistribution: [BloomLevel: Int],
        templateSequence: [QuestionTemplateType],
        slots: [QuestionSlot],
        estimatedTimeMinutes: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.questionCount = questionCount
        self.topics = topics
        self.topicQuotas = topicQuotas
        self.difficultyTarget = difficultyTarget
        self.difficultyDistribution = difficultyDistribution
        self.bloomDistribution = bloomDistribution
        self.templateSequence = templateSequence
        self.slots = slots
        self.estimatedTimeMinutes = estimatedTimeMinutes
        self.createdAt = createdAt
    }
}

/// Generation context for a single question
struct GenerationContext: Codable {
    var courseName: String
    var existingQuestionHashes: Set<String> // to avoid duplicates
    var generatedCount: Int // how many questions already generated
    var totalCount: Int
    
    init(
        courseName: String,
        existingQuestionHashes: Set<String> = [],
        generatedCount: Int = 0,
        totalCount: Int
    ) {
        self.courseName = courseName
        self.existingQuestionHashes = existingQuestionHashes
        self.generatedCount = generatedCount
        self.totalCount = totalCount
    }
}

/// Draft question from LLM (before validation)
struct QuestionDraft: Codable {
    var prompt: String
    var choices: [String]? // For MCQ
    var correctAnswer: String
    var correctIndex: Int? // For MCQ (0-3)
    var rationale: String
    var topic: String
    var bloomLevel: String
    var difficulty: String
    var templateType: String
}

/// Validated question (passed all gates)
struct QuestionValidated: Identifiable, Codable {
    var id: UUID
    var slotId: String
    var question: PracticeQuestion
    var promptHash: String
    var validatedAt: Date
    
    init(
        id: UUID = UUID(),
        slotId: String,
        question: PracticeQuestion,
        promptHash: String,
        validatedAt: Date = Date()
    ) {
        self.id = id
        self.slotId = slotId
        self.question = question
        self.promptHash = promptHash
        self.validatedAt = validatedAt
    }
}

/// Validation error details
struct ValidationError: Codable, Sendable, CustomStringConvertible {
    enum Category: String, Codable, Sendable {
        case schema = "Schema"
        case content = "Content"
        case distribution = "Distribution"
        case duplicate = "Duplicate"
    }
    
    var category: Category
    var field: String?
    var message: String
    var severity: String // "error" or "warning"
    
    nonisolated var description: String {
        if let field = field {
            return "[\(category.rawValue)] \(field): \(message)"
        }
        return "[\(category.rawValue)] \(message)"
    }
}

/// Generation failure state
struct GenerationFailure: Codable, Error, CustomStringConvertible, Sendable {
    var reason: String
    var slotId: String?
    var errors: [ValidationError]
    var attemptsMade: Int
    var timestamp: Date
    
    nonisolated var description: String {
        var desc = "Generation failed: \(reason)"
        if let slotId = slotId {
            desc += " (slot: \(slotId))"
        }
        desc += " after \(attemptsMade) attempts"
        if !errors.isEmpty {
            desc += "\nErrors:\n" + errors.map { "  - \($0)" }.joined(separator: "\n")
        }
        return desc
    }
    
    init(
        reason: String,
        slotId: String? = nil,
        errors: [ValidationError] = [],
        attemptsMade: Int = 0,
        timestamp: Date = Date()
    ) {
        self.reason = reason
        self.slotId = slotId
        self.errors = errors
        self.attemptsMade = attemptsMade
        self.timestamp = timestamp
    }
}

/// Generation result (either success or failure)
enum GenerationResult {
    case success([QuestionValidated])
    case failure(GenerationFailure)
}

/// Generation statistics
struct GenerationStats: Codable {
    var totalSlots: Int
    var successfulSlots: Int
    var failedSlots: Int
    var totalAttempts: Int
    var averageAttemptsPerSlot: Double
    var validationErrors: [ValidationError]
    var repairAttempts: Int
    var fallbacksUsed: Int
    
    init(
        totalSlots: Int = 0,
        successfulSlots: Int = 0,
        failedSlots: Int = 0,
        totalAttempts: Int = 0,
        averageAttemptsPerSlot: Double = 0,
        validationErrors: [ValidationError] = [],
        repairAttempts: Int = 0,
        fallbacksUsed: Int = 0
    ) {
        self.totalSlots = totalSlots
        self.successfulSlots = successfulSlots
        self.failedSlots = failedSlots
        self.totalAttempts = totalAttempts
        self.averageAttemptsPerSlot = averageAttemptsPerSlot
        self.validationErrors = validationErrors
        self.repairAttempts = repairAttempts
        self.fallbacksUsed = fallbacksUsed
    }
}
