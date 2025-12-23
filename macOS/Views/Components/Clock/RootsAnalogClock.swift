import SwiftUI

/// Minimalist analog clock with concentric rings and cardinal ticks.
/// When timerSeconds is provided, displays that time (defaulting to 12:00:00 when 0).
/// Otherwise shows system time.
struct RootsAnalogClock: View {
    var diameter: CGFloat = 200
    var showSecondHand: Bool = true
    var accentColor: Color = .accentColor
    var timerSeconds: TimeInterval? = nil // Timer state in seconds; nil = show system time

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        if let timerSeconds = timerSeconds {
            // Timer mode: display timer/stopwatch time (defaults to 12:00:00 when 0)
            let components = timeComponents(from: timerSeconds)
            ZStack {
                StopwatchBezel(diameter: diameter, accentColor: accentColor)
                StopwatchTicks(diameter: diameter)
                StopwatchNumerals(diameter: diameter)
                StopwatchSubDial(
                    diameter: diameter * 0.32,
                    value: components.minutes / 60.0,
                    maxValue: 60,
                    numerals: [15, 30, 45, 60],
                    accentColor: accentColor
                )
                .offset(y: radius * 0.28)
                StopwatchSubDial(
                    diameter: diameter * 0.26,
                    value: components.hours / 12.0,
                    maxValue: 12,
                    numerals: [3, 6, 9, 12],
                    accentColor: accentColor
                )
                .offset(y: -radius * 0.16)
                StopwatchHands(
                    radius: radius,
                    hours: components.hours,
                    minutes: components.minutes,
                    seconds: components.seconds,
                    showSecondHand: showSecondHand,
                    accentColor: accentColor
                )
            }
            .frame(width: diameter, height: diameter)
        } else {
            // System time mode: animated real-time clock
            TimelineView(.animation) { timeline in
                let date = timeline.date
                let components = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
                let seconds = Double(components.second ?? 0) + Double(components.nanosecond ?? 0) / 1_000_000_000
                let minutes = Double(components.minute ?? 0) + seconds / 60
                let hours = Double(components.hour ?? 0 % 12) + minutes / 60

                ZStack {
                    StopwatchBezel(diameter: diameter, accentColor: accentColor)
                    StopwatchTicks(diameter: diameter)
                    StopwatchNumerals(diameter: diameter)
                    StopwatchSubDial(
                        diameter: diameter * 0.32,
                        value: minutes / 60.0,
                        maxValue: 60,
                        numerals: [15, 30, 45, 60],
                        accentColor: accentColor
                    )
                    .offset(y: radius * 0.28)
                    StopwatchSubDial(
                        diameter: diameter * 0.26,
                        value: hours / 12.0,
                        maxValue: 12,
                        numerals: [3, 6, 9, 12],
                        accentColor: accentColor
                    )
                    .offset(y: -radius * 0.16)
                    StopwatchHands(
                        radius: radius,
                        hours: hours,
                        minutes: minutes,
                        seconds: seconds,
                        showSecondHand: showSecondHand,
                        accentColor: accentColor
                    )
                }
                .frame(width: diameter, height: diameter)
            }
        }
    }
    
    /// Converts timer seconds to clock components (hours on 12-hour face, minutes, seconds)
    /// Defaults to 12:00:00 when timerSeconds is 0 or very small
    private func timeComponents(from timerSeconds: TimeInterval) -> (hours: Double, minutes: Double, seconds: Double) {
        // Default to 12:00:00 when idle (0 seconds)
        guard timerSeconds >= 1.0 else {
            return (hours: 0.0, minutes: 0.0, seconds: 0.0)
        }
        
        let totalSeconds = Int(timerSeconds)
        let s = Double(totalSeconds % 60)
        let m = Double((totalSeconds / 60) % 60)
        let h = Double((totalSeconds / 3600) % 12)
        
        // Add fractional seconds for smooth animation
        let fractionalSeconds = timerSeconds - Double(totalSeconds)
        let seconds = s + fractionalSeconds
        let minutes = m + seconds / 60.0
        let hours = h + minutes / 60.0
        
        return (hours: hours, minutes: minutes, seconds: seconds)
    }
}

struct StopwatchBezel: View {
    let diameter: CGFloat
    let accentColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.28), lineWidth: 2)
                )
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                .frame(width: diameter * 0.88, height: diameter * 0.88)
            Circle()
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
                .frame(width: diameter * 0.68, height: diameter * 0.68)
        }
        .drawingGroup()
    }
}

struct StopwatchTicks: View {
    let diameter: CGFloat

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        ZStack {
            ForEach(0..<60) { idx in
                let isMajor = idx % 5 == 0
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(isMajor ? 0.75 : 0.45))
                    .frame(width: isMajor ? 3.5 : 2, height: isMajor ? 14 : 8)
                    .offset(y: -radius + (isMajor ? 16 : 14))
                    .rotationEffect(.degrees(Double(idx) * 6))
            }
        }
        .drawingGroup()
    }
}

struct StopwatchNumerals: View {
    let diameter: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var radius: CGFloat { diameter / 2 }
    
    /// Show cardinal hours (12, 3, 6, 9) for smaller clocks, all hours for larger
    private var hoursToShow: [Int] {
        diameter >= 250 ? Array(1...12) : [12, 3, 6, 9]
    }
    
    private var dynamicTypeSizeMultiplier: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.1
        case .xLarge: return 1.2
        case .xxLarge: return 1.3
        case .xxxLarge: return 1.4
        default: return 1.5
        }
    }
    
    private var fontSize: CGFloat {
        let baseSize = diameter / 12
        return baseSize * dynamicTypeSizeMultiplier
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: hour)) ?? "\(hour)"
    }

    var body: some View {
        ZStack {
            ForEach(hoursToShow, id: \.self) { hour in
                let angle = Double(hour) / 12.0 * 360.0 - 90.0
                let radian = angle * .pi / 180.0
                let numeralDistance = radius * 0.82
                
                Text(formatHour(hour))
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .position(
                        x: radius + cos(radian) * numeralDistance,
                        y: radius + sin(radian) * numeralDistance
                    )
            }
        }
        .drawingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Clock face with hour numerals")
    }
}

struct StopwatchSubDial: View {
    let diameter: CGFloat
    let value: Double
    let maxValue: Int
    let numerals: [Int]
    let accentColor: Color

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        ZStack {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                ForEach(0..<60) { idx in
                    let isMajor = idx % 5 == 0
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(isMajor ? 0.6 : 0.35))
                        .frame(width: isMajor ? 2.5 : 1.5, height: isMajor ? 8 : 5)
                        .offset(y: -radius + (isMajor ? 8 : 7))
                        .rotationEffect(.degrees(Double(idx) * 6))
                }

                ForEach(numerals, id: \.self) { numeral in
                    let mapped = numeral == maxValue ? 0 : numeral
                    let angle = Double(mapped) / Double(maxValue) * 360.0 - 90.0
                    Text("\(numeral)")
                        .font(.system(size: diameter * 0.12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.65))
                        .frame(width: diameter * 0.28, height: diameter * 0.2, alignment: .center)
                        .position(
                            x: radius + cos(angle * .pi / 180) * radius * 0.72,
                            y: radius + sin(angle * .pi / 180) * radius * 0.72
                        )
                }
            }
            .drawingGroup()

            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.9))
                .frame(width: 2, height: radius * 0.7)
                .offset(y: -radius * 0.35)
                .rotationEffect(.degrees(value * 360))

            Circle()
                .fill(accentColor.opacity(0.4))
                .frame(width: 5, height: 5)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct StopwatchHands: View {
    let radius: CGFloat
    let hours: Double
    let minutes: Double
    let seconds: Double
    let showSecondHand: Bool
    let accentColor: Color

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.primary)
                .frame(width: 8, height: radius * 0.5)
                .offset(y: -radius * 0.25)
                .rotationEffect(.degrees((hours / 12) * 360))

            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.9))
                .frame(width: 6, height: radius * 0.7)
                .offset(y: -radius * 0.35)
                .rotationEffect(.degrees((minutes / 60) * 360))

            if showSecondHand {
                Capsule(style: .continuous)
                    .fill(accentColor)
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
