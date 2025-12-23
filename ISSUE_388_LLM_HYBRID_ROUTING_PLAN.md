# Issue #388: Hybrid LLM Routing Architecture - Implementation Plan

**Date**: December 23, 2025  
**Status**: 📋 Planning Phase  
**Complexity**: High (Multi-week implementation)

---

## Overview

Implement a sophisticated hybrid AI architecture for Roots that uses Apple Intelligence as primary, allows optional BYO providers, and provides platform-optimized local fallbacks with explicit routing and privacy guarantees.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   AI Router                         │
│  • Selects provider per request                    │
│  • Enforces user preferences                        │
│  • Logs provider usage                              │
└────────────┬────────────────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
┌───▼────────┐  ┌────▼──────────┐  ┌──────────────┐
│  Primary   │  │   Optional    │  │   Fallback   │
│            │  │               │  │              │
│   Apple    │  │     BYO       │  │    Local     │
│Intelligence│  │   Provider    │  │   Models     │
│            │  │               │  │              │
│ (On-device)│  │ (User config) │  │  (Offline)   │
└────────────┘  └───────────────┘  └──────┬───────┘
                                          │
                                   ┌──────┴───────┐
                                   │              │
                            ┌──────▼─────┐  ┌────▼──────┐
                            │    macOS    │  │iOS/iPadOS │
                            │  Standard   │  │   Lite    │
                            │   Model     │  │  Model    │
                            └─────────────┘  └───────────┘
```

---

## Phase 1: Core Architecture (Week 1)

### A) Provider Protocol & Types

**File**: `Sources/Shared/AI/AIProvider.swift`

```swift
// MARK: - AI Task Types

public enum AITaskKind {
    case intentToAction      // Parse user intent → structured action
    case summarize          // Summarize text
    case rewrite            // Rewrite/improve text
    case studyQuestionGen   // Generate study questions
    case textCompletion     // General completion
    case chat               // Conversational
}

// MARK: - Provider Capabilities

public struct AICapabilities {
    let isOffline: Bool
    let supportsTools: Bool
    let supportsSchema: Bool
    let maxContextLength: Int
    let supportedTasks: Set<AITaskKind>
    let estimatedLatency: TimeInterval  // Rough estimate
}

// MARK: - AI Result

public struct AIResult {
    let text: String
    let provider: String
    let latencyMs: Int
    let tokenCount: Int?
    let cached: Bool
    
    // For structured outputs
    let structuredData: [String: Any]?
}

// MARK: - AI Provider Protocol

public protocol AIProvider {
    var name: String { get }
    var capabilities: AICapabilities { get }
    
    /// Generate completion for given prompt
    func generate(
        prompt: String,
        task: AITaskKind,
        schema: [String: Any]?,  // JSON schema for structured output
        temperature: Double
    ) async throws -> AIResult
    
    /// Check if provider is available/ready
    func isAvailable() async -> Bool
}
```

---

### B) AI Router

**File**: `Sources/Shared/AI/AIRouter.swift`

```swift
// MARK: - AI Mode

public enum AIMode: String, Codable {
    case auto              // Smart routing (Apple → BYO → Local)
    case appleOnly         // Only use Apple Intelligence
    case localOnly         // Only use local models (offline)
    case byoOnly           // Only use BYO provider
}

// MARK: - AI Router

@MainActor
public final class AIRouter: ObservableObject {
    public static let shared = AIRouter()
    
    @Published public var mode: AIMode
    @Published public var currentProvider: String?
    
    private var providers: [String: AIProvider] = [:]
    private var routingLog: [RoutingEvent] = []
    
    public init() {
        self.mode = .auto
        registerProviders()
    }
    
    /// Route a request to appropriate provider
    public func route(
        prompt: String,
        task: AITaskKind,
        schema: [String: Any]? = nil,
        requireOffline: Bool = false
    ) async throws -> AIResult {
        let provider = try await selectProvider(
            task: task,
            requireOffline: requireOffline
        )
        
        logRouting(provider: provider.name, task: task)
        
        let result = try await provider.generate(
            prompt: prompt,
            task: task,
            schema: schema,
            temperature: temperatureFor(task: task)
        )
        
        currentProvider = provider.name
        return result
    }
    
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
            return apple
        case .localOnly:
            return try await selectLocalProvider()
        case .byoOnly:
            guard let byo = providers["byo"] else {
                throw AIError.providerNotConfigured("BYO")
            }
            return byo
        }
    }
    
    private func autoSelectProvider(
        task: AITaskKind,
        requireOffline: Bool
    ) async throws -> AIProvider {
        // 1. Try Apple Intelligence (if available and not offline-only)
        if !requireOffline,
           let apple = providers["apple"],
           await apple.isAvailable() {
            return apple
        }
        
        // 2. Try BYO (if configured and not offline-only)
        if !requireOffline,
           let byo = providers["byo"],
           await byo.isAvailable() {
            return byo
        }
        
        // 3. Fallback to local
        return try await selectLocalProvider()
    }
    
    private func selectLocalProvider() async throws -> AIProvider {
        #if os(macOS)
        guard let local = providers["local-macos"] else {
            throw AIError.providerUnavailable("Local macOS")
        }
        return local
        #else
        guard let local = providers["local-ios"] else {
            throw AIError.providerUnavailable("Local iOS")
        }
        return local
        #endif
    }
    
    private func temperatureFor(task: AITaskKind) -> Double {
        switch task {
        case .intentToAction:
            return 0.0  // Deterministic
        case .studyQuestionGen:
            return 0.7  // Creative
        case .rewrite:
            return 0.5  // Balanced
        default:
            return 0.3
        }
    }
    
    private func registerProviders() {
        // Register all available providers
        providers["apple"] = AppleIntelligenceProvider()
        providers["local-macos"] = LocalModelProvider_macOS()
        providers["local-ios"] = LocalModelProvider_iOS()
        // BYO registered when user configures
    }
}

// MARK: - Routing Event

private struct RoutingEvent {
    let timestamp: Date
    let provider: String
    let task: AITaskKind
    let latencyMs: Int
    let success: Bool
}

// MARK: - AI Error

public enum AIError: Error {
    case providerUnavailable(String)
    case providerNotConfigured(String)
    case networkRequired
    case modelNotDownloaded
    case generationFailed(String)
}
```

---

## Phase 2: Provider Implementations (Week 2)

### A) Apple Intelligence Provider

**File**: `Sources/Shared/AI/Providers/AppleIntelligenceProvider.swift`

```swift
import Foundation

#if canImport(AppleIntelligence)
import AppleIntelligence
#endif

public final class AppleIntelligenceProvider: AIProvider {
    public let name = "Apple Intelligence"
    
    public var capabilities: AICapabilities {
        AICapabilities(
            isOffline: true,  // On-device
            supportsTools: true,
            supportsSchema: true,
            maxContextLength: 8192,
            supportedTasks: [
                .intentToAction,
                .summarize,
                .rewrite,
                .textCompletion,
                .chat
            ],
            estimatedLatency: 0.5
        )
    }
    
    public func generate(
        prompt: String,
        task: AITaskKind,
        schema: [String: Any]?,
        temperature: Double
    ) async throws -> AIResult {
        #if canImport(AppleIntelligence)
        // TODO: Actual Apple Intelligence SDK integration
        // This is a placeholder for when SDK is available
        
        let startTime = Date()
        
        // Use Apple's Foundation Models
        let response = try await callAppleIntelligence(
            prompt: prompt,
            schema: schema,
            temperature: temperature
        )
        
        let latency = Int(Date().timeIntervalSince(startTime) * 1000)
        
        return AIResult(
            text: response.text,
            provider: name,
            latencyMs: latency,
            tokenCount: response.tokenCount,
            cached: response.cached,
            structuredData: response.structuredData
        )
        #else
        throw AIError.providerUnavailable("Apple Intelligence not available on this platform")
        #endif
    }
    
    public func isAvailable() async -> Bool {
        #if canImport(AppleIntelligence)
        // Check if Apple Intelligence is enabled and available
        return await AppleIntelligence.isAvailable()
        #else
        return false
        #endif
    }
}
```

---

### B) Local Model Providers

**File**: `Sources/Shared/AI/Providers/LocalModelProvider_macOS.swift`

```swift
import Foundation

#if os(macOS)
import MLCore  // Or whatever ML framework is used

public final class LocalModelProvider_macOS: AIProvider {
    public let name = "Local Model (macOS Standard)"
    
    public var capabilities: AICapabilities {
        AICapabilities(
            isOffline: true,
            supportsTools: false,
            supportsSchema: true,
            maxContextLength: 4096,
            supportedTasks: [
                .intentToAction,
                .summarize,
                .rewrite,
                .studyQuestionGen
            ],
            estimatedLatency: 1.5
        )
    }
    
    private var model: MLModel?
    
    public init() {
        // Model will be loaded lazily
    }
    
    public func generate(
        prompt: String,
        task: AITaskKind,
        schema: [String: Any]?,
        temperature: Double
    ) async throws -> AIResult {
        // Ensure model is loaded
        if model == nil {
            try await loadModel()
        }
        
        guard let model = model else {
            throw AIError.modelNotDownloaded
        }
        
        let startTime = Date()
        
        // Run inference
        let response = try await runInference(
            model: model,
            prompt: prompt,
            schema: schema,
            temperature: temperature
        )
        
        let latency = Int(Date().timeIntervalSince(startTime) * 1000)
        
        return AIResult(
            text: response,
            provider: name,
            latencyMs: latency,
            tokenCount: nil,
            cached: false,
            structuredData: nil
        )
    }
    
    public func isAvailable() async -> Bool {
        // Check if model is downloaded
        return LocalModelManager.shared.isModelDownloaded(.macOSStandard)
    }
    
    private func loadModel() async throws {
        let modelURL = try await LocalModelManager.shared.getModelURL(.macOSStandard)
        // Load CoreML model
        // self.model = try MLModel(contentsOf: modelURL)
    }
    
    private func runInference(
        model: MLModel,
        prompt: String,
        schema: [String: Any]?,
        temperature: Double
    ) async throws -> String {
        // Actual inference logic
        // This would use CoreML or other ML framework
        return "Generated response"
    }
}
#endif
```

**File**: `Sources/Shared/AI/Providers/LocalModelProvider_iOS.swift`

```swift
// Similar structure but optimized for iOS
// Smaller model, lower resource usage
// Target: ~100-200MB vs ~500MB-1GB for macOS
```

---

### C) BYO Provider

**File**: `Sources/Shared/AI/Providers/BYOProvider.swift`

```swift
import Foundation

public enum BYOProviderType: String, Codable {
    case openai
    case anthropic
    case custom
}

public final class BYOProvider: AIProvider {
    public let name: String
    private let type: BYOProviderType
    private let apiKey: String
    private let endpoint: String?
    
    public var capabilities: AICapabilities {
        AICapabilities(
            isOffline: false,  // Network required
            supportsTools: true,
            supportsSchema: true,
            maxContextLength: 100000,  // Depends on provider
            supportedTasks: Set(AITaskKind.allCases),
            estimatedLatency: 2.0  // Network latency
        )
    }
    
    public init(type: BYOProviderType, apiKey: String, endpoint: String? = nil) {
        self.type = type
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.name = "BYO (\(type.rawValue))"
    }
    
    public func generate(
        prompt: String,
        task: AITaskKind,
        schema: [String: Any]?,
        temperature: Double
    ) async throws -> AIResult {
        let startTime = Date()
        
        // Make API call to BYO provider
        let response = try await callProvider(
            prompt: prompt,
            schema: schema,
            temperature: temperature
        )
        
        let latency = Int(Date().timeIntervalSince(startTime) * 1000)
        
        return AIResult(
            text: response.text,
            provider: name,
            latencyMs: latency,
            tokenCount: response.tokenCount,
            cached: false,
            structuredData: response.structuredData
        )
    }
    
    public func isAvailable() async -> Bool {
        // Check if API key is valid and network is available
        return !apiKey.isEmpty && NetworkMonitor.shared.isConnected
    }
    
    private func callProvider(
        prompt: String,
        schema: [String: Any]?,
        temperature: Double
    ) async throws -> ProviderResponse {
        switch type {
        case .openai:
            return try await callOpenAI(prompt: prompt, schema: schema, temperature: temperature)
        case .anthropic:
            return try await callAnthropic(prompt: prompt, schema: schema, temperature: temperature)
        case .custom:
            return try await callCustom(prompt: prompt, schema: schema, temperature: temperature)
        }
    }
}
```

---

## Phase 3: Settings UI (Week 3)

### Settings UI Structure

**File**: `Sources/Shared/Views/Settings/AISettingsView.swift`

```swift
struct AISettingsView: View {
    @StateObject private var router = AIRouter.shared
    @StateObject private var modelManager = LocalModelManager.shared
    
    var body: some View {
        Form {
            Section("AI Mode") {
                Picker("Mode", selection: $router.mode) {
                    Text("Auto (Recommended)").tag(AIMode.auto)
                    Text("Apple Intelligence Only").tag(AIMode.appleOnly)
                    Text("Local Only (Offline)").tag(AIMode.localOnly)
                    Text("BYO Provider").tag(AIMode.byoOnly)
                }
                
                Text(modeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Local Models") {
                #if os(macOS)
                modelDownloadRow(
                    type: .macOSStandard,
                    name: "macOS Standard Model",
                    size: "800 MB"
                )
                #else
                modelDownloadRow(
                    type: .iOSLite,
                    name: "iOS Lite Model",
                    size: "150 MB"
                )
                #endif
            }
            
            if router.mode == .byoOnly {
                Section("BYO Provider") {
                    byoProviderSettings
                }
            }
            
            Section("Current Status") {
                LabeledContent("Active Provider", value: router.currentProvider ?? "None")
                LabeledContent("Offline Mode", value: router.mode == .localOnly ? "Yes" : "No")
            }
        }
    }
    
    private func modelDownloadRow(type: LocalModelType, name: String, size: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                Text(size)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if modelManager.isModelDownloaded(type) {
                Label("Downloaded", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if modelManager.isDownloading(type) {
                ProgressView(value: modelManager.downloadProgress(type))
                    .frame(width: 100)
            } else {
                Button("Download") {
                    Task {
                        await modelManager.downloadModel(type)
                    }
                }
            }
        }
    }
}
```

---

## Phase 4: Model Management (Week 4)

### Local Model Manager

**File**: `Sources/Shared/AI/LocalModelManager.swift`

```swift
public enum LocalModelType {
    case macOSStandard
    case iOSLite
}

@MainActor
public final class LocalModelManager: ObservableObject {
    public static let shared = LocalModelManager()
    
    @Published public var downloadProgress: [LocalModelType: Double] = [:]
    private var downloadedModels: Set<LocalModelType> = []
    
    public func isModelDownloaded(_ type: LocalModelType) -> Bool {
        downloadedModels.contains(type)
    }
    
    public func isDownloading(_ type: LocalModelType) -> Bool {
        downloadProgress[type] != nil
    }
    
    public func downloadProgress(_ type: LocalModelType) -> Double {
        downloadProgress[type] ?? 0.0
    }
    
    public func downloadModel(_ type: LocalModelType) async throws {
        let url = modelURL(for: type)
        let destination = localPath(for: type)
        
        // Download with progress tracking
        for try await progress in downloadWithProgress(from: url, to: destination) {
            downloadProgress[type] = progress
        }
        
        downloadedModels.insert(type)
        downloadProgress[type] = nil
    }
    
    public func deleteModel(_ type: LocalModelType) throws {
        let path = localPath(for: type)
        try FileManager.default.removeItem(at: path)
        downloadedModels.remove(type)
    }
    
    public func getModelURL(_ type: LocalModelType) throws -> URL {
        let path = localPath(for: type)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AIError.modelNotDownloaded
        }
        return path
    }
    
    private func modelURL(for type: LocalModelType) -> URL {
        // CDN or server URL for model downloads
        switch type {
        case .macOSStandard:
            return URL(string: "https://models.roots.app/macos-standard-v1.mlmodel")!
        case .iOSLite:
            return URL(string: "https://models.roots.app/ios-lite-v1.mlmodel")!
        }
    }
    
    private func localPath(for type: LocalModelType) -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let modelDir = directory.appendingPathComponent("Models")
        
        try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        
        let filename = type == .macOSStandard ? "macos-standard.mlmodel" : "ios-lite.mlmodel"
        return modelDir.appendingPathComponent(filename)
    }
}
```

---

## Phase 5: Integration & Testing (Week 5)

### Testing Plan

#### Unit Tests
```swift
class AIRouterTests: XCTestCase {
    func testAutoRouting_AppleAvailable() async throws {
        let router = AIRouter.shared
        router.mode = .auto
        
        let result = try await router.route(
            prompt: "Test prompt",
            task: .intentToAction
        )
        
        XCTAssertEqual(result.provider, "Apple Intelligence")
    }
    
    func testOfflineMode_NeverNetwork() async throws {
        let router = AIRouter.shared
        router.mode = .localOnly
        
        let result = try await router.route(
            prompt: "Test prompt",
            task: .summarize,
            requireOffline: true
        )
        
        XCTAssertTrue(result.provider.contains("Local"))
    }
}
```

#### Integration Tests
- Test provider switching
- Test model download flow
- Test BYO provider configuration
- Test offline mode enforcement

#### Manual Testing Checklist
- [ ] Apple Intelligence routing (when available)
- [ ] Local fallback (when Apple unavailable)
- [ ] BYO provider configuration
- [ ] Model download (macOS)
- [ ] Model download (iOS/iPadOS)
- [ ] Offline mode (no network calls)
- [ ] Settings UI persistence
- [ ] Provider switching
- [ ] Error handling

---

## Model Size Targets

### macOS Standard Model
- **Target Size**: 500-800 MB
- **Capabilities**: Full reasoning, multi-turn, tool use
- **Context**: 4096 tokens
- **Format**: CoreML optimized
- **Quantization**: 4-bit or 8-bit

### iOS/iPadOS Lite Model
- **Target Size**: 100-200 MB
- **Capabilities**: Intent parsing, short summaries
- **Context**: 2048 tokens
- **Format**: CoreML optimized for ANE
- **Quantization**: 4-bit aggressive

---

## Privacy & Security

### Guarantees
1. **Local-only mode**: No network calls, enforced by router
2. **Explicit consent**: BYO requires user configuration
3. **No silent switching**: Always log provider changes
4. **Data retention**: No prompt logging by default
5. **API key storage**: Keychain on macOS/iOS

### User Controls
- Clear indication of which provider is active
- Ability to disable AI entirely
- Ability to delete downloaded models
- Ability to clear API keys

---

## Documentation Requirements

1. **User Guide**: How to configure AI settings
2. **Developer Guide**: How to use AIRouter API
3. **Model Guide**: Size, capabilities, limitations
4. **Privacy Policy**: How AI/LLM features work

---

## Acceptance Criteria

| Criterion | Implementation Plan |
|-----------|-------------------|
| Apple Intelligence primary when available | ✅ AIRouter auto mode |
| Optional BYO provider | ✅ BYOProvider + Settings UI |
| Local fallback with platform sizes | ✅ LocalModelProvider_macOS/iOS |
| Explicit routing | ✅ AIRouter mode selection |
| No silent network switch | ✅ Router logging + mode enforcement |
| macOS larger than iOS | ✅ 800MB vs 150MB targets |
| Clean conditional compilation | ✅ #if os() guards |

---

## Timeline

| Week | Phase | Deliverables |
|------|-------|-------------|
| 1 | Core Architecture | Protocols, Router, Types |
| 2 | Providers | Apple, BYO, Local stubs |
| 3 | Settings UI | AI settings view, model downloads |
| 4 | Model Management | Download, storage, packaging |
| 5 | Testing | Unit tests, integration, manual QA |

**Total**: 5 weeks (1 developer full-time)

---

## Risks & Mitigations

### Risks
1. **Apple Intelligence SDK availability** - May not be public yet
   - Mitigation: Implement stub provider, update when SDK available

2. **Model licensing** - Finding suitable open models
   - Mitigation: Use Llama 3.2, Phi-3, or similar permissively licensed models

3. **Model size vs capability trade-off** - iOS model may be too small
   - Mitigation: Start with minimal iOS model, expand based on testing

4. **Performance on older devices** - Local models may be slow
   - Mitigation: Performance testing on oldest supported devices, graceful degradation

### Dependencies
- CoreML framework
- Apple Intelligence SDK (when available)
- Network monitoring
- Keychain services
- File management

---

## Future Enhancements (Post-v1)

1. **RAG Pipeline**: Vector embeddings, document retrieval
2. **Fine-tuning**: Custom models per user/course
3. **Hybrid Inference**: Start local, augment with cloud
4. **Model Quantization**: On-device quantization for size optimization
5. **Streaming**: Token-by-token streaming responses
6. **Multi-modal**: Image understanding, OCR
7. **Voice**: Speech-to-text integration
8. **Caching**: Response caching for common queries

---

## Status

**Current**: 📋 Planning/Design Phase  
**Next Step**: Begin Phase 1 - Core Architecture implementation  
**Estimated Completion**: 5 weeks from start  

This is a substantial feature requiring dedicated development time and careful testing across platforms.

---

*Planning completed: December 23, 2025*  
*Ready for implementation phase*
