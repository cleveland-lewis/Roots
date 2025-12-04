import SwiftUI

enum EventDensityLevel { case none, low, medium, high }

struct EventDensityHelper {
    static func level(for count: Int) -> EventDensityLevel {
        switch count {
        case 0: return .none
        case 1...3: return .low
        case 4...6: return .medium
        default: return .high
        }
    }

    static func color(for level: EventDensityLevel) -> Color {
        switch level {
        case .none: return .secondary.opacity(0.2)
        case .low: return .green.opacity(0.7)
        case .medium: return .yellow.opacity(0.8)
        case .high: return .red.opacity(0.8)
        }
    }
}

