import SwiftUI

public enum ColorTag: String, CaseIterable, Identifiable {
    case blue, green, purple, orange, pink, yellow, gray
    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .orange: return .orange
        case .pink: return .pink
        case .yellow: return .yellow
        case .gray: return .gray
        }
    }



}
