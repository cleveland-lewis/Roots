import XCTest
@testable import Roots

/// Tests for strict schema validation
class SchemaValidatorTests: XCTestCase {
    
    var builders: TestBuilders!
    var slot: QuestionSlot!
    
    override func setUp() {
        super.setUp()
        builders = TestBuilders(seed: 42)
        slot = builders.buildSlot()
    }
    
    // MARK: - Required Fields
    
    func testValidDraftPassesSchemaValidation() {
        let draft = builders.buildValidDraft(for: slot)
        let errors = QuestionValidator.validateSchema(draft: draft)
        
        XCTAssertTrue(errors.isEmpty, "Valid draft should pass schema validation")
    }
    
    func testEmptyPromptFails() {
        var draft = builders.buildValidDraft(for: slot)
        draft.prompt = ""
        
        let errors = QuestionValidator.validateSchema(draft: draft)
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.field == "prompt" && $0.category == .schema })
    }
    
    func testEmptyCorrectAnswerFails() {
        var draft = builders.buildValidDraft(for: slot)
        draft.correctAnswer = ""
        
        let errors = QuestionValidator.validateSchema(draft: draft)
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.field == "correctAnswer" && $0.category == .schema })
    }
    
    func testEmptyRationaleFails() {
        var draft = builders.buildValidDraft(for: slot)
        draft.rationale = ""
        
        let errors = QuestionValidator.validateSchema(draft: draft)
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.field == "rationale" && $0.category == .schema })
    }
    
    // MARK: - MCQ Structure
    
    func testMCQRequiresExactlyFourChoices() {
        var draft = builders.buildValidDraft(for: slot)
        
        // Three choices
        draft.choices = ["A", "B", "C"]
        var errors = QuestionValidator.validateSchema(draft: draft)
        XCTAssertTrue(errors.contains { $0.field == "choices" && $0.message.contains("4 choices") })
        
        // Five choices
        draft.choices = ["A", "B", "C", "D", "E"]
        errors = QuestionValidator.validateSchema(draft: draft)
        XCTAssertTrue(errors.contains { $0.field == "choices" && $0.message.contains("4 choices") })
        
        // Four choices (valid)
        draft.choices = ["A", "B", "C", "D"]
        errors = QuestionValidator.validateSchema(draft: draft)
        XCTAssertFalse(errors.contains { $0.field == "choices" })
    }
    
    func testMCQRequiresCorrectIndex() {
        var draft = builders.buildValidDraft(for: slot)
        draft.correctIndex = nil
        
        let errors = QuestionValidator.validateSchema(draft: draft)
        
        XCTAssertTrue(errors.contains {
            $0.field == "correctIndex" && $0.category == .schema
        })
    }
    
    func testCorrectIndexMustBeInRange() {
        var draft = builders.buildValidDraft(for: slot)
        
        // Index -1
        draft.correctIndex = -1
        var errors = QuestionValidator.validateSchema(draft: draft)
        XCTAssertTrue(errors.contains { $0.field == "correctIndex" && $0.message.contains("0-3") })
        
        // Index 4
        draft.correctIndex = 4
        errors = QuestionValidator.validateSchema(draft: draft)
        XCTAssertTrue(errors.contains { $0.field == "correctIndex" && $0.message.contains("0-3") })
        
        // Valid indices
        for index in 0...3 {
            draft.correctIndex = index
            draft.correctAnswer = draft.choices![index]
            errors = QuestionValidator.validateSchema(draft: draft)
            XCTAssertFalse(errors.contains { $0.field == "correctIndex" },
                          "Index \(index) should be valid")
        }
    }
    
    // MARK: - Edge Cases
    
    func testWhitespaceOnlyFieldsFail() {
        var draft = builders.buildValidDraft(for: slot)
        
        draft.prompt = "   "
        var errors = QuestionValidator.validateSchema(draft: draft)
        XCTAssertTrue(errors.contains { $0.field == "prompt" })
        
        draft.prompt = "Valid prompt"
        draft.correctAnswer = "   "
        errors = QuestionValidator.validateSchema(draft: draft)
        XCTAssertTrue(errors.contains { $0.field == "correctAnswer" })
    }
    
    func testNewlinesAndTabsInFieldsAreOK() {
        var draft = builders.buildValidDraft(for: slot)
        draft.prompt = "Line 1\nLine 2\tTabbed"
        draft.rationale = "Paragraph 1\n\nParagraph 2"
        
        let errors = QuestionValidator.validateSchema(draft: draft)
        
        // Should not fail on schema (may fail on content rules)
        XCTAssertFalse(errors.contains { $0.category == .schema })
    }
}
