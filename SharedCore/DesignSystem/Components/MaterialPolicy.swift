import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// MaterialPolicy centralizes accessibility-aware material and contrast decisions.
/// Replaces glass materials with opaque surfaces and strengthens contrast when accessibility settings are enabled.
@MainActor
struct MaterialPolicy {
    let reduceTransparency: Bool
    let increaseContrast: Bool
    let differentiateWithoutColor: Bool
    
    init(
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
        differentiateWithoutColor: Bool = false
    ) {
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.differentiateWithoutColor = differentiateWithoutColor
    }
    
    /// Initialize from AppPreferences
    init(preferences: AppPreferences) {
        self.reduceTransparency = preferences.reduceTransparency
        self.increaseContrast = preferences.highContrast
        self.differentiateWithoutColor = false
    }
    
    /// Initialize from system accessibility settings
    @MainActor
    static var system: MaterialPolicy {
        #if os(macOS)
        return MaterialPolicy(
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
            increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
            differentiateWithoutColor: NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor
        )
        #else
        return MaterialPolicy(
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled,
            increaseContrast: UIAccessibility.isDarkerSystemColorsEnabled,
            differentiateWithoutColor: UIAccessibility.shouldDifferentiateWithoutColor
        )
        #endif
    }
    
    // MARK: - Material Resolution
    
    /// Returns the appropriate material for cards based on accessibility settings
    func cardMaterial(colorScheme: ColorScheme) -> AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(solidCardBackground(colorScheme: colorScheme))
        }
        return AnyShapeStyle(.regularMaterial)
    }
    
    /// Returns the appropriate material for HUD/chrome elements
    func hudMaterial(colorScheme: ColorScheme) -> AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(solidHudBackground(colorScheme: colorScheme))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }
    
    /// Returns the appropriate material for popups
    func popupMaterial(colorScheme: ColorScheme) -> AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(solidPopupBackground(colorScheme: colorScheme))
        }
        return AnyShapeStyle(.thickMaterial)
    }
    
    // MARK: - Solid Backgrounds
    
    private func solidCardBackground(colorScheme: ColorScheme) -> Color {
        #if os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }
    
    private func solidHudBackground(colorScheme: ColorScheme) -> Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor).opacity(0.95)
        #else
        return Color(uiColor: .secondarySystemBackground).opacity(0.95)
        #endif
    }
    
    private func solidPopupBackground(colorScheme: ColorScheme) -> Color {
        #if os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }
    
    // MARK: - Border/Separator Strength
    
    /// Returns border opacity based on contrast settings
    var borderOpacity: Double {
        increaseContrast ? 0.3 : 0.12
    }
    
    /// Returns border width based on contrast settings
    var borderWidth: CGFloat {
        increaseContrast ? 1.5 : 1.0
    }
    
    /// Returns separator opacity based on contrast settings
    var separatorOpacity: Double {
        increaseContrast ? 0.25 : 0.1
    }
    
    // MARK: - Shape/Icon Cues for Differentiate Without Color
    
    /// Returns whether additional visual cues (shapes, icons, outlines) should be shown
    var shouldShowAdditionalCues: Bool {
        differentiateWithoutColor
    }
}

// MARK: - View Modifiers

struct MaterialPolicyModifier: ViewModifier {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.colorScheme) private var colorScheme
    
    var cornerRadius: CGFloat
    var materialType: MaterialType
    
    enum MaterialType {
        case card
        case hud
        case popup
    }
    
    func body(content: Content) -> some View {
        let policy = MaterialPolicy(preferences: preferences)
        let material: AnyShapeStyle
        
        switch materialType {
        case .card:
            material = policy.cardMaterial(colorScheme: colorScheme)
        case .hud:
            material = policy.hudMaterial(colorScheme: colorScheme)
        case .popup:
            material = policy.popupMaterial(colorScheme: colorScheme)
        }
        
        return content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
            )
    }
}

struct MaterialPolicyBorderModifier: ViewModifier {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.colorScheme) private var colorScheme
    
    var cornerRadius: CGFloat
    var color: Color?
    
    func body(content: Content) -> some View {
        let policy = MaterialPolicy(preferences: preferences)
        let borderColor = color ?? Color.primary
        
        return content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor.opacity(policy.borderOpacity), lineWidth: policy.borderWidth)
            )
    }
}

extension View {
    /// Applies material policy-aware background
    func materialPolicyBackground(
        cornerRadius: CGFloat,
        type: MaterialPolicyModifier.MaterialType
    ) -> some View {
        self.modifier(MaterialPolicyModifier(cornerRadius: cornerRadius, materialType: type))
    }
    
    /// Applies material policy-aware border
    func materialPolicyBorder(
        cornerRadius: CGFloat,
        color: Color? = nil
    ) -> some View {
        self.modifier(MaterialPolicyBorderModifier(cornerRadius: cornerRadius, color: color))
    }
}
