import SwiftUI

func makeSidebarBackground(colorScheme: ColorScheme) -> AnyView {
    let tint = Color.primary.opacity(colorScheme == .dark ? 0.03 : 0.02)
    let bg = Color.clear
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .stroke(Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.06 : 0.03), lineWidth: 0.4)
        )
        .background(tint)
    return AnyView(bg)
}

func makeSidebarRowBackground(isSelected: Bool, colorScheme: ColorScheme) -> AnyView {
    if isSelected {
        let fill = Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12)
        let background = RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(fill)
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        return AnyView(background)
    } else {
        return AnyView(Color.clear)
    }
}
