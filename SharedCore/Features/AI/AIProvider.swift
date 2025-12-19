import Foundation

// MARK: - AI Task Kinds

enum AITaskKind: String, Codable, CaseIterable {
    case intentToAction
    case summarize
    case rewrite
    case studyQuestionGen
    case syllabusParser
    case scheduleOptimize
}

// MARK: - AI Result

struct AIResult {
    let content: String
    let metadata: AIResultMetadata
}

struct AIResultMetadata {
    let provider: String
    let latencyMs: Int
    let tokenCount: Int?
    let model: String?
    let timestamp: Date
}

// MARK: - AI Provider Protocol

protocol AIProvider {
    var name: String { get }
    var capabilities: AICapabilities { get }
    
    func generate(prompt: String, taskKind: AITaskKind, options: AIGenerateOptions) async throws -> AIResult
}

// MARK: - AI Capabilities

struct AICapabilities {
    let offline: Bool
    let supportsTools: Bool
    let supportsSchema: Bool
    let maxContextTokens: Int
    let supportedTaskKinds: Set<AITaskKind>
}

// MARK: - Generate Options

struct AIGenerateOptions {
    let temperature: Double?
    let maxTokens: Int?
    let strictJSON: Bool
    let systemPrompt: String?
    
    nonisolated static let `default` = AIGenerateOptions(
        temperature: 0.7,
        maxTokens: nil,
        strictJSON: false,
        systemPrompt: nil
    )
}

// MARK: - AI Errors

enum AIError: LocalizedError {
    case providerUnavailable(String)
    case networkRequired
    case modelNotDownloaded
    case taskNotSupported(AITaskKind)
    case generationFailed(String)
    case invalidResponse
    case timeout
    case disabledByPrivacy
    
    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let name):
            return "AI provider '\(name)' is unavailable"
        case .networkRequired:
            return "This operation requires network access"
        case .modelNotDownloaded:
            return "Local AI model not downloaded"
        case .taskNotSupported(let kind):
            return "Task '\(kind.rawValue)' is not supported by this provider"
        case .generationFailed(let reason):
            return "AI generation failed: \(reason)"
        case .invalidResponse:
            return "Received invalid response from AI provider"
        case .timeout:
            return "AI request timed out"
        case .disabledByPrivacy:
            return "AI features are disabled in Privacy settings"
        }
    }
}
