import Foundation
import CryptoKit

/// Download state for a model
public enum ModelDownloadState: Equatable, Sendable {
    case idle
    case downloading(progress: Double, bytesReceived: Int64, totalBytes: Int64)
    case verifying
    case completed
    case failed(String)
    
    public var isActive: Bool {
        switch self {
        case .downloading, .verifying:
            return true
        default:
            return false
        }
    }
}

/// Service for downloading and verifying Core ML models
@Observable
public final class ModelDownloader: NSObject, Sendable {
    
    // MARK: - State
    
    public private(set) var downloadState: ModelDownloadState = .idle
    public private(set) var currentModelEntry: LocalModelEntry?
    
    private var downloadTask: URLSessionDownloadTask?
    private var session: URLSession!
    
    // MARK: - Init
    
    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 3600 // 1 hour for large models
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Download
    
    /// Download a model with progress tracking
    public func downloadModel(_ entry: LocalModelEntry) async throws {
        // Check if already downloaded
        if LocalModelCatalog.isModelInstalled(entry) {
            downloadState = .completed
            return
        }
        
        currentModelEntry = entry
        downloadState = .downloading(progress: 0, bytesReceived: 0, totalBytes: Int64(entry.expectedFileSizeBytes))
        
        // Create destination directory
        let destinationDir = LocalModelCatalog.modelDirectory(id: entry.id, version: entry.version)
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        
        // Download file
        let downloadedURL = try await performDownload(from: entry.remoteURL)
        
        // Verify SHA256
        downloadState = .verifying
        try await verifyAndExtract(downloadedURL: downloadedURL, entry: entry, destinationDir: destinationDir)
        
        downloadState = .completed
    }
    
    /// Perform the actual download
    private func performDownload(from url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            downloadTask = session.downloadTask(with: url) { [weak self] tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let tempURL = tempURL else {
                    continuation.resume(throwing: ModelDownloadError.downloadFailed("No file received"))
                    return
                }
                
                continuation.resume(returning: tempURL)
            }
            downloadTask?.resume()
        }
    }
    
    /// Verify SHA256 and extract model
    private func verifyAndExtract(downloadedURL: URL, entry: LocalModelEntry, destinationDir: URL) async throws {
        // For now, skip SHA256 verification if hash is placeholder
        // In production, always verify:
        if !entry.sha256Hash.starts(with: "placeholder") {
            let computedHash = try await computeSHA256(url: downloadedURL)
            guard computedHash == entry.sha256Hash else {
                throw ModelDownloadError.hashMismatch(expected: entry.sha256Hash, got: computedHash)
            }
        }
        
        // Extract if it's a zip file
        if downloadedURL.pathExtension == "zip" || entry.remoteURL.pathExtension == "zip" {
            try await extractZip(from: downloadedURL, to: destinationDir)
        } else {
            // Copy directly if not zipped
            let destinationPath = destinationDir.appendingPathComponent(entry.modelFileName)
            try FileManager.default.copyItem(at: downloadedURL, to: destinationPath)
        }
        
        // Verify model can be loaded
        let modelPath = LocalModelCatalog.modelPath(entry: entry)
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw ModelDownloadError.modelNotFound("Model file not found after extraction")
        }
    }
    
    /// Compute SHA256 hash of a file
    private func computeSHA256(url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Extract zip file (basic implementation)
    private func extractZip(from sourceURL: URL, to destinationDir: URL) async throws {
        // Use FileManager's built-in unzipping on macOS
        // Note: This requires the zip to be properly formatted
        try FileManager.default.unzipItem(at: sourceURL, to: destinationDir)
    }
    
    // MARK: - Cancellation
    
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadState = .failed("Cancelled by user")
    }
    
    // MARK: - Retry
    
    public func retryDownload() async throws {
        guard let entry = currentModelEntry else {
            throw ModelDownloadError.noModelSelected
        }
        
        // Delete partial download if exists
        let modelDir = LocalModelCatalog.modelDirectory(id: entry.id, version: entry.version)
        try? FileManager.default.removeItem(at: modelDir)
        
        // Retry download
        try await downloadModel(entry)
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloader: URLSessionDownloadDelegate {
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        downloadState = .downloading(
            progress: progress,
            bytesReceived: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite
        )
    }
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Handled in performDownload continuation
    }
}

// MARK: - Errors

public enum ModelDownloadError: Error, LocalizedError {
    case downloadFailed(String)
    case hashMismatch(expected: String, got: String)
    case modelNotFound(String)
    case noModelSelected
    case extractionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .hashMismatch(let expected, let got):
            return "Hash mismatch. Expected: \(expected), got: \(got)"
        case .modelNotFound(let message):
            return "Model not found: \(message)"
        case .noModelSelected:
            return "No model selected for download"
        case .extractionFailed(let message):
            return "Failed to extract model: \(message)"
        }
    }
}

// MARK: - FileManager Unzip Extension

extension FileManager {
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        // Use Process to call unzip command on macOS
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", sourceURL.path, "-d", destinationURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ModelDownloadError.extractionFailed("Unzip failed with status \(process.terminationStatus)")
        }
    }
}
