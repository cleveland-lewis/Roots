import Foundation

enum EducationLevel: String, Codable, CaseIterable, Identifiable {
    case middleSchool = "Middle School"
    case highSchool = "High School"
    case college = "College"
    case gradSchool = "Graduate School"

    var id: String { rawValue }

    var semesterTypes: [SemesterType] {
        switch self {
        case .middleSchool, .highSchool:
            return [.fall, .spring, .summerI, .summerII]
        case .college:
            return [.fall, .spring, .summerI, .winter]
        case .gradSchool:
            return [.fall, .spring, .winter, .summerI, .summerII]
        }
    }
}

enum SemesterType: String, Codable, CaseIterable, Identifiable {
    case fall = "Fall"
    case winter = "Winter"
    case spring = "Spring"
    case summerI = "Summer I"
    case summerII = "Summer II"

    var id: String { rawValue }
}

enum GradSchoolProgram: String, Codable, CaseIterable, Identifiable {
    case masters = "Master's (MA/MS)"
    case phd = "PhD"
    case md = "MD"
    case jd = "JD"
    case mba = "MBA"
    case mfa = "MFA"
    case edd = "EdD"
    case other = "Other"

    var id: String { rawValue }
}

struct Semester: Identifiable, Codable, Hashable {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var isCurrent: Bool
    var educationLevel: EducationLevel
    var semesterTerm: SemesterType
    var gradProgram: GradSchoolProgram?
    var isArchived: Bool
    var deletedAt: Date?
    var academicYear: String? // e.g., "2024-2025"
    var notes: String?

    // computed default name
    var defaultName: String {
        "\(semesterTerm.rawValue) \(Calendar.current.component(.year, from: startDate))"
    }

    var name: String { defaultName }

    init(id: UUID = UUID(),
         startDate: Date,
         endDate: Date,
         isCurrent: Bool = false,
         educationLevel: EducationLevel = .college,
         semesterTerm: SemesterType = .fall,
         gradProgram: GradSchoolProgram? = nil,
         isArchived: Bool = false,
         deletedAt: Date? = nil,
         academicYear: String? = nil,
         notes: String? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
        self.educationLevel = educationLevel
        self.semesterTerm = semesterTerm
        self.gradProgram = gradProgram
        self.isArchived = isArchived
        self.deletedAt = deletedAt
        self.academicYear = academicYear
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, isCurrent, educationLevel, semesterTerm, gradProgram, isArchived, deletedAt, academicYear, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        isCurrent = try container.decode(Bool.self, forKey: .isCurrent)
        educationLevel = try container.decodeIfPresent(EducationLevel.self, forKey: .educationLevel) ?? .college
        semesterTerm = try container.decodeIfPresent(SemesterType.self, forKey: .semesterTerm) ?? .fall
        gradProgram = try container.decodeIfPresent(GradSchoolProgram.self, forKey: .gradProgram)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        academicYear = try container.decodeIfPresent(String.self, forKey: .academicYear)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

enum CourseType: String, Codable, CaseIterable, Identifiable {
    case regular = "Regular"
    case honors = "Honors"
    case ap = "AP"
    case ib = "IB"
    case dualEnrollment = "Dual Enrollment"
    case seminar = "Seminar"
    case lab = "Lab"
    case independent = "Independent Study"
    case thesis = "Thesis/Dissertation"
    case clinical = "Clinical"
    case practicum = "Practicum"
    case other = "Other"

    var id: String { rawValue }
}

enum CreditType: String, Codable, CaseIterable, Identifiable {
    case credits = "Credits"
    case units = "Units"
    case hours = "Hours"
    case none = "None"

    var id: String { rawValue }
}

struct Course: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var code: String
    var semesterId: UUID
    var colorHex: String?
    var isArchived: Bool
    var courseType: CourseType
    var instructor: String?
    var location: String?
    var credits: Double?
    var creditType: CreditType
    var meetingTimes: String? // e.g., "MWF 9:00-10:00"
    var syllabus: String? // URL or notes
    var notes: String?
    var attachments: [Attachment]

    init(id: UUID = UUID(),
         title: String,
         code: String,
         semesterId: UUID,
         colorHex: String? = nil,
         isArchived: Bool = false,
         courseType: CourseType = .regular,
         instructor: String? = nil,
         location: String? = nil,
         credits: Double? = nil,
         creditType: CreditType = .credits,
         meetingTimes: String? = nil,
         syllabus: String? = nil,
         notes: String? = nil,
         attachments: [Attachment] = []) {
        self.id = id
        self.title = title
        self.code = code
        self.semesterId = semesterId
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.courseType = courseType
        self.instructor = instructor
        self.location = location
        self.credits = credits
        self.creditType = creditType
        self.meetingTimes = meetingTimes
        self.syllabus = syllabus
        self.notes = notes
        self.attachments = attachments
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, code, semesterId, colorHex, isArchived, courseType, instructor, location, credits, creditType, meetingTimes, syllabus, notes, attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        code = try container.decode(String.self, forKey: .code)
        semesterId = try container.decode(UUID.self, forKey: .semesterId)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        courseType = try container.decodeIfPresent(CourseType.self, forKey: .courseType) ?? .regular
        instructor = try container.decodeIfPresent(String.self, forKey: .instructor)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        credits = try container.decodeIfPresent(Double.self, forKey: .credits)
        creditType = try container.decodeIfPresent(CreditType.self, forKey: .creditType) ?? .credits
        meetingTimes = try container.decodeIfPresent(String.self, forKey: .meetingTimes)
        syllabus = try container.decodeIfPresent(String.self, forKey: .syllabus)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
    }
    
    /// Get display name based on user's preference
    func displayName(mode: CourseDisplayMode? = nil) -> String {
        let displayMode = mode ?? CourseDisplayMode.from(userDefaults: .standard)
        
        switch displayMode {
        case .name:
            return title
        case .code:
            return code.isEmpty ? title : code
        case .both:
            if code.isEmpty {
                return title
            } else {
                return "\(code) - \(title)"
            }
        }
    }
}

// MARK: - Course Display Mode

public enum CourseDisplayMode: String, Codable {
    case name
    case code
    case both
    
    public static func from(userDefaults: UserDefaults) -> CourseDisplayMode {
        let rawValue = userDefaults.string(forKey: "courseDisplayMode") ?? "both"
        return CourseDisplayMode(rawValue: rawValue) ?? .both
    }
}

protocol CourseLinkable {
    var courseId: UUID { get set }
}

// MARK: - Course Outline System

enum CourseOutlineNodeType: String, Codable, CaseIterable, Identifiable {
    case module = "Module"
    case unit = "Unit"
    case section = "Section"
    case chapter = "Chapter"
    case part = "Part"
    case lesson = "Lesson"
    
    var id: String { rawValue }
}

struct CourseOutlineNode: Identifiable, Codable, Hashable {
    var id: UUID
    var courseId: UUID
    var parentId: UUID?  // nil means root node
    var type: CourseOutlineNodeType
    var title: String
    var sortIndex: Int  // Deterministic ordering within siblings
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        courseId: UUID,
        parentId: UUID? = nil,
        type: CourseOutlineNodeType,
        title: String,
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.parentId = parentId
        self.type = type
        self.title = title
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Helper to check if this is a root node
    var isRoot: Bool {
        parentId == nil
    }
}

// MARK: - Course Files

struct CourseFile: Identifiable, Codable, Hashable {
    var id: UUID
    var courseId: UUID
    var nodeId: UUID?  // nil means attached to course root
    var filename: String
    var fileType: String  // e.g., "pdf", "docx"
    var localURL: String?  // File path or bookmark data
    var isSyllabus: Bool
    var isPracticeExam: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        courseId: UUID,
        nodeId: UUID? = nil,
        filename: String,
        fileType: String = "",
        localURL: String? = nil,
        isSyllabus: Bool = false,
        isPracticeExam: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.nodeId = nodeId
        self.filename = filename
        self.fileType = fileType
        self.localURL = localURL
        self.isSyllabus = isSyllabus
        self.isPracticeExam = isPracticeExam
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
