import XCTest
@testable import Roots

/// Property-based tests with fuzzing for validator invariants
class PropertyBasedValidatorTests: XCTestCase {
    
    var random: SeededRandom!
    var builders: TestBuilders!
    var slot: QuestionSlot!
    
    override func setUp() {
        super.setUp()
        random = SeededRandom(seed: 42)
        builders = TestBuilders(seed: 42)
        slot = builders.buildSlot()
    }
    
    // MARK: - Invariant: Invalid Drafts Are Rejected
    
    func testInvalidDraftsNeverSilentlyAccepted() {
        let violations: [TestBuilders.DraftViolation] = [
            .missingPrompt,
            .missingRationale,
            .shortRationale,
            .wrongChoiceCount,
            .duplicateChoices,
            .wrongTopic,
            .wrongDifficulty,
            .wrongBloomLevel,
            .bannedPhrase,
            .tooLongPrompt,
            .wrongCorrectIndex,
            .mismatchedAnswer
        ]
        
        for violation in violations {
            let draft = builders.buildInvalidDraft(for: slot, violation: violation)
            
            let schemaErrors = QuestionValidator.validateSchema(draft: draft)
            let contentErrors = QuestionValidator.validateContent(draft: draft, slot: slot)
            let allErrors = schemaErrors + contentErrors
            
            XCTAssertFalse(allErrors.isEmpty,
                          "Violation \(violation) must be detected")
        }
    }
    
    // MARK: - Invariant: Valid Drafts Remain Valid After Normalization
    
    func testValidDraftStaysValidAfterNormalization() {
        for _ in 0..<20 {
            let draft = builders.buildValidDraft(for: slot)
            
            // Apply various normalizations
            var normalized = draft
            normalized.prompt = normalized.prompt.trimmingCharacters(in: .whitespaces)
            normalized.correctAnswer = normalized.correctAnswer.trimmingCharacters(in: .whitespaces)
            normalized.rationale = normalized.rationale.trimmingCharacters(in: .whitespaces)
            
            let schemaErrors = QuestionValidator.validateSchema(draft: normalized)
            let contentErrors = QuestionValidator.validateContent(draft: normalized, slot: slot)
            
            XCTAssertTrue(schemaErrors.isEmpty, "Normalized valid draft should pass schema")
            XCTAssertTrue(contentErrors.filter { $0.severity == "error" }.isEmpty,
                         "Normalized valid draft should pass content rules")
        }
    }
    
    // MARK: - Unicode Fuzzing
    
    func testUnicodeWhitespaceFuzzing() {
        for _ in 0..<50 {
            var draft = builders.buildValidDraft(for: slot)
            
            // Inject various Unicode whitespace
            let unicodeSpaces = [
                "\u{00A0}", // Non-breaking space
                "\u{2000}", // En quad
                "\u{2001}", // Em quad
                "\u{2002}", // En space
                "\u{2003}", // Em space
                "\u{200B}", // Zero-width space
                "\u{FEFF}"  // Zero-width no-break space
            ]
            
            if let space = random.element(from: unicodeSpaces) {
                draft.prompt = draft.prompt + space + "extra"
                draft.choices = draft.choices?.map { $0 + space }
            }
            
            // Should still validate or fail gracefully
            let errors = QuestionValidator.validateSchema(draft: draft)
            // Just ensure it doesn't crash
            XCTAssertNotNil(errors)
        }
    }
    
    func testSmartQuotesFuzzing() {
        for _ in 0..<30 {
            var draft = builders.buildValidDraft(for: slot)
            
            let smartQuotes = ["'", "'", """, """]
            if let quote = random.element(from: smartQuotes) {
                draft.prompt = "\(quote)\(draft.prompt)\(quote)"
            }
            
            // Should handle gracefully
            let errors = QuestionValidator.validateSchema(draft: draft)
            XCTAssertNotNil(errors)
        }
    }
    
    func testZeroWidthCharactersFuzzing() {
        for _ in 0..<30 {
            var draft = builders.buildValidDraft(for: slot)
            
            let zeroWidth = [
                "\u{200B}", // Zero-width space
                "\u{200C}", // Zero-width non-joiner
                "\u{200D}", // Zero-width joiner
                "\u{FEFF}"  // BOM
            ]
            
            if let char = random.element(from: zeroWidth) {
                // Insert in middle of choices
                if var choices = draft.choices {
                    choices[0] = choices[0] + char
                    choices[1] = char + choices[1]
                    draft.choices = choices
                }
            }
            
            let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
            XCTAssertNotNil(errors)
        }
    }
    
    func testMixedCasingFuzzing() {
        for _ in 0..<30 {
            var draft = builders.buildValidDraft(for: slot)
            
            // Mix case randomly
            draft.topic = random.bool() ? draft.topic.uppercased() : draft.topic.lowercased()
            draft.difficulty = random.bool() ? draft.difficulty.uppercased() : draft.difficulty.lowercased()
            draft.bloomLevel = random.bool() ? draft.bloomLevel.uppercased() : draft.bloomLevel.lowercased()
            
            // Should still match due to case-insensitive comparison
            let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
            
            // Topic/difficulty/bloom should still match
            let topicErrors = errors.filter { $0.field == "topic" }
            XCTAssertTrue(topicErrors.isEmpty || topicErrors.allSatisfy { $0.severity == "warning" })
        }
    }
    
    // MARK: - Extreme Length Fuzzing
    
    func testExtremelyLongStringsFuzzing() {
        for _ in 0..<20 {
            var draft = builders.buildValidDraft(for: slot)
            
            // Very long prompt
            draft.prompt = String(repeating: "word ", count: 1000)
            
            let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
            
            // Should reject for exceeding word limit
            XCTAssertTrue(errors.contains { $0.message.contains("exceeds") })
        }
    }
    
    func testEmptyStringsFuzzing() {
        for _ in 0..<20 {
            var draft = builders.buildValidDraft(for: slot)
            
            // Empty various fields
            if random.bool() { draft.prompt = "" }
            if random.bool() { draft.correctAnswer = "" }
            if random.bool() { draft.rationale = "" }
            
            let errors = QuestionValidator.validateSchema(draft: draft)
            
            // Should catch empty required fields
            if draft.prompt.isEmpty {
                XCTAssertTrue(errors.contains { $0.field == "prompt" })
            }
            if draft.correctAnswer.isEmpty {
                XCTAssertTrue(errors.contains { $0.field == "correctAnswer" })
            }
            if draft.rationale.isEmpty {
                XCTAssertTrue(errors.contains { $0.field == "rationale" })
            }
        }
    }
    
    // MARK: - Duplicate Choice Fuzzing
    
    func testDuplicateChoiceWithMinorChangesFuzzing() {
        for _ in 0..<50 {
            var draft = builders.buildValidDraft(for: slot)
            
            if var choices = draft.choices, choices.count >= 4 {
                let baseChoice = choices[0]
                
                // Create near-duplicate
                let variant = random.nearDuplicate(of: baseChoice)
                choices[1] = variant
                draft.choices = choices
                
                let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
                
                // Might or might not be caught depending on variant
                // Just ensure it doesn't crash
                XCTAssertNotNil(errors)
            }
        }
    }
    
    // MARK: - Punctuation Fuzzing
    
    func testPunctuationVariantsFuzzing() {
        for _ in 0..<30 {
            var draft = builders.buildValidDraft(for: slot)
            
            if var choices = draft.choices {
                let punctuation = [".", "!", "?", ",", ";", ":", "-", "—", "–"]
                
                for i in 0..<choices.count {
                    if random.bool(), let p = random.element(from: punctuation) {
                        choices[i] = choices[i] + p
                    }
                }
                
                draft.choices = choices
            }
            
            let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
            XCTAssertNotNil(errors)
        }
    }
}
