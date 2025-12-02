import SwiftUI
import AppKit

final class SettingsWindowController: NSWindowController {
    private static let lastPaneKey = "roots.settings.lastSelectedPane"
    private let appSettings: AppSettingsModel

    init(appSettings: AppSettingsModel) {
        self.appSettings = appSettings
        let savedPane = UserDefaults.standard.string(forKey: Self.lastPaneKey)
        let initialPane = SettingsToolbarIdentifier(rawValue: savedPane ?? "") ?? .general

        // Create a placeholder handler to avoid capturing self before super.init
        var onSelectPane: ((SettingsToolbarIdentifier) -> Void)? = nil
        let rootView = SettingsRootView(initialPane: initialPane) { pane in
            onSelectPane?(pane)
        }

        let hostingController = NSHostingController(rootView: rootView.environmentObject(appSettings))
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 580, height: 430))
        window.minSize = NSSize(width: 580, height: 430)
        window.maxSize = NSSize(width: 580, height: 430)
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.miniaturizeButton)?.alphaValue = 0.35
        window.standardWindowButton(.zoomButton)?.alphaValue = 0.35
        window.isMovableByWindowBackground = true
        window.toolbarStyle = .unifiedCompact
        window.collectionBehavior = [.transient]
        window.center()

        super.init(window: window)

        // Now that super.init has run, safely reference self
        window.toolbar?.allowsUserCustomization = false
        window.toolbar?.showsBaselineSeparator = true
        window.toolbar?.displayMode = .iconAndLabel
        window.toolbar?.sizeMode = .small
        updateTitle(for: initialPane)

        // Wire the callback to use self methods
        onSelectPane = { [weak self] pane in
            self?.updateTitle(for: pane)
            self?.persistPane(pane)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSettings() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateTitle(for pane: SettingsToolbarIdentifier) {
        window?.title = pane.windowTitle
    }

    private func persistPane(_ pane: SettingsToolbarIdentifier) {
        UserDefaults.standard.set(pane.rawValue, forKey: Self.lastPaneKey)
    }
}
