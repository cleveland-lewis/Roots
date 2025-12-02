import SwiftUI

struct SettingsRootView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @State private var selectedPane: SettingsToolbarIdentifier
    @State private var hasSetInitialPane = false

    private let paneChanged: (SettingsToolbarIdentifier) -> Void

    init(initialPane: SettingsToolbarIdentifier, paneChanged: @escaping (SettingsToolbarIdentifier) -> Void) {
        _selectedPane = State(initialValue: initialPane)
        self.paneChanged = paneChanged
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.primary.opacity(0.05), radius: 12, x: 0, y: 6)

            ScrollView {
                paneContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 20)
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
                            isSelected: selectedPane == identifier,
                            action: {
                                guard selectedPane != identifier else { return }
                                selectedPane = identifier
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            guard !hasSetInitialPane else { return }
            paneChanged(selectedPane)
            hasSetInitialPane = true
        }
        .onChange(of: selectedPane) { (prev, newPane) in
            print("[Settings] Switched to pane: \(newPane.label)")
            paneChanged(newPane)
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selectedPane {
        case .general:
            SettingsPane_General()
        case .appearance:
            SettingsPane_Appearance()
        case .interface:
            SettingsPane_Interface()
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
