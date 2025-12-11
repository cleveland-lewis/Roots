import SwiftUI

struct TimerHeaderView: View {
    let now: Date
    @Binding var isMenuOpen: Bool
    var onAdd: () -> Void
    var onSettings: () -> Void

    @EnvironmentObject private var settings: AppSettingsModel

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(settings.formattedTime(now))
                    .font(DesignSystem.Typography.body)
                    .monospacedDigit()
                Text(dateFormatter.string(from: now))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .background(DesignSystem.Materials.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
