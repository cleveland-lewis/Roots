import Foundation
import SwiftUI
import Combine

enum LogSeverity: String {
    case fatal  = "FATAL"
    case error  = "ERROR"
    case warn   = "WARN"
    case info   = "INFO"
    case debug  = "DEBUG"
}

enum LogSubsystem: String {
    case ui          = "UI"
    case scheduler   = "Scheduler"
    case practice    = "Practice"
    case data        = "Data"
    case sync        = "Sync"
    case settings    = "Settings"
    case performance = "Performance"
}

struct LogEvent {
    let timestamp: Date
    let severity: LogSeverity
    let subsystem: LogSubsystem
    let category: String
    let message: String
    let metadata: [String: String]?
    let file: String
    let function: String
    let line: Int
}

@MainActor
final class Diagnostics: ObservableObject {
    static let shared = Diagnostics()

    @Published var isDeveloperModeEnabled: Bool = false
    @Published var enableUILogging: Bool = false
    @Published var enableDataLogging: Bool = false
    @Published var enableSchedulerLogging: Bool = false
    @Published var enablePerformanceWarnings: Bool = false

    @Published private(set) var recentEvents: [LogEvent] = []
    private let maxEvents = 500
    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    func log(_ severity: LogSeverity,
             subsystem: LogSubsystem,
             category: String,
             message: @autoclosure () -> String,
             metadata: [String: String]? = nil,
             file: StaticString = #fileID,
             function: StaticString = #function,
             line: UInt = #line) {

        let fileStr = String(describing: file)
        let functionStr = String(describing: function)
        let lineInt = Int(line)
        let msg = message()

        // Filtering
        if !isDeveloperModeEnabled {
            // Only allow fatal and error through when dev mode is off
            if severity != .fatal && severity != .error { return }
        } else {
            // respect subsystem toggles
            switch subsystem {
            case .ui:
                if !enableUILogging && severity == .debug { return }
            case .data, .sync:
                if !enableDataLogging && severity == .debug { return }
            case .scheduler, .practice:
                if !enableSchedulerLogging && severity == .debug { return }
            case .performance:
                if !enablePerformanceWarnings && severity == .warn { return }
            default:
                break
            }
        }

        let event = LogEvent(timestamp: Date(), severity: severity, subsystem: subsystem, category: category, message: msg, metadata: metadata, file: fileStr, function: functionStr, line: lineInt)

        // Store
        recentEvents.append(event)
        if recentEvents.count > maxEvents { recentEvents.removeFirst(recentEvents.count - maxEvents) }

        // Format
        let ts = iso8601.string(from: event.timestamp)
        var metaStr = ""
        if let md = metadata, !md.isEmpty {
            metaStr = " | " + md.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        }
        let console = "[\(event.severity.rawValue)][\(event.subsystem.rawValue)][\(category)][\(ts)] \(event.message)\(metaStr)  (\(event.file):\(event.line) \(event.function))"

        print(console)

        #if DEBUG
        if severity == .fatal || severity == .error {
            assertionFailure("\(severity.rawValue): \(event.message)")
        }
        #endif
    }

    func clearBuffer() {
        recentEvents.removeAll()
    }

    // convenience measure wrapper
    func measure<T>(_ label: String, threshold: TimeInterval = 0.3, context: LogSubsystem = .performance, block: () throws -> T) rethrows -> T {
        let start = Date()
        let result = try block()
        let dur = Date().timeIntervalSince(start)
        if isDeveloperModeEnabled && enablePerformanceWarnings {
            if dur > threshold {
                log(.warn, subsystem: context, category: "SlowOperation", message: "\(label) took \(String(format: "%.3f", dur))s", metadata: ["duration":"\(dur)"], file: #fileID, function: #function, line: #line)
            } else {
                log(.debug, subsystem: context, category: "Performance", message: "\(label) took \(String(format: "%.3f", dur))s", metadata: ["duration":"\(dur)"], file: #fileID, function: #function, line: #line)
            }
        }
        return result
    }
}

// MARK: - Convenience global log functions

func LOG_UI(_ severity: LogSeverity = .debug,
            _ category: String,
            _ message: @autoclosure () -> String,
            metadata: [String: String]? = nil,
            file: StaticString = #fileID,
            function: StaticString = #function,
            line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .ui, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_SCHEDULER(_ severity: LogSeverity = .debug,
                   _ category: String,
                   _ message: @autoclosure () -> String,
                   metadata: [String: String]? = nil,
                   file: StaticString = #fileID,
                   function: StaticString = #function,
                   line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .scheduler, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_PRACTICE(_ severity: LogSeverity = .debug,
                  _ category: String,
                  _ message: @autoclosure () -> String,
                  metadata: [String: String]? = nil,
                  file: StaticString = #fileID,
                  function: StaticString = #function,
                  line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .practice, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_DATA(_ severity: LogSeverity = .debug,
              _ category: String,
              _ message: @autoclosure () -> String,
              metadata: [String: String]? = nil,
              file: StaticString = #fileID,
              function: StaticString = #function,
              line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .data, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_SYNC(_ severity: LogSeverity = .debug,
              _ category: String,
              _ message: @autoclosure () -> String,
              metadata: [String: String]? = nil,
              file: StaticString = #fileID,
              function: StaticString = #function,
              line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .sync, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_SETTINGS(_ severity: LogSeverity = .info,
                  _ category: String,
                  _ message: @autoclosure () -> String,
                  metadata: [String: String]? = nil,
                  file: StaticString = #fileID,
                  function: StaticString = #function,
                  line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .settings, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_PERF(_ severity: LogSeverity = .warn,
              _ category: String,
              _ message: @autoclosure () -> String,
              metadata: [String: String]? = nil,
              file: StaticString = #fileID,
              function: StaticString = #function,
              line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .performance, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}
