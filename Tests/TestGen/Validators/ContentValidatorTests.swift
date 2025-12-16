import XCTest
@testable import Roots

/// Tests for content validation rules
class ContentValidatorTests: XCTestCase {
    
    var builders: TestBuilders!
    var slot: QuestionSlot!
    
    override func setUp() {
        super.setUp()
        builders = TestBuilders(seed: 42)
        slot = builders.buildSlot(
            topic: "Cell Biology",
            bloomLevel: .understand,
            difficulty: .medium
        )
    }
    
    // MARK: - Topic Validation
    
    func testCorrectTopicPasses() {
        let draft = builders.buildValidDraft(for: slot)
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertFalse(errors.contains { $0.field == "topic" })
    }
    
    func testWrongTopicFails() {
        var draft = builders.buildValidDraft(for: slot)
        draft.topic = "Different Topic"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains {
            $0.field == "topic" && $0.message.contains("mismatch")
        })
    }
    
    func testTopicComparisonIsCaseInsensitive() {
        var draft = builders.buildValidDraft(for: slot)
        draft.topic = "CELL BIOLOGY"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertFalse(errors.contains { $0.field == "topic" })
    }
    
    // MARK: - Difficulty Validation
    
    func testCorrectDifficultyPasses() {
        let draft = builders.buildValidDraft(for: slot)
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertFalse(errors.contains { $0.field == "difficulty" })
    }
    
    func testWrongDifficultyFails() {
        var draft = builders.buildValidDraft(for: slot)
        draft.difficulty = "Hard"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains { $0.field == "difficulty" })
    }
    
    // MARK: - Bloom Level Validation
    
    func testCorrectBloomLevelPasses() {
        let draft = builders.buildValidDraft(for: slot)
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertFalse(errors.contains { $0.field == "bloomLevel" })
    }
    
    func testWrongBloomLevelFails() {
        var draft = builders.buildValidDraft(for: slot)
        draft.bloomLevel = "Analyze"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains { $0.field == "bloomLevel" })
    }
    
    // MARK: - Prompt Word Count
    
    func testPromptWithinLimitPasses() {
        var draft = builders.buildValidDraft(for: slot)
        draft.prompt = String(repeating: "word ", count: slot.maxPromptWords - 1).trimmingCharacters(in: .whitespaces)
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertFalse(errors.contains { $0.field == "prompt" && $0.message.contains("exceeds") })
    }
    
    func testPromptExceedingLimitFails() {
        var draft = builders.buildValidDraft(for: slot)
        draft.prompt = String(repeating: "word ", count: slot.maxPromptWords + 10)
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains { $0.field == "prompt" && $0.message.contains("exceeds") })
    }
    
    // MARK: - Banned Phrases
    
    func testBannedPhrasesDetected() {
        let bannedPhrases = [
            "all of the above",
            "none of the above",
            "both a and b",
            "neither a nor b"
        ]
        
        for phrase in bannedPhrases {
            var draft = builders.buildValidDraft(for: slot)
            draft.prompt = "Which is correct? \(phrase)?"
            
            let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
            
            XCTAssertTrue(errors.contains { $0.message.contains(phrase) },
                         "Should detect banned phrase: '\(phrase)'")
        }
    }
    
    func testBannedPhrasesInChoices() {
        var draft = builders.buildValidDraft(for: slot)
        draft.choices = [
            "All of the above",
            "Option B",
            "Option C",
            "Option D"
        ]
        draft.correctIndex = 1
        draft.correctAnswer = "Option B"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains { $0.message.contains("all of the above") })
    }
    
    func testBannedPhrasesAreCaseInsensitive() {
        var draft = builders.buildValidDraft(for: slot)
        draft.prompt = "ALL OF THE ABOVE is wrong"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains { $0.message.lowercased().contains("all of the above") })
    }
    
    // MARK: - Double Negatives
    
    func testDoubleNegativeDetected() {
        var draft = builders.buildValidDraft(for: slot)
        draft.prompt = "Which is not incorrect?"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains { $0.message.contains("double negative") || $0.message.contains("negative") },
                     "Should detect double negative")
    }
    
    func testSingleNegativeIsOK() {
        var draft = builders.buildValidDraft(for: slot)
        draft.prompt = "Which is not a cell organelle?"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        // Single negative might trigger warning but not error
        let negativeErrors = errors.filter { $0.message.contains("double negative") }
        XCTAssertTrue(negativeErrors.isEmpty || negativeErrors.allSatisfy { $0.severity == "warning" })
    }
    
    // MARK: - Choice Uniqueness
    
    func testDuplicateChoicesAfterNormalizationFail() {
        var draft = builders.buildValidDraft(for: slot)
        draft.choices = [
            "Answer A",
            "answer a",  // Same after normalization
            "Answer B",
            "Answer C"
        ]
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains { $0.field == "choices" && $0.message.contains("unique") })
    }
    
    func testWhitespaceVariantsCounted AsDuplicates() {
        var draft = builders.buildValidDraft(for: slot)
        draft.choices = [
            "Answer A",
            " Answer A ",  // Same after trimming
            "Answer B",
            "Answer C"
        ]
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains { $0.message.contains("unique") || $0.message.contains("duplicate") })
    }
    
    // MARK: - Correct Answer Match
    
    func testCorrectAnswerMatchesChoice() {
        var draft = builders.buildValidDraft(for: slot)
        draft.choices = ["A", "B", "C", "D"]
        draft.correctIndex = 2
        draft.correctAnswer = "C"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertFalse(errors.contains { $0.field == "correctAnswer" })
    }
    
    func testCorrectAnswerMismatchFails() {
        var draft = builders.buildValidDraft(for: slot)
        draft.choices = ["A", "B", "C", "D"]
        draft.correctIndex = 2
        draft.correctAnswer = "Wrong"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains {
            $0.field == "correctAnswer" && $0.message.contains("match")
        })
    }
    
    // MARK: - Rationale Validation
    
    func testRationaleMinimumLength() {
        var draft = builders.buildValidDraft(for: slot)
        
        // Too short
        draft.rationale = "Too short"
        var errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        XCTAssertTrue(errors.contains { $0.field == "rationale" && $0.message.contains("short") })
        
        // Long enough (10+ words)
        draft.rationale = "This is a proper rationale with more than ten words explaining the answer"
        errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        XCTAssertFalse(errors.contains { $0.field == "rationale" && $0.message.contains("short") })
    }
    
    // MARK: - Template Type Validation
    
    func testTemplateTypeMustMatch() {
        var draft = builders.buildValidDraft(for: slot)
        draft.templateType = "wrong_template"
        
        let errors = QuestionValidator.validateContent(draft: draft, slot: slot)
        
        XCTAssertTrue(errors.contains { $0.field == "templateType" })
    }
}
