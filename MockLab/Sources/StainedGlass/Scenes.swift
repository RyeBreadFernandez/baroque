import SwiftUI

// Builders that cut the window: a radiating sky around a rose-window sun, faceted mountain shards with
// snowcaps, whiplash stems and cloud ribbons, a jewel border, pale cathedral-glass panels, and arched lancets.

struct MountainRange {
    var ridge: [CGPoint]          // left base ... peaks ... right base
    var base: CGFloat             // where the facets' spines land
    var lit: Glass = .heather
    var shade: Glass = .indigo
    var low: Glass = .dusk
    var snowline: CGFloat? = nil  // peaks above this y get snowcaps
    var seed: UInt64 = 1
    var strata: Bool = true       // painted rock lines on the faces
    var facet: CGFloat = 24       // depth of the upper row of facets below the ridge
}

enum Scene {
    // MARK: sky

    /// Rings of radiating panes around the sun; the inner ring warm, the rest jewel blues, paler toward the horizon.
    static func sky(_ w: inout Window, _ size: CGSize, sun: CGPoint, radii: [CGFloat], rays: Int,
                    rotation: Double = -90, seed: UInt64 = 7, warmRings: Int = 1, horizon: CGFloat? = nil) {
        var rng = SeededRandom(seed: seed)
        let canvas = CGRect(origin: .zero, size: size).insetBy(dx: -4, dy: -4)
        let step = 360.0 / Double(rays)
        let warm: [Glass] = [.gold, .amber]
        let near: [Glass] = [.skyPale, .sapphire, .skyPale, .cobalt]
        let far: [Glass] = [.cobalt, .ultramarine, .sapphire, .cobalt, .ultramarine]
        let low = horizon ?? size.height * 0.5
        for k in 0..<(radii.count - 1) {
            let r0 = radii[k], r1 = radii[k + 1]
            let offset = (k % 2 == 1) ? step / 2 : 0
            for i in 0..<rays {
                let a0 = rotation + offset + Double(i) * step
                let a1 = a0 + step
                let path = Geo.sector(sun, r0, r1, a0, a1)
                guard path.boundingRect.intersects(canvas) else { continue }
                let am = (a0 + a1) / 2
                let mid = Geo.polar(sun, (r0 + min(r1, r0 + 90)) / 2, am)
                let glass: Glass
                if k < warmRings {
                    glass = warm[(i + k) % 2]
                } else if k == warmRings || mid.y > low {
                    glass = near[Int(rng.next() % UInt64(near.count))]
                } else {
                    glass = far[Int(rng.next() % UInt64(far.count))]
                }
                let rl = r0 + min(r1 - r0, 120) * rng.range(0.15...0.45)
                var p = Pane(path: path, glass: glass, light: Geo.polar(sun, rl, am + Double(rng.range(-0.25...0.25)) * step))
                p.reach = k < warmRings ? 0.9 : rng.range(0.7...1.0)
                p.texture = k % 2 == 0 ? .streaky : .hammered
                p.texAngle = am + 90 + Double(rng.range(-20...20))
                p.texShift = CGPoint(x: rng.range(-60...60), y: rng.range(-60...60))
                p.texStrength = 0.6
                p.bloom = k < warmRings ? 0.3 : 0
                p.corners = k == 0 ? [Geo.polar(sun, r1, a0), Geo.polar(sun, r1, a1)]
                                   : [Geo.polar(sun, r0, a0), Geo.polar(sun, r0, a1), Geo.polar(sun, r1, a0), Geo.polar(sun, r1, a1)]
                p.lead = k < warmRings ? 2.0 : 2.5
                w.add(p)
            }
        }
    }

    // MARK: sun as a rose window

    static func sunRose(_ w: inout Window, center c: CGPoint, radius r: CGFloat, petals n: Int, seed: UInt64 = 3) {
        var rng = SeededRandom(seed: seed)
        let step = 360.0 / Double(n)
        // outer ring of the rose: alternating amber and ruby segments
        for i in 0..<n {
            let a0 = -90 + Double(i) * step, a1 = a0 + step
            var p = Pane(path: Geo.sector(c, r * 0.74, r, a0, a1), glass: i % 2 == 0 ? .amber : .ruby,
                         light: Geo.polar(c, r * 0.8, (a0 + a1) / 2))
            p.reach = 1.1
            p.texture = .hammered
            p.texAngle = Double(rng.range(0...360))
            p.bloom = 0.4
            p.lead = r > 30 ? 1.9 : 1.6
            w.add(p)
        }
        var ground = Pane(path: Geo.circle(c, r * 0.74), glass: .garnet, light: c)
        ground.reach = 0.6
        ground.texture = .hammered
        ground.lead = r > 30 ? 1.9 : 1.6
        w.add(ground)
        // petals: pointed ovals from the heart to the ring, each with a painted midrib
        var ribs = Path()
        for i in 0..<n {
            let a = -90 + Double(i) * step + step / 2
            let inner = Geo.polar(c, r * 0.3, a), tip = Geo.polar(c, r * 0.74, a)
            let half = r * 0.23
            let side1 = Geo.polar(Geo.lerp(inner, tip, 0.48), half, a + 90)
            let side2 = Geo.polar(Geo.lerp(inner, tip, 0.48), half, a - 90)
            var path = Path()
            path.move(to: inner)
            path.addQuadCurve(to: tip, control: side1)
            path.addQuadCurve(to: inner, control: side2)
            path.closeSubpath()
            var p = Pane(path: path, glass: .gold, light: Geo.lerp(inner, tip, 0.35))
            p.reach = 0.9
            p.texture = .streaky
            p.texAngle = a
            p.bloom = 0.45
            p.lead = r > 30 ? 1.6 : 1.3
            w.add(p)
            ribs.move(to: Geo.lerp(inner, tip, 0.25))
            ribs.addLine(to: Geo.lerp(inner, tip, 0.78))
        }
        if r > 20 { w.paint(ribs, r > 30 ? 0.9 : 0.6) }
        var heart = Pane(path: Geo.circle(c, r * 0.32), glass: .sun, light: CGPoint(x: c.x - r * 0.05, y: c.y - r * 0.05))
        heart.reach = 1.1
        heart.texture = .hammered
        heart.texStrength = 0.35
        heart.bloom = 0.9
        heart.lead = r > 30 ? 2.0 : 1.6
        heart.rim = 0.6
        w.add(heart)
    }

    // MARK: mountains

    /// Crystalline mountains: a row of triangular facets hung from the ridge (lit faces rising to the right,
    /// shadow faces falling), wedges under each ridge point, a lower row of dusk facets, then snowcaps.
    static func mountains(_ w: inout Window, _ m: MountainRange) {
        var rng = SeededRandom(seed: m.seed)
        let pts = m.ridge
        let n = pts.count
        guard n >= 3 else { return }
        var f: [CGPoint] = []
        for i in 0..<(n - 1) {
            let a = pts[i], b = pts[i + 1]
            f.append(CGPoint(x: a.x + (b.x - a.x) * rng.range(0.38...0.62), y: max(a.y, b.y) + m.facet * rng.range(0.75...1.2)))
        }
        let feet: [CGPoint] = f.map { CGPoint(x: $0.x + rng.range(-10...10), y: m.base) }
        var strata = Path()
        // upper row: one face under each ridge segment
        for i in 0..<(n - 1) {
            let a = pts[i], b = pts[i + 1]
            let lit = b.y < a.y
            addFacet(&w, [a, b, f[i]], lit ? m.lit : m.shade, &rng, top: lit ? b : a)
            if m.strata {
                for k in 1...2 {
                    let t = CGFloat(k) * 0.28 + rng.range(-0.04...0.04)
                    let p0 = Geo.lerp(a, f[i], t), p1 = Geo.lerp(b, f[i], t)
                    strata.move(to: Geo.lerp(p0, p1, rng.range(0.08...0.2)))
                    strata.addLine(to: Geo.lerp(p0, p1, rng.range(0.55...0.8)))
                }
            }
        }
        // wedges under each interior ridge point
        for i in 1..<(n - 1) {
            let p = pts[i]
            let peak = p.y < pts[i - 1].y && p.y < pts[i + 1].y
            addFacet(&w, [p, f[i], f[i - 1]], peak ? m.shade : m.lit, &rng, top: p, dim: !peak)
        }
        // lower row down to the base
        let first = pts[0], last = pts[n - 1]
        addFacet(&w, [first, f[0], feet[0], CGPoint(x: first.x, y: m.base)], m.low, &rng, top: first, corners: false)
        for i in 0..<(f.count - 1) {
            addFacet(&w, [f[i], f[i + 1], feet[i + 1], feet[i]], i % 2 == 0 ? m.low : m.shade, &rng,
                     top: f[i].y < f[i + 1].y ? f[i] : f[i + 1], dim: true)
        }
        addFacet(&w, [f[f.count - 1], last, CGPoint(x: last.x, y: m.base), feet[f.count - 1]], m.low, &rng, top: last, corners: false)
        w.paint(strata, 0.7)
        if let snow = m.snowline { snowcaps(&w, pts, f, snow, &rng) }
        var ridge = Path()
        ridge.addLines(pts)
        w.lead(ridge, 3.0)
    }

    private static func addFacet(_ w: inout Window, _ pts: [CGPoint], _ g: Glass, _ rng: inout SeededRandom,
                                 top: CGPoint, dim: Bool = false, corners: Bool = true) {
        let c = Geo.centroid(pts)
        var p = Pane(path: Geo.poly(pts), glass: g, light: Geo.lerp(c, top, rng.range(0.3...0.55)))
        p.reach = dim ? rng.range(0.6...0.8) : rng.range(0.85...1.15)
        p.texture = rng.unit() < 0.5 ? .streaky : .hammered
        p.texAngle = Double(rng.range(0...360))
        p.texShift = CGPoint(x: rng.range(-80...80), y: rng.range(-80...80))
        p.lead = 2.2
        p.corners = corners ? pts : []
        w.add(p)
    }

    private static func snowcaps(_ w: inout Window, _ pts: [CGPoint], _ f: [CGPoint], _ line: CGFloat, _ rng: inout SeededRandom) {
        for i in 1..<(pts.count - 1) {
            let p = pts[i], l = pts[i - 1], r = pts[i + 1]
            guard p.y < l.y, p.y < r.y, p.y < line - 4 else { continue }
            let depth = min(line - p.y, (min(l.y, r.y) - p.y) * 0.8)
            guard depth > 5 else { continue }
            let lp = Geo.lerp(p, l, depth / (l.y - p.y))
            let rp = Geo.lerp(p, r, depth / (r.y - p.y))
            let under = Geo.lerp(f[i - 1], f[i], 0.5)
            let spine = Geo.lerp(p, under, min(1, depth * 1.2 / max(under.y - p.y, 1)))
            func jag(_ a: CGPoint, _ b: CGPoint) -> [CGPoint] {
                let q1 = Geo.lerp(a, b, 0.33), q2 = Geo.lerp(a, b, 0.66)
                return [CGPoint(x: q1.x, y: q1.y + depth * rng.range(0.14...0.24)),
                        CGPoint(x: q2.x, y: q2.y - depth * rng.range(0.08...0.18))]
            }
            let left = [p, lp] + jag(lp, spine) + [spine]
            let right = [p, spine] + jag(spine, rp) + [rp]
            var a = Pane(path: Geo.poly(left), glass: .opal, light: Geo.lerp(p, lp, 0.45))
            a.reach = 1.0
            a.texture = .hammered
            a.texStrength = 0.45
            a.bloom = 0.25
            a.lead = 2.0
            a.corners = [lp, spine]
            w.add(a)
            var b = Pane(path: Geo.poly(right), glass: .opalShade, light: Geo.lerp(p, spine, 0.3))
            b.reach = 1.0
            b.texture = .hammered
            b.texStrength = 0.45
            b.lead = 2.0
            b.corners = [rp]
            w.add(b)
        }
    }

    // MARK: whiplash curves

    /// Points along a Catmull-Rom curve through `pts`.
    static func sampleSpline(_ pts: [CGPoint], perSegment n: Int = 12) -> [CGPoint] {
        guard pts.count >= 2 else { return pts }
        var out: [CGPoint] = [pts[0]]
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
            for s in 1...n {
                let t = CGFloat(s) / CGFloat(n), t2 = t * t, t3 = t2 * t
                func f(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                    0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
                }
                out.append(CGPoint(x: f(p0.x, p1.x, p2.x, p3.x), y: f(p0.y, p1.y, p2.y, p3.y)))
            }
        }
        return out
    }

    static func cubic(_ a: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ b: CGPoint, _ n: Int = 14) -> [CGPoint] {
        (0...n).map { s in
            let t = CGFloat(s) / CGFloat(n), u = 1 - t
            return CGPoint(x: u * u * u * a.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * b.x,
                           y: u * u * u * a.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * b.y)
        }
    }

    /// An Art Nouveau stem: a whiplash lead rising from `base`, leaves along it, a tulip at the top,
    /// and a tendril that springs off near the head and winds into a tight curl.
    static func stem(_ w: inout Window, base: CGPoint, top: CGPoint, bend: CGFloat, curl: CGFloat,
                     leaves: [(t: CGFloat, side: CGFloat, len: CGFloat)], bud: Glass, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        let d = CGPoint(x: top.x - base.x, y: top.y - base.y)
        let len = max(hypot(d.x, d.y), 1)
        let n = CGPoint(x: -d.y / len, y: d.x / len)
        let c1 = CGPoint(x: base.x + d.x * 0.35 + n.x * bend, y: base.y + d.y * 0.35 + n.y * bend)
        let c2 = CGPoint(x: base.x + d.x * 0.7 - n.x * bend, y: base.y + d.y * 0.7 - n.y * bend)
        let spine = cubic(base, c1, c2, top, 30)
        func frame(_ t: CGFloat) -> (p: CGPoint, u: CGPoint) {
            let idx = min(spine.count - 2, max(1, Int(t * CGFloat(spine.count - 1))))
            let tan = CGPoint(x: spine[idx + 1].x - spine[idx - 1].x, y: spine[idx + 1].y - spine[idx - 1].y)
            let tl = max(hypot(tan.x, tan.y), 0.001)
            return (spine[idx], CGPoint(x: tan.x / tl, y: tan.y / tl))
        }
        for leaf in leaves {
            let (a, u) = frame(leaf.t)
            let nn = CGPoint(x: -u.y * leaf.side, y: u.x * leaf.side)
            let tip = CGPoint(x: a.x + (u.x * 0.8 + nn.x * 0.6) * leaf.len, y: a.y + (u.y * 0.8 + nn.y * 0.6) * leaf.len)
            Scene.leaf(&w, from: a, to: tip, width: leaf.len * 0.34 * leaf.side, glass: rng.unit() < 0.5 ? .emerald : .jade)
        }
        // the tendril: leaves the stem near the head and coils
        let (tp, tu) = frame(0.84)
        let side: CGFloat = curl > 0 ? 1 : -1
        let tn = CGPoint(x: -tu.y * side, y: tu.x * side)
        let k = abs(curl)
        let t1 = CGPoint(x: tp.x + tn.x * k * 1.4 + tu.x * k * 0.6, y: tp.y + tn.y * k * 1.4 + tu.y * k * 0.6)
        var tendril = Path()
        tendril.move(to: tp)
        tendril.addQuadCurve(to: t1, control: CGPoint(x: tp.x + tn.x * k * 0.2 + tu.x * k * 1.2, y: tp.y + tn.y * k * 0.2 + tu.y * k * 1.2))
        tendril.addPath(Scene.whiplashCurl(at: t1, dir: CGPoint(x: -tu.x, y: -tu.y), normal: CGPoint(x: -tn.x, y: -tn.y), size: k * 0.8))
        w.lead(tendril, 2.2)
        var path = Path()
        path.addLines(spine)
        w.lead(path, 3.4)
        // tulip: three petals opening along the stem's direction
        let u = frame(1).u
        let un = CGPoint(x: -u.y, y: u.x)
        let head = k * 2.4
        func petal(_ ang: CGFloat, _ l: CGFloat, _ g: Glass) {
            let dir = CGPoint(x: u.x * cos(ang) + un.x * sin(ang), y: u.y * cos(ang) + un.y * sin(ang))
            Scene.leaf(&w, from: top, to: CGPoint(x: top.x + dir.x * l, y: top.y + dir.y * l), width: l * 0.4, glass: g, vein: false)
        }
        petal(-0.45, head * 0.9, .ruby)
        petal(0.45, head * 0.9, .ruby)
        petal(0, head * 1.05, bud)
    }

    /// A whiplash cloud: a tapering ribbon of pale glass along a curve, ending in a leaded curl.
    static func ribbon(_ w: inout Window, through pts: [CGPoint], width: CGFloat, glass: Glass, curl: CGFloat, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        let line = sampleSpline(pts, perSegment: 10)
        guard line.count > 3 else { return }
        var left: [CGPoint] = [], right: [CGPoint] = []
        for (i, p) in line.enumerated() {
            let a = line[max(i - 1, 0)], b = line[min(i + 1, line.count - 1)]
            let tl = max(hypot(b.x - a.x, b.y - a.y), 0.001)
            let n = CGPoint(x: -(b.y - a.y) / tl, y: (b.x - a.x) / tl)
            let t = CGFloat(i) / CGFloat(line.count - 1)
            let half = width * 0.5 * pow(sin(.pi * min(1, t * 1.15)), 0.7)
            left.append(CGPoint(x: p.x + n.x * half, y: p.y + n.y * half))
            right.append(CGPoint(x: p.x - n.x * half, y: p.y - n.y * half))
        }
        let poly = left + right.reversed()
        let b = Geo.poly(poly).boundingRect
        var p = Pane(path: Geo.poly(poly), glass: glass, light: CGPoint(x: b.midX + rng.range(-8...8), y: b.midY))
        p.reach = 1.3
        p.rim = 0.35
        p.texture = .streaky
        p.texAngle = Double(rng.range(-20...20))
        p.bloom = 0.2
        p.lead = 2.2
        p.corners = [line[0]]
        w.add(p)
        let e = line[line.count - 1], q = line[line.count - 3]
        let ul = max(hypot(e.x - q.x, e.y - q.y), 0.001)
        let u = CGPoint(x: (e.x - q.x) / ul, y: (e.y - q.y) / ul)
        w.lead(whiplashCurl(at: e, dir: u, normal: CGPoint(x: -u.y, y: u.x), size: curl), 2.2)
    }

    static func whiplashCurl(at b: CGPoint, dir u: CGPoint, normal n: CGPoint, size curl: CGFloat) -> Path {
        var p = Path()
        p.move(to: b)
        let tip = CGPoint(x: b.x - n.x * curl * 1.1 + u.x * curl * 0.4, y: b.y - n.y * curl * 1.1 + u.y * curl * 0.4)
        p.addQuadCurve(to: tip, control: CGPoint(x: b.x - n.x * curl * 0.2 + u.x * curl, y: b.y - n.y * curl * 0.2 + u.y * curl))
        let end = CGPoint(x: b.x - n.x * curl * 0.6 - u.x * curl * 0.1, y: b.y - n.y * curl * 0.6 - u.y * curl * 0.1)
        p.addQuadCurve(to: end, control: CGPoint(x: tip.x - u.x * curl * 0.9, y: tip.y - u.y * curl * 0.9))
        return p
    }

    /// A leaf pane: a pointed oval between two points (width signed for which way it bellies).
    static func leaf(_ w: inout Window, from a: CGPoint, to b: CGPoint, width: CGFloat, glass: Glass, vein: Bool = true) {
        let d = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let len = max(hypot(d.x, d.y), 1)
        let n = CGPoint(x: -d.y / len * width, y: d.x / len * width)
        let m = Geo.lerp(a, b, 0.45)
        var path = Path()
        path.move(to: a)
        path.addQuadCurve(to: b, control: CGPoint(x: m.x + n.x, y: m.y + n.y))
        path.addQuadCurve(to: a, control: CGPoint(x: m.x - n.x * 0.35, y: m.y - n.y * 0.35))
        path.closeSubpath()
        var p = Pane(path: path, glass: glass, light: Geo.lerp(a, b, 0.5))
        p.reach = 1.8
        p.rim = 0.45
        p.texture = .streaky
        p.texAngle = Double(atan2(d.y, d.x) * 180 / .pi)
        p.lead = 1.8
        p.bloom = glass.core == Glass.ruby.core || glass.core == Glass.amber.core ? 0.35 : 0
        w.add(p)
        if vein {
            var v = Path()
            v.move(to: Geo.lerp(a, b, 0.12))
            v.addQuadCurve(to: Geo.lerp(a, b, 0.85), control: CGPoint(x: m.x + n.x * 0.3, y: m.y + n.y * 0.3))
            w.paint(v, 0.6)
        }
    }

    // MARK: border

    /// A narrow band of jewel segments around the widget edge, like the border of a leaded light.
    static func border(_ w: inout Window, _ size: CGSize, width b: CGFloat, segment: CGFloat, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        let full = CGRect(origin: .zero, size: size)
        let outer = Path(roundedRect: full.insetBy(dx: -2, dy: -2), cornerRadius: Mock.cornerRadius + 2, style: .continuous)
        let inner = Path(roundedRect: full.insetBy(dx: b, dy: b), cornerRadius: Mock.cornerRadius - b, style: .continuous)
        let band = outer.subtracting(inner)
        let corner: CGFloat = Mock.cornerRadius + 4
        let ring: [Glass] = [.garnet, .amber, .ruby, .gold]
        func add(_ r: CGRect, _ g: Glass, _ corners: [CGPoint], bloom: Double = 0.12) {
            let piece = band.intersection(Path(r))
            var p = Pane(path: piece, glass: g, light: CGPoint(x: r.midX + rng.range(-4...4), y: r.midY + rng.range(-4...4)))
            p.reach = 0.8
            p.texture = .hammered
            p.texAngle = Double(rng.range(0...360))
            p.lead = 2.0
            p.bloom = bloom
            p.corners = corners
            p.rim = 0.7
            w.add(p)
        }
        for (cx, cy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
            let x = cx == 0 ? -4 : size.width - corner + 4
            let y = cy == 0 ? -4 : size.height - corner + 4
            add(CGRect(x: x, y: y, width: corner, height: corner), .violet, [], bloom: 0.1)
        }
        func run(_ length: CGFloat) -> [CGFloat] {
            let inner = length - 2 * (corner - 4)
            let n = max(1, Int((inner / segment).rounded()))
            return (0...n).map { (corner - 4) + inner * CGFloat($0) / CGFloat(n) }
        }
        let xs = run(size.width), ys = run(size.height)
        for i in 0..<(xs.count - 1) {
            let g = ring[(i + Int(rng.next() % 2)) % ring.count]
            add(CGRect(x: xs[i], y: -4, width: xs[i + 1] - xs[i], height: b + 4), g,
                [CGPoint(x: xs[i], y: b), CGPoint(x: xs[i + 1], y: b)])
            add(CGRect(x: xs[i], y: size.height - b, width: xs[i + 1] - xs[i], height: b + 4), ring[(i + 2) % ring.count],
                [CGPoint(x: xs[i], y: size.height - b), CGPoint(x: xs[i + 1], y: size.height - b)])
        }
        for i in 0..<(ys.count - 1) {
            add(CGRect(x: -4, y: ys[i], width: b + 4, height: ys[i + 1] - ys[i]), ring[(i + 1) % ring.count],
                [CGPoint(x: b, y: ys[i]), CGPoint(x: b, y: ys[i + 1])])
            add(CGRect(x: size.width - b, y: ys[i], width: b + 4, height: ys[i + 1] - ys[i]), ring[(i + 3) % ring.count],
                [CGPoint(x: size.width - b, y: ys[i]), CGPoint(x: size.width - b, y: ys[i + 1])])
        }
    }

    // MARK: pale panels and lancets

    /// A pale cathedral-glass panel cut into horizontal strips (one per row), with a heavier outer lead.
    static func panel(_ w: inout Window, _ rect: CGRect, rows: [CGFloat], glass: [Glass], radius: CGFloat = 9,
                      lead: CGFloat = 3.2, inlay: Bool = false, seed: UInt64 = 5) {
        var rng = SeededRandom(seed: seed)
        let outline = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        var y = rect.minY
        for (i, h) in rows.enumerated() {
            let r = CGRect(x: rect.minX - 2, y: y, width: rect.width + 4, height: i == rows.count - 1 ? rect.maxY - y + 2 : h)
            let piece = outline.intersection(Path(r))
            var p = Pane(path: piece, glass: glass[i % glass.count],
                         light: CGPoint(x: rect.minX + rect.width * rng.range(0.25...0.6), y: y + min(h, 60) * 0.4))
            p.reach = 0.75
            p.texture = .cathedral
            p.texAngle = Double(rng.range(-8...8)) + (i % 2 == 0 ? 0 : 180)
            p.texShift = CGPoint(x: rng.range(-90...90), y: rng.range(-90...90))
            p.texStrength = 0.55
            p.lead = 1.7
            p.rim = 0.55
            p.corners = i == 0 ? [] : [CGPoint(x: rect.minX, y: y), CGPoint(x: rect.maxX, y: y)]
            w.add(p, front: true)
            y += h
        }
        if inlay {
            // a painted double rule just inside the lead, with small corner knots
            let r1 = rect.insetBy(dx: 5.5, dy: 5.5), r2 = rect.insetBy(dx: 8, dy: 8)
            var rule = Path(roundedRect: r1, cornerRadius: max(radius - 5, 2), style: .continuous)
            rule.addPath(Path(roundedRect: r2, cornerRadius: max(radius - 7, 2), style: .continuous))
            for c in [CGPoint(x: r2.minX + 5, y: r2.minY + 5), CGPoint(x: r2.maxX - 5, y: r2.minY + 5),
                      CGPoint(x: r2.minX + 5, y: r2.maxY - 5), CGPoint(x: r2.maxX - 5, y: r2.maxY - 5)] {
                rule.addPath(Geo.circle(c, 1.6))
            }
            w.paint(rule, 0.6, front: true)
        }
        w.lead(outline, lead, front: true)
    }

    /// A ring of jewel segments framing a panel, with cobalt corner blocks each holding a cabochon.
    static func frame(_ w: inout Window, _ rect: CGRect, width b: CGFloat, radius: CGFloat, segment: CGFloat, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        let outerRect = rect.insetBy(dx: -b, dy: -b)
        let outer = Path(roundedRect: outerRect, cornerRadius: radius + b, style: .continuous)
        let inner = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        let band = outer.subtracting(inner)
        let ring: [Glass] = [.amber, .garnet, .gold, .ruby]
        let o = outerRect.insetBy(dx: -2, dy: -2)
        let cs = radius + b + 2
        func piece(_ r: CGRect, _ g: Glass, corners: [CGPoint]) {
            let path = band.intersection(Path(r))
            guard !path.isEmpty else { return }
            var p = Pane(path: path, glass: g, light: CGPoint(x: r.midX + rng.range(-3...3), y: r.midY + rng.range(-3...3)))
            p.reach = 0.9
            p.texture = .hammered
            p.texAngle = Double(rng.range(0...360))
            p.lead = 1.6
            p.bloom = 0.12
            p.rim = 0.6
            p.corners = corners
            w.add(p, front: true)
        }
        let innerW = o.width - 2 * cs, innerH = o.height - 2 * cs
        let tx = max(1, Int((innerW / segment).rounded())), ty = max(1, Int((innerH / segment).rounded()))
        for i in 0..<tx {
            let x = o.minX + cs + innerW * CGFloat(i) / CGFloat(tx)
            let r = CGRect(x: x, y: o.minY, width: innerW / CGFloat(tx), height: b + 2)
            piece(r, ring[i % ring.count], corners: [CGPoint(x: x, y: outerRect.minY), CGPoint(x: x, y: rect.minY)])
            let rb = r.offsetBy(dx: 0, dy: o.height - b - 2)
            piece(rb, ring[(i + 2) % ring.count], corners: [CGPoint(x: x, y: outerRect.maxY), CGPoint(x: x, y: rect.maxY)])
        }
        for j in 0..<ty {
            let y = o.minY + cs + innerH * CGFloat(j) / CGFloat(ty)
            let r = CGRect(x: o.minX, y: y, width: b + 2, height: innerH / CGFloat(ty))
            piece(r, ring[(j + 1) % ring.count], corners: [CGPoint(x: outerRect.minX, y: y), CGPoint(x: rect.minX, y: y)])
            let rr = r.offsetBy(dx: o.width - b - 2, dy: 0)
            piece(rr, ring[(j + 3) % ring.count], corners: [CGPoint(x: outerRect.maxX, y: y), CGPoint(x: rect.maxX, y: y)])
        }
        let corners = [(o.minX, o.minY), (o.maxX - cs, o.minY), (o.minX, o.maxY - cs), (o.maxX - cs, o.maxY - cs)]
        for (cx, cy) in corners {
            piece(CGRect(x: cx, y: cy, width: cs, height: cs), .cobalt, corners: [])
        }
        w.lead(outer, 2.4, front: true)
        // a cabochon in each corner block, on the band's centre line
        let k = (radius + b / 2) * (1 - 0.7071)
        for (x, y) in [(outerRect.minX + b / 2 + k, outerRect.minY + b / 2 + k), (outerRect.maxX - b / 2 - k, outerRect.minY + b / 2 + k),
                       (outerRect.minX + b / 2 + k, outerRect.maxY - b / 2 - k), (outerRect.maxX - b / 2 - k, outerRect.maxY - b / 2 - k)] {
            w.jewel(Jewel(center: CGPoint(x: x, y: y), radius: b * 0.42, glass: .sapphire, lead: 1.3, bloom: 0.3))
        }
    }

    /// An arched window light (a lancet with a rounded ogee head).
    static func arch(_ r: CGRect, head: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + head))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.minY + head * 0.05))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + head), control: CGPoint(x: r.maxX, y: r.minY + head * 0.05))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
