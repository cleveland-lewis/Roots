import SwiftUI

struct FlashcardSettingsView: View {
    @EnvironmentObject private var settings: AppSettingsModel

    var body: some View {
        Form {
            Section("Flashcards") {
                Toggle("Enable Flashcards", isOn: $settings.enableFlashcards)
                    .onChange(of: settings.enableFlashcards) { _, _ in settings.save() }
            }

            Section {
                Text("Turn flashcards on or off across the app. Disabling hides related UI and study flows.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Flashcards")
    }
}
