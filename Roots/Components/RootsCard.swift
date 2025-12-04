import SwiftUI

struct RootsCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    var icon: String?
    var footer: AnyView?
    var compact: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? RootsSpacing.m : RootsSpacing.l) {
            if title != nil || icon != nil || subtitle != nil {
                HStack(spacing: RootsSpacing.s) {
                    if let icon { Image(systemName: icon) }
                    VStack(alignment: .leading, spacing: 2) {
                        if let title { Text(title).rootsSectionHeader() }
                        if let subtitle { Text(subtitle).rootsCaption() }
                    }
                    Spacer()
                }
            }

            content

            if let footer {
                Divider()
                footer
            }
        }
        .padding(compact ? RootsSpacing.m : RootsSpacing.l)
        .rootsCardBackground()
        .rootsCardShadow()
    }
}

