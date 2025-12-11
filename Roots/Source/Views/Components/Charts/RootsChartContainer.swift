import SwiftUI
import Charts

struct RootsChartContainer<Content: View>: View {
    let title: String
    let summary: String?
    let trend: Trend?
    let content: Content

    init(title: String, summary: String? = nil, trend: Trend? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.summary = summary
        self.trend = trend
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DesignSystem.Typography.header)
                    if let summary = summary {
                        Text(summary).font(DesignSystem.Typography.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let trend = trend {
                    Image(systemName: trend == .up ? "arrow.up" : "arrow.down")
                        .foregroundColor(trend == .up ? .green : .red)
                }
            }
            .padding([.horizontal, .top], 12)

            content
                .frame(minHeight: 140)
                .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: DesignSystem.Corners.medium, style: .continuous)
                        .fill(DesignSystem.Materials.card))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Corners.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Corners.medium, style: .continuous)
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }
}

// Simple trend enum used by the container
enum Trend {
    case up, down
}
