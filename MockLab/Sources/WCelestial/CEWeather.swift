import SwiftUI

// The Weather widget: one instrument per size.
//   large   the full dial: month across the top of the limb (a pointer under it marks the day), the sky with the day
//           ring and the Matterhorn above the horizon, the sun times at the east and west points, the temperature at
//           the centre below the horizon with the condition and high/low under it, tonight's moon in the limb below.
//   medium  the sky hemisphere at left on a flat brass base (tonight's moon set into it), the reading engraved at right.
//   small   a compact dial: month above, temperature and condition below the horizon, the next sun time in the limb.

struct CEWeather: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        let dial = CEDial.spec(family)
        let arc = CEArc(snapshot)
        let condition = SkyCondition(code: snapshot.weather?.code)
        let phase = MoonPhase(date: snapshot.date)
        ZStack {
            CELacquer(family: family)
            CESky(dial: dial, arc: arc, condition: condition)
            if !dial.half { CEEarth(dial: dial) }
            CEEngraving(dial: dial, arc: arc, condition: condition, phase: phase, date: snapshot.date)
            CELimb(dial: dial, date: snapshot.date, family: family)
            reading(dial: dial, arc: arc, phase: phase)
            CEBrassRim(outer: dial.rimOuterPath, inner: dial.rimInnerPath, crest: dial.rimCrestPath, center: dial.center,
                       radius: dial.rimOuter + 2, plate: dial.recess, size: dial.size, groove: dial.rimGroovePath)
            if dial.half { CEBaseMoon(dial: dial, phase: phase) }
            CEScrews(points: CEWeather.screws(dial), radius: family == .large ? 4.4 : (family == .medium ? 2.9 : 3.3), size: dial.size)
        }
        .frame(width: dial.size.width, height: dial.size.height)
    }

    /// Where the screws go: the four corners outside a round dial, the two ends of the medium's base.
    static func screws(_ dial: CEDial) -> [CGPoint] {
        if dial.half {
            let y = dial.horizon + dial.baseBar / 2
            return [CGPoint(x: dial.center.x - dial.rimOuter + 7, y: y), CGPoint(x: dial.center.x + dial.rimOuter - 7, y: y)]
        }
        let i: CGFloat = dial.size.width > 200 ? 21 : 15
        let w = dial.size.width, h = dial.size.height
        return [CGPoint(x: i, y: i), CGPoint(x: w - i, y: i), CGPoint(x: i, y: h - i), CGPoint(x: w - i, y: h - i)]
    }

    // MARK: Reading

    private var temp: String {
        guard let w = snapshot.weather else { return "–" }
        return "\(Int(w.temperature.rounded()))"
    }

    private var condition: String { snapshot.weather?.label ?? "No forecast" }

    private var highLow: String? {
        guard let w = snapshot.weather else { return nil }
        return "HIGH \(Int(w.high.rounded()))°  ·  LOW \(Int(w.low.rounded()))°"
    }

    private var errorLine: String? {
        snapshot.weather == nil ? (snapshot.weatherError ?? "No forecast yet") : nil
    }

    /// The next of sunrise or sunset.
    private func nextSun(_ arc: CEArc) -> (String, String) {
        let now = snapshot.date
        if now < arc.rise { return ("SUNRISE", CETime.string(snapshot.weather?.sunrise)) }
        if now < arc.set { return ("SUNSET", CETime.string(snapshot.weather?.sunset)) }
        return ("SUNRISE", CETime.string(snapshot.weather?.sunrise))
    }

    @ViewBuilder
    private func reading(dial: CEDial, arc: CEArc, phase: MoonPhase) -> some View {
        switch family {
        case .large: large(dial)
        case .medium: medium(dial)
        case .small: small(dial, arc)
        }
    }

    /// The temperature in gold leaf, its degree sign set small at the cap height (Didot's own is a full-size ring).
    private func numeral(_ s: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: -s * 0.03) {
            Text(temp)
                .font(CEFont.numeral(s))
            if snapshot.weather != nil {
                Text("°")
                    .font(CEFont.numeral(s * 0.62))
                    .baselineOffset(s * 0.22)
            }
        }
        .foregroundStyle(CEGold.leaf)
        .opacity(snapshot.weather == nil ? 0.6 : 1)
        .ceRaisedLeaf()
        .fixedSize()
    }

    private func sunTime(_ label: String, _ time: String, size: CGFloat, labelSize: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(CEFont.caps(labelSize))
                .tracking(1.2)
                .foregroundStyle(CE.goldMuted)
            Text(time)
                .font(CEFont.numeral(size))
                .foregroundStyle(CEGold.type)
        }
        .ceInlay()
        .fixedSize()
    }

    private func large(_ dial: CEDial) -> some View {
        let c = dial.center
        let rise = CETime.string(snapshot.weather?.sunrise), set = CETime.string(snapshot.weather?.sunset)
        return ZStack {
            sunTime("SUNRISE", rise, size: 19, labelSize: 8.5)
                .position(x: c.x - 86, y: dial.horizon + 24)
            sunTime("SUNSET", set, size: 19, labelSize: 8.5)
                .position(x: c.x + 86, y: dial.horizon + 24)
            numeral(66)
                .position(x: c.x + 4, y: dial.horizon + 44)
            Text(condition)
                .font(CEFont.italic(19))
                .foregroundStyle(CE.parchment)
                .ceInlay()
                .fixedSize()
                .position(x: c.x, y: dial.horizon + 86)
            if let hl = highLow {
                Text(hl)
                    .font(CEFont.caps(9))
                    .tracking(0.8)
                    .foregroundStyle(CE.goldMuted)
                    .ceInlay()
                    .fixedSize()
                    .position(x: c.x, y: dial.horizon + 105)
            } else if let e = errorLine {
                Text(e)
                    .font(CEFont.italic(13))
                    .foregroundStyle(CE.copperInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .ceInlay()
                    .frame(width: 170)
                    .position(x: c.x, y: dial.horizon + 108)
            }
        }
        .frame(width: dial.size.width, height: dial.size.height)
    }

    private func medium(_ dial: CEDial) -> some View {
        // The reading in a column 86 pt wide, held inside the 16 pt margins (top of the figures to the last time).
        VStack(alignment: .leading, spacing: 0) {
            numeral(44)
                .padding(.leading, -2)
                .frame(height: 44, alignment: .bottom)
            Text(condition)
                .font(CEFont.italic(15))
                .foregroundStyle(CE.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .ceInlay()
                .padding(.top, 3)
            if let w = snapshot.weather {
                Text("H \(Int(w.high.rounded()))°  ·  L \(Int(w.low.rounded()))°")
                    .font(CEFont.caps(8.5))
                    .tracking(0.6)
                    .foregroundStyle(CE.goldMuted)
                    .ceInlay()
                    .padding(.top, 2)
            } else if let e = errorLine {
                Text(e)
                    .font(CEFont.italic(11))
                    .foregroundStyle(CE.copperInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .ceInlay()
                    .padding(.top, 1)
            }
            Spacer(minLength: 0)
            CERule()
                .frame(height: 3)
                .padding(.bottom, 5)
            CESunRow(rising: true, time: CETime.string(snapshot.weather?.sunrise))
            CESunRow(rising: false, time: CETime.string(snapshot.weather?.sunset))
                .padding(.top, 3)
        }
        .frame(width: 86, height: 132, alignment: .topLeading)
        .position(x: 245 + 43, y: 16 + 66)
        .frame(width: dial.size.width, height: dial.size.height)
    }

    private func small(_ dial: CEDial, _ arc: CEArc) -> some View {
        let c = dial.center
        let next = nextSun(arc)
        return ZStack {
            numeral(31)
                .position(x: c.x + 2, y: dial.horizon + 20)
            Text(condition)
                .font(CEFont.italic(10.5))
                .foregroundStyle(snapshot.weather == nil ? CE.copperInk : CE.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .ceInlay()
                .frame(width: 70)
                .position(x: c.x, y: dial.horizon + 40)
            CEArcText(text: "\(next.0) \(next.1)", center: c, radius: dial.monthRadius - 0.5, at: 90, step: 9.6,
                      font: CEFont.caps(8.5), style: AnyShapeStyle(CEGold.type), bottom: true, size: dial.size)
        }
        .frame(width: dial.size.width, height: dial.size.height)
    }
}

/// Sun times as "6:14" and "4:58" (a fixed POSIX format, so the Mac's 24-hour setting doesn't turn them into 06:14).
enum CETime {
    static func string(_ date: Date?) -> String {
        guard let date else { return "–:––" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }
}

// MARK: - Limb

/// The month in spaced capitals across the top of the limb, between two small stars; in the large dial a pointer on
/// the limb's inner edge marks how far through the month today is, with the day under it; in the large dial
/// tonight's moon sits in the limb at the foot of the dial.
struct CELimb: View {
    var dial: CEDial
    var date: Date
    var family: Family

    var body: some View {
        let month = CELimb.month(date)
        let span = Double(month.count) * dial.monthStep
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let days = cal.range(of: .day, in: .month, for: date)?.count ?? 30
        let pointer = -90 - span / 2 + span * (Double(day) - 0.5) / Double(days)
        ZStack {
            CEArcText(text: month, center: dial.center, radius: dial.monthRadius, at: -90, step: dial.monthStep,
                      font: CEFont.caps(dial.monthFont), style: AnyShapeStyle(CEGold.type), size: dial.size)
            Canvas { ctx, _ in
                let sheen = CEGold.sheen(dial.dialRect)
                let s = dial.monthFont * 0.36
                for a in [-90 - span / 2 - dial.monthStep * 0.55, -90 + span / 2 + dial.monthStep * 0.55] {
                    let p = CEEngrave.point(dial.center, dial.monthRadius + 0.4, a)
                    ctx.fill(CEEngrave.star(p, s).offsetBy(dx: 0.3, dy: 0.5), with: .color(CE.ink.opacity(0.8)))
                    ctx.fill(CEEngrave.star(p, s), with: sheen)
                }
                if family == .large {
                    // The day's pointer: a small gold wedge on the plate's edge, under the month.
                    let base = dial.limb + 0.4
                    let tip = CEEngrave.point(dial.center, base + 4.2, pointer)
                    let l = CEEngrave.point(dial.center, base, pointer - 1.6)
                    let r = CEEngrave.point(dial.center, base, pointer + 1.6)
                    var wedge = Path()
                    wedge.addLines([l, tip, r])
                    wedge.closeSubpath()
                    ctx.fill(wedge.offsetBy(dx: 0.3, dy: 0.6), with: .color(CE.ink.opacity(0.8)))
                    ctx.fill(wedge, with: .color(CE.goldBright))
                }
            }
            if family == .large {
                Text("\(day)")
                    .font(CEFont.numeral(10))
                    .foregroundStyle(CEGold.type)
                    .ceInlay()
                    .fixedSize()
                    .position(CEEngrave.point(dial.center, dial.limb - 8, pointer))
                Canvas { ctx, _ in
                    let c = CEEngrave.point(dial.center, dial.monthRadius, 90)
                    // A sunken aperture with tonight's moon in it, between two small stars.
                    ctx.fill(CEEngrave.circle(c, 7.6), with: .color(CE.ink.opacity(0.7)))
                    CEGlyph.moon(ctx, at: CGPoint(x: c.x, y: c.y + 0.3), r: 6, phase: MoonPhase(date: date), glow: false)
                    let sheen = CEGold.sheen(dial.dialRect)
                    for a in [90.0 - 7.5, 90 + 7.5] {
                        let p = CEEngrave.point(dial.center, dial.monthRadius, a)
                        ctx.fill(CEEngrave.star(p, 2.6), with: sheen)
                    }
                }
            }
        }
        .frame(width: dial.size.width, height: dial.size.height)
    }

    static func month(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL"
        return f.string(from: date).uppercased()
    }
}

/// Text set along an arc, letter by letter. Across the top it reads clockwise with the letters' feet toward the
/// centre; along the bottom (`bottom`) it reads left to right with their heads toward the centre.
struct CEArcText: View {
    var text: String
    var center: CGPoint
    var radius: CGFloat
    var at: Double       // degrees: -90 is the top, 90 the bottom
    var step: Double     // degrees per full letter
    var font: Font
    var style: AnyShapeStyle
    var bottom = false
    var size: CGSize

    private static func weight(_ c: Character) -> Double {
        switch c {
        case " ", ":", "·", ".", ",": return 0.5
        case "1", "I": return 0.7
        case "M", "W": return 1.2
        default: return 1
        }
    }

    var body: some View {
        let chars = Array(text)
        let weights = chars.map(Self.weight)
        let total = weights.reduce(0, +)
        ZStack {
            ForEach(chars.indices, id: \.self) { i in
                let mid = weights[..<i].reduce(0, +) + weights[i] / 2
                let offset = (mid - total / 2) * step
                let a = bottom ? at - offset : at + offset
                Text(String(chars[i]))
                    .font(font)
                    .foregroundStyle(style)
                    .ceInlay()
                    .fixedSize()
                    .rotationEffect(.degrees(bottom ? a - 90 : a + 90))
                    .position(CEEngrave.point(center, radius, a))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Medium parts

/// A gold rule engraved across the reading, with a small star at its middle.
struct CERule: View {
    var body: some View {
        Canvas { ctx, size in
            let y = size.height / 2
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            CEEngrave.line(ctx, p, width: 0.6, shading: .linearGradient(Gradient(colors: [CE.gold, CE.goldMid.opacity(0.2)]),
                                                                       startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), light: 0.6)
        }
    }
}

/// One sun time: an engraved half sun on its horizon (rising or setting), the label, and the time.
struct CESunRow: View {
    var rising: Bool
    var time: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height - 2.5)
                let r: CGFloat = 4.2
                var sun = Path()
                sun.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                sun.closeSubpath()
                ctx.fill(sun.offsetBy(dx: 0.3, dy: 0.5), with: .color(CE.ink.opacity(0.7)))
                ctx.fill(sun, with: .linearGradient(Gradient(colors: [CE.goldBright, CE.goldMid]), startPoint: CGPoint(x: c.x, y: c.y - r),
                                                    endPoint: c))
                var rays = Path()
                for i in 0..<5 {
                    let a = (180 + Double(i) * 45) * .pi / 180
                    rays.move(to: CGPoint(x: c.x + (r + 1.3) * CGFloat(cos(a)), y: c.y + (r + 1.3) * CGFloat(sin(a))))
                    rays.addLine(to: CGPoint(x: c.x + (r + 3.3) * CGFloat(cos(a)), y: c.y + (r + 3.3) * CGFloat(sin(a))))
                }
                var hz = Path()
                hz.move(to: CGPoint(x: 0, y: c.y + 0.4))
                hz.addLine(to: CGPoint(x: size.width, y: c.y + 0.4))
                CEEngrave.line(ctx, rays, width: 0.6, shading: .color(CE.gold), light: 0, groove: 0.6)
                CEEngrave.line(ctx, hz, width: 0.6, shading: .color(CE.gold), light: 0, groove: 0.6)
            }
            .frame(width: 14, height: 10)
            .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }
            Text(rising ? "RISE" : "SET")
                .font(CEFont.caps(8))
                .tracking(0.8)
                .foregroundStyle(CE.goldMuted)
                .fixedSize()
            Spacer(minLength: 2)
            Text(time)
                .font(CEFont.numeral(15.5))
                .foregroundStyle(CEGold.type)
                .fixedSize()
        }
        .ceInlay()
    }
}

/// Medium: tonight's moon set into the brass base under the horizon, at the middle.
struct CEBaseMoon: View {
    var dial: CEDial
    var phase: MoonPhase

    var body: some View {
        Canvas { ctx, _ in
            let c = CGPoint(x: dial.center.x, y: dial.horizon + dial.baseBar / 2)
            let r = dial.baseBar / 2 - 0.6
            ctx.fill(CEEngrave.circle(c, r + 1.3), with: .color(Color(hex: 0x2A1B06).opacity(0.85)))
            ctx.stroke(CEEngrave.circle(c, r + 1.3), with: .linearGradient(Gradient(colors: [Color(hex: 0x2A1B06), CE.goldBright]),
                                                                           startPoint: CGPoint(x: c.x - r, y: c.y - r),
                                                                           endPoint: CGPoint(x: c.x + r, y: c.y + r)), lineWidth: 0.6)
            CEGlyph.moon(ctx, at: c, r: r, phase: phase, glow: false)
        }
        .frame(width: dial.size.width, height: dial.size.height)
        .allowsHitTesting(false)
    }
}
