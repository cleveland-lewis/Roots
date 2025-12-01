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

    init(id: UUID = UUID(),
         title: String,
         code: String,
         semesterId: UUID,
         colorHex: String? = nil) {
        self.id = id
        self.title = title
        self.code = code
        self.semesterId = semesterId
        self.colorHex = colorHex
    }
}

protocol CourseLinkable {
    var courseId: UUID { get set }
}
