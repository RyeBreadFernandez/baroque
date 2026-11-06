import SwiftUI

// The day as a sundial: the sun's path engraved across the painted sky from sunrise to sunset (by night, the moon's
// path from sunset to sunrise), with a tick at every hour and Roman numerals at the quarters of the clock. The part of
// the path already travelled is cut solid, the daylight still to come is dotted, and the sun or moon glows where it
// is now (OIPainting draws it on top). The feet stand on the far ridge with the times of sunrise and sunset; the next
// one is lettered in cream, the past one faded. The cut is an engraver's: a dark groove with a lit lip, so it reads on
// the bright snow and on the dark cloud alike.

/// The half-day the arc shows and where the hours fall on it. Mirrors SkyClock's rule (sunrise to sunset by day,
/// sunset to the next sunrise by night), so the dial and the sun agree.
struct OIDial {
    var start: Date
    var end: Date
    var progress: Double
    var isDay: Bool
    /// False when there is no weather, so no real sunrise or sunset: the arc stays, the feet go unlabelled.
    var knowsTimes: Bool
    /// Roman numerals at III, VI, IX and XII (large only), and the sunrise and sunset times at the feet.
    var numerals: Bool
    var feet: Bool
    var tick: CGFloat
    var numeralSize: CGFloat = 9.5

    init(now: Date, weather: WeatherSnapshot?, numerals: Bool, feet: Bool, tick: CGFloat = 3) {
        let cal = Calendar.current
        func today(_ d: Date?, hour: Int, minute: Int) -> Date {
            let c = d.map { cal.dateComponents([.hour, .minute], from: $0) }
            return cal.date(bySettingHour: c?.hour ?? hour, minute: c?.minute ?? minute, second: 0, of: now) ?? now
        }
        let rise = today(weather?.sunrise, hour: 6, minute: 30)
        let set = today(weather?.sunset, hour: 17, minute: 45)
        if now >= rise && now <= set {
            isDay = true
            start = rise
            end = set
        } else {
            isDay = false
            start = now > set ? set : set.addingTimeInterval(-86_400)
            end = now > set ? rise.addingTimeInterval(86_400) : rise
        }
        progress = min(1, max(0, now.timeIntervalSince(start) / max(1, end.timeIntervalSince(start))))
        knowsTimes = weather?.sunrise != nil && weather?.sunset != nil
        self.numerals = numerals
        self.feet = feet
        self.tick = tick
    }

    struct Mark { var progress: Double; var hour: Int }

    /// Every whole hour strictly between the feet.
    var marks: [Mark] {
        let cal = Calendar.current
        var out: [Mark] = []
        var h = cal.dateInterval(of: .hour, for: start)?.end ?? start
        let span = max(1, end.timeIntervalSince(start))
        while h < end {
            out.append(Mark(progress: h.timeIntervalSince(start) / span, hour: cal.component(.hour, from: h)))
            h = h.addingTimeInterval(3600)
        }
        return out
    }

    static func roman(_ hour: Int) -> String {
        switch hour % 12 {
        case 0: return "XII"
        case 3: return "III"
        case 6: return "VI"
        case 9: return "IX"
        default: return ""
        }
    }

    /// The left foot's time ("6:14" by day, the sunset by night) and the right foot's, the one still ahead.
    var leftTime: String { OMWords.clock(start) }
    var rightTime: String { OMWords.clock(end) }
}

/// The engraved path, its hour ticks and numerals, and the feet. Drawn in the widget's own coordinates.
struct OIDialEngraving: View {
    var dial: OIDial
    var arc: SkyArc

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Canvas { ctx, size in
                    let p = dial.progress
                    let groove = OMInk.shadow
                    // The cut: a soft dark groove along the whole path, then its lit lip.
                    ctx.stroke(path(0, 1, size), with: .color(groove.opacity(0.42)),
                               style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
                    ctx.stroke(path(0, p, size), with: .color(OMInk.cream.opacity(0.85)),
                               style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    // The daylight still to come: a row of cream points, each on its own dark seat.
                    ctx.stroke(path(p, 1, size), with: .color(groove.opacity(0.4)),
                               style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [0.01, 3.2]))
                    ctx.stroke(path(p, 1, size), with: .color(OMInk.cream.opacity(0.85)),
                               style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [0.01, 3.2]))
                    // Hour ticks, outward; longer at the numerals.
                    var cuts = Path()
                    for m in dial.marks {
                        let a = arc.point(m.progress, in: size)
                        let n = normal(m.progress, size)
                        let major = !OIDial.roman(m.hour).isEmpty
                        let len = dial.tick * (major ? 1.7 : 1)
                        cuts.move(to: CGPoint(x: a.x - n.x * 0.6, y: a.y - n.y * 0.6))
                        cuts.addLine(to: CGPoint(x: a.x + n.x * len, y: a.y + n.y * len))
                    }
                    // The feet: a short level bar where the path meets the ridge.
                    for f in [0.0, 1.0] {
                        let a = arc.point(f, in: size)
                        cuts.move(to: CGPoint(x: a.x - dial.tick * 1.2, y: a.y))
                        cuts.addLine(to: CGPoint(x: a.x + dial.tick * 1.2, y: a.y))
                    }
                    ctx.stroke(cuts, with: .color(groove.opacity(0.45)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
                    ctx.stroke(cuts, with: .color(OMInk.cream.opacity(0.8)), style: StrokeStyle(lineWidth: 0.85, lineCap: .round))
                }
                if dial.numerals {
                    ForEach(dial.marks.filter { !OIDial.roman($0.hour).isEmpty && $0.progress > 0.07 && $0.progress < 0.93 },
                            id: \.hour) { m in
                        let a = arc.point(m.progress, in: size)
                        let n = normal(m.progress, size)
                        let off = dial.tick * 1.7 + dial.numeralSize * 0.75
                        Text(OIDial.roman(m.hour))
                            .font(OMType.serif(dial.numeralSize))
                            .tracking(0.6)
                            .foregroundStyle(OMInk.creamSoft)
                            .fixedSize()
                            .omOnPaint(0.9)
                            .position(x: a.x + n.x * off, y: a.y + n.y * off)
                    }
                }
                if dial.feet && dial.knowsTimes {
                    // Under each foot, on the dark fir shore.
                    let l = arc.point(0, in: size), r = arc.point(1, in: size)
                    // The foot already passed: its time, faded. The one ahead: named, in cream.
                    feetLabel(dial.leftTime, next: false)
                        .frame(width: 80, alignment: .leading)
                        .position(x: max(16, l.x - 11) + 40, y: l.y + 10)
                    feetLabel("\(dial.isDay ? "sunset" : "sunrise") \(dial.rightTime)", next: true)
                        .frame(width: 80, alignment: .trailing)
                        .position(x: min(size.width - 16, r.x + 11) - 40, y: r.y + 10)
                }
            }
        }
    }

    private func feetLabel(_ time: String, next: Bool) -> some View {
        Text(time)
            .omLabel(8.5, next ? OMInk.cream : OMInk.creamFaint)
            .monospacedDigit()
            .fixedSize()
            .omOnPaint(1)
    }

    private func path(_ a: Double, _ b: Double, _ size: CGSize) -> Path {
        var p = Path()
        guard b > a else { return p }
        let steps = max(2, Int((b - a) * 90))
        for i in 0...steps {
            let t = a + (b - a) * Double(i) / Double(steps)
            let pt = arc.point(t, in: size)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    /// The outward normal of the path at a progress.
    private func normal(_ progress: Double, _ size: CGSize) -> CGPoint {
        let theta = Double.pi * (1 - progress)
        let rx = arc.radiusX * size.width, ry = arc.radiusY * size.height
        let nx = cos(theta) / rx, ny = -sin(theta) / ry
        let len = max(1e-9, (nx * nx + ny * ny).squareRoot())
        return CGPoint(x: nx / len, y: ny / len)
    }
}
