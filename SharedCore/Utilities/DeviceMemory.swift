import Foundation

/// Utility for detecting device physical RAM and selecting appropriate model tier
public struct DeviceMemory {
    
    /// Model tier based on device RAM
    public enum ModelTier: String, Codable, CaseIterable, Sendable {
        case tierA = "TierA" // <= 16 GiB (smallest, fastest)
        case tierB = "TierB" // 24-32 GiB (mid, higher quality)
        case tierC = "TierC" // >= 64 GiB (best quality)
        
        public var humanLabel: String {
            switch self {
            case .tierA: return "Fast (16GB)"
            case .tierB: return "Balanced (32GB)"
            case .tierC: return "Quality (64GB+)"
            }
        }
        
        public var minimumRAMGiB: Int {
            switch self {
            case .tierA: return 8
            case .tierB: return 24
            case .tierC: return 64
            }
        }
    }
    
    // MARK: - RAM Detection
    
    /// Get physical RAM in bytes
    public static var physicalRAMBytes: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }
    
    /// Get physical RAM in GiB (binary gigabytes)
    public static var physicalRAMGiB: Double {
        Double(physicalRAMBytes) / (1024.0 * 1024.0 * 1024.0)
    }
    
    // MARK: - Tier Selection
    
    /// Tier thresholds (adjustable constants)
    private static let tierAMaxGiB: Double = 16.0
    private static let tierBMinGiB: Double = 17.0
    private static let tierBMaxGiB: Double = 48.0
    private static let tierCMinGiB: Double = 49.0
    
    /// Automatically select model tier based on device RAM
    public static func selectTier() -> ModelTier {
        let ramGiB = physicalRAMGiB
        
        if ramGiB <= tierAMaxGiB {
            return .tierA
        } else if ramGiB >= tierBMinGiB && ramGiB <= tierBMaxGiB {
            return .tierB
        } else if ramGiB >= tierCMinGiB {
            return .tierC
        } else {
            // Fallback to TierA for edge cases
            return .tierA
        }
    }
    
    /// Check if device can run a specific tier
    public static func canRunTier(_ tier: ModelTier) -> Bool {
        physicalRAMGiB >= Double(tier.minimumRAMGiB)
    }
    
    /// Get human-readable RAM description
    public static func ramDescription() -> String {
        String(format: "%.1f GB", physicalRAMGiB)
    }
    
    /// Log RAM detection (for debugging)
    public static func logRAMInfo() {
        let ramGiB = physicalRAMGiB
        let selectedTier = selectTier()
        print("[DeviceMemory] Physical RAM: \(String(format: "%.2f", ramGiB)) GiB")
        print("[DeviceMemory] Auto-selected tier: \(selectedTier.rawValue) (\(selectedTier.humanLabel))")
    }
}
