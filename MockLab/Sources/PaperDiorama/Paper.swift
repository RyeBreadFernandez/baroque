import SwiftUI

// Paper Diorama: the material kit. Cardstock colours, type, hand-cut shapes, the paper sheet itself
// (colour + fiber + light falloff + lit cut edge) and the lift that casts each layer's shadow on the one behind.

enum PD {
    // Ink (text) — deep enough to read on every pastel stock.
    static let ink = Color(hex: 0x2B3150)
    static let inkSoft = Color(hex: 0x4E5878)

    // Cardstock
    static let coral = Color(hex: 0xEA7260)
    static let coralDeep = Color(hex: 0xB94434)
    static let peach = Color(hex: 0xF8C4A4)
    static let tangerine = Color(hex: 0xF5A066)
    static let butter = Color(hex: 0xFFD872)
    static let butterLight = Color(hex: 0xFFE9A8)
    static let mint = Color(hex: 0xA9DFBF)
    static let meadow = Color(hex: 0x9BD5A6)
    static let sage = Color(hex: 0x7DB497)
    static let pine = Color(hex: 0x4E8B71)
    static let skyTop = Color(hex: 0x8FCBE8)
    static let skyLow = Color(hex: 0xD8EFF0)
    static let skyStock = Color(hex: 0xA9D7EC)
    static let periwinkle = Color(hex: 0xBAC6EB)
    static let periShade = Color(hex: 0xA2B1DE)
    static let teal = Color(hex: 0x9DC8BB)
    static let tealShade = Color(hex: 0x86B5A7)
    static let cream = Color(hex: 0xFFF8EA)
    static let creamFold = Color(hex: 0xEADCC2)
    static let snow = Color(hex: 0xFFFDF8)
    static let lavender = Color(hex: 0xC3B9E6)
    static let twine = Color(hex: 0x9A7C62)
    static let kraft = Color(hex: 0xC99A6B)

    /// Shadow colour: a cool blue-slate, the way daylight shadows fall in a white box.
    static let shadow = Color(hex: 0x1D3045)

    /// What a punched hole reveals: the forest layers behind the card.
    static let holeTop = Color(hex: 0x2C5149)
    static let holeLow = Color(hex: 0x5C8C79)

    /// Hole-reinforcement ring colour per priority (none = bare hole).
    static func ring(_ p: TaskPriority) -> Color? {
        switch p {
        case .highest: return coral
        case .high: return tangerine
        case .medium: return butter
        case .none: return Color(hex: 0xFFFFFF)
        case .low: return skyStock
        case .lowest: return lavender
        }
    }
}

extension Font {
    static func pdRounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func pdAvenir(_ size: CGFloat, _ face: String = "DemiBold") -> Font {
        .custom("AvenirNext-" + face, fixedSize: size)
    }
    static func pdChalk(_ size: CGFloat, _ face: String = "Bold") -> Font {
        .custom("ChalkboardSE-" + face, fixedSize: size)
    }
}

// MARK: - Fiber

enum PaperTex {
    static let a = Mock.texture("paper-diorama/fiber")
    static let b = Mock.texture("paper-diorama/fiber-b")
    static let tooth = Mock.texture("paper-diorama/tooth")
}

/// White-based cardstock tooth, for a multiply blend on cream and white stock.
struct Tooth: View {
    var seed: UInt64
    var body: some View {
        GeometryReader { g in
            PaperTex.tooth
                .resizable(resizingMode: .tile)
                .frame(width: g.size.width + 256, height: g.size.height + 256)
                .offset(x: -CGFloat((seed &* 53) % 199), y: -CGFloat((seed &* 29) % 181))
        }
        .clipped()
    }
}

/// The tiled fiber tile (256 px at 1 px per point), offset per sheet so neighbouring layers never share a pattern.
struct Fiber: View {
    var seed: UInt64
    var body: some View {
        GeometryReader { g in
            let ox = CGFloat((seed &* 37) % 211)
            let oy = CGFloat((seed &* 91) % 197)
            (seed % 2 == 0 ? PaperTex.a : PaperTex.b)
                .resizable(resizingMode: .tile)
                .frame(width: g.size.width + 256, height: g.size.height + 256)
                .offset(x: -ox, y: -oy)
        }
        .clipped()
    }
}

// MARK: - Sheet material

/// One sheet of cardstock cut to `shape`: stock colour, light falling off away from the cut edge,
/// fiber (overlay blend), and the thin bright core that shows where scissors cut the top edges.
struct Sheet<S: Shape>: View {
    var shape: S
    var color: Color
    var seed: UInt64 = 1
    var grain: Double = 0.9
    var lightTop: CGFloat = 0
    var lightBottom: CGFloat = 1
    var edge: CGFloat = 1.2
    var tooth: Double = 0      // multiply-blended tooth for pale stock
    var curl: Double = 0       // edges shaded as if the sheet bows slightly

    var body: some View {
        ZStack {
            shape.fill(color)
            shape.fill(falloff)
            Fiber(seed: seed).opacity(grain).mask(shape).blendMode(.overlay)
            if tooth > 0 {
                Tooth(seed: seed).opacity(tooth).mask(shape).blendMode(.multiply)
            }
            if curl > 0 {
                shape.stroke(PD.shadow.opacity(curl), lineWidth: 12).blur(radius: 7).mask(shape)
            }
            shape.stroke(Color.white.opacity(0.62), lineWidth: edge)
                .offset(y: edge * 0.55)
                .mask(shape)
        }
    }

    private var falloff: LinearGradient {
        LinearGradient(stops: [
            .init(color: .white.opacity(0.20), location: 0),
            .init(color: .white.opacity(0.0), location: 0.38),
            .init(color: PD.shadow.opacity(0.12), location: 1)
        ], startPoint: UnitPoint(x: 0.5, y: lightTop), endPoint: UnitPoint(x: 0.5, y: lightBottom))
    }
}

extension View {
    /// Raise a sheet `h` points off the one behind it: a soft ambient shadow plus a tight contact shadow,
    /// both falling down and a little left (the light comes from the upper right).
    func lifted(_ h: CGFloat, opacity: Double = 1) -> some View {
        compositingGroup()
            .shadow(color: PD.shadow.opacity(0.22 * opacity), radius: h * 1.5, x: -h * 0.35, y: h * 0.95)
            .shadow(color: PD.shadow.opacity(0.30 * opacity), radius: max(0.5, h * 0.32), x: -h * 0.1, y: max(0.4, h * 0.3))
    }

    /// Text sitting on a printed stock: a faint paper-coloured halo keeps it crisp over busy cut edges.
    func onPaper(_ halo: Color = PD.cream, _ strength: Double = 0.85) -> some View {
        shadow(color: halo.opacity(strength), radius: 1.2)
            .shadow(color: halo.opacity(strength * 0.6), radius: 3)
    }
}

// MARK: - Hand-cut geometry

enum Cutter {
    /// Densify a polyline and nudge the new points sideways with a damped random walk: a scissor cut.
    /// The given vertices stay put, so peaks and corners stay crisp.
    static func handCut(_ pts: [CGPoint], closed: Bool, seed: UInt64, wobble: CGFloat, step: CGFloat = 4.5) -> [CGPoint] {
        guard pts.count > 1 else { return pts }
        var rng = SeededRandom(seed: seed)
        var out: [CGPoint] = []
        var drift: CGFloat = 0
        let n = closed ? pts.count : pts.count - 1
        for i in 0..<n {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(0.001, hypot(dx, dy))
            let nx = -dy / len, ny = dx / len
            let k = max(1, Int(len / step))
            out.append(a)
            drift = 0
            if k > 1 {
                for j in 1..<k {
                    let t = CGFloat(j) / CGFloat(k)
                    drift = drift * 0.72 + rng.range(-1...1) * 0.55
                    let taper = min(1, min(t, 1 - t) * 6)   // ease into the vertices
                    let off = drift * wobble * taper
                    out.append(CGPoint(x: a.x + dx * t + nx * off, y: a.y + dy * t + ny * off))
                }
            }
        }
        if !closed, let last = pts.last { out.append(last) }
        return out
    }

    /// Catmull-Rom spline through the points, sampled about every `step` points.
    static func spline(_ p: [CGPoint], step: CGFloat = 4) -> [CGPoint] {
        guard p.count > 2 else { return p }
        var out: [CGPoint] = []
        for i in 0..<(p.count - 1) {
            let p0 = p[max(i - 1, 0)], p1 = p[i], p2 = p[i + 1], p3 = p[min(i + 2, p.count - 1)]
            let samples = max(2, Int(hypot(p2.x - p1.x, p2.y - p1.y) / step))
            for s in 0..<samples {
                let t = CGFloat(s) / CGFloat(samples)
                out.append(catmull(p0, p1, p2, p3, t))
            }
        }
        out.append(p[p.count - 1])
        return out
    }

    private static func catmull(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        let t2 = t * t, t3 = t2 * t
        func c(_ a: CGFloat, _ b: CGFloat, _ cc: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * ((2 * b) + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3)
        }
        return CGPoint(x: c(p0.x, p1.x, p2.x, p3.x), y: c(p0.y, p1.y, p2.y, p3.y))
    }

    /// Wobble every interior point of a dense curve (for spline-cut hills).
    static func jitter(_ pts: [CGPoint], seed: UInt64, wobble: CGFloat) -> [CGPoint] {
        guard pts.count > 2 else { return pts }
        var rng = SeededRandom(seed: seed)
        var out = pts
        var drift: CGFloat = 0
        for i in 1..<(pts.count - 1) {
            let a = pts[i - 1], b = pts[i + 1]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(0.001, hypot(dx, dy))
            drift = drift * 0.75 + rng.range(-1...1) * 0.5
            out[i] = CGPoint(x: pts[i].x - dy / len * drift * wobble, y: pts[i].y + dx / len * drift * wobble)
        }
        return out
    }

    static func scaled(_ unit: [CGPoint], in r: CGRect) -> [CGPoint] {
        unit.map { CGPoint(x: r.minX + $0.x * r.width, y: r.minY + $0.y * r.height) }
    }
}

/// A closed polygon (unit coordinates of its frame) cut by hand.
struct CutPolygon: Shape {
    var points: [CGPoint]
    var seed: UInt64 = 1
    var wobble: CGFloat = 0.5
    var step: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        let pts = Cutter.handCut(Cutter.scaled(points, in: rect), closed: true, seed: seed, wobble: wobble, step: step)
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }
}

/// A landscape layer: its top contour runs through `top` (unit coordinates of the whole widget,
/// spanning a little past both sides) and it is closed well below the bottom edge.
struct RidgeCut: Shape {
    var top: [CGPoint]
    var smooth = false
    var seed: UInt64 = 1
    var wobble: CGFloat = 0.65

    func path(in r: CGRect) -> Path {
        let pts = Cutter.scaled(top, in: r)
        let contour = smooth
            ? Cutter.jitter(Cutter.spline(pts, step: 4), seed: seed, wobble: wobble)
            : Cutter.handCut(pts, closed: false, seed: seed, wobble: wobble)
        guard let first = contour.first, let last = contour.last else { return Path() }
        var p = Path()
        p.move(to: CGPoint(x: first.x, y: r.maxY + 40))
        for q in contour { p.addLine(to: q) }
        p.addLine(to: CGPoint(x: last.x, y: r.maxY + 40))
        p.closeSubpath()
        return p
    }
}

/// White paper snowcaps glued over the given peaks, with a zig-zag lower edge. Mask with the ridge.
struct SnowcapCut: Shape {
    var top: [CGPoint]
    var peaks: [Int]
    var depth: CGFloat
    var seed: UInt64

    func path(in r: CGRect) -> Path {
        let pts = Cutter.scaled(top, in: r)
        var rng = SeededRandom(seed: seed)
        var path = Path()
        for i in peaks where i > 0 && i < pts.count - 1 {
            let p = pts[i]
            func along(_ q: CGPoint) -> CGPoint {
                let t = min(0.7, depth / max(1, q.y - p.y))
                return CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t)
            }
            let a = along(pts[i - 1]), b = along(pts[i + 1])
            var poly = [CGPoint(x: p.x, y: p.y - 6), CGPoint(x: b.x + 4, y: b.y - 2)]
            let teeth = 3
            for k in 1..<(teeth * 2) {
                let t = CGFloat(k) / CGFloat(teeth * 2)
                let x = b.x + (a.x - b.x) * t
                let y = b.y + (a.y - b.y) * t
                let dip = k % 2 == 1 ? depth * rng.range(0.30...0.50) : -depth * rng.range(0.05...0.2)
                poly.append(CGPoint(x: x, y: y + dip))
            }
            poly.append(CGPoint(x: a.x - 4, y: a.y - 2))
            path.addLines(Cutter.handCut(poly, closed: true, seed: seed &+ UInt64(i), wobble: 0.3, step: 3))
            path.closeSubpath()
        }
        return path
    }
}

/// The darker left face of each peak (the light comes from the right). Mask with the ridge.
struct ShadeCut: Shape {
    var top: [CGPoint]
    var peaks: [Int]
    var seed: UInt64

    func path(in r: CGRect) -> Path {
        let pts = Cutter.scaled(top, in: r)
        var path = Path()
        for i in peaks where i > 0 && i < pts.count - 1 {
            let p = pts[i], l = pts[i - 1]
            let h = max(8, l.y - p.y)
            let poly = [
                CGPoint(x: p.x, y: p.y - 3),
                CGPoint(x: p.x + 1.5, y: p.y + h * 0.35),
                CGPoint(x: p.x - 2.5, y: p.y + h * 0.7),
                CGPoint(x: p.x + 2, y: p.y + h * 1.15),
                CGPoint(x: p.x - 3, y: r.maxY + 20),
                CGPoint(x: l.x - 2, y: r.maxY + 20),
                CGPoint(x: l.x - 2, y: l.y - 3)
            ]
            path.addLines(Cutter.handCut(poly, closed: true, seed: seed &+ UInt64(i), wobble: 0.5, step: 4))
            path.closeSubpath()
        }
        return path
    }
}

/// An index card: square corners nicked round, edges cut by hand, the lower-right corner folded over.
struct CardCut: Shape {
    var seed: UInt64 = 1
    var dogEar: CGFloat = 0
    var wobble: CGFloat = 0.35

    func path(in r: CGRect) -> Path {
        let c: CGFloat = 2.2
        var pts = [
            CGPoint(x: r.minX + c, y: r.minY), CGPoint(x: r.maxX - c, y: r.minY),
            CGPoint(x: r.maxX, y: r.minY + c)
        ]
        if dogEar > 0 {
            pts += [CGPoint(x: r.maxX, y: r.maxY - dogEar), CGPoint(x: r.maxX - dogEar, y: r.maxY)]
        } else {
            pts += [CGPoint(x: r.maxX, y: r.maxY - c), CGPoint(x: r.maxX - c, y: r.maxY)]
        }
        pts += [CGPoint(x: r.minX + c, y: r.maxY), CGPoint(x: r.minX, y: r.maxY - c), CGPoint(x: r.minX, y: r.minY + c)]
        var p = Path()
        p.addLines(Cutter.handCut(pts, closed: true, seed: seed, wobble: wobble, step: 7))
        p.closeSubpath()
        return p
    }
}

/// The folded-over corner flap (sits in a dogEar x dogEar frame at the card's lower right).
struct DogEarFlap: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY), control: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.12))
        p.closeSubpath()
        return p
    }
}

struct RingCut: Shape {
    var width: CGFloat
    func path(in r: CGRect) -> Path {
        Path(ellipseIn: r).subtracting(Path(ellipseIn: r.insetBy(dx: width, dy: width)))
    }
}

/// A many-pointed burst (sun rays).
struct Sunburst: Shape {
    var rays = 12
    var inner: CGFloat = 0.58
    var phase: Double = 0

    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let R = min(r.width, r.height) / 2
        var p = Path()
        for k in 0..<(rays * 2) {
            let a = Double(k) / Double(rays * 2) * 2 * .pi + phase
            let rad = k % 2 == 0 ? R : R * inner
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// A luggage tag pointing left, with a punched eyelet.
struct TagCut: Shape {
    func path(in r: CGRect) -> Path {
        let n = min(6, r.height * 0.5)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + n, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 2, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + 2), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 2))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 2, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        let e: CGFloat = 2.6
        return p.subtracting(Path(ellipseIn: CGRect(x: r.minX + n * 0.8 - e / 2, y: r.midY - e / 2, width: e, height: e)))
    }
}

/// A swallowtail pennant (bunting flag).
struct PennantCut: Shape {
    var notch: CGFloat = 7
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addLines(Cutter.handCut([
            CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
            CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.midX, y: r.maxY - notch),
            CGPoint(x: r.minX, y: r.maxY)
        ], closed: true, seed: UInt64(r.width * 7 + r.height), wobble: 0.35, step: 5))
        p.closeSubpath()
        return p
    }
}

/// Washi tape: a strip with torn, zig-zag ends.
struct TapeCut: Shape {
    var seed: UInt64 = 3
    func path(in r: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        var pts: [CGPoint] = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY)]
        let teeth = 5
        for k in 1..<teeth {
            let y = r.minY + r.height * CGFloat(k) / CGFloat(teeth)
            pts.append(CGPoint(x: r.maxX - (k % 2 == 1 ? rng.range(1.5...3) : 0), y: y))
        }
        pts.append(CGPoint(x: r.maxX, y: r.maxY))
        pts.append(CGPoint(x: r.minX, y: r.maxY))
        for k in stride(from: teeth - 1, through: 1, by: -1) {
            let y = r.minY + r.height * CGFloat(k) / CGFloat(teeth)
            pts.append(CGPoint(x: r.minX + (k % 2 == 1 ? rng.range(1.5...3) : 0), y: y))
        }
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }
}
