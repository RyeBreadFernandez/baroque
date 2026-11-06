import SwiftUI

// The concierge's props, each a painted object standing in front of the set: a postage stamp for the date, a brass
// barometer for the weather, velvet ribbons and plaques for labels, the week's pigeonholes, the register of room keys,
// and the brass desk bell. All are raised slabs or domed pebbles with cut sides and cast shadows.

// MARK: - Postage stamp

/// The date as a perforated postage stamp: cream card around a velvet panel, the day number in gold leaf, the month in
/// cream capitals, a little engraved range at the foot of the panel. No weekday.
struct GHDateStamp: View {
    enum Style { case large, medium, small }

    var date: Date
    var style: Style

    private var numeral: CGFloat {
        switch style {
        case .large: return 40
        case .medium: return 30
        case .small: return 26
        }
    }

    var body: some View {
        let day = GHDates.string(date, "d")
        let month = GHDates.string(date, style == .large ? "MMMM" : "MMM").uppercased()
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(day)
                    .font(Serif.font(numeral, weight: .medium))
                    .foregroundStyle(Gilt.style)
                    .legible(1.1)
                    .lineLimit(1)
                    .padding(.top, style == .large ? -1 : -2)
                    .padding(.bottom, style == .large ? -5 : -4)
                Text(month)
                    .ghCaps(style == .large ? 8.5 : 8, GH.cream, tracking: style == .large ? 0.9 : 0.8)
                    .raised(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(style == .large ? 0.94 : 1) // never under 8 pt
                    .padding(.horizontal, 2)
            }
            .padding(.bottom, style == .large ? 9 : 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { panel }
            if style == .large {
                // The issuer's name in the margin, as on a real stamp.
                Text("HOTEL TERRA")
                    .ghCaps(8, GH.burgundy, tracking: 0.5)
                    .ghPressed()
                    .lineLimit(1)
                    .padding(.top, 3)
                    .padding(.bottom, -1)
            }
        }
        .padding(style == .small ? 4.5 : 5.5)
        .ghSlab(.cream, shape: GHPerforated(hole: style == .small ? 1.6 : 2.0), depth: 1.8, inlay: false)
    }

    /// The printed panel: velvet, set into the card with a shaded upper lip and a gilt hairline, over an engraved range.
    private var panel: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                GHSurface(material: .velvet, weave: 0.6)
                    .overlay(GHMaterial.velvet.lighting)
                RidgeShape(profile: RidgeProfile(keys: [CGPoint(x: 0, y: 0.86), CGPoint(x: 0.2, y: 0.76), CGPoint(x: 0.36, y: 0.82),
                                                         CGPoint(x: 0.55, y: 0.66), CGPoint(x: 0.72, y: 0.8), CGPoint(x: 0.86, y: 0.72),
                                                         CGPoint(x: 1, y: 0.82)], seed: 5, roughness: 0.25, levels: 3))
                    .fill(LinearGradient(colors: [Color(hex: 0xE57A9C).opacity(0.55), Color(hex: 0xC34A70).opacity(0.2)], startPoint: .top, endPoint: .bottom))
                SnowShape(profile: RidgeProfile(keys: [CGPoint(x: 0, y: 0.86), CGPoint(x: 0.2, y: 0.76), CGPoint(x: 0.36, y: 0.82),
                                                        CGPoint(x: 0.55, y: 0.66), CGPoint(x: 0.72, y: 0.8), CGPoint(x: 0.86, y: 0.72),
                                                        CGPoint(x: 1, y: 0.82)], seed: 5, roughness: 0.25, levels: 3), snowline: 0.78)
                    .fill(Color(hex: 0xFFE7EE).opacity(0.55))
                Rectangle()
                    .strokeBorder(LinearGradient(colors: [GH.shadow.opacity(0.65), .clear, Stone.goldBright.opacity(0.35)], startPoint: .top, endPoint: .bottom),
                                  lineWidth: 1.1)
                Rectangle()
                    .inset(by: 2.6)
                    .stroke(GH.goldLight.opacity(0.7), lineWidth: 0.5)
            }
            .frame(width: w, height: h)
        }
    }
}

/// A circular postmark in plum ink with wavy cancellation lines running off to the right, and the year in the ring.
struct GHPostmark: View {
    var year: String?
    var diameter: CGFloat
    var waves: Int = 3

    var body: some View {
        ZStack(alignment: .leading) {
            Canvas { ctx, size in
                let d = diameter
                let c = CGPoint(x: d / 2, y: size.height / 2)
                let ink = GH.plum.opacity(0.6)
                let r0 = d / 2 - 0.6
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r0, y: c.y - r0, width: r0 * 2, height: r0 * 2)), with: .color(ink), lineWidth: 1)
                let r1 = r0 * 0.74
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r1, y: c.y - r1, width: r1 * 2, height: r1 * 2)), with: .color(ink), lineWidth: 0.6)
                // star ticks around the ring
                var dots = Path()
                for k in 0..<16 {
                    let a = Double(k) / 16 * 2 * .pi
                    let rr = (r0 + r1) / 2
                    let p = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
                    dots.addEllipse(in: CGRect(x: p.x - 0.55, y: p.y - 0.55, width: 1.1, height: 1.1))
                }
                ctx.fill(dots, with: .color(ink))
                var p = Path()
                for k in 0..<waves {
                    let y = c.y - CGFloat(waves - 1) * d * 0.1 + CGFloat(k) * d * 0.2
                    p.move(to: CGPoint(x: d + 1, y: y))
                    var x = d + 1
                    var up = k % 2 == 0
                    while x < size.width {
                        p.addQuadCurve(to: CGPoint(x: x + d * 0.3, y: y), control: CGPoint(x: x + d * 0.15, y: y + (up ? -1 : 1) * d * 0.09))
                        x += d * 0.3
                        up.toggle()
                    }
                }
                ctx.stroke(p, with: .color(ink), lineWidth: 0.8)
            }
            if let year {
                Text(year)
                    .ghCaps(8, GH.plum.opacity(0.75), tracking: 0.4)
                    .frame(width: diameter)
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}

// MARK: - Barometer

/// A brass aneroid barometer in a painted bezel: bellboy-purple lacquer face, a pastel scale from rain to fair, a
/// raspberry needle set by the weather, and the temperature in gold leaf below the hub.
struct GHBarometer: View {
    var weather: WeatherSnapshot?
    var diameter: CGFloat

    var body: some View {
        let d = diameter
        ZStack {
            Canvas { ctx, _ in GHBarometer.draw(ctx, d: d, condition: weather.map { SkyCondition(code: $0.code) }) }
            Text(weather.map { GHText.temp($0.temperature) } ?? "—")
                .font(Serif.font(d * 0.27, weight: .semibold))
                .foregroundStyle(Gilt.style)
                .legible(0.9)
                .lineLimit(1)
                .fixedSize()
                .offset(x: weather == nil ? 0 : d * 0.025, y: d * 0.2)
        }
        .frame(width: d, height: d)
    }

    /// Scale position (0 = rain, 1 = fair) to a dial angle: the scale sweeps the upper 220 degrees.
    static func angle(_ s: Double) -> Double { 200 - 220 * s }

    static func reading(_ c: SkyCondition?) -> Double {
        guard let c else { return 0.5 }
        switch c {
        case .clear: return 0.86
        case .partly: return 0.68
        case .overcast, .fog: return 0.5
        case .rain: return 0.26
        case .snow: return 0.18
        case .storm: return 0.08
        }
    }

    static func polar(_ c: CGPoint, _ r: CGFloat, _ deg: Double) -> CGPoint {
        CGPoint(x: c.x + CGFloat(cos(deg * .pi / 180)) * r, y: c.y - CGFloat(sin(deg * .pi / 180)) * r)
    }

    static func draw(_ ctx: GraphicsContext, d: CGFloat, condition: SkyCondition?) {
        let c = CGPoint(x: d / 2, y: d / 2)
        func circle(_ r: CGFloat, _ dy: CGFloat = 0) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r + dy, width: r * 2, height: r * 2)) }
        let depth = max(1.6, d * 0.03)
        // two-part cast shadow, then the cut side of the bezel
        var soft = ctx
        soft.addFilter(.blur(radius: d * 0.07))
        soft.fill(circle(d / 2, depth + 3), with: .color(GH.shadow.opacity(0.45)))
        var tight = ctx
        tight.addFilter(.blur(radius: 1))
        tight.fill(circle(d / 2, depth * 0.6), with: .color(GH.shadow.opacity(0.5)))
        ctx.fill(circle(d / 2, depth), with: .linearGradient(Gradient(colors: GHMaterial.brass.edge), startPoint: CGPoint(x: 0, y: d * 0.5), endPoint: CGPoint(x: 0, y: d + depth)))
        // brushed brass bezel, lit from the upper left
        var bz = ctx
        bz.clip(to: circle(d / 2))
        bz.fill(circle(d / 2), with: .color(GHMaterial.brass.base))
        bz.draw(bz.resolve(GHTex.brass), in: CGRect(x: 0, y: 0, width: d, height: d))
        bz.fill(circle(d / 2), with: .conicGradient(Gradient(colors: [Color.white.opacity(0.35), .clear, GH.shadow.opacity(0.35), .clear, Color.white.opacity(0.35)]),
                                                     center: c, angle: .degrees(-135)))
        bz.fill(circle(d / 2), with: .radialGradient(Gradient(colors: [Stone.goldBright.opacity(0.45), .clear]),
                                                      center: CGPoint(x: d * 0.3, y: d * 0.2), startRadius: 0, endRadius: d * 0.45))
        ctx.stroke(circle(d / 2 - 0.5), with: .linearGradient(Gradient(colors: [Stone.goldBright.opacity(0.8), .clear, GH.shadow.opacity(0.5)]),
                                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: d)), lineWidth: 1)
        // the step down to the face: carved
        let rf = d * 0.41
        ctx.fill(circle(rf + d * 0.025), with: .color(GH.shadow.opacity(0.55)))
        // lacquered face
        var face = ctx
        face.clip(to: circle(rf))
        face.fill(circle(rf), with: .color(GHMaterial.plum.base))
        face.draw(face.resolve(GHTex.plum), in: CGRect(x: c.x - rf, y: c.y - rf, width: rf * 2, height: rf * 2))
        face.fill(circle(rf), with: .radialGradient(Gradient(colors: [Color(hex: 0x8A5A92).opacity(0.45), .clear]),
                                                    center: CGPoint(x: c.x - rf * 0.35, y: c.y - rf * 0.45), startRadius: 0, endRadius: rf * 1.1))
        // inner shadow under the bezel lip
        face.stroke(circle(rf).offsetBy(dx: 0, dy: d * 0.02), with: .color(GH.shadow.opacity(0.8)), lineWidth: d * 0.06)
        // pastel scale: rain (powder) -> change (lilac) -> fair (butter)
        let rs = d * 0.31
        let segs: [(Double, Double, Color)] = [(0, 0.34, Color(hex: 0x9EC3E6)), (0.34, 0.66, Color(hex: 0xC9B6E4)), (0.66, 1, Color(hex: 0xF6D57E))]
        for (a, b, col) in segs {
            var p = Path()
            for i in 0...18 {
                let s = a + (b - a) * Double(i) / 18
                let pt = polar(c, rs, angle(s))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            ctx.stroke(p, with: .color(col.opacity(0.9)), style: StrokeStyle(lineWidth: d * 0.055, lineCap: .butt))
        }
        var ticks = Path(), major = Path()
        for i in 0...20 {
            let s = Double(i) / 20
            let isMajor = i % 5 == 0
            let a = angle(s)
            let from = polar(c, rs - d * (isMajor ? 0.055 : 0.035), a), to = polar(c, rs + d * 0.03, a)
            if isMajor { major.move(to: from); major.addLine(to: to) } else { ticks.move(to: from); ticks.addLine(to: to) }
        }
        ctx.stroke(ticks, with: .color(GH.goldLight.opacity(0.8)), lineWidth: max(0.4, d * 0.008))
        ctx.stroke(major, with: .color(GH.goldLight), lineWidth: max(0.6, d * 0.014))
        // printed marks: a raindrop toward wet, a sun toward fair
        let dr = d * 0.03
        let dropC = polar(c, d * 0.2, angle(0.08))
        var drop = Path()
        drop.move(to: CGPoint(x: dropC.x, y: dropC.y - dr * 1.8))
        drop.addQuadCurve(to: CGPoint(x: dropC.x, y: dropC.y + dr), control: CGPoint(x: dropC.x + dr * 1.6, y: dropC.y + dr * 0.4))
        drop.addQuadCurve(to: CGPoint(x: dropC.x, y: dropC.y - dr * 1.8), control: CGPoint(x: dropC.x - dr * 1.6, y: dropC.y + dr * 0.4))
        ctx.fill(drop, with: .color(Color(hex: 0x9EC3E6)))
        let sunC = polar(c, d * 0.2, angle(0.92))
        var rays = Path()
        for k in 0..<8 {
            let a = Double(k) * 45
            rays.move(to: polar(sunC, dr * 1.5, a)); rays.addLine(to: polar(sunC, dr * 2.2, a))
        }
        ctx.stroke(rays, with: .color(Color(hex: 0xF6D57E)), lineWidth: max(0.4, d * 0.01))
        ctx.fill(Path(ellipseIn: CGRect(x: sunC.x - dr * 1.1, y: sunC.y - dr * 1.1, width: dr * 2.2, height: dr * 2.2)), with: .color(Color(hex: 0xF6D57E)))
        // needle with its shadow on the face
        let a = angle(reading(condition))
        let tip = polar(c, rs + d * 0.02, a)
        let tail = polar(c, d * 0.08, a + 180)
        let s1 = polar(c, d * 0.024, a + 90), s2 = polar(c, d * 0.024, a - 90)
        var needle = Path()
        needle.move(to: tip); needle.addLine(to: s1); needle.addLine(to: tail); needle.addLine(to: s2); needle.closeSubpath()
        var ns = ctx
        ns.addFilter(.blur(radius: 0.8))
        ns.fill(needle.offsetBy(dx: d * 0.012, dy: d * 0.025), with: .color(Color.black.opacity(0.45)))
        ctx.fill(needle, with: .linearGradient(Gradient(colors: condition == nil ? [Color(hex: 0xA58CA8), Color(hex: 0x7A607E)] : [Color(hex: 0xE0607F), GH.raspberryDeep]),
                                               startPoint: s1, endPoint: s2))
        // brass hub, domed
        let hub = CGRect(x: c.x - d * 0.055, y: c.y - d * 0.055, width: d * 0.11, height: d * 0.11)
        ctx.fill(Path(ellipseIn: hub.offsetBy(dx: 0, dy: d * 0.012)), with: .color(GH.shadow.opacity(0.5)))
        ctx.fill(Path(ellipseIn: hub), with: .radialGradient(Gradient(colors: [GH.goldLight, GH.gold, GH.goldDeep]),
                                                             center: CGPoint(x: hub.minX + hub.width * 0.35, y: hub.minY + hub.height * 0.3),
                                                             startRadius: 0, endRadius: hub.width * 0.7))
        // the glass: a crescent of reflected light
        var glint = Path()
        glint.move(to: polar(c, rf * 0.94, 165))
        glint.addQuadCurve(to: polar(c, rf * 0.94, 75), control: polar(c, rf * 0.72, 120))
        glint.addQuadCurve(to: polar(c, rf * 0.94, 165), control: polar(c, rf * 1.12, 120))
        ctx.fill(glint, with: .color(Color.white.opacity(0.22)))
    }
}

// MARK: - Ribbons and plaques

/// A ribbon with swallowtail notches at both ends. Insettable for the slab's ChamferRim.
struct GHRibbon: InsettableShape {
    var notch: CGFloat = 5
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let n = max(0, notch - inset * 0.5)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - n, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.midY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> GHRibbon {
        var s = self
        s.inset += amount
        return s
    }
}

/// One or two lines of capitals on a raised velvet plaque or ribbon: cream first line, gold second.
struct GHPlaque: View {
    var lines: [String]
    var ribbon = false
    var size: CGFloat = 8.5

    var body: some View {
        let content = VStack(spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { i, s in
                // Long labels close up their tracking, then shrink to 8 pt, then truncate.
                ViewThatFits(in: .horizontal) {
                    line(s, first: i == 0, tracking: size * (i == 0 ? 0.11 : 0.08))
                    line(s, first: i == 0, tracking: size * 0.02)
                    line(s, first: i == 0, tracking: 0).minimumScaleFactor(8 / size)
                }
            }
        }
        .padding(.horizontal, ribbon ? 11 : 7)
        .padding(.vertical, lines.count > 1 ? 5 : 3.5)
        if ribbon {
            content.ghSlab(.velvet, shape: GHRibbon(notch: 5), depth: 2, inlay: false)
        } else {
            content.ghSlab(.velvet, radius: 6, depth: 2.2, inlay: true)
        }
    }

    private func line(_ s: String, first: Bool, tracking: CGFloat) -> some View {
        Text(s)
            .ghCaps(size, first ? GH.cream : GH.goldLight, tracking: tracking, medium: !first)
            .raised(0.8)
            .lineLimit(1)
    }
}

// MARK: - Pigeonholes

/// The week as the concierge's pigeonholes: a mint enamel cabinet with seven dark slots, the date in each, today's
/// slot lit by a brass lamp, and a raspberry wax seal on every day that has something due. Dates only.
struct GHPigeonholes: View {
    var date: Date
    var tasks: [TaskItem]
    var height: CGFloat = 30

    var body: some View {
        let cal = Calendar.current
        let due = Set(tasks.compactMap { $0.due.map { cal.startOfDay(for: $0) } })
        HStack(spacing: 4) {
            ForEach(Array(GHDates.week(of: date).enumerated()), id: \.offset) { _, d in
                let today = cal.isDate(d, inSameDayAs: date)
                let past = !today && d < cal.startOfDay(for: date)
                slot(day: GHDates.string(d, "d"), today: today, past: past, sealed: due.contains(cal.startOfDay(for: d)))
            }
        }
        .padding(4)
        .ghSlab(.mint, radius: 9, depth: 2.5, inlay: false)
    }

    private func slot(day: String, today: Bool, past: Bool, sealed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        return ZStack {
            shape.fill(LinearGradient(colors: [Color(hex: 0x173B3A), Color(hex: 0x24524C)], startPoint: .top, endPoint: .bottom))
            CarvedRecess(shape: shape)
            if today {
                GHPebble(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), material: .brass)
                    .padding(2.5)
                    .shadow(color: GH.lamplight.opacity(0.6), radius: 3)
            }
            Text(day)
                .font(Serif.font(14.5, weight: today ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(today ? GH.burgundy : (past ? GH.cream.opacity(0.6) : GH.cream))
                .shadow(color: today ? Color.white.opacity(0.5) : GH.shadow.opacity(0.8), radius: 0, x: 0, y: today ? 0.6 : 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height - 8)
        .overlay(alignment: .bottomTrailing) {
            if sealed {
                GHSeal(size: 9)
                    .offset(x: 2.5, y: 2.5)
            }
        }
    }
}

/// A raspberry wax seal: a domed enamel pebble stamped with a gilt sparkle.
struct GHSeal: View {
    var size: CGFloat

    var body: some View {
        GHPebble(shape: Circle(), material: .raspberry)
            .overlay(Sparkle().fill(GH.goldLight.opacity(0.9)).frame(width: size * 0.42, height: size * 0.52))
            .frame(width: size, height: size)
    }
}

// MARK: - Register

/// A brass room key: a ring and a domed fob stamped with the room number; raspberry enamel when the task is late.
struct GHRoomKey: View {
    var number: Int
    var urgent: Bool
    var height: CGFloat

    var body: some View {
        let ring = height * 0.78
        HStack(spacing: -ring * 0.32) {
            Circle()
                .strokeBorder(LinearGradient(colors: [GH.goldLight, GH.gold, GH.goldDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: max(1.2, height * 0.13))
                .shadow(color: GH.shadow.opacity(0.4), radius: 0.4, x: 0, y: 0.6)
                .frame(width: ring, height: ring)
                .zIndex(1)
            Text("\(number)")
                .font(GHFont.caps(max(8, height * 0.68)))
                .foregroundStyle(urgent ? GH.cream : GH.plum)
                .shadow(color: urgent ? GH.shadow.opacity(0.6) : Color.white.opacity(0.5), radius: 0, x: 0, y: urgent ? -0.5 : 0.6)
                .padding(.leading, ring * 0.32)
                .frame(width: height * 1.5, height: height)
                .background(GHPebble(shape: Capsule(), material: urgent ? .raspberry : .brass))
        }
        .fixedSize()
    }
}

/// The due mark at the end of a row: a raspberry enamel chip when late, burgundy capitals for today, soft plum capitals
/// otherwise.
struct GHDueMark: View {
    var task: TaskItem
    var now: Date

    var body: some View {
        if let label = Mock.dueLabel(task, now: now)?.uppercased() {
            if task.isOverdue(asOf: now) {
                Text(label)
                    .ghCaps(8.5, GH.cream, tracking: 0.7)
                    .raised(0.7)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2)
                    .background(GHPebble(shape: Capsule(), material: .raspberry))
                    .fixedSize()
            } else if task.isDueToday(asOf: now) {
                Text(label).ghCaps(8.5, GH.burgundy, tracking: 1.1).ghPressed().fixedSize()
            } else {
                Text(label).ghCaps(8.5, GH.inkSoft, tracking: 0.9, medium: true).ghPressed().fixedSize()
            }
        }
    }
}

/// A one-line warning that shortens itself to fit (as ErrorLine), in the register's raspberry ink.
struct GHErrorLine: View {
    var message: String
    var prefix: String? = nil
    var color: Color = GH.raspberry
    var size: CGFloat = 9.5
    /// The last resort before truncating, for the narrowest footers.
    var short: String? = nil

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
            if let short { line(short) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func line(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: size - 1.5, weight: .semibold))
            Text(text)
                .font(GHFont.capsMedium(size))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(color)
        .ghPressed()
    }
}

/// The hotel register on cream card: a header with the count, then each task as a numbered room key in a ruled row
/// with a raspberry ledger margin, and the remainder at the foot.
struct GHRegister: View {
    enum Style { case large, medium, small }

    var tasks: [TaskItem]
    var error: String?
    var now: Date
    var style: Style

    private var maxRows: Int {
        switch style {
        case .large: return 5
        case .medium: return 3
        case .small: return 1
        }
    }
    private var shown: Int { min(tasks.count, maxRows) }
    private var rowHeight: CGFloat {
        switch style {
        case .large: return 18
        case .medium: return 15.5
        case .small: return 30
        }
    }
    private var keyHeight: CGFloat { style == .large ? 13.5 : 12.5 }

    var body: some View {
        VStack(spacing: 0) {
            if style == .large {
                header
                    .padding(.bottom, 5)
            }
            if tasks.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                rows
                Spacer(minLength: 0)
                footer
            }
        }
        .padding(.horizontal, style == .small ? 8 : 11)
        .padding(.top, style == .large ? 8 : (style == .small ? 6 : 5))
        .padding(.bottom, style == .small ? 5 : 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ghSlab(.cream, radius: style == .small ? 10 : 12, depth: style == .small ? 2.5 : 3)
    }

    private var header: some View {
        ZStack {
            HStack(spacing: 6) {
                GHFlourishRule().frame(maxWidth: .infinity)
                Text("THE REGISTER")
                    .ghCaps(9, GH.burgundy, tracking: 2.4)
                    .ghPressed()
                    .fixedSize()
                GHFlourishRule().frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 26)
            HStack {
                GHGiltSparkle(size: 9)
                Spacer()
                Text("\(tasks.count)")
                    .font(GHFont.caps(9.5))
                    .monospacedDigit()
                    .foregroundStyle(GH.cream)
                    .raised(0.7)
                    .frame(minWidth: 19, minHeight: 15)
                    .padding(.horizontal, tasks.count > 9 ? 3 : 0)
                    .background(GHPebble(shape: Capsule(), material: .raspberry))
                    .opacity(tasks.isEmpty ? 0 : 1)
            }
        }
        .frame(height: 15)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.prefix(shown).enumerated()), id: \.element.id) { i, t in
                row(t, number: i + 1)
                    .frame(height: rowHeight)
                    .overlay(alignment: .bottom) {
                        if i < shown - 1 || style != .small {
                            GHRule(color: Color(hex: 0x5A73A8)).opacity(0.8)
                        }
                    }
            }
        }
        .background(alignment: .leading) {
            // the ledger's double margin line, just after the keys
            HStack(spacing: 1.4) {
                Rectangle().fill(GH.raspberry.opacity(0.55)).frame(width: 0.6)
                Rectangle().fill(GH.raspberry.opacity(0.55)).frame(width: 0.6)
            }
            .padding(.leading, keyHeight * 1.5 + keyHeight * 0.78 * 0.68 + 3)
        }
    }

    private func row(_ t: TaskItem, number: Int) -> some View {
        HStack(alignment: style == .small ? .top : .center, spacing: 7) {
            GHRoomKey(number: number, urgent: t.isOverdue(asOf: now), height: keyHeight)
                .padding(.top, style == .small ? 1.5 : 0)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(t.text)
                    .font(Serif.font(style == .large ? 13.5 : (style == .small ? 12.5 : 12.5), weight: .medium))
                    .foregroundStyle(GH.espresso)
                    .ghPressed()
                    .lineLimit(style == .small ? 2 : 1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: style == .small)
                if style != .small && t.priority >= .high {
                    HStack(spacing: 1) {
                        ForEach(0..<(t.priority == .highest ? 2 : 1), id: \.self) { _ in GHGiltSparkle(size: 8) }
                    }
                    .fixedSize()
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 4)
            if style != .small {
                GHDueMark(task: t, now: now)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        let more = tasks.count - shown
        if style == .small {
            HStack(spacing: 4) {
                // A stale-cache warning takes the due mark's place; the count of the rest always stays.
                if let error {
                    GHErrorLine(message: error, size: 8.5, short: "Sync failed")
                        .layoutPriority(-1)
                } else if let first = tasks.first {
                    GHDueMark(task: first, now: now)
                }
                Spacer(minLength: 2)
                if more > 0 { Text(GHText.more(more)).ghCaps(8, GH.raspberry, tracking: 1).ghPressed().fixedSize() }
            }
            .frame(height: 13)
        } else if more > 0 || error != nil {
            HStack(spacing: 8) {
                if error == nil { Spacer(minLength: 0) }
                if more > 0 {
                    Text(GHText.more(more)).ghCaps(8.5, GH.raspberry, tracking: 2).ghPressed().fixedSize()
                }
                if let error {
                    GHErrorLine(message: error, prefix: "Cached")
                }
                Spacer(minLength: 0)
            }
            .frame(height: 12)
            .padding(.top, 1)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let failed = error != nil
        switch style {
        case .large:
            VStack(spacing: 5) {
                Image(systemName: failed ? "exclamationmark" : "key.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(failed ? GH.cream : GH.plum)
                    .frame(width: 32, height: 32)
                    .background(GHPebble(shape: Circle(), material: failed ? .raspberry : .brass))
                    .padding(3)
                    .background(CarvedRecess(shape: Circle()).opacity(0.5))
                Text(failed ? "Couldn't load tasks" : "Nothing due. Nice.")
                    .font(Serif.font(16, weight: .semibold))
                    .foregroundStyle(GH.burgundy)
                    .ghPressed()
                if let error {
                    Text(error)
                        .font(Serif.font(12.5, weight: .medium, italic: true))
                        .foregroundStyle(GH.raspberry)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .ghPressed()
                } else {
                    Text("EVERY KEY IS ON ITS HOOK").ghCaps(8.5, GH.inkSoft, tracking: 1.8, medium: true).ghPressed()
                }
            }
            .padding(.horizontal, 10)
        case .medium:
            HStack(spacing: 10) {
                Image(systemName: failed ? "exclamationmark" : "key.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(failed ? GH.cream : GH.plum)
                    .frame(width: 26, height: 26)
                    .background(GHPebble(shape: Circle(), material: failed ? .raspberry : .brass))
                VStack(alignment: .leading, spacing: 2) {
                    Text(failed ? "Couldn't load tasks" : "Nothing due. Nice.")
                        .font(Serif.font(14.5, weight: .semibold))
                        .foregroundStyle(GH.burgundy)
                        .ghPressed()
                    if let error {
                        Text(error)
                            .font(Serif.font(11.5, weight: .medium, italic: true))
                            .foregroundStyle(GH.raspberry)
                            .lineLimit(2)
                            .ghPressed()
                    } else {
                        Text("EVERY KEY IS ON ITS HOOK").ghCaps(8, GH.inkSoft, tracking: 1.4, medium: true).ghPressed()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
        case .small:
            VStack(alignment: .leading, spacing: 2) {
                Text(failed ? "Couldn't load tasks" : "Nothing due. Nice.")
                    .font(Serif.font(failed ? 12 : 13, weight: .semibold))
                    .foregroundStyle(GH.burgundy)
                    .ghPressed()
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                if let error {
                    Text(error)
                        .font(Serif.font(10.5, weight: .medium, italic: true))
                        .foregroundStyle(GH.raspberry)
                        .lineLimit(2)
                        .ghPressed()
                } else {
                    Text("EVERY KEY ON ITS HOOK").ghCaps(8, GH.inkSoft, tracking: 0.6, medium: true).ghPressed().lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A raspberry rule over a gold one, for headers on cream card.
struct GHFlourishRule: View {
    var body: some View {
        VStack(spacing: 1.2) {
            Rectangle().fill(GH.raspberry.opacity(0.75)).frame(height: 0.7)
            Rectangle().fill(GH.gold.opacity(0.85)).frame(height: 0.5)
        }
    }
}

// MARK: - Desk bell

/// The brass desk bell: the next-quote button. A domed brass bell with its plunger on a raspberry lacquer plinth, the
/// plinth's cut side showing, with a two-part shadow.
struct GHDeskBell: View {
    var size: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            let w = size, h = size * 0.86
            let plinth = CGRect(x: w * 0.04, y: h * 0.6, width: w * 0.92, height: h * 0.26)
            let depth = h * 0.08
            var soft = ctx
            soft.addFilter(.blur(radius: w * 0.07))
            soft.fill(Path(ellipseIn: plinth.offsetBy(dx: 0, dy: depth + 2.5)), with: .color(GH.shadow.opacity(0.55)))
            var tight = ctx
            tight.addFilter(.blur(radius: 0.8))
            tight.fill(Path(ellipseIn: plinth.offsetBy(dx: 0, dy: depth * 0.8)), with: .color(GH.shadow.opacity(0.6)))
            // the plinth's cut side, then its lacquered top
            var side = Path()
            side.addEllipse(in: plinth.offsetBy(dx: 0, dy: depth))
            side.addRect(CGRect(x: plinth.minX, y: plinth.midY, width: plinth.width, height: depth))
            ctx.fill(side, with: .linearGradient(Gradient(colors: GHMaterial.raspberry.edge), startPoint: CGPoint(x: 0, y: plinth.midY), endPoint: CGPoint(x: 0, y: plinth.maxY + depth)))
            var top = ctx
            top.clip(to: Path(ellipseIn: plinth))
            top.fill(Path(plinth), with: .color(GHMaterial.raspberry.base))
            top.draw(top.resolve(GHTex.raspberry), in: plinth.insetBy(dx: 0, dy: -plinth.height))
            top.fill(Path(plinth), with: .linearGradient(Gradient(colors: [Color.white.opacity(0.3), .clear, GH.shadow.opacity(0.3)]),
                                                         startPoint: CGPoint(x: plinth.minX, y: plinth.minY), endPoint: CGPoint(x: plinth.maxX, y: plinth.maxY)))
            ctx.stroke(Path(ellipseIn: plinth.insetBy(dx: w * 0.05, dy: h * 0.025)), with: .color(GH.goldLight.opacity(0.8)), lineWidth: 0.6)
            // the bell's shadow on the plinth
            var bs = ctx
            bs.addFilter(.blur(radius: 1.2))
            bs.fill(Path(ellipseIn: CGRect(x: w * 0.2, y: h * 0.66, width: w * 0.66, height: h * 0.14)), with: .color(GH.shadow.opacity(0.45)))
            // dome
            var dome = Path()
            let dl = w * 0.17, dr = w * 0.83, dy = h * 0.72
            dome.move(to: CGPoint(x: dl, y: dy))
            dome.addCurve(to: CGPoint(x: w / 2, y: h * 0.2), control1: CGPoint(x: dl, y: h * 0.42), control2: CGPoint(x: w * 0.3, y: h * 0.2))
            dome.addCurve(to: CGPoint(x: dr, y: dy), control1: CGPoint(x: w * 0.7, y: h * 0.2), control2: CGPoint(x: dr, y: h * 0.42))
            dome.addQuadCurve(to: CGPoint(x: dl, y: dy), control: CGPoint(x: w / 2, y: h * 0.8))
            dome.closeSubpath()
            var d = ctx
            d.clip(to: dome)
            d.fill(dome, with: .color(GHMaterial.brass.base))
            d.draw(d.resolve(GHTex.brass), in: CGRect(x: dl, y: h * 0.18, width: dr - dl, height: dy - h * 0.18))
            d.fill(dome, with: .radialGradient(Gradient(colors: [Stone.goldBright.opacity(0.7), .clear]),
                                               center: CGPoint(x: w * 0.36, y: h * 0.34), startRadius: 0, endRadius: w * 0.3))
            d.fill(dome, with: .radialGradient(Gradient(colors: [.clear, GH.shadow.opacity(0.45)]),
                                               center: CGPoint(x: w * 0.42, y: h * 0.36), startRadius: w * 0.18, endRadius: w * 0.42))
            var glint = Path()
            glint.move(to: CGPoint(x: w * 0.27, y: h * 0.55))
            glint.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.28), control: CGPoint(x: w * 0.27, y: h * 0.34))
            ctx.stroke(glint, with: .color(Color.white.opacity(0.75)), style: StrokeStyle(lineWidth: w * 0.04, lineCap: .round))
            ctx.stroke(dome, with: .linearGradient(Gradient(colors: [Stone.goldBright.opacity(0.7), GH.shadow.opacity(0.5)]),
                                                   startPoint: CGPoint(x: 0, y: h * 0.2), endPoint: CGPoint(x: 0, y: dy)), lineWidth: 0.6)
            // plunger
            let knob = CGRect(x: w * 0.44, y: h * 0.08, width: w * 0.12, height: h * 0.15)
            ctx.fill(Path(roundedRect: knob, cornerRadius: w * 0.04), with: .linearGradient(Gradient(colors: [GH.goldLight, GH.goldDeep]),
                                                                                           startPoint: CGPoint(x: knob.minX, y: 0), endPoint: CGPoint(x: knob.maxX, y: 0)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.4, y: h * 0.04, width: w * 0.2, height: h * 0.08)),
                     with: .radialGradient(Gradient(colors: [GH.goldLight, GH.gold]), center: CGPoint(x: w * 0.46, y: h * 0.06), startRadius: 0, endRadius: w * 0.1))
        }
        .frame(width: size, height: size * 0.86)
        .accessibilityLabel("Next quote")
    }
}
