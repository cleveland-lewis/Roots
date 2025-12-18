#if os(macOS)
import SwiftUI

struct MainThreadDebuggerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var debugger = MainThreadDebugger.shared
    @State private var selectedEvent: MainThreadDebugger.DebugEvent?
    @State private var autoScroll = true
    @State private var showActivationToast = false
    
    var body: some View {
        ZStack {
            mainContent
            
            // Activation Toast
            if showActivationToast {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        
                        Text("Debugger Activated")
                            .font(.headline)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showActivationToast)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { dismiss() }) {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header with controls
            HStack {
                Toggle("Enable Main Thread Debugger", isOn: Binding(
                    get: { 
                        print("🔍 Toggle GET called - debugger.isEnabled = \(debugger.isEnabled)")
                        return debugger.isEnabled 
                    },
                    set: { newValue in
                        print("🔍 Toggle SET called with newValue = \(newValue)")
                        print("🔍 About to call debugger.toggle()...")
                        debugger.toggle()
                        print("🔍 debugger.toggle() completed")
                        if newValue {
                            print("🔍 Showing activation toast")
                            showActivationToast = true
                            // Auto-dismiss after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showActivationToast = false
                            }
                        }
                    }
                ))
                .font(.headline)
                .toggleStyle(.switch)
                
                Spacer()
                
                HStack(spacing: 12) {
                    // TEST BUTTON - to verify enable() works
                    Button("Test Enable") {
                        print("🔍 TEST BUTTON clicked - manually calling enable()")
                        MainThreadDebugger.shared.enable()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Toggle("Auto-scroll", isOn: $autoScroll)
                        .font(.caption)
                    
                    Button(action: { debugger.clearEvents() }) {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(!debugger.isEnabled)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            if debugger.isEnabled {
                // Metrics Dashboard
                metricsSection
                
                Divider()
                
                // Events List
                eventsSection
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "ant.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("Main Thread Debugger Disabled")
                        .font(.headline)
                    
                    Text("Enable the debugger to track main thread blocks, long operations, and performance issues.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        featureItem(icon: "stopwatch", title: "Main Thread Monitoring", description: "Detects UI freezes and blocked main thread")
                        featureItem(icon: "chart.line.uptrend.xyaxis", title: "Performance Metrics", description: "Track block duration, memory usage, and active tasks")
                        featureItem(icon: "list.bullet.clipboard", title: "Event Log", description: "Detailed log with stack traces for debugging")
                        featureItem(icon: "arrow.down.doc", title: "Export Reports", description: "Export debug data for analysis")
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Activation Toast
            if showActivationToast {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        
                        Text("Debugger Activated")
                            .font(.headline)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showActivationToast)
            }
        }
    }
    
    private var metricsSection: some View {
        HStack(spacing: 20) {
            metricCard(
                icon: "exclamationmark.triangle.fill",
                title: "Total Blocks",
                value: "\(debugger.performanceMetrics.totalMainThreadBlocks)",
                color: .orange
            )
            
            metricCard(
                icon: "clock.fill",
                title: "Longest Block",
                value: String(format: "%.0fms", debugger.performanceMetrics.longestBlockDuration * 1000),
                color: .red
            )
            
            metricCard(
                icon: "chart.bar.fill",
                title: "Avg Block",
                value: String(format: "%.0fms", debugger.performanceMetrics.averageBlockDuration * 1000),
                color: .yellow
            )
            
            metricCard(
                icon: "memorychip.fill",
                title: "Memory",
                value: String(format: "%.0fMB", debugger.performanceMetrics.memoryUsageMB),
                color: .blue
            )
            
            metricCard(
                icon: "app.badge.fill",
                title: "Active Tasks",
                value: "\(debugger.performanceMetrics.activeTasks)",
                color: .green
            )
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    private var eventsSection: some View {
        HSplitView {
            // Events list
            VStack(spacing: 0) {
                HStack {
                    Text("Events (\(debugger.events.count))")
                        .font(.headline)
                    Spacer()
                    Text("Last 500 events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(debugger.events.reversed()) { event in
                                eventRow(event)
                                    .background(selectedEvent?.id == event.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .onTapGesture {
                                        selectedEvent = event
                                    }
                                    .id(event.id)
                            }
                        }
                    }
                    .onChange(of: debugger.events.count) { _, _ in
                        if autoScroll, let lastEvent = debugger.events.last {
                            withAnimation {
                                proxy.scrollTo(lastEvent.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 300)
            
            // Event detail
            if let event = selectedEvent {
                eventDetailView(event)
                    .frame(minWidth: 300)
            } else {
                VStack {
                    Text("Select an event to view details")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            }
        }
    }
    
    private func eventRow(_ event: MainThreadDebugger.DebugEvent) -> some View {
        HStack(spacing: 8) {
            Text(event.type.rawValue)
                .font(.caption2)
                .frame(width: 30)
            
            Text(timeString(event.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 80)
            
            Text(event.message)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func eventDetailView(_ event: MainThreadDebugger.DebugEvent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.type.rawValue)
                        .font(.title2)
                    Text(event.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Message
                VStack(alignment: .leading, spacing: 4) {
                    Text("Message")
                        .font(.headline)
                    Text(event.message)
                        .font(.body)
                        .textSelection(.enabled)
                }
                
                // Thread Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thread")
                        .font(.headline)
                    Text(event.threadInfo)
                        .font(.body)
                        .monospaced()
                }
                
                // Stack Trace
                if !event.stackTrace.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stack Trace")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(event.stackTrace.enumerated()), id: \.offset) { index, frame in
                                Text("\(index): \(frame)")
                                    .font(.caption)
                                    .monospaced()
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func metricCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func featureItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

#endif
