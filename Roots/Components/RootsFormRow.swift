import SwiftUI

struct RootsFormRow<Control: View, Helper: View>: View {
    var label: String
    @ViewBuilder var control: Control
    @ViewBuilder var helper: Helper = EmptyView()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: RootsSpacing.m) {
                Text(label)
                    .rootsBodySecondary()
                    .frame(width: 110, alignment: .leading)
                control
                    .rootsBody()
            }
            helper
        }
    }
}

