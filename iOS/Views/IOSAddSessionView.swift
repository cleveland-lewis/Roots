//
//  IOSAddSessionView.swift
//  Roots (iOS)
//

#if os(iOS)
import SwiftUI

struct IOSAddSessionView: View {
    @ObservedObject var viewModel: TimerPageViewModel
    let onDismiss: () -> Void
    
    @State private var selectedMode: TimerMode = .pomodoro
    @State private var durationMinutes: Int = 25
    @State private var durationSeconds: Int = 0
    @State private var sessionDate: Date = Date()
    @State private var selectedActivityID: UUID? = nil
    
    private var isValid: Bool {
        durationMinutes > 0 || durationSeconds > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Session Type") {
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(TimerMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.systemImage)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Duration") {
                    HStack {
                        Stepper("\(durationMinutes) min", value: $durationMinutes, in: 0...999)
                    }
                    HStack {
                        Stepper("\(durationSeconds) sec", value: $durationSeconds, in: 0...59)
                    }
                }
                
                Section("When") {
                    DatePicker("Date & Time", selection: $sessionDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Activity") {
                    Picker("Link to Activity", selection: $selectedActivityID) {
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
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveSession()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func saveSession() {
        let totalSeconds = TimeInterval(durationMinutes * 60 + durationSeconds)
        guard totalSeconds > 0 else { return }
        
        let session = FocusSession(
            activityID: selectedActivityID,
            mode: selectedMode,
            plannedDuration: totalSeconds,
            startedAt: sessionDate,
            endedAt: sessionDate.addingTimeInterval(totalSeconds),
            state: .completed,
            actualDuration: totalSeconds,
            interruptions: 0
        )
        
        viewModel.addManualSession(session)
        onDismiss()
    }
}
#endif
