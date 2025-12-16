import Foundation

// MARK: - Practice Test Models (v1)

/// Difficulty hint for practice test generation
enum PracticeTestDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    
    var id: String { rawValue }
}

/// Question format types supported in v1
enum QuestionFormat: String, Codable {
    case multipleChoice = "Multiple Choice"
    case shortAnswer = "Short Answer"
    case explanation = "Explanation"
}

/// Individual question in a practice test
struct PracticeQuestion: Identifiable, Codable, Hashable {
    var id: UUID
    var prompt: String
    var format: QuestionFormat
    var options: [String]? // For multiple choice
    var correctAnswer: String
    var explanation: String
    var bloomsLevel: String? // e.g., "Remember", "Understand", "Apply", "Analyze"
    
    init(
        id: UUID = UUID(),
        prompt: String,
        format: QuestionFormat,
        options: [String]? = nil,
        correctAnswer: String,
        explanation: String,
        bloomsLevel: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.format = format
        self.options = options
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.bloomsLevel = bloomsLevel
    }
}

/// User's answer to a practice question
struct PracticeAnswer: Codable, Hashable {
    var questionId: UUID
    var userAnswer: String
    var isCorrect: Bool
    var timeSpentSeconds: Double?
    
    init(questionId: UUID, userAnswer: String, isCorrect: Bool, timeSpentSeconds: Double? = nil) {
        self.questionId = questionId
        self.userAnswer = userAnswer
        self.isCorrect = isCorrect
        self.timeSpentSeconds = timeSpentSeconds
    }
}

/// Status of a practice test
enum PracticeTestStatus: String, Codable {
    case generating = "Generating"
    case ready = "Ready"
    case inProgress = "In Progress"
    case submitted = "Submitted"
    case failed = "Failed"
}

/// Complete practice test instance
struct PracticeTest: Identifiable, Codable {
    var id: UUID
    var courseId: UUID
    var courseName: String
    var topics: [String]
    var difficulty: PracticeTestDifficulty
    var questionCount: Int
    var questions: [PracticeQuestion]
    var answers: [UUID: PracticeAnswer] // questionId -> answer
    var status: PracticeTestStatus
    var createdAt: Date
    var submittedAt: Date?
    var generationError: String?
    
    init(
        id: UUID = UUID(),
        courseId: UUID,
        courseName: String,
        topics: [String],
        difficulty: PracticeTestDifficulty,
        questionCount: Int,
        questions: [PracticeQuestion] = [],
        answers: [UUID: PracticeAnswer] = [:],
        status: PracticeTestStatus = .generating,
        createdAt: Date = Date(),
        submittedAt: Date? = nil,
        generationError: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.courseName = courseName
        self.topics = topics
        self.difficulty = difficulty
        self.questionCount = questionCount
        self.questions = questions
        self.answers = answers
        self.status = status
        self.createdAt = createdAt
        self.submittedAt = submittedAt
        self.generationError = generationError
    }
    
    var score: Double? {
        guard status == .submitted else { return nil }
        let correct = answers.values.filter { $0.isCorrect }.count
        return questions.isEmpty ? 0 : Double(correct) / Double(questions.count)
    }
    
    var correctCount: Int {
        answers.values.filter { $0.isCorrect }.count
    }
}

/// Request to generate a practice test
struct PracticeTestRequest {
    var courseId: UUID
    var courseName: String
    var topics: [String]
    var difficulty: PracticeTestDifficulty
    var questionCount: Int
    var includeMultipleChoice: Bool
    var includeShortAnswer: Bool
    var includeExplanation: Bool
    
    init(
        courseId: UUID,
        courseName: String,
        topics: [String] = [],
        difficulty: PracticeTestDifficulty = .medium,
        questionCount: Int = 10,
        includeMultipleChoice: Bool = true,
        includeShortAnswer: Bool = true,
        includeExplanation: Bool = false
    ) {
        self.courseId = courseId
        self.courseName = courseName
        self.topics = topics
        self.difficulty = difficulty
        self.questionCount = questionCount
        self.includeMultipleChoice = includeMultipleChoice
        self.includeShortAnswer = includeShortAnswer
        self.includeExplanation = includeExplanation
    }
}

// MARK: - Analytics Models

/// Per-topic performance summary
struct TopicPerformance: Identifiable, Codable {
    var id: String { topic }
    var topic: String
    var totalQuestions: Int
    var correctAnswers: Int
    var averageScore: Double
    var lastPracticed: Date?
    
    var accuracy: Double {
        totalQuestions > 0 ? Double(correctAnswers) / Double(totalQuestions) : 0
    }
}

/// Practice test history summary
struct PracticeTestSummary: Codable {
    var totalTests: Int
    var totalQuestions: Int
    var averageScore: Double
    var topicPerformance: [String: TopicPerformance]
    var recentTests: [PracticeTest]
    var practiceFrequency: [Date: Int] // Date -> test count
    
    init(
        totalTests: Int = 0,
        totalQuestions: Int = 0,
        averageScore: Double = 0,
        topicPerformance: [String: TopicPerformance] = [:],
        recentTests: [PracticeTest] = [],
        practiceFrequency: [Date: Int] = [:]
    ) {
        self.totalTests = totalTests
        self.totalQuestions = totalQuestions
        self.averageScore = averageScore
        self.topicPerformance = topicPerformance
        self.recentTests = recentTests
        self.practiceFrequency = practiceFrequency
    }
}
