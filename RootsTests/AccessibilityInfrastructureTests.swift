import XCTest
@testable import Roots

/// Unit tests for accessibility infrastructure
final class AccessibilityInfrastructureTests: XCTestCase {
    
    // MARK: - AnimationPolicy Tests
    
    @MainActor
    func testAnimationPolicyReduceMotion() async {
        let policy = AnimationPolicy.shared
        
        // Test that essential animations are allowed even with reduce motion
        if policy.isReduceMotionEnabled {
            let essentialAnimation = policy.animation(for: .essential)
            XCTAssertNotNil(essentialAnimation, "Essential animations should be allowed")
            
            let decorativeAnimation = policy.animation(for: .decorative)
            XCTAssertNil(decorativeAnimation, "Decorative animations should be disabled")
            
            let continuousAnimation = policy.animation(for: .continuous)
            XCTAssertNil(continuousAnimation, "Continuous animations should be disabled")
        }
    }
    
    @MainActor
    func testAnimationPolicyDurations() async {
        let policy = AnimationPolicy.shared
        
        let essentialDuration = policy.duration(for: .essential)
        let decorativeDuration = policy.duration(for: .decorative)
        
        // Essential animations should be faster
        XCTAssertLessThanOrEqual(essentialDuration, decorativeDuration)
        
        if policy.isReduceMotionEnabled {
            XCTAssertEqual(essentialDuration, 0.1, accuracy: 0.01)
            XCTAssertEqual(decorativeDuration, 0.0, accuracy: 0.01)
        }
    }
    
    @MainActor
    func testAnimationPolicyShouldAnimate() async {
        let policy = AnimationPolicy.shared
        
        if policy.isReduceMotionEnabled {
            XCTAssertTrue(policy.shouldAnimate(for: .essential))
            XCTAssertFalse(policy.shouldAnimate(for: .decorative))
            XCTAssertFalse(policy.shouldAnimate(for: .continuous))
        } else {
            XCTAssertTrue(policy.shouldAnimate(for: .essential))
            XCTAssertTrue(policy.shouldAnimate(for: .decorative))
            XCTAssertTrue(policy.shouldAnimate(for: .continuous))
        }
    }
    
    // MARK: - MaterialPolicy Tests
    
    @MainActor
    func testMaterialPolicySystem() async {
        let policy = MaterialPolicy.system
        
        // Test that system policy reflects actual settings
        #if os(macOS)
        XCTAssertEqual(
            policy.reduceTransparency,
            NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        )
        XCTAssertEqual(
            policy.increaseContrast,
            NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        )
        #endif
    }
    
    func testMaterialPolicyBorderOpacity() {
        let normalPolicy = MaterialPolicy(increaseContrast: false)
        let contrastPolicy = MaterialPolicy(increaseContrast: true)
        
        XCTAssertLessThan(normalPolicy.borderOpacity, contrastPolicy.borderOpacity)
        XCTAssertEqual(normalPolicy.borderOpacity, 0.12, accuracy: 0.01)
        XCTAssertEqual(contrastPolicy.borderOpacity, 0.3, accuracy: 0.01)
    }
    
    func testMaterialPolicyBorderWidth() {
        let normalPolicy = MaterialPolicy(increaseContrast: false)
        let contrastPolicy = MaterialPolicy(increaseContrast: true)
        
        XCTAssertLessThan(normalPolicy.borderWidth, contrastPolicy.borderWidth)
        XCTAssertEqual(normalPolicy.borderWidth, 1.0, accuracy: 0.1)
        XCTAssertEqual(contrastPolicy.borderWidth, 1.5, accuracy: 0.1)
    }
    
    // MARK: - AccessibilityCoordinator Tests
    
    @MainActor
    func testAccessibilityCoordinatorInitialization() async {
        let coordinator = AccessibilityCoordinator.shared
        
        // Verify that coordinator is initialized and tracking system settings
        XCTAssertNotNil(coordinator)
        
        // Test that coordinator properties match system state
        #if os(macOS)
        XCTAssertEqual(
            coordinator.isReduceMotionEnabled,
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        #endif
    }
    
    @MainActor
    func testAccessibilityCoordinatorEnhancedVisuals() async {
        let coordinator = AccessibilityCoordinator.shared
        
        let requiresEnhanced = coordinator.isIncreaseContrastEnabled ||
                               coordinator.isReduceTransparencyEnabled ||
                               coordinator.isDifferentiateWithoutColorEnabled
        
        XCTAssertEqual(coordinator.requiresEnhancedVisuals, requiresEnhanced)
    }
    
    @MainActor
    func testAccessibilityCoordinatorAssistiveTechnology() async {
        let coordinator = AccessibilityCoordinator.shared
        
        let hasAssistiveTech = coordinator.isVoiceOverEnabled || coordinator.isSwitchControlEnabled
        
        XCTAssertEqual(coordinator.isAssistiveTechnologyActive, hasAssistiveTech)
    }
    
    // MARK: - Contrast Ratio Tests
    
    func testContrastRatioBlackWhite() {
        let ratio = AccessibilityTestHelpers.contrastRatio(
            foreground: .black,
            background: .white
        )
        
        // Black on white should have maximum contrast (21:1)
        XCTAssertEqual(ratio, 21.0, accuracy: 0.1)
    }
    
    func testContrastRatioSameColor() {
        let ratio = AccessibilityTestHelpers.contrastRatio(
            foreground: .black,
            background: .black
        )
        
        // Same color should have minimum contrast (1:1)
        XCTAssertEqual(ratio, 1.0, accuracy: 0.1)
    }
    
    func testWCAGAACompliance() {
        // Test common color combinations
        let meetsAA = AccessibilityTestHelpers.assertMeetsWCAGAA(
            foreground: .black,
            background: .white,
            isLargeText: false
        )
        
        XCTAssertTrue(meetsAA, "Black on white should meet WCAG AA")
    }
    
    func testWCAGAAACompliance() {
        let meetsAAA = AccessibilityTestHelpers.assertMeetsWCAGAAA(
            foreground: .black,
            background: .white,
            isLargeText: false
        )
        
        XCTAssertTrue(meetsAAA, "Black on white should meet WCAG AAA")
    }
    
    // MARK: - Touch Target Tests
    
    func testMinimumTouchTargetMacOS() {
        #if os(macOS)
        let validSize = CGSize(width: 30, height: 30)
        let invalidSize = CGSize(width: 20, height: 20)
        
        XCTAssertTrue(AccessibilityTestHelpers.assertMeetsMinimumTouchTarget(size: validSize))
        XCTAssertFalse(AccessibilityTestHelpers.assertMeetsMinimumTouchTarget(size: invalidSize))
        #endif
    }
    
    func testMinimumTouchTargetIOS() {
        #if !os(macOS)
        let validSize = CGSize(width: 44, height: 44)
        let invalidSize = CGSize(width: 40, height: 40)
        
        XCTAssertTrue(AccessibilityTestHelpers.assertMeetsMinimumTouchTarget(size: validSize))
        XCTAssertFalse(AccessibilityTestHelpers.assertMeetsMinimumTouchTarget(size: invalidSize))
        #endif
    }
    
    // MARK: - VoiceOver Labels Tests
    
    func testVoiceOverAddButtonLabels() {
        let content = VoiceOverLabels.addButton(for: "Event")
        
        XCTAssertEqual(content.label, "Add Event")
        XCTAssertNotNil(content.hint)
        XCTAssertTrue(content.hint!.contains("create"))
    }
    
    func testVoiceOverTimerDisplayLabels() {
        let content = VoiceOverLabels.timerDisplay(minutes: 5, seconds: 30)
        
        XCTAssertEqual(content.label, "Timer")
        XCTAssertNotNil(content.value)
        XCTAssertTrue(content.value!.contains("5 minutes"))
        XCTAssertTrue(content.value!.contains("30 seconds"))
    }
    
    func testVoiceOverTimerDisplaySingular() {
        let content = VoiceOverLabels.timerDisplay(minutes: 1, seconds: 1)
        
        XCTAssertTrue(content.value!.contains("1 minute"))
        XCTAssertTrue(content.value!.contains("1 second"))
        XCTAssertFalse(content.value!.contains("minutes"))
        XCTAssertFalse(content.value!.contains("seconds"))
    }
    
    func testVoiceOverGPADisplay() {
        let content = VoiceOverLabels.gpaDisplay(gpa: 3.75)
        
        XCTAssertEqual(content.label, "Grade Point Average")
        XCTAssertEqual(content.value, "3.75")
    }
    
    // MARK: - Dynamic Type Tests
    
    func testDynamicTypeTextSizes() {
        let defaultSize = AccessibilityTestHelpers.textSize(for: .large)
        let largestSize = AccessibilityTestHelpers.textSize(for: .accessibilityExtraExtraExtraLarge)
        
        XCTAssertEqual(defaultSize, 17)
        XCTAssertEqual(largestSize, 53)
        XCTAssertGreaterThan(largestSize, defaultSize)
    }
}
