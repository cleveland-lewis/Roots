import SwiftUI
import Combine

struct TimerControlsView: View {
    @ObservedObject var vm: TimerPageViewModel
    @State private var countdown: TimeInterval = 25*60
    @State private var elapsed: TimeInterval = 0
    @State private var timerCancellable: AnyCancellable? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(label: Label("Timer", systemImage: "timer")) {
                VStack(spacing: 12) {
                    Text(displayString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    HStack(spacing: 12) {
                        Button(action: startPause) {
                            Image(systemName: vm.currentSession?.state == .running ? "pause.fill" : "play.fill")
                            Text(vm.currentSession?.state == .running ? "Pause" : "Start")
                        }
                        .buttonStyle(.glassProminent)

                        Button("Reset") { vm.endSession(completed: false) }
                            .buttonStyle(.glass)
                    }

                    if vm.currentMode == .omodoro {
                        HStack {
                            Text("Segment: ")
                            Text(vm.currentSession?.mode == .omodoro ? "Focus" : "Break")
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var displayString: String {
        if vm.currentMode == .stopwatch {
            let e = elapsed
            return formatted(seconds: Int(e))
        } else {
            let s = Int(countdown)
            return formatted(seconds: s)
        }
    }

    private func formatted(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func startPause() {
        if vm.currentSession?.state == .running {
            vm.pauseSession()
            timerCancellable?.cancel()
        } else {
            vm.startSession(mode: vm.currentMode, plannedDuration: countdown)
            // start a simple timer
            timerCancellable = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
                .sink { _ in
                    if vm.currentMode == .stopwatch {
                        elapsed += 1
                    } else {
                        if countdown > 0 { countdown -= 1 } else { vm.endSession(completed: true); timerCancellable?.cancel() }
                    }
                }
        }
    }
}
