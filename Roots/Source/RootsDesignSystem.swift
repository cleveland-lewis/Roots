import SwiftUI

// Design system tokens for spacing and radii
// Note: RootsSpacing and RootsRadius are defined in Roots/DesignTokensCompat.swift to avoid redeclaration

// MARK: - Responsive Grid

public struct RootsResponsiveGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable, Data.Index == Int {
    var items: Data
    let content: (Data.Element) -> Content

    public init(_ items: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.content = content
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: RootsSpacing.l)], spacing: RootsSpacing.l) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

