import SwiftUI

/// Minimalist analog clock with concentric rings and cardinal ticks.
struct RootsAnalogClock: View {
    var diameter: CGFloat = 200
    var showSecondHand: Bool = true

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        TimelineView(.animation) { timeline in
            let date = timeline.date
            let components = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
            let seconds = Double(components.second ?? 0) + Double(components.nanosecond ?? 0) / 1_000_000_000
            let minutes = Double(components.minute ?? 0) + seconds / 60
            let hours = Double(components.hour ?? 0 % 12) + minutes / 60

            ZStack {
                face
                ticks
                hands(hours: hours, minutes: minutes, seconds: seconds)
            }
            .frame(width: diameter, height: diameter)
        }
    }

    private var face: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .overlay(
                    Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )

            ForEach(1..<4) { idx in
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    .frame(width: diameter * (1 - CGFloat(idx) * 0.15), height: diameter * (1 - CGFloat(idx) * 0.15))
            }
        }
    }

    private var ticks: some View {
        ZStack {
            // Cardinal ticks
            ForEach([0, 90, 180, 270], id: \.self) { angle in
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.65))
                    .frame(width: 6, height: 18)
                    .offset(y: -radius + 14)
                    .rotationEffect(.degrees(Double(angle)))
            }

            // Subtle hour ticks
            ForEach(0..<12) { idx in
                Capsule(style: .continuous)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3, height: 10)
                    .offset(y: -radius + 12)
                    .rotationEffect(.degrees(Double(idx) * 30))
            }
        }
    }

    private func hands(hours: Double, minutes: Double, seconds: Double) -> some View {
        ZStack {
            // Hour hand
            Capsule(style: .continuous)
                .fill(Color.primary)
                .frame(width: 8, height: radius * 0.5)
                .offset(y: -radius * 0.25)
                .rotationEffect(.degrees((hours / 12) * 360))

            // Minute hand
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.9))
                .frame(width: 6, height: radius * 0.7)
                .offset(y: -radius * 0.35)
                .rotationEffect(.degrees((minutes / 60) * 360))

            if showSecondHand {
                Capsule(style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: 2, height: radius * 0.85)
                    .offset(y: -radius * 0.42)
                    .rotationEffect(.degrees((seconds / 60) * 360))
            }

            Circle()
                .fill(Color.primary.opacity(0.9))
                .frame(width: 10, height: 10)
        }
    }
}
