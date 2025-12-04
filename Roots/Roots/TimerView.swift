import SwiftUI

struct TimerView: View {
    @State private var secondsRemaining: Int = 25 * 60
    @State private var isRunning: Bool = false
    @State private var timer: Timer? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text(timeString(from: secondsRemaining))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 16) {
                Button(action: toggleRunning) {
                    Label(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.glassProminent)

                Button("Reset") {
                    reset()
                }
                .buttonStyle(.glass)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onDisappear { stopTimer() }
        .rootsSystemBackground()
    }

    private func toggleRunning() {
        if isRunning { stopTimer() } else { startTimer() }
    }

    private func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                stopTimer()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func reset() {
        stopTimer()
        secondsRemaining = 25 * 60
    }

    private func timeString(from seconds: Int) -> String {
        let min = seconds / 60
        let sec = seconds % 60
        return String(format: "%02d:%02d", min, sec)
    }
}
