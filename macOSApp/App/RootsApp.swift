//
//  RootsApp.swift
//  Roots (macOS)
//

#if os(macOS)
import SwiftUI
import Combine
#if !DISABLE_SWIFTDATA
import SwiftData
#endif
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.set(false, forKey: "ApplePersistenceIgnoreState")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            let windows = NSApplication.shared.windows.filter { window in
                window.className.contains("SwiftUI") || window.title.isEmpty == false
            }
            if windows.count > 1 {
                for window in windows.dropFirst() {
                    LOG_LIFECYCLE(.warn, "WindowManagement", "Closing duplicate window: \(window.title)")
                    window.close()
                }
            }
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { false }

    func application(_ app: NSApplication, didDecodeRestorableState coder: NSCoder) {
        // noop
    }

    func application(_ application: NSApplication, willEncodeRestorableState coder: NSCoder) {
        // noop
    }
}

@main
struct RootsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
    @StateObject private var parsingStore = SyllabusParsingStore.shared
    @StateObject private var eventsCountStore = EventsCountStore()

    @Environment(\.scenePhase) private var scenePhase

    private var menuBarManager: MenuBarManager

    init() {
        LOG_LIFECYCLE(.info, "AppInit", "RootsApp initializing")
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
        LOG_LIFECYCLE(.info, "AppInit", "RootsApp initialization complete")
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
        WindowGroup(id: "main") {
            applyUITestOverrides(
                to: ContentView()
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
                    .environmentObject(parsingStore)
                    .detectReduceMotion()
                    .onOpenURL { url in
                        _ = DeepLinkRouter.shared.handle(
                            url: url,
                            appModel: appModel,
                            plannerCoordinator: plannerCoordinator,
                            calendarManager: calendarManager,
                            settingsCoordinator: settingsCoordinator
                        )
                    }
                    .onAppear {
                        LOG_LIFECYCLE(.info, "ViewLifecycle", "Main window appeared")
                        preferences.highContrast = appSettings.highContrastMode
                        preferences.reduceTransparency = appSettings.increaseTransparency
                        if let g = appSettings.glassIntensity { preferences.glassIntensity = g }

                        resetCancellable = AppModel.shared.resetPublisher
                            .receive(on: DispatchQueue.main)
                            .sink { _ in
                                LOG_LIFECYCLE(.warn, "AppReset", "Global app reset requested")
                                AssignmentsStore.shared.resetAll()
                                CoursesStore.shared?.resetAll()
                                PlannerStore.shared.reset()
                                GradesStore.shared.resetAll()
                                LOG_LIFECYCLE(.info, "AppReset", "Global app reset complete")
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
                        LOG_LIFECYCLE(.info, "AppStartup", "Running startup tasks")
                        SchedulerAdaptationManager.shared.runAdaptiveSchedulerUpdateIfNeeded()
                        await calendarManager.checkPermissionsOnStartup()
                        await calendarManager.planTodayIfNeeded(tasks: AssignmentsStore.shared.tasks)
                        timerManager.checkNotificationPermissions()
                        
                        if appSettings.dailyOverviewEnabled {
                            LOG_NOTIFICATIONS(.info, "DailyOverview", "Scheduling daily overview notification")
                            NotificationManager.shared.scheduleDailyOverview()
                        }
                        LOG_LIFECYCLE(.info, "AppStartup", "Startup tasks complete")
                    }
            )
        }
        .handlesExternalEvents(matching: Set<String>())
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
#if !DISABLE_SWIFTDATA
        .modelContainer(sharedModelContainer)
#endif
        Settings {
            applyUITestOverrides(
                to: SettingsRootView(selection: $settingsCoordinator.selectedSection)
                    .environmentObject(AssignmentsStore.shared)
                    .environmentObject(coursesStore)
                    .environmentObject(appSettings)
                    .environmentObject(appModel)
                    .environmentObject(settingsCoordinator)
                    .environmentObject(eventsCountStore)
                    .environmentObject(calendarManager)
                    .environmentObject(timerManager)
                    .environmentObject(focusManager)
                    .environmentObject(FlashcardManager.shared)
                    .environmentObject(preferences)
                    .environmentObject(gradesStore)
                    .environmentObject(plannerStore)
                    .environmentObject(parsingStore)
            )
        }
        .commands {
            AppCommands()
            SettingsCommands(showSettings: {
                settingsCoordinator.show()
            })
        }
    }

    private var uiTestColorSchemeOverride: ColorScheme? {
        guard let raw = ProcessInfo.processInfo.environment["UITEST_COLOR_SCHEME"] else { return nil }
        return raw.lowercased() == "dark" ? .dark : .light
    }

    private var uiTestSizeCategoryOverride: ContentSizeCategory? {
        guard let raw = ProcessInfo.processInfo.environment["UITEST_CONTENT_SIZE"] else { return nil }
        return sizeCategory(for: raw)
    }

    private var shouldDisableAnimationsForUITests: Bool {
        ProcessInfo.processInfo.environment["UITEST_DISABLE_ANIMATIONS"] == "1"
    }

    @ViewBuilder
    private func applyUITestOverrides<Content: View>(to content: Content) -> some View {
        let colored = content.preferredColorScheme(uiTestColorSchemeOverride)
        if let sizeCategory = uiTestSizeCategoryOverride {
            colored
                .environment(\.sizeCategory, sizeCategory)
                .transaction { txn in
                    if shouldDisableAnimationsForUITests { txn.animation = nil }
                }
        } else {
            colored
                .transaction { txn in
                    if shouldDisableAnimationsForUITests { txn.animation = nil }
                }
        }
    }

    private func sizeCategory(for raw: String) -> ContentSizeCategory? {
        // Map common UIKit-style identifiers used in UI tests to SwiftUI categories.
        switch raw {
        case "UICTContentSizeCategoryXS": return .extraSmall
        case "UICTContentSizeCategoryS": return .small
        case "UICTContentSizeCategoryM": return .medium
        case "UICTContentSizeCategoryL": return .large
        case "UICTContentSizeCategoryXL": return .extraLarge
        case "UICTContentSizeCategoryXXL": return .extraExtraLarge
        case "UICTContentSizeCategoryXXXL": return .extraExtraExtraLarge
        case "UICTContentSizeCategoryAccessibilityM": return .accessibilityMedium
        case "UICTContentSizeCategoryAccessibilityL": return .accessibilityLarge
        case "UICTContentSizeCategoryAccessibilityXL": return .accessibilityExtraLarge
        case "UICTContentSizeCategoryAccessibilityXXL": return .accessibilityExtraExtraLarge
        case "UICTContentSizeCategoryAccessibilityXXXL": return .accessibilityExtraExtraExtraLarge
        default: return nil
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        LOG_LIFECYCLE(.info, "ScenePhase", "Scene phase changed to: \(phase)")
        if phase == .background || phase == .inactive {
            LOG_LIFECYCLE(.info, "ScenePhase", "App entering background, saving settings")
            appSettings.save()
        } else if phase == .active {
            LOG_LIFECYCLE(.info, "ScenePhase", "App became active, refreshing calendar")
            _Concurrency.Task {
                await calendarManager.checkPermissionsOnStartup()
                await calendarManager.planTodayIfNeeded(tasks: AssignmentsStore.shared.tasks)
            }
            NotificationManager.shared.clearBadge()
        }
    }
}
#elseif os(iOS)
import SwiftUI
import Combine

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
    @StateObject private var parsingStore = SyllabusParsingStore.shared
    @StateObject private var eventsCountStore = EventsCountStore()

    init() {
        let store = CoursesStore()
        _coursesStore = StateObject(wrappedValue: store)
        let settings = AppSettingsModel.shared
        _settingsCoordinator = StateObject(wrappedValue: SettingsCoordinator(appSettings: settings, coursesStore: store))
    }

    var body: some Scene {
        WindowGroup {
            IOSContentView()
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
                .environmentObject(parsingStore)
                .onAppear {
                    preferences.highContrast = appSettings.highContrastMode
                    preferences.reduceTransparency = appSettings.increaseTransparency
                    if let g = appSettings.glassIntensity { preferences.glassIntensity = g }
                }
        }
    }
}

struct IOSContentView: View {
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        Text("Roots iOS - Coming Soon")
            .font(.largeTitle)
            .padding()
    }
}
#endif
