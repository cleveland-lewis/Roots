#if os(macOS)
import SwiftUI
import Combine

// MARK: - Settings Category Enum

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case calendar = "Calendar"
    case reminders = "Reminders"
    case planner = "Planner"
    case courses = "Courses"
    case semesters = "Semesters"
    case interface = "Interface"
    case profiles = "Profiles"
    case account = "Account"
    case privacy = "Privacy & Security"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .calendar: return "calendar"
        case .reminders: return "list.bullet"
        case .planner: return "pencil.and.list.clipboard"
        case .courses: return "book.closed"
        case .semesters: return "calendar"
        case .interface: return "macwindow"
        case .profiles: return "person.crop.circle"
        case .account: return "person.text.rectangle"
        case .privacy: return "lock.shield"
        }
    }
}

// MARK: - Settings Root View

struct SettingsRootView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @EnvironmentObject var coursesStore: CoursesStore
    @Binding private var selectedPane: SettingsToolbarIdentifier

    init(selection: Binding<SettingsToolbarIdentifier>) {
        _selectedPane = selection
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsToolbarIdentifier.allCases, selection: $selectedPane) { pane in
                NavigationLink(value: pane) {
                    Label(pane.label, systemImage: pane.systemImageName)
                }
            }
            .navigationTitle("Settings")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            Group {
                switch selectedPane {
                case .general:
                    GeneralSettingsView()
                case .calendar:
                    CalendarSettingsView()
                case .reminders:
                    RemindersSettingsView()
                case .planner:
                    PlannerSettingsView()
                case .courses:
                    CoursesSettingsView()
                case .semesters:
                    SemestersSettingsView()
                case .interface:
                    InterfaceSettingsView()
                case .profiles:
                    ProfilesSettingsView()
                case .timer:
                    TimerSettingsView()
                case .flashcards:
                    FlashcardSettingsView()
                case .notifications:
                    NotificationsSettingsView()
                case .privacy:
                    PrivacySettingsView()
                case .developer:
                    DeveloperSettingsView()
                }
            }
            .id(selectedPane)
            .frame(minWidth: 400, minHeight: 400)
        }
        .navigationSplitViewStyle(.balanced)
        .hideSplitViewDivider()
        .frame(minWidth: 600, minHeight: 400)
    }
}
#endif
