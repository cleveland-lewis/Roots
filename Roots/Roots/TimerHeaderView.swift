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
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(dateFormatter.string(from: now))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
