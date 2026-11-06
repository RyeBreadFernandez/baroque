import SwiftUI

// MARK: - Pasted paper (legend insets, cartouche, title strips)

/// A slip of survey paper pasted onto the sheet: fibre texture, a double rule and a soft cast shadow.
struct PaperSlip: View {
    var rules = true
    var body: some View {
        ZStack {
            PaperFill()
            LinearGradient(colors: [.white.opacity(0.18), .clear, TopoInk.shadow.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if rules {
                Rectangle().strokeBorder(TopoInk.ink.opacity(0.9), lineWidth: 1)
                Rectangle().inset(by: 2.6).stroke(TopoInk.ink.opacity(0.65), lineWidth: 0.45)
            }
        }
        .clipped()
        .compositingGroup()
        .shadow(color: TopoInk.shadow.opacity(0.18), radius: 0.6, x: 0.3, y: 0.6)
        .shadow(color: TopoInk.shadow.opacity(0.26), radius: 3.5, x: 1.5, y: 2.5)
    }
}

/// A legend box title: tracked caps and a hairline that runs to the box edge.
struct LegendTitle: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(TopoFont.futuraBold(6.6)).tracking(1.2).foregroundColor(TopoInk.inkSoft).fixedSize()
            Rectangle().fill(TopoInk.inkSoft.opacity(0.6)).frame(height: 0.5)
        }
    }
}

// MARK: - Weather

/// The sun drawn as a survey symbol: a ringed disc with long and short rays. Other conditions use the SF Symbol in map inks.
struct WeatherGlyph: View {
    let symbol: String
    var size: CGFloat

    var body: some View {
        if symbol.hasPrefix("sun") {
            SunGlyph().frame(width: size, height: size)
        } else {
            Image(systemName: symbol)
                .symbolRenderingMode(.palette)
                .foregroundStyle(TopoInk.inkSoft, TopoInk.water)
                .font(.system(size: size * 0.78, weight: .medium))
                .frame(width: size, height: size)
        }
    }
}

struct SunGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = size.width / 2
            var rays = Path()
            for i in 0..<16 {
                let a = Double(i) * .pi / 8
                let r0 = r * 0.5, r1 = i % 2 == 0 ? r * 0.98 : r * 0.74
                rays.move(to: CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
                rays.addLine(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
            }
            ctx.stroke(rays, with: .color(TopoInk.red), style: StrokeStyle(lineWidth: r * 0.09, lineCap: .round))
            let disc = Path(ellipseIn: CGRect(x: c.x - r * 0.38, y: c.y - r * 0.38, width: r * 0.76, height: r * 0.76))
            ctx.fill(disc, with: .radialGradient(Gradient(colors: [Color(hex: 0xF2C25A), Color(hex: 0xD9762E)]),
                                                 center: CGPoint(x: c.x - r * 0.12, y: c.y - r * 0.12), startRadius: 0, endRadius: r * 0.45))
            ctx.stroke(disc, with: .color(TopoInk.redDeep), lineWidth: r * 0.08)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.09, y: c.y - r * 0.09, width: r * 0.18, height: r * 0.18)),
                     with: .color(TopoInk.redDeep))
        }
    }
}

/// Small triangle marks for high and low, as map spot symbols.
struct TriangleMark: Shape {
    var up: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if up {
            p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        }
        p.closeSubpath()
        return p
    }
}

struct HiLo: View {
    let up: Bool
    let value: Double
    var size: CGFloat = 13
    var body: some View {
        HStack(spacing: 3) {
            TriangleMark(up: up).fill(up ? TopoInk.red : TopoInk.water).frame(width: size * 0.5, height: size * 0.42)
            Text("\(Int(value.rounded()))°").font(TopoFont.din(size)).foregroundColor(TopoInk.ink).offset(y: size * 0.08)
        }
    }
}

struct SunTime: View {
    let rise: Bool
    let date: Date?
    var body: some View {
        HStack(spacing: 2.5) {
            SunHorizon(rise: rise).frame(width: 11, height: 7)
            Text(Mock.time(date)).font(TopoFont.menlo(8.6)).foregroundColor(TopoInk.inkSoft)
        }
    }
}

/// Half sun on a horizon line with an up or down tick.
struct SunHorizon: View {
    let rise: Bool
    var body: some View {
        Canvas { ctx, s in
            let base = s.height - 0.6
            var arc = Path()
            arc.addArc(center: CGPoint(x: s.width / 2, y: base), radius: s.height * 0.62,
                       startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            ctx.fill(arc, with: .color(Color(hex: 0xE09A3E)))
            ctx.stroke(arc, with: .color(TopoInk.redDeep), lineWidth: 0.6)
            var line = Path()
            line.move(to: CGPoint(x: 0, y: base)); line.addLine(to: CGPoint(x: s.width, y: base))
            ctx.stroke(line, with: .color(TopoInk.ink), lineWidth: 0.7)
            var tick = Path()
            let x = s.width / 2
            if rise {
                tick.move(to: CGPoint(x: x - 1.6, y: 1.6)); tick.addLine(to: CGPoint(x: x, y: 0)); tick.addLine(to: CGPoint(x: x + 1.6, y: 1.6))
            } else {
                tick.move(to: CGPoint(x: x - 1.6, y: 0)); tick.addLine(to: CGPoint(x: x, y: 1.6)); tick.addLine(to: CGPoint(x: x + 1.6, y: 0))
            }
            ctx.stroke(tick, with: .color(TopoInk.ink), lineWidth: 0.6)
        }
    }
}

// MARK: - Week as a scale bar

struct WeekScaleBar: View {
    let date: Date
    let width: CGFloat

    private var days: [Date] { TopoDates.week(date) }
    private var todayIndex: Int { days.firstIndex { Calendar.current.isDate($0, inSameDayAs: date) } ?? 0 }

    var body: some View {
        let seg = width / 7
        ZStack(alignment: .topLeading) {
            ScaleBarCanvas(today: todayIndex, seg: seg).frame(width: width, height: 26)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in dayColumn(i).frame(width: seg) }
            }
        }
        .frame(width: width, height: 40, alignment: .topLeading)
    }

    private func dayColumn(_ i: Int) -> some View {
        let isToday = i == todayIndex
        let letter = String(TopoDates.shortWeekday(days[i]).prefix(1))
        return VStack(spacing: 0) {
            Text(letter).font(TopoFont.futuraBold(7.6)).tracking(0.5)
                .foregroundColor(isToday ? TopoInk.red : TopoInk.inkSoft)
                .frame(height: 10)
            Spacer().frame(height: 12)
            Text(TopoDates.dayNumber(days[i])).font(TopoFont.din(isToday ? 18 : 16))
                .foregroundColor(isToday ? TopoInk.red : TopoInk.ink)
                .frame(height: 18)
        }
        .halo(strength: 0.9)
    }
}

/// Two-row checkered bar with ticks at every day boundary; today's segment is printed in survey red.
struct ScaleBarCanvas: View {
    let today: Int
    let seg: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let top: CGFloat = 12, h: CGFloat = 7
            let bar = CGRect(x: 0.5, y: top, width: size.width - 1, height: h)
            var shadowCtx = ctx
            shadowCtx.addFilter(.shadow(color: TopoInk.shadow.opacity(0.35), radius: 1.2, x: 0.6, y: 1))
            shadowCtx.fill(Path(bar), with: .color(TopoInk.paperLight))
            for i in 0..<7 {
                let x = CGFloat(i) * seg
                for row in 0..<2 {
                    let r = CGRect(x: x, y: top + CGFloat(row) * h / 2, width: seg, height: h / 2)
                    let dark = (i + row) % 2 == 0
                    if i == today {
                        ctx.fill(Path(r), with: .color(row == 0 ? TopoInk.red : TopoInk.redDeep))
                    } else if dark {
                        ctx.fill(Path(r), with: .color(TopoInk.ink.opacity(0.88)))
                    }
                }
            }
            // the first segment subdivided, as on a real scale bar
            for k in 0..<4 {
                let r = CGRect(x: CGFloat(k) * seg / 4, y: top, width: seg / 4, height: h / 2)
                if today != 0 { ctx.fill(Path(r), with: .color(k % 2 == 0 ? TopoInk.ink.opacity(0.88) : TopoInk.paperLight)) }
            }
            ctx.stroke(Path(bar), with: .color(TopoInk.ink), lineWidth: 0.8)
            var ticks = Path()
            for i in 0...7 {
                let x = min(max(CGFloat(i) * seg, 0.5), size.width - 0.5)
                ticks.move(to: CGPoint(x: x, y: top - 2.5)); ticks.addLine(to: CGPoint(x: x, y: top + h + 2.5))
            }
            ctx.stroke(ticks, with: .color(TopoInk.ink), lineWidth: 0.6)
            // a pointer over today
            let cx = (CGFloat(today) + 0.5) * seg
            var tri = Path()
            tri.move(to: CGPoint(x: cx - 3, y: top - 2.4)); tri.addLine(to: CGPoint(x: cx + 3, y: top - 2.4)); tri.addLine(to: CGPoint(x: cx, y: top + 0.6))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(TopoInk.red))
        }
    }
}

// MARK: - Waypoints

/// A numbered trail marker. Priority sets the print: highest a red disc with a ring, high a solid ink disc, medium a
/// heavy ring, none a light ring, low a dashed ring. Overdue tasks get the red hazard triangle.
struct Waypoint: View {
    let number: String
    let task: TaskItem?
    var size: CGFloat = 19

    private var overdue: Bool { task?.isOverdue(asOf: Mock.now) ?? false }

    var body: some View {
        ZStack {
            if overdue { hazard } else { disc }
        }
        .frame(width: size, height: size)
        .shadow(color: TopoInk.shadow.opacity(0.4), radius: 0.7, x: 0.4, y: 0.9)
    }

    private func numeral(_ color: Color, _ scale: CGFloat = 0.64) -> some View {
        Text(number).font(TopoFont.din(size * scale)).foregroundColor(color).offset(y: size * 0.07)
    }

    @ViewBuilder private var disc: some View {
        switch task?.priority ?? .lowest {
        case .highest:
            Circle().fill(TopoInk.red)
            Circle().inset(by: 1.6).stroke(TopoInk.paperLight, lineWidth: 0.8)
            Circle().stroke(TopoInk.redDeep, lineWidth: 0.8)
            numeral(TopoInk.paperLight)
        case .high:
            Circle().fill(TopoInk.ink)
            Circle().inset(by: 1.6).stroke(TopoInk.paperLight.opacity(0.8), lineWidth: 0.6)
            numeral(TopoInk.paperLight)
        case .medium:
            Circle().fill(TopoInk.paperLight)
            Circle().inset(by: 1).stroke(TopoInk.ink, lineWidth: 2)
            numeral(TopoInk.ink)
        case .none:
            Circle().fill(TopoInk.paperLight)
            Circle().inset(by: 0.5).stroke(TopoInk.ink, lineWidth: 1)
            numeral(TopoInk.ink)
        case .low, .lowest:
            Circle().fill(TopoInk.paperLight)
            Circle().inset(by: 0.5).stroke(TopoInk.ink, style: StrokeStyle(lineWidth: 1, dash: [2, 1.6]))
            numeral(TopoInk.inkSoft)
        }
    }

    @ViewBuilder private var hazard: some View {
        HazardTriangle().fill(TopoInk.red)
        HazardTriangle().inset(by: 1.6).stroke(TopoInk.paperLight, lineWidth: 0.7)
        HazardTriangle().stroke(TopoInk.redDeep, lineWidth: 0.8)
        numeral(TopoInk.paperLight, 0.56).offset(y: size * 0.12)
    }
}

struct HazardTriangle: InsettableShape {
    var inset: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let h = r.width * 0.92
        let top = r.midY - h * 0.58, bottom = top + h + inset * 0.3
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: top - inset * 0.6))
        p.addLine(to: CGPoint(x: r.maxX + inset * 0.2, y: bottom))
        p.addLine(to: CGPoint(x: r.minX - inset * 0.2, y: bottom))
        p.closeSubpath()
        return p
    }
    func inset(by amount: CGFloat) -> HazardTriangle { HazardTriangle(inset: inset + amount) }
}

/// The route: a red dashed trail with a paper casing, bending between the waypoint centres.
struct RoutePath: Shape {
    let points: [CGPoint]
    var bend: CGFloat = 7
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for (i, b) in points.dropFirst().enumerated() {
            let a = points[i]
            let side: CGFloat = i % 2 == 0 ? -bend : bend
            let dy = b.y - a.y
            p.addCurve(to: b, control1: CGPoint(x: a.x + side, y: a.y + dy * 0.35), control2: CGPoint(x: b.x + side, y: b.y - dy * 0.35))
        }
        return p
    }
}

struct RouteTrail: View {
    let points: [CGPoint]
    var body: some View {
        ZStack {
            RoutePath(points: points).stroke(TopoInk.paperLight.opacity(0.85), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            RoutePath(points: points).stroke(TopoInk.red, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [3.4, 2.4]))
        }
    }
}

// MARK: - Compass rose

struct CompassRose: View {
    var radius: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2 + 3)
            let R = radius
            let disc = Path(ellipseIn: CGRect(x: c.x - R * 0.7, y: c.y - R * 0.7, width: R * 1.4, height: R * 1.4))
            ctx.fill(disc, with: .color(TopoInk.paperLight.opacity(0.7)))
            ctx.stroke(disc, with: .color(TopoInk.ink), lineWidth: 0.7)
            let inner = Path(ellipseIn: CGRect(x: c.x - R * 0.58, y: c.y - R * 0.58, width: R * 1.16, height: R * 1.16))
            ctx.stroke(inner, with: .color(TopoInk.ink.opacity(0.8)), lineWidth: 0.4)
            var ticks = Path()
            for i in 0..<36 {
                let a = Double(i) * .pi / 18
                let r0 = i % 3 == 0 ? R * 0.58 : R * 0.64
                ticks.move(to: point(c, a, r0)); ticks.addLine(to: point(c, a, R * 0.7))
            }
            ctx.stroke(ticks, with: .color(TopoInk.ink.opacity(0.8)), lineWidth: 0.35)
            for i in 0..<4 { star(&ctx, c, Double(i) * .pi / 2 + .pi / 4, R * 0.6, R * 0.13, north: false) }
            for i in 0..<4 { star(&ctx, c, Double(i) * .pi / 2, R, R * 0.19, north: i == 0) }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 1.6, y: c.y - 1.6, width: 3.2, height: 3.2)), with: .color(TopoInk.paperLight))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 1.6, y: c.y - 1.6, width: 3.2, height: 3.2)), with: .color(TopoInk.ink), lineWidth: 0.5)
            let n = ctx.resolve(Text("N").font(TopoFont.futuraBold(R * 0.5)).foregroundColor(TopoInk.ink))
            ctx.draw(n, at: CGPoint(x: c.x, y: c.y - R - 1), anchor: .bottom)
        }
        .frame(width: radius * 2 + 4, height: radius * 2 + 12)
        .shadow(color: TopoInk.shadow.opacity(0.25), radius: 0.8, x: 0.5, y: 0.8)
    }

    private func point(_ c: CGPoint, _ a: Double, _ r: CGFloat) -> CGPoint {
        CGPoint(x: c.x + CGFloat(sin(a)) * r, y: c.y - CGFloat(cos(a)) * r)
    }

    /// One faceted point: the left half inked, the right half paper, so the star reads as a raised pyramid.
    private func star(_ ctx: inout GraphicsContext, _ c: CGPoint, _ a: Double, _ len: CGFloat, _ hw: CGFloat, north: Bool) {
        let tip = point(c, a, len)
        var left = Path(), right = Path()
        left.move(to: c); left.addLine(to: tip); left.addLine(to: point(c, a - .pi / 2, hw)); left.closeSubpath()
        right.move(to: c); right.addLine(to: tip); right.addLine(to: point(c, a + .pi / 2, hw)); right.closeSubpath()
        let dark = north ? TopoInk.red : TopoInk.ink
        ctx.fill(left, with: .color(dark))
        ctx.fill(right, with: .color(TopoInk.paperLight))
        ctx.stroke(right, with: .color(north ? TopoInk.redDeep : TopoInk.ink), lineWidth: 0.5)
        ctx.stroke(left, with: .color(north ? TopoInk.redDeep : TopoInk.ink), lineWidth: 0.5)
    }
}

// MARK: - Next quote: the "adjoining sheet" arrow

struct AdjoiningSheetButton: View {
    var body: some View {
        ZStack {
            PaperFill().clipShape(Circle())
            RadialGradient(colors: [.white.opacity(0.25), .clear, TopoInk.shadow.opacity(0.18)],
                           center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 18).clipShape(Circle())
            Circle().strokeBorder(TopoInk.ink, lineWidth: 1.2)
            Circle().inset(by: 3).stroke(TopoInk.ink.opacity(0.55), lineWidth: 0.45)
            BezelTicks().stroke(TopoInk.ink.opacity(0.7), lineWidth: 0.5)
            NextArrow().fill(TopoInk.red)
            NextArrow().stroke(TopoInk.redDeep, lineWidth: 0.5)
        }
        .frame(width: 30, height: 30)
        .shadow(color: TopoInk.shadow.opacity(0.22), radius: 0.6, x: 0.3, y: 0.6)
        .shadow(color: TopoInk.shadow.opacity(0.3), radius: 2.5, x: 1, y: 2)
    }
}

struct BezelTicks: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        for i in 0..<16 {
            let a = Double(i) * .pi / 8
            let r0 = r.width / 2 - 3, r1 = r.width / 2 - (i % 4 == 0 ? 6 : 4.6)
            p.move(to: CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
            p.addLine(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
        }
        return p
    }
}

struct NextArrow: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        var p = Path()
        p.move(to: CGPoint(x: w * 0.27, y: w * 0.44))
        p.addLine(to: CGPoint(x: w * 0.52, y: w * 0.44))
        p.addLine(to: CGPoint(x: w * 0.52, y: w * 0.32))
        p.addLine(to: CGPoint(x: w * 0.76, y: w * 0.5))
        p.addLine(to: CGPoint(x: w * 0.52, y: w * 0.68))
        p.addLine(to: CGPoint(x: w * 0.52, y: w * 0.56))
        p.addLine(to: CGPoint(x: w * 0.27, y: w * 0.56))
        p.closeSubpath()
        return p
    }
}
