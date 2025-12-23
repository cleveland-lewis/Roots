import Foundation
import Combine

// MARK: - AI Mode

/// Defines how AI requests are routed
public enum AIMode: String, Codable, CaseIterable, Identifiable {
    case auto              // Smart routing (Apple → BYO → Local)
    case appleOnly         // Only use Apple Intelligence
    case localOnly         // Only use local models (offline)
    case byoOnly           // Only use BYO provider
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .auto:
            return "Auto (Recommended)"
        case .appleOnly:
            return "Apple Intelligence Only"
        case .localOnly:
            return "Local Only (Offline)"
        case .byoOnly:
            return "BYO Provider"
        }
    }
    
    public var description: String {
        switch self {
        case .auto:
            return "Automatically select the best available provider"
        case .appleOnly:
            return "Use only Apple Intelligence (on-device)"
        case .localOnly:
            return "Use only local models (no network access)"
        case .byoOnly:
            return "Use your configured provider"
        }
    }
}

// MARK: - Routing Event

/// Log entry for provider routing decisions
public struct RoutingEvent {
    let timestamp: Date
    let provider: String
    let task: AITaskKind
    let latencyMs: Int
    let success: Bool
    let errorMessage: String?
    
    init(provider: String, task: AITaskKind, latencyMs: Int, success: Bool, errorMessage: String? = nil) {
        self.timestamp = Date()
        self.provider = provider
        self.task = task
        self.latencyMs = latencyMs
        self.success = success
        self.errorMessage = errorMessage
    }
}

// MARK: - AI Router

/// Central router for AI requests
@MainActor
public final class AIRouter: ObservableObject {
    public static let shared = AIRouter()
    
    @Published public var mode: AIMode {
        didSet {
            saveMode()
            objectWillChange.send()
        }
    }
    
    @Published public var currentProvider: String?
    @Published public var isProcessing: Bool = false
    
    private var providers: [String: AIProvider] = [:]
    private var routingLog: [RoutingEvent] = []
    private let maxLogSize = 100
    
    private init() {
        // Load saved mode
        if let savedRaw = UserDefaults.standard.string(forKey: "aiRouterMode"),
           let saved = AIMode(rawValue: savedRaw) {
            self.mode = saved
        } else {
            self.mode = .auto
        }
        
        registerProviders()
    }
    
    /// Route a request to appropriate provider
    public func route(
        prompt: String,
        task: AITaskKind,
        schema: [String: Any]? = nil,
        requireOffline: Bool = false
    ) async throws -> AIResult {
        isProcessing = true
        defer { isProcessing = false }
        
        let startTime = Date()
        
        do {
            let provider = try await selectProvider(
                task: task,
                requireOffline: requireOffline
            )
            
            let result = try await provider.generate(
                prompt: prompt,
                task: task,
                schema: schema,
                temperature: temperatureFor(task: task)
            )
            
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            logRouting(
                provider: provider.name,
                task: task,
                latencyMs: latency,
                success: true
            )
            
            currentProvider = provider.name
            return result
            
        } catch {
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            logRouting(
                provider: currentProvider ?? "Unknown",
                task: task,
                latencyMs: latency,
                success: false,
                errorMessage: error.localizedDescription
            )
            throw error
        }
    }
    
    /// Select appropriate provider based on mode and requirements
    private func selectProvider(
        task: AITaskKind,
        requireOffline: Bool
    ) async throws -> AIProvider {
        switch mode {
        case .auto:
            return try await autoSelectProvider(task: task, requireOffline: requireOffline)
        case .appleOnly:
            guard let apple = providers["apple"] else {
                throw AIError.providerUnavailable("Apple Intelligence")
            }
            guard await apple.isAvailable() else {
                throw AIError.providerUnavailable("Apple Intelligence")
            }
            return apple
        case .localOnly:
            return try await selectLocalProvider()
        case .byoOnly:
            guard let byo = providers["byo"] else {
                throw AIError.providerNotConfigured("BYO Provider")
            }
            guard await byo.isAvailable() else {
                throw AIError.providerUnavailable("BYO Provider")
            }
            return byo
        }
    }
    
    /// Auto-select best available provider
    private func autoSelectProvider(
        task: AITaskKind,
        requireOffline: Bool
    ) async throws -> AIProvider {
        // 1. Try Apple Intelligence (if available and not offline-only)
        if !requireOffline,
           let apple = providers["apple"],
           await apple.isAvailable(),
           apple.capabilities.supportedTasks.contains(task) {
            return apple
        }
        
        // 2. Try BYO (if configured and not offline-only)
        if !requireOffline,
           let byo = providers["byo"],
           await byo.isAvailable(),
           byo.capabilities.supportedTasks.contains(task) {
            return byo
        }
        
        // 3. Fallback to local
        return try await selectLocalProvider()
    }
    
    /// Select platform-appropriate local provider
    private func selectLocalProvider() async throws -> AIProvider {
        #if os(macOS)
        guard let local = providers["local-macos"] else {
            throw AIError.providerUnavailable("Local macOS model")
        }
        #else
        guard let local = providers["local-ios"] else {
            throw AIError.providerUnavailable("Local iOS model")
        }
        #endif
        
        guard await local.isAvailable() else {
            throw AIError.modelNotDownloaded
        }
        
        return local
    }
    
    /// Get appropriate temperature for task type
    private func temperatureFor(task: AITaskKind) -> Double {
        switch task {
        case .intentToAction:
            return 0.0  // Deterministic
        case .studyQuestionGen:
            return 0.7  // Creative
        case .rewrite:
            return 0.5  // Balanced
        case .summarize:
            return 0.3  // Focused
        case .textCompletion:
            return 0.5  // Balanced
        case .chat:
            return 0.7  // Natural
        }
    }
    
    /// Log a routing decision
    private func logRouting(
        provider: String,
        task: AITaskKind,
        latencyMs: Int,
        success: Bool,
        errorMessage: String? = nil
    ) {
        let event = RoutingEvent(
            provider: provider,
            task: task,
            latencyMs: latencyMs,
            success: success,
            errorMessage: errorMessage
        )
        
        routingLog.append(event)
        
        // Trim log if too large
        if routingLog.count > maxLogSize {
            routingLog.removeFirst(routingLog.count - maxLogSize)
        }
        
        #if DEBUG
        print("🤖 AI Router: \(provider) - \(task.displayName) (\(latencyMs)ms) - \(success ? "✅" : "❌")")
        if let error = errorMessage {
            print("   Error: \(error)")
        }
        #endif
    }
    
    /// Register all available providers
    private func registerProviders() {
        // Register Apple Intelligence provider
        providers["apple"] = AppleIntelligenceProvider()
        
        // Register local providers
        #if os(macOS)
        providers["local-macos"] = LocalModelProvider_macOS()
        #else
        providers["local-ios"] = LocalModelProvider_iOS()
        #endif
        
        // BYO provider will be registered when user configures
    }
    
    /// Register BYO provider with configuration
    public func registerBYOProvider(_ provider: AIProvider) {
        providers["byo"] = provider
    }
    
    /// Remove BYO provider
    public func removeBYOProvider() {
        providers.removeValue(forKey: "byo")
    }
    
    /// Get current routing log
    public func getRoutingLog() -> [RoutingEvent] {
        return routingLog
    }
    
    /// Clear routing log
    public func clearRoutingLog() {
        routingLog.removeAll()
    }
    
    /// Save mode to UserDefaults
    private func saveMode() {
        UserDefaults.standard.set(mode.rawValue, forKey: "aiRouterMode")
    }
    
    /// Get available providers
    public func getAvailableProviders() async -> [String: Bool] {
        var availability: [String: Bool] = [:]
        
        for (key, provider) in providers {
            availability[key] = await provider.isAvailable()
        }
        
        return availability
    }
}
