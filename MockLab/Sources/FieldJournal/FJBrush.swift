import SwiftUI

// Hand-made marks: smooth noise for wobble, Catmull-Rom paths, tapered ink strokes, grainy pencil,
// and the watercolour wash (layered body, pooled edge, granulation into the paper tooth, blooms).

/// Smooth 1-D noise from a few seeded sines: deterministic and cheap.
struct Wobble {
    private var waves: [(f: CGFloat, p: CGFloat, a: CGFloat)] = []
    init(seed: UInt64, base: CGFloat = 0.08, octaves: Int = 4) {
        var r = SeededRandom(seed: seed)
        var amp: CGFloat = 1
        var freq = base
        var total: CGFloat = 0
        for _ in 0..<octaves {
            waves.append((freq * r.range(0.8...1.25), r.range(0...(2 * .pi)), amp))
            total += amp
            amp *= 0.5
            freq *= 2.1
        }
        waves = waves.map { ($0.f, $0.p, $0.a / total) }
    }
    func callAsFunction(_ x: CGFloat) -> CGFloat {
        waves.reduce(0) { $0 + $1.a * sin($1.f * x + $1.p) }
    }
}

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
    var length: CGFloat { sqrt(x * x + y * y) }
    var normalized: CGPoint { let l = max(length, 0.0001); return CGPoint(x: x / l, y: y / l) }
    var perp: CGPoint { CGPoint(x: -y, y: x) }
}

enum Brush {
    /// A smooth curve through the points (Catmull-Rom as cubic Béziers).
    static func smooth(_ p: [CGPoint], closed: Bool = false) -> Path {
        var path = Path()
        guard p.count > 1 else { return path }
        let n = p.count
        func at(_ i: Int) -> CGPoint {
            if closed { return p[(i % n + n) % n] }
            return p[min(max(i, 0), n - 1)]
        }
        path.move(to: p[0])
        let segments = closed ? n : n - 1
        for i in 0..<segments {
            let p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2)
            let c1 = p1 + (p2 - p0) * (1.0 / 6.0)
            let c2 = p2 - (p3 - p1) * (1.0 / 6.0)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        if closed { path.closeSubpath() }
        return path
    }

    /// Resample a polyline every `step` points and push each sample sideways by smooth noise (a steady hand, not a ruler).
    static func wobbly(_ pts: [CGPoint], amplitude: CGFloat, step: CGFloat = 3, seed: UInt64) -> [CGPoint] {
        guard pts.count > 1 else { return pts }
        let w = Wobble(seed: seed, base: 0.11)
        var out: [CGPoint] = []
        var dist: CGFloat = 0
        for i in 0..<(pts.count - 1) {
            let a = pts[i], b = pts[i + 1]
            let d = (b - a).length
            let n = max(1, Int(d / step))
            let nrm = (b - a).normalized.perp
            for k in 0..<n {
                let t = CGFloat(k) / CGFloat(n)
                let p = a + (b - a) * t
                out.append(p + nrm * (w(dist + d * t) * amplitude))
            }
            dist += d
        }
        let last = pts[pts.count - 1]
        out.append(last + (last - pts[pts.count - 2]).normalized.perp * (w(dist) * amplitude))
        return out
    }

    /// A filled, tapered ink stroke along the points: pressure swells mid-stroke and lifts at the ends.
    static func tapered(_ pts: [CGPoint], width: CGFloat, taperIn: CGFloat = 0.25, taperOut: CGFloat = 0.35,
                        pressureSeed: UInt64 = 1, pressureVar: CGFloat = 0.35) -> Path {
        guard pts.count > 1 else { return Path() }
        var cum: [CGFloat] = [0]
        for i in 1..<pts.count { cum.append(cum[i - 1] + (pts[i] - pts[i - 1]).length) }
        let total = max(cum.last ?? 1, 0.001)
        let pressure = Wobble(seed: pressureSeed, base: 0.09, octaves: 2)
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0..<pts.count {
            let prev = pts[max(i - 1, 0)], next = pts[min(i + 1, pts.count - 1)]
            let n = (next - prev).normalized.perp
            let t = cum[i] / total
            var w = width * (1 + pressure(cum[i]) * pressureVar)
            if taperIn > 0 { w *= min(1, 0.18 + t / taperIn) }
            if taperOut > 0 { w *= min(1, 0.12 + (1 - t) / taperOut) }
            left.append(pts[i] + n * (w / 2))
            right.append(pts[i] - n * (w / 2))
        }
        return outline(left: left, right: right)
    }

    private static func outline(left: [CGPoint], right: [CGPoint]) -> Path {
        var all = left
        all.append(contentsOf: right.reversed())
        return smooth(all, closed: true)
    }

    /// An irregular closed blob (watercolour dab, flower petal base) around a centre.
    static func blob(center c: CGPoint, rx: CGFloat, ry: CGFloat, irregularity: CGFloat = 0.12,
                     points: Int = 18, rotation: CGFloat = 0, seed: UInt64) -> Path {
        let w = Wobble(seed: seed, base: 1.0, octaves: 3)
        var pts: [CGPoint] = []
        for i in 0..<points {
            let a = CGFloat(i) / CGFloat(points) * 2 * .pi
            let k = 1 + w(a * 2.3) * irregularity * 2
            let x = cos(a) * rx * k, y = sin(a) * ry * k
            pts.append(CGPoint(x: c.x + x * cos(rotation) - y * sin(rotation),
                               y: c.y + x * sin(rotation) + y * cos(rotation)))
        }
        return smooth(pts, closed: true)
    }

    /// A hand-drawn loop (circling something), overshooting its start like a quick pencil ring.
    static func loopPoints(in r: CGRect, turns: CGFloat = 1.12, seed: UInt64) -> [CGPoint] {
        let w = Wobble(seed: seed, base: 1.3, octaves: 3)
        var pts: [CGPoint] = []
        let n = 46
        let start: CGFloat = -2.4
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let a = start + t * turns * 2 * .pi
            let grow = 1 + (t - 0.5) * 0.10 + w(a) * 0.05
            pts.append(CGPoint(x: r.midX + cos(a) * r.width / 2 * grow,
                               y: r.midY + sin(a) * r.height / 2 * grow))
        }
        return pts
    }
}

extension GraphicsContext {
    /// Graphite or coloured pencil: a soft core plus broken grainy passes.
    func pencil(_ path: Path, color: Color, width: CGFloat, seed: UInt64, strength: Double = 1) {
        var r = SeededRandom(seed: seed)
        stroke(path, with: .color(color.opacity(0.30 * strength)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        for _ in 0..<3 {
            let dash: [CGFloat] = [r.range(0.4...1.6), r.range(0.2...0.7), r.range(0.8...2.4), r.range(0.2...0.6)]
            let off = CGSize(width: r.range(-0.25...0.25), height: r.range(-0.25...0.25))
            var c = self
            c.translateBy(x: off.width, y: off.height)
            c.stroke(path, with: .color(color.opacity(0.42 * strength)),
                     style: StrokeStyle(lineWidth: width * 0.62, lineCap: .butt, lineJoin: .round, dash: dash, dashPhase: r.range(0...4)))
        }
    }

    /// Ink: a filled tapered stroke with a faint wet halo.
    func ink(_ pts: [CGPoint], color: Color, width: CGFloat, seed: UInt64, taperIn: CGFloat = 0.25, taperOut: CGFloat = 0.35, opacity: Double = 0.92) {
        let p = Brush.tapered(pts, width: width, taperIn: taperIn, taperOut: taperOut, pressureSeed: seed)
        fill(p, with: .color(color.opacity(opacity)))
    }

    /// Transparent watercolour, painted in its own layer and multiplied onto the paper: three offset passes of
    /// pigment, a darker pooled rim, pigment settling into the paper tooth, blooms that lift colour with a dark
    /// fringe, and optional fades where the wash runs dry (`fade` downward, `fadeUp` upward, as y ranges).
    func wash(_ shape: Path, pigment: Color, rim: Color? = nil, opacity: Double = 1, seed: UInt64,
              tooth: GraphicsContext.ResolvedImage? = nil, granulation: Double = 0.35, blooms: Int = 1,
              rimWidth: CGFloat = 2.2, spread: CGFloat = 1.0, soft: CGFloat = 0,
              fade: ClosedRange<CGFloat>? = nil, fadeUp: ClosedRange<CGFloat>? = nil) {
        let rimColor = rim ?? pigment
        var outer = self
        outer.blendMode = .multiply
        outer.drawLayer { l in
            var r = SeededRandom(seed: seed)
            var bodyCtx = l
            if soft > 0 { bodyCtx.addFilter(.blur(radius: soft)) }
            for i in 0..<3 {
                let dx = r.range(-spread...spread), dy = r.range(-spread...spread)
                bodyCtx.fill(shape.offsetBy(dx: dx, dy: dy), with: .color(pigment.opacity(opacity * (i == 0 ? 0.36 : 0.24))))
            }
            var e = l
            e.clip(to: shape)
            e.addFilter(.blur(radius: 0.7 + soft * 0.6))
            e.stroke(shape, with: .color(rimColor.opacity((soft > 0 ? 0.3 : 0.55) * opacity)), lineWidth: rimWidth)
            let b = shape.boundingRect
            if let tooth, granulation > 0 {
                var g = l
                g.clip(to: shape)
                var t = tooth
                t.shading = .color(rimColor.opacity(granulation * opacity))
                let ox = r.range(0...max(0, 350 - b.width)), oy = r.range(0...max(0, 370 - b.height))
                var ty = b.minY - oy
                while ty < b.maxY {
                    var tx = b.minX - ox
                    while tx < b.maxX {
                        g.draw(t, in: CGRect(x: tx, y: ty, width: 350, height: 370))
                        tx += 350
                    }
                    ty += 370
                }
            }
            for k in 0..<blooms {
                let rad = r.range(0.2...0.34) * min(b.width, b.height) + 3
                let ctr = CGPoint(x: r.range(b.minX...b.maxX), y: r.range((b.minY + b.height * 0.15)...b.maxY))
                let ring = Brush.blob(center: ctr, rx: rad, ry: rad * r.range(0.7...1.0), irregularity: 0.22, points: 22,
                                      seed: seed &+ UInt64(k + 1) &* 31)
                var lift = l
                lift.clip(to: shape)
                lift.blendMode = .destinationOut
                lift.fill(ring, with: .radialGradient(Gradient(colors: [.black.opacity(0.55), .black.opacity(0.25)]),
                                                      center: ctr, startRadius: 0, endRadius: rad))
                var fr = l
                fr.clip(to: shape)
                fr.addFilter(.blur(radius: 0.45))
                fr.stroke(ring, with: .color(rimColor.opacity(0.42 * opacity)), lineWidth: 1.0)
            }
            if let fade {
                var f = l
                f.blendMode = .destinationOut
                let rect = CGRect(x: b.minX - 60, y: fade.lowerBound, width: b.width + 120, height: max(b.maxY, fade.upperBound) - fade.lowerBound + 6)
                f.fill(Path(rect), with: .linearGradient(Gradient(stops: [.init(color: .black.opacity(0), location: 0),
                                                                          .init(color: .black, location: (fade.upperBound - fade.lowerBound) / max(rect.height, 1))]),
                                                         startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
            }
            if let fadeUp {
                var f = l
                f.blendMode = .destinationOut
                let rect = CGRect(x: b.minX - 60, y: min(b.minY, fadeUp.lowerBound) - 20, width: b.width + 120,
                                  height: fadeUp.upperBound - min(b.minY, fadeUp.lowerBound) + 20)
                let span = fadeUp.upperBound - fadeUp.lowerBound
                f.fill(Path(rect), with: .linearGradient(Gradient(stops: [.init(color: .black, location: 1 - span / max(rect.height, 1)),
                                                                          .init(color: .black.opacity(0), location: 1)]),
                                                         startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
            }
        }
    }
}
