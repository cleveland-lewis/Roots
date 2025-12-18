import Foundation
import EventKit
import Combine

@MainActor
final class DeviceCalendarManager: ObservableObject {
    static let shared = DeviceCalendarManager()

    let store = EKEventStore()

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var events: [EKEvent] = []

    @Published private(set) var lastRefreshAt: Date? = nil
    @Published private(set) var isObservingStoreChanges: Bool = false
    @Published private(set) var lastRefreshReason: String? = nil

    private var storeChangedObserver: Any?

    private init() {}

    func bootstrapOnLaunch() async {
        let granted = await requestFullAccessIfNeeded()
        await MainActor.run { self.isAuthorized = granted }
        guard granted else { return }

        startObservingStoreChanges()
        await refreshEventsForVisibleRange(reason: "launch")
    }

    func refreshEventsForVisibleRange(reason: String = "rangeRefresh") async {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -30, to: .now)!
        let end   = cal.date(byAdding: .day, value:  90, to: .now)!

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let fetched = store.events(matching: predicate)

        await MainActor.run {
            self.events = fetched
            self.lastRefreshAt = Date()
            self.lastRefreshReason = reason
        }
    }

    func requestFullAccessIfNeeded() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess:
            return true
        case .writeOnly:
            return true
        case .notDetermined:
            if #available(macOS 14.0, *) {
                do {
                    return try await store.requestFullAccessToEvents()
                } catch {
                    return false
                }
            } else {
                return await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { granted, _ in cont.resume(returning: granted) }
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func refreshEventsForVisibleRange() async {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -30, to: .now)!
        let end   = cal.date(byAdding: .day, value:  90, to: .now)!

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let fetched = store.events(matching: predicate)

        await MainActor.run {
            self.events = fetched
        }
    }

    func startObservingStoreChanges() {
        guard storeChangedObserver == nil else { return }

        storeChangedObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.refreshEventsForVisibleRange(reason: "storeChanged") }
        }

        isObservingStoreChanges = true
    }
}
