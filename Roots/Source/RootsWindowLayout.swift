import SwiftUI

/// Minimal app window layout helper used by screens to provide stable sizes and background.
public struct RootsWindowLayout<Content: View>: View {
    public static var sidebarWidth: CGFloat { 280 }

    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            content()
                .frame(minWidth: 900, minHeight: 560)
        }
    }
}
