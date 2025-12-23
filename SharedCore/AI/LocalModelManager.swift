import Foundation
import Combine

// MARK: - Local Model Type

/// Types of local models available
public enum LocalModelType: String, Codable {
    case macOSStandard
    case iOSLite
    
    public var displayName: String {
        switch self {
        case .macOSStandard:
            return "macOS Standard Model"
        case .iOSLite:
            return "iOS Lite Model"
        }
    }
    
    public var estimatedSize: String {
        switch self {
        case .macOSStandard:
            return "800 MB"
        case .iOSLite:
            return "150 MB"
        }
    }
    
    public var estimatedSizeBytes: Int64 {
        switch self {
        case .macOSStandard:
            return 800 * 1024 * 1024  // 800 MB
        case .iOSLite:
            return 150 * 1024 * 1024  // 150 MB
        }
    }
}

// MARK: - Local Model Manager

/// Manages downloading and storage of local AI models
@MainActor
public final class LocalModelManager: ObservableObject {
    public static let shared = LocalModelManager()
    
    @Published public var downloadProgress: [LocalModelType: Double] = [:]
    @Published public var downloadedModels: Set<LocalModelType> = []
    
    private var downloadTasks: [LocalModelType: Task<Void, Error>] = [:]
    
    private init() {
        // Check which models are already downloaded
        checkDownloadedModels()
    }
    
    /// Check if a model is downloaded
    public func isModelDownloaded(_ type: LocalModelType) -> Bool {
        return downloadedModels.contains(type)
    }
    
    /// Check if a model is currently downloading
    public func isDownloading(_ type: LocalModelType) -> Bool {
        return downloadProgress[type] != nil
    }
    
    /// Get download progress for a model
    public func downloadProgress(_ type: LocalModelType) -> Double {
        return downloadProgress[type] ?? 0.0
    }
    
    /// Download a model
    public func downloadModel(_ type: LocalModelType) async throws {
        // Don't download if already downloaded
        guard !isModelDownloaded(type) else { return }
        
        // Don't download if already downloading
        guard !isDownloading(type) else { return }
        
        downloadProgress[type] = 0.0
        
        do {
            let url = modelURL(for: type)
            let destination = localPath(for: type)
            
            // TODO: Implement actual download with progress tracking
            // For now, simulate download
            #if DEBUG
            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                downloadProgress[type] = progress
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s per 10%
            }
            #endif
            
            downloadedModels.insert(type)
            downloadProgress[type] = nil
            
        } catch {
            downloadProgress[type] = nil
            throw error
        }
    }
    
    /// Cancel download
    public func cancelDownload(_ type: LocalModelType) {
        downloadTasks[type]?.cancel()
        downloadTasks.removeValue(forKey: type)
        downloadProgress.removeValue(forKey: type)
    }
    
    /// Delete a model
    public func deleteModel(_ type: LocalModelType) throws {
        let path = localPath(for: type)
        
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
        
        downloadedModels.remove(type)
    }
    
    /// Get model URL for loading
    public func getModelURL(_ type: LocalModelType) throws -> URL {
        let path = localPath(for: type)
        
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AIError.modelNotDownloaded
        }
        
        return path
    }
    
    /// Get download URL for a model
    private func modelURL(for type: LocalModelType) -> URL {
        // TODO: Replace with actual CDN/server URLs
        switch type {
        case .macOSStandard:
            return URL(string: "https://models.roots.app/macos-standard-v1.mlmodel")!
        case .iOSLite:
            return URL(string: "https://models.roots.app/ios-lite-v1.mlmodel")!
        }
    }
    
    /// Get local storage path for a model
    private func localPath(for type: LocalModelType) -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        
        let modelDir = directory.appendingPathComponent("Models")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: modelDir,
            withIntermediateDirectories: true
        )
        
        let filename = type == .macOSStandard ? "macos-standard.mlmodel" : "ios-lite.mlmodel"
        return modelDir.appendingPathComponent(filename)
    }
    
    /// Check which models are already downloaded
    private func checkDownloadedModels() {
        for type in [LocalModelType.macOSStandard, .iOSLite] {
            let path = localPath(for: type)
            if FileManager.default.fileExists(atPath: path.path) {
                downloadedModels.insert(type)
            }
        }
    }
    
    /// Get total size of downloaded models
    public func totalDownloadedSize() -> Int64 {
        var total: Int64 = 0
        
        for type in downloadedModels {
            let path = localPath(for: type)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
               let size = attributes[.size] as? Int64 {
                total += size
            }
        }
        
        return total
    }
}
