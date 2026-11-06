import SwiftUI

// Pieces shared by the day widgets: due stamps, priority pilots, task rows, the smoked-glass list panel,
// the LED week ticker and the weather block.

enum NRTaskState {
    case late, today, later, none

    init(_ task: TaskItem) {
        if task.isOverdue(asOf: Mock.now) { self = .late }
        else if task.isDueToday(asOf: Mock.now) { self = .today }
        else if task.due != nil { self = .later }
        else { self = .none }
    }

    var color: Color {
        switch self {
        case .late: return NR.red
        case .today: return NR.sodium
        case .later, .none: return Color(hex: 0x8FE9E2)
        }
    }
}

/// The due label as a dot-matrix expiry stamp. Overdue prints red, today sodium, later a cold cyan.
struct NRDueStamp: View {
    var task: TaskItem
    var pitch: CGFloat = 1.2

    var body: some View {
        if let label = Mock.dueLabel(task) {
            let state = NRTaskState(task)
            NRDotStamp(text: label, color: state.color, pitch: pitch, glow: state == .later ? 0.35 : 0.85, seed: UInt64(task.lineNumber))
        }
    }
}

/// A tiny pilot lamp for the priority: lit red, amber or cyan, or an unlit glass bead.
struct NRPilot: View {
    var task: TaskItem
    var size: CGFloat = 7

    var body: some View {
        let (lit, color): (Bool, Color) = {
            if NRTaskState(task) == .late { return (true, NR.red) }
            switch task.priority {
            case .highest: return (true, NR.magenta)
            case .high: return (true, NR.sodium)
            case .medium: return (true, NR.cyan)
            default: return (false, NR.tealMist)
            }
        }()
        ZStack {
            if lit {
                Circle().fill(color.opacity(0.7)).frame(width: size * 2.6, height: size * 2.6).blur(radius: size * 0.6).blendMode(.plusLighter)
            }
            Circle()
                .fill(RadialGradient(colors: lit ? [.white, color, color.opacity(0.7)] : [Color(hex: 0x3B5551), Color(hex: 0x0E1A19)],
                                     center: UnitPoint(x: 0.38, y: 0.35), startRadius: 0, endRadius: size * 0.6))
                .overlay { Circle().strokeBorder(.black.opacity(0.7), lineWidth: 0.6) }
                .overlay(alignment: .topLeading) {
                    Circle().fill(.white.opacity(0.75)).frame(width: size * 0.26, height: size * 0.26).offset(x: size * 0.2, y: size * 0.16)
                }
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

/// One task line: pilot lamp, text, and the stamp either trailing or tucked under the text.
struct NRTaskRow: View {
    var task: TaskItem
    var font: CGFloat = 13.5
    var pitch: CGFloat = 1.2
    var stampBelow = false

    var body: some View {
        let late = NRTaskState(task) == .late
        HStack(alignment: stampBelow ? .top : .center, spacing: 8) {
            NRPilot(task: task, size: font * 0.5)
                .padding(.top, stampBelow ? font * 0.42 : 0)
            if stampBelow {
                VStack(alignment: .leading, spacing: 3) {
                    label
                    NRDueStamp(task: task, pitch: pitch)
                }
            } else {
                label
                Spacer(minLength: 8)
                NRDueStamp(task: task, pitch: pitch)
            }
        }
        .background {
            if late {
                // The red stamp's light lies across the row.
                LinearGradient(colors: [NR.red.opacity(0.0), NR.red.opacity(0.13), NR.red.opacity(0.24)], startPoint: .leading, endPoint: .trailing)
                    .padding(.horizontal, -8).padding(.vertical, -3)
                    .blur(radius: 4)
            }
        }
    }

    private var label: some View {
        Text(task.text)
            .font(NR.body(font))
            .foregroundStyle(NR.paper)
            .lineLimit(1)
            .truncationMode(.tail)
            .nrLegible(0.8)
    }
}

/// Smoked glass for the list: dark tinted pane, bevelled edge catching neon on both sides, a cast shadow,
/// a diagonal sheen, and a few beads on its face.
struct NRPanel: View {
    var radius: CGFloat = 13
    var seed: UInt64 = 5
    var spillLeft: Color = NR.red
    var spillRight: Color = NR.cyan

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Color(hex: 0x0C1A19).opacity(0.86), Color(hex: 0x050B0B).opacity(0.92)], startPoint: .top, endPoint: .bottom))
            .overlay {
                // Sheen of the street lights on the glass.
                shape.fill(LinearGradient(stops: [.init(color: .clear, location: 0.0), .init(color: .white.opacity(0.06), location: 0.18),
                                                  .init(color: .clear, location: 0.32), .init(color: .clear, location: 0.7),
                                                  .init(color: NR.magenta.opacity(0.07), location: 1)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                // Light from the signs falling across the top of the pane.
                shape.fill(RadialGradient(colors: [spillLeft.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 150))
                shape.fill(RadialGradient(colors: [spillRight.opacity(0.11), .clear], center: .topTrailing, startRadius: 0, endRadius: 130))
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [NR.magenta.opacity(0.55), .white.opacity(0.28), NR.cyan.opacity(0.45)],
                                                  startPoint: .leading, endPoint: .trailing), lineWidth: 0.8)
            }
            .overlay {
                shape.inset(by: 1.4).strokeBorder(.black.opacity(0.55), lineWidth: 1)
            }
            .overlay {
                Canvas { ctx, size in
                    var rng = SeededRandom(seed: seed)
                    for _ in 0..<Int(size.width * size.height / 2600) {
                        let c = CGPoint(x: rng.unit() * size.width, y: rng.unit() * size.height)
                        let r = rng.range(0.5...1.3)
                        let tint = c.x < size.width / 2 ? NR.magenta : NR.cyan
                        NRGlass.drop(ctx, .init(c: c, r: r), color: tint)
                    }
                }
                .clipShape(shape)
                .opacity(0.8)
            }
            .shadow(color: .black.opacity(0.7), radius: 8, x: 0, y: 5)
            .shadow(color: NR.magenta.opacity(0.18), radius: 14, x: -4, y: 0)
    }
}

/// The week on an LED ticker: a dark bezel, the unlit dot grid showing through, today burning sodium.
struct NRWeekTicker: View {
    var date: Date
    var pitch: CGFloat = 1.05

    var body: some View {
        let days = NRDates.week(of: date)
        let cal = Calendar.current
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x030606), Color(hex: 0x0A1413)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    // Unlit LEDs.
                    Canvas { ctx, size in
                        var dots = Path()
                        let cols = Int((size.width - 8) / pitch), rows = 9
                        let y0 = (size.height - CGFloat(rows) * pitch) / 2
                        for r in 0..<rows {
                            for c in 0..<cols {
                                let x = 4 + (CGFloat(c) + 0.5) * pitch, y = y0 + (CGFloat(r) + 0.5) * pitch
                                dots.addEllipse(in: CGRect(x: x - pitch * 0.28, y: y - pitch * 0.28, width: pitch * 0.56, height: pitch * 0.56))
                            }
                        }
                        ctx.fill(dots, with: .color(Color(hex: 0x1D3431).opacity(0.75)))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .black.opacity(0.8)], startPoint: .top, endPoint: .bottom), lineWidth: 0.9)
                }
                .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 2.5)
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { d in
                    let today = cal.isDate(d, inSameDayAs: date)
                    NRDotStamp(text: NRDates.string(d, "EEE d"), color: today ? NR.sodium : Color(hex: 0x6FA59B),
                               pitch: pitch, glow: today ? 0.9 : 0.12, seed: UInt64(cal.component(.day, from: d)))
                        .opacity(today ? 1 : 0.75)
                        .frame(maxWidth: .infinity)
                        .background {
                            if today {
                                RoundedRectangle(cornerRadius: 3).fill(NR.sodium.opacity(0.12))
                                    .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(NR.sodium.opacity(0.55), lineWidth: 0.6) }
                                    .padding(.vertical, -4).padding(.horizontal, 2)
                                    .shadow(color: NR.sodium.opacity(0.5), radius: 4)
                            }
                        }
                }
            }
            .padding(.horizontal, 4)
            // Glass over the LEDs.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.07), .clear], startPoint: .top, endPoint: .center))
                .padding(1)
        }
    }
}

enum NRWeatherText {
    static func temp(_ v: Double) -> String { "\(Int(v.rounded()))°" }

    /// The next of sunrise or sunset after now, e.g. ("SUNSET", "4:58").
    static func sunEvent(_ w: WeatherSnapshot, now: Date = Mock.now) -> (String, String)? {
        if let rise = w.sunrise, now < rise { return ("SUNRISE", NRDates.string(rise, "h:mm")) }
        if let set = w.sunset, now < set { return ("SUNSET", NRDates.string(set, "h:mm")) }
        if let rise = w.sunrise { return ("SUNRISE", NRDates.string(rise, "h:mm")) }
        return nil
    }
}

/// Unlit tubes for when there is no weather: the sign is off.
struct NRDeadNeon: View {
    var text: String
    var height: CGFloat

    var body: some View {
        let lay = NRTubeFont.layout(text, height: height)
        let w = max(1.75, height * 0.075)
        Canvas { ctx, _ in
            for (i, pts) in lay.tubes {
                let p = NRNeon.path(pts).offsetBy(dx: 4, dy: 4)
                // Cold glass: a shadow on the wall, grey tube, a sliver of street light along its top.
                ctx.stroke(p.offsetBy(dx: w * 0.5, dy: w * 0.9), with: .color(.black.opacity(0.55)), style: StrokeStyle(lineWidth: w * 1.3, lineCap: .round, lineJoin: .round))
                ctx.stroke(p, with: .color(Color(hex: 0x56686A)), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
                ctx.stroke(p, with: .color(Color(hex: 0x1C2628)), style: StrokeStyle(lineWidth: w * 0.45, lineCap: .round, lineJoin: .round))
                ctx.stroke(p.offsetBy(dx: -w * 0.2, dy: -w * 0.25), with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: w * 0.2, lineCap: .round))
                // A last ember in the first tube, as if the sign just died.
                if i == 0 {
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: w * 1.2))
                        l.stroke(p, with: .color(NR.cyan.opacity(0.18)), style: StrokeStyle(lineWidth: w * 1.5, lineCap: .round))
                    }
                }
            }
        }
        .frame(width: lay.width + 8, height: height + 8)
        .padding(-4)
        .frame(width: lay.width, height: height)
    }
}
