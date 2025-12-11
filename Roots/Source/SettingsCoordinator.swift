import SwiftUI
import Combine
import AppKit

@MainActor
final class SettingsCoordinator: ObservableObject {
    @Published var selectedSection: SettingsToolbarIdentifier = .general

    private let appSettings: AppSettingsModel
    private let coursesStore: CoursesStore
    private lazy var windowController: SettingsWindowController = {
        SettingsWindowController(
            appSettings: appSettings,
            coursesStore: coursesStore,
            coordinator: self
        )
    }()

    init(appSettings: AppSettingsModel, coursesStore: CoursesStore) {
        self.appSettings = appSettings
        self.coursesStore = coursesStore
        if let stored = UserDefaults.standard.string(forKey: SettingsWindowController.lastPaneKey),
           let pane = SettingsToolbarIdentifier(rawValue: stored) {
            selectedSection = pane
        }
    }

    func show() {
        windowController.showSettings()
    }

    func show(selecting section: SettingsToolbarIdentifier) {
        selectedSection = section
        windowController.showSettings()
    }

    func show(selecting paneRawValue: String) {
        if let section = SettingsToolbarIdentifier(rawValue: paneRawValue) {
            show(selecting: section)
        } else {
            show()
        }
    }
}

extension Notification.Name {
    static let selectSettingsPane = Notification.Name("roots.settings.selectPane")
}
