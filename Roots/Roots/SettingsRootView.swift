import SwiftUI

struct SettingsRootView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var selection: SettingsSection? = .appearance

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("General") {
                    SettingsRow(section: .appearance)
                    SettingsRow(section: .notifications)
                }

                Section("Account") {
                    SettingsRow(section: .profile)
                }

                Section("Advanced") {
                    SettingsRow(section: .developer)
                }

                Section("Design") {
                    SettingsRow(section: .design)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            detailView(for: selection ?? .appearance)
                .padding(20)
        }
        .frame(width: 720, height: 480)
    }

    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .appearance:   return AnyView(AppearanceSettingsView())
        case .notifications:return AnyView(NotificationSettingsView())
        case .profile:      return AnyView(ProfileSettingsView())
        case .developer:    return AnyView(DeveloperSettingsView())
        case .design:       return AnyView(DesignSettingsView())
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance, notifications, profile, developer, design

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appearance:   return "Appearance"
        case .notifications:return "Notifications"
        case .profile:      return "Profile"
        case .developer:    return "Developer"
        case .design:       return "Design"
        }
    }

    var systemImage: String {
        switch self {
        case .appearance:   return "paintpalette"
        case .notifications:return "bell"
        case .profile:      return "person.crop.circle"
        case .developer:    return "wrench.and.screwdriver"
        case .design:       return "square.on.square"
        }
    }
}

struct SettingsRow: View {
    let section: SettingsSection

    var body: some View {
        Label(section.label, systemImage: section.systemImage)
    }
}

// MARK: - Detail sections

struct AppearanceSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Mode", selection: $appSettings.appearanceMode) {
                    ForEach(AppSettings.AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Appearance")
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable notifications", isOn: $appSettings.notificationsEnabled)
            }
            .footer {
                Text("Roots can remind you about upcoming assignments and exams.")
            }
        }
        .navigationTitle("Notifications")
    }
}

struct ProfileSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $appSettings.displayName)
                Toggle("Show course codes", isOn: $appSettings.showCourseCodes)
            }
        }
        .navigationTitle("Profile")
    }
}

struct DeveloperSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        Form {
            Section("Debugging") {
                Toggle("Enable debug logging", isOn: $appSettings.enableDebugLogging)
            }
        }
        .navigationTitle("Developer")
    }
}

struct DesignSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        Form {
            Section("Card Material") {
                Picker("Material", selection: $appSettings.cardMaterial) {
                    ForEach(AppSettings.CardMaterial.allCases) { mat in
                        Text(mat.label).tag(mat)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Card Shape") {
                HStack {
                    Text("Corner radius")
                    Slider(value: $appSettings.cardCornerRadius, in: 8...32, step: 1)
                    Text("\(Int(appSettings.cardCornerRadius))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Design")
    }
}
