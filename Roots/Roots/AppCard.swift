import SwiftUI

struct AppCard<Content: View>: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    let title: String?
    let icon: Image?
    let iconBounceTrigger: Bool
    let content: Content
    private let cardCornerRadius: CGFloat = 24
    private let cardPadding: CGFloat = 24

    init(
        title: String? = nil,
        icon: Image? = nil,
        iconBounceTrigger: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconBounceTrigger = iconBounceTrigger
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if title != nil || icon != nil {
                header
            }

            content
                .font(settings.font(for: .body))
                .foregroundStyle(.primary)
        }
        .padding(cardPadding)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 0.6)
        )
        .shadow(color: shadowColor, radius: 24, x: 0, y: 12)
        .contentTransition(.opacity)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let icon {
                icon
                    .font(.title2)
                    .symbolEffect(.bounce, value: iconBounceTrigger)
                    .transition(.cardHeaderTransition)
            }

            if let title {
                Text(title)
                    .font(settings.font(for: .title2))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .transition(.cardHeaderTransition)
            }

            Spacer()
        }
        .contentTransition(.opacity)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.22)
    }
}

private extension AnyTransition {
    static var cardHeaderTransition: AnyTransition {
        let opacity = AnyTransition.opacity
        let scale = AnyTransition.scale(scale: 0.95)
        return .asymmetric(insertion: opacity.combined(with: scale), removal: opacity.combined(with: scale))
    }
}
