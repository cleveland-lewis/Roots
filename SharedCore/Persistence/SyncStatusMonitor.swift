import Combine
import CoreData
import Foundation

@MainActor
final class SyncStatusMonitor: ObservableObject {
    static let shared = SyncStatusMonitor(container: PersistenceController.shared.container)

    @Published private(set) var lastRemoteChangeAt: Date?
    @Published private(set) var lastEventDescription: String?
    @Published private(set) var lastErrorDescription: String?

    private var cancellables: Set<AnyCancellable> = []

    private init(container: NSPersistentCloudKitContainer) {
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.lastRemoteChangeAt = Date()
                self?.lastEventDescription = "Remote change notification"
                LOG_SYNC(.debug, "CloudKit", "Received NSPersistentStoreRemoteChange")
                if let error = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSError {
                    self?.lastErrorDescription = error.localizedDescription
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
                self?.lastEventDescription = String(describing: event.type)
                LOG_SYNC(.debug, "CloudKit", "Mirroring event: \(event.type)")
                if let error = event.error {
                    self?.lastErrorDescription = error.localizedDescription
                }
            }
            .store(in: &cancellables)

        if container.viewContext.persistentStoreCoordinator == nil {
            lastErrorDescription = "Persistent store coordinator is unavailable"
        }
    }
}
