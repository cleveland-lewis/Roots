import SwiftUI

struct DateDaySelector: View {
    @Binding var date: Date
    var onPrevious: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            GhostIconButton(systemName: "chevron.left", action: onPrevious)
            Text(date, formatter: DateDaySelector.dateFormatter)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            GhostIconButton(systemName: "chevron.right", action: onNext)
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 0)
        .accessibilityElement(children: .combine)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()
}

private struct GhostIconButton: View {
    let systemName: String
    let size: CGFloat = 36
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .background(
            Circle()
                .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
                .animation(.easeInOut(duration: 0.1), value: isHovering)
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.1)) { isHovering = hover }
        }
        .help(systemName.capitalized)
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    DateDaySelector(date: .constant(Date()), onPrevious: {}, onNext: {})
        .frame(width: 420)
}
#endif
