#if os(iOS)
import SwiftUI

struct AddSessionSheet: View {
    @ObservedObject var viewModel: TimerPageViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: TimerMode = .pomodoro
    @State private var durationMinutes: Int = 25
    @State private var occurredAt: Date = Date()
    @State private var selectedActivityID: UUID? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Type") {
                    Picker("Session Type", selection: $mode) {
                        ForEach(TimerMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Duration") {
                    Stepper(value: $durationMinutes, in: 0...480, step: 5) {
                        Text("\(durationMinutes) min")
                    }
                }
                Section("Date & Time") {
                    DatePicker("Occurred", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                }
                Section("Activity") {
                    Picker("Activity", selection: $selectedActivityID) {
                        Text("None").tag(UUID?.none)
                        ForEach(viewModel.activities) { activity in
                            Text(activity.name).tag(Optional(activity.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Add Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveSession() }
                        .disabled(shouldDisableSave)
                }
            }
            .onChange(of: mode) { _, newMode in
                if newMode == .stopwatch && durationMinutes == 0 {
                    return
                }
                if durationMinutes == 0 && newMode != .stopwatch {
                    durationMinutes = 25
                }
            }
        }
    }

    private var shouldDisableSave: Bool {
        mode != .stopwatch && durationMinutes <= 0
    }

    private func saveSession() {
        let durationSeconds = TimeInterval(max(durationMinutes, 0) * 60)
        let endDate = occurredAt.addingTimeInterval(durationSeconds)
        let plannedDuration: TimeInterval? = mode == .stopwatch ? nil : durationSeconds
        let session = FocusSession(
            activityID: selectedActivityID,
            mode: mode,
            plannedDuration: plannedDuration,
            startedAt: occurredAt,
            endedAt: endDate,
            state: .completed,
            actualDuration: durationSeconds
        )
        viewModel.addManualSession(session)
        dismiss()
    }
}
#endif
