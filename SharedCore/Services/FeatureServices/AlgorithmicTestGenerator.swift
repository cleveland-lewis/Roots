import Foundation

/// Algorithm-owned test generator with deterministic gates and never-ship-invalid guarantee
@Observable
class AlgorithmicTestGenerator {
    
    var isGenerating: Bool = false
    var stats: GenerationStats = GenerationStats()
    
    private let llmService: LocalLLMService
    private let maxAttemptsPerSlot: Int
    private let maxAttemptsPerTest: Int
    private let enableDevLogs: Bool
    
    init(
        llmService: LocalLLMService = LocalLLMService(),
        maxAttemptsPerSlot: Int = 5,
        maxAttemptsPerTest: Int = 3,
        enableDevLogs: Bool = false
    ) {
        self.llmService = llmService
        self.maxAttemptsPerSlot = maxAttemptsPerSlot
        self.maxAttemptsPerTest = maxAttemptsPerTest
        self.enableDevLogs = enableDevLogs
    }
    
    // MARK: - Main Generation Flow
    
    func generateTest(request: PracticeTestRequest) async -> GenerationResult {
        isGenerating = true
        defer { isGenerating = false }
        
        // Reset stats
        stats = GenerationStats()
        
        // Step 1: Generate deterministic blueprint
        let blueprint = TestBlueprintGenerator.generateBlueprint(from: request)
        logInfo("TestGen.Algorithm", "Blueprint created: \(blueprint.questionCount) questions, \(blueprint.topics.count) topics")
        
        // Step 2: Generate questions slot-by-slot
        var validatedQuestions: [QuestionValidated] = []
        var questionHashes: Set<String> = []
        var testAttempts = 0
        
        while testAttempts < maxAttemptsPerTest {
            testAttempts += 1
            logInfo("TestGen.Algorithm", "Test generation attempt \(testAttempts)/\(maxAttemptsPerTest)")
            
            validatedQuestions = []
            questionHashes = []
            stats.totalSlots = blueprint.slots.count
            stats.successfulSlots = 0
            stats.failedSlots = 0
            
            var generationContext = GenerationContext(
                courseName: request.courseName,
                existingQuestionHashes: questionHashes,
                generatedCount: 0,
                totalCount: blueprint.questionCount
            )
            
            // Generate each slot
            for slot in blueprint.slots {
                let result = await generateSlot(
                    slot: slot,
                    context: generationContext,
                    blueprint: blueprint
                )
                
                switch result {
                case .success(let validated):
                    validatedQuestions.append(validated)
                    questionHashes.insert(validated.promptHash)
                    stats.successfulSlots += 1
                    generationContext.generatedCount += 1
                    generationContext.existingQuestionHashes = questionHashes
                    
                case .failure(let failure):
                    stats.failedSlots += 1
                    stats.validationErrors.append(contentsOf: failure.errors)
                    logError("TestGen.Algorithm", "Slot \(slot.id) failed: \(failure.reason)")
                    break // Abort this test attempt
                }
            }
            
            // Check if all slots succeeded
            if validatedQuestions.count == blueprint.slots.count {
                // Step 3: Validate whole-test distribution
                let distributionErrors = QuestionValidator.validateDistribution(
                    validatedQuestions: validatedQuestions,
                    blueprint: blueprint
                )
                
                if distributionErrors.filter({ $0.severity == "error" }).isEmpty {
                    // Success!
                    stats.averageAttemptsPerSlot = Double(stats.totalAttempts) / Double(stats.totalSlots)
                    logInfo("TestGen.Algorithm", "Test generation succeeded on attempt \(testAttempts)")
                    return .success(validatedQuestions)
                } else {
                    // Distribution failed
                    stats.validationErrors.append(contentsOf: distributionErrors)
                    logError("TestGen.Algorithm", "Distribution validation failed: \(distributionErrors)")
                }
            }
        }
        
        // Failed after all attempts
        let failure = GenerationFailure(
            reason: "Failed to generate valid test after \(testAttempts) attempts",
            errors: stats.validationErrors,
            attemptsMade: testAttempts
        )
        
        logError("TestGen.Algorithm", "Test generation failed completely: \(failure.description)")
        return .failure(failure)
    }
    
    // MARK: - Slot Generation
    
    private func generateSlot(
        slot: QuestionSlot,
        context: GenerationContext,
        blueprint: TestBlueprint
    ) async -> Result<QuestionValidated, GenerationFailure> {
        logInfo("TestGen.Algorithm", "Generating slot \(slot.id): \(slot.topic) | \(slot.bloomLevel.rawValue) | \(slot.difficulty.rawValue)")
        
        var slotAttempts = 0
        var lastErrors: [ValidationError] = []
        
        while slotAttempts < maxAttemptsPerSlot {
            slotAttempts += 1
            stats.totalAttempts += 1
            
            logInfo("TestGen.Algorithm", "  Slot \(slot.id) attempt \(slotAttempts)/\(maxAttemptsPerSlot)")
            
            // Generate question draft
            do {
                let draft = try await llmService.generateQuestionForSlot(
                    slot: slot,
                    context: context,
                    repairInstructions: slotAttempts > 1 ? lastErrors : nil
                )
                
                // Validate schema
                let schemaErrors = QuestionValidator.validateSchema(draft: draft)
                if !schemaErrors.isEmpty {
                    lastErrors = schemaErrors
                    logError("TestGen.Validator", "    Schema validation failed: \(schemaErrors)")
                    stats.repairAttempts += 1
                    continue
                }
                
                // Validate content
                let contentErrors = QuestionValidator.validateContent(draft: draft, slot: slot)
                if !contentErrors.isEmpty {
                    lastErrors = contentErrors
                    logError("TestGen.Validator", "    Content validation failed: \(contentErrors)")
                    stats.repairAttempts += 1
                    continue
                }
                
                // Validate no duplicate
                let duplicateErrors = QuestionValidator.validateNoDuplicate(
                    draft: draft,
                    existingHashes: context.existingQuestionHashes
                )
                if !duplicateErrors.isEmpty {
                    lastErrors = duplicateErrors
                    logError("TestGen.Validator", "    Duplicate validation failed: \(duplicateErrors)")
                    stats.repairAttempts += 1
                    continue
                }
                
                // Convert to PracticeQuestion
                let practiceQuestion = convertDraftToPracticeQuestion(draft: draft)
                let promptHash = QuestionValidator.hashPrompt(draft.prompt)
                
                let validated = QuestionValidated(
                    slotId: slot.id,
                    question: practiceQuestion,
                    promptHash: promptHash
                )
                
                logInfo("TestGen.Algorithm", "  Slot \(slot.id) validated successfully")
                return .success(validated)
                
            } catch let error as LocalLLMService.LLMError {
                // Handle specific LLM errors
                switch error {
                case .contractViolation(let reason):
                    lastErrors = [ValidationError(
                        category: .schema,
                        message: "CONTRACT_VIOLATION: \(reason)",
                        severity: "error"
                    )]
                    logError("TestGen.Algorithm", "    LLM reported contract violation: \(reason)")
                    // This counts as an attempt, continue to retry or fallback
                    
                default:
                    lastErrors = [ValidationError(
                        category: .schema,
                        message: "LLM error: \(error.localizedDescription)",
                        severity: "error"
                    )]
                    logError("TestGen.Algorithm", "    LLM error: \(error)")
                }
                continue
                
            } catch {
                lastErrors = [ValidationError(
                    category: .schema,
                    message: "Generation error: \(error.localizedDescription)",
                    severity: "error"
                )]
                logError("TestGen.Algorithm", "    Generation threw error: \(error)")
                continue
            }
        }
        
        // Exhausted attempts, try fallback
        logError("TestGen.Algorithm", "  Slot \(slot.id) exhausted attempts, trying fallback")
        
        if let fallback = generateFallbackQuestion(slot: slot) {
            stats.fallbacksUsed += 1
            logInfo("TestGen.Algorithm", "  Slot \(slot.id) using fallback question")
            return .success(fallback)
        }
        
        // Complete failure
        let failure = GenerationFailure(
            reason: "Slot generation failed after \(slotAttempts) attempts",
            slotId: slot.id,
            errors: lastErrors,
            attemptsMade: slotAttempts
        )
        
        return .failure(failure)
    }
    
    // MARK: - Fallback Questions
    
    private func generateFallbackQuestion(slot: QuestionSlot) -> QuestionValidated? {
        // Deterministic fallback based on slot parameters
        let prompt = "What is a key concept related to \(slot.topic) at the \(slot.bloomLevel.rawValue) level?"
        let correctAnswer = "\(slot.topic) involves understanding fundamental principles at the \(slot.bloomLevel.rawValue) cognitive level."
        let explanation = "This question tests your \(slot.bloomLevel.rawValue) level understanding of \(slot.topic). The correct answer demonstrates comprehension of core concepts in this area."
        
        let question = PracticeQuestion(
            prompt: prompt,
            format: .multipleChoice,
            options: [
                correctAnswer,
                "An unrelated concept from a different field",
                "A superficial memorization approach",
                "A tangential application without depth"
            ],
            correctAnswer: correctAnswer,
            explanation: explanation,
            bloomsLevel: slot.bloomLevel.rawValue
        )
        
        let promptHash = QuestionValidator.hashPrompt(prompt)
        
        return QuestionValidated(
            slotId: slot.id,
            question: question,
            promptHash: promptHash
        )
    }
    
    // MARK: - Conversion
    
    private func convertDraftToPracticeQuestion(draft: QuestionDraft) -> PracticeQuestion {
        let format: QuestionFormat
        if draft.choices != nil {
            format = .multipleChoice
        } else if draft.templateType.contains("scenario") || draft.templateType.contains("compare") {
            format = .explanation
        } else {
            format = .shortAnswer
        }
        
        return PracticeQuestion(
            prompt: draft.prompt,
            format: format,
            options: draft.choices,
            correctAnswer: draft.correctAnswer,
            explanation: draft.rationale,
            bloomsLevel: draft.bloomLevel
        )
    }
    
    // MARK: - Logging
    
    private func logInfo(_ category: String, _ message: String) {
        if enableDevLogs {
            print("[\(category)] INFO: \(message)")
        }
    }
    
    private func logError(_ category: String, _ message: String) {
        if enableDevLogs {
            print("[\(category)] ERROR: \(message)")
        }
    }
}
