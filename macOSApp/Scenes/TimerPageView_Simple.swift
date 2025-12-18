#if os(macOS)
import SwiftUI
import Combine

struct TimerPageView_Simple: View {
    // Phase 1: Environment Objects ✅ ALL WORK!
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator
    
    // Phase 2.1: Basic State Variables ✅
    @State private var mode: LocalTimerMode = .pomodoro
    @State private var activities: [LocalTimerActivity] = []
    @State private var selectedActivityID: UUID? = nil
    @State private var showActivityEditor: Bool = false
    @State private var editingActivity: LocalTimerActivity? = nil
    
    // Phase 2.2: Timer State Variables ✅
    @State private var isRunning: Bool = false
    @State private var remainingSeconds: TimeInterval = 0
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var pomodoroSessions: Int = 4
    @State private var completedPomodoroSessions: Int = 0
    @State private var isPomodorBreak: Bool = false
    @State private var sessions: [LocalTimerSession] = []
    @State private var loadedSessions = false
    @State private var tickCancellable: AnyCancellable?
    
    // Phase 3.1: Simple Computed Property (collections) ✅
    private var collections: [String] {
        var set: Set<String> = ["All"]
        set.formUnion(activities.map { $0.category })
        return Array(set).sorted()
    }
    
    // Phase 3.2: Cached Computed Properties
    @State private var cachedPinnedActivities: [LocalTimerActivity] = []
    @State private var cachedFilteredActivities: [LocalTimerActivity] = []
    @State private var searchText: String = ""
    @State private var selectedCollection: String = "All"
    
    // Phase 6.7: Activity notes
    @State private var activityNotes: [UUID: String] = [:]
    
    private var pinnedActivities: [LocalTimerActivity] {
        cachedPinnedActivities
    }
    
    private var filteredActivities: [LocalTimerActivity] {
        cachedFilteredActivities
    }
    
    private func updateCachedValues() {
        cachedPinnedActivities = activities.filter { $0.isPinned }
        
        let query = searchText.lowercased()
        cachedFilteredActivities = activities.filter { activity in
            (!activity.isPinned) &&
            (selectedCollection == "All" || activity.category.lowercased().contains(selectedCollection.lowercased())) &&
            (query.isEmpty || activity.name.lowercased().contains(query) || activity.category.lowercased().contains(query))
        }
    }
    
    // Minimal timer functions for testing
    private func startTickTimer() {
        print("⏱️  startTickTimer() called - creating Timer publisher")
        stopTickTimer()
        
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                print("⏱️  Timer tick")
            }
        print("⏱️  Timer started successfully")
    }
    
    private func stopTickTimer() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }
    
    // Phase 6.7: Save notes function
    private func saveNotes(_ notes: String, for activityID: UUID) {
        print("💾 Saving notes for activity \(activityID): \(notes.prefix(20))...")
        // In real implementation, this would save to disk
    }
    
    // Minimal implementations for testing
    private func loadSessions() {
        print("💾 loadSessions() - would load from disk asynchronously")
        // Intentionally empty - just testing if calling it causes freeze
    }
    
    private func syncTimerWithAssignment() {
        print("🔄 syncTimerWithAssignment() - checking if assignment exists")
        // Intentionally minimal - just checking call doesn't freeze
    }
    
    // MARK: - Subviews
    
    private var totalToday: TimeInterval {
        activities.reduce(0) { $0 + $1.todayTrackedSeconds }
    }
    
    private var currentActivity: LocalTimerActivity? {
        activities.first(where: { $0.id == selectedActivityID }) ?? activities.first
    }
    
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            Spacer()
            // Top spacer only; time/date removed per request
            Spacer()
        }
    }
    
    // Phase 6.7: FULL three-column layout WITH TextEditor
    private var mainGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            activitiesColumn
            timerAndDetailColumn
            rightPane
        }
        .frame(maxWidth: .infinity)
    }
    
    private var activitiesColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Activities")
                        .font(.body)
                    Spacer()
                }
                
                collectionsFilter
                
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                activityList
            }
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 350)
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
    }
    
    private var timerAndDetailColumn: some View {
        VStack(spacing: 16) {
                timerCoreCard
                
                // Activity detail panel WITH TextEditor
                VStack(alignment: .leading, spacing: 12) {
                    if let activity = currentActivity {
                        Text("Selected: \(activity.name)")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: Binding(
                                get: { activityNotes[activity.id] ?? "" },
                                set: { newValue in
                                    activityNotes[activity.id] = newValue
                                    saveNotes(newValue, for: activity.id)
                                })
                            )
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Text("🔧 Phase 6.7: TextEditor with custom Binding ADDED")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("No activity selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
            .frame(minWidth: 300, idealWidth: 400, maxWidth: 500)
    }
    
    private var collectionsFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(collections, id: \.self) { collection in
                    let isSelected = selectedCollection == collection
                    Button(action: { selectedCollection = collection }) {
                        Text(collection)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 32)
    }
    
    private var activityList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !cachedPinnedActivities.isEmpty {
                    Text("Pinned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(cachedPinnedActivities) { activity in
                        activityRow(activity)
                    }
                }
                
                Text("All Activities")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(cachedFilteredActivities) { activity in
                    activityRow(activity)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func activityRow(_ activity: LocalTimerActivity) -> some View {
        Button(action: { selectedActivityID = activity.id }) {
            HStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text(activity.name)
                    .font(.body)
                Spacer()
                if selectedActivityID == activity.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(8)
            .background(selectedActivityID == activity.id ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 12) {
                Text("Study Summary")
                    .font(.headline)
                
                Text("Activities: \(activities.count)")
                    .font(.caption)
            }
            .frame(width: 420, alignment: .top)
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
    }
    
    // Phase 5.5: Add mode menu button
    @State private var showingModeMenu = false
    
    private var timerCoreCard: some View {
        VStack(spacing: 16) {
            // Top bar with expand button and mode menu
            HStack(alignment: .center) {
                Button(action: openFocusWindow) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if !isRunning {
                    Button(action: { showingModeMenu = true }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingModeMenu, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(LocalTimerMode.allCases, id: \.self) { timerMode in
                                Button(action: {
                                    mode = timerMode
                                    showingModeMenu = false
                                }) {
                                    HStack {
                                        if mode == timerMode {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                        Text(timerMode.label)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .frame(minWidth: 150)
                    }
                }
            }
            .frame(height: 36)
            
            // Phase 5.7: Add EVERYTHING including pomodoro circles
            if isRunning {
                VStack(spacing: 8) {
                    if mode == .pomodoro {
                        Text(isPomodorBreak ? "Break" : "Work")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    } else {
                        Text(mode.label)
                            .font(.headline.weight(.medium))
                    }
                    
                    Text(timeDisplay)
                        .font(.system(.largeTitle, design: .monospaced).weight(.light))
                        .monospacedDigit()
                }
                .padding(.vertical, 12)
                
                // POMODORO CIRCLES - FIXED VERSION
                Group {
                    if mode == .pomodoro {
                        HStack(spacing: 8) {
                            ForEach(Array(0..<max(1, settings.pomodoroIterations)), id: \.self) { index in
                                Circle()
                                    .fill(index < completedPomodoroSessions ? Color.accentColor : Color.secondary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .id(settings.pomodoroIterations)
                    } else {
                        Color.clear.frame(height: 8)
                    }
                }
                .frame(height: 12)
                .padding(.bottom, 4)
                
                HStack(spacing: 18) {
                    Button(action: pauseTimer) {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: resetTimer) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 8) {
                    if mode == .pomodoro {
                        Text(isPomodorBreak ? "Break" : "Work")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    } else {
                        Text(mode.label)
                            .font(.headline.weight(.medium))
                    }
                    
                    Text(timeDisplay)
                        .font(.system(.largeTitle, design: .monospaced).weight(.light))
                        .monospacedDigit()
                }
                .padding(.vertical, 12)
                
                // POMODORO CIRCLES - FIXED VERSION
                Group {
                    if mode == .pomodoro {
                        HStack(spacing: 8) {
                            ForEach(Array(0..<max(1, settings.pomodoroIterations)), id: \.self) { index in
                                Circle()
                                    .fill(index < completedPomodoroSessions ? Color.accentColor : Color.accentColor.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .id(settings.pomodoroIterations)
                    } else {
                        Color.clear.frame(height: 8)
                    }
                }
                .frame(height: 12)
                .padding(.bottom, 4)
                
                Button("Start", action: startTimer)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
            
            Text("🧪 Phase 5.7: FULL TimerCoreCard with FIXED circles")
                .font(.caption)
        }
        .padding(24)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(24)
    }
    
    private var timeDisplay: String {
        switch mode {
        case .stopwatch:
            let h = Int(elapsedSeconds) / 3600
            let m = (Int(elapsedSeconds) % 3600) / 60
            let s = Int(elapsedSeconds) % 60
            if h > 0 {
                return String(format: "%02d:%02d:%02d", h, m, s)
            } else {
                return String(format: "%02d:%02d", m, s)
            }
        case .pomodoro, .countdown:
            let m = Int(remainingSeconds) / 60
            let s = Int(remainingSeconds) % 60
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    private func startTimer() {
        print("▶️ Start timer")
    }
    
    private func pauseTimer() {
        print("⏸️ Pause timer")
    }
    
    private func resetTimer() {
        print("🔄 Reset timer")
    }
    
    private func completeCurrentBlock() {
        print("⏭️ Skip to next")
    }
    
    private func openFocusWindow() {
        print("🎯 Open focus window")
    }
    
    private var bottomSummary: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                Text("Today: \(formattedDuration(totalToday))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let activity = currentActivity {
                Text("Selected: \(activity.name) • \(formattedDuration(activity.todayTrackedSeconds)) today")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
    
    var body: some View {
        // Phase 4.2: Add ZStack + Color (matching original structure)
        ScrollView {
            ZStack {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("🚧 Timer Page - Phase 6.7")
                        .font(.largeTitle)
                    
                    Text("Testing: TextEditor with custom Binding (CRITICAL)")
                        .foregroundColor(.secondary)
                    
                    // Add topBar
                    topBar
                    
                    // Add MINIMAL mainGrid (just text to start)
                    mainGrid
                    
                    // Add bottomSummary
                    bottomSummary
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
        .onAppear {
            print("✅✅✅ PHASE 4.5 - Testing debugMainThread() call ✅✅✅")
            
            // THIS IS THE CRITICAL TEST - debugMainThread was called at START of onAppear
            print("🔧 Calling debugMainThread('[TimerPageView] onAppear START')")
            debugMainThread("[TimerPageView] onAppear START")
            
            // Operation 0: Start tick timer
            print("🔧 Step 0: startTickTimer()")
            startTickTimer()
            
            // Operation 1: Update cached values
            print("🔧 Step 1: updateCachedValues()")
            updateCachedValues()
            
            // Operation 2: Initialize pomodoro settings
            print("🔧 Step 2: pomodoroSessions = settings.pomodoroIterations")
            pomodoroSessions = settings.pomodoroIterations
            
            // Operation 3: Initialize timer duration
            print("🔧 Step 3: Initialize remainingSeconds if 0")
            if remainingSeconds == 0 {
                remainingSeconds = TimeInterval(settings.pomodoroFocusMinutes * 60)
            }
            
            // Operation 4: Load sessions (if needed)
            print("🔧 Step 4: Check loadedSessions flag")
            if !loadedSessions {
                print("🔧   Calling loadSessions()")
                loadSessions()
                loadedSessions = true
            }
            
            // Operation 5: Sync with assignment
            print("🔧 Step 5: syncTimerWithAssignment()")
            syncTimerWithAssignment()
            
            print("🔧 Calling debugMainThread('[TimerPageView] onAppear COMPLETE')")
            debugMainThread("[TimerPageView] onAppear COMPLETE")
            
            print("✅ All onAppear operations completed")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
        // Phase 4.3: Add onChange modifiers one by one
        .onChange(of: activities) { _, _ in 
            print("🔄 onChange(activities) triggered")
            updateCachedValues() 
        }
        .onChange(of: searchText) { _, _ in 
            print("🔄 onChange(searchText) triggered")
            updateCachedValues() 
        }
        .onChange(of: sessions) { _, _ in
            print("🔄 onChange(sessions) triggered - would persist")
            // persistSessions() - commented out for testing
        }
        .onChange(of: selectedActivityID) { _, _ in
            print("🔄 onChange(selectedActivityID) triggered")
            // syncTimerWithAssignment() - commented out for testing
        }
        .onChange(of: settings.pomodoroIterations) { _, newValue in
            print("🔄 onChange(pomodoroIterations) triggered: \(newValue)")
            pomodoroSessions = newValue
        }
        .onDisappear {
            print("👋 Timer view disappeared")
        }
    }
}
#endif
