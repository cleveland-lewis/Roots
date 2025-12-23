import Foundation

// MARK: - AI Task Types

/// Defines the type of AI task to be performed
public enum AITaskKind: String, Codable {
    case intentToAction      // Parse user intent → structured action
    case summarize          // Summarize text
    case rewrite            // Rewrite/improve text
    case studyQuestionGen   // Generate study questions
    case textCompletion     // General completion
    case chat               // Conversational
    
    public var displayName: String {
        switch self {
        case .intentToAction:
            return "Intent Parsing"
        case .summarize:
            return "Summarization"
        case .rewrite:
            return "Text Rewriting"
        case .studyQuestionGen:
            return "Study Questions"
        case .textCompletion:
            return "Text Completion"
        case .chat:
            return "Chat"
        }
    }
}

// MARK: - Provider Capabilities

/// Describes what a provider is capable of
public struct AICapabilities {
    public let isOffline: Bool
    public let supportsTools: Bool
    public let supportsSchema: Bool
    public let maxContextLength: Int
    public let supportedTasks: Set<AITaskKind>
    public let estimatedLatency: TimeInterval
    
    public init(
        isOffline: Bool,
        supportsTools: Bool,
        supportsSchema: Bool,
        maxContextLength: Int,
        supportedTasks: Set<AITaskKind>,
        estimatedLatency: TimeInterval
    ) {
        self.isOffline = isOffline
        self.supportsTools = supportsTools
        self.supportsSchema = supportsSchema
        self.maxContextLength = maxContextLength
        self.supportedTasks = supportedTasks
        self.estimatedLatency = estimatedLatency
    }
}

// MARK: - AI Result

/// Result from an AI generation request
public struct AIResult {
    public let text: String
    public let provider: String
    public let latencyMs: Int
    public let tokenCount: Int?
    public let cached: Bool
    public let structuredData: [String: Any]?
    
    public init(
        text: String,
        provider: String,
        latencyMs: Int,
        tokenCount: Int? = nil,
        cached: Bool = false,
        structuredData: [String: Any]? = nil
    ) {
        self.text = text
        self.provider = provider
        self.latencyMs = latencyMs
        self.tokenCount = tokenCount
        self.cached = cached
        self.structuredData = structuredData
    }
}

// MARK: - AI Provider Protocol

/// Protocol that all AI providers must implement
public protocol AIProvider {
    var name: String { get }
    var capabilities: AICapabilities { get }
    
    /// Generate completion for given prompt
    func generate(
        prompt: String,
        task: AITaskKind,
        schema: [String: Any]?,
        temperature: Double
    ) async throws -> AIResult
    
    /// Check if provider is available/ready
    func isAvailable() async -> Bool
}

// MARK: - AI Error

/// Errors that can occur during AI operations
public enum AIError: Error, LocalizedError {
    case providerUnavailable(String)
    case providerNotConfigured(String)
    case networkRequired
    case modelNotDownloaded
    case generationFailed(String)
    case invalidSchema
    case contextTooLong(Int, Int)  // requested, max
    
    public var errorDescription: String? {
        switch self {
        case .providerUnavailable(let name):
            return "Provider '\(name)' is not available"
        case .providerNotConfigured(let name):
            return "Provider '\(name)' is not configured"
        case .networkRequired:
            return "This operation requires network access"
        case .modelNotDownloaded:
            return "Local model is not downloaded"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        case .invalidSchema:
            return "Invalid JSON schema provided"
        case .contextTooLong(let requested, let max):
            return "Context length \(requested) exceeds maximum \(max)"
        }
    }
}
