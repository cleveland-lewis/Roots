import Foundation

/// Manages local LLM model preferences
@Observable
public final class LocalModelSettings {
    
    // MARK: - Singleton
    
    public static let shared = LocalModelSettings()
    
    // MARK: - Settings
    
    @ObservationIgnored
    @AppStorage("localModel.tierSelection")
    public var tierSelection: TierSelection = .auto
    
    @ObservationIgnored
    @AppStorage("localModel.selectedModelID")
    private var selectedModelID: String?
    
    @ObservationIgnored
    @AppStorage("localModel.lastUsedDate")
    private var lastUsedDateString: String?
    
    public var selectedModel: LocalModelEntry? {
        get {
            guard let id = selectedModelID else { return nil }
            return LocalModelCatalog.model(id: id)
        }
        set {
            selectedModelID = newValue?.id
            if newValue != nil {
                lastUsedDateString = ISO8601DateFormatter().string(from: Date())
            }
        }
    }
    
    public var lastUsedDate: Date? {
        guard let dateString = lastUsedDateString else { return nil }
        return ISO8601DateFormatter().date(from: dateString)
    }
    
    // MARK: - Tier Selection
    
    public enum TierSelection: String, Codable, CaseIterable {
        case auto = "Auto"
        case tierA = "TierA"
        case tierB = "TierB"
        case tierC = "TierC"
        
        public var displayName: String {
            switch self {
            case .auto: return "Auto (Recommended)"
            case .tierA: return "Fast (16GB)"
            case .tierB: return "Balanced (32GB)"
            case .tierC: return "Quality (64GB+)"
            }
        }
        
        public func resolvedTier() -> DeviceMemory.ModelTier {
            switch self {
            case .auto:
                return DeviceMemory.selectTier()
            case .tierA:
                return .tierA
            case .tierB:
                return .tierB
            case .tierC:
                return .tierC
            }
        }
    }
    
    // MARK: - Computed
    
    public var effectiveTier: DeviceMemory.ModelTier {
        tierSelection.resolvedTier()
    }
    
    public var effectiveModel: LocalModelEntry? {
        LocalModelCatalog.model(for: effectiveTier)
    }
    
    public var isModelReady: Bool {
        guard let model = effectiveModel else { return false }
        return LocalModelCatalog.isModelInstalled(model)
    }
    
    // MARK: - Init
    
    private init() {
        // Auto-select model on first launch
        if selectedModelID == nil {
            selectedModel = effectiveModel
        }
    }
}

// MARK: - AppStorage Property Wrapper

@propertyWrapper
public struct AppStorage<Value: Codable> {
    private let key: String
    private let defaultValue: Value
    
    public init(wrappedValue defaultValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    public var wrappedValue: Value {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}
