#if os(macOS)
import SwiftUI

struct DeveloperSettingsView: View {
    @ObservedObject private var diagnostics = Diagnostics.shared
    @ObservedObject private var settings = AppSettingsModel.shared
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Developer Mode", isOn: $settings.devModeEnabled)
                        .font(.headline)
                        .onChange(of: settings.devModeEnabled) { _, _ in
                            settings.save()
                        }
                    
                    Text("When enabled, the app emits structured debug logging to the Xcode console. This helps with debugging, triage, and understanding app behavior at runtime.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("Debug Logging")
            }
            
            if diagnostics.isDeveloperModeEnabled {
                Section {
                    NavigationLink(destination: MainThreadDebuggerView()) {
                        HStack {
                            Image(systemName: "ant.circle.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Main Thread Debugger")
                                    .font(.headline)
                                Text("Track UI freezes and performance issues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Performance Debugging")
                } footer: {
                    Text("Advanced tool to detect main thread blocks, long operations, and memory issues.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("UI Logging", isOn: $settings.devModeUILogging)
                            .onChange(of: settings.devModeUILogging) { _, _ in settings.save() }
                        Toggle("Data & Sync Logging", isOn: $settings.devModeDataLogging)
                            .onChange(of: settings.devModeDataLogging) { _, _ in settings.save() }
                        Toggle("Scheduler & Planner Logging", isOn: $settings.devModeSchedulerLogging)
                            .onChange(of: settings.devModeSchedulerLogging) { _, _ in settings.save() }
                        Toggle("Performance Warnings", isOn: $settings.devModePerformance)
                            .onChange(of: settings.devModePerformance) { _, _ in settings.save() }
                    }
                } header: {
                    Text("Subsystem Toggles")
                } footer: {
                    Text("Fine-tune which subsystems emit debug logs. Errors and warnings are always logged.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Subsystems")
                            .font(.headline)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(LogSubsystem.allCases, id: \.self) { subsystem in
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 6))
                                            .foregroundColor(.green)
                                        Text(subsystem.rawValue)
                                            .font(.caption)
                                            .monospaced()
                                    }
                                }
                            }
                            .padding(8)
                        }
                        .frame(maxHeight: 200)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                } header: {
                    Text("Available Subsystems")
                } footer: {
                    Text("All subsystems are actively logging when Developer Mode is enabled.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Events: \(diagnostics.recentEvents.count)")
                            .font(.headline)
                        
                        Button("Clear Event Buffer") {
                            diagnostics.clearBuffer()
                        }
                        
                        if !diagnostics.recentEvents.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(diagnostics.recentEvents.suffix(50).reversed(), id: \.timestamp) { event in
                                        HStack(alignment: .top, spacing: 4) {
                                            Text(event.severity.rawValue)
                                                .font(.caption2)
                                                .monospaced()
                                                .foregroundColor(colorForSeverity(event.severity))
                                                .frame(width: 50, alignment: .leading)
                                            
                                            Text("[\(event.subsystem.rawValue)]")
                                                .font(.caption2)
                                                .monospaced()
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(event.message)
                                                .font(.caption2)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                                .padding(8)
                            }
                            .frame(maxHeight: 300)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                } header: {
                    Text("Event Buffer (Last 50)")
                } footer: {
                    Text("View recent log events. Full logs are available in Console.app filtered by subsystem 'com.roots.app'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy & Safety")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        bulletPoint("Logs do not contain sensitive user content")
                        bulletPoint("Only IDs, counts, and high-level summaries are logged")
                        bulletPoint("All logs are local only—no external upload")
                        bulletPoint("Use Console.app to view full structured logs")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Developer")
    }
    
    private func colorForSeverity(_ severity: LogSeverity) -> Color {
        switch severity {
        case .fatal: return .red
        case .error: return .orange
        case .warn: return .yellow
        case .info: return .blue
        case .debug: return .secondary
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("•")
            Text(text)
        }
    }
}

struct DeveloperSettingsView_Old: View {
    // This file intentionally kept as compatibility; UI is located in SettingsRootView's DeveloperSettingsView
    var body: some View { EmptyView() }
}
#endif
