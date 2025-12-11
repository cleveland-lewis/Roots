import SwiftUI

struct QuickActionFanOut: View {
    @Binding var isExpanded: Bool
    var addAssignment: () -> Void
    var addExam: () -> Void
    var addCourse: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: DesignSystem.Layout.spacing.small) {
                if isExpanded {
                    MiniActionButton(label: "Add Assignment", systemImage: "doc.badge.plus", action: addAssignment)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    MiniActionButton(label: "Add Exam", systemImage: "calendar.badge.clock", action: addExam)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    MiniActionButton(label: "Add Course", systemImage: "book.closed", action: addCourse)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isExpanded)
        }
    }
}

private struct MiniActionButton: View {
    let label: String
    let systemImage: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Layout.spacing.small) {
                Image(systemName: systemImage)
                    .font(DesignSystem.Typography.body)
                Text(label)
                    .font(DesignSystem.Typography.body)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(DesignSystem.Materials.hud, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(hovering ? 1.02 : 1.0)
        .onHover { hovering = $0 }
    }
}
