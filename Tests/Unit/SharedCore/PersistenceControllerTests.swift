import XCTest
import CoreData
@testable import Roots

final class PersistenceControllerTests: XCTestCase {
    func testInsertAndFetchCourse() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext

        let course = NSEntityDescription.insertNewObject(forEntityName: "Course", into: context)
        course.setValue(UUID(), forKey: "id")
        course.setValue("Test Course", forKey: "title")

        controller.save(context: context)

        let request = NSFetchRequest<NSManagedObject>(entityName: "Course")
        let results = try context.fetch(request)
        XCTAssertEqual(results.count, 1)
    }

    func testUpdatedAtChangesOnEdit() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext

        let course = NSEntityDescription.insertNewObject(forEntityName: "Course", into: context)
        course.setValue(UUID(), forKey: "id")
        course.setValue("History 101", forKey: "title")
        controller.save(context: context)

        let firstUpdatedAt = course.value(forKey: "updatedAt") as? Date
        XCTAssertNotNil(firstUpdatedAt)

        course.setValue("History 102", forKey: "title")
        controller.save(context: context)

        let secondUpdatedAt = course.value(forKey: "updatedAt") as? Date
        XCTAssertNotNil(secondUpdatedAt)
        XCTAssertNotEqual(firstUpdatedAt, secondUpdatedAt)
    }
}
