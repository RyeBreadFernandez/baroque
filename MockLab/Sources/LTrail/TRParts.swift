import SwiftUI

// Pieces of the Trail layout built from the shipped materials: gilt numerals, copper pebbles, carved channels.

// MARK: - Date and weather

/// The date on one line: a gilt numeral with the weekday (copper small caps) and month stacked beside it.
struct TRDateLine: View {
    enum Style { case large, medium, small }

    var date: Date
    var style: Style

    private var numeral: CGFloat {
        switch style {
        case .large: return 42
        case .medium: return 34
        case .small: return 30
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: style == .small ? 5 : 7) {
            Text(date, format: .dateTime.day())
                .font(Serif.font(numeral, weight: .medium))
                .foregroundStyle(Gilt.style)
                .legible(1.2)
                .lineLimit(1)
                .fixedSize()
            VStack(alignment: .leading, spacing: style == .large ? 1 : 0) {
                Group {
                    if style == .small {
                        Text(date, format: .dateTime.weekday(.abbreviated))
                    } else {
                        Text(date, format: .dateTime.weekday(.wide))
                    }
                }
                .font(.system(size: style == .large ? 10.5 : 9.5, weight: .bold))
                .tracking(style == .large ? 2.2 : 1.5)
                .textCase(.uppercase)
                .foregroundStyle(Stone.copperInk)
                Group {
                    if style == .large {
                        Text(date, format: .dateTime.month(.wide).year())
                    } else if style == .medium {
                        Text(date, format: .dateTime.month(.wide))
                    } else {
                        Text(date, format: .dateTime.month(.abbreviated))
                    }
                }
                .font(Serif.font(style == .large ? 14 : 12.5, italic: true))
                .foregroundStyle(Stone.goldMuted)
            }
            .legible()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
    }
}

/// Weather written into the sky at the top right: glyph and gilt temperature, then the sky's label and
/// the day's range. "—" and "Unavailable" when there is no weather.
struct TRWeather: View {
    enum Style { case large, medium, small }

    var weather: WeatherSnapshot?
    var style: Style

    private var temp: String { weather.map { "\(Int($0.temperature.rounded()))°" } ?? "—" }
    private var symbol: String { weather?.symbolName ?? "cloud.fill" }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(alignment: .center, spacing: 4) {
                WeatherGlyph(symbol: symbol, size: style == .large ? 16 : (style == .medium ? 14 : 13))
                Text(temp)
                    .font(Serif.font(style == .large ? 28 : (style == .medium ? 24 : 21), weight: .semibold))
                    .foregroundStyle(Gilt.style)
                    .lineLimit(1)
                    .fixedSize()
            }
            if style != .small {
                Text(weather?.label ?? "Unavailable")
                    .font(Serif.font(style == .large ? 13 : 12, weight: .medium, italic: true))
                    .foregroundStyle(Stone.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, style == .large ? -1 : -2)
                if let w = weather {
                    HighLow(high: w.high, low: w.low, size: 10)
                        .foregroundStyle(Stone.gold)
                        .padding(.top, 1)
                }
            }
        }
        .legible()
    }
}

// MARK: - Week strip

/// Today and the six days after it, cut into the ground. Each day carries one gold pip per task due
/// (a numeral past four); today is the copper pebble at the trailhead.
struct TRWeekPips: View {
    var agenda: TRAgenda

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(agenda.week.enumerated()), id: \.offset) { i, day in
                let isToday = i == 0
                VStack(spacing: 0) {
                    Text(day.date, format: .dateTime.weekday(.narrow))
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.6)
                        .opacity(isToday ? 1 : 0.85)
                    Text(day.date, format: .dateTime.day())
                        .font(Serif.font(14.5, weight: isToday ? .bold : .semibold))
                        .monospacedDigit()
                        .padding(.top, -2)
                    TRPips(count: day.count, color: isToday ? Stone.parchment : Stone.gold)
                        .frame(height: 5)
                        .padding(.top, 1)
                }
                .foregroundStyle(isToday ? Stone.parchment : Stone.gold.opacity(0.92))
                .raised()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isToday { Pebble(shape: RoundedRectangle(cornerRadius: 10, style: .continuous)) }
                }
            }
        }
        .padding(2.5)
        .carved(RoundedRectangle(cornerRadius: 12.5, style: .continuous))
    }
}

/// Tasks due on a day as little gold beads.
struct TRPips: View {
    var count: Int
    var color: Color

    var body: some View {
        if count > 4 {
            Text("\(count)")
                .font(.system(size: 9, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(color)
                .fixedSize()
        } else {
            HStack(spacing: 2.5) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(color)
                        .overlay(Circle().fill(EllipticalGradient(colors: [.white.opacity(0.5), .white.opacity(0)],
                                                                  center: UnitPoint(x: 0.35, y: 0.3), endRadiusFraction: 0.7)))
                        .frame(width: 4.5, height: 4.5)
                }
            }
        }
    }
}

// MARK: - Thread and nodes

/// A gold wire inlaid in a carved channel, running down (or across) the trail. Solid over the stretch
/// already walked, dashed ahead. Coordinates are in the parent's space.
struct TRThread: View {
    var x: CGFloat
    var top: CGFloat
    var bottom: CGFloat
    /// The wire is solid down to here, then dashed.
    var walked: CGFloat
    var channel: CGFloat = 6

    var body: some View {
        ZStack(alignment: .topLeading) {
            CarvedRecess(shape: Capsule())
                .frame(width: channel, height: max(channel, bottom - top + channel))
                .offset(x: x - channel / 2, y: top - channel / 2)
            TRWire(from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: min(bottom, walked)), dashed: false)
            if walked < bottom {
                TRWire(from: CGPoint(x: x, y: max(top, walked)), to: CGPoint(x: x, y: bottom), dashed: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One straight run of gold wire with its lit edge.
struct TRWire: View {
    var from: CGPoint
    var to: CGPoint
    var dashed: Bool

    var body: some View {
        let line = Path { p in
            p.move(to: from)
            p.addLine(to: to)
        }
        let style = StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: dashed ? [2.2, 3.4] : [])
        ZStack {
            line.stroke(Stone.shadow.opacity(0.7), style: style).offset(y: 0.8)
            line.stroke(LinearGradient(colors: [Stone.goldBright, Stone.gold, Color(hex: 0xB98C55)],
                                       startPoint: .top, endPoint: .bottom),
                        style: style)
                .opacity(dashed ? 0.75 : 0.95)
        }
    }
}

/// A copper waypoint on the thread. Today's is larger and ringed in gold: you are here.
/// With a count, the number of tasks at the stop is lettered on the pebble.
struct TRNode: View {
    var size: CGFloat
    var here: Bool = false
    var count: Int? = nil

    var body: some View {
        ZStack {
            if here {
                Circle()
                    .stroke(Stone.gold.opacity(0.75), lineWidth: 0.9)
                    .frame(width: size + 6, height: size + 6)
                    .shadow(color: Stone.goldBright.opacity(0.5), radius: 2)
            }
            TRPebble()
                .frame(width: size, height: size)
            if let count {
                Text("\(count)")
                    .font(.system(size: size * 0.56, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Stone.parchment)
                    .raised()
            }
        }
        .frame(width: size + (here ? 6 : 0), height: size + (here ? 6 : 0))
    }
}

/// The shipped copper pebble (Theme.swift) at node size: the same paint, dome and rim, with only the contact
/// shadow, since the soft outer shadow barely shows on something this small and the trail has several.
struct TRPebble: View {
    var body: some View {
        StoneSurface(material: .copper)
            .overlay(EllipticalGradient(colors: [Stone.goldBright.opacity(0.45), .white.opacity(0)],
                                        center: UnitPoint(x: 0.34, y: 0.16), startRadiusFraction: 0, endRadiusFraction: 0.6))
            .overlay(EllipticalGradient(colors: [.clear, Stone.shadow.opacity(0.42)],
                                        center: UnitPoint(x: 0.45, y: 0.32), startRadiusFraction: 0.32, endRadiusFraction: 0.95))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(
                LinearGradient(colors: [Stone.goldBright.opacity(0.6), .white.opacity(0), Stone.shadow.opacity(0.4)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 0.8))
            .shadow(color: Stone.shadow.opacity(0.75), radius: 1.4, x: 0, y: 1.5)
    }
}

/// A stop with nothing at it: an empty socket cut into the ground, its lip catching the light.
struct TREmptyNode: View {
    var size: CGFloat
    var here: Bool = false

    var body: some View {
        ZStack {
            if here {
                Circle()
                    .stroke(Stone.gold.opacity(0.75), lineWidth: 0.9)
                    .frame(width: size + 6, height: size + 6)
            }
            Circle()
                .strokeBorder(Stone.gold.opacity(0.4), lineWidth: 0.8)
                .frame(width: size, height: size)
                .carved(Circle())
        }
    }
}

// MARK: - Rows

/// The gem colour the shipped rows use: copper when late, gold when high priority, sage otherwise.
func trAccent(_ task: TaskItem, stage: TRStage) -> Color {
    if stage == .late { return Stone.copperLight }
    if task.priority >= .high { return Stone.gold }
    return Stone.sage
}

/// A due label beside a row: a copper chip when late, gilt italic otherwise.
struct TRDue: View {
    var text: String
    var late: Bool
    var size: CGFloat = 12

    var body: some View {
        if late {
            Text(text)
                .font(.system(size: size - 2.5, weight: .bold))
                .foregroundStyle(Stone.parchment)
                .raised()
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Pebble(shape: Capsule()))
                .fixedSize()
        } else {
            Text(text)
                .font(Serif.font(size, weight: .medium, italic: true))
                .foregroundStyle(Stone.goldMuted)
                .raised()
                .fixedSize()
        }
    }
}

/// Small caps over the scene or a slab: the stage names on the trail.
struct TRCaps: View {
    var text: String
    var color: Color
    var size: CGFloat = 10
    var tracking: CGFloat = 1.6

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold))
            .tracking(tracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}
