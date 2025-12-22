import Foundation

/// Catalog entry for a Core ML model
public struct LocalModelEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let tier: DeviceMemory.ModelTier
    public let version: String
    public let remoteURL: URL
    public let expectedFileSizeBytes: UInt64
    public let sha256Hash: String
    public let minimumRAMGiB: Int
    public let humanLabel: String
    public let modelFileName: String // e.g., "model.mlmodelc"
    
    public init(
        id: String,
        tier: DeviceMemory.ModelTier,
        version: String,
        remoteURL: URL,
        expectedFileSizeBytes: UInt64,
        sha256Hash: String,
        minimumRAMGiB: Int,
        humanLabel: String,
        modelFileName: String
    ) {
        self.id = id
        self.tier = tier
        self.version = version
        self.remoteURL = remoteURL
        self.expectedFileSizeBytes = expectedFileSizeBytes
        self.sha256Hash = sha256Hash
        self.minimumRAMGiB = minimumRAMGiB
        self.humanLabel = humanLabel
        self.modelFileName = modelFileName
    }
}

/// Catalog of available Core ML models
public struct LocalModelCatalog {
    
    // MARK: - Model Storage
    
    /// Base directory for all models
    public static var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let rootsDir = appSupport.appendingPathComponent("Roots", isDirectory: true)
        let modelsDir = rootsDir.appendingPathComponent("Models", isDirectory: true)
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        
        return modelsDir
    }
    
    /// Directory for a specific model
    public static func modelDirectory(id: String, version: String) -> URL {
        modelsDirectory
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
    }
    
    /// Path to a specific model file
    public static func modelPath(entry: LocalModelEntry) -> URL {
        modelDirectory(id: entry.id, version: entry.version)
            .appendingPathComponent(entry.modelFileName)
    }
    
    // MARK: - Available Models
    
    /// Current catalog version
    public static let catalogVersion = "1.0.0"
    
    /// All available models in catalog
    /// NOTE: These are placeholder URLs. Replace with actual Core ML model hosting URLs.
    public static let availableModels: [LocalModelEntry] = [
        // Tier A: Fast model for 16GB devices
        LocalModelEntry(
            id: "roots-llm-tierA",
            tier: .tierA,
            version: "1.0.0",
            remoteURL: URL(string: "https://models.roots.app/coreml/tierA/v1.0.0/model.mlmodelc.zip")!,
            expectedFileSizeBytes: 500_000_000, // ~500 MB
            sha256Hash: "placeholder_hash_tierA_replace_with_actual",
            minimumRAMGiB: 8,
            humanLabel: "Fast (16GB) - Phi-2 Quantized",
            modelFileName: "model.mlmodelc"
        ),
        
        // Tier B: Balanced model for 32GB devices
        LocalModelEntry(
            id: "roots-llm-tierB",
            tier: .tierB,
            version: "1.0.0",
            remoteURL: URL(string: "https://models.roots.app/coreml/tierB/v1.0.0/model.mlmodelc.zip")!,
            expectedFileSizeBytes: 2_000_000_000, // ~2 GB
            sha256Hash: "placeholder_hash_tierB_replace_with_actual",
            minimumRAMGiB: 24,
            humanLabel: "Balanced (32GB) - Mistral 7B Quantized",
            modelFileName: "model.mlmodelc"
        ),
        
        // Tier C: Quality model for 64GB+ devices
        LocalModelEntry(
            id: "roots-llm-tierC",
            tier: .tierC,
            version: "1.0.0",
            remoteURL: URL(string: "https://models.roots.app/coreml/tierC/v1.0.0/model.mlmodelc.zip")!,
            expectedFileSizeBytes: 7_000_000_000, // ~7 GB
            sha256Hash: "placeholder_hash_tierC_replace_with_actual",
            minimumRAMGiB: 64,
            humanLabel: "Quality (64GB+) - Llama 3.1 8B",
            modelFileName: "model.mlmodelc"
        )
    ]
    
    // MARK: - Lookup
    
    /// Get model entry for a specific tier
    public static func model(for tier: DeviceMemory.ModelTier) -> LocalModelEntry? {
        availableModels.first { $0.tier == tier }
    }
    
    /// Get model entry by ID
    public static func model(id: String) -> LocalModelEntry? {
        availableModels.first { $0.id == id }
    }
    
    /// Check if a model is downloaded and verified
    public static func isModelInstalled(_ entry: LocalModelEntry) -> Bool {
        let modelPath = modelPath(entry: entry)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    /// Get installed model size on disk
    public static func installedModelSize(_ entry: LocalModelEntry) -> UInt64? {
        let modelPath = modelPath(entry: entry)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: modelPath.path),
              let size = attributes[.size] as? UInt64 else {
            return nil
        }
        return size
    }
    
    /// Delete an installed model
    public static func deleteModel(_ entry: LocalModelEntry) throws {
        let modelDir = modelDirectory(id: entry.id, version: entry.version)
        if FileManager.default.fileExists(atPath: modelDir.path) {
            try FileManager.default.removeItem(at: modelDir)
        }
    }
}
