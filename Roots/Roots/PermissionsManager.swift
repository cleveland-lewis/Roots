import Foundation
import Combine
import EventKit
import SwiftUI

final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    private let eventStore = EKEventStore()

    @Published var calendarStatus: EKAuthorizationStatus = .notDetermined
    @Published var remindersStatus: EKAuthorizationStatus = .notDetermined

    private init() {
        refreshStatuses()
    }

    func refreshStatuses() {
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
        remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    func requestCalendarIfNeeded(completion: @escaping () -> Void = {}) {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .notDetermined else {
            completion()
            return
        }
        eventStore.requestAccess(to: .event) { _, _ in
            DispatchQueue.main.async {
                self.refreshStatuses()
                completion()
            }
        }
    }

    func requestRemindersIfNeeded(completion: @escaping () -> Void = {}) {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .notDetermined else {
            completion()
            return
        }
        eventStore.requestAccess(to: .reminder) { _, _ in
            DispatchQueue.main.async {
                self.refreshStatuses()
                completion()
            }
        }
    }
}
