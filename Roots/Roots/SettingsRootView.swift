import SwiftUI
import Combine

struct SettingsRootView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @EnvironmentObject var coordinator: SettingsCoordinator
    @State private var hasSetInitialPane = false

    private let paneChanged: (SettingsToolbarIdentifier) -> Void

    init(initialPane: SettingsToolbarIdentifier, paneChanged: @escaping (SettingsToolbarIdentifier) -> Void) {
        self.paneChanged = paneChanged
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.primary.opacity(0.05), radius: 12, x: 0, y: 6)

            HStack(spacing: 0) {
                // Left navigation stack
                List(selection: $coordinator.selectedSection) {
                    ForEach(SettingsToolbarIdentifier.allCases) { id in
                        Label(id.label, systemImage: id.systemImageName)
                            .tag(id)
                    }
                }
                .listStyle(.sidebar)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)

                // Right detail area
                ScrollView {
                    paneContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 20)
                }
            }
        }
        .frame(minWidth: 540, minHeight: 420)
        .toolbarRole(.automatic)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                HStack(spacing: 12) {
                    ForEach(SettingsToolbarIdentifier.allCases, id: \.self) { identifier in
                        SettingsToolbarButton(
                            identifier: identifier,
                            isSelected: coordinator.selectedSection == identifier,
                            action: {
                                guard coordinator.selectedSection != identifier else { return }
                                coordinator.selectedSection = identifier
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            guard !hasSetInitialPane else { return }
            paneChanged(coordinator.selectedSection)
            hasSetInitialPane = true
        }
        .onChange(of: coordinator.selectedSection) { (prev, newPane) in
            print("[Settings] Switched to pane: \(newPane.label)")
            paneChanged(newPane)
        }
        .onReceive(settings.objectWillChange) { _ in
            // Persist settings whenever they change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                settings.save()
            }
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        switch coordinator.selectedSection {
        case .general:
            SettingsPane_General()
        case .appearance:
            SettingsPane_Appearance()
        case .interface:
            SettingsPane_Interface()
        case .courses:
            SettingsPane_Courses()
        case .accounts:
            SettingsPane_Accounts()
        }
    }
}

private struct SettingsToolbarButton: View {
    let identifier: SettingsToolbarIdentifier
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(identifier.label, systemImage: identifier.systemImageName)
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        .help("Show \(identifier.label) settings")
    }
}
