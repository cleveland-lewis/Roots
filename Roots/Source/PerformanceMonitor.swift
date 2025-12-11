import Foundation

struct PerformanceMonitor {
    static func measure(_ label: String, threshold: TimeInterval = 0.3, _ block: () -> Void) {
        let start = Date()
        block()
        let dur = Date().timeIntervalSince(start)
        if Diagnostics.shared.isDeveloperModeEnabled && Diagnostics.shared.enablePerformanceWarnings {
            if dur > threshold {
                LOG_PERF(.warn, "SlowOperation", "\(label) took \(String(format: "%.3f", dur))s")
            } else {
                LOG_PERF(.debug, "Performance", "\(label) took \(String(format: "%.3f", dur))s")
            }
        }
    }
}
