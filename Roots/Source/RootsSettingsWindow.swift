import SwiftUI
import Combine
import AppKit

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case interface
    case accounts
    case courses

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .interface: return "rectangle.3.offgrid"
        case .accounts: return "person.crop.circle"
        case .courses: return "books.vertical"
        }
    }
}

struct RootsSettingsWindow: View {
    @EnvironmentObject var settings: AppSettingsModel
    @EnvironmentObject var coursesStore: CoursesStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: SettingsSection = .general
    @State private var paneSelectionCancellableHolder: AnyCancellable? = nil
    @State private var query: String = ""

    private var accentColor: Color { settings.activeAccentColor }

    @State private var sidebarExpanded: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Constrain the sidebar to a slimmer range (min 180, ideal 200, max 220)
            let sidebarWidth = min(max(180, size.width * (sidebarExpanded ? 0.20 : 0.14)), 220)

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignSystem.Materials.card)
                    .opacity(0.20)
                    .shadow(radius: 24, y: 10)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Empty top spacer to align content under traffic lights
                    Spacer().frame(height: 8)

                    HStack(spacing: 0) {
                        SettingsSidebar(selection: $selection, query: $query, accentColor: accentColor)
                            .frame(width: sidebarWidth, height: size.height - 56) // account for header
                            .frame(minWidth: 180, idealWidth: 200, maxWidth: 220, alignment: .leading)

                        Divider()

                        SettingsDetail(selection: selection, accentColor: accentColor)
                            .frame(width: size.width - sidebarWidth, height: size.height - 56)
                    }
                    .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .tint(accentColor)
        .frame(minWidth: 820, idealWidth: 820, maxWidth: 1200, minHeight: 520, idealHeight: 560, maxHeight: 900)
        .onReceive(settings.objectWillChange) { _ in
            DispatchQueue.main.async {
                settings.save()
            }
        }
        .onAppear {
            paneSelectionCancellableHolder = NotificationCenter.default.publisher(for: .selectSettingsPane)
                .compactMap { $0.userInfo?["pane"] as? String }
                .receive(on: DispatchQueue.main)
                .sink { raw in
                    if let match = SettingsSection.allCases.first(where: { $0.rawValue == raw }) {
                        selection = match
                    }
                }
        }
        .onDisappear {
            paneSelectionCancellableHolder?.cancel()
            paneSelectionCancellableHolder = nil
        }
    }
}

// MARK: - Sidebar

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection
    @Binding var query: String
    var accentColor: Color

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search Settings", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 10)
                .padding(.top, 12)

            List(selection: $selection) {
                ForEach(SettingsSection.allCases, id: \.id) { section in
                    HStack { sidebarRow(for: section) }
                        .tag(section)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func sidebarRow(for section: SettingsSection) -> some View {
        let isSelected = selection == section
        HStack(spacing: DesignSystem.Layout.spacing.small) {
            Image(systemName: section.iconName)
                .font(DesignSystem.Typography.body)
            Text(section.title)
                .font(DesignSystem.Typography.body)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                .fill(isSelected ? accentColor.opacity(0.9) : Color.clear)
        )
        .foregroundColor(isSelected ? .white : .primary)
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
    }
}

// MARK: - Detail Container

private struct SettingsDetail: View {
    @EnvironmentObject var settings: AppSettingsModel
    @EnvironmentObject var coursesStore: CoursesStore
    var selection: SettingsSection
    var accentColor: Color

    var body: some View {
        VStack {
            switch selection {
            case .general:
                LegacyGeneralSettingsView(accentColor: accentColor)
            case .appearance:
                AppearanceSettingsView(accentColor: accentColor)
            case .interface:
                LegacyInterfaceSettingsView(accentColor: accentColor)
            case .courses:
                // Note: Legacy courses settings - use SettingsRootView for new settings system
                CoursesSettingsView()
                    .environmentObject(coursesStore)
            case .accounts:
                AccountsSettingsView(accentColor: accentColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Group Container Helper

private struct SettingsBreadcrumbView: View {
    let segments: [String]
    let activeIndex: Int
    var onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            if segments.count >= 2 {
                Button {
                    onTap(0)
                } label: {
                    Text(segments[0])
                        .font(activeIndex == 0 ? .body : .caption)
                        .foregroundColor(activeIndex == 0 ? RootsColor.textPrimary : RootsColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(.plain)
                .disabled(activeIndex == 0)

                Text(">")
                    .rootsCaption()
                    .foregroundColor(RootsColor.textSecondary)

                Button {
                    onTap(1)
                } label: {
                    Text(segments[1])
                        .font(activeIndex == 1 ? .body : .caption)
                        .foregroundColor(activeIndex == 1 ? RootsColor.textPrimary : RootsColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(.plain)
                .disabled(activeIndex == 1)
            } else {
                Text(segments.first ?? "")
                    .font(.body)
            }
        }
    }
}

// MARK: - Group Container Helper

private struct SettingsRow<Content: View>: View {
    let title: String
    let description: String?
    @ViewBuilder let control: () -> Content

    private let labelWidth: CGFloat = 180

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: RootsSpacing.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .rootsBodySecondary()
                    .frame(width: labelWidth, alignment: Alignment.leading)

                if let description {
                    Text(description)
                        .rootsCaption()
                        .frame(width: labelWidth, alignment: Alignment.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            control()
                .frame(maxWidth: .infinity, alignment: Alignment.leading)
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let accent: Color
    let content: Content

    init(title: String, accent: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .rootsSectionHeader()
                .foregroundColor(accent)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(DesignSystem.Layout.padding.card)
            .rootsCardBackground(radius: 18)
        }
    }
}

// MARK: - Sections

private struct LegacyGeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    var accentColor: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.large) {
                Text("General")
                    .font(.title2.weight(.semibold))

                SettingsGroup(title: "Interaction", accent: accentColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsRow(title: "Enable hover wiggle", description: nil) {
                            Toggle("", isOn: $settings.wiggleOnHover)
                                .labelsHidden()
                                .onChange(of: settings.wiggleOnHover) { _, _ in settings.save() }
                        }
                        SettingsRow(title: "Keep glass accents active", description: "Prevents cards from desaturating when idle.") {
                            Toggle("", isOn: $settings.enableGlassEffects)
                                .labelsHidden()
                                .onChange(of: settings.enableGlassEffects) { _, _ in settings.save() }
                        }
                    }
                }

                SettingsGroup(title: "Layout", accent: accentColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsRow(title: "Tab bar mode", description: nil) {
                            Picker("", selection: $settings.tabBarMode) {
                                Text("Icons").tag(TabBarMode.iconsOnly)
                                Text("Text").tag(TabBarMode.textOnly)
                                Text("Icons & Text").tag(TabBarMode.iconsAndText)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        SettingsRow(title: "Sidebar behavior", description: "Automatic keeps the sidebar responsive to window size while still letting it stay pinned when you want it.") {
                            Picker("", selection: $settings.sidebarBehavior) {
                                Text("Auto-collapse").tag(SidebarBehavior.automatic)
                                Text("Always visible").tag(SidebarBehavior.expanded)
                                Text("Always hidden").tag(SidebarBehavior.compact)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(DesignSystem.Layout.spacing.large)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tint(accentColor)
    }
}

private struct AppearanceSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    var accentColor: Color

    private let swatches: [(choice: AppAccentColor, color: Color)] = [
        (.blue, .blue),
        (.purple, .purple),
        (.green, .green),
        (.pink, .pink),
        (.orange, .orange),
        (.yellow, .yellow)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.large) {
                Text("Appearance")
                    .font(.title2.weight(.semibold))

                SettingsGroup(title: "Theme", accent: accentColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsRow(title: "Follow system appearance", description: nil) {
                            Toggle("", isOn: Binding(get: { settings.interfaceStyle == .system }, set: { newValue in
                                settings.interfaceStyle = newValue ? .system : .light
                            }))
                            .labelsHidden()
                        }

                        SettingsRow(title: "Mode", description: "Choose how Roots reacts to system appearance changes.") {
                            Picker("", selection: $settings.interfaceStyle) {
                                ForEach(InterfaceStyle.allCases) { style in
                                    Text(style.label).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                }

                SettingsGroup(title: "Accent Color", accent: accentColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsRow(title: "Accent color", description: nil) {
                            HStack(spacing: 12) {
                                ForEach(swatches, id: \.choice) { swatch in
                                    ZStack {
                                        Circle()
                                            .fill(swatch.color)
                                            .frame(width: 32, height: 32)
                                        if settings.accentColorChoice == swatch.choice {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.25)))
                                        }
                                    }
                                    .onTapGesture {
                                        settings.accentColorChoice = swatch.choice
                                        settings.save()
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(DesignSystem.Layout.spacing.large)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tint(accentColor)
    }
}

private struct LegacyInterfaceSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    var accentColor: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.large) {
                Text("Interface")
                    .font(.title2.weight(.semibold))

                SettingsGroup(title: "Display", accent: accentColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsRow(title: "Show hover wiggle on cards", description: nil) {
                            Toggle("", isOn: $settings.wiggleOnHover)
                                .labelsHidden()
                        }
                        SettingsRow(title: "Use compact mode for Dashboard", description: nil) {
                            Toggle("", isOn: $settings.highContrastMode)
                                .labelsHidden()
                        }
                        SettingsRow(title: "Use 24-hour time", description: nil) {
                            Toggle("", isOn: $settings.use24HourTime)
                                .labelsHidden()
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(DesignSystem.Layout.spacing.large)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tint(accentColor)
    }
}

private struct AccountsSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    var accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Accounts")
                .font(.title2.weight(.semibold))

            SettingsGroup(title: "Primary Account", accent: accentColor) {
                HStack {
                    Text("Email")
                    Spacer()
                    Text("Not set")
                        .foregroundColor(.secondary)
                }
                Button("Manage…") { }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
            }

            SettingsGroup(title: "Sync", accent: accentColor) {
                Toggle("Enable iCloud sync", isOn: $settings.devModeEnabled) // using available boolean as placeholder
                Text("Syncs your settings and academic data across devices using iCloud.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .tint(accentColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct LegacyCoursesSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    var accentColor: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.large) {
                Text("Courses")
                    .font(.title2.weight(.semibold))

                SettingsGroup(title: "Course Management", accent: accentColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Manage all your courses, semesters, and academic settings from the Courses page.")
                            .rootsBody()
                            .foregroundColor(.secondary)

                        Text("Use the Courses page to add, edit, and organize your academic schedule.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                SettingsGroup(title: "Academic Settings", accent: accentColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsRow(title: "Default grade scale", description: nil) {
                            Picker("", selection: Binding(get: {
                                "standard"
                            }, set: { _ in })) {
                                Text("Standard (A-F)").tag("standard")
                                Text("Percentage").tag("percentage")
                                Text("Points").tag("points")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        SettingsRow(title: "Show course codes", description: "Display course codes in sidebar lists.") {
                            Toggle("", isOn: $settings.wiggleOnHover) // placeholder
                                .labelsHidden()
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(DesignSystem.Layout.spacing.large)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tint(accentColor)
    }
}
