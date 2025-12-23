#if os(iOS)
import SwiftUI

/// Floating menu panel that mimics native iOS context menu style
/// - Dark material blur background
/// - Rounded corners with shadow
/// - Dismisses on outside tap
struct FloatingMenuPanel<Content: View>: View {
    let content: Content
    let width: CGFloat
    let maxHeight: CGFloat?
    @Binding var isPresented: Bool
    
    init(
        isPresented: Binding<Bool>,
        width: CGFloat = 280,
        maxHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.width = width
        self.maxHeight = maxHeight
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Scrim for tap-to-dismiss
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isPresented = false
                }
            
            // Menu panel
            VStack(spacing: 0) {
                content
            }
            .frame(width: width)
            .if(maxHeight != nil) { view in
                view.frame(maxHeight: maxHeight!)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .ignoresSafeArea()
    }
}

// Helper for conditional view modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#endif
