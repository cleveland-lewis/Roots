import Foundation
import SwiftUI
import Combine
import OSLog

enum LogSeverity: String {
    case fatal  = "FATAL"
    case error  = "ERROR"
    case warn   = "WARN"
    case info   = "INFO"
    case debug  = "DEBUG"
    
    var osLogType: OSLogType {
        switch self {
        case .fatal: return .fault
        case .error: return .error
        case .warn: return .default
        case .info: return .info
        case .debug: return .debug
        }
    }
}

enum LogSubsystem: String, CaseIterable {
    case appLifecycle = "AppLifecycle"
    case navigation   = "Navigation"
    case persistence  = "Persistence"
    case scheduler    = "Scheduler"
    case planner      = "Planner"
    case calendar     = "Calendar"
    case eventKit     = "EventKit"
    case grades       = "Grades"
    case courses      = "Courses"
    case timer        = "Timer"
    case focus        = "Focus"
    case notifications = "Notifications"
    case networking   = "Networking"
    case integrations = "Integrations"
    case ui           = "UI"
    case practice     = "Practice"
    case data         = "Data"
    case sync         = "Sync"
    case settings     = "Settings"
    case performance  = "Performance"
    
    var logger: Logger {
        Logger(subsystem: "com.roots.app", category: self.rawValue)
    }
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

final class Diagnostics: ObservableObject {
    static let shared = Diagnostics()

    @MainActor @Published private(set) var recentEvents: [LogEvent] = []
    private let maxEvents = 500
    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private var errorCounts: [String: (count: Int, lastLogged: Date)] = [:]
    private let errorRateLimitWindow: TimeInterval = 5.0
    private let maxErrorsPerWindow = 3

    private init() {}
    
    // Read settings directly from AppSettingsModel to avoid recursion
    var isDeveloperModeEnabled: Bool {
        AppSettingsModel.shared.devModeEnabled
    }
    
    var enableUILogging: Bool {
        AppSettingsModel.shared.devModeUILogging
    }
    
    var enableDataLogging: Bool {
        AppSettingsModel.shared.devModeDataLogging
    }
    
    var enableSchedulerLogging: Bool {
        AppSettingsModel.shared.devModeSchedulerLogging
    }
    
    var enablePerformanceWarnings: Bool {
        AppSettingsModel.shared.devModePerformance
    }

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
        
        // Rate limiting for errors
        if severity == .error {
            let errorKey = "\(subsystem.rawValue).\(category).\(msg)"
            let now = Date()
            
            if let existing = errorCounts[errorKey] {
                let timeSinceLastLog = now.timeIntervalSince(existing.lastLogged)
                if timeSinceLastLog < errorRateLimitWindow {
                    if existing.count >= maxErrorsPerWindow {
                        // Skip this error, too many in window
                        return
                    }
                    errorCounts[errorKey] = (existing.count + 1, existing.lastLogged)
                } else {
                    // Reset window
                    errorCounts[errorKey] = (1, now)
                }
            } else {
                errorCounts[errorKey] = (1, now)
            }
        }

        let event = LogEvent(timestamp: Date(), severity: severity, subsystem: subsystem, category: category, message: msg, metadata: metadata, file: fileStr, function: functionStr, line: lineInt)

        // Store (async to respect MainActor isolation)
        Task { @MainActor in
            recentEvents.append(event)
            if recentEvents.count > maxEvents { recentEvents.removeFirst(recentEvents.count - maxEvents) }
        }

        // Format metadata
        var metaStr = ""
        if let md = metadata, !md.isEmpty {
            metaStr = " | " + md.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        }
        
        // Use OSLog for structured logging
        let logger = subsystem.logger
        
        switch severity {
        case .fatal:
            logger.fault("[\(category)] \(msg)\(metaStr)")
        case .error:
            logger.error("[\(category)] \(msg)\(metaStr)")
        case .warn:
            logger.warning("[\(category)] \(msg)\(metaStr)")
        case .info:
            logger.info("[\(category)] \(msg)\(metaStr)")
        case .debug:
            logger.debug("[\(category)] \(msg)\(metaStr)")
        }

        #if DEBUG
        if severity == .fatal {
            assertionFailure("\(severity.rawValue): \(msg)")
        } else if severity == .error {
            // Don't crash on errors - just print to console
            print("⚠️ ERROR: \(msg)")
        }
        #endif
    }

    @MainActor
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

func LOG_LIFECYCLE(_ severity: LogSeverity = .info,
                   _ category: String,
                   _ message: @autoclosure () -> String,
                   metadata: [String: String]? = nil,
                   file: StaticString = #fileID,
                   function: StaticString = #function,
                   line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .appLifecycle, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_NAVIGATION(_ severity: LogSeverity = .info,
                    _ category: String,
                    _ message: @autoclosure () -> String,
                    metadata: [String: String]? = nil,
                    file: StaticString = #fileID,
                    function: StaticString = #function,
                    line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .navigation, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_PERSISTENCE(_ severity: LogSeverity = .info,
                     _ category: String,
                     _ message: @autoclosure () -> String,
                     metadata: [String: String]? = nil,
                     file: StaticString = #fileID,
                     function: StaticString = #function,
                     line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .persistence, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_PLANNER(_ severity: LogSeverity = .info,
                 _ category: String,
                 _ message: @autoclosure () -> String,
                 metadata: [String: String]? = nil,
                 file: StaticString = #fileID,
                 function: StaticString = #function,
                 line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .planner, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_CALENDAR(_ severity: LogSeverity = .info,
                  _ category: String,
                  _ message: @autoclosure () -> String,
                  metadata: [String: String]? = nil,
                  file: StaticString = #fileID,
                  function: StaticString = #function,
                  line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .calendar, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_EVENTKIT(_ severity: LogSeverity = .info,
                  _ category: String,
                  _ message: @autoclosure () -> String,
                  metadata: [String: String]? = nil,
                  file: StaticString = #fileID,
                  function: StaticString = #function,
                  line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .eventKit, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_GRADES(_ severity: LogSeverity = .info,
                _ category: String,
                _ message: @autoclosure () -> String,
                metadata: [String: String]? = nil,
                file: StaticString = #fileID,
                function: StaticString = #function,
                line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .grades, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_COURSES(_ severity: LogSeverity = .info,
                 _ category: String,
                 _ message: @autoclosure () -> String,
                 metadata: [String: String]? = nil,
                 file: StaticString = #fileID,
                 function: StaticString = #function,
                 line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .courses, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_TIMER(_ severity: LogSeverity = .info,
               _ category: String,
               _ message: @autoclosure () -> String,
               metadata: [String: String]? = nil,
               file: StaticString = #fileID,
               function: StaticString = #function,
               line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .timer, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_FOCUS(_ severity: LogSeverity = .info,
               _ category: String,
               _ message: @autoclosure () -> String,
               metadata: [String: String]? = nil,
               file: StaticString = #fileID,
               function: StaticString = #function,
               line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .focus, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_NOTIFICATIONS(_ severity: LogSeverity = .info,
                       _ category: String,
                       _ message: @autoclosure () -> String,
                       metadata: [String: String]? = nil,
                       file: StaticString = #fileID,
                       function: StaticString = #function,
                       line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .notifications, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_NETWORKING(_ severity: LogSeverity = .info,
                    _ category: String,
                    _ message: @autoclosure () -> String,
                    metadata: [String: String]? = nil,
                    file: StaticString = #fileID,
                    function: StaticString = #function,
                    line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .networking, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}

func LOG_INTEGRATIONS(_ severity: LogSeverity = .info,
                      _ category: String,
                      _ message: @autoclosure () -> String,
                      metadata: [String: String]? = nil,
                      file: StaticString = #fileID,
                      function: StaticString = #function,
                      line: UInt = #line) {
    Diagnostics.shared.log(severity, subsystem: .integrations, category: category, message: message(), metadata: metadata, file: file, function: function, line: line)
}
