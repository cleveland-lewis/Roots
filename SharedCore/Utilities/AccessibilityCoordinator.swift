import SwiftUI
import Combine

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Centralized coordinator for all accessibility features across the app
/// Monitors system accessibility settings and provides unified access points
@MainActor
public final class AccessibilityCoordinator: ObservableObject {
    
    public static let shared = AccessibilityCoordinator()
    
    // MARK: - Published Properties
    
    @Published public private(set) var isReduceMotionEnabled: Bool = false
    @Published public private(set) var isReduceTransparencyEnabled: Bool = false
    @Published public private(set) var isIncreaseContrastEnabled: Bool = false
    @Published public private(set) var isDifferentiateWithoutColorEnabled: Bool = false
    @Published public private(set) var isVoiceOverEnabled: Bool = false
    @Published public private(set) var isSwitchControlEnabled: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        updateAllSettings()
        setupAccessibilityObservers()
    }
    
    // MARK: - System Setting Updates
    
    private func updateAllSettings() {
        #if os(macOS)
        isReduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        isReduceTransparencyEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        isIncreaseContrastEnabled = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        isDifferentiateWithoutColorEnabled = NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor
        isVoiceOverEnabled = NSWorkspace.shared.isVoiceOverEnabled
        isSwitchControlEnabled = NSWorkspace.shared.isSwitchControlEnabled
        #else
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        isDifferentiateWithoutColorEnabled = UIAccessibility.shouldDifferentiateWithoutColor
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isSwitchControlEnabled = UIAccessibility.isSwitchControlRunning
        #endif
    }
    
    private func setupAccessibilityObservers() {
        #if os(macOS)
        // macOS notifications
        NotificationCenter.default.publisher(
            for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateAllSettings()
        }
        .store(in: &cancellables)
        #else
        // iOS notifications
        NotificationCenter.default.publisher(
            for: UIAccessibility.reduceMotionStatusDidChangeNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateAllSettings()
        }
        .store(in: &cancellables)
        
        NotificationCenter.default.publisher(
            for: UIAccessibility.reduceTransparencyStatusDidChangeNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateAllSettings()
        }
        .store(in: &cancellables)
        
        NotificationCenter.default.publisher(
            for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateAllSettings()
        }
        .store(in: &cancellables)
        
        NotificationCenter.default.publisher(
            for: UIAccessibility.voiceOverStatusDidChangeNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateAllSettings()
        }
        .store(in: &cancellables)
        
        NotificationCenter.default.publisher(
            for: UIAccessibility.switchControlStatusDidChangeNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateAllSettings()
        }
        .store(in: &cancellables)
        #endif
    }
    
    // MARK: - Convenience Properties
    
    /// Whether enhanced visual accessibility features are needed
    public var requiresEnhancedVisuals: Bool {
        isIncreaseContrastEnabled || isReduceTransparencyEnabled || isDifferentiateWithoutColorEnabled
    }
    
    /// Whether assistive technologies are running
    public var isAssistiveTechnologyActive: Bool {
        isVoiceOverEnabled || isSwitchControlEnabled
    }
    
    /// Material policy based on current settings
    var materialPolicy: MaterialPolicy {
        MaterialPolicy(
            reduceTransparency: isReduceTransparencyEnabled,
            increaseContrast: isIncreaseContrastEnabled,
            differentiateWithoutColor: isDifferentiateWithoutColorEnabled
        )
    }
}

// MARK: - Environment Key

private struct AccessibilityCoordinatorKey: EnvironmentKey {
    static let defaultValue = AccessibilityCoordinator.shared
}

extension EnvironmentValues {
    public var accessibilityCoordinator: AccessibilityCoordinator {
        get { self[AccessibilityCoordinatorKey.self] }
        set { self[AccessibilityCoordinatorKey.self] = newValue }
    }
}

// MARK: - View Modifier for Accessibility Awareness

public struct AccessibilityAwareModifier: ViewModifier {
    @ObservedObject private var coordinator = AccessibilityCoordinator.shared
    
    public func body(content: Content) -> some View {
        content
            .environment(\.accessibilityCoordinator, coordinator)
            .environment(\.reduceMotion, coordinator.isReduceMotionEnabled)
    }
}

extension View {
    /// Inject accessibility coordinator into view hierarchy
    public func accessibilityAware() -> some View {
        modifier(AccessibilityAwareModifier())
    }
}
