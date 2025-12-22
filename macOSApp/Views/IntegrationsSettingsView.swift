#if os(macOS)
import SwiftUI
import UserNotifications

struct IntegrationsSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @State private var notificationStatus: PermissionStatus = .notRequested
    @State private var iCloudStatus: Bool = false
    
    var body: some View {
        Form {
            Section {
                Text("Integrations")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 4)
                
                Text("Manage app capabilities that require permissions or connect to external services.")
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            
            // Notifications Integration
            Section {
                IntegrationCard(
                    title: "Notifications",
                    icon: "bell.badge",
                    description: "Get alerts for timers, assignments, and important reminders",
                    status: notificationStatus,
                    isEnabled: Binding(
                        get: { settings.notificationsEnabled },
                        set: { settings.notificationsEnabled = $0; settings.save() }
                    ),
                    onOpenSettings: {
                        openNotificationSettings()
                    }
                )
            }
            
            // Developer Mode Integration
            Section {
                IntegrationCard(
                    title: "Developer Mode",
                    icon: "hammer.fill",
                    description: "Enable detailed logging and diagnostics for troubleshooting",
                    status: settings.devModeEnabled ? .granted : .notRequested,
                    isEnabled: Binding(
                        get: { settings.devModeEnabled },
                        set: { settings.devModeEnabled = $0; settings.save() }
                    ),
                    showOpenSettings: false
                )
            }
            
            // Spotlight / Search Integration
            Section {
                IntegrationCard(
                    title: "Spotlight & Search",
                    icon: "magnifyingglass",
                    description: "Index courses, assignments, and notes for system-wide search",
                    status: .notRequested, // Placeholder - will implement in future
                    isEnabled: .constant(false),
                    showOpenSettings: false
                )
                .opacity(0.6) // Indicate not yet implemented
            }
            
            // Raycast Integration
            Section {
                IntegrationCard(
                    title: "Raycast",
                    icon: "command.square",
                    description: "Quick actions and search integration with Raycast",
                    status: .notRequested, // Placeholder - will implement in future
                    isEnabled: .constant(false),
                    showOpenSettings: false
                )
                .opacity(0.6) // Indicate not yet implemented
            }
            
            // iCloud Sync Integration
            Section {
                IntegrationCard(
                    title: "iCloud Sync",
                    icon: "icloud",
                    description: "Sync your data across all your devices using iCloud",
                    status: settings.enableICloudSync ? .granted : .notRequested,
                    isEnabled: Binding(
                        get: { settings.enableICloudSync },
                        set: { settings.enableICloudSync = $0; settings.save() }
                    ),
                    showOpenSettings: false
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Integrations")
        .frame(minWidth: 500, maxWidth: 700)
        .onAppear {
            checkNotificationPermissions()
        }
    }
    
    private func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    notificationStatus = .granted
                case .denied:
                    notificationStatus = .denied
                case .notDetermined:
                    notificationStatus = .notRequested
                @unknown default:
                    notificationStatus = .notRequested
                }
            }
        }
    }
    
    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permission Status

enum PermissionStatus {
    case notRequested
    case granted
    case denied
    case error
    
    var label: String {
        switch self {
        case .notRequested: return "Not Requested"
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .error: return "Error"
        }
    }
    
    var color: Color {
        switch self {
        case .notRequested: return .gray
        case .granted: return .green
        case .denied: return .red
        case .error: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .notRequested: return "circle"
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Integration Card

struct IntegrationCard: View {
    let title: String
    let icon: String
    let description: String
    let status: PermissionStatus
    @Binding var isEnabled: Bool
    var onOpenSettings: (() -> Void)? = nil
    var showOpenSettings: Bool = true
    
    @EnvironmentObject var settings: AppSettingsModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.accentColor)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                HStack(spacing: 6) {
                    Image(systemName: status.icon)
                        .foregroundStyle(status.color)
                        .font(.caption)
                    
                    Text(status.label)
                        .font(.caption)
                        .foregroundStyle(status.color)
                }
            }
            
            // Controls
            HStack(spacing: 12) {
                // Toggle (if applicable)
                if showOpenSettings || status != .denied {
                    Toggle("Enabled", isOn: $isEnabled)
                        .toggleStyle(.switch)
                        .disabled(status == .denied)
                }
                
                Spacer()
                
                // Open Settings button (if denied and applicable)
                if status == .denied && showOpenSettings, let openSettings = onOpenSettings {
                    Button {
                        openSettings()
                    } label: {
                        Label("Open System Settings", systemImage: "gear")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                }
            }
            
            // Guidance message for denied state
            if status == .denied && showOpenSettings {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.orange)
                    
                    Text("Permission denied. Please enable in System Settings to use this feature.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

#endif
