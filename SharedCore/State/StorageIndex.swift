import Foundation
import Combine

struct StorageIndexEntry: Identifiable, Hashable {
    let id: UUID
    let title: String
    let searchText: String
    let entityType: StorageEntityType
    let primaryDate: Date

    var normalizedTitle: String {
        title.lowercased()
    }

    var normalizedSearchText: String {
        searchText.lowercased()
    }

    var tokens: [String] {
        normalizedSearchText.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
}

enum StorageSortOption: String, CaseIterable, Identifiable {
    case titleAscending
    case mostRecent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .titleAscending: return "A-Z"
        case .mostRecent: return "Recent"
        }
    }
}

final class StorageIndex: ObservableObject {
    @Published private(set) var entries: [UUID: StorageIndexEntry] = [:]

    func update(with entries: [StorageIndexEntry]) {
        var map: [UUID: StorageIndexEntry] = [:]
        map.reserveCapacity(entries.count)
        for entry in entries {
            map[entry.id] = entry
        }
        self.entries = map
    }

    func search(
        query: String,
        types: Set<StorageEntityType>,
        sort: StorageSortOption
    ) -> [UUID] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tokens = trimmed.split { !$0.isLetter && !$0.isNumber }.map(String.init)

        let filtered: [StorageIndexEntry] = entries.values.filter { entry in
            let typeMatch = types.isEmpty || types.contains(entry.entityType)
            guard typeMatch else { return false }

            guard !trimmed.isEmpty else { return true }

            if entry.normalizedSearchText.contains(trimmed) {
                return true
            }

            guard !tokens.isEmpty else { return false }
            return tokens.allSatisfy { token in
                entry.tokens.contains { $0.hasPrefix(token) }
            }
        }

        switch sort {
        case .titleAscending:
            return filtered.sorted { $0.normalizedTitle < $1.normalizedTitle }.map(\.id)
        case .mostRecent:
            return filtered.sorted { $0.primaryDate > $1.primaryDate }.map(\.id)
        }
    }
}
