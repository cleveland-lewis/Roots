import SwiftUI

struct DesignPage: View {
    @State private var selectedMaterialToken: DesignMaterial = .regular

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.large) {
                AppCard {
                    Image(systemName: "cube.fill")
                        .imageScale(.large)

                    Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.primary)
                }
                .frame(minHeight: DesignSystem.Cards.defaultHeight)

                Picker("Material", selection: $selectedMaterialToken) {
                    ForEach(DesignSystem.materials, id: \.name) { token in
                        Text(token.name).tag(token)
                    }
                }
                .pickerStyle(.segmented)
                .padding(DesignSystem.Layout.padding.card)

                Spacer()
            }
            .navigationTitle("Design")
            .padding(DesignSystem.Layout.padding.card)
            .background(DesignSystem.background(for: .light))
        }
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    DesignPage()
}
#endif
