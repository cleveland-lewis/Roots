#if os(macOS)
import SwiftUI

struct TimerView: View {
    @State private var secondsRemaining: Int = 25 * 60
    @State private var isRunning: Bool = false
    @State private var timer: Timer? = nil
    @State private var activities: [String] = [
        "Math HW · 45m",
        "CS Project · 90m",
        "Reading · 30m",
        "Exam Prep · 60m"
    ]

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .top, spacing: 16) {
                // Left column: Activities list
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Activities")
                            .font(DesignSystem.Typography.subHeader)
                        Spacer()
                        Button {
                            // placeholder for add action
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    List(activities, id: \.self) { item in
                        Text(item)
                            .padding(.vertical, 4)
                    }
                }
                .frame(width: 350)
                .frame(maxHeight: .infinity)
                .glassCard(cornerRadius: 20)

                // Right column: Dashboard stack
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        // Timer takes ~60% width
                        timerCard
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)

                        // Pie chart takes ~40% width
                        CategoryPieChart(initialRange: .today)
                            .frame(maxWidth: proxy.size.width * 0.35)
                    }
                    .frame(height: 300)

                    // Bar chart spanning the width
                    StudyHistoryBarChart(initialRange: .thisWeek)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .onDisappear { stopTimer() }
    }

    private var timerCard: some View {
        VStack(spacing: 16) {
            Text(timeString(from: secondsRemaining))
                .font(DesignSystem.Typography.body)
                .monospacedDigit()

            HStack(spacing: 16) {
                Button(action: toggleRunning) {
                    Label(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(LegacyGlassProminentButtonStyle())

                Button("Reset") {
                    reset()
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .glassCard(cornerRadius: 20)
    }

    private func toggleRunning() {
        isRunning ? stopTimer() : startTimer()
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
#endif
