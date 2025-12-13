import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var assignmentsStore: AssignmentsStore
    @ObservedObject var settings: AppSettingsModel
    
    private var assignmentsLeftToday: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfTomorrow = calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        return assignmentsStore.tasks.filter { task in
            guard !task.isCompleted, let due = task.due else { return false }
            return due < startOfTomorrow
        }.count
    }

    private var totalStudyTimeToday: String {
        let todaySessions = viewModel.sessions.filter {
            guard let endedAt = $0.endDate else { return false }
            return Calendar.current.isDateInToday(endedAt)
        }
        
        let totalSeconds = todaySessions.reduce(0.0) { total, session in
            if session.mode == .pomodoro && !viewModel.isPomodorBreak {
                return total + session.duration
            } else if session.mode != .pomodoro {
                return total + session.duration
            }
            return total
        }
        
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: modeIcon)
                    .foregroundColor(.secondary)
                Text(viewModel.mode.label)
                    .font(.headline)
                Spacer()
                Text(viewModel.isRunning ? "Running" : "Paused")
                    .font(.caption)
                    .foregroundColor(viewModel.isRunning ? .green : .secondary)
            }

            if viewModel.mode == .pomodoro {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isPomodorBreak ? "cup.and.saucer" : "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.isPomodorBreak ? "Break" : "Work")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Assignments left today:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(assignmentsLeftToday)")
                        .font(.subheadline)
                        .bold()
                }

                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Study time today:")
                        .font(.subheadline)
                    Spacer()
                    Text(totalStudyTimeToday)
                        .font(.subheadline)
                        .bold()
                }
                
                if let activity = viewModel.activities.first(where: { $0.id == viewModel.selectedActivityID }) {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.caption)
                            .foregroundColor(Color(activity.colorTag.color))
                        Text("Activity:")
                            .font(.subheadline)
                        Spacer()
                        Text(activity.name)
                            .font(.subheadline)
                            .bold()
                            .lineLimit(1)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button(viewModel.isRunning ? "Pause" : "Start") {
                    if viewModel.isRunning {
                        NotificationCenter.default.post(name: .timerStopRequested, object: nil)
                    } else {
                        NotificationCenter.default.post(name: .timerStartRequested, object: nil)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("End") {
                    NotificationCenter.default.post(name: .timerEndRequested, object: nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 280)
    }
    
    private var modeIcon: String {
        switch viewModel.mode {
        case .pomodoro:
            return "timer"
        case .countdown:
            return "timer"
        case .stopwatch:
            return "stopwatch"
        }
    }
}


