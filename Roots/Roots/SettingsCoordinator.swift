import SwiftUI
import Combine
import AppKit

@MainActor
final class SettingsCoordinator: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private let appSettings: AppSettingsModel
    private lazy var windowController: SettingsWindowController = {
        SettingsWindowController(appSettings: appSettings)
    }()

    init(appSettings: AppSettingsModel) {
        self.appSettings = appSettings
    }

    func show() {
        windowController.showSettings()
    }
}
