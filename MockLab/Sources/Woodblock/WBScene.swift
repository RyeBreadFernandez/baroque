import SwiftUI

// The printed landscape: a bokashi sky, ranges cut as separate colour blocks (back to front),
// snow left as embossed bare paper, sugi and pine silhouettes on the ridges, kasumi mist bands, weather.

struct TreeSpec {
    enum Kind { case sugi, matsu }
    var from: CGFloat
    var to: CGFloat
    var spacing: ClosedRange<CGFloat> = 3.2...6
    var height: ClosedRange<CGFloat> = 6...11
    var color: Color = WB.pine
    var kind: Kind = .sugi
}

struct RidgeSpec {
    var keys: [CGPoint]                 // points, left to right; run past the edges to bleed
    var top: Color
    var bottom: Color
    var gradFrom: CGFloat? = nil         // y where the bokashi starts (default: highest key)
    var gradTo: CGFloat? = nil           // y where it ends (default: bottom of the scene)
    var rough: CGFloat = 0.07
    var seed: UInt64
    var snow: CGFloat? = nil             // snowline y
    var trees: [TreeSpec] = []
    var keyline: CGFloat = 0.9
    var grain: Int = 0
    var misreg: CGSize = CGSize(width: 0.6, height: -0.4)
    var gullies: Int = 0
    var gullyColor: Color = WB.indigoDeep
}

/// Suyari-gasumi: long bands of mist that run off one edge (or both) in staggered, overlapping tiers.
/// Each tier is printed dense along its top edge and graded (bokashi) to nothing below, so the scene shows through.
struct MistSpec {
    enum Edge { case left, right, both }
    var edge: Edge
    var y: CGFloat                       // top of the upper tier
    var length: CGFloat                  // how far the upper tier reaches in from its edge
    var height: CGFloat                  // thickness of one tier
    var tiers: [CGFloat] = [1, 0.7, 0.86] // relative lengths, top to bottom
    var drop: CGFloat = 0.6              // vertical step between tiers, as a fraction of the height
    var solid: CGFloat = 0.26            // share of each tier kept dense before the bokashi fades it out
    var after: Int                       // drawn after ridge index (-1: in the sky)
    var tint: Color = WB.blush
    var opacity: Double = 0.92
}

struct CloudSpec {
    var center: CGPoint
    var width: CGFloat
    var height: CGFloat
    var seed: UInt64
}

struct PineSpec {
    var base: CGPoint
    var height: CGFloat
    var lean: CGFloat = 1
    var seed: UInt64
}

struct SceneSpec {
    var sky: [Gradient.Stop]
    var skyFrom: CGFloat = 0
    var skyTo: CGFloat
    var ridges: [RidgeSpec]
    var mists: [MistSpec] = []
    var sun: CGPoint? = nil
    var sunR: CGFloat = 14
    var moon: CGPoint? = nil
    var moonR: CGFloat = 18
    var clouds: [CloudSpec] = []
    var birds: [CGPoint] = []
    var pines: [PineSpec] = []
    var pinesAfter: Int = 0
    var weather: WBSky = .fewClouds
    var precip: CGRect? = nil
    var water: CGFloat? = nil
    var waterAfter: Int = 0
}

struct PrintScene: View {
    var spec: SceneSpec
    var body: some View {
        Canvas { ctx, size in
            SceneDrawer(spec: spec, size: size, ink: InkSet(ctx)).draw(ctx)
        }
    }
}

struct SceneDrawer {
    var spec: SceneSpec
    var size: CGSize
    var ink: InkSet

    func draw(_ ctx: GraphicsContext) {
        sky(ctx)
        if spec.weather == .night { stars(ctx) }
        if let m = spec.moon { moon(ctx, m, r: spec.moonR) }
        if spec.moon == nil, spec.weather == .night, let s = spec.sun { moon(ctx, s, r: spec.sunR * 0.9) }
        if let s = spec.sun, spec.weather.showsSun { sun(ctx, s) }
        for c in spec.clouds { cloud(ctx, c) }
        birds(ctx)
        for m in spec.mists where m.after < 0 { mist(ctx, m) }
        for (i, r) in spec.ridges.enumerated() {
            ridge(ctx, r)
            if i == spec.pinesAfter { for p in spec.pines { matsu(ctx, p) } }
            if let w = spec.water, spec.waterAfter == i { water(ctx, top: w) }
            for m in spec.mists where m.after == i { mist(ctx, m) }
        }
        precipitation(ctx)
        ctx.fiberVeil(size, ink: ink, opacity: 0.45)
    }

    // MARK: sky

    func sky(_ ctx: GraphicsContext) {
        let rect = Path(CGRect(origin: .zero, size: size).insetBy(dx: -2, dy: -2))
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(stops: spec.sky),
            startPoint: CGPoint(x: 0, y: spec.skyFrom), endPoint: CGPoint(x: 0, y: spec.skyTo))
        ctx.printBlock(rect, shading, ink: ink, grain: 1, strength: 0.7, size: size)
        // the wiped edge of the top band: a slightly darker streak where the printer stopped the bokashi
        var streak = Path()
        streak.addRect(CGRect(x: -2, y: 0, width: size.width + 4, height: spec.skyTo * 0.16))
        ctx.printBlock(streak, .linearGradient(Gradient(colors: [WB.indigoDeep.opacity(0.55), WB.indigoDeep.opacity(0)]),
                                                startPoint: .zero, endPoint: CGPoint(x: 0, y: spec.skyTo * 0.16)),
                       ink: ink, grain: 0, strength: 0.5, grainShift: CGPoint(x: 7, y: 3), size: size)
    }

    func sun(_ ctx: GraphicsContext, _ c: CGPoint) {
        let r = spec.sunR
        let halo = Path(ellipseIn: CGRect(x: c.x - r * 2.2, y: c.y - r * 2.2, width: r * 4.4, height: r * 4.4))
        ctx.fill(halo, with: .radialGradient(Gradient(colors: [WB.ochrePale.opacity(0.38), WB.ochrePale.opacity(0)]),
                                             center: c, startRadius: r * 0.8, endRadius: r * 2.2))
        let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.printBlock(disc, .radialGradient(Gradient(colors: [WB.vermilion, WB.vermilionDeep]),
                                             center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.3), startRadius: 0, endRadius: r * 1.3),
                       ink: ink, grain: 0, strength: 0.75, grainShift: CGPoint(x: 11, y: 5),
                       misreg: CGSize(width: 0.5, height: 0.3), size: size)
    }

    func stars(_ ctx: GraphicsContext) {
        var rng = SeededRandom(seed: 404)
        var dots = Path()
        for _ in 0..<Int(size.width * spec.skyTo / 900) {
            let x = rng.range(0...size.width), y = rng.range(0...(spec.skyTo * 0.55))
            let r = rng.range(0.4...1.1)
            dots.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        ctx.fill(dots, with: .color(WB.ochrePale.opacity(0.8)))
    }

    func moon(_ ctx: GraphicsContext, _ c: CGPoint, r: CGFloat) {
        let halo = Path(ellipseIn: CGRect(x: c.x - r * 2.4, y: c.y - r * 2.4, width: r * 4.8, height: r * 4.8))
        ctx.fill(halo, with: .radialGradient(Gradient(colors: [WB.washi.opacity(0.5), WB.washi.opacity(0)]),
                                             center: c, startRadius: r, endRadius: r * 2.4))
        let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.printBlock(disc, .radialGradient(Gradient(colors: [Color(hex: 0xF6E7B8), WB.ochrePale]),
                                             center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.3), startRadius: 0, endRadius: r * 1.4),
                       ink: ink, grain: 1, strength: 0.6, grainShift: CGPoint(x: 3, y: 9), size: size)
        ctx.keyline(disc, width: 0.6, opacity: 0.5, seed: 2)
    }

    // MARK: ranges

    func ridge(_ ctx: GraphicsContext, _ r: RidgeSpec) {
        let pts = Geo.ridge(r.keys, rough: r.rough, seed: r.seed)
        let path = Geo.fill(pts, base: size.height + 4)
        let topY = r.gradFrom ?? (r.keys.map(\.y).min() ?? 0)
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [r.top, r.bottom]),
            startPoint: CGPoint(x: 0, y: topY), endPoint: CGPoint(x: 0, y: r.gradTo ?? size.height))
        let shift = CGPoint(x: CGFloat(r.seed % 17), y: CGFloat(r.seed % 11))
        ctx.printBlock(path, shading, ink: ink, grain: r.grain, strength: 0.75, grainShift: shift, misreg: r.misreg, size: size)
        if let s = r.snow { snow(ctx, pts: pts, snowline: s, seed: r.seed, clip: path) }
        if r.gullies > 0 { relief(ctx, r, clip: path) }
        for t in r.trees { trees(ctx, t, pts: pts, seed: r.seed &+ 3) }
        if r.keyline > 0 { ctx.keyline(Geo.line(pts), width: r.keyline, opacity: 0.85, seed: Int(r.seed % 3)) }
    }

    /// Volume for a range: the shadow flank of each peak in a darker bokashi, and ridge lines cut down both flanks.
    func relief(_ ctx: GraphicsContext, _ r: RidgeSpec, clip: Path) {
        var rng = SeededRandom(seed: r.seed &+ 9)
        let keys = r.keys
        var c = ctx
        c.clip(to: clip)
        var lines = Path()
        for i in 1..<(keys.count - 1) where keys[i].y < keys[i - 1].y && keys[i].y < keys[i + 1].y {
            let p = keys[i], left = keys[i - 1]
            // the shadow flank runs down to the first key well below the summit
            let right = keys[(i + 1)...].first { $0.y >= p.y + 22 } ?? keys[keys.count - 1]
            let major = keys[(i + 1)...].prefix { $0.y > p.y }.count > 0 && keys[..<i].last.map { $0.y - p.y > 9 } == true
                && keys[(i + 1)...].first.map { $0.y - p.y > 9 } == true
            var shade = Path()
            shade.move(to: CGPoint(x: p.x - 1, y: p.y - 24))
            shade.addLine(to: CGPoint(x: right.x + 2, y: right.y - 24))
            shade.addLine(to: CGPoint(x: right.x + 2, y: right.y + 3))
            shade.addLine(to: CGPoint(x: p.x + (right.x - p.x) * 0.55, y: p.y + 120))
            shade.addLine(to: CGPoint(x: p.x + (right.x - p.x) * 0.08, y: p.y + 120))
            shade.closeSubpath()
            if major { c.fill(shade, with: .linearGradient(Gradient(colors: [r.gullyColor.opacity(0.34), r.gullyColor.opacity(0)]),
                                                startPoint: CGPoint(x: 0, y: p.y), endPoint: CGPoint(x: 0, y: p.y + 70))) }
            for (nb, side) in [(left, CGFloat(-1)), (keys[i + 1], CGFloat(1))] {
                for k in 0..<max(1, r.gullies / 2) {
                    let t = 0.12 + CGFloat(k) * 0.22
                    let s = CGPoint(x: p.x + (nb.x - p.x) * t, y: p.y + (nb.y - p.y) * t + 2.5)
                    let len = rng.range(14...30) * (1 - t * 0.5)
                    let e = CGPoint(x: s.x + side * len * 0.25, y: s.y + len)
                    lines.move(to: s)
                    lines.addQuadCurve(to: e, control: CGPoint(x: s.x + side * len * 0.03, y: s.y + len * 0.55))
                }
            }
        }
        c.stroke(lines, with: .color(r.gullyColor.opacity(0.4)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
    }

    func snow(_ ctx: GraphicsContext, pts: [CGPoint], snowline: CGFloat, seed: UInt64, clip: Path) {
        let cap = Geo.snow(pts, snowline: snowline, seed: seed &+ 1)
        var c = ctx
        c.clip(to: clip)
        c.paper(cap, ink: ink, size: size, shift: CGPoint(x: 5, y: 2))
        // shadowed face: a faint blue bokashi on the lower part of the cap
        c.fill(cap, with: .linearGradient(Gradient(colors: [WB.prussianPale.opacity(0), WB.prussianPale.opacity(0.5)]),
                                          startPoint: CGPoint(x: 0, y: snowline - 26), endPoint: CGPoint(x: 0, y: snowline + 6)))
        // karazuri: blind embossing raises the snow, catching light on one edge and shade on the other
        var hi = c
        hi.translateBy(x: -0.5, y: -0.5)
        hi.stroke(cap, with: .color(.white.opacity(0.55)), lineWidth: 0.6)
        var lo = c
        lo.translateBy(x: 0.5, y: 0.6)
        lo.stroke(cap, with: .color(WB.indigoDeep.opacity(0.28)), lineWidth: 0.6)
    }

    func trees(_ ctx: GraphicsContext, _ t: TreeSpec, pts: [CGPoint], seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        var path = Path()
        var x = t.from
        while x < t.to {
            let h = rng.range(t.height)
            let y = Geo.y(at: x, in: pts) + rng.range(0.5...2.0)
            path.addPath(sugi(at: CGPoint(x: x, y: y), h: h))
            x += rng.range(t.spacing)
        }
        ctx.printBlock(path, .color(t.color), ink: ink, grain: 0, strength: 0.5, grainShift: CGPoint(x: 4, y: 4),
                       misreg: CGSize(width: -0.3, height: 0.2), size: size)
    }

    /// A cryptomeria silhouette: stacked, slightly ragged tiers on a short trunk.
    func sugi(at b: CGPoint, h: CGFloat) -> Path {
        let w = h * 0.46
        var p = Path()
        p.move(to: CGPoint(x: b.x, y: b.y - h))
        let tiers: [(CGFloat, CGFloat)] = [(0.30, 0.22), (0.36, 0.30), (0.58, 0.40), (0.62, 0.36), (0.86, 0.50), (0.9, 0.06)]
        for (fy, fx) in tiers { p.addLine(to: CGPoint(x: b.x + w * fx, y: b.y - h + h * fy)) }
        p.addLine(to: CGPoint(x: b.x + w * 0.06, y: b.y + 1.5))
        p.addLine(to: CGPoint(x: b.x - w * 0.06, y: b.y + 1.5))
        for (fy, fx) in tiers.reversed() { p.addLine(to: CGPoint(x: b.x - w * fx, y: b.y - h + h * fy)) }
        p.closeSubpath()
        return p
    }

    /// A flat-topped pine: a leaning trunk and cloud-like pads of needles, each pad outlined in sumi.
    func matsu(_ ctx: GraphicsContext, _ s: PineSpec) {
        var rng = SeededRandom(seed: s.seed)
        let b = s.base, h = s.height, lean = s.lean
        var trunk = Path()
        trunk.move(to: b)
        let top = CGPoint(x: b.x + h * 0.35 * lean, y: b.y - h)
        trunk.addCurve(to: top, control1: CGPoint(x: b.x - h * 0.15 * lean, y: b.y - h * 0.4),
                       control2: CGPoint(x: b.x + h * 0.45 * lean, y: b.y - h * 0.6))
        ctx.stroke(trunk, with: .color(WB.lacquer), style: StrokeStyle(lineWidth: max(1.2, h * 0.07), lineCap: .round))
        var pads = Path()
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.35, 1.0, 0.55), (-0.1, 0.72, 0.42), (0.62, 0.62, 0.38), (0.12, 0.45, 0.30)]
        for (fx, fy, fw) in spots {
            let cx = b.x + h * fx * lean, cy = b.y - h * fy
            let w = h * fw * rng.range(0.9...1.1)
            pads.addEllipse(in: CGRect(x: cx - w / 2, y: cy - w * 0.13, width: w, height: w * 0.26))
            pads.addEllipse(in: CGRect(x: cx - w * 0.36, y: cy - w * 0.25, width: w * 0.4, height: w * 0.24))
            pads.addEllipse(in: CGRect(x: cx - w * 0.02, y: cy - w * 0.22, width: w * 0.36, height: w * 0.2))
            var branch = Path()
            branch.move(to: CGPoint(x: b.x + h * 0.2 * lean, y: cy + 1))
            branch.addLine(to: CGPoint(x: cx, y: cy + 1))
            ctx.stroke(branch, with: .color(WB.lacquer), lineWidth: max(0.7, h * 0.03))
        }
        ctx.keyline(pads, width: 1.8, opacity: 0.9, seed: 1)
        ctx.printBlock(pads, .color(WB.pine), ink: ink, grain: 0, strength: 0.6, misreg: CGSize(width: 0.5, height: -0.3), size: size)
        var needles = Path()
        for (fx, fy, fw) in spots {
            let cx = b.x + h * fx * lean, cy = b.y - h * fy, w = h * fw
            for k in 0..<5 {
                let x = cx - w * 0.36 + CGFloat(k) * w * 0.18
                needles.move(to: CGPoint(x: x, y: cy - w * 0.06))
                needles.addLine(to: CGPoint(x: x + w * 0.05, y: cy + w * 0.08))
            }
        }
        ctx.stroke(needles, with: .color(WB.celadon.opacity(0.45)), lineWidth: 0.5)
    }

    // MARK: mist, cloud, birds, weather

    func mist(_ ctx: GraphicsContext, _ m: MistSpec) {
        for (k, f) in m.tiers.enumerated() {
            let h = m.height * (1 - CGFloat(k) * 0.08)
            let top = m.y + CGFloat(k) * m.height * m.drop
            let len = m.length * f
            let rect: CGRect
            switch m.edge {
            case .left: rect = CGRect(x: -40, y: top, width: len + 40, height: h)
            case .right: rect = CGRect(x: size.width - len, y: top, width: len + 40, height: h)
            case .both: rect = CGRect(x: -40, y: top, width: size.width + 80, height: h)
            }
            mistTier(ctx, m, rect: rect, seed: k)
        }
    }

    /// One tier: washi-white ink with the block's grain, tint wiped onto the top edge, graded out toward the bottom.
    func mistTier(_ ctx: GraphicsContext, _ m: MistSpec, rect r: CGRect, seed: Int) {
        let shape = Path(roundedRect: r, cornerRadius: r.height * 0.5, style: .continuous)
        let fadeFrom = r.minY + r.height * m.solid
        ctx.drawLayer { l in
            l.opacity = m.opacity
            l.paper(shape, ink: ink, size: size, shift: CGPoint(x: CGFloat(seed * 5), y: CGFloat(seed * 3 + 2)))
            var g = l
            g.clip(to: shape)
            g.blendMode = .softLight
            g.opacity = 0.55
            g.draw(ink.grain(seed + 1), in: grainRect(size, shift: CGPoint(x: CGFloat(seed * 11), y: r.minY.truncatingRemainder(dividingBy: 13))))
            l.fill(shape, with: .linearGradient(Gradient(colors: [m.tint.opacity(0.7), m.tint.opacity(0)]),
                                                startPoint: CGPoint(x: 0, y: r.minY),
                                                endPoint: CGPoint(x: 0, y: fadeFrom + r.height * 0.25)))
            // bokashi: the lower part of the tier is wiped away so the range behind shows through
            var cut = l
            cut.blendMode = .destinationOut
            cut.fill(Path(r.insetBy(dx: -2, dy: -2)),
                     with: .linearGradient(Gradient(stops: [.init(color: .clear, location: 0),
                                                            .init(color: .black.opacity(0.55), location: 0.5),
                                                            .init(color: .black, location: 1)]),
                                           startPoint: CGPoint(x: 0, y: fadeFrom), endPoint: CGPoint(x: 0, y: r.maxY)))
            // the inner end thins out too, as the printer's cloth ran out of ink
            let inner: (CGPoint, CGPoint)? = {
                switch m.edge {
                case .left: return (CGPoint(x: r.maxX - r.height * 2.5, y: 0), CGPoint(x: r.maxX, y: 0))
                case .right: return (CGPoint(x: r.minX + r.height * 2.5, y: 0), CGPoint(x: r.minX, y: 0))
                case .both: return nil
                }
            }()
            if let (a, b) = inner {
                cut.fill(Path(r.insetBy(dx: -2, dy: -2)),
                         with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.6)]), startPoint: a, endPoint: b))
            }
        }
    }

    /// Still water: a graded blue block with rows of small wave strokes that open up toward the viewer,
    /// and the moon or sun laid on it as a broken column of reflected light.
    func water(_ ctx: GraphicsContext, top: CGFloat) {
        let rect = CGRect(x: -2, y: top, width: size.width + 4, height: size.height - top + 4)
        ctx.printBlock(Path(rect), .linearGradient(Gradient(colors: [WB.prussianMid, WB.prussian, WB.indigo]),
                                                   startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)),
                       ink: ink, grain: 1, strength: 0.7, grainShift: CGPoint(x: 6, y: 14), size: size)
        var waves = Path()
        var y = top + 3
        var row = 0
        while y < size.height + 6 {
            let depth = y - top
            let spacing = 9 + depth * 0.35
            var x = (row % 2 == 0 ? 0 : spacing / 2) - spacing
            while x < size.width + spacing {
                waves.move(to: CGPoint(x: x, y: y))
                waves.addQuadCurve(to: CGPoint(x: x + spacing * 0.62, y: y), control: CGPoint(x: x + spacing * 0.31, y: y - spacing * 0.2))
                x += spacing
            }
            y += 3.2 + depth * 0.14
            row += 1
        }
        ctx.stroke(waves, with: .color(WB.washi.opacity(0.5)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        if let m = spec.moon ?? (spec.weather.showsSun ? spec.sun : nil) {
            var rng = SeededRandom(seed: 61)
            var gy = top + 3
            let reach = top + (size.height - top) * 0.62
            while gy < reach {
                let fall = (gy - top) / max(1, reach - top)
                let w = spec.moonR * 1.3 * (1 - fall * 0.7) * rng.range(0.3...1)
                let x = m.x - w / 2 + rng.range(-2.5...2.5)
                let glint = Path(roundedRect: CGRect(x: x, y: gy, width: w, height: rng.range(0.8...1.3)),
                                 cornerSize: CGSize(width: 0.6, height: 0.6))
                ctx.fill(glint, with: .color(WB.ochrePale.opacity(0.9 - fall * 0.6)))
                gy += rng.range(2.2...4.5) + fall * 3
            }
        }
        var shore = Path()
        shore.move(to: CGPoint(x: -2, y: top))
        shore.addLine(to: CGPoint(x: size.width + 2, y: top))
        ctx.keyline(shore, width: 0.8, opacity: 0.6, seed: 1)
    }

    /// A stylised band of cloud: a flat-bottomed strip with a shallow scalloped crown, outlined by the key block.
    func cloud(_ ctx: GraphicsContext, _ s: CloudSpec) {
        var rng = SeededRandom(seed: s.seed)
        var blob = Path()
        let n = max(3, Int(s.width / (s.height * 1.0)))
        for i in 0..<n {
            let t = CGFloat(i) / CGFloat(n - 1)
            let rr = s.height * rng.range(0.55...0.75) * (1 - abs(t - 0.5) * 0.5)
            let cx = s.center.x - s.width / 2 + s.width * t
            let cy = s.center.y - s.height * 0.05
            blob.addEllipse(in: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2))
        }
        blob.addRoundedRect(in: CGRect(x: s.center.x - s.width / 2 - s.height * 0.6, y: s.center.y - s.height * 0.1,
                                       width: s.width + s.height * 1.2, height: s.height * 0.6),
                            cornerSize: CGSize(width: s.height * 0.3, height: s.height * 0.3))
        var c = ctx
        c.clip(to: Path(CGRect(x: -10, y: -10, width: size.width + 20, height: s.center.y + s.height * 0.5 + 10)))
        c.keyline(blob, width: 1.7, opacity: 0.8, seed: Int(s.seed % 3))
        c.paper(blob, ink: ink, size: size, shift: CGPoint(x: 2, y: 8))
        c.fill(blob, with: .linearGradient(Gradient(colors: [WB.ochrePale.opacity(0), WB.ochrePale.opacity(0.6)]),
                                           startPoint: CGPoint(x: 0, y: s.center.y - s.height * 0.6),
                                           endPoint: CGPoint(x: 0, y: s.center.y + s.height * 0.5)))
        // inner curls: a short arc inside each scallop
        var curls = Path()
        for i in stride(from: 1, to: n - 1, by: 2) {
            let t = CGFloat(i) / CGFloat(n - 1)
            let cx = s.center.x - s.width / 2 + s.width * t
            curls.addArc(center: CGPoint(x: cx, y: s.center.y + s.height * 0.05), radius: s.height * 0.32,
                         startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        }
        c.stroke(curls, with: .color(WB.sumi.opacity(0.45)), lineWidth: 0.6)
    }

    func birds(_ ctx: GraphicsContext) {
        var p = Path()
        for b in spec.birds {
            p.move(to: CGPoint(x: b.x - 3.2, y: b.y + 0.4))
            p.addQuadCurve(to: CGPoint(x: b.x, y: b.y), control: CGPoint(x: b.x - 1.6, y: b.y - 2.2))
            p.addQuadCurve(to: CGPoint(x: b.x + 3.4, y: b.y + 0.2), control: CGPoint(x: b.x + 1.7, y: b.y - 2.4))
        }
        ctx.stroke(p, with: .color(WB.sumi.opacity(0.85)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
    }

    func precipitation(_ ctx: GraphicsContext) {
        guard let area = spec.precip else { return }
        var rng = SeededRandom(seed: 77)
        switch spec.weather {
        case .rain, .storm:
            var lines = Path()
            let n = Int(area.width * area.height / 180)
            for _ in 0..<n {
                let x = rng.range(area.minX...area.maxX), y = rng.range(area.minY...area.maxY)
                let len = rng.range(14...46)
                lines.move(to: CGPoint(x: x, y: y))
                lines.addLine(to: CGPoint(x: x - len * 0.18, y: y + len))
            }
            ctx.stroke(lines, with: .color(WB.indigoDeep.opacity(0.45)), lineWidth: 0.55)
        case .snow:
            var flakes = Path()
            let n = Int(area.width * area.height / 140)
            for _ in 0..<n {
                let x = rng.range(area.minX...area.maxX), y = rng.range(area.minY...area.maxY)
                let r = rng.range(0.7...1.7)
                flakes.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            ctx.keyline(flakes, width: 0.5, opacity: 0.35)
            ctx.paper(flakes, ink: ink, size: size)
        default:
            break
        }
    }
}
