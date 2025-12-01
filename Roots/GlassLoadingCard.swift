import SwiftUI

struct GlassLoadingCard: View {
    @State private var progress: Double = 0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    @EnvironmentObject var appSettings: AppSettings

    var title: String
    var message: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
                .shadow(radius: 18, y: 8)

            VStack(spacing: 12) {
                if !title.isEmpty {
                    Text(title)
                        .font(.headline)
                }

                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                LoadingIndicatorLinear(progress: $progress)
                    .padding(.top, 8)
            }
            .padding(16)
        }
        .frame(minWidth: 260, maxWidth: 360, minHeight: 140)
        .onReceive(timer) { _ in
            if progress < 100 { progress += 1 } else { progress = 0 }
        }
    }
}
