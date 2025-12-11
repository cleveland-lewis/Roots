import SwiftUI

struct GlassCircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        RootsHeaderButton(icon: systemName, size: 40) {
            action()
        }
    }
}
