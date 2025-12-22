//
//  RootsIOSApp.swift
//  Roots (iOS)
//

#if os(iOS)
import SwiftUI
import Combine

@main
struct RootsIOSApp: App {
    @StateObject private var coursesStore: CoursesStore
    @StateObject private var appSettings = AppSettingsModel.shared
    @StateObject private var settingsCoordinator: SettingsCoordinator
    @StateObject private var gradesStore = GradesStore.shared
    @StateObject private var plannerStore = PlannerStore.shared
    @StateObject private var plannerCoordinator = PlannerCoordinator.shared
    @StateObject private var assignmentPlansStore = AssignmentPlansStore.shared
    @StateObject private var sheetRouter = IOSSheetRouter()
    @StateObject private var toastRouter = IOSToastRouter()
    @StateObject private var filterState = IOSFilterState()
    @StateObject private var appModel = AppModel()
    @StateObject private var calendarManager = CalendarManager.shared
    @StateObject private var deviceCalendar = DeviceCalendarManager.shared
    @StateObject private var timerManager = TimerManager()
    @StateObject private var focusManager = FocusManager()
    @StateObject private var preferences = AppPreferences()
    @StateObject private var parsingStore = SyllabusParsingStore.shared
    @StateObject private var eventsCountStore = EventsCountStore()

    init() {
        let store = CoursesStore()
        _coursesStore = StateObject(wrappedValue: store)
        let settings = AppSettingsModel.shared
        _settingsCoordinator = StateObject(wrappedValue: SettingsCoordinator(appSettings: settings, coursesStore: store))
        if UserDefaults.standard.data(forKey: "roots.settings.appsettings") == nil {
            settings.visibleTabs = TabRegistry.defaultEnabledTabs
            settings.tabOrder = TabRegistry.allTabs.map { $0.id }
            settings.save()
        }
    }

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(AssignmentsStore.shared)
                .environmentObject(coursesStore)
                .environmentObject(appSettings)
                .environmentObject(appModel)
                .environmentObject(settingsCoordinator)
                .environmentObject(eventsCountStore)
                .environmentObject(calendarManager)
                .environmentObject(DeviceCalendarManager.shared)
                .environmentObject(timerManager)
                .environmentObject(focusManager)
                .environmentObject(FlashcardManager.shared)
                .environmentObject(preferences)
                .environmentObject(gradesStore)
                .environmentObject(plannerStore)
                .environmentObject(plannerCoordinator)
                .environmentObject(assignmentPlansStore)
                .environmentObject(parsingStore)
                .environmentObject(sheetRouter)
                .environmentObject(toastRouter)
                .environmentObject(filterState)
                .onAppear {
                    preferences.highContrast = appSettings.highContrastMode
                    preferences.reduceTransparency = appSettings.increaseTransparency
                    if let g = appSettings.glassIntensity { preferences.glassIntensity = g }
                }
        }
    }
}
#endif
