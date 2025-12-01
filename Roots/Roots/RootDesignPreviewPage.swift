import SwiftUI

struct RootDesignPreviewPage: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedMaterial: DesignMaterial = .regular

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                Text("Design Tokens")
                    .font(DesignSystem.Typography.title)

                // Colors
                VStack(alignment: .leading) {
                    Text("Colors").font(.headline)
                    HStack {
                        ColorSwatch(name: "Primary", color: DesignSystem.Colors.primary)
                        ColorSwatch(name: "Secondary", color: DesignSystem.Colors.secondary)
                        ColorSwatch(name: "Destructive", color: DesignSystem.Colors.destructive)
                        ColorSwatch(name: "Subtle", color: DesignSystem.Colors.subtle)
                        ColorSwatch(name: "Neutral", color: DesignSystem.Colors.neutral)
                    }
                }

                // Typography
                VStack(alignment: .leading) {
                    Text("Typography").font(.headline)
                    Text("Title / body / caption")
                        .font(DesignSystem.Typography.title)
                    Text("Body example")
                        .font(DesignSystem.Typography.body)
                    Text("Caption example")
                        .font(DesignSystem.Typography.caption)
                }

                // Materials
                VStack(alignment: .leading) {
                    Text("Materials").font(.headline)
                    Picker("Material", selection: $selectedMaterial) {
                        ForEach(DesignSystem.materials, id: \.name) { token in
                            Text(token.name).tag(token)
                        }
                    }
                    .pickerStyle(.segmented)

                    DesignCard(imageName: "Tahoe", material: .constant(selectedMaterial.material)) {
                        Image(systemName: "cube.fill")
                            .imageScale(.large)
                        Text("Material preview")
                    }
                    .frame(minHeight: DesignSystem.Cards.defaultHeight)
                }

                // Corners & spacing
                VStack(alignment: .leading) {
                    Text("Corners & Spacing").font(.headline)
                    HStack {
                        RoundedRectangle(cornerRadius: DesignSystem.Corners.small)
                            .fill(Color.secondary)
                            .frame(width: 60, height: 60)
                        RoundedRectangle(cornerRadius: DesignSystem.Corners.medium)
                            .fill(Color.secondary)
                            .frame(width: 60, height: 60)
                        RoundedRectangle(cornerRadius: DesignSystem.Corners.large)
                            .fill(Color.secondary)
                            .frame(width: 60, height: 60)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Design System Preview")
        .background(DesignSystem.background(for: colorScheme))
    }
}

private struct ColorSwatch: View {
    var name: String
    var color: Color

    var body: some View {
        VStack {
            Rectangle()
                .fill(color)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            Text(name).font(.caption)
        }
    }
}

#Preview {
    RootDesignPreviewPage()
}