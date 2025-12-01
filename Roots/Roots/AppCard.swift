import SwiftUI

enum DesignSystem {
    static let cardCornerRadius: CGFloat = 18
    static let cardMinWidth: CGFloat = 260
    static let cardMinHeight: CGFloat = 140
}

struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius, style: .continuous)
                .fill(backgroundMaterial)
                .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.15), radius: 18, y: 8)
        }
        .overlay(
            content
                .padding(16)
        )
        .frame(minWidth: DesignSystem.cardMinWidth, maxWidth: .infinity, minHeight: DesignSystem.cardMinHeight)
        .compositingGroup()
    }

    private var backgroundMaterial: some ShapeStyle {
        if scheme == .dark {
            return .thinMaterial.opacity(0.45)
        } else {
            return .regularMaterial.opacity(0.4)
        }
    }
}

extension AppCard where Content == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}
