import Foundation

@MainActor
final class StorageAggregateStore: ObservableObject {
    static let shared = StorageAggregateStore()

    @Published private(set) var buckets: [String: [StorageEntityType: Int]] = [:]

    private let storageURL: URL

    private init(storageURL: URL? = nil) {
        let fm = FileManager.default
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let folder = dir.appendingPathComponent("RootsStorage", isDirectory: true)
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            self.storageURL = folder.appendingPathComponent("aggregate_storage.json")
        }
        load()
    }

    func recordDeletion(type: StorageEntityType, date: Date) {
        let key = monthKey(for: date)
        var counts = buckets[key, default: [:]]
        counts[type, default: 0] += 1
        buckets[key] = counts
        persist()
    }

    private func monthKey(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(buckets)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            LOG_DATA(.error, "StorageAggregate", "Failed to persist aggregate storage: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            buckets = try JSONDecoder().decode([String: [StorageEntityType: Int]].self, from: data)
        } catch {
            LOG_DATA(.error, "StorageAggregate", "Failed to load aggregate storage: \(error.localizedDescription)")
        }
    }
}
