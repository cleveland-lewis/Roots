import SwiftUI

struct GlassTabBar: View {
    @Binding var selected: RootTab
    @Namespace private var bubbleNamespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RootTab.allCases) { tab in
                button(for: tab)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.45))
                .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 10)
        )
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func button(for tab: RootTab) -> some View {
        let isSelected = (tab == selected)

        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2)) {
                selected = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13, weight: .semibold))

                Text(tab.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minWidth: 0)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.65))
        .background(
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 18, x: 0, y: 8)
                        .matchedGeometryEffect(id: "glassBubble", in: bubbleNamespace)
                }
            }
        )
    }
}
