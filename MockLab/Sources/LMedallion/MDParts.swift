import SwiftUI

// Pieces of the Medallion layout: the round date medallion (a raised disc lettered like a coin), the daylight
// dial that rings it, ornamental rules and fleurons, and the arched or round window that holds tonight's moon.
// Everything is built from the shipped materials in Theme.swift (StoneSurface, ChamferRim, CarvedRecess,
// Pebble, Gilt, Sparkle), so it ports into Shared/ unchanged.

// MARK: - Medallion

/// A round painted slab: brushed espresso face, lit chamfer, gold inlay, the cut side below and a cast shadow.
/// The round twin of `.stoneSlab(.panel)`.
struct MDDisc: View {
    var depth: CGFloat = 3

    var body: some View {
        let material = StoneMaterial.panel
        ZStack {
            Circle()
                .fill(LinearGradient(colors: material.edge, startPoint: .top, endPoint: .bottom))
                .offset(y: depth)
                .shadow(color: Stone.shadow.opacity(0.55), radius: 8, x: 0, y: depth + 3)
                .shadow(color: Stone.shadow.opacity(0.5), radius: 1, x: 0, y: depth * 0.6)
            StoneSurface(material: material)
                .overlay(material.lighting)
                .clipShape(Circle())
                .overlay(ChamferRim(shape: Circle()))
            Circle().inset(by: 4).stroke(Stone.gold.opacity(0.36), lineWidth: 0.6)
        }
    }
}

/// The date as a medallion: the weekday lettered round the top of the rim, the month round the bottom,
/// and the day in gold leaf in a carved field at the center.
struct MDMedallion: View {
    var date: Date
    var radius: CGFloat
    var numeral: CGFloat
    var lettering: CGFloat

    // The lettered ring between the gold inlay (4pt in from the rim) and the carved field.
    private var band: CGFloat { lettering + 4 }
    private var textRadius: CGFloat { radius - 4.5 - band / 2 }
    private var field: CGFloat { radius - 4 - band }

    private var weekdays: [String] {
        [date.formatted(.dateTime.weekday(.wide)), date.formatted(.dateTime.weekday(.abbreviated))].map { $0.uppercased() }
    }
    private var months: [String] {
        [date.formatted(.dateTime.month(.wide)), date.formatted(.dateTime.month(.abbreviated))].map { $0.uppercased() }
    }

    var body: some View {
        ZStack {
            MDDisc(depth: radius > 38 ? 3 : 2.5)
            Color.clear
                .frame(width: field * 2, height: field * 2)
                .carved(Circle())
            Circle()
                .stroke(Stone.gold.opacity(0.28), lineWidth: 0.6)
                .frame(width: field * 2 + 3, height: field * 2 + 3)
            // Stops between the two inscriptions, at nine and three o'clock.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Sparkle()
                    .fill(Stone.gold)
                    .frame(width: lettering * 0.5, height: lettering * 0.62)
                    .raised()
                    .offset(x: side * textRadius)
            }
            MDCoinLegend(top: .init(forms: weekdays, font: .system(size: lettering, weight: .bold),
                                    color: Stone.copperInk, tracking: lettering * 0.2),
                         bottom: .init(forms: months, font: Serif.font(lettering + 0.5, weight: .semibold),
                                       color: Stone.gold, tracking: lettering * 0.16),
                         radius: textRadius)
            Text(date, format: .dateTime.day())
                .font(Serif.font(numeral, weight: .medium))
                .foregroundStyle(Gilt.style)
                .raised(1.2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: field * 2 + 8)
                .offset(y: -numeral * 0.02)
        }
        .frame(width: radius * 2, height: radius * 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).month(.wide).day()))
    }
}

/// The two legends round the medallion, like the lettering on a coin: the weekday across the top reading
/// clockwise, the month across the bottom reading left to right with its letters' tops toward the center.
/// Glyphs are measured, so any name in any locale spaces evenly. Both legends take the same form: full names
/// when both fit within `maxAngle` degrees (closing up the letter spacing by up to half if needed), else both
/// abbreviated.
struct MDCoinLegend: View {
    struct Legend {
        var forms: [String] // full first, then shorter
        var font: Font
        var color: Color
        var tracking: CGFloat
    }

    var top: Legend
    var bottom: Legend
    var radius: CGFloat
    var maxAngle: Double = 160

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let budget = CGFloat(maxAngle * Double.pi / 180) * radius
            typealias Set = (glyphs: [GraphicsContext.ResolvedText], widths: [CGFloat])
            func measure(_ legend: Legend, form: Int) -> Set {
                let text = legend.forms[min(form, legend.forms.count - 1)]
                let glyphs = text.map { ctx.resolve(Text(String($0)).font(legend.font).foregroundStyle(legend.color)) }
                return (glyphs, glyphs.map { $0.measure(in: CGSize(width: 400, height: 400)).width })
            }
            // Letter spacing that fits the budget, or nil if even half the tracking is too wide.
            func tracking(_ set: Set, _ legend: Legend) -> CGFloat? {
                let gaps = CGFloat(max(1, set.widths.count - 1))
                let room = (budget - set.widths.reduce(0, +)) / gaps
                return room >= legend.tracking * 0.5 ? min(legend.tracking, room) : nil
            }
            let forms = max(top.forms.count, bottom.forms.count)
            var chosen: [(Set, CGFloat)] = []
            for form in 0..<forms {
                let t = measure(top, form: form), b = measure(bottom, form: form)
                if let tt = tracking(t, top), let bt = tracking(b, bottom) {
                    chosen = [(t, tt), (b, bt)]
                    break
                }
                if form == forms - 1 {
                    chosen = [(t, tracking(t, top) ?? top.tracking * 0.5), (b, tracking(b, bottom) ?? bottom.tracking * 0.5)]
                }
            }
            // Raised letters: the same tight shadow as `.raised()`.
            ctx.addFilter(.shadow(color: Stone.shadow.opacity(0.75), radius: 0.6, x: 0, y: 1))
            for (i, (set, track)) in chosen.enumerated() {
                let isBottom = i == 1
                let total = set.widths.reduce(0, +) + track * CGFloat(max(0, set.widths.count - 1))
                var s = -total / 2
                for (glyph, w) in zip(set.glyphs, set.widths) {
                    let a = (s + w / 2) / radius
                    var layer = ctx
                    if isBottom {
                        layer.translateBy(x: c.x + radius * sin(a), y: c.y + radius * cos(a))
                        layer.rotate(by: .radians(Double(-a)))
                    } else {
                        layer.translateBy(x: c.x + radius * sin(a), y: c.y - radius * cos(a))
                        layer.rotate(by: .radians(Double(a)))
                    }
                    layer.draw(glyph, at: .zero, anchor: .center)
                    s += w + track
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Daylight dial

/// Points on the dial, a horseshoe over the top of the medallion whose ends dip `drop` degrees below the
/// horizontal (sunrise and sunset come up from behind the peak): progress 0 at the left end, 0.5 at the top,
/// 1 at the right end.
enum MDArc {
    static let drop: Double = 30

    static func point(_ t: Double, center c: CGPoint, radius r: CGFloat, drop: Double = MDArc.drop) -> CGPoint {
        let start = (180 - drop) * Double.pi / 180
        let sweep = (180 + 2 * drop) * Double.pi / 180
        let a = start + sweep * min(1, max(0, t))
        return CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
    }
}

/// An open arc over the top of the frame's center, from progress `from` to `to`.
struct MDArcLine: Shape {
    var radius: CGFloat
    var from: Double = 0
    var to: Double = 1

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        let steps = max(2, Int(abs(to - from) * 64))
        for i in 0...steps {
            let pt = MDArc.point(from + (to - from) * Double(i) / Double(steps), center: c, radius: radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

/// The dial's channel as a solid band with round ends, insettable so `.carved` can cut it.
struct MDArcBand: InsettableShape {
    var radius: CGFloat
    var width: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        MDArcLine(radius: radius).path(in: rect)
            .strokedPath(StrokeStyle(lineWidth: max(0.1, width - inset * 2), lineCap: .round, lineJoin: .round))
    }

    func inset(by amount: CGFloat) -> MDArcBand {
        var band = self
        band.inset += amount
        return band
    }
}

/// The daylight dial: a channel carved round the top of the medallion from sunrise (left) to sunset (right),
/// gold leaf laid in it up to now, a dotted trail for the rest of the day, and a copper pebble at now.
/// At night the same arc runs from sunset to sunrise in moonlight, with tonight's moon as the marker.
struct MDDial: View {
    var clock: SkyClock
    var phase: MoonPhase
    var radius: CGFloat
    var width: CGFloat
    var marker: CGFloat

    var body: some View {
        let progress = min(1, max(0, clock.progress))
        let lit = clock.isDay ? Stone.goldBright : Stone.moonlight
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let now = MDArc.point(progress, center: c, radius: radius)
            ZStack {
                Color.clear.carved(MDArcBand(radius: radius, width: width))
                MDArcLine(radius: radius, from: progress, to: 1)
                    .stroke(lit.opacity(0.55), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [0.1, 3.6]))
                MDArcLine(radius: radius, from: 0, to: progress)
                    .stroke(LinearGradient(colors: clock.isDay ? [Stone.goldBright, Stone.gold, Color(hex: 0xB98C55)]
                                                               : [Stone.moonlight, Color(hex: 0xA9B3A6)],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: max(1.6, width * 0.34), lineCap: .round))
                    .shadow(color: lit.opacity(0.45), radius: 1.5)
                // End stops where the channel meets the horizon.
                ForEach([0.0, 1.0], id: \.self) { t in
                    Circle()
                        .fill(Stone.gold.opacity(0.9))
                        .frame(width: 2.6, height: 2.6)
                        .raised()
                        .position(MDArc.point(t, center: c, radius: radius))
                }
                Group {
                    if clock.isDay {
                        ZStack {
                            Circle()
                                .fill(RadialGradient(colors: [Stone.goldBright.opacity(0.42), .clear],
                                                     center: .center, startRadius: 0, endRadius: marker * 1.5))
                                .frame(width: marker * 3, height: marker * 3)
                            Pebble(shape: Circle())
                                .frame(width: marker, height: marker)
                        }
                    } else {
                        MoonDisc(radius: marker * 0.55, phase: phase)
                    }
                }
                .position(now)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The time printed at each end of the dial: sunrise and sunset by day, sunset and sunrise by night.
struct MDDialTime: View {
    var symbol: String
    var time: Date?

    var body: some View {
        HStack(spacing: 2.5) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Stone.copperInk)
            Group {
                if let time {
                    Text(time, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                } else {
                    Text("—")
                }
            }
            .font(.system(size: 10.5, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(Stone.gold)
        }
        .fixedSize()
        .legible()
    }

    /// Left and right ends for the current half of the day.
    static func ends(clock: SkyClock, weather: WeatherSnapshot?) -> (left: MDDialTime, right: MDDialTime) {
        let rise = MDDialTime(symbol: "sunrise.fill", time: weather?.sunrise)
        let set = MDDialTime(symbol: "sunset.fill", time: weather?.sunset)
        return clock.isDay ? (rise, set) : (set, rise)
    }
}

// MARK: - Ornament

/// A gold hairline that fades toward its outer end, with a dark cut under it.
struct MDHairline: View {
    var fadesLeading: Bool
    var strength: Double = 0.8

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Stone.gold.opacity(0), Stone.gold.opacity(strength)],
                                 startPoint: fadesLeading ? .leading : .trailing,
                                 endPoint: fadesLeading ? .trailing : .leading))
            .frame(height: 0.8)
            .shadow(color: Stone.shadow.opacity(0.85), radius: 0, x: 0, y: 0.8)
            .accessibilityHidden(true)
    }
}

/// A small gold sparkle with its glow.
struct MDSparkle: View {
    var size: CGFloat
    var color: Color = Stone.gold

    var body: some View {
        Sparkle()
            .fill(color)
            .frame(width: size * 0.82, height: size)
            .shadow(color: Stone.goldBright.opacity(0.55), radius: size * 0.22)
            .accessibilityHidden(true)
    }
}

private struct MDDot: View {
    var size: CGFloat = 2.4

    var body: some View {
        Circle().fill(Stone.gold.opacity(0.85)).frame(width: size, height: size).raised()
    }
}

/// An ornamental rule: hairlines fading outward, a dot either side, and a centerpiece (a sparkle, a heading).
struct MDRule<Center: View>: View {
    var width: CGFloat
    var gap: CGFloat = 6
    @ViewBuilder var center: Center

    var body: some View {
        HStack(spacing: gap) {
            MDHairline(fadesLeading: true)
            MDDot()
            center
            MDDot()
            MDHairline(fadesLeading: false)
        }
        .frame(width: width)
    }
}

/// A fleuron for the quote: a short rule with a sparkle and two dots each side.
struct MDFleuron: View {
    var width: CGFloat
    var sparkle: CGFloat = 10

    var body: some View {
        MDRule(width: width, gap: 5) {
            HStack(spacing: 5) {
                MDDot(size: 1.8)
                MDSparkle(size: sparkle)
                MDDot(size: 1.8)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One-line warning, centered: the shipped `ErrorLine`'s shortening ladder, laid out on the axis.
struct MDErrorLine: View {
    var message: String
    var prefix: String? = nil
    var color: Color
    var fontSize: CGFloat = 10

    private var firstSentence: String {
        guard let r = message.range(of: ". ") else { return message }
        return String(message[..<r.lowerBound]) + "."
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            line(prefix.map { "\($0) · \(message)" } ?? message)
            line(message)
            line(prefix.map { "\($0) · \(firstSentence)" } ?? firstSentence)
            line(firstSentence)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func line(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: fontSize - 1, weight: .semibold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: fontSize, weight: .semibold))
        .foregroundStyle(color)
    }
}

// MARK: - Moon window

/// A round-headed arch, insettable so it can be carved.
struct MDArchShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let rad = r.width / 2
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
        p.addRelativeArc(center: CGPoint(x: r.midX, y: r.minY + rad), radius: rad,
                         startAngle: .degrees(180), delta: .degrees(180))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> MDArchShape {
        var arch = self
        arch.inset += amount
        return arch
    }
}

/// Tonight's moon in a window cut into the sky: a carved arch or circle, framed in gold, with a few stars.
struct MDMoonWindow<S: InsettableShape>: View {
    var shape: S
    var phase: MoonPhase
    var moonRadius: CGFloat
    var moonCenter: UnitPoint = .center
    /// Stars inside the window, in unit coordinates; the first is a sparkle, the rest points of light.
    var stars: [UnitPoint] = []

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack {
                Color.clear.carved(shape)
                ZStack {
                    ForEach(Array(stars.enumerated()), id: \.offset) { i, p in
                        Group {
                            if i == 0 {
                                MDSparkle(size: 6, color: Stone.goldBright)
                            } else {
                                Circle()
                                    .fill(Stone.moonlight.opacity(0.85))
                                    .frame(width: 1.6, height: 1.6)
                                    .shadow(color: Stone.moonlight.opacity(0.6), radius: 1.5)
                            }
                        }
                        .position(x: s.width * p.x, y: s.height * p.y)
                    }
                    MoonDisc(radius: moonRadius, phase: phase)
                        .position(x: s.width * moonCenter.x, y: s.height * moonCenter.y)
                }
                .clipShape(shape)
                // Gold hairline frame with its shadow, a little outside the cut.
                shape.inset(by: -2.2)
                    .stroke(Stone.shadow.opacity(0.6), lineWidth: 0.8)
                    .offset(y: 0.8)
                shape.inset(by: -2.2)
                    .stroke(Stone.gold.opacity(0.62), lineWidth: 0.8)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Mountains

enum MDRidges {
    static let far = (top: Color(hex: 0x5A6D67), bottom: Color(hex: 0x3D4F4A))
    static let mid = (top: Color(hex: 0x34463F), bottom: Color(hex: 0x263630))
    static let near = (top: Color(hex: 0x1E2A24), bottom: Color(hex: 0x141C18))

    /// A ridge whose key points mirror about the center: give the left half (x from 0 up to 0.5).
    /// The seeded roughening still differs side to side, so the range reads balanced, not stamped.
    static func mirrored(_ left: [(CGFloat, CGFloat)], seed: UInt64, roughness: CGFloat = 0.16) -> RidgeProfile {
        var keys = left.map { CGPoint(x: $0.0, y: $0.1) }
        for k in left.reversed() where k.0 < 0.5 {
            keys.append(CGPoint(x: 1 - k.0, y: k.1))
        }
        return RidgeProfile(keys: keys, seed: seed, roughness: roughness)
    }
}
