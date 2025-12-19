import SwiftUI

#if DEBUG

/// Debug-only view for testing accessibility features and simulating system settings
/// Allows developers to preview accessibility states without changing system settings
struct AccessibilityDebugView: View {
    @ObservedObject private var coordinator = AccessibilityCoordinator.shared
    @ObservedObject private var animationPolicy = AnimationPolicy.shared
    
    @State private var simulateReduceMotion = false
    @State private var simulateReduceTransparency = false
    @State private var simulateIncreaseContrast = false
    @State private var simulateDifferentiateWithoutColor = false
    @State private var simulateVoiceOver = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                currentStatusSection
                simulationSection
                previewSection
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accessibility Debug Tools")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Test and preview accessibility features without changing system settings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
        }
    }
    
    // MARK: - Current System Status
    
    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current System Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                statusRow(
                    title: "Reduce Motion",
                    isEnabled: coordinator.isReduceMotionEnabled
                )
                statusRow(
                    title: "Reduce Transparency",
                    isEnabled: coordinator.isReduceTransparencyEnabled
                )
                statusRow(
                    title: "Increase Contrast",
                    isEnabled: coordinator.isIncreaseContrastEnabled
                )
                statusRow(
                    title: "Differentiate Without Color",
                    isEnabled: coordinator.isDifferentiateWithoutColorEnabled
                )
                statusRow(
                    title: "VoiceOver",
                    isEnabled: coordinator.isVoiceOverEnabled
                )
                statusRow(
                    title: "Switch Control",
                    isEnabled: coordinator.isSwitchControlEnabled
                )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            Divider()
        }
    }
    
    // MARK: - Simulation Controls
    
    private var simulationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Simulate Accessibility Features")
                .font(.headline)
            
            Text("Note: These simulations are for preview only and don't affect actual system behavior")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Reduce Motion", isOn: $simulateReduceMotion)
                Toggle("Reduce Transparency", isOn: $simulateReduceTransparency)
                Toggle("Increase Contrast", isOn: $simulateIncreaseContrast)
                Toggle("Differentiate Without Color", isOn: $simulateDifferentiateWithoutColor)
                Toggle("VoiceOver Active", isOn: $simulateVoiceOver)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            Divider()
        }
    }
    
    // MARK: - Live Preview
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Preview")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Button preview
                HStack(spacing: 12) {
                    Button("Standard Button") { }
                        .buttonStyle(.borderedProminent)
                    
                    Button("Secondary Button") { }
                        .buttonStyle(.bordered)
                }
                
                // Card preview with glass effect
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sample Card")
                        .font(.headline)
                    Text("This card demonstrates material effects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(simulateReduceTransparency ? 
                              AnyShapeStyle(Color(nsColor: .textBackgroundColor)) :
                              AnyShapeStyle(.regularMaterial))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            Color.primary.opacity(simulateIncreaseContrast ? 0.3 : 0.12),
                            lineWidth: simulateIncreaseContrast ? 1.5 : 1.0
                        )
                )
                
                // Animation preview
                HStack {
                    Text("Animation:")
                        .font(.subheadline)
                    
                    Text(simulateReduceMotion ? "Reduced/Disabled" : "Full animations")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(simulateReduceMotion ? .orange : .green)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
        }
    }
    
    // MARK: - Helper Views
    
    private func statusRow(title: String, isEnabled: Bool) -> some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isEnabled ? .green : .secondary)
                .font(.body)
        }
    }
}

// MARK: - Preview

struct AccessibilityDebugView_Previews: PreviewProvider {
    static var previews: some View {
        AccessibilityDebugView()
    }
}

#endif
