import SwiftUI

struct AppCard<Content: View>: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    let title: String?
    let icon: Image?
    let content: Content

    init(title: String? = nil, icon: Image? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                HStack(spacing: 8) {
                    if let icon = icon {
                        icon
                            .symbolEffect(.bounce)
                            .font(.title3)
                    }
                    Text(title)
                        .font(settings.font(for: .title2))
                        .fontWeight(.semibold)
                }
                Divider()
            }
            content
                .font(settings.font(for: .body))
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .opacity(settings.glassOpacity(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
        .contentTransition(.opacity)
    }
}
