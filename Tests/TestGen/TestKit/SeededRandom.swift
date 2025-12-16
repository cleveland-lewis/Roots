import Foundation

/// Deterministic random number generator for reproducible fuzz testing
class SeededRandom {
    private var seed: UInt64
    private let a: UInt64 = 6364136223846793005
    private let c: UInt64 = 1442695040888963407
    
    init(seed: UInt64 = 42) {
        self.seed = seed
    }
    
    /// Reset to initial seed
    func reset(seed: UInt64) {
        self.seed = seed
    }
    
    /// Generate next random number
    private func next() -> UInt64 {
        seed = seed &* a &+ c
        return seed
    }
    
    /// Random integer in range
    func int(in range: Range<Int>) -> Int {
        let n = UInt64(range.upperBound - range.lowerBound)
        guard n > 0 else { return range.lowerBound }
        let random = next() % n
        return range.lowerBound + Int(random)
    }
    
    /// Random integer in closed range
    func int(in range: ClosedRange<Int>) -> Int {
        return int(in: range.lowerBound..<(range.upperBound + 1))
    }
    
    /// Random double between 0 and 1
    func double() -> Double {
        return Double(next()) / Double(UInt64.max)
    }
    
    /// Random double in range
    func double(in range: Range<Double>) -> Double {
        let value = double()
        return range.lowerBound + value * (range.upperBound - range.lowerBound)
    }
    
    /// Random boolean
    func bool() -> Bool {
        return next() % 2 == 0
    }
    
    /// Random element from array
    func element<T>(from array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        let index = int(in: 0..<array.count)
        return array[index]
    }
    
    /// Shuffle array deterministically
    func shuffle<T>(_ array: [T]) -> [T] {
        var result = array
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            let j = int(in: 0...i)
            result.swapAt(i, j)
        }
        return result
    }
    
    /// Generate random string
    func string(length: Int, charset: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") -> String {
        let chars = Array(charset)
        var result = ""
        for _ in 0..<length {
            if let char = element(from: chars) {
                result.append(char)
            }
        }
        return result
    }
    
    /// Generate random topic name
    func topicName() -> String {
        let prefixes = ["Introduction to", "Advanced", "Fundamentals of", "Applied", "Theoretical"]
        let subjects = ["Biology", "Physics", "Chemistry", "Mathematics", "Psychology", "Economics"]
        
        guard let prefix = element(from: prefixes),
              let subject = element(from: subjects) else {
            return "Random Topic"
        }
        
        return "\(prefix) \(subject)"
    }
}

// MARK: - Fuzz Generators

extension SeededRandom {
    /// Generate random Unicode edge cases
    func unicodeString(length: Int) -> String {
        let edgeCases = [
            "\u{200B}", // Zero-width space
            "\u{200C}", // Zero-width non-joiner
            "\u{200D}", // Zero-width joiner
            "\u{FEFF}", // Zero-width no-break space
            "\u{202A}", // Left-to-right embedding
            "\u{202E}", // Right-to-left override
            "😀", "🎉", "🚀", // Emoji
            "'", "'", """, """, // Smart quotes
            "–", "—", // En dash, em dash
            " ", " " // Non-breaking space, thin space
        ]
        
        var result = ""
        for _ in 0..<length {
            if bool() {
                result.append(string(length: 1))
            } else if let edge = element(from: edgeCases) {
                result.append(edge)
            }
        }
        return result
    }
    
    /// Generate malformed JSON
    func malformedJSON() -> String {
        let variants = [
            "{incomplete",
            "{ \"key\": }",
            "{ \"key\": \"value\", }",
            "{ 'single': 'quotes' }",
            "{ \"key\": value }",
            "[ \"array\": \"not\", \"object\" ]",
            "{ \"nested\": { }",
            "null",
            "undefined",
            "{ \"key\": NaN }",
            "{ \"trailing\": \"comma\", }",
            "{{{",
            "{ \"unicode\": \"\u{FFFF}\" }"
        ]
        
        return element(from: variants) ?? "{}"
    }
    
    /// Generate near-duplicate text
    func nearDuplicate(of text: String) -> String {
        let variants = [
            text + " ",
            " " + text,
            text.replacingOccurrences(of: " ", with: "  "),
            text.replacingOccurrences(of: ".", with: " ."),
            text.lowercased(),
            text.uppercased(),
            text + "!",
            text.replacingOccurrences(of: "a", with: "á")
        ]
        
        return element(from: variants) ?? text
    }
}
