import SwiftUI

struct RootsPopupContainer<Content: View, Footer: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.l) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).rootsSectionHeader()
                if let subtitle { Text(subtitle).rootsCaption() }
            }
            Divider()
            content
            Divider()
            footer
        }
        .padding(.horizontal, RootsSpacing.xl)
        .padding(.vertical, RootsSpacing.l)
        .frame(maxWidth: 560)
        .rootsGlassBackground(opacity: 0.20, radius: RootsRadius.popup)
        .rootsFloatingShadow()
        .popupTextAlignedLeft()
    }
}
