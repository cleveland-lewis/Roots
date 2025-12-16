import XCTest
@testable import Roots

/// Tests that run against the fixture corpus
class FixtureBasedTests: XCTestCase {
    
    var builders: TestBuilders!
    
    override func setUp() {
        super.setUp()
        builders = TestBuilders(seed: 42)
    }
    
    // MARK: - Schema Fixtures
    
    func testSchemaFixtures() {
        let fixtures = schemaFixtures()
        
        for fixture in fixtures {
            let data = fixture.input.data(using: .utf8)!
            
            do {
                let decoded = try JSONDecoder().decode(QuestionDraft.self, from: data)
                
                if fixture.expected.shouldPass {
                    XCTAssertTrue(true, "\(fixture.name): Passed as expected")
                } else {
                    XCTFail("\(fixture.name): Should have failed but passed. Got: \(decoded)")
                }
            } catch {
                if fixture.expected.shouldPass {
                    XCTFail("\(fixture.name): Should have passed but failed with: \(error)")
                } else {
                    XCTAssertTrue(true, "\(fixture.name): Failed as expected")
                }
            }
        }
    }
    
    // MARK: - Validator Fixtures
    
    func testValidatorFixtures() {
        let fixtures = validatorFixtures()
        
        for fixture in fixtures {
            guard let data = fixture.input.data(using: .utf8),
                  let draft = try? JSONDecoder().decode(QuestionDraft.self, from: data) else {
                if !fixture.expected.shouldPass {
                    continue
                }
                XCTFail("\(fixture.name): Failed to parse valid JSON")
                continue
            }
            
            let slot = builders.buildSlot(
                topic: draft.topic,
                bloomLevel: BloomLevel(rawValue: draft.bloomLevel) ?? .understand,
                difficulty: PracticeTestDifficulty(rawValue: draft.difficulty) ?? .medium
            )
            
            let schemaErrors = QuestionValidator.validateSchema(draft: draft)
            let contentErrors = QuestionValidator.validateContent(draft: draft, slot: slot)
            let allErrors = schemaErrors + contentErrors
            
            let hasErrors = !allErrors.filter { $0.severity == "error" }.isEmpty
            
            if fixture.expected.shouldPass {
                XCTAssertFalse(hasErrors, "\(fixture.name): Should pass but has errors: \(allErrors)")
            } else {
                XCTAssertTrue(hasErrors, "\(fixture.name): Should fail but passed")
            }
        }
    }
    
    // MARK: - Unicode Fixtures
    
    func testUnicodeFixtures() {
        let fixtures = unicodeFixtures()
        
        for fixture in fixtures {
            guard let data = fixture.input.data(using: .utf8),
                  let draft = try? JSONDecoder().decode(QuestionDraft.self, from: data) else {
                if !fixture.expected.shouldPass {
                    continue
                }
                XCTFail("\(fixture.name): Failed to parse")
                continue
            }
            
            let errors = QuestionValidator.validateSchema(draft: draft)
            XCTAssertNotNil(errors, "\(fixture.name): Should not crash")
        }
    }
    
    // MARK: - Golden Fixtures
    
    func testGoldenFixtures() {
        let fixtures = goldenFixtures()
        
        for fixture in fixtures {
            guard let data = fixture.input.data(using: .utf8),
                  let draft = try? JSONDecoder().decode(QuestionDraft.self, from: data) else {
                XCTFail("\(fixture.name): Golden fixture must parse")
                continue
            }
            
            let slot = builders.buildSlot(
                topic: draft.topic,
                bloomLevel: BloomLevel(rawValue: draft.bloomLevel) ?? .understand,
                difficulty: PracticeTestDifficulty(rawValue: draft.difficulty) ?? .medium
            )
            
            let schemaErrors = QuestionValidator.validateSchema(draft: draft)
            let contentErrors = QuestionValidator.validateContent(draft: draft, slot: slot)
            let allErrors = schemaErrors + contentErrors
            
            let criticalErrors = allErrors.filter { $0.severity == "error" }
            
            XCTAssertTrue(criticalErrors.isEmpty,
                         "\(fixture.name): Golden fixture must pass. Errors: \(criticalErrors)")
        }
    }
    
    // MARK: - Hardcoded Fixtures
    
    private func schemaFixtures() -> [TestFixture] {
        return [
            FixtureBuilder.createFixture(
                name: "non_json_text",
                category: "schema",
                input: "This is not JSON",
                shouldPass: false,
                errorCodes: ["INVALID_JSON"],
                notes: "Plain text should be rejected"
            ),
            
            FixtureBuilder.createFixture(
                name: "empty_json",
                category: "schema",
                input: "{}",
                shouldPass: false,
                errorCodes: ["MISSING_FIELD"],
                notes: "Empty object missing all required fields"
            ),
            
            FixtureBuilder.createFixture(
                name: "missing_prompt",
                category: "schema",
                input: """
                {
                    "choices": ["A", "B", "C", "D"],
                    "correctAnswer": "A",
                    "correctIndex": 0,
                    "rationale": "This is correct",
                    "topic": "Biology",
                    "bloomLevel": "Remember",
                    "difficulty": "Easy",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: false,
                errorCodes: ["MISSING_FIELD"],
                errorFields: ["prompt"],
                notes: "Missing required prompt field"
            ),
            
            FixtureBuilder.createFixture(
                name: "wrong_type_choices",
                category: "schema",
                input: """
                {
                    "prompt": "What is DNA?",
                    "choices": "A, B, C, D",
                    "correctAnswer": "A",
                    "correctIndex": 0,
                    "rationale": "Genetic material",
                    "topic": "Biology",
                    "bloomLevel": "Remember",
                    "difficulty": "Easy",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: false,
                errorCodes: ["INVALID_TYPE"],
                errorFields: ["choices"],
                notes: "choices should be array not string"
            )
        ]
    }
    
    private func validatorFixtures() -> [TestFixture] {
        return [
            FixtureBuilder.createFixture(
                name: "all_of_the_above",
                category: "validators",
                input: """
                {
                    "prompt": "Which is true?",
                    "choices": ["A is true", "B is true", "C is true", "All of the above"],
                    "correctAnswer": "All of the above",
                    "correctIndex": 3,
                    "rationale": "All statements are correct and this explains why",
                    "topic": "Test Topic",
                    "bloomLevel": "Understand",
                    "difficulty": "Medium",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: false,
                errorCodes: ["BANNED_PHRASE"],
                notes: "'All of the above' is banned"
            ),
            
            FixtureBuilder.createFixture(
                name: "three_choices",
                category: "validators",
                input: """
                {
                    "prompt": "What is mitosis?",
                    "choices": ["Cell division", "Cell growth", "Cell death"],
                    "correctAnswer": "Cell division",
                    "correctIndex": 0,
                    "rationale": "Mitosis is the process of cell division in organisms",
                    "topic": "Biology",
                    "bloomLevel": "Remember",
                    "difficulty": "Easy",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: false,
                errorCodes: ["INVALID_CHOICE_COUNT"],
                notes: "Must have exactly 4 choices"
            ),
            
            FixtureBuilder.createFixture(
                name: "duplicate_choices",
                category: "validators",
                input: """
                {
                    "prompt": "What is DNA?",
                    "choices": ["Genetic material", "genetic material", "RNA", "Protein"],
                    "correctAnswer": "Genetic material",
                    "correctIndex": 0,
                    "rationale": "DNA stores genetic information in all living cells",
                    "topic": "Biology",
                    "bloomLevel": "Remember",
                    "difficulty": "Easy",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: false,
                errorCodes: ["DUPLICATE_CHOICE"],
                notes: "Choices must be unique after normalization"
            ),
            
            FixtureBuilder.createFixture(
                name: "correct_index_out_of_bounds",
                category: "validators",
                input: """
                {
                    "prompt": "What is a cell?",
                    "choices": ["Basic unit", "Molecule", "Atom", "Tissue"],
                    "correctAnswer": "Basic unit",
                    "correctIndex": 5,
                    "rationale": "Cells are the basic structural units of life",
                    "topic": "Biology",
                    "bloomLevel": "Remember",
                    "difficulty": "Easy",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: false,
                errorCodes: ["INDEX_OUT_OF_BOUNDS"],
                notes: "correctIndex must be 0-3"
            )
        ]
    }
    
    private func unicodeFixtures() -> [TestFixture] {
        return [
            FixtureBuilder.createFixture(
                name: "zero_width_space",
                category: "unicode",
                input: """
                {
                    "prompt": "What is\u{200B}DNA?",
                    "choices": ["Genetic\u{200B}material", "Protein", "Lipid", "Carb"],
                    "correctAnswer": "Genetic\u{200B}material",
                    "correctIndex": 0,
                    "rationale": "DNA stores genetic information in cells of organisms",
                    "topic": "Biology",
                    "bloomLevel": "Remember",
                    "difficulty": "Easy",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: true,
                notes: "Zero-width space should be handled gracefully"
            ),
            
            FixtureBuilder.createFixture(
                name: "smart_quotes",
                category: "unicode",
                input: """
                {
                    "prompt": "What is "DNA"?",
                    "choices": ["Genetic 'material'", "Protein", "Lipid", "Carb"],
                    "correctAnswer": "Genetic 'material'",
                    "correctIndex": 0,
                    "rationale": "DNA stores genetic information in living cells of all organisms",
                    "topic": "Biology",
                    "bloomLevel": "Remember",
                    "difficulty": "Easy",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: true,
                notes: "Smart quotes should be accepted"
            )
        ]
    }
    
    private func goldenFixtures() -> [TestFixture] {
        return [
            FixtureBuilder.createFixture(
                name: "golden_bio_mitosis",
                category: "golden",
                input: """
                {
                    "prompt": "What is the primary function of mitosis in multicellular organisms?",
                    "choices": [
                        "Growth and repair of tissues",
                        "Production of sex cells",
                        "Energy production in cells",
                        "Protein synthesis"
                    ],
                    "correctAnswer": "Growth and repair of tissues",
                    "correctIndex": 0,
                    "rationale": "Mitosis is the process of cell division that produces two identical daughter cells. In multicellular organisms, this process is essential for growth and tissue repair. Sex cells are produced through meiosis, not mitosis.",
                    "topic": "Cell Biology",
                    "bloomLevel": "Understand",
                    "difficulty": "Medium",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: true,
                notes: "Golden fixture: valid mitosis question"
            ),
            
            FixtureBuilder.createFixture(
                name: "golden_bio_photosynthesis",
                category: "golden",
                input: """
                {
                    "prompt": "Which of the following is the correct chemical equation for photosynthesis?",
                    "choices": [
                        "6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂",
                        "C₆H₁₂O₆ + 6O₂ → 6CO₂ + 6H₂O",
                        "CO₂ + H₂O → CH₂O + O₂",
                        "C₆H₁₂O₆ → 2C₂H₅OH + 2CO₂"
                    ],
                    "correctAnswer": "6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂",
                    "correctIndex": 0,
                    "rationale": "This is the balanced chemical equation for photosynthesis, where carbon dioxide and water are converted into glucose and oxygen using light energy. The second option represents cellular respiration (the reverse process), and the other options are incorrect or represent different processes.",
                    "topic": "Plant Biology",
                    "bloomLevel": "Remember",
                    "difficulty": "Medium",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: true,
                notes: "Golden fixture: valid photosynthesis question with proper formatting"
            ),
            
            FixtureBuilder.createFixture(
                name: "golden_bio_dna_structure",
                category: "golden",
                input: """
                {
                    "prompt": "What type of bond holds the two strands of DNA together?",
                    "choices": [
                        "Hydrogen bonds",
                        "Covalent bonds",
                        "Ionic bonds",
                        "Disulfide bridges"
                    ],
                    "correctAnswer": "Hydrogen bonds",
                    "correctIndex": 0,
                    "rationale": "The two strands of the DNA double helix are held together by hydrogen bonds between complementary base pairs. Adenine pairs with thymine via two hydrogen bonds, while guanine pairs with cytosine via three hydrogen bonds. These bonds are relatively weak, allowing the strands to separate during replication and transcription.",
                    "topic": "Molecular Biology",
                    "bloomLevel": "Remember",
                    "difficulty": "Easy",
                    "templateType": "concept_id"
                }
                """,
                shouldPass: true,
                notes: "Golden fixture: valid DNA structure question"
            )
        ]
    }
}
