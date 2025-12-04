import SwiftUI

struct LoadingHUD: View {
    @Binding var isVisible: Bool
    @State private var progress: Double = 0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    @EnvironmentObject var appSettings: AppSettings

    var title: String = "Loading"
    var message: String? = nil

    var body: some View {
        Group {
            if isVisible {
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    VStack(spacing: 12) {
                        LoadingIndicatorCircular(progress: $progress)
                            .environmentObject(appSettings)

                        Text(title)
                            .font(.headline)

                        if let message = message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.thinMaterial)
                            .shadow(radius: 20, y: 8)
                    )
                }
                .onReceive(timer) { _ in
                    if progress < 100 { progress += 1 } else { progress = 0 }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isVisible)
    }
}

extension View {
    func loadingHUD(isVisible: Binding<Bool>,
                    title: String = "Loading",
                    message: String? = nil) -> some View {
        ZStack {
            self
            LoadingHUD(isVisible: isVisible, title: title, message: message)
        }
    }
}
