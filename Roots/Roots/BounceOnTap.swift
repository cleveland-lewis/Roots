import SwiftUI

struct BounceOnTap: ViewModifier {
    @State private var bounce = false

    func body(content: Content) -> some View {
        content
            .symbolEffect(.bounce, value: bounce)
            .onTapGesture {
                bounce.toggle()
            }
    }
}

extension View {
    func bounceOnTap() -> some View {
        self.modifier(BounceOnTap())
    }
}
