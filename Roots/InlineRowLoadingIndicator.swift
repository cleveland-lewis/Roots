import SwiftUI

struct InlineRowLoadingIndicator: View {
    @State private var progress: Double = 0
    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(appSettings.accentColor)

            Text("Loading…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onReceive(timer) { _ in
            if progress < 100 { progress += 1 } else { progress = 0 }
        }
    }
}
