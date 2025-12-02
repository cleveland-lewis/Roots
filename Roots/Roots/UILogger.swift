import Foundation

enum UILogCategory: String {
    case dashboard
}

struct UILogger {
    static func log(_ category: UILogCategory, _ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[UI][\(category.rawValue)] \(timestamp) - \(message)")
    }
}
