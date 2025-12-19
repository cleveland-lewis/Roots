#if os(macOS)
import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @State private var showingBYOConfig = false
    @State private var byoConfig = BYOProviderConfig.default
    @State private var isDownloadingModel = false
    @State private var downloadProgress: Double = 0.0
    @State private var isAppleIntelligenceAvailable = false
    @State private var availableProviders: [String] = []
    @State private var lastUsedProvider: String?
    
    var body: some View {
        Form {
            Section {
                Text("AI Features")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 4)
                
                Text("Configure how Roots uses AI for intelligent scheduling, summarization, and more.")
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            
            Section("AI Mode") {
                Picker("Mode", selection: $settings.aiMode) {
                    ForEach(AIMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: settings.aiMode) { _, _ in
                    settings.save()
                    LOG_SETTINGS(.info, "AIModeChanged", "AI mode changed", metadata: ["mode": settings.aiMode.rawValue])
                }
                
                Text(modeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Apple Intelligence Status
            if settings.aiMode == .auto || settings.aiMode == .appleIntelligenceOnly {
                Section("Apple Intelligence") {
                    HStack {
                        Image(systemName: isAppleIntelligenceAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isAppleIntelligenceAvailable ? .green : .orange)
                        
                        Text(isAppleIntelligenceAvailable ? "Available" : "Not Available")
                        
                        Spacer()
                    }
                    
                    if !isAppleIntelligenceAvailable {
                        Text("Apple Intelligence is not currently available on this device. Roots will fall back to the local model when needed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Local Model Settings
            if settings.aiMode == .auto || settings.aiMode == .localOnly {
                Section("Local Model") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            #if os(macOS)
                            Text("macOS Model: \(LocalModelProvider_macOS.modelConfig.modelName)")
                            Text("Size: \(LocalModelProvider_macOS.modelConfig.displaySize)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            #elseif os(iOS) || os(visionOS)
                            Text("iOS Model: \(LocalModelProvider_iOS.modelConfig.modelName)")
                            Text("Size: \(LocalModelProvider_iOS.modelConfig.displaySize)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            #endif
                        }
                        
                        Spacer()
                        
                        if isModelDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Downloaded")
                                .font(.caption)
                        } else {
                            Button("Download") {
                                downloadModel()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(settings.activeAccentColor)
                            .disabled(isDownloadingModel)
                        }
                    }
                    
                    if isDownloadingModel {
                        ProgressView(value: downloadProgress, total: 1.0)
                            .progressViewStyle(.linear)
                        Text("Downloading: \(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("The local model runs entirely on your device with no internet connection required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // BYO Provider Settings
            if settings.aiMode == .byoProvider {
                Section("Custom Provider") {
                    Button("Configure Provider") {
                        byoConfig = settings.byoProviderConfig
                        showingBYOConfig = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.activeAccentColor)
                    
                    if !settings.byoProviderConfig.apiKey.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Configured: \(settings.byoProviderConfig.providerType.displayName)")
                        }
                    } else {
                        Text("No provider configured")
                            .foregroundStyle(.secondary)
                    }
                }
                .sheet(isPresented: $showingBYOConfig) {
                    BYOProviderConfigView(config: $byoConfig, onSave: {
                        settings.byoProviderConfig = byoConfig
                        settings.save()
                        showingBYOConfig = false
                    })
                }
            }
            
            Section("Privacy") {
                Label {
                    Text("All AI requests are logged for debugging")
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.caption)
                
                if settings.aiMode == .localOnly {
                    Label {
                        Text("Local-only mode never makes network requests")
                    } icon: {
                        Image(systemName: "network.slash")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }
            }
            
            Section("Status") {
                if let provider = lastUsedProvider {
                    HStack {
                        Text("Last Used Provider:")
                        Spacer()
                        Text(provider)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !availableProviders.isEmpty {
                    HStack {
                        Text("Available Providers:")
                        Spacer()
                        Text(availableProviders.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("AI")
        .frame(minWidth: 500, maxWidth: 700)
        .onAppear {
            checkProviderAvailability()
        }
    }
    
    private var modeDescription: String {
        switch settings.aiMode {
        case .auto:
            return "Automatically selects the best available AI provider. Prefers Apple Intelligence when available, falls back to local model."
        case .appleIntelligenceOnly:
            return "Only use Apple Intelligence. AI features will be disabled if Apple Intelligence is unavailable."
        case .localOnly:
            return "Only use the local on-device model. Guaranteed no network access."
        case .byoProvider:
            return "Use your own AI provider (OpenAI, Anthropic, or custom endpoint). Requires API key and network access."
        }
    }
    
    private var isModelDownloaded: Bool {
        #if os(macOS)
        return settings.localModelDownloadedMacOS
        #else
        return settings.localModelDownloadediOS
        #endif
    }
    
    private func checkProviderAvailability() {
        // Check Apple Intelligence availability once
        isAppleIntelligenceAvailable = AppleFoundationModelsProvider.isAvailable()
        
        // Build list of available providers
        var providers: [String] = []
        
        if isAppleIntelligenceAvailable {
            providers.append("Apple Intelligence")
        }
        
        #if os(macOS)
        providers.append("Local (macOS)")
        #elseif os(iOS) || os(visionOS)
        providers.append("Local (iOS)")
        #endif
        
        if !settings.byoProviderConfig.apiKey.isEmpty {
            providers.append("BYO (\(settings.byoProviderConfig.providerType.displayName))")
        }
        
        availableProviders = providers
    }
    
    private func downloadModel() {
        isDownloadingModel = true
        downloadProgress = 0.0
        
        // Simulate download (in production, this would actually download the model)
        Task {
            for i in 0...100 {
                try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
                await MainActor.run {
                    downloadProgress = Double(i) / 100.0
                }
            }
            
            await MainActor.run {
                #if os(macOS)
                settings.localModelDownloadedMacOS = true
                #else
                settings.localModelDownloadediOS = true
                #endif
                settings.save()
                
                isDownloadingModel = false
                LOG_SETTINGS(.info, "ModelDownloaded", "Local AI model downloaded")
            }
        }
    }
}

// MARK: - BYO Provider Configuration View

struct BYOProviderConfigView: View {
    @Binding var config: BYOProviderConfig
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettingsModel
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Provider Type") {
                    Picker("Provider", selection: $config.providerType) {
                        ForEach(BYOProviderType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(settings.activeAccentColor)
                }
                
                Section("Credentials") {
                    SecureField("API Key", text: $config.apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Advanced") {
                    TextField("API Endpoint (Optional)", text: Binding(
                        get: { config.apiEndpoint ?? "" },
                        set: { config.apiEndpoint = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    TextField("Model Name (Optional)", text: Binding(
                        get: { config.modelName ?? "" },
                        set: { config.modelName = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                
                Section {
                    Text("Your API key is stored securely on this device and never shared.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Configure Provider")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.activeAccentColor)
                    .disabled(config.apiKey.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

#endif
