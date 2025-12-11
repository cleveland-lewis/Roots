import Foundation

// Minimal Attachment model to satisfy AIScheduler and other references.
// Keep fields minimal; expand if other compile errors request additional properties.
public struct Attachment: Codable, Equatable, Hashable {
    public let id: UUID
    public let name: String?
    public let localURL: URL?
    public let dateAdded: Date?

    public init(id: UUID = UUID(), name: String? = nil, localURL: URL? = nil, dateAdded: Date? = nil) {
        self.id = id
        self.name = name
        self.localURL = localURL
        self.dateAdded = dateAdded
    }
}
