import SwiftUI

// Renamed legacy style to avoid conflict with new GlassProminentBlueButtonStyle
struct LegacyGlassProminentButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    
    func makeBody(configuration: Configuration) -> some View {
        let policy = MaterialPolicy(preferences: preferences)
        
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(policy.hudMaterial(colorScheme: .light), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(policy.borderOpacity * 0.67), lineWidth: policy.borderWidth * 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .onHover { hovering in
                #if canImport(AppKit)
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                #endif
            }
    }
}
