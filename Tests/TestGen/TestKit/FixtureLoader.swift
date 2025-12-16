import Foundation
import XCTest

/// Model for test fixtures
struct TestFixture: Codable {
    let name: String
    let category: String
    let input: String
    let expected: ExpectedResult
    let notes: String
    
    struct ExpectedResult: Codable {
        let shouldPass: Bool
        let errorCodes: [String]?
        let errorFields: [String]?
        let severity: String? // "error", "warning"
    }
}

/// Fixture loader with caching
class FixtureLoader {
    static let shared = FixtureLoader()
    
    private var cache: [String: [TestFixture]] = [:]
    private let basePath: String
    
    init() {
        // Find Tests/Fixtures/TestGen/v1 directory
        let testBundle = Bundle(for: FixtureLoader.self)
        if let resourcePath = testBundle.resourcePath {
            basePath = resourcePath + "/Fixtures/TestGen/v1"
        } else {
            // Fallback for when running from source
            basePath = #file
                .replacingOccurrences(of: "Tests/TestGen/TestKit/FixtureLoader.swift", with: "Tests/Fixtures/TestGen/v1")
        }
    }
    
    /// Load all fixtures from a category
    func loadFixtures(category: String) throws -> [TestFixture] {
        if let cached = cache[category] {
            return cached
        }
        
        let categoryPath = "\(basePath)/\(category)"
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: categoryPath) else {
            throw FixtureError.categoryNotFound(category)
        }
        
        let files = try fileManager.contentsOfDirectory(atPath: categoryPath)
        let jsonFiles = files.filter { $0.hasSuffix(".json") }
        
        var fixtures: [TestFixture] = []
        
        for file in jsonFiles {
            let filePath = "\(categoryPath)/\(file)"
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let fixture = try JSONDecoder().decode(TestFixture.self, from: data)
            fixtures.append(fixture)
        }
        
        cache[category] = fixtures
        return fixtures
    }
    
    /// Load a specific fixture by name
    func loadFixture(category: String, name: String) throws -> TestFixture {
        let fixtures = try loadFixtures(category: category)
        guard let fixture = fixtures.first(where: { $0.name == name }) else {
            throw FixtureError.fixtureNotFound(name)
        }
        return fixture
    }
    
    /// Load all fixtures from all categories
    func loadAllFixtures() throws -> [String: [TestFixture]] {
        let categories = ["schema", "validators", "regeneration", "distribution", "unicode", "golden"]
        var allFixtures: [String: [TestFixture]] = [:]
        
        for category in categories {
            do {
                allFixtures[category] = try loadFixtures(category: category)
            } catch {
                // Category might not exist yet, skip
                continue
            }
        }
        
        return allFixtures
    }
}

enum FixtureError: Error {
    case categoryNotFound(String)
    case fixtureNotFound(String)
    case invalidJSON(String)
}

// MARK: - Fixture Builder (for creating fixtures)

struct FixtureBuilder {
    static func createFixture(
        name: String,
        category: String,
        input: String,
        shouldPass: Bool,
        errorCodes: [String]? = nil,
        errorFields: [String]? = nil,
        severity: String? = nil,
        notes: String
    ) -> TestFixture {
        return TestFixture(
            name: name,
            category: category,
            input: input,
            expected: TestFixture.ExpectedResult(
                shouldPass: shouldPass,
                errorCodes: errorCodes,
                errorFields: errorFields,
                severity: severity
            ),
            notes: notes
        )
    }
    
    /// Save fixture to disk
    static func saveFixture(_ fixture: TestFixture, to directory: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(fixture)
        
        let filename = "\(fixture.name).json"
        let path = "\(directory)/\(fixture.category)/\(filename)"
        
        try data.write(to: URL(fileURLWithPath: path))
    }
}
