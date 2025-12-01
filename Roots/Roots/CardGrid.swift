import SwiftUI

struct CardGrid<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: DesignSystem.cardMinWidth, maximum: 360), spacing: 16)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            content()
        }
    }
}
