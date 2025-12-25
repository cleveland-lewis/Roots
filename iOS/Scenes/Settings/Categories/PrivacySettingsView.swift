import SwiftUI
#if os(iOS)

struct PrivacySettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @State private var showingClearConfirmation = false
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $settings.enableICloudSync) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.privacy.icloud_sync", comment: "iCloud Sync"))
                        Text(NSLocalizedString("settings.privacy.icloud_sync.detail", comment: "Sync data across your devices using iCloud"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: settings.enableICloudSync) { _, _ in
                    settings.save()
                }
                
                if !settings.enableICloudSync {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("settings.privacy.local_only", comment: "Local-Only Mode"))
                                .font(.subheadline)
                            Text(NSLocalizedString("settings.privacy.local_only.detail", comment: "All data stays on this device"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("settings.privacy.data.header", comment: "Data Storage"))
            } footer: {
                if settings.enableICloudSync {
                    Text(NSLocalizedString("settings.privacy.icloud_sync.footer", comment: "Your data will be synced across all devices signed in to your iCloud account. Data is encrypted in transit and at rest."))
                } else {
                    Text(NSLocalizedString("settings.privacy.local_only.footer", comment: "All your data stays on this device. No cloud sync or external services are used."))
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(NSLocalizedString("settings.privacy.clear_logs", comment: "Clear Debug Logs"))
                    }
                }
                .confirmationDialog(
                    NSLocalizedString("settings.privacy.clear_logs.confirm.title", comment: "Clear Debug Logs?"),
                    isPresented: $showingClearConfirmation
                ) {
                    Button(NSLocalizedString("settings.privacy.clear_logs.confirm.action", comment: "Clear Logs"), role: .destructive) {
                        clearDebugLogs()
                    }
                    Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) { }
                } message: {
                    Text(NSLocalizedString("settings.privacy.clear_logs.confirm.message", comment: "This will clear all debug logs and analytics data stored on your device."))
                }
            } header: {
                Text(NSLocalizedString("settings.privacy.diagnostics.header", comment: "Diagnostics"))
            }
            
            Section {
                Button {
                    openAppSettings()
                } label: {
                    HStack {
                        Image(systemName: "hand.raised")
                        Text(NSLocalizedString("settings.privacy.permissions", comment: "Manage Permissions"))
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("settings.privacy.permissions.header", comment: "Permissions"))
            } footer: {
                Text(NSLocalizedString("settings.privacy.permissions.footer", comment: "Open iOS Settings to manage calendar, notifications, and other permissions"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("settings.category.privacy", comment: "Privacy"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func clearDebugLogs() {
        // Clear any debug logs or analytics data
        UserDefaults.standard.removeObject(forKey: "debug.logs")
        UserDefaults.standard.removeObject(forKey: "analytics.events")
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
            .environmentObject(AppSettingsModel.shared)
    }
}
#endif
