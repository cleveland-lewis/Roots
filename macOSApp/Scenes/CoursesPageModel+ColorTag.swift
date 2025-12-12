#if os(macOS)
import SwiftUI

extension ColorTag {
    static func fromHex(_ hex: String?) -> ColorTag? {
        guard let hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return nil }
        switch hex {
        case "#4c78ff", "blue": return .blue
        case "#34c759", "green": return .green
        case "#af52de", "purple": return .purple
        case "#ff9f0a", "orange": return .orange
        case "#ff2d55", "pink": return .pink
        case "#ffd60a", "yellow": return .yellow
        case "#8e8e93", "gray": return .gray
        default: return nil
        }
    }

    static func hex(for tag: ColorTag) -> String {
        switch tag {
        case .blue: return "#4C78FF"
        case .green: return "#34C759"
        case .purple: return "#AF52DE"
        case .orange: return "#FF9F0A"
        case .pink: return "#FF2D55"
        case .yellow: return "#FFD60A"
        case .gray: return "#8E8E93"
        }
    }
}

#endif
