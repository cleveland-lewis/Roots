import Foundation

/// Local LLM service for practice test generation
/// v1: Placeholder for local LLM integration (MLX, Ollama, or similar)
@Observable
class LocalLLMService {
    
    enum LLMError: Error, LocalizedError {
        case modelUnavailable
        case generationFailed(String)
        case timeout
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "Local LLM is not available"
            case .generationFailed(let message):
                return "Generation failed: \(message)"
            case .timeout:
                return "Generation timed out"
            case .invalidResponse:
                return "Invalid response from LLM"
            }
        }
    }
    
    var isAvailable: Bool = false
    var modelName: String = "local-model"
    private let maxTokens: Int = 4096
    private let timeoutSeconds: TimeInterval = 60
    
    init() {
        checkAvailability()
    }
    
    private func checkAvailability() {
        // TODO: Check if MLX or Ollama is installed and running
        // For v1, we'll simulate availability
        isAvailable = true
    }
    
    /// Generate practice questions using local LLM
    func generateQuestions(request: PracticeTestRequest) async throws -> [PracticeQuestion] {
        guard isAvailable else {
            throw LLMError.modelUnavailable
        }
        
        let prompt = buildPrompt(for: request)
        
        // TODO: Replace with actual LLM call (MLX, Ollama, etc.)
        // For now, simulate generation with mock data
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay to simulate processing
        
        return try await mockGeneration(request: request)
    }
    
    private func buildPrompt(for request: PracticeTestRequest) -> String {
        var prompt = """
        Generate \(request.questionCount) practice questions for the course: \(request.courseName)
        Difficulty: \(request.difficulty.rawValue)
        """
        
        if !request.topics.isEmpty {
            prompt += "\nTopics: \(request.topics.joined(separator: ", "))"
        }
        
        prompt += """
        
        
        Question types to include:
        """
        
        if request.includeMultipleChoice {
            prompt += "\n- Multiple choice (4 options)"
        }
        if request.includeShortAnswer {
            prompt += "\n- Short answer"
        }
        if request.includeExplanation {
            prompt += "\n- Explanation-based"
        }
        
        prompt += """
        
        
        For each question, provide:
        1. Clear, unambiguous prompt
        2. Correct answer
        3. Brief explanation (2-3 sentences)
        4. Bloom's taxonomy level (Remember, Understand, Apply, Analyze, Evaluate, Create)
        
        Ensure questions:
        - Align with the specified difficulty level
        - Cover different aspects of the topic
        - Are pedagogically sound
        - Have clear, correct answers
        
        Format response as JSON array of questions.
        """
        
        return prompt
    }
    
    // MARK: - Mock Generation (v1 placeholder)
    
    private func mockGeneration(request: PracticeTestRequest) async throws -> [PracticeQuestion] {
        var questions: [PracticeQuestion] = []
        let questionTypes = availableQuestionTypes(for: request)
        
        for i in 0..<request.questionCount {
            let type = questionTypes[i % questionTypes.count]
            let question = generateMockQuestion(
                type: type,
                courseName: request.courseName,
                topics: request.topics,
                difficulty: request.difficulty,
                questionNumber: i + 1
            )
            questions.append(question)
        }
        
        return questions
    }
    
    private func availableQuestionTypes(for request: PracticeTestRequest) -> [QuestionFormat] {
        var types: [QuestionFormat] = []
        if request.includeMultipleChoice { types.append(.multipleChoice) }
        if request.includeShortAnswer { types.append(.shortAnswer) }
        if request.includeExplanation { types.append(.explanation) }
        return types.isEmpty ? [.multipleChoice] : types
    }
    
    private func generateMockQuestion(
        type: QuestionFormat,
        courseName: String,
        topics: [String],
        difficulty: PracticeTestDifficulty,
        questionNumber: Int
    ) -> PracticeQuestion {
        let topicText = topics.isEmpty ? courseName : topics.first ?? courseName
        
        switch type {
        case .multipleChoice:
            return PracticeQuestion(
                prompt: "Which of the following best describes \(topicText) in the context of \(courseName)?",
                format: .multipleChoice,
                options: [
                    "A fundamental concept that forms the basis of the subject",
                    "An advanced technique used in specialized applications",
                    "A deprecated approach no longer used",
                    "An alternative methodology with limited applications"
                ],
                correctAnswer: "A fundamental concept that forms the basis of the subject",
                explanation: "This concept is essential to understanding \(topicText) and serves as a foundation for more advanced topics in \(courseName).",
                bloomsLevel: difficulty == .easy ? "Remember" : difficulty == .medium ? "Understand" : "Apply"
            )
            
        case .shortAnswer:
            return PracticeQuestion(
                prompt: "Briefly explain the significance of \(topicText) in \(courseName).",
                format: .shortAnswer,
                correctAnswer: "\(topicText) is significant because it provides a framework for understanding key principles in \(courseName).",
                explanation: "A complete answer should mention the foundational role of \(topicText) and its practical applications in the field.",
                bloomsLevel: difficulty == .hard ? "Analyze" : "Understand"
            )
            
        case .explanation:
            return PracticeQuestion(
                prompt: "Explain how \(topicText) relates to other concepts in \(courseName). Provide specific examples.",
                format: .explanation,
                correctAnswer: "\(topicText) connects to multiple core concepts by serving as a bridge between theory and practice. For example, it influences both methodological approaches and practical applications.",
                explanation: "Strong answers should demonstrate understanding of relationships between concepts and provide concrete examples from the course material.",
                bloomsLevel: "Analyze"
            )
        }
    }
    
    /// Validate user answer against correct answer
    func validateAnswer(userAnswer: String, correctAnswer: String, format: QuestionFormat) -> Bool {
        let normalizedUser = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCorrect = correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch format {
        case .multipleChoice:
            return normalizedUser == normalizedCorrect
        case .shortAnswer:
            // Simple keyword matching for v1
            let keywords = normalizedCorrect.components(separatedBy: " ").filter { $0.count > 3 }
            let matchCount = keywords.filter { normalizedUser.contains($0) }.count
            return keywords.isEmpty ? false : Double(matchCount) / Double(keywords.count) >= 0.5
        case .explanation:
            // More lenient matching for explanations
            let keywords = normalizedCorrect.components(separatedBy: " ").filter { $0.count > 4 }
            let matchCount = keywords.filter { normalizedUser.contains($0) }.count
            return keywords.isEmpty ? false : Double(matchCount) / Double(keywords.count) >= 0.4
        }
    }
}
