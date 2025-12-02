import SwiftUI

struct TimerPageView: View {
    @StateObject var vm: TimerPageViewModel
    @EnvironmentObject var appSettings: AppSettingsModel

    @State private var now: Date = Date()
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var graphMode: TimerGraphsView.GraphMode = .live

    var body: some View {
        VStack(spacing: 18) {
            // Top: Time & Date
            HStack {
                VStack(alignment: .leading) {
                    Text(now, style: .time)
                        .font(.largeTitle).fontWeight(.semibold)
                    Text(now, formatter: DateFormatter.longDate)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // Mode indicator
                Picker("Mode", selection: $vm.currentMode) {
                    ForEach(TimerMode.allCases, id: \.self) { m in
                        Label(m.rawValue.capitalized, systemImage: m == .omodoro ? "hourglass" : (m == .timer ? "timer" : "stopwatch"))
                            .tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Middle: Activity + Timer
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    currentActivityView
                    TimerControlsView(vm: vm)
                }
                .frame(minWidth: 360)

                VStack(alignment: .leading, spacing: 12) {
                    Picker("Graphs", selection: $graphMode) {
                        Text("Live").tag(TimerGraphsView.GraphMode.live)
                        Text("History").tag(TimerGraphsView.GraphMode.history)
                    }
                    .pickerStyle(.segmented)
                    TimerGraphsView(mode: graphMode, sessions: vm.pastSessions, currentSession: vm.currentSession)
                }
                .frame(minWidth: 360)
            }

            // Bottom: Activities & Collections
            HStack(spacing: 16) {
                ActivityListView(vm: vm)
                    .frame(minWidth: 360)
                VStack(alignment: .leading) {
                    Text("Collections")
                        .font(.headline)
                    Picker("Collection", selection: Binding(get: { vm.selectedCollectionID }, set: { vm.selectedCollectionID = $0 })) {
                        Text("All").tag(UUID?.none)
                        ForEach(vm.collections) { c in
                            Text(c.name).tag(Optional(c.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()
                }
                .frame(width: 220)
            }
        }
        .padding()
        .onReceive(clockTimer) { d in now = d }
    }

    private var currentActivityView: some View {
        Group {
            if let id = vm.currentActivityID, let act = vm.activities.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if let emoji = act.emoji { Text(emoji).font(.largeTitle) }
                        Text(act.name).font(.title2).fontWeight(.semibold)
                    }

                    HStack(spacing: 8) {
                        if let cat = act.studyCategory { Text(cat.rawValue.capitalized).font(.caption).foregroundColor(.secondary) }
                        if let course = act.courseID { Text("Course") .font(.caption).foregroundColor(.secondary) }
                        if let assn = act.assignmentID { Text("Assignment") .font(.caption).foregroundColor(.secondary) }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No activity selected")
                        .font(.title2)
                    Button("Create New Activity") {
                        let a = TimerActivity(name: "New Activity")
                        vm.addActivity(a)
                        vm.selectActivity(a.id)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
}

// MARK: - DateFormatter helper
fileprivate extension DateFormatter {
    static var longDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()
}
