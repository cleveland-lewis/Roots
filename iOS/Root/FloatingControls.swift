#if os(iOS)
import SwiftUI

struct FloatingControls: View {
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var navigation: IOSNavigationCoordinator
    @EnvironmentObject private var sheetRouter: IOSSheetRouter
    @EnvironmentObject private var toastRouter: IOSToastRouter
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var plannerStore: PlannerStore
    @EnvironmentObject private var filterState: IOSFilterState

    let safeInsets: EdgeInsets
    
    private var buttonSize: CGFloat {
        settings.largeTapTargets ? 64 : 52
    }

    var body: some View {
        HStack(spacing: 16) {
            menuButton
            Spacer()
            quickAddButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, safeInsets.bottom + 12)
    }

    private var menuButton: some View {
        Menu {
            ForEach(allMenuPages, id: \.self) { page in
                Button {
                    let starred = settings.starredTabs
                    navigation.open(page: page, starredTabs: starred)
                } label: {
                    Label(menuTitle(for: page), systemImage: page.systemImage)
                }
            }

            Divider()

            Button {
                navigation.openSettings()
            } label: {
                Label(NSLocalizedString("ios.menu.settings", comment: "Settings"), systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: buttonSize * 0.4, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: buttonSize, height: buttonSize)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                .contentShape(Rectangle().size(width: buttonSize + 8, height: buttonSize + 8))
        }
        .accessibilityLabel(NSLocalizedString("ios.menu.hamburger", comment: "Open menu"))
    }

    private var quickAddButton: some View {
        Menu {
            Button {
                handleQuickAction(.add_assignment)
            } label: {
                Label(NSLocalizedString("ios.menu.add_assignment", comment: "Add Assignment"), systemImage: "plus.square.on.square")
            }

            Button {
                handleQuickAction(.add_grade)
            } label: {
                Label(NSLocalizedString("ios.menu.add_grade", comment: "Add Grade"), systemImage: "number.circle")
            }

            Button {
                handleQuickAction(.auto_schedule)
            } label: {
                Label(NSLocalizedString("ios.menu.auto_schedule", comment: "Auto Schedule"), systemImage: "calendar.badge.clock")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: buttonSize * 0.4, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: buttonSize, height: buttonSize)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                .contentShape(Rectangle().size(width: buttonSize + 8, height: buttonSize + 8))
        }
        .accessibilityLabel(NSLocalizedString("ios.menu.quick_add", comment: "Quick add"))
    }

    private var allMenuPages: [AppPage] {
        [
            .dashboard,
            .calendar,
            .planner,
            .assignments,
            .courses,
            .timer,
            .practice
        ]
    }

    private func menuTitle(for page: AppPage) -> String {
        switch page {
        case .assignments:
            return NSLocalizedString("ios.menu.tasks", comment: "Tasks")
        default:
            return page.title
        }
    }

    private func handleQuickAction(_ action: QuickAction) {
        switch action {
        case .add_assignment:
            let defaults = IOSSheetRouter.TaskDefaults(
                courseId: filterState.selectedCourseId,
                dueDate: Date(),
                title: "",
                type: .practiceHomework,
                itemLabel: "Assignment"
            )
            sheetRouter.activeSheet = .addAssignment(defaults)
        case .add_grade:
            sheetRouter.activeSheet = .addGrade(UUID())
        case .auto_schedule:
            autoSchedule()
        default:
            break
        }
    }

    private func autoSchedule() {
        let assignments = assignmentsForPlanning()
        guard !assignments.isEmpty else {
            toastRouter.show(NSLocalizedString("ios.toast.no_tasks_schedule", comment: "No tasks to schedule"))
            return
        }
        let settings = StudyPlanSettings()
        let sessions = assignments.flatMap { PlannerEngine.generateSessions(for: $0, settings: settings) }
        let result = PlannerEngine.scheduleSessions(sessions, settings: settings, energyProfile: defaultEnergyProfile())
        plannerStore.persist(scheduled: result.scheduled, overflow: result.overflow)
        toastRouter.show(NSLocalizedString("ios.toast.schedule_updated", comment: "Schedule updated"))
    }

    private func assignmentsForPlanning() -> [Assignment] {
        let today = Calendar.current.startOfDay(for: Date())
        return filteredTasks.compactMap { task in
            guard !task.isCompleted, let due = task.due else { return nil }
            if due < today { return nil }
            return Assignment(
                id: task.id,
                courseId: task.courseId,
                title: task.title,
                dueDate: due,
                estimatedMinutes: task.estimatedMinutes,
                weightPercent: nil,
                category: category(for: task),
                urgency: urgency(for: task.importance),
                isLockedToDueDate: task.locked,
                plan: []
            )
        }
    }

    private var filteredTasks: [AppTask] {
        let courseLookup = coursesStore.courses
        return assignmentsStore.tasks.filter { task in
            guard let courseId = task.courseId else {
                return filterState.selectedCourseId == nil && filterState.selectedSemesterId == nil
            }
            if let selectedCourse = filterState.selectedCourseId, selectedCourse != courseId {
                return false
            }
            if let semesterId = filterState.selectedSemesterId,
               let course = courseLookup.first(where: { $0.id == courseId }),
               course.semesterId != semesterId {
                return false
            }
            return true
        }
    }

    private func category(for task: AppTask) -> AssignmentCategory {
        switch task.category {
        case .exam: return .exam
        case .quiz: return .quiz
        case .practiceHomework: return .practiceHomework
        case .reading: return .reading
        case .review: return .review
        case .project: return .project
        }
    }

    private func urgency(for value: Double) -> AssignmentUrgency {
        switch value {
        case ..<0.3: return .low
        case ..<0.6: return .medium
        case ..<0.85: return .high
        default: return .critical
        }
    }

    private func defaultEnergyProfile() -> [Int: Double] {
        [
            9: 0.55, 10: 0.65, 11: 0.7, 12: 0.6,
            13: 0.5, 14: 0.55, 15: 0.65, 16: 0.7,
            17: 0.6, 18: 0.5, 19: 0.45, 20: 0.4
        ]
    }
}
#endif
