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
        case contractViolation(String)
        case backendError(Error)
        
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
            case .contractViolation(let reason):
                return "LLM cannot comply with requirements: \(reason)"
            case .backendError(let error):
                return "Backend error: \(error.localizedDescription)"
            }
        }
    }
    
    var isAvailable: Bool = false
    var modelName: String = "local-model"
    var backend: LLMBackend
    var config: LLMBackendConfig
    
    private let maxTokens: Int = 4096
    private let timeoutSeconds: TimeInterval = 60
    
    init(backend: LLMBackend? = nil, config: LLMBackendConfig? = nil) {
        if let providedBackend = backend {
            self.backend = providedBackend
            self.config = providedBackend.config
        } else if let providedConfig = config {
            self.config = providedConfig
            self.backend = LLMBackendFactory.createBackend(config: providedConfig)
        } else {
            // Try to load from user defaults, or use mock
            let loadedBackend = LLMBackendFactory.createFromUserDefaults()
            self.backend = loadedBackend
            self.config = loadedBackend.config
        }
        
        self.modelName = self.config.modelName
        
        Task {
            await checkAvailability()
        }
    }
    
    private func checkAvailability() async {
        isAvailable = await backend.isAvailable
        
        if !isAvailable {
            print("[LocalLLMService] Backend \(config.type.rawValue) not available, falling back to mock")
            backend = MockLLMBackend()
            config = backend.config
            isAvailable = true
        }
    }
    
    /// Update backend configuration
    func updateBackend(_ newConfig: LLMBackendConfig) async {
        config = newConfig
        backend = LLMBackendFactory.createBackend(config: newConfig)
        await checkAvailability()
        LLMBackendFactory.saveConfig(newConfig)
    }
    
    /// Generate practice questions using local LLM (legacy method)
    func generateQuestions(request: PracticeTestRequest) async throws -> [PracticeQuestion] {
        guard isAvailable else {
            throw LLMError.modelUnavailable
        }
        
        // For legacy mode, use mock generation
        // Real LLM integration happens through generateQuestionForSlot()
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay to simulate processing
        
        return try await mockGeneration(request: request)
    }
    
    /// Generate a single question for a specific slot (blueprint-first approach)
    func generateQuestionForSlot(
        slot: QuestionSlot,
        context: GenerationContext,
        repairInstructions: [ValidationError]?
    ) async throws -> QuestionDraft {
        guard isAvailable else {
            throw LLMError.modelUnavailable
        }
        
        let prompt = buildSlotPrompt(slot: slot, context: context, repairInstructions: repairInstructions)
        
        do {
            // Use real LLM backend
            let jsonResponse = try await backend.generateJSON(prompt: prompt, schema: nil)
            
            // Check for CONTRACT_VIOLATION error response
            if let data = jsonResponse.data(using: .utf8),
               let errorCheck = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorCheck["error"] as? String,
               error == "CONTRACT_VIOLATION" {
                let reason = errorCheck["reason"] as? String ?? "Unknown reason"
                throw LLMError.contractViolation(reason)
            }
            
            // Parse the JSON response
            guard let data = jsonResponse.data(using: .utf8) else {
                throw LLMError.invalidResponse
            }
            
            // Use strict decoding
            let decoder = JSONDecoder()
            // Note: Swift's JSONDecoder already rejects unknown keys by default when using structs
            
            guard let json = try? decoder.decode(QuestionDraft.self, from: data) else {
                throw LLMError.invalidResponse
            }
            
            return json
            
        } catch {
            // If backend fails, provide detailed error
            if let backendError = error as? LLMBackendError {
                throw LLMError.backendError(backendError)
            }
            throw error
        }
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
    
    private func buildSlotPrompt(
        slot: QuestionSlot,
        context: GenerationContext,
        repairInstructions: [ValidationError]?
    ) -> String {
        var prompt = """
        Generate ONE multiple-choice question with the following STRICT requirements:
        
        CONTRACT VERSION: testgen.v1
        
        Course: \(context.courseName)
        Topic: \(slot.topic)
        Difficulty: \(slot.difficulty.rawValue)
        Bloom's Level: \(slot.bloomLevel.rawValue)
        Template Type: \(slot.templateType.rawValue)
        Max Prompt Words: \(slot.maxPromptWords)
        
        HARD-LINE REQUIREMENTS (NON-NEGOTIABLE):
        - Question prompt: clear, unambiguous, \(slot.maxPromptWords) words maximum
        - Exactly 4 answer choices (A, B, C, D)
        - Exactly 1 correct answer
        - Rationale: minimum 10 words explaining why the answer is correct
        - All choices must be unique and plausible
        - Correct answer can be in any position (0-3)
        - NO external sources or URLs allowed
        - ONLY use the provided topic: \(slot.topic)
        - Must match specified difficulty and Bloom level exactly
        
        BANNED PHRASES (do NOT use under any circumstances):
        \(slot.bannedPhrases.map { "  - \($0)" }.joined(separator: "\n"))
        
        AVOID:
        - Double negatives (e.g., "Which is NOT incorrect")
        - Trick questions or misleading language
        - Ambiguous phrasing
        - "All of the above" or "None of the above" constructs
        
        QUALITY SELF-CHECK:
        Before returning, verify:
        1. Prompt is clear and unambiguous
        2. All 4 choices are unique and plausible
        3. Only ONE choice is definitively correct
        4. Rationale justifies the correct answer
        5. No banned phrases present
        6. Word count within limit
        """
        
        if let repairs = repairInstructions, !repairs.isEmpty {
            prompt += "\n\nPREVIOUS ERRORS TO FIX:\n"
            for error in repairs {
                prompt += "- \(error.description)\n"
            }
            prompt += "\nYou MUST fix all errors above in this generation.\n"
        }
        
        prompt += """
        
        
        CRITICAL: If you CANNOT comply with these requirements, you MUST return:
        {"error": "CONTRACT_VIOLATION", "reason": "Specific reason why requirements cannot be met"}
        
        Otherwise, return ONLY valid JSON in this EXACT format (no markdown, no extra text):
        {
          "contractVersion": "testgen.v1",
          "prompt": "Your question text here",
          "choices": ["Choice A", "Choice B", "Choice C", "Choice D"],
          "correctAnswer": "The exact text of the correct choice",
          "correctIndex": 0,
          "rationale": "Explanation of why this is correct (minimum 10 words)",
          "topic": "\(slot.topic)",
          "bloomLevel": "\(slot.bloomLevel.rawValue)",
          "difficulty": "\(slot.difficulty.rawValue)",
          "templateType": "\(slot.templateType.rawValue)",
          "quality": {
            "selfCheck": ["List of criteria verified"],
            "confidence": 0.95
          }
        }
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
    
    private func mockSlotGeneration(slot: QuestionSlot, context: GenerationContext) async throws -> QuestionDraft {
        let topicText = slot.topic
        
        // Generate appropriate question based on template type and bloom level
        let (prompt, choices, correctIndex) = generateQuestionContent(
            slot: slot,
            topicText: topicText,
            context: context
        )
        
        let correctAnswer = choices[correctIndex]
        let rationale = generateRationale(
            slot: slot,
            topicText: topicText,
            correctAnswer: correctAnswer
        )
        
        return QuestionDraft(
            prompt: prompt,
            choices: choices,
            correctAnswer: correctAnswer,
            correctIndex: correctIndex,
            rationale: rationale,
            topic: slot.topic,
            bloomLevel: slot.bloomLevel.rawValue,
            difficulty: slot.difficulty.rawValue,
            templateType: slot.templateType.rawValue
        )
    }
    
    private func generateQuestionContent(
        slot: QuestionSlot,
        topicText: String,
        context: GenerationContext
    ) -> (prompt: String, choices: [String], correctIndex: Int) {
        let prompt: String
        let choices: [String]
        
        switch slot.templateType {
        case .conceptIdentification:
            prompt = "Which statement best identifies the core concept of \(topicText)?"
            choices = [
                "A fundamental principle that forms the basis of \(topicText)",
                "An advanced technique used only in specialized applications",
                "A deprecated approach that is no longer recommended",
                "An alternative methodology with limited practical use"
            ]
            
        case .causeEffect:
            prompt = "What is the primary effect when applying \(topicText) principles?"
            choices = [
                "Enhanced understanding and practical application capabilities",
                "Reduced flexibility in problem-solving approaches",
                "Increased complexity without tangible benefits",
                "Limited applicability to real-world scenarios"
            ]
            
        case .scenarioChange:
            prompt = "How would the outcome change if \(topicText) principles were applied differently?"
            choices = [
                "The results would align more closely with theoretical expectations",
                "The system would become less predictable and harder to control",
                "There would be no significant change in outcomes",
                "The approach would contradict established best practices"
            ]
            
        case .dataInterpretation:
            prompt = "When analyzing data related to \(topicText), which interpretation is most accurate?"
            choices = [
                "The data demonstrates clear patterns consistent with \(topicText) theory",
                "The data shows inconsistencies that contradict current understanding",
                "The data is insufficient to draw meaningful conclusions",
                "The data supports alternative explanations over \(topicText)"
            ]
            
        case .compareContrast:
            prompt = "How does \(topicText) compare to related concepts in the field?"
            choices = [
                "\(topicText) provides unique insights while building on foundational concepts",
                "\(topicText) completely replaces all previous approaches",
                "\(topicText) is largely redundant with existing methods",
                "\(topicText) contradicts most established principles"
            ]
        }
        
        // Randomize correct answer position
        let correctIndex = Int.random(in: 0..<4)
        
        return (prompt, choices, correctIndex)
    }
    
    private func generateRationale(
        slot: QuestionSlot,
        topicText: String,
        correctAnswer: String
    ) -> String {
        let bloomExplanation: String
        switch slot.bloomLevel {
        case .remember:
            bloomExplanation = "This requires recalling key facts about \(topicText)."
        case .understand:
            bloomExplanation = "This tests your understanding of how \(topicText) functions."
        case .apply:
            bloomExplanation = "This assesses your ability to apply \(topicText) concepts."
        case .analyze:
            bloomExplanation = "This evaluates your analytical thinking about \(topicText)."
        case .evaluate:
            bloomExplanation = "This measures your ability to evaluate \(topicText) critically."
        case .create:
            bloomExplanation = "This tests your capacity to synthesize ideas about \(topicText)."
        }
        
        return "The correct answer is the best choice because it accurately reflects the core principles of \(topicText). \(bloomExplanation) Other options either misrepresent the concept or present incorrect applications."
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
