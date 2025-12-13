//
//  RootsApp.swift
//  Roots
//
//  Created by Cleveland Lewis III on 11/30/25.
//

import SwiftUI
import _Concurrency
import Combine
#if !DISABLE_SWIFTDATA
import SwiftData
#endif

@main
struct RootsApp: App {

    @StateObject private var coursesStore: CoursesStore
    @StateObject private var appSettings = AppSettingsModel.shared
    @StateObject private var settingsCoordinator: SettingsCoordinator
    @StateObject private var gradesStore = GradesStore.shared
    @StateObject private var plannerStore = PlannerStore.shared
    @StateObject private var plannerCoordinator = PlannerCoordinator.shared
    @StateObject private var appModel = AppModel()
    @StateObject private var calendarManager = CalendarManager.shared
    @StateObject private var deviceCalendar = DeviceCalendarManager.shared
    @StateObject private var timerManager = TimerManager()
    @StateObject private var focusManager = FocusManager()
    @StateObject private var preferences = AppPreferences()

    @Environment(\.scenePhase) private var scenePhase

    private var menuBarManager: MenuBarManager

    init() {
        let store = CoursesStore()
        _coursesStore = StateObject(wrappedValue: store)
        let settings = AppSettingsModel.shared
        _appSettings = StateObject(wrappedValue: settings)
        _settingsCoordinator = StateObject(wrappedValue: SettingsCoordinator(appSettings: settings, coursesStore: store))
        let assignments = AssignmentsStore.shared
        let timer = TimerManager()
        _timerManager = StateObject(wrappedValue: timer)
        let focus = FocusManager()
        _focusManager = StateObject(wrappedValue: focus)
        menuBarManager = MenuBarManager(focusManager: focus, assignmentsStore: assignments, settings: settings)
        _ = DeveloperSettingsSynchronizer.shared
    }

#if !DISABLE_SWIFTDATA
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            AssignmentPlan.self,
            PlanStep.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
#endif

    @State private var resetCancellable: AnyCancellable? = nil

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AssignmentsStore.shared)
                .environmentObject(coursesStore)
                .environmentObject(appSettings)
                .environmentObject(appModel)
                .environmentObject(settingsCoordinator)
                .environmentObject(EventsCountStore())
                .environmentObject(calendarManager)
                .environmentObject(DeviceCalendarManager.shared)
                .environmentObject(timerManager)
                .environmentObject(focusManager)
                .environmentObject(FlashcardManager.shared)
                .environmentObject(preferences)
                .environmentObject(gradesStore)
                .environmentObject(plannerStore)
                .environmentObject(plannerCoordinator)
                .onAppear {
                    // Sync stored AppSettingsModel -> AppPreferences on launch
                    preferences.highContrast = appSettings.highContrastMode
                    preferences.reduceTransparency = appSettings.increaseTransparency
                    if let g = appSettings.glassIntensity { preferences.glassIntensity = g }

                    // Subscribe to app reset requests from AppModel
                    resetCancellable = AppModel.shared.resetPublisher
                        .receive(on: DispatchQueue.main)
                        .sink { _ in
                            // perform global resets
                            AssignmentsStore.shared.resetAll()
                            CoursesStore.shared?.resetAll()
                            PlannerStore.shared.reset()
                            GradesStore.shared.resetAll()
                        }
                }
                .onChange(of: preferences.highContrast) { _, newValue in
                    appSettings.highContrastMode = newValue
                    appSettings.save()
                }
                .onChange(of: preferences.reduceTransparency) { _, newValue in
                    appSettings.increaseTransparency = newValue
                    appSettings.save()
                }
                // Reverse sync: when saved AppSettingsModel values change (from other settings UI), update AppPreferences
                .onReceive(appSettings.objectWillChange) { _ in
                    preferences.highContrast = appSettings.highContrastMode
                    preferences.reduceTransparency = appSettings.increaseTransparency
                    if let g = appSettings.glassIntensity { preferences.glassIntensity = g }
                }
                .accentColor(preferences.currentAccentColor)
                .buttonStyle(.glassBlueProminent)
                .controlSize(.regular)
                .buttonBorderShape(.automatic)
                .tint(preferences.currentAccentColor)
                .frame(minWidth: RootsWindowSizing.minMainWidth, minHeight: RootsWindowSizing.minMainHeight)
                .task {
                    // Run adaptation on launch
                    SchedulerAdaptationManager.shared.runAdaptiveSchedulerUpdateIfNeeded()
                    // Refresh and request permissions on launch
                    await calendarManager.checkPermissionsOnStartup()
                    await calendarManager.planTodayIfNeeded(tasks: AssignmentsStore.shared.tasks)
                    timerManager.checkNotificationPermissions()
                    
                    // Schedule daily overview if enabled
                    if appSettings.dailyOverviewEnabled {
                        NotificationManager.shared.scheduleDailyOverview()
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
#if !DISABLE_SWIFTDATA
        .modelContainer(sharedModelContainer)
#endif
#if os(macOS)
        Settings {
            SettingsRootView(selection: $settingsCoordinator.selectedSection)
                .environmentObject(AssignmentsStore.shared)
                .environmentObject(coursesStore)
                .environmentObject(appSettings)
                .environmentObject(appModel)
                .environmentObject(settingsCoordinator)
                .environmentObject(EventsCountStore())
                .environmentObject(calendarManager)
                .environmentObject(timerManager)
                .environmentObject(focusManager)
                .environmentObject(FlashcardManager.shared)
                .environmentObject(preferences)
                .environmentObject(gradesStore)
                .environmentObject(plannerStore)
        }
        .commands {
            AppCommands()
            SettingsCommands(showSettings: {
                settingsCoordinator.show()
            })
        }
#endif
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .background || phase == .inactive {
            appSettings.save()
        } else if phase == .active {
            _Concurrency.Task {
                await calendarManager.checkPermissionsOnStartup()
                await calendarManager.planTodayIfNeeded(tasks: AssignmentsStore.shared.tasks)
            }
            NotificationManager.shared.clearBadge()
        }
    }
}
