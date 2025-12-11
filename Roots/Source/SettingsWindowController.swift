import SwiftUI
import AppKit
import Combine

final class SettingsWindowController: NSWindowController {
    static let lastPaneKey = "roots.settings.lastSelectedPane"
    private let appSettings: AppSettingsModel
    private let coursesStore: CoursesStore
    private let coordinator: SettingsCoordinator
    private var selectionCancellable: AnyCancellable?

    init(appSettings: AppSettingsModel, coursesStore: CoursesStore, coordinator: SettingsCoordinator) {
        // Assign stored properties first
        self.appSettings = appSettings
        self.coursesStore = coursesStore
        self.coordinator = coordinator

        // Capture initial values without touching self
        let initialPane = coordinator.selectedSection

        // Build binding and views without referencing self
        let selectionBinding = Binding<SettingsToolbarIdentifier>(
            get: { coordinator.selectedSection },
            set: { newValue in
                guard coordinator.selectedSection != newValue else { return }
                DispatchQueue.main.async {
                    coordinator.selectedSection = newValue
                }
            }
        )

        let hostingController = NSHostingController(rootView: SettingsWindowController.makeRootView(
            selection: selectionBinding,
            appSettings: appSettings,
            coursesStore: coursesStore,
            coordinator: coordinator
        ))
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: RootsWindowSizing.minSettingsWidth, height: RootsWindowSizing.minSettingsHeight))
        window.minSize = NSSize(width: RootsWindowSizing.minSettingsWidth, height: RootsWindowSizing.minSettingsHeight)
        RootsWindowSizing.applyMinimumSize(to: window, role: .settings)
        window.title = initialPane.windowTitle
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.toolbarStyle = .unifiedCompact
        window.collectionBehavior = [.transient]
        window.center()

        // Create toolbar; set delegate after super.init
        let toolbar = NSToolbar(identifier: "roots.settings.toolbar")
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel
        window.toolbar = toolbar

        // Call super before any use of self
        super.init(window: window)

        // Now that self exists, set toolbar delegate to self
        toolbar.delegate = self

        DispatchQueue.main.async { [weak self] in
            self?.window?.toolbar?.selectedItemIdentifier = initialPane.toolbarItemIdentifier
            self?.updateTitle(for: initialPane)
        }

        // Set up selection sink observing coordinator
        selectionCancellable = coordinator.$selectedSection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pane in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.window?.toolbar?.selectedItemIdentifier = pane.toolbarItemIdentifier
                    self.updateTitle(for: pane)
                    self.persistPane(pane)
                    if let navController = self.contentViewController as? NSHostingController<AnyView> {
                        let selectionBinding = Binding<SettingsToolbarIdentifier>(
                            get: { self.coordinator.selectedSection },
                            set: { newValue in self.coordinator.selectedSection = newValue }
                        )
                        navController.rootView = SettingsWindowController.makeRootView(
                            selection: selectionBinding,
                            appSettings: self.appSettings,
                            coursesStore: self.coursesStore,
                            coordinator: self.coordinator
                        )
                    }
                }
            }
    }

    private static func makeRootView(
        selection: Binding<SettingsToolbarIdentifier>,
        appSettings: AppSettingsModel,
        coursesStore: CoursesStore,
        coordinator: SettingsCoordinator
    ) -> AnyView {
        AnyView(
            SettingsRootView(selection: selection)
                .environmentObject(AssignmentsStore.shared)
                .environmentObject(appSettings)
                .environmentObject(coursesStore)
                .environmentObject(GradesStore.shared)
                .environmentObject(PlannerStore.shared)
                .environmentObject(AppModel())
                .environmentObject(coordinator)
                .environmentObject(EventsCountStore())
                .environmentObject(CalendarManager.shared)
                .environmentObject(TimerManager())
                .environmentObject(FlashcardManager.shared)
                .environmentObject(AppPreferences())
        )
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

// MARK: - Toolbar delegate

extension SettingsWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsToolbarIdentifier.allCases.map { $0.toolbarItemIdentifier }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let pane = SettingsToolbarIdentifier.allCases.first(where: { $0.toolbarItemIdentifier == itemIdentifier }) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = pane.label
        item.image = NSImage(systemSymbolName: pane.systemImageName, accessibilityDescription: pane.label)
        item.target = self
        item.action = #selector(selectPane(_:))
        return item
    }

    @objc private func selectPane(_ sender: NSToolbarItem) {
        guard let pane = SettingsToolbarIdentifier.allCases.first(where: { $0.toolbarItemIdentifier == sender.itemIdentifier }) else { return }
        DispatchQueue.main.async {
            self.coordinator.selectedSection = pane
        }
    }
}
