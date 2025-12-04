//
//  RootsApp.swift
//  Roots
//
//  Created by Cleveland Lewis III on 11/30/25.
//

import SwiftUI
import SwiftData

@main
struct RootsApp: App {
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var coursesStore: CoursesStore
    @StateObject private var appSettings = AppSettingsModel.shared
    @StateObject private var settingsCoordinator: SettingsCoordinator
    @StateObject private var appModel = AppModel()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = CoursesStore()
        _coursesStore = StateObject(wrappedValue: store)
        _settingsCoordinator = StateObject(wrappedValue: SettingsCoordinator(appSettings: AppSettingsModel.shared, coursesStore: store))
        _ = DeveloperSettingsSynchronizer.shared
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AssignmentsStore.shared)
                .environmentObject(permissionsManager)
                .environmentObject(coursesStore)
                .environmentObject(appSettings)
                .environmentObject(appModel)
                .environmentObject(settingsCoordinator)
                .environmentObject(EventsCountStore())
                .accentColor(appSettings.activeAccentColor)
                .buttonStyle(.glassBlueProminent)
                .controlSize(.regular)
                .buttonBorderShape(.automatic)
                .tint(appSettings.activeAccentColor)
                .frame(minWidth: RootsWindowSizing.minMainWidth, minHeight: RootsWindowSizing.minMainHeight)
                .task {
                    // Run adaptation on launch
                    SchedulerAdaptationManager.shared.runAdaptiveSchedulerUpdateIfNeeded()
                    // Request calendar/reminder access immediately on launch
                    permissionsManager.requestCalendarIfNeeded()
                    permissionsManager.requestRemindersIfNeeded()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                appSettings.save()
            }
        }
        .commands {
            AppCommands()
            SettingsCommands(showSettings: {
                settingsCoordinator.show()
            })
        }
        .modelContainer(sharedModelContainer)
    }
}
