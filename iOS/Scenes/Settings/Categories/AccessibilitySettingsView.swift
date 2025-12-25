import SwiftUI
#if os(iOS)

struct AccessibilitySettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $settings.reduceMotionStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.accessibility.reduce_motion", comment: "Reduce Motion"))
                        Text(NSLocalizedString("settings.accessibility.reduce_motion.detail", comment: "Minimize animations and transitions"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: settings.reduceMotionStorage) { _, _ in
                    settings.save()
                }
                
                Toggle(isOn: $settings.increaseTransparencyStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.accessibility.increase_transparency", comment: "Increase Transparency"))
                        Text(NSLocalizedString("settings.accessibility.increase_transparency.detail", comment: "Reduce blur and transparency effects"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: settings.increaseTransparencyStorage) { _, _ in
                    settings.save()
                }
                
                Toggle(isOn: $settings.highContrastModeStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.accessibility.high_contrast", comment: "Increase Contrast"))
                        Text(NSLocalizedString("settings.accessibility.high_contrast.detail", comment: "Make colors and borders more distinct"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: settings.highContrastModeStorage) { _, _ in
                    settings.save()
                }
            } header: {
                Text(NSLocalizedString("settings.accessibility.visual.header", comment: "Visual"))
            }
            
            Section {
                Toggle(isOn: $settings.enableHapticsStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.accessibility.haptics", comment: "Haptic Feedback"))
                        Text(NSLocalizedString("settings.accessibility.haptics.detail", comment: "Feel tactile responses for actions"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: settings.enableHapticsStorage) { _, _ in
                    settings.save()
                }
            } header: {
                Text(NSLocalizedString("settings.accessibility.interaction.header", comment: "Interaction"))
            }
            
            Section {
                Toggle(isOn: $settings.showTooltipsStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.accessibility.tooltips", comment: "Show Tooltips"))
                        Text(NSLocalizedString("settings.accessibility.tooltips.detail", comment: "Display helpful hints for interface elements"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: settings.showTooltipsStorage) { _, _ in
                    settings.save()
                }
            } header: {
                Text(NSLocalizedString("settings.accessibility.guidance.header", comment: "Guidance"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("settings.category.accessibility", comment: "Accessibility"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AccessibilitySettingsView()
            .environmentObject(AppSettingsModel.shared)
    }
}
#endif
