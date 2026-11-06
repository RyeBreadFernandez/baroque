import SwiftUI

// Printing primitives: every colour is laid down as a separate block, so each fill carries the block's wood grain
// and uneven ink, sits a hair out of register with the sumi key line, and the paper shows through.

struct InkSet {
    var grainA: GraphicsContext.ResolvedImage
    var grainB: GraphicsContext.ResolvedImage
    var washi: GraphicsContext.ResolvedImage
    var fibers: GraphicsContext.ResolvedImage

    init(_ ctx: GraphicsContext) {
        grainA = ctx.resolve(WB.grainA)
        grainB = ctx.resolve(WB.grainB)
        washi = ctx.resolve(WB.washiTex)
        fibers = ctx.resolve(WB.fibers)
    }

    func grain(_ i: Int) -> GraphicsContext.ResolvedImage { i % 2 == 0 ? grainA : grainB }
}

extension GraphicsContext {
    /// A printed colour block: flat ink plus the block's grain (soft light) and density, offset out of register.
    func printBlock(_ path: Path, _ shading: Shading, ink: InkSet, grain: Int = 0, strength: Double = 0.6,
                    grainShift: CGPoint = .zero, misreg: CGSize = .zero, size: CGSize) {
        var c = self
        c.translateBy(x: misreg.width, y: misreg.height)
        c.fill(path, with: shading)
        // blend straight into the destination (a drawLayer would composite the gray grain as a veil)
        c.clip(to: path)
        c.blendMode = .softLight
        c.opacity = strength
        c.draw(ink.grain(grain), in: grainRect(size, shift: grainShift))
    }

    /// Bare paper: the washi texture inside `path`.
    func paper(_ path: Path, ink: InkSet, size: CGSize, shift: CGPoint = .zero, opacity: Double = 1) {
        var c = self
        c.opacity = opacity
        c.clip(to: path)
        c.draw(ink.washi, in: grainRect(size, shift: shift))
    }

    /// Sumi key line with the uneven weight of a hand-cut line: a steady stroke plus a broken heavier pass.
    func keyline(_ path: Path, width: CGFloat = 0.9, opacity: Double = 0.92, color: Color = WB.sumi, seed: Int = 0) {
        stroke(path, with: .color(color.opacity(opacity)),
               style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        let dashes: [[CGFloat]] = [[9, 6, 15, 4], [6, 9, 4, 12], [13, 5, 7, 8]]
        stroke(path, with: .color(color.opacity(opacity * 0.55)),
               style: StrokeStyle(lineWidth: width * 1.7, lineCap: .round, lineJoin: .round,
                                  dash: dashes[abs(seed) % dashes.count], dashPhase: CGFloat(seed * 7)))
    }

    /// Paper fibers lying over the ink.
    func fiberVeil(_ size: CGSize, ink: InkSet, opacity: Double = 0.4) {
        var c = self
        c.opacity = opacity
        c.draw(ink.fibers, in: grainRect(size, shift: .zero))
    }
}

/// Grain textures are 348 x 365; stretch them over the drawing with an optional shift so blocks don't share grain.
func grainRect(_ size: CGSize, shift: CGPoint) -> CGRect {
    let w = max(size.width, 348) + 24
    let h = max(size.height, 365) + 24
    return CGRect(x: -12 - shift.x, y: -12 - shift.y, width: w, height: h)
}

extension Path {
    /// Lines through `pts` continuing the current subpath (Path.addLines would start a new one).
    mutating func addPolyline(_ pts: [CGPoint]) {
        for q in pts { addLine(to: q) }
    }
}

enum Geo {
    /// A hand-cut polyline through `keys`: midpoint displacement with a seeded generator.
    static func ridge(_ keys: [CGPoint], rough: CGFloat, levels: Int = 4, seed: UInt64) -> [CGPoint] {
        var rng = SeededRandom(seed: seed)
        var pts = keys
        for level in 0..<levels {
            var out: [CGPoint] = [pts[0]]
            let damp = pow(0.62, CGFloat(level))
            for i in 1..<pts.count {
                let a = pts[i - 1], b = pts[i]
                let len = hypot(b.x - a.x, b.y - a.y)
                let mx = (a.x + b.x) / 2 + rng.range(-0.12...0.12) * (b.x - a.x)
                let my = (a.y + b.y) / 2 + rng.range(-1...1) * len * rough * damp
                out.append(CGPoint(x: mx, y: my))
                out.append(b)
            }
            pts = out
        }
        return pts
    }

    static func fill(_ pts: [CGPoint], base: CGFloat) -> Path {
        var p = Path()
        guard let first = pts.first, let last = pts.last else { return p }
        p.move(to: CGPoint(x: first.x, y: base))
        p.addPolyline(pts)
        p.addLine(to: CGPoint(x: last.x, y: base))
        p.closeSubpath()
        return p
    }

    static func line(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(pts)
        return p
    }

    /// Height of the polyline at `x` (linear between vertices).
    static func y(at x: CGFloat, in pts: [CGPoint]) -> CGFloat {
        guard pts.count > 1 else { return pts.first?.y ?? 0 }
        for i in 1..<pts.count where pts[i].x >= x {
            let a = pts[i - 1], b = pts[i]
            let t = b.x == a.x ? 0 : (x - a.x) / (b.x - a.x)
            return a.y + (b.y - a.y) * max(0, min(1, t))
        }
        return pts.last!.y
    }

    /// Snow cap: follows the ridge and ends in a ragged, dripping edge near the snowline.
    static func snow(_ pts: [CGPoint], snowline: CGFloat, seed: UInt64) -> Path {
        var rng = SeededRandom(seed: seed)
        var p = Path()
        var run: [CGPoint] = []
        func flush() {
            guard run.count > 2 else { run.removeAll(); return }
            // zigzag fingers: alternate long and short drips every few vertices, interpolated between
            let step = 3
            let peakLift = max(1, snowline - (run.map(\.y).min() ?? snowline))
            var targets: [CGFloat] = []
            for k in 0...(run.count / step + 1) {
                targets.append(k % 2 == 0 ? rng.range(peakLift * 0.1...peakLift * 0.28) + 1.5 : rng.range(0...1.0))
            }
            var bottom: [CGPoint] = []
            for (i, q) in run.enumerated() {
                let lift = max(0, snowline - q.y)
                let k = i / step, t = CGFloat(i % step) / CGFloat(step)
                let drip = targets[k] + (targets[k + 1] - targets[k]) * t
                let edge = i == 0 || i == run.count - 1
                let d = edge ? 0 : lift * 0.45 + drip * min(1, lift / 4 + 0.3)
                bottom.append(CGPoint(x: q.x, y: q.y + d))
            }
            p.move(to: run[0])
            p.addPolyline(run)
            p.addPolyline(bottom.reversed())
            p.closeSubpath()
            run.removeAll()
        }
        for q in pts {
            if q.y < snowline { run.append(q) } else { if !run.isEmpty { run.append(q) }; flush() }
        }
        flush()
        return p
    }

    /// Slightly uneven rectangle, as if cut by hand.
    static func roughRect(_ r: CGRect, jitter: CGFloat, seed: UInt64, steps: Int = 5) -> Path {
        var rng = SeededRandom(seed: seed)
        let corners = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                       CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
        var p = Path()
        for i in 0..<4 {
            let a = corners[i], b = corners[(i + 1) % 4]
            for s in 0..<steps {
                let t = CGFloat(s) / CGFloat(steps)
                let q = CGPoint(x: a.x + (b.x - a.x) * t + rng.range(-jitter...jitter),
                                y: a.y + (b.y - a.y) * t + rng.range(-jitter...jitter))
                if i == 0 && s == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
        }
        p.closeSubpath()
        return p
    }
}
