import SwiftUI

struct CardGrid<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let columns = max(1, min(5, Int(width / 260)))
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 20),
                    count: columns
                ),
                spacing: 20
            ) {
                content()
            }
            .contentTransition(.opacity)
        }
        .frame(minHeight: 0)
    }
}
