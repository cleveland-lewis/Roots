import SwiftUI

#if !os(macOS)
enum AnalogDialStyle {
    case clock
    case stopwatch
}

/// Configurable analog dial with clock/stopwatch styling.
struct RootsAnalogClock: View {
    var style: AnalogDialStyle = .stopwatch
    var diameter: CGFloat = 200
    var showSecondHand: Bool = true
    var accentColor: Color = .accentColor
    var timerSeconds: TimeInterval? = nil // Timer state in seconds; nil = show system time

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        if let timerSeconds = timerSeconds {
            let components = timeComponents(from: timerSeconds)
            ZStack {
                AnalogDialView(style: style, diameter: diameter, accentColor: accentColor)
                stopwatchSubDialHands(hours: components.hours, minutes: components.minutes)
                AnalogClockHands(
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
            ZStack {
                AnalogDialView(style: style, diameter: diameter, accentColor: accentColor)
                TimelineView(.animation) { timeline in
                    let date = timeline.date
                    let components = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
                    let seconds = Double(components.second ?? 0) + Double(components.nanosecond ?? 0) / 1_000_000_000
                    let minutes = Double(components.minute ?? 0) + seconds / 60
                    let rawHours = Double(components.hour ?? 0)
                    let hours = rawHours.truncatingRemainder(dividingBy: 12) + minutes / 60

                    ZStack {
                        stopwatchSubDialHands(hours: hours, minutes: minutes)
                        AnalogClockHands(
                            radius: radius,
                            hours: hours,
                            minutes: minutes,
                            seconds: seconds,
                            showSecondHand: showSecondHand,
                            accentColor: accentColor
                        )
                    }
                }
            }
            .frame(width: diameter, height: diameter)
        }
    }

    @ViewBuilder
    private func stopwatchSubDialHands(hours: Double, minutes: Double) -> some View {
        if style == .stopwatch {
            StopwatchSubDialHand(
                diameter: diameter * 0.32,
                value: minutes / 60.0,
                accentColor: accentColor
            )
            .offset(y: radius * 0.28)

            StopwatchSubDialHand(
                diameter: diameter * 0.26,
                value: hours / 12.0,
                accentColor: accentColor
            )
            .offset(y: -radius * 0.16)
        }
    }

    /// Converts timer seconds to clock components (hours on 12-hour face, minutes, seconds)
    /// Defaults to 12:00:00 when timerSeconds is 0 or very small
    private func timeComponents(from timerSeconds: TimeInterval) -> (hours: Double, minutes: Double, seconds: Double) {
        guard timerSeconds >= 1.0 else {
            return (hours: 0.0, minutes: 0.0, seconds: 0.0)
        }

        let totalSeconds = Int(timerSeconds)
        let s = Double(totalSeconds % 60)
        let m = Double((totalSeconds / 60) % 60)
        let h = Double((totalSeconds / 3600) % 12)

        let fractionalSeconds = timerSeconds - Double(totalSeconds)
        let seconds = s + fractionalSeconds
        let minutes = m + seconds / 60.0
        let hours = h + minutes / 60.0

        return (hours: hours, minutes: minutes, seconds: seconds)
    }
}

struct AnalogDialView: View {
    let style: AnalogDialStyle
    let diameter: CGFloat
    let accentColor: Color

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        ZStack {
            switch style {
            case .stopwatch:
                StopwatchBezel(diameter: diameter)
                StopwatchTicks(diameter: diameter)
                StopwatchNumerals(diameter: diameter)
                StopwatchSubDialFace(
                    diameter: diameter * 0.32,
                    maxValue: 60,
                    numerals: [15, 30, 45, 60]
                )
                .offset(y: radius * 0.28)
                StopwatchSubDialFace(
                    diameter: diameter * 0.26,
                    maxValue: 12,
                    numerals: [3, 6, 9, 12]
                )
                .offset(y: -radius * 0.16)
            case .clock:
                ClockBezel(diameter: diameter)
                ClockTicks(diameter: diameter)
                ClockNumerals(diameter: diameter)
            }
        }
        .drawingGroup()
    }
}

struct StopwatchBezel: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .stroke(Color.primary.opacity(0.6), lineWidth: 2.5)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                    .frame(width: diameter * 0.86, height: diameter * 0.86)
            )
    }
}

struct ClockBezel: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .stroke(Color.primary.opacity(0.45), lineWidth: 2)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    .frame(width: diameter * 0.9, height: diameter * 0.9)
            )
    }
}

struct StopwatchTicks: View {
    let diameter: CGFloat

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        ZStack {
            ForEach(0..<60) { idx in
                let isFive = idx % 5 == 0
                let isQuarter = idx % 15 == 0
                let tickHeight: CGFloat = isQuarter ? 16 : (isFive ? 12 : 7)
                let tickWidth: CGFloat = isQuarter ? 3 : (isFive ? 2 : 1.25)
                let opacity: Double = isQuarter ? 0.9 : (isFive ? 0.7 : 0.5)
                let inset: CGFloat = 8

                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(opacity))
                    .frame(width: tickWidth, height: tickHeight)
                    .offset(y: -radius + inset + tickHeight / 2)
                    .rotationEffect(.degrees(Double(idx) * 6))
            }
        }
    }
}

struct ClockTicks: View {
    let diameter: CGFloat

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        ZStack {
            ForEach(0..<60) { idx in
                let isFive = idx % 5 == 0
                let tickHeight: CGFloat = isFive ? 12 : 6
                let tickWidth: CGFloat = isFive ? 2.5 : 1.2
                let opacity: Double = isFive ? 0.7 : 0.45
                let inset: CGFloat = 10

                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(opacity))
                    .frame(width: tickWidth, height: tickHeight)
                    .offset(y: -radius + inset + tickHeight / 2)
                    .rotationEffect(.degrees(Double(idx) * 6))
            }
        }
    }
}

struct StopwatchNumerals: View {
    let diameter: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var radius: CGFloat { diameter / 2 }

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

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    var body: some View {
        ZStack {
            ForEach(stride(from: 5, through: 60, by: 5), id: \.self) { value in
                let mapped = value % 60
                let angle = Double(mapped) / 60.0 * 360.0 - 90.0
                let radian = angle * .pi / 180.0
                let numeralDistance = radius * 0.86

                Text(formatNumber(value))
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .position(
                        x: radius + cos(radian) * numeralDistance,
                        y: radius + sin(radian) * numeralDistance
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stopwatch face with second numerals")
    }
}

struct ClockNumerals: View {
    let diameter: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var radius: CGFloat { diameter / 2 }

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

    private func baselineOffset(for hour: Int) -> CGFloat {
        switch hour {
        case 12: return fontSize * 0.15
        case 6: return -fontSize * 0.1
        default: return 0
        }
    }

    var body: some View {
        ZStack {
            ForEach(1...12, id: \.self) { hour in
                let angle = Double(hour) / 12.0 * 360.0 - 90.0
                let radian = angle * .pi / 180.0
                let numeralDistance = radius * 0.78

                Text(formatHour(hour))
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .baselineOffset(baselineOffset(for: hour))
                    .position(
                        x: radius + cos(radian) * numeralDistance,
                        y: radius + sin(radian) * numeralDistance
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Clock face with hour numerals")
    }
}

struct StopwatchSubDialFace: View {
    let diameter: CGFloat
    let maxValue: Int
    let numerals: [Int]

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.3), lineWidth: 1)

            ForEach(0..<60) { idx in
                let isMajor = idx % 5 == 0
                let tickOpacity: Double = isMajor ? 0.32 : 0.24
                let tickWidth: CGFloat = isMajor ? 2.2 : 1.3
                let tickHeight: CGFloat = isMajor ? 7.5 : 4.8
                let inset: CGFloat = 6

                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(tickOpacity))
                    .frame(width: tickWidth, height: tickHeight)
                    .offset(y: -radius + inset + tickHeight / 2)
                    .rotationEffect(.degrees(Double(idx) * 6))
            }

            ForEach(numerals, id: \.self) { numeral in
                let mapped = numeral == maxValue ? 0 : numeral
                let angle = Double(mapped) / Double(maxValue) * 360.0 - 90.0
                let radian = angle * .pi / 180.0

                Text("\(numeral)")
                    .font(.system(size: diameter * 0.12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.6))
                    .frame(width: diameter * 0.28, height: diameter * 0.2, alignment: .center)
                    .position(
                        x: radius + cos(radian) * radius * 0.72,
                        y: radius + sin(radian) * radius * 0.72
                    )
            }
        }
    }
}

struct StopwatchSubDialHand: View {
    let diameter: CGFloat
    let value: Double
    let accentColor: Color

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        ZStack {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sub-dial hand")
    }
}

struct AnalogClockHands: View {
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
#endif
