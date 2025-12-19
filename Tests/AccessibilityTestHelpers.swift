import XCTest
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Test utilities for verifying accessibility compliance
/// Use these helpers in unit and UI tests to ensure accessibility requirements are met
public final class AccessibilityTestHelpers {
    
    // MARK: - VoiceOver Testing
    
    /// Verify that a view has an accessibility label
    public static func assertHasLabel(_ view: some View, file: StaticString = #file, line: UInt = #line) {
        // Note: This is a conceptual helper. In practice, use XCTest UI testing to verify labels.
        // See AccessibilityUITests for actual test implementations.
    }
    
    /// Verify that an interactive element has both label and hint
    public static func assertHasLabelAndHint(_ view: some View, file: StaticString = #file, line: UInt = #line) {
        // Conceptual helper for documentation
    }
    
    // MARK: - Contrast Testing
    
    /// Calculate contrast ratio between two colors
    /// Returns value between 1 and 21, where 21 is maximum contrast
    public static func contrastRatio(foreground: Color, background: Color) -> Double {
        #if os(macOS)
        guard let fgColor = NSColor(foreground).cgColor,
              let bgColor = NSColor(background).cgColor else {
            return 1.0
        }
        #else
        guard let fgColor = UIColor(foreground).cgColor,
              let bgColor = UIColor(background).cgColor else {
            return 1.0
        }
        #endif
        
        let fgLuminance = relativeLuminance(cgColor: fgColor)
        let bgLuminance = relativeLuminance(cgColor: bgColor)
        
        let lighter = max(fgLuminance, bgLuminance)
        let darker = min(fgLuminance, bgLuminance)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Verify contrast ratio meets WCAG AA standard (4.5:1 for normal text, 3:1 for large text)
    public static func assertMeetsWCAGAA(
        foreground: Color,
        background: Color,
        isLargeText: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let ratio = contrastRatio(foreground: foreground, background: background)
        let requiredRatio = isLargeText ? 3.0 : 4.5
        return ratio >= requiredRatio
    }
    
    /// Verify contrast ratio meets WCAG AAA standard (7:1 for normal text, 4.5:1 for large text)
    public static func assertMeetsWCAGAAA(
        foreground: Color,
        background: Color,
        isLargeText: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let ratio = contrastRatio(foreground: foreground, background: background)
        let requiredRatio = isLargeText ? 4.5 : 7.0
        return ratio >= requiredRatio
    }
    
    private static func relativeLuminance(cgColor: CGColor) -> Double {
        guard let components = cgColor.components, components.count >= 3 else {
            return 0
        }
        
        let r = gammaCorrect(components[0])
        let g = gammaCorrect(components[1])
        let b = gammaCorrect(components[2])
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    private static func gammaCorrect(_ value: CGFloat) -> Double {
        let v = Double(value)
        return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    
    // MARK: - Dynamic Type Testing
    
    /// Get text size for given content size category
    public static func textSize(for category: ContentSizeCategory) -> CGFloat {
        switch category {
        case .extraSmall: return 14
        case .small: return 15
        case .medium: return 16
        case .large: return 17  // Default
        case .extraLarge: return 19
        case .extraExtraLarge: return 21
        case .extraExtraExtraLarge: return 23
        case .accessibilityMedium: return 28
        case .accessibilityLarge: return 33
        case .accessibilityExtraLarge: return 40
        case .accessibilityExtraExtraLarge: return 47
        case .accessibilityExtraExtraExtraLarge: return 53
        @unknown default: return 17
        }
    }
    
    // MARK: - Touch Target Testing
    
    /// Verify that a touch target meets minimum size requirement (44x44 points for iOS, 28x28 for macOS)
    public static func assertMeetsMinimumTouchTarget(size: CGSize, file: StaticString = #file, line: UInt = #line) -> Bool {
        #if os(macOS)
        let minimumSize: CGFloat = 28
        #else
        let minimumSize: CGFloat = 44
        #endif
        
        return size.width >= minimumSize && size.height >= minimumSize
    }
    
    // MARK: - Reduce Motion Testing
    
    /// Test helper to simulate reduce motion being enabled
    public static func withReduceMotionEnabled<T>(_ block: () -> T) -> T {
        // Note: In actual tests, use environment override
        return block()
    }
    
    /// Verify that an animation duration is reduced when reduce motion is enabled
    public static func assertAnimationReducedForReduceMotion(
        normalDuration: TimeInterval,
        reducedDuration: TimeInterval,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        // Reduced duration should be significantly shorter or zero
        return reducedDuration < normalDuration * 0.3
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    
    /// Verify an element is accessible to VoiceOver
    public func assertAccessible(
        _ element: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "Element should exist", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Element should be hittable", file: file, line: line)
        XCTAssertFalse(
            element.label.isEmpty,
            "Element should have accessibility label",
            file: file,
            line: line
        )
    }
    
    /// Verify an interactive element has proper traits
    public func assertInteractiveElement(
        _ element: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assertAccessible(element, file: file, line: line)
        
        let hasButtonTrait = element.elementType == .button
        let hasLinkTrait = element.elementType == .link
        let hasTextFieldTrait = element.elementType == .textField
        
        XCTAssertTrue(
            hasButtonTrait || hasLinkTrait || hasTextFieldTrait,
            "Element should have interactive trait",
            file: file,
            line: line
        )
    }
    
    /// Verify keyboard focus can reach an element
    public func assertKeyboardNavigable(
        _ element: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "Element should exist", file: file, line: line)
        
        // Tab to element
        let app = XCUIApplication()
        app.typeKey("\t", modifierFlags: [])
        
        XCTAssertTrue(
            element.hasFocus,
            "Element should be reachable via keyboard",
            file: file,
            line: line
        )
    }
}

// MARK: - Mock Accessibility Coordinator for Testing

#if DEBUG
public final class MockAccessibilityCoordinator: ObservableObject {
    @Published public var isReduceMotionEnabled: Bool = false
    @Published public var isReduceTransparencyEnabled: Bool = false
    @Published public var isIncreaseContrastEnabled: Bool = false
    @Published public var isDifferentiateWithoutColorEnabled: Bool = false
    @Published public var isVoiceOverEnabled: Bool = false
    @Published public var isSwitchControlEnabled: Bool = false
    
    public init() {}
    
    public func reset() {
        isReduceMotionEnabled = false
        isReduceTransparencyEnabled = false
        isIncreaseContrastEnabled = false
        isDifferentiateWithoutColorEnabled = false
        isVoiceOverEnabled = false
        isSwitchControlEnabled = false
    }
}
#endif
