import SwiftUI

struct GlassPopupContainer<Content: View>: View {
    let content: Content
    let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            content
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
                .transition(.opacity)
        }
    }
}
