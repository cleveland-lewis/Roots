import SwiftUI

/// A lightweight design shell that provides the card style used across the app.
/// Includes a timestamp display to help with debugging and design iterations.
struct DesignShell<Content: View>: View {
    @Binding var selectedMaterialToken: DesignMaterial
    let imageName: String
    let timestamp: Date
    let content: () -> Content

    init(imageName: String = "Tahoe", selectedMaterial: Binding<DesignMaterial>, timestamp: Date = Date(), @ViewBuilder content: @escaping () -> Content) {
        self._selectedMaterialToken = selectedMaterial
        self.imageName = imageName
        self.timestamp = timestamp
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .overlay(alignment: .bottom) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.Corners.medium, style: .continuous)
                            .fill(selectedMaterialToken.material)

                        VStack(spacing: DesignSystem.Spacing.medium) {
                            content()
                        }
                        .padding(DesignSystem.Spacing.medium)
                    }
                    .padding(DesignSystem.Spacing.small)
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Corners.medium, style: .continuous))
                .frame(minHeight: DesignSystem.Cards.defaultHeight)

            Text("Updated: \(timestamp.formatted(.iso8601))")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StatefulPreviewWrapper(DesignMaterial.regular) { binding in
        DesignShell(selectedMaterial: binding, timestamp: Date(timeIntervalSince1970: 1760000000)) {
            Image(systemName: "cube.fill")
                .imageScale(.large)
            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
                .foregroundStyle(.primary)
        }
        .padding()
    }
}