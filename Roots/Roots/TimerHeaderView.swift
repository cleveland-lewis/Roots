import SwiftUI

struct TimerHeaderView: View {
    let now: Date
    @Binding var isMenuOpen: Bool
    var onAdd: () -> Void
    var onSettings: () -> Void

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        isMenuOpen.toggle()
                    }
                    onAdd()
                }) {
                    Image(systemName: "plus")
                        .font(.headline)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .rotationEffect(.degrees(isMenuOpen ? 90 : 0))
                }
                Spacer()
                Text("Timer")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.headline)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }

            VStack(spacing: 2) {
                Text(now, style: .time)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(dateFormatter.string(from: now))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
