import SwiftUI

struct RootsSectionHeader<Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: RootsSpacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).rootsSectionHeader()
                if let subtitle { Text(subtitle).rootsCaption() }
            }
            Spacer()
            trailing
        }
    }
}

