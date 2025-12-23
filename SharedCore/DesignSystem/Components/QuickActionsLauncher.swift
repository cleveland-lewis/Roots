import SwiftUI

struct QuickActionsLauncher: View {
    @Binding var isExpanded: Bool
    let actions: [QuickAction]
    let onSelect: (QuickAction) -> Void
    var expansionDirection: QuickActionsExpansionDirection = .trailing

    private let buttonSize: CGFloat = 44
    private let buttonSpacing: CGFloat = 10
    private let maxVisible: Int = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedAction: QuickActionsFocus?

    private var effectiveActions: [QuickAction] {
        let selection = actions.isEmpty ? QuickAction.defaultSelection : actions
        return Array(selection.prefix(maxVisible))
    }

    var body: some View {
        ZStack(alignment: expansionDirection.alignment) {
            ForEach(effectiveActions.indices, id: \.self) { index in
                let action = effectiveActions[index]
                actionButton(action)
                    .offset(x: isExpanded ? expansionDirection.multiplier * CGFloat(index + 1) * (buttonSize + buttonSpacing) : 0)
                    .opacity(isExpanded ? 1 : 0)
                    .scaleEffect(isExpanded ? 1 : 0.6)
                    .animation(actionAnimation(for: index), value: isExpanded)
                    .allowsHitTesting(isExpanded)
            }

            plusButton
                .zIndex(1)
        }
        .frame(height: buttonSize)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                focusedAction = effectiveActions.first.map { .action($0) } ?? .launcher
            } else {
                focusedAction = .launcher
            }
        }
        #if os(macOS)
        .onExitCommand {
            if isExpanded {
                toggleExpanded()
            }
        }
        #endif
    }

    private var plusButton: some View {
        Button {
            toggleExpanded()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: buttonSize, height: buttonSize)
                .background(DesignSystem.Materials.hud, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .opacity(focusedAction == .launcher ? 0.7 : 0)
                )
                .rotationEffect(.degrees(isExpanded && !reduceMotion ? 90 : 0))
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($focusedAction, equals: .launcher)
        .focusEffectDisabled(true)
        .accessibilityLabel(isExpanded ? "Collapse quick actions" : "Expand quick actions")
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: isExpanded)
    }

    private func actionButton(_ action: QuickAction) -> some View {
        Button {
            select(action)
        } label: {
            Image(systemName: action.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: buttonSize, height: buttonSize)
                .background(DesignSystem.Materials.hud, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .opacity(focusedAction == .action(action) ? 0.7 : 0)
                )
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($focusedAction, equals: .action(action))
        .focusEffectDisabled(true)
        .accessibilityLabel(action.title)
    }

    private func toggleExpanded() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82)) {
            isExpanded.toggle()
        }
    }

    private func select(_ action: QuickAction) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.85)) {
            isExpanded = false
        }
        focusedAction = .launcher
        onSelect(action)
    }

    private func actionAnimation(for index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .spring(response: 0.3, dampingFraction: 0.8).delay(Double(index) * 0.03)
    }
}

private enum QuickActionsFocus: Hashable {
    case launcher
    case action(QuickAction)
}

enum QuickActionsExpansionDirection {
    case leading
    case trailing

    var multiplier: CGFloat {
        switch self {
        case .leading: return -1
        case .trailing: return 1
        }
    }

    var alignment: Alignment {
        switch self {
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}
