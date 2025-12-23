#if os(iOS)
import SwiftUI

/// Individual row for FloatingMenuPanel matching iOS context menu style
/// - Full-width tappable area
/// - Left-aligned title with optional checkmark
/// - Right-aligned SF Symbol icon
/// - Subtle highlight on press (no blue outline)
/// - Separator support
struct FloatingMenuRow: View {
    let title: String
    let icon: String
    let isChecked: Bool
    let showSeparator: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        title: String,
        icon: String,
        isChecked: Bool = false,
        showSeparator: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isChecked = isChecked
        self.showSeparator = showSeparator
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                action()
            } label: {
                HStack(spacing: 12) {
                    // Optional checkmark
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 20)
                    }
                    
                    // Title
                    Text(title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
                .background(
                    isPressed ?
                        Color.white.opacity(0.15) :
                        Color.clear
                )
            }
            .buttonStyle(FloatingMenuButtonStyle(isPressed: $isPressed))
            
            // Separator
            if showSeparator {
                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.leading, isChecked ? 48 : 16)
            }
        }
    }
}

/// Custom button style for menu rows that shows press state without blue highlight
struct FloatingMenuButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                isPressed = newValue
            }
    }
}

/// Section header for menu groups
struct FloatingMenuSectionHeader: View {
    let title: String?
    
    var body: some View {
        if let title = title {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
    }
}

/// Thicker divider for section separation
struct FloatingMenuSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(height: 8)
    }
}

#endif
