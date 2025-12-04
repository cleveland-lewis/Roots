import SwiftUI

// MARK: - Environment key for popup text alignment

private struct PopupTextAlignmentKey: EnvironmentKey {
    static let defaultValue: TextAlignment = .leading
}

extension EnvironmentValues {
    var popupTextAlignment: TextAlignment {
        get { self[PopupTextAlignmentKey.self] }
        set { self[PopupTextAlignmentKey.self] = newValue }
    }
}

// MARK: - View helpers

extension View {
    /// Applies popup text alignment to the view hierarchy beneath this call.
    /// Use at the container level (e.g. RootsPopupContainer) to set a default alignment for popup/card text.
    func popupAlignedText(_ alignment: TextAlignment = .trailing) -> some View {
        environment(\.popupTextAlignment, alignment)
    }

    /// Applies the current popup text alignment environment value to a Text subtree.
    func applyPopupTextAlignment() -> some View {
        modifier(PopupTextAlignmentModifier())
    }
}

private struct PopupTextAlignmentModifier: ViewModifier {
    @Environment(\.popupTextAlignment) private var popupTextAlignment

    func body(content: Content) -> some View {
        content.multilineTextAlignment(popupTextAlignment)
    }
}

