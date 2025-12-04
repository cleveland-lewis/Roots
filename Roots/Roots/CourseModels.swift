import Foundation

struct Semester: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var isCurrent: Bool

    init(id: UUID = UUID(),
         name: String,
         startDate: Date,
         endDate: Date,
         isCurrent: Bool = false) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
    }
}

struct Course: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var code: String
    var semesterId: UUID
    var colorHex: String?
    var isArchived: Bool

    init(id: UUID = UUID(),
         title: String,
         code: String,
         semesterId: UUID,
         colorHex: String? = nil,
         isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.code = code
        self.semesterId = semesterId
        self.colorHex = colorHex
        self.isArchived = isArchived
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, code, semesterId, colorHex, isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        code = try container.decode(String.self, forKey: .code)
        semesterId = try container.decode(UUID.self, forKey: .semesterId)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}

protocol CourseLinkable {
    var courseId: UUID { get set }
}
