import SwiftUI

extension EnvironmentValues {
    private struct PopupTextAlignmentKey: EnvironmentKey {
        static let defaultValue: TextAlignment = .leading
    }

    var popupTextAlignment: TextAlignment {
        get { self[PopupTextAlignmentKey.self] }
        set { self[PopupTextAlignmentKey.self] = newValue }
    }
}

extension View {
    func popupTextStyle() -> some View {
        self.environment(\.popupTextAlignment, .trailing)
    }

    func popupAlignedText(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.trailing)
    }

    func popupAlignedText(_ alignment: TextAlignment = .trailing) -> some View {
        environment(\.popupTextAlignment, alignment)
    }

    /// Applies the current popup text alignment environment value to a Text subtree.
    func applyPopupTextAlignment() -> some View {
        modifier(PopupTextAlignmentModifier())
    }

    /// Universal left-alignment modifier for popup containers.
    /// Enforces left-aligned text in all popup-style UI.
    func popupTextAlignedLeft() -> some View {
        self
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: Alignment.leading)
            .environment(\.popupTextAlignment, .leading)
            .environment(\.layoutDirection, .leftToRight)
    }
}

private struct PopupTextAlignmentModifier: ViewModifier {
    @Environment(\.popupTextAlignment) private var popupTextAlignment

    func body(content: Content) -> some View {
        content.multilineTextAlignment(popupTextAlignment)
    }
}
