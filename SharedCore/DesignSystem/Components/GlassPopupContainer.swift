import SwiftUI

struct GlassPopupContainer<Content: View>: View {
    let content: Content
    let onDismiss: () -> Void
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.colorScheme) private var colorScheme

    init(onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onDismiss = onDismiss
    }

    var body: some View {
        let policy = MaterialPolicy(preferences: preferences)
        
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            content
                .padding(DesignSystem.Layout.padding.card)
                .background(policy.popupMaterial(colorScheme: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.primary.opacity(policy.borderOpacity), lineWidth: policy.borderWidth)
                )
                .shadow(color: DesignSystem.Colors.neutralLine(for: colorScheme).opacity(0.14), radius: 24, x: 0, y: 10)
                .transition(.opacity)
        }
    }
}
