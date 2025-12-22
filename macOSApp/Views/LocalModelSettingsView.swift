import SwiftUI

struct LocalModelSettingsView: View {
    
    @State private var settings = LocalModelSettings.shared
    @State private var downloader = ModelDownloader()
    @State private var showingDeleteConfirmation = false
    @State private var modelToDelete: LocalModelEntry?
    
    var body: some View {
        Form {
            // Device RAM Info
            ramInfoSection
            
            // Tier Selection
            tierSelectionSection
            
            // Current Model Status
            modelStatusSection
            
            // Download/Management Actions
            actionsSection
            
            // Installed Models
            installedModelsSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 600, minHeight: 500)
    }
    
    // MARK: - Sections
    
    private var ramInfoSection: some View {
        Section("Device Information") {
            LabeledContent("Physical RAM", value: DeviceMemory.ramDescription())
            LabeledContent("Recommended Tier", value: DeviceMemory.selectTier().humanLabel)
        }
    }
    
    private var tierSelectionSection: some View {
        Section("Model Quality") {
            Picker("Quality Level", selection: $settings.tierSelection) {
                ForEach(LocalModelSettings.TierSelection.allCases, id: \.self) { tier in
                    Text(tier.displayName).tag(tier)
                }
            }
            .pickerStyle(.segmented)
            
            Text("Auto selects the best model for your device's RAM. Higher quality models provide better responses but require more memory.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var modelStatusSection: some View {
        Section("Current Model") {
            if let model = settings.effectiveModel {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Model", value: model.humanLabel)
                    LabeledContent("Version", value: model.version)
                    LabeledContent("Tier", value: model.tier.rawValue)
                    LabeledContent("Size", value: formatBytes(model.expectedFileSizeBytes))
                    
                    if LocalModelCatalog.isModelInstalled(model) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Ready")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Not Downloaded")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let lastUsed = settings.lastUsedDate {
                        LabeledContent("Last Used", value: lastUsed.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            } else {
                Text("No model selected")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var actionsSection: some View {
        Section {
            switch downloader.downloadState {
            case .idle, .completed, .failed:
                downloadButton
                
            case .downloading(let progress, let bytesReceived, let totalBytes):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Downloading...")
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    
                    ProgressView(value: progress)
                    
                    HStack {
                        Text("\(formatBytes(UInt64(bytesReceived))) / \(formatBytes(UInt64(totalBytes)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button("Cancel") {
                            downloader.cancelDownload()
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
            case .verifying:
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Verifying model...")
                        .foregroundStyle(.secondary)
                }
            }
            
            if case .failed(let error) = downloader.downloadState {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Download Failed")
                            .foregroundStyle(.red)
                    }
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("Retry") {
                        Task {
                            try? await downloader.retryDownload()
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
        } header: {
            Text("Actions")
        }
    }
    
    private var downloadButton: some View {
        Group {
            if let model = settings.effectiveModel {
                if LocalModelCatalog.isModelInstalled(model) {
                    HStack {
                        Button("Redownload Model") {
                            Task {
                                try? LocalModelCatalog.deleteModel(model)
                                try? await downloader.downloadModel(model)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Delete Model") {
                            modelToDelete = model
                            showingDeleteConfirmation = true
                        }
                        .foregroundStyle(.red)
                    }
                } else {
                    Button("Download Model") {
                        Task {
                            try? await downloader.downloadModel(model)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private var installedModelsSection: some View {
        Section("Installed Models") {
            let installedModels = LocalModelCatalog.availableModels.filter { LocalModelCatalog.isModelInstalled($0) }
            
            if installedModels.isEmpty {
                Text("No models installed")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(installedModels) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.humanLabel)
                                .font(.headline)
                            Text("v\(model.version) • \(model.tier.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if let size = LocalModelCatalog.installedModelSize(model) {
                            Text(formatBytes(size))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            modelToDelete = model
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .alert("Delete Model?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    try? LocalModelCatalog.deleteModel(model)
                    modelToDelete = nil
                }
            }
        } message: {
            if let model = modelToDelete {
                Text("Are you sure you want to delete \(model.humanLabel)? You can redownload it later.")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    LocalModelSettingsView()
        .frame(width: 600, height: 500)
}
