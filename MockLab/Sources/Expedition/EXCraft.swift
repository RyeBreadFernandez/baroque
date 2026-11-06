import SwiftUI

// The miniature-maker's bench: geometry helpers and the drawing primitives every set piece is built from.
// Felt pieces (cast shadow, felt nap, puffy padded edge, fuzzy cut edge), running stitches, and the
// film finish (warm key light, Kodachrome grade, grain, vignette).

extension CGPoint {
    func exPlus(_ b: CGPoint) -> CGPoint { CGPoint(x: x + b.x, y: y + b.y) }
    func exMinus(_ b: CGPoint) -> CGPoint { CGPoint(x: x - b.x, y: y - b.y) }
    func exScaled(_ k: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
    /// The point a fraction `t` of the way to `b`.
    func exLerp(_ b: CGPoint, _ t: CGFloat) -> CGPoint { CGPoint(x: x + (b.x - x) * t, y: y + (b.y - y) * t) }
    var exLength: CGFloat { sqrt(x * x + y * y) }
    var exNormalized: CGPoint { let l = exLength; return l > 0 ? CGPoint(x: x / l, y: y / l) : .zero }
}

enum EXGeo {
    /// A closed polygon with every corner rounded (felt is cut with scissors, never a perfect point).
    static func roundedPolygon(_ pts: [CGPoint], radius: CGFloat) -> Path {
        var p = Path()
        let n = pts.count
        guard n > 2 else { return p }
        for i in 0..<n {
            let prev = pts[(i - 1 + n) % n], cur = pts[i], next = pts[(i + 1) % n]
            let a = toward(cur, prev, radius), b = toward(cur, next, radius)
            if i == 0 { p.move(to: a) } else { p.addLine(to: a) }
            p.addQuadCurve(to: b, control: cur)
        }
        p.closeSubpath()
        return p
    }

    /// An open polyline with rounded interior corners.
    static func roundedPolyline(_ pts: [CGPoint], radius: CGFloat) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        if pts.count > 2 {
            for i in 1..<(pts.count - 1) {
                let a = toward(pts[i], pts[i - 1], radius), b = toward(pts[i], pts[i + 1], radius)
                p.addLine(to: a)
                p.addQuadCurve(to: b, control: pts[i])
            }
        }
        if let last = pts.last, pts.count > 1 { p.addLine(to: last) }
        return p
    }

    static func toward(_ a: CGPoint, _ b: CGPoint, _ r: CGFloat) -> CGPoint {
        let d = b.exMinus(a)
        let l = d.exLength
        guard l > 0 else { return a }
        return a.exPlus(d.exScaled(min(r, l / 2) / l))
    }

    /// Points every `step` along a polyline (or closed polygon).
    static func samples(_ pts: [CGPoint], closed: Bool, step: CGFloat) -> [CGPoint] {
        guard pts.count > 1 else { return pts }
        var out: [CGPoint] = []
        let segs = closed ? pts.count : pts.count - 1
        for i in 0..<segs {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            let n = max(1, Int(b.exMinus(a).exLength / step))
            for k in 0..<n { out.append(a.exLerp(b, CGFloat(k) / CGFloat(n))) }
        }
        if !closed, let last = pts.last { out.append(last) }
        return out
    }

    /// Offset an open polyline along its left-hand normal (downward for a left-to-right top edge).
    static func offset(_ pts: [CGPoint], by d: CGFloat) -> [CGPoint] {
        guard pts.count > 1 else { return pts }
        func normal(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            let t = b.exMinus(a).exNormalized
            return CGPoint(x: -t.y, y: t.x)
        }
        var out: [CGPoint] = []
        for i in 0..<pts.count {
            let nPrev = i > 0 ? normal(pts[i - 1], pts[i]) : normal(pts[i], pts[i + 1])
            let nNext = i < pts.count - 1 ? normal(pts[i], pts[i + 1]) : nPrev
            let n = nPrev.exPlus(nNext).exNormalized
            let cosHalf = max(0.45, n.x * nNext.x + n.y * nNext.y)
            out.append(pts[i].exPlus(n.exScaled(d / cosHalf)))
        }
        return out
    }

    /// Scale a closed outline toward its centroid by an absolute inset (good enough for round-ish shapes).
    static func inset(_ pts: [CGPoint], by d: CGFloat) -> [CGPoint] {
        guard !pts.isEmpty else { return pts }
        let sum = pts.reduce(CGPoint.zero) { $0.exPlus($1) }
        let c = sum.exScaled(1 / CGFloat(pts.count))
        return pts.map { p in
            let v = p.exMinus(c)
            let l = v.exLength
            return l > d ? c.exPlus(v.exScaled((l - d) / l)) : c
        }
    }

    /// Points around a rounded rectangle (clockwise from the top-left) with their outward normals.
    static func roundedRectRing(_ r: CGRect, radius: CGFloat, step: CGFloat) -> [(CGPoint, CGPoint)] {
        var out: [(CGPoint, CGPoint)] = []
        let rad = min(radius, min(r.width, r.height) / 2)
        func line(_ a: CGPoint, _ b: CGPoint, _ n: CGPoint) {
            let k = max(1, Int(b.exMinus(a).exLength / step))
            for i in 0..<k { out.append((a.exLerp(b, CGFloat(i) / CGFloat(k)), n)) }
        }
        func arc(_ c: CGPoint, from a0: CGFloat) {
            let k = max(2, Int(rad * .pi / 2 / step))
            for i in 0..<k {
                let a = a0 + CGFloat(i) / CGFloat(k) * .pi / 2
                let n = CGPoint(x: cos(a), y: sin(a))
                out.append((c.exPlus(n.exScaled(rad)), n))
            }
        }
        line(CGPoint(x: r.minX + rad, y: r.minY), CGPoint(x: r.maxX - rad, y: r.minY), CGPoint(x: 0, y: -1))
        arc(CGPoint(x: r.maxX - rad, y: r.minY + rad), from: -.pi / 2)
        line(CGPoint(x: r.maxX, y: r.minY + rad), CGPoint(x: r.maxX, y: r.maxY - rad), CGPoint(x: 1, y: 0))
        arc(CGPoint(x: r.maxX - rad, y: r.maxY - rad), from: 0)
        line(CGPoint(x: r.maxX - rad, y: r.maxY), CGPoint(x: r.minX + rad, y: r.maxY), CGPoint(x: 0, y: 1))
        arc(CGPoint(x: r.minX + rad, y: r.maxY - rad), from: .pi / 2)
        line(CGPoint(x: r.minX, y: r.maxY - rad), CGPoint(x: r.minX, y: r.minY + rad), CGPoint(x: -1, y: 0))
        arc(CGPoint(x: r.minX + rad, y: r.minY + rad), from: .pi)
        return out
    }

    static func circlePoints(_ c: CGPoint, _ r: CGFloat, step: CGFloat = 1.2) -> [CGPoint] {
        let n = max(12, Int(2 * .pi * r / step))
        return (0..<n).map { i in
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        }
    }
}

/// Resolved textures for one Canvas.
struct EXKit {
    let felt: GraphicsContext.ResolvedImage
    let sky: GraphicsContext.ResolvedImage
    let card: GraphicsContext.ResolvedImage
    let walnut: GraphicsContext.ResolvedImage

    init(_ ctx: GraphicsContext) {
        felt = ctx.resolve(EX.tex("felt"))
        sky = ctx.resolve(EX.tex("sky"))
        card = ctx.resolve(EX.tex("card"))
        walnut = ctx.resolve(EX.tex("walnut"))
    }
}

/// How a felt piece is cut and mounted.
struct EXFeltStyle {
    var color: Color
    var lift: CGFloat = 2.0       // distance of the cast shadow (how far the piece stands off the one behind)
    var fuzz: CGFloat = 1.1       // length of the stray fibres at the cut edge
    var nap: Double = 0.7         // strength of the felt texture
    var puff: Double = 1.0        // padded-edge shading
    var fibres: CGFloat = 1.0     // density of crisp surface fibres
    var hairDensity: CGFloat = 1.0
}

enum EXCraft {
    /// One felt piece: cast shadow, colour, nap, light across it, padded edge, crisp fibres, fuzzy cut edge.
    /// `edge` is the outline that gets stray fibres (often only the visible top edge).
    static func felt(_ ctx: GraphicsContext, _ path: Path, edge: [CGPoint], closed: Bool,
                     style s: EXFeltStyle, kit: EXKit, seed: UInt64) {
        let b = path.boundingRect
        if s.lift > 0 {
            var cast = ctx
            cast.addFilter(.blur(radius: s.lift * 1.15))
            cast.fill(path.offsetBy(dx: s.lift * 0.55, dy: s.lift * 0.95), with: .color(EX.shadow.opacity(0.42)))
            var contact = ctx
            contact.addFilter(.blur(radius: 0.55))
            contact.fill(path.offsetBy(dx: 0.3, dy: 0.55), with: .color(EX.shadow.opacity(0.32)))
        }
        ctx.fill(path, with: .color(s.color))
        var inside = ctx
        inside.clip(to: path)
        var rng = SeededRandom(seed: seed)
        let ox = rng.range(0...max(0, 360 - b.width)), oy = rng.range(0...max(0, 380 - b.height))
        var nap = inside
        nap.opacity = s.nap
        nap.draw(kit.felt, in: CGRect(x: b.minX - ox, y: b.minY - oy, width: 360, height: 380))
        // Key light from the upper left across the piece.
        inside.fill(Path(b), with: .linearGradient(
            Gradient(stops: [.init(color: .white.opacity(0.14), location: 0),
                             .init(color: .white.opacity(0), location: 0.45),
                             .init(color: .black.opacity(0.14), location: 1)]),
            startPoint: CGPoint(x: b.minX, y: b.minY), endPoint: CGPoint(x: b.maxX, y: b.maxY)))
        if s.puff > 0 {
            var hi = inside
            hi.addFilter(.blur(radius: 1.3))
            hi.stroke(path.offsetBy(dx: 1.1, dy: 1.5), with: .color(.white.opacity(0.26 * s.puff)), lineWidth: 1.8)
            var lo = inside
            lo.addFilter(.blur(radius: 1.8))
            lo.stroke(path.offsetBy(dx: -1.3, dy: -1.7), with: .color(EX.shadow.opacity(0.34 * s.puff)), lineWidth: 2.6)
        }
        if s.fibres > 0 { fibres(inside, in: b, density: s.fibres, seed: seed &+ 3) }
        if s.fuzz > 0 { fuzz(ctx, along: edge, closed: closed, color: s.color, length: s.fuzz, density: s.hairDensity, seed: seed &+ 5) }
    }

    /// Crisp stray fibres lying on a felt surface (the raster nap softens at 3x; these keep it tactile).
    static func fibres(_ ctx: GraphicsContext, in b: CGRect, density: CGFloat, seed: UInt64) {
        var r = SeededRandom(seed: seed)
        let count = Int(b.width * b.height / 48 * density)
        guard count > 0 else { return }
        var light = Path(), dark = Path()
        for i in 0..<min(count, 3000) {
            let p = CGPoint(x: r.range(b.minX...b.maxX), y: r.range(b.minY...b.maxY))
            let a = r.range(0...(2 * .pi))
            let len = r.range(1.2...3.6)
            let end = CGPoint(x: p.x + cos(a) * len, y: p.y + sin(a) * len)
            let c = CGPoint(x: (p.x + end.x) / 2 + r.range(-0.8...0.8), y: (p.y + end.y) / 2 + r.range(-0.8...0.8))
            if i % 3 == 0 { dark.move(to: p); dark.addQuadCurve(to: end, control: c) } else { light.move(to: p); light.addQuadCurve(to: end, control: c) }
        }
        ctx.stroke(light, with: .color(.white.opacity(0.19)), lineWidth: 0.3)
        ctx.stroke(dark, with: .color(EX.shadow.opacity(0.18)), lineWidth: 0.3)
    }

    /// Stray fibres along a cut edge: most in the piece's own colour (a soft, fuzzy silhouette), some catching light.
    static func fuzz(_ ctx: GraphicsContext, along pts: [CGPoint], closed: Bool, color: Color, length: CGFloat,
                     density: CGFloat = 1, seed: UInt64) {
        var r = SeededRandom(seed: seed)
        let samples = EXGeo.samples(pts, closed: closed, step: 0.55 / max(0.2, density))
        var base = Path(), light = Path(), dark = Path()
        for s in samples {
            let a = r.range(0...(2 * .pi))
            let len = length * r.range(0.35...1.2)
            let start = CGPoint(x: s.x + r.range(-0.35...0.35), y: s.y + r.range(-0.35...0.35))
            let end = CGPoint(x: start.x + cos(a) * len, y: start.y + sin(a) * len)
            let bend = r.range(-0.5...0.5) * len
            let mid = CGPoint(x: (start.x + end.x) / 2 - sin(a) * bend, y: (start.y + end.y) / 2 + cos(a) * bend)
            let k = r.unit()
            if k < 0.64 { base.move(to: start); base.addQuadCurve(to: end, control: mid) }
            else if k < 0.86 { light.move(to: start); light.addQuadCurve(to: end, control: mid) }
            else { dark.move(to: start); dark.addQuadCurve(to: end, control: mid) }
        }
        ctx.stroke(base, with: .color(color), lineWidth: 0.42)
        ctx.stroke(light, with: .color(.white.opacity(0.42)), lineWidth: 0.32)
        ctx.stroke(dark, with: .color(EX.shadow.opacity(0.32)), lineWidth: 0.32)
    }

    /// A running stitch of thread along a path: shadow, thread, and a glint on each stitch.
    static func stitches(_ ctx: GraphicsContext, _ path: Path, color: Color, width: CGFloat = 0.95,
                         dash: [CGFloat] = [2.6, 1.9], phase: CGFloat = 0) {
        let style = StrokeStyle(lineWidth: width, lineCap: .round, dash: dash, dashPhase: phase)
        var sh = ctx
        sh.addFilter(.blur(radius: 0.35))
        sh.stroke(path.offsetBy(dx: 0.35, dy: 0.6), with: .color(EX.shadow.opacity(0.45)),
                  style: StrokeStyle(lineWidth: width + 0.25, lineCap: .round, dash: dash, dashPhase: phase))
        ctx.stroke(path, with: .color(color), style: style)
        ctx.stroke(path.offsetBy(dx: -0.18, dy: -0.25), with: .color(.white.opacity(0.35)),
                   style: StrokeStyle(lineWidth: width * 0.4, lineCap: .round, dash: dash, dashPhase: phase))
    }

    /// A soft ellipse of shadow where something stands on a surface.
    static func contact(_ ctx: GraphicsContext, _ r: CGRect, opacity: Double = 0.4, blur: CGFloat = 1.6) {
        var c = ctx
        c.addFilter(.blur(radius: blur))
        c.fill(Path(ellipseIn: r), with: .color(EX.shadow.opacity(opacity)))
    }
}

/// The film finish laid over every widget: warm key light from the upper left, a faded Kodachrome grade,
/// grain, and a slight vignette. One Canvas plus two gradient layers.
struct EXFinish: View {
    var gloom: Double = 0

    var body: some View {
        ZStack {
            // Warm key light pooling from the upper left.
            RadialGradient(colors: [Color(hex: 0xFFE2A6).opacity(0.30), Color(hex: 0xFFE2A6).opacity(0)],
                           center: UnitPoint(x: 0.12, y: 0.0), startRadius: 0, endRadius: 300)
                .blendMode(.softLight)
            // Kodachrome: warm the mids and lift the blacks a touch toward brown.
            Color(hex: 0xF4D7A4).opacity(0.13 + gloom * 0.05).blendMode(.multiply)
            Color(hex: 0x3A1E0A).opacity(0.05).blendMode(.lighten)
            // Grain.
            EX.tex("grain").resizable(resizingMode: .tile).opacity(0.5)
            // Vignette.
            GeometryReader { g in
                let d = max(g.size.width, g.size.height)
                RadialGradient(colors: [.clear, .clear, EX.shadow.opacity(0.36)],
                               center: .center, startRadius: d * 0.22, endRadius: d * 0.78)
                    .blendMode(.multiply)
            }
        }
        .allowsHitTesting(false)
    }
}
