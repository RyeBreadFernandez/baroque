import SwiftUI

// The Matterhorn engraved on the instrument's horizon: gold hatching on navy, so (as in a white-line engraving) the
// more gold, the more light. The faces follow Old Master Cover's reading of the photograph
// (Textures/old-master-cover/make.py, matterhorn()): the steep left face in shadow (a few level lines), the east face
// in front lit, its snow cut as broken strokes down the fall line, a dark unworked band under the summit ridge that
// runs on from the notch as the Hornli ridge, the lit north face beyond it, and the lower ridges in sparse level
// lines; the hatching thins into mist toward the horizon.

extension CEMatterhorn {
    /// The skyline's depth (pyramid heights, y down) at unit x; level beyond the ends of the trace.
    static func depth(at u: Double) -> Double {
        if u <= xs[0] { return ys[0] }
        if u >= xs[xs.count - 1] { return ys[ys.count - 1] }
        var lo = 0, hi = xs.count - 1
        while hi - lo > 1 {
            let m = (lo + hi) / 2
            if xs[m] <= u { lo = m } else { hi = m }
        }
        let t = (u - xs[lo]) / (xs[hi] - xs[lo])
        return ys[lo] + t * (ys[hi] - ys[lo])
    }

    /// The Hornli ridge, from the notch down to the right (as in Old Master Cover's painter).
    static func hornli(_ v: Double) -> Double {
        interp(v, [notch.y, 0.825, 1.026, 1.226, 1.6, 3.0], [notch.x - 0.02, 0.579, 0.723, 0.838, 1.1, 2.0])
    }

    /// Width of the dark band under the summit ridge (to the notch) and either side of the Hornli ridge.
    static func band(_ v: Double) -> Double {
        v <= notch.y ? interp(v, [0, 0.12, 0.35, notch.y], [0, 0.03, 0.06, 0.07]) : interp(v, [notch.y, 0.9, 1.3], [0.05, 0.035, 0.03])
    }

    /// The edge between the shadowed left face and the lit east face.
    static func shadowEdge(_ v: Double) -> Double { 0.03 - 0.33 * v }

    static func interp(_ x: Double, _ xp: [Double], _ fp: [Double]) -> Double {
        if x <= xp[0] { return fp[0] }
        for i in 1..<xp.count where x <= xp[i] {
            let t = (x - xp[i - 1]) / (xp[i] - xp[i - 1])
            return fp[i - 1] + t * (fp[i] - fp[i - 1])
        }
        return fp[fp.count - 1]
    }
}

/// The Matterhorn placed on a horizon: summit at `summit` (pt), the pyramid `h` pt tall, drawn from x0 to x1.
struct CEPeak {
    var summit: CGPoint
    var h: CGFloat
    var base: CGFloat
    var x0: CGFloat
    var x1: CGFloat

    typealias M = CEMatterhorn

    func pt(_ u: Double, _ v: Double) -> CGPoint {
        CGPoint(x: summit.x + CGFloat(u) * h, y: min(base + 2, summit.y + CGFloat(v) * h))
    }

    func unit(_ x: CGFloat) -> Double { Double((x - summit.x) / h) }

    /// The skyline from x0 to x1, pinned to the horizon where it would dip below it.
    var crest: [CGPoint] {
        let u0 = unit(x0), u1 = unit(x1)
        var pts = [pt(u0, M.depth(at: u0))]
        for i in M.xs.indices where M.xs[i] > u0 && M.xs[i] < u1 { pts.append(pt(M.xs[i], M.ys[i])) }
        pts.append(pt(u1, M.depth(at: u1)))
        return pts.map { CGPoint(x: $0.x, y: min($0.y, base)) }
    }

    var crestPath: Path {
        var p = Path()
        p.addLines(crest)
        return p
    }

    /// The whole range, closed down to the horizon.
    var silhouette: Path {
        var p = Path()
        p.addLines(crest)
        p.addLine(to: CGPoint(x: x1, y: base + 1))
        p.addLine(to: CGPoint(x: x0, y: base + 1))
        p.closeSubpath()
        return p
    }

    private func poly(_ pts: [(Double, Double)]) -> Path {
        var p = Path()
        p.addLines(pts.map { pt($0.0, $0.1) })
        p.closeSubpath()
        return p
    }

    private func steps(_ a: Double, _ b: Double, _ n: Int = 24) -> [Double] {
        (0...n).map { a + (b - a) * Double($0) / Double(n) }
    }

    private var deep: Double { Double((base - summit.y) / h) + 0.05 }

    /// The pyramid itself: the left skyline from the foot to the summit, the right skyline to the shoulder, and its
    /// edges running on down below the foot and the shoulder.
    var pyramid: Path {
        let f = M.foot, s = M.shoulder
        var pts: [(Double, Double)] = []
        for v in steps(deep, f.y, 8) { pts.append((f.x - 0.45 * (v - f.y), v)) }
        for i in M.xs.indices where M.xs[i] > f.x && M.xs[i] < s.x { pts.append((M.xs[i], M.ys[i])) }
        for v in steps(s.y, deep, 8) { pts.append((s.x + 1.2 * (v - s.y), v)) }
        return poly(pts)
    }

    var leftFace: Path {
        var pts: [(Double, Double)] = [(-4, -0.2), (M.shadowEdge(-0.2), -0.2)]
        for v in steps(-0.2, deep) { pts.append((M.shadowEdge(v), v)) }
        pts.append((-4, deep))
        return poly(pts)
    }

    var eastFace: Path {
        var pts: [(Double, Double)] = []
        for v in steps(0, deep) { pts.append((M.shadowEdge(v), v)) }
        for v in steps(deep, M.notch.y) { pts.append((M.hornli(v) - M.band(v), v)) }
        // Up under the summit ridge, inset by the dark band.
        let right = M.xs.indices.filter { M.xs[$0] >= 0 && M.xs[$0] <= M.notch.x }.reversed()
        for i in right { pts.append((M.xs[i] - M.band(M.ys[i]), M.ys[i])) }
        return poly(pts)
    }

    var northFace: Path {
        var pts: [(Double, Double)] = []
        for v in steps(M.notch.y, deep) { pts.append((M.hornli(v) + M.band(v), v)) }
        pts.append((5, deep))
        pts.append((5, M.notch.y - 0.2))
        pts.append((M.notch.x, M.notch.y - 0.2))
        return poly(pts)
    }

    /// The ridge between the faces, from just under the summit down into the mist.
    var shadowRidge: Path {
        var p = Path()
        p.addLines(steps(0.03, min(1.15, deep), 12).map { pt(M.shadowEdge($0), $0) })
        return p
    }

    var hornliRidge: Path {
        var p = Path()
        p.addLines(steps(M.notch.y, min(1.3, deep), 12).map { pt(M.hornli($0), $0) })
        return p
    }

    /// Engraves the range into `ctx` (fill, hatching, ridges, skyline). `fill` is the colour the range is cut from.
    func engrave(_ ctx: GraphicsContext, fill: Color, sheen: GraphicsContext.Shading, line: CGFloat, spacing: CGFloat, seed: UInt64) {
        let sil = silhouette
        let pyr = pyramid.intersection(sil)
        // The range is cut from the plate: it hides the sky, the stars and the day ring behind it.
        ctx.fill(sil, with: .linearGradient(Gradient(colors: [fill, fill.opacity(0.92)]),
                                            startPoint: CGPoint(x: 0, y: summit.y), endPoint: CGPoint(x: 0, y: base)))
        let box = sil.boundingRect.insetBy(dx: -2, dy: -2)
        let k = h / 66 // scale of the strokes against the large dial
        let hair = StrokeStyle(lineWidth: line * 0.62, lineCap: .round)

        ctx.drawLayer { layer in
            // Lower ridges: sparse level lines.
            layer.drawLayer { l in
                l.clip(to: sil.subtracting(pyr))
                l.stroke(CEEngrave.hatch(box, angle: 0.02, spacing: spacing * 2.3, dash: (on: 6 * k...26 * k, off: 1.5...5), seed: seed),
                         with: sheen, style: hair)
                l.opacity = 1
            }
            // Left face, in shadow: a few level lines.
            layer.drawLayer { l in
                l.clip(to: pyr)
                l.clip(to: leftFace)
                l.opacity = 0.34
                l.stroke(CEEngrave.hatch(box, angle: -0.08, spacing: spacing * 2.4, seed: seed &+ 1), with: sheen, style: hair)
            }
            // East face, lit: broken strokes down the fall line (snow on the ledges, rock between).
            layer.drawLayer { l in
                l.clip(to: pyr)
                l.clip(to: eastFace)
                l.stroke(CEEngrave.hatch(box, angle: .pi / 2 + 0.36, spacing: spacing, dash: (on: 2.5 * k...13 * k, off: 0.8...3.6), seed: seed &+ 2),
                         with: sheen, style: StrokeStyle(lineWidth: line * 0.7, lineCap: .round))
            }
            // North face beyond the Hornli ridge, lit snow: strokes leaning down to the right.
            layer.drawLayer { l in
                l.clip(to: pyr)
                l.clip(to: northFace)
                l.opacity = 0.9
                l.stroke(CEEngrave.hatch(box, angle: .pi / 2 - 0.55, spacing: spacing * 1.2, dash: (on: 3 * k...11 * k, off: 0.8...3), seed: seed &+ 3),
                         with: sheen, style: StrokeStyle(lineWidth: line * 0.66, lineCap: .round))
            }
            // Mist: the hatching thins out toward the horizon.
            layer.blendMode = .destinationOut
            let top = summit.y + 0.95 * h
            layer.fill(Path(CGRect(x: box.minX, y: top, width: box.width, height: base - top + 2)),
                       with: .linearGradient(Gradient(colors: [.black.opacity(0), .black.opacity(0.85)]),
                                             startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: base)))
        }
        // Ridges and the skyline, cut deeper.
        ctx.drawLayer { l in
            l.clip(to: sil)
            CEEngrave.line(l, shadowRidge, width: line * 0.7, shading: sheen, light: 0.6, groove: 0.6)
            CEEngrave.line(l, hornliRidge, width: line * 0.7, shading: sheen, light: 0.6, groove: 0.6)
        }
        CEEngrave.line(ctx, crestPath, width: line, shading: sheen, light: 1)
    }
}
