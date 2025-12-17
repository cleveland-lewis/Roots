import Foundation
import Combine
import os.log

@MainActor
final class MainThreadDebugger: ObservableObject {
    static let shared = MainThreadDebugger()
    
    @Published private(set) var isEnabled = false
    @Published private(set) var events: [DebugEvent] = []
    @Published private(set) var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    
    private var timer: Timer?
    private let maxEvents = 500
    private let logger = Logger(subsystem: "com.roots.app", category: "MainThreadDebugger")
    
    struct DebugEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: EventType
        let message: String
        let threadInfo: String
        let stackTrace: [String]
        
        enum EventType: String {
            case mainThreadBlock = "⚠️ MAIN THREAD BLOCKED"
            case longOperation = "🐌 LONG OPERATION"
            case memoryWarning = "💾 MEMORY WARNING"
            case uiFreeze = "❄️ UI FREEZE"
            case taskCreated = "📦 TASK CREATED"
            case taskCompleted = "✅ TASK COMPLETED"
            case warning = "⚠️ WARNING"
            case info = "ℹ️ INFO"
        }
    }
    
    struct PerformanceMetrics {
        var totalMainThreadBlocks: Int = 0
        var longestBlockDuration: TimeInterval = 0
        var averageBlockDuration: TimeInterval = 0
        var memoryUsageMB: Double = 0
        var activeTasks: Int = 0
    }
    
    private init() {}
    
    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        events.removeAll()
        startMonitoring()
        log(.info, "Main Thread Debugger enabled")
    }
    
    func disable() {
        guard isEnabled else { return }
        isEnabled = false
        stopMonitoring()
        log(.info, "Main Thread Debugger disabled")
    }
    
    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }
    
    func clearEvents() {
        events.removeAll()
        performanceMetrics = PerformanceMetrics()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        // Monitor main thread every 100ms
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkMainThread()
            }
        }
        
        // Monitor memory
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while self?.isEnabled == true {
                self?.updateMemoryUsage()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkMainThread() {
        guard isEnabled else { return }
        
        // Check if main thread is blocked
        let start = CFAbsoluteTimeGetCurrent()
        
        // Perform a dummy operation
        _ = (0...100).reduce(0, +)
        
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        // If this simple operation took too long, main thread is blocked
        if elapsed > 0.016 { // 16ms = 60fps threshold
            recordMainThreadBlock(duration: elapsed)
        }
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            Task { @MainActor [weak self] in
                self?.performanceMetrics.memoryUsageMB = memoryMB
            }
        }
    }
    
    // MARK: - Event Recording
    
    private func recordMainThreadBlock(duration: TimeInterval) {
        let stackTrace = Thread.callStackSymbols.prefix(10).map { $0 }
        
        let event = DebugEvent(
            timestamp: Date(),
            type: duration > 0.1 ? .uiFreeze : .mainThreadBlock,
            message: "Main thread blocked for \(String(format: "%.2f", duration * 1000))ms",
            threadInfo: threadInfo(),
            stackTrace: stackTrace
        )
        
        addEvent(event)
        
        // Update metrics
        performanceMetrics.totalMainThreadBlocks += 1
        if duration > performanceMetrics.longestBlockDuration {
            performanceMetrics.longestBlockDuration = duration
        }
        
        // Calculate running average
        let total = performanceMetrics.averageBlockDuration * Double(performanceMetrics.totalMainThreadBlocks - 1) + duration
        performanceMetrics.averageBlockDuration = total / Double(performanceMetrics.totalMainThreadBlocks)
        
        logger.warning("⚠️ Main thread blocked for \(duration * 1000, format: .fixed(precision: 2))ms")
    }
    
    func recordLongOperation(name: String, duration: TimeInterval) {
        guard isEnabled else { return }
        
        let event = DebugEvent(
            timestamp: Date(),
            type: .longOperation,
            message: "\(name) took \(String(format: "%.2f", duration * 1000))ms",
            threadInfo: threadInfo(),
            stackTrace: Thread.callStackSymbols.prefix(5).map { $0 }
        )
        
        addEvent(event)
        logger.info("🐌 Long operation: \(name) - \(duration * 1000, format: .fixed(precision: 2))ms")
    }
    
    func recordTaskCreation(name: String) {
        guard isEnabled else { return }
        
        let event = DebugEvent(
            timestamp: Date(),
            type: .taskCreated,
            message: "Task created: \(name)",
            threadInfo: threadInfo(),
            stackTrace: Thread.callStackSymbols.prefix(3).map { $0 }
        )
        
        addEvent(event)
        performanceMetrics.activeTasks += 1
    }
    
    func recordTaskCompletion(name: String, duration: TimeInterval) {
        guard isEnabled else { return }
        
        let event = DebugEvent(
            timestamp: Date(),
            type: .taskCompleted,
            message: "Task completed: \(name) (\(String(format: "%.2f", duration * 1000))ms)",
            threadInfo: threadInfo(),
            stackTrace: []
        )
        
        addEvent(event)
        performanceMetrics.activeTasks = max(0, performanceMetrics.activeTasks - 1)
    }
    
    func recordWarning(message: String) {
        guard isEnabled else { return }
        
        let event = DebugEvent(
            timestamp: Date(),
            type: .warning,
            message: message,
            threadInfo: threadInfo(),
            stackTrace: Thread.callStackSymbols.prefix(5).map { $0 }
        )
        
        addEvent(event)
        logger.warning("⚠️ \(message)")
    }
    
    func recordInfo(message: String) {
        guard isEnabled else { return }
        
        let event = DebugEvent(
            timestamp: Date(),
            type: .info,
            message: message,
            threadInfo: threadInfo(),
            stackTrace: []
        )
        
        addEvent(event)
        logger.info("ℹ️ \(message)")
    }
    
    private func addEvent(_ event: DebugEvent) {
        events.append(event)
        
        // Trim to max events
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }
    
    private func threadInfo() -> String {
        if Thread.isMainThread {
            return "Main Thread"
        } else {
            return "Background Thread (\(Thread.current.description))"
        }
    }
    
    private func log(_ level: OSLogType, _ message: String) {
        logger.log(level: level, "\(message)")
    }
}

// MARK: - Convenience Functions

func debugMainThread(_ message: String) {
    MainThreadDebugger.shared.recordInfo(message: message)
}

func debugWarning(_ message: String) {
    MainThreadDebugger.shared.recordWarning(message: message)
}

func measureOperation<T>(_ name: String, operation: () throws -> T) rethrows -> T {
    let start = CFAbsoluteTimeGetCurrent()
    let result = try operation()
    let duration = CFAbsoluteTimeGetCurrent() - start
    
    if duration > 0.016 { // Longer than one frame
        MainThreadDebugger.shared.recordLongOperation(name: name, duration: duration)
    }
    
    return result
}

func measureAsyncOperation<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
    MainThreadDebugger.shared.recordTaskCreation(name: name)
    let start = CFAbsoluteTimeGetCurrent()
    let result = try await operation()
    let duration = CFAbsoluteTimeGetCurrent() - start
    MainThreadDebugger.shared.recordTaskCompletion(name: name, duration: duration)
    return result
}
