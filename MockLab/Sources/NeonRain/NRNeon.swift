import SwiftUI

// Real neon: bent glass tubes with a bright core, a dark glass body at the edges, painted-out electrode ends,
// mounting clips on standoffs, a glow halo on the wall behind and film halation around it.

/// A single-stroke tube alphabet for numerals (the date and the temperature). Glyphs are polylines in a box
/// 1 unit tall (y down); `advance` is the glyph width before tracking.
enum NRTubeFont {
    struct Glyph {
        var advance: CGFloat
        var strokes: [[CGPoint]]
    }

    /// Sampled elliptical arc in degrees (0 = right, 90 = down), drawn from a0 toward a1.
    static func arc(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ a0: CGFloat, _ a1: CGFloat) -> [CGPoint] {
        let n = max(8, Int(abs(a1 - a0) / 6))
        return (0...n).map { i in
            let a = (a0 + (a1 - a0) * CGFloat(i) / CGFloat(n)) * .pi / 180
            return CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a))
        }
    }

    static func glyph(_ c: Character) -> Glyph {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        switch c {
        case "0":
            var s = arc(0.29, 0.29, 0.29, 0.29, 180, 360)
            s += arc(0.29, 0.71, 0.29, 0.29, 0, 180)
            s.append(s[0])
            return Glyph(advance: 0.58, strokes: [s])
        case "1":
            return Glyph(advance: 0.42, strokes: [[P(0.04, 0.2), P(0.3, 0.0), P(0.3, 1.0)]])
        case "2":
            var s = arc(0.29, 0.28, 0.28, 0.28, 195, 380)
            s += [P(0.0, 1.0), P(0.6, 1.0)]
            return Glyph(advance: 0.6, strokes: [s])
        case "3":
            var s = arc(0.28, 0.245, 0.235, 0.235, 205, 450)
            s += arc(0.29, 0.735, 0.27, 0.265, 270, 518)
            return Glyph(advance: 0.58, strokes: [[P(0.17, 0.48)] + s])
        case "4":
            return Glyph(advance: 0.62, strokes: [[P(0.46, 1.0), P(0.46, 0.0), P(0.0, 0.68), P(0.62, 0.68)]])
        case "5":
            var s = [P(0.55, 0.0), P(0.1, 0.0), P(0.075, 0.455)]
            s += arc(0.3, 0.69, 0.3, 0.31, 228, 518)
            return Glyph(advance: 0.6, strokes: [s])
        case "6":
            var s = arc(0.67, 0.7, 0.65, 0.66, 252, 180)
            s += arc(0.31, 0.7, 0.29, 0.3, 180, 540)
            return Glyph(advance: 0.6, strokes: [s])
        case "7":
            return Glyph(advance: 0.58, strokes: [[P(0.0, 0.0), P(0.58, 0.0), P(0.17, 1.0)]])
        case "8":
            let top = arc(0.29, 0.245, 0.23, 0.235, 90, 450)
            let bottom = arc(0.29, 0.735, 0.28, 0.265, 270, 630)
            return Glyph(advance: 0.58, strokes: [top, bottom])
        case "9":
            var s = arc(0.29, 0.3, 0.29, 0.3, 0, 360)
            s += arc(-0.07, 0.3, 0.65, 0.66, 0, 72)
            return Glyph(advance: 0.6, strokes: [s])
        case "°":
            return Glyph(advance: 0.26, strokes: [arc(0.12, 0.12, 0.11, 0.11, -90, 270)])
        case "-":
            return Glyph(advance: 0.44, strokes: [[P(0.03, 0.56), P(0.41, 0.56)]])
        default:
            return Glyph(advance: 0.4, strokes: [])
        }
    }

    /// Lays out `text` at `height` points tall. Returns tubes (in points, origin top-left of the text box)
    /// tagged with the index of the character they belong to, and the total width.
    static func layout(_ text: String, height: CGFloat, tracking: CGFloat = 0.2) -> (tubes: [(Int, [CGPoint])], width: CGFloat) {
        var x: CGFloat = 0
        var tubes: [(Int, [CGPoint])] = []
        for (i, ch) in text.enumerated() {
            let g = glyph(ch)
            for s in g.strokes {
                tubes.append((i, s.map { CGPoint(x: x + $0.x * height, y: $0.y * height) }))
            }
            x += (g.advance + tracking) * height
        }
        return (tubes, max(0, x - tracking * height))
    }
}

enum NRNeon {
    static func path(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for q in pts.dropFirst() { p.addLine(to: q) }
        return p
    }

    /// Point and unit tangent at fraction `t` of a polyline's length.
    static func sample(_ pts: [CGPoint], at t: CGFloat) -> (CGPoint, CGVector) {
        guard pts.count > 1 else { return (pts.first ?? .zero, CGVector(dx: 1, dy: 0)) }
        var lens: [CGFloat] = []
        var total: CGFloat = 0
        for i in 1..<pts.count {
            let d = hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
            lens.append(d)
            total += d
        }
        var target = total * min(max(t, 0), 1)
        for i in 1..<pts.count {
            let d = lens[i - 1]
            if target <= d || i == pts.count - 1 {
                let f = d > 0 ? target / d : 0
                let a = pts[i - 1], b = pts[i]
                let dx = b.x - a.x, dy = b.y - a.y
                let n = max(hypot(dx, dy), 0.0001)
                return (CGPoint(x: a.x + dx * f, y: a.y + dy * f), CGVector(dx: dx / n, dy: dy / n))
            }
            target -= d
        }
        return (pts.last!, CGVector(dx: 1, dy: 0))
    }

    struct Tube {
        var points: [CGPoint]
        var dim: Bool = false      // the flickering letter: a weaker core, a thinner halo
    }

    /// Draws lit tubes into a canvas: halo on the wall, halation, dark glass body, lit gas, white-hot core,
    /// painted-out electrode ends, clips. `width` is the tube diameter in points.
    static func draw(_ ctx: GraphicsContext, tubes: [Tube], color: Color, core: Color, width w: CGFloat,
                     clips: Bool = true, glow: CGFloat = 1) {
        let round = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
        func style(_ k: CGFloat) -> StrokeStyle { StrokeStyle(lineWidth: w * k, lineCap: .round, lineJoin: .round) }
        let lit = tubes.filter { !$0.dim }.reduce(into: Path()) { $0.addPath(path($1.points)) }
        let dim = tubes.filter { $0.dim }.reduce(into: Path()) { $0.addPath(path($1.points)) }

        // Wall glow and film halation (additive).
        var add = ctx
        add.blendMode = .plusLighter
        add.drawLayer { l in
            l.addFilter(.blur(radius: w * 7 * glow))
            l.stroke(lit, with: .color(color.opacity(0.55)), style: style(4))
            l.stroke(dim, with: .color(color.opacity(0.16)), style: style(4))
        }
        add.drawLayer { l in
            l.addFilter(.blur(radius: w * 2.4 * glow))
            l.stroke(lit, with: .color(color.opacity(0.75)), style: style(2.2))
            l.stroke(dim, with: .color(color.opacity(0.25)), style: style(2.2))
        }
        add.drawLayer { l in
            l.addFilter(.blur(radius: w * 12 * glow))
            l.stroke(lit, with: .color(NR.halation.opacity(0.22)), style: style(5))
        }

        // Clip standoffs sit behind the glass: shadows on the wall.
        if clips {
            for t in tubes where t.points.count > 1 {
                for f in clipStops(t.points) {
                    let (p, _) = sample(t.points, at: f)
                    let r = CGRect(x: p.x - w * 0.55 + w * 0.6, y: p.y - w * 0.55 + w * 1.1, width: w * 1.1, height: w * 1.1)
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: w * 0.5))
                        l.fill(Path(ellipseIn: r), with: .color(.black.opacity(0.55)))
                    }
                }
            }
        }

        // Dark glass body at the edges of the tube, then the lit gas and its core.
        ctx.stroke(lit, with: .color(Color(hex: 0x0A0E10).opacity(0.55)), style: style(1.28))
        ctx.stroke(dim, with: .color(Color(hex: 0x0A0E10).opacity(0.75)), style: style(1.28))
        ctx.stroke(lit, with: .color(color), style: round)
        ctx.stroke(dim, with: .color(color.opacity(0.42)), style: round)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: w * 0.14))
            l.stroke(lit, with: .color(core), style: style(0.56))
            l.stroke(dim, with: .color(core.opacity(0.28)), style: style(0.34))
        }
        // A glint along the top of the glass.
        ctx.stroke(lit.offsetBy(dx: -w * 0.16, dy: -w * 0.2), with: .color(.white.opacity(0.35)), style: style(0.14))

        // Electrode ends: painted black where the tube dives through the backing.
        for t in tubes where t.points.count > 1 && t.points.first != t.points.last {
            for (p, v) in [sample(t.points, at: 0), sample(t.points, at: 1)] {
                let isStart = p == t.points.first
                let dir: CGFloat = isStart ? 1 : -1
                var cap = Path()
                cap.move(to: p)
                cap.addLine(to: CGPoint(x: p.x + v.dx * w * 0.5 * dir, y: p.y + v.dy * w * 0.5 * dir))
                ctx.stroke(cap, with: .color(Color(hex: 0x23292C)), style: style(1.08))
                ctx.stroke(cap.offsetBy(dx: -w * 0.15, dy: -w * 0.15), with: .color(.white.opacity(0.3)), style: style(0.18))
            }
        }

        // Clips: little metal saddles across the tube.
        if clips {
            for t in tubes where t.points.count > 1 {
                for f in clipStops(t.points) {
                    let (p, v) = sample(t.points, at: f)
                    let n = CGVector(dx: -v.dy, dy: v.dx)
                    var bar = Path()
                    bar.move(to: CGPoint(x: p.x - n.dx * w * 0.78, y: p.y - n.dy * w * 0.78))
                    bar.addLine(to: CGPoint(x: p.x + n.dx * w * 0.78, y: p.y + n.dy * w * 0.78))
                    ctx.stroke(bar, with: .color(Color(hex: 0x2A3236)), style: StrokeStyle(lineWidth: w * 0.42, lineCap: .round))
                    ctx.stroke(bar.offsetBy(dx: -w * 0.08, dy: -w * 0.08), with: .color(.white.opacity(0.4)),
                               style: StrokeStyle(lineWidth: w * 0.12, lineCap: .round))
                }
            }
        }
    }

    /// Where clips go along a tube: one on a short stroke, two on a long one.
    static func clipStops(_ pts: [CGPoint]) -> [CGFloat] {
        var len: CGFloat = 0
        for i in 1..<pts.count { len += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y) }
        return len > 70 ? [0.22, 0.7] : [0.45]
    }
}

/// A neon numeral sign drawn with the tube alphabet. Its layout size is the text box; glow spills past it.
struct NRNeonNumerals: View {
    var text: String
    var height: CGFloat
    var color: Color
    var core: Color
    var tube: CGFloat? = nil
    var dimIndex: Int? = nil        // which character flickers
    var tracking: CGFloat = 0.2
    var clips: Bool = true

    var body: some View {
        let lay = NRTubeFont.layout(text, height: height, tracking: tracking)
        let w = tube ?? max(1.75, height * 0.075)
        let pad = w * 14
        Canvas { ctx, _ in
            let tubes = lay.tubes.map { NRNeon.Tube(points: $0.1.map { CGPoint(x: $0.x + pad, y: $0.y + pad) }, dim: $0.0 == dimIndex) }
            NRNeon.draw(ctx, tubes: tubes, color: color, core: core, width: w, clips: clips)
        }
        .frame(width: lay.width + pad * 2, height: height + pad * 2)
        .padding(-pad)
        .frame(width: lay.width, height: height)
        .allowsHitTesting(false)
    }

    static func width(_ text: String, height: CGFloat, tracking: CGFloat = 0.2) -> CGFloat {
        NRTubeFont.layout(text, height: height, tracking: tracking).width
    }
}

/// A vertical hanging lightbox with the weekday in Chinese neon: dark enamel box, bracket arm,
/// one character flickering dim. Exact mapping lives in `NRDates.hanziWeekday`.
struct NRHanziSign: View {
    var date: Date
    var size: CGFloat               // character size
    var color: Color = NR.magenta
    var core: Color = NR.magentaCore
    var flicker: Int = 1

    var body: some View {
        let chars = NRDates.hanziWeekday(date)
        let w = size * 1.5
        let h = size * CGFloat(chars.count) * 1.12 + size * 0.7
        ZStack {
            // Box: enamel with a bevel, a cast shadow and the glow pooling inside.
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x1A0E16), Color(hex: 0x0B0709)], startPoint: .leading, endPoint: .trailing))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                        .fill(RadialGradient(colors: [color.opacity(0.32), .clear], center: .center, startRadius: 0, endRadius: h * 0.6))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), color.opacity(0.35), .black.opacity(0.6)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.9)
                }
                .shadow(color: .black.opacity(0.7), radius: 3, x: 1.5, y: 2.5)
            VStack(spacing: size * 0.12) {
                ForEach(Array(chars.enumerated()), id: \.offset) { i, ch in
                    neonChar(ch, dim: i == flicker)
                }
            }
        }
        .frame(width: w, height: h)
        .background(alignment: .top) {
            // Bracket rods up to the building.
            Rectangle().fill(LinearGradient(colors: [Color(hex: 0x2A3032), Color(hex: 0x0C0F10)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 1.2, height: size * 0.9)
                .offset(y: -size * 0.85)
        }
    }

    private func neonChar(_ ch: String, dim: Bool) -> some View {
        let t = Text(ch).font(.custom("PingFangHK-Light", size: size))
        return ZStack {
            t.foregroundStyle(color.opacity(dim ? 0.25 : 0.9)).blur(radius: size * 0.22).blendMode(.plusLighter)
            t.foregroundStyle(color.opacity(dim ? 0.12 : 0.6)).blur(radius: size * 0.6).blendMode(.plusLighter)
            t.foregroundStyle(Color(hex: 0x0A0E10).opacity(0.9)).offset(x: 0.5, y: 0.6)
            t.foregroundStyle(dim ? color.opacity(0.55) : color)
            t.foregroundStyle(dim ? core.opacity(0.25) : core).blur(radius: 0.25).scaleEffect(0.985)
        }
        .frame(width: size * 1.1, height: size * 1.0)
    }
}

/// The next-quote button: a cyan neon arrow on a round smoked-glass plaque with a bevel and a cast shadow.
struct NRNeonArrow: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x10292B), Color(hex: 0x050B0C)], center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 0, endRadius: size * 0.6))
                .overlay { Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.5), NR.cyan.opacity(0.3), .black.opacity(0.7)],
                                                                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1) }
                .shadow(color: .black.opacity(0.8), radius: 3, x: 1, y: 2.5)
                .shadow(color: NR.cyan.opacity(0.35), radius: 8)
            Canvas { ctx, s in
                let c = CGPoint(x: s.width / 2, y: s.height / 2)
                let a = size * 0.22
                let shaft = [CGPoint(x: c.x - a, y: c.y), CGPoint(x: c.x + a * 0.95, y: c.y)]
                let head = [CGPoint(x: c.x + a * 0.2, y: c.y - a * 0.72), CGPoint(x: c.x + a, y: c.y), CGPoint(x: c.x + a * 0.2, y: c.y + a * 0.72)]
                NRNeon.draw(ctx, tubes: [.init(points: shaft), .init(points: head)], color: NR.cyan, core: NR.cyanCore,
                            width: max(1.3, size * 0.06), clips: false, glow: 0.5)
            }
            .frame(width: size, height: size)
            // Specular on the glass dome.
            Ellipse().fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.62, height: size * 0.3)
                .offset(y: -size * 0.24)
        }
        .frame(width: size, height: size)
    }
}
