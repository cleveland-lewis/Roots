import Foundation
import CryptoKit

/// Strict validation gates for question generation
class QuestionValidator {
    
    // MARK: - Schema Validation
    
    static func validateSchema(draft: QuestionDraft) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Required fields
        if draft.prompt.isEmpty {
            errors.append(ValidationError(
                category: .schema,
                field: "prompt",
                message: "Prompt cannot be empty",
                severity: "error"
            ))
        }
        
        if draft.correctAnswer.isEmpty {
            errors.append(ValidationError(
                category: .schema,
                field: "correctAnswer",
                message: "Correct answer cannot be empty",
                severity: "error"
            ))
        }
        
        if draft.rationale.isEmpty {
            errors.append(ValidationError(
                category: .schema,
                field: "rationale",
                message: "Rationale cannot be empty",
                severity: "error"
            ))
        }
        
        // MCQ-specific validation
        if let choices = draft.choices {
            if choices.count != 4 {
                errors.append(ValidationError(
                    category: .schema,
                    field: "choices",
                    message: "MCQ must have exactly 4 choices, got \(choices.count)",
                    severity: "error"
                ))
            }
            
            if let correctIndex = draft.correctIndex {
                if correctIndex < 0 || correctIndex > 3 {
                    errors.append(ValidationError(
                        category: .schema,
                        field: "correctIndex",
                        message: "correctIndex must be 0-3, got \(correctIndex)",
                        severity: "error"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    category: .schema,
                    field: "correctIndex",
                    message: "MCQ must have correctIndex",
                    severity: "error"
                ))
            }
        }
        
        return errors
    }
    
    // MARK: - Content Validation
    
    static func validateContent(draft: QuestionDraft, slot: QuestionSlot) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Topic validation
        if draft.topic.lowercased() != slot.topic.lowercased() {
            errors.append(ValidationError(
                category: .content,
                field: "topic",
                message: "Topic mismatch: expected '\(slot.topic)', got '\(draft.topic)'",
                severity: "error"
            ))
        }
        
        // Difficulty validation
        if draft.difficulty.lowercased() != slot.difficulty.rawValue.lowercased() {
            errors.append(ValidationError(
                category: .content,
                field: "difficulty",
                message: "Difficulty mismatch: expected '\(slot.difficulty.rawValue)', got '\(draft.difficulty)'",
                severity: "error"
            ))
        }
        
        // Bloom level validation
        if draft.bloomLevel.lowercased() != slot.bloomLevel.rawValue.lowercased() {
            errors.append(ValidationError(
                category: .content,
                field: "bloomLevel",
                message: "Bloom level mismatch: expected '\(slot.bloomLevel.rawValue)', got '\(draft.bloomLevel)'",
                severity: "error"
            ))
        }
        
        // Template type validation
        if draft.templateType.lowercased() != slot.templateType.rawValue.lowercased() {
            errors.append(ValidationError(
                category: .content,
                field: "templateType",
                message: "Template type mismatch: expected '\(slot.templateType.rawValue)', got '\(draft.templateType)'",
                severity: "error"
            ))
        }
        
        // Word count validation
        let wordCount = draft.prompt.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        if wordCount > slot.maxPromptWords {
            errors.append(ValidationError(
                category: .content,
                field: "prompt",
                message: "Prompt exceeds \(slot.maxPromptWords) words (got \(wordCount))",
                severity: "error"
            ))
        }
        
        // Banned phrases validation
        errors.append(contentsOf: validateBannedPhrases(text: draft.prompt, banned: slot.bannedPhrases))
        if let choices = draft.choices {
            for (index, choice) in choices.enumerated() {
                errors.append(contentsOf: validateBannedPhrases(
                    text: choice,
                    banned: slot.bannedPhrases,
                    field: "choices[\(index)]"
                ))
            }
        }
        
        // Double negative check
        errors.append(contentsOf: validateNoDoubleNegatives(text: draft.prompt))
        
        // MCQ-specific content validation
        if let choices = draft.choices {
            // Unique choices after normalization
            let normalized = choices.map { normalizeText($0) }
            let uniqueSet = Set(normalized)
            if uniqueSet.count != choices.count {
                errors.append(ValidationError(
                    category: .content,
                    field: "choices",
                    message: "Choices must be unique (found duplicates after normalization)",
                    severity: "error"
                ))
            }
            
            // Correct answer must match one choice
            if let correctIndex = draft.correctIndex {
                if correctIndex >= 0 && correctIndex < choices.count {
                    let choiceText = normalizeText(choices[correctIndex])
                    let correctText = normalizeText(draft.correctAnswer)
                    if choiceText != correctText {
                        errors.append(ValidationError(
                            category: .content,
                            field: "correctAnswer",
                            message: "Correct answer doesn't match choice at correctIndex \(correctIndex)",
                            severity: "error"
                        ))
                    }
                }
            }
        }
        
        // Rationale validation
        let rationaleWords = draft.rationale.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        if rationaleWords < 10 {
            errors.append(ValidationError(
                category: .content,
                field: "rationale",
                message: "Rationale too short (minimum 10 words, got \(rationaleWords))",
                severity: "error"
            ))
        }
        
        return errors
    }
    
    // MARK: - Distribution Validation
    
    static func validateDistribution(
        validatedQuestions: [QuestionValidated],
        blueprint: TestBlueprint
    ) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        guard !validatedQuestions.isEmpty else { return errors }
        
        // Check correct answer index distribution for MCQ
        var indexCounts: [Int: Int] = [0: 0, 1: 0, 2: 0, 3: 0]
        var mcqCount = 0
        
        for validated in validatedQuestions {
            if validated.question.format == .multipleChoice,
               let options = validated.question.options,
               let correctAnswer = options.firstIndex(of: validated.question.correctAnswer) {
                indexCounts[correctAnswer, default: 0] += 1
                mcqCount += 1
            }
        }
        
        // Check for pathological distribution (no single index > 40%)
        if mcqCount > 0 {
            for (index, count) in indexCounts {
                let percentage = Double(count) / Double(mcqCount)
                if percentage > 0.4 && mcqCount >= 5 {
                    errors.append(ValidationError(
                        category: .distribution,
                        field: "correctIndex",
                        message: "Correct index \(index) appears in \(Int(percentage * 100))% of questions (max 40%)",
                        severity: "error"
                    ))
                }
            }
        }
        
        // Check topic distribution tolerance (±20%)
        var actualTopicCounts: [String: Int] = [:]
        for validated in validatedQuestions {
            let slotId = validated.slotId
            if let slot = blueprint.slots.first(where: { $0.id == slotId }) {
                actualTopicCounts[slot.topic, default: 0] += 1
            }
        }
        
        for (topic, expectedCount) in blueprint.topicQuotas {
            let actualCount = actualTopicCounts[topic] ?? 0
            let tolerance = max(1, Int(Double(expectedCount) * 0.2))
            let minCount = expectedCount - tolerance
            let maxCount = expectedCount + tolerance
            
            if actualCount < minCount || actualCount > maxCount {
                errors.append(ValidationError(
                    category: .distribution,
                    field: "topicQuotas",
                    message: "Topic '\(topic)' count \(actualCount) outside tolerance [\(minCount)-\(maxCount)]",
                    severity: "warning"
                ))
            }
        }
        
        return errors
    }
    
    // MARK: - Duplicate Detection
    
    static func validateNoDuplicate(
        draft: QuestionDraft,
        existingHashes: Set<String>
    ) -> [ValidationError] {
        let hash = hashPrompt(draft.prompt)
        
        if existingHashes.contains(hash) {
            return [ValidationError(
                category: .duplicate,
                field: "prompt",
                message: "Question prompt is a duplicate (hash: \(hash))",
                severity: "error"
            )]
        }
        
        return []
    }
    
    // MARK: - Helper Functions
    
    static func hashPrompt(_ prompt: String) -> String {
        let normalized = normalizeText(prompt)
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private static func normalizeText(_ text: String) -> String {
        return text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    private static func validateBannedPhrases(
        text: String,
        banned: [String],
        field: String = "prompt"
    ) -> [ValidationError] {
        var errors: [ValidationError] = []
        let lowerText = text.lowercased()
        
        for phrase in banned {
            if lowerText.contains(phrase.lowercased()) {
                errors.append(ValidationError(
                    category: .content,
                    field: field,
                    message: "Contains banned phrase: '\(phrase)'",
                    severity: "error"
                ))
            }
        }
        
        return errors
    }
    
    private static func validateNoDoubleNegatives(text: String) -> [ValidationError] {
        let lowerText = text.lowercased()
        let negatives = ["not", "no", "never", "neither", "nor"]
        
        var negativeCount = 0
        for negative in negatives {
            let pattern = "\\b\(negative)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)) != nil {
                negativeCount += 1
            }
        }
        
        if negativeCount >= 2 {
            return [ValidationError(
                category: .content,
                field: "prompt",
                message: "Contains double negative (found \(negativeCount) negative words)",
                severity: "warning"
            )]
        }
        
        return []
    }
}
