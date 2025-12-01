import XCTest
@testable import Roots

@MainActor
final class CoursesStoreTests: XCTestCase {

    func testPersistenceRoundTrip() throws {
        // temp dir
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let storageURL = tmpDir.appendingPathComponent("courses.json")

        // first store
        do {
            let store = CoursesStore(storageURL: storageURL)
            let start = Date()
            let end = Calendar.current.date(byAdding: .month, value: 4, to: start) ?? start

            let fall = Semester(name: "Fall 2025", startDate: start, endDate: end, isCurrent: true)
            store.addSemester(fall)
            store.setCurrentSemester(fall)

            store.addCourse(title: "Neurobiology", code: "BIO 440", to: fall)
            store.addCourse(title: "Physics I", code: "PHY 211", to: fall)
        }

        // second store load
        do {
            let store = CoursesStore(storageURL: storageURL)
            XCTAssertEqual(store.semesters.count, 1)
            XCTAssertEqual(store.courses.count, 2)

            let semester = try XCTUnwrap(store.semesters.first)
            XCTAssertEqual(semester.name, "Fall 2025")
            XCTAssertTrue(semester.isCurrent)

            XCTAssertEqual(store.currentSemesterId, semester.id)

            let fallCourses = store.currentSemesterCourses
            XCTAssertEqual(fallCourses.count, 2)
            XCTAssertEqual(Set(fallCourses.map({ $0.code })), ["BIO 440", "PHY 211"]) 
        }
    }
}
