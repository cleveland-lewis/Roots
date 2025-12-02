import SwiftUI
import Combine

struct TimerPageView: View {
    @ObservedObject var viewModel: TimerPageViewModel
    @Binding var currentMode: TimerMode

    @State private var showActivityEditor: Bool = false
    @State private var editingActivity: TimerActivity?
    @State private var lowerSection: LowerSection = .activities
    @State private var graphMode: TimerGraphsView.GraphMode = .live
    @State private var isMenuOpen: Bool = false

    private enum LowerSection { case activities, graphs }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.6), Color.blue.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    TimerHeaderView(now: viewModel.now, isMenuOpen: $isMenuOpen, onAdd: {
                        editingActivity = nil
                        showActivityEditor = true
                    }, onSettings: { LOG_UI(.info, "Timer", "Settings tapped") })

                    modeSelector

                    VStack(spacing: 16) {
                        TimerControlsView(viewModel: viewModel, currentMode: $currentMode)
                        CurrentActivityView(viewModel: viewModel) {
                            lowerSection = .activities
                        }
                    }

                    segmentedControl

                    if lowerSection == .activities {
                        ActivityListView(viewModel: viewModel, onAdd: { editingActivity = nil; showActivityEditor = true }) { activity in
                            editingActivity = activity
                            showActivityEditor = true
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        TimerGraphsView(mode: $graphMode, sessions: viewModel.pastSessions, currentSession: viewModel.currentSession, sessionElapsed: viewModel.sessionElapsed, sessionRemaining: viewModel.sessionRemaining)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: currentMode) { newValue in
            if viewModel.currentMode != newValue { viewModel.currentMode = newValue }
        }
        .onChange(of: viewModel.currentMode) { newValue in
            if currentMode != newValue { currentMode = newValue }
        }
        .sheet(isPresented: $showActivityEditor) {
            ActivityEditorView(activity: editingActivity, collections: viewModel.collections, onSave: { activity in
                if let existing = viewModel.activities.first(where: { $0.id == activity.id }) {
                    viewModel.updateActivity(activity)
                    viewModel.selectActivity(activity.id)
                    LOG_UI(.info, "Timer", "Updated activity \(existing.id)")
                } else {
                    viewModel.addActivity(activity)
                    viewModel.selectActivity(activity.id)
                }
                showActivityEditor = false
                isMenuOpen = false
            }, onCancel: {
                showActivityEditor = false
                isMenuOpen = false
            })
            .presentationDetents([.medium, .large])
        }
    }

    private var modeSelector: some View {
        HStack {
            Picker("Mode", selection: $currentMode) {
                ForEach(TimerMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var segmentedControl: some View {
        HStack(spacing: 12) {
            segmentButton(title: "Activities", isSelected: lowerSection == .activities) { lowerSection = .activities }
            segmentButton(title: "Graphs", isSelected: lowerSection == .graphs) { lowerSection = .graphs }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func segmentButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct TimerPageView_Previews: PreviewProvider {
    static var previews: some View {
        TimerPageView(viewModel: TimerPageViewModel(), currentMode: .constant(.omodoro))
            .environment(\.colorScheme, .dark)
            .environmentObject(AppSettingsModel.shared)
    }
}
