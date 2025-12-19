import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Roots")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.cwlewisiii.Roots")
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Persistent store load failed: \(error.localizedDescription)")
            }
        }

        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext.automaticallyMergesChangesFromParent = true
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func saveViewContext() {
        save(context: viewContext)
    }

    func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        touchTimestamps(in: context)
        do {
            try context.save()
        } catch {
            LOG_DATA(.error, "Persistence", "Failed to save context: \(error.localizedDescription)")
        }
    }

    private func touchTimestamps(in context: NSManagedObjectContext) {
        let now = Date()
        for object in context.insertedObjects {
            if object.value(forKey: "createdAt") == nil {
                object.setValue(now, forKey: "createdAt")
            }
            object.setValue(now, forKey: "updatedAt")
        }
        for object in context.updatedObjects {
            object.setValue(now, forKey: "updatedAt")
        }
    }
}
