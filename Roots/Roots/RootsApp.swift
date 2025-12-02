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
    @StateObject private var coursesStore = CoursesStore()
    @StateObject private var appSettings = AppSettingsModel.shared
    private let settingsWindowController = SettingsWindowController(appSettings: AppSettingsModel.shared)
    @StateObject private var appModel = AppModel()

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
                .buttonStyle(.glassBlueProminent)
                .controlSize(.regular)
                .buttonBorderShape(.automatic)
                .tint(.accentColor)
                .task {
                    // Run adaptation on launch
                    SchedulerAdaptationManager.shared.runAdaptiveSchedulerUpdateIfNeeded()
                }
        }
        .commands {
            AppCommands()
            SettingsCommands(showSettings: {
                settingsWindowController.showSettings()
            })
        }
        .modelContainer(sharedModelContainer)
    }
}
