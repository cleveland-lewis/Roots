# Roots AI Architecture

## Overview

Roots implements a hybrid AI architecture that provides intelligent features across all platforms while respecting user privacy and device capabilities.

## Architecture Components

### 1. Core Provider Interface (`AIProvider`)

All AI providers implement the `AIProvider` protocol, which defines:
- `generate()` - Main inference method
- `capabilities` - What the provider can do (offline, tools support, max context, etc.)
- Task kind support for different AI operations

### 2. AI Router (`AIRouter`)

The router is the central coordinator that:
- Registers available providers at runtime
- Selects the appropriate provider based on mode and task
- Logs all AI operations for debugging
- Enforces privacy guarantees (no silent network fallbacks)

### 3. Providers

#### Apple Foundation Models Provider
- Primary provider when available (iOS 18+, macOS 15+)
- Fully on-device
- Currently a stub - will be implemented when Apple releases APIs

#### Local Model Providers
Two variants optimized per platform:

**macOS (`LocalModelProvider_macOS`)**
- Model: roots-standard-7b (~4.3 GB)
- Capabilities: Higher context window (32K tokens)
- Supports: Intent parsing, summarization, rewriting, question generation, syllabus parsing

**iOS/iPadOS (`LocalModelProvider_iOS`)**
- Model: roots-lite-1b (~800 MB)
- Capabilities: Smaller context window (8K tokens)
- Optimized for battery and footprint
- Supports: Intent parsing, summarization, syllabus parsing (core tasks only)

#### BYO Provider
- Supports OpenAI, Anthropic, and custom endpoints
- User provides API key
- Requires explicit opt-in
- Network-based

## AI Modes

### Auto (Recommended)
Priority order:
1. Apple Intelligence (if available)
2. Local model (platform-specific)

### Apple Intelligence Only
- Only uses Apple Intelligence
- Disables AI features if unavailable

### Local Only
- Uses on-device model exclusively
- Guaranteed no network access
- Requires model download

### BYO Provider
- Uses custom API provider
- Requires configuration
- Network access required

## Task Kinds

AI operations are categorized by task kind:
- `intentToAction` - Parse user intent to structured actions
- `summarize` - Generate summaries
- `rewrite` - Rewrite/improve text
- `studyQuestionGen` - Generate study questions
- `syllabusParser` - Extract structured data from syllabi
- `scheduleOptimize` - Schedule optimization suggestions

## Settings Integration

Users can configure AI behavior through Settings → AI:
- Select AI mode
- View provider availability
- Download local models
- Configure BYO providers
- View privacy guarantees

## Privacy & Security

### Guarantees
- Local-only mode never makes network requests
- No silent provider switching
- BYO provider requires explicit opt-in
- All requests logged (provider selection, latency)
- API keys stored securely on device

### Logging
All AI operations are logged via the diagnostics system:
- Provider selection
- Request outcomes (success/error)
- Latency metrics
- No sensitive prompt logging by default

## Implementation Status

### ✅ Completed
- Core provider protocol and interfaces
- AI Router with provider selection logic
- All provider implementations (stubs for unreleased features)
- Settings UI for macOS
- Integration with app settings model
- Logging infrastructure
- Privacy guarantees

### 🔄 To Be Implemented
- Actual Apple Intelligence integration (when APIs available)
- Local model download implementation
- Local model inference (using mlx-swift or CoreML)
- iOS/iPadOS settings UI
- Model management (download progress, deletion)
- RAG/embeddings pipeline (future ticket)

## Usage Example

```swift
// Initialize router
let router = AIRouter(mode: .auto)

// Register providers
router.registerProvider(AppleFoundationModelsProvider())
router.registerProvider(LocalModelProvider_macOS())

// Generate
let result = try await router.generate(
    prompt: "Summarize this syllabus...",
    taskKind: .syllabusParser,
    options: .default
)

print("Provider used: \(result.metadata.provider)")
print("Latency: \(result.metadata.latencyMs)ms")
print("Content: \(result.content)")
```

## Files Created

### SharedCore/Features/AI/
- `AIProvider.swift` - Core protocols and types
- `AIRouter.swift` - Router and mode management
- `AppleFoundationModelsProvider.swift` - Apple Intelligence provider
- `LocalModelProvider.swift` - On-device model providers
- `BYOProvider.swift` - Custom API provider

### macOS/Views/Settings/
- `AISettingsView.swift` - Settings UI

### Modified Files
- `SharedCore/State/AppSettingsModel.swift` - Added AI settings
- `SharedCore/Utilities/Diagnostics.swift` - Added AI logging
- `macOS/PlatformAdapters/SettingsToolbarIdentifiers.swift` - Added AI tab
- `macOS/Scenes/SettingsRootView.swift` - Added AI settings route

## Next Steps

1. Implement local model download mechanism
2. Integrate actual inference engine (mlx-swift for Apple Silicon)
3. Add iOS/iPadOS settings UI
4. Implement Apple Intelligence when APIs are available
5. Add embeddings/RAG support (separate ticket)
6. Performance optimization and caching
