import Foundation
import Combine

// MARK: - AI Mode

enum AIMode: String, Codable, CaseIterable {
    case auto
    case appleIntelligenceOnly
    case localOnly
    case byoProvider
    
    var label: String {
        switch self {
        case .auto: return "Auto (Recommended)"
        case .appleIntelligenceOnly: return "Apple Intelligence Only"
        case .localOnly: return "Local Only (Offline)"
        case .byoProvider: return "Custom Provider"
        }
    }
}

// MARK: - AI Router

@MainActor
class AIRouter: ObservableObject {
    @Published var currentMode: AIMode
    @Published var lastUsedProvider: String?
    @Published var isAppleIntelligenceAvailable: Bool = false
    
    private var providers: [String: AIProvider] = [:]
    private let logger = AILogger.shared
    
    init(mode: AIMode = .auto) {
        self.currentMode = mode
        detectAppleIntelligenceAvailability()
    }
    
    // MARK: - Provider Registration
    
    func registerProvider(_ provider: AIProvider) {
        providers[provider.name] = provider
        LOG_AI(.info, "ProviderRegistration", "Registered AI provider", metadata: ["provider": provider.name])
    }
    
    // MARK: - Generation
    
    func generate(prompt: String, taskKind: AITaskKind, options: AIGenerateOptions = .default) async throws -> AIResult {
        let startTime = Date()
        
        let provider = try selectProvider(for: taskKind)
        logger.logProviderSelection(provider: provider.name, taskKind: taskKind, mode: currentMode)
        
        do {
            let result = try await provider.generate(prompt: prompt, taskKind: taskKind, options: options)
            lastUsedProvider = provider.name
            
            logger.logSuccess(
                provider: provider.name,
                taskKind: taskKind,
                latencyMs: result.metadata.latencyMs,
                tokenCount: result.metadata.tokenCount
            )
            
            return result
        } catch {
            logger.logError(provider: provider.name, taskKind: taskKind, error: error)
            throw error
        }
    }
    
    // MARK: - Provider Selection
    
    private func selectProvider(for taskKind: AITaskKind) throws -> AIProvider {
        switch currentMode {
        case .auto:
            return try selectAutoProvider(for: taskKind)
        case .appleIntelligenceOnly:
            return try getAppleIntelligenceProvider()
        case .localOnly:
            return try getLocalProvider()
        case .byoProvider:
            return try getBYOProvider()
        }
    }
    
    private func selectAutoProvider(for taskKind: AITaskKind) throws -> AIProvider {
        // Priority: Apple Intelligence -> Local Fallback
        if isAppleIntelligenceAvailable, let appleProvider = providers["AppleIntelligence"] {
            if appleProvider.capabilities.supportedTaskKinds.contains(taskKind) {
                return appleProvider
            }
        }
        
        // Fallback to local provider
        if let localProvider = getLocalProviderForPlatform() {
            if localProvider.capabilities.supportedTaskKinds.contains(taskKind) {
                return localProvider
            }
        }
        
        throw AIError.providerUnavailable("No suitable provider found for task \(taskKind)")
    }
    
    private func getAppleIntelligenceProvider() throws -> AIProvider {
        guard let provider = providers["AppleIntelligence"] else {
            throw AIError.providerUnavailable("Apple Intelligence is not available")
        }
        return provider
    }
    
    private func getLocalProvider() throws -> AIProvider {
        guard let provider = getLocalProviderForPlatform() else {
            throw AIError.providerUnavailable("Local provider is not available")
        }
        return provider
    }
    
    private func getBYOProvider() throws -> AIProvider {
        guard let provider = providers["BYO"] else {
            throw AIError.providerUnavailable("Custom provider not configured")
        }
        return provider
    }
    
    private func getLocalProviderForPlatform() -> AIProvider? {
        #if os(macOS)
        return providers["LocalMacOS"]
        #elseif os(iOS) || os(visionOS)
        return providers["LocaliOS"]
        #else
        return nil
        #endif
    }
    
    // MARK: - Availability Detection
    
    private func detectAppleIntelligenceAvailability() {
        #if os(iOS) || os(macOS) || os(visionOS)
        if #available(iOS 18.0, macOS 15.0, *) {
            // Check if Apple Intelligence/Foundation Models are available
            // This is a placeholder - actual implementation would check system capabilities
            isAppleIntelligenceAvailable = false // Will be implemented when Apple releases APIs
        }
        #endif
    }
    
    // MARK: - Status
    
    func getAvailableProviders() -> [String] {
        return Array(providers.keys)
    }
    
    func getProviderCapabilities(_ providerName: String) -> AICapabilities? {
        return providers[providerName]?.capabilities
    }
}

// MARK: - AI Logger

class AILogger {
    static let shared = AILogger()
    
    private init() {}
    
    func logProviderSelection(provider: String, taskKind: AITaskKind, mode: AIMode) {
        LOG_AI(.info, "ProviderSelection", "Selected AI provider", metadata: [
            "provider": provider,
            "taskKind": taskKind.rawValue,
            "mode": mode.rawValue
        ])
    }
    
    func logSuccess(provider: String, taskKind: AITaskKind, latencyMs: Int, tokenCount: Int?) {
        var metadata: [String: String] = [
            "provider": provider,
            "taskKind": taskKind.rawValue,
            "latencyMs": "\(latencyMs)"
        ]
        if let tokens = tokenCount {
            metadata["tokenCount"] = "\(tokens)"
        }
        LOG_AI(.info, "GenerationSuccess", "AI generation completed", metadata: metadata)
    }
    
    func logError(provider: String, taskKind: AITaskKind, error: Error) {
        LOG_AI(.error, "GenerationError", "AI generation failed", metadata: [
            "provider": provider,
            "taskKind": taskKind.rawValue,
            "error": error.localizedDescription
        ])
    }
}
