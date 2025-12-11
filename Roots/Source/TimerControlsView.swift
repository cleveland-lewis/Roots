import SwiftUI

struct TimerControlsView: View {
    @ObservedObject var viewModel: TimerPageViewModel
    @Binding var currentMode: TimerMode

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: DesignSystem.Layout.spacing.small) {
                Text(timeDisplay)
                    .font(DesignSystem.Typography.body)
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .shadow(color: Color(nsColor: .separatorColor).opacity(0.08), radius: 10, x: 0, y: 10)

                Text(modeSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            HStack(spacing: 12) {
                if viewModel.currentSession?.state == .running {
                    button(label: "Pause", systemImage: "pause.fill", prominent: true) { viewModel.pauseSession() }
                } else if viewModel.currentSession?.state == .paused {
                    button(label: "Resume", systemImage: "play.fill", prominent: true) { viewModel.resumeSession() }
                } else {
                    button(label: "Start", systemImage: "play.fill", prominent: true) { viewModel.startSession(plannedDuration: currentMode == .timer ? viewModel.timerDuration : nil) }
                }

                button(label: viewModel.currentSession == nil ? "Reset" : "End", systemImage: "stop.fill", prominent: false) {
                    if viewModel.currentSession == nil {
                        resetDefaults()
                    } else {
                        viewModel.endSession(completed: false)
                    }
                }
            }

            if currentMode == .pomodoro {
                HStack(spacing: 12) {
                    durationControl(title: "Focus", duration: $viewModel.focusDuration, symbol: "flame")
                    durationControl(title: "Break", duration: $viewModel.breakDuration, symbol: "cup.and.saucer")
                    Label(viewModel.isOnBreak ? "Break" : "Focus", systemImage: viewModel.isOnBreak ? "leaf" : "bolt.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
                }
            } else if currentMode == .timer {
                durationControl(title: "Duration", duration: $viewModel.timerDuration, symbol: "clock")
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .background(DesignSystem.Materials.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func button(label: String, systemImage: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        let style = prominent ? AnyButtonStyle(GlassBlueProminentButtonStyle()) : AnyButtonStyle(GlassButtonStyle())
        return Button(action: action) {
            Label(label, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(style)
    }

    private func durationControl(title: String, duration: Binding<TimeInterval>, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack {
                Slider(value: Binding(get: { duration.wrappedValue / 60 }, set: { duration.wrappedValue = $0 * 60 }), in: 5...120, step: 5)
                Text("\(Int(duration.wrappedValue / 60))m")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 44)
            }
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
    }

    private var timeDisplay: String {
        if let session = viewModel.currentSession, session.state != .idle {
            if session.mode == .stopwatch {
                return format(seconds: Int(viewModel.sessionElapsed))
            } else {
                let remaining = viewModel.sessionRemaining > 0 ? viewModel.sessionRemaining : (session.plannedDuration ?? 0)
                return format(seconds: Int(remaining))
            }
        }

        switch currentMode {
        case .pomodoro:
            return format(seconds: Int(viewModel.focusDuration))
        case .timer:
            return format(seconds: Int(viewModel.timerDuration))
        case .stopwatch:
            return "00:00"
        }
    }

    private var modeSubtitle: String {
        switch currentMode {
        case .pomodoro:
            return viewModel.isOnBreak ? "Pomodoro — Break" : "Pomodoro — Focus Block"
        case .timer:
            return "Timer — Countdown"
        case .stopwatch:
            return "Stopwatch"
        }
    }

    private func format(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func resetDefaults() {
        viewModel.sessionElapsed = 0
        viewModel.sessionRemaining = 0
    }
}
