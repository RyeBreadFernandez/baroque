import SwiftUI

// The miniature set: a painted muslin backdrop, felt mountain ranges with wool snowcaps and stitched edges,
// a felt sun and clouds hung on rigging wire, felt rain or wool snow, model-railway bottle-brush pines,
// a summit weather mast, a weather balloon and a little cable car. Everything is drawn in Canvas.
// Ridge key points are fractions of the widget so each layout can place its ranges around its text.

struct EXRidge {
    var top: [CGPoint]              // unit points, left to right
    var color: UInt32
    var haze: Double = 0            // atmospheric layering: mix toward the backdrop's horizon
    var bottom: CGFloat = 1.05      // unit y the felt piece runs down to
    var snow: CGFloat = 0           // snowcap depth in points (0 = none)
    var snowLine: CGFloat = 1       // unit y: only peaks higher than this get a cap
    var stitch: Color? = nil        // running stitch along the top edge
    var capStitch: Color? = nil     // running stitch along the snowcap's lower edge
    var shade = true                // darker felt on the shadow face of each peak
    var lift: CGFloat = 2.2
    var fuzz: CGFloat = 1.2
    var seed: UInt64
}

enum EXScenery {
    // MARK: Backdrop

    /// The painted muslin sky, greyed for bad weather.
    static func sky(_ ctx: GraphicsContext, _ rect: CGRect, kit: EXKit, gloom: Double) {
        ctx.draw(kit.sky, in: rect)
        if gloom > 0 {
            var g = ctx
            g.blendMode = .color
            g.fill(Path(rect), with: .color(Color(hex: 0x8C9696).opacity(gloom * 1.4)))
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Color(hex: 0x5F6B70).opacity(gloom * 0.55), Color(hex: 0xB9B4A2).opacity(gloom * 0.3)]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        }
        // The backdrop is lit by the same warm key light, falling off to the right.
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [Color(hex: 0xFFE8B8).opacity(0.16), .clear, EX.shadow.opacity(0.08)]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
    }

    // MARK: Mountains

    static func unit(_ pts: [CGPoint], _ size: CGSize) -> [CGPoint] {
        pts.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }

    static func peaks(_ top: [CGPoint]) -> [Int] {
        guard top.count > 2 else { return [] }
        return (1..<(top.count - 1)).filter { top[$0].y < top[$0 - 1].y && top[$0].y < top[$0 + 1].y }
    }

    static func ridge(_ ctx: GraphicsContext, size: CGSize, _ r: EXRidge, kit: EXKit) {
        let top = unit(r.top, size)
        guard let first = top.first, let last = top.last else { return }
        let by = r.bottom * size.height
        var poly = top
        poly.append(CGPoint(x: last.x, y: by))
        poly.append(CGPoint(x: first.x, y: by))
        let path = EXGeo.roundedPolygon(poly, radius: 2.4)
        let base = EX.mix(r.color, EX.hHaze, r.haze)
        EXCraft.felt(ctx, path, edge: top, closed: false,
                     style: EXFeltStyle(color: base, lift: r.lift, fuzz: r.fuzz, nap: 0.78 - r.haze * 0.35,
                                        puff: 1 - r.haze * 0.5, fibres: 1 - r.haze * 0.6),
                     kit: kit, seed: r.seed)
        var inside = ctx
        inside.clip(to: path)
        let pk = peaks(top)
        if r.shade {
            let shadeColor = EX.mix(EX.mixHex(r.color, 0x161C2A, 0.30), EX.hHaze, r.haze * 0.85)
            for (n, k) in pk.enumerated() {
                let face = shadeFace(top, k, bottom: by + 4, seed: r.seed &+ UInt64(n * 13))
                EXCraft.felt(inside, EXGeo.roundedPolygon(face.poly, radius: 1.5), edge: face.fold, closed: false,
                             style: EXFeltStyle(color: shadeColor, lift: 0, fuzz: 0.9, nap: 0.7, puff: 0.5, fibres: 0.5),
                             kit: kit, seed: r.seed &+ UInt64(100 + n))
            }
        }
        if let st = r.stitch {
            EXCraft.stitches(inside, EXGeo.roundedPolyline(EXGeo.offset(top, by: 3.8), radius: 2), color: st.opacity(0.9))
        }
        if r.snow > 0 {
            for (n, k) in pk.enumerated() where top[k].y < r.snowLine * size.height {
                snowcap(ctx, top: top, peak: k, depth: r.snow, haze: r.haze, stitch: r.capStitch,
                        shade: r.shade ? shadeFace(top, k, bottom: by + 4, seed: r.seed &+ UInt64(n * 13)).poly : nil,
                        kit: kit, seed: r.seed &+ UInt64(200 + n))
            }
        }
    }

    /// The shadow face of a peak: from the summit along the right slope to the next valley, down to the base,
    /// and back up a slightly crooked fold line.
    static func shadeFace(_ top: [CGPoint], _ k: Int, bottom: CGFloat, seed: UInt64) -> (poly: [CGPoint], fold: [CGPoint]) {
        var v = k + 1
        while v < top.count - 1 && top[v + 1].y > top[v].y { v += 1 }
        v = min(v, top.count - 1)
        var r = SeededRandom(seed: seed)
        let p = top[k]
        let span = max(6, top[v].x - p.x)
        let foot = CGPoint(x: p.x + span * r.range(0.12...0.3), y: bottom)
        let m1 = CGPoint(x: p.x + span * r.range(0.04...0.12), y: p.y + (bottom - p.y) * 0.3)
        let m2 = CGPoint(x: p.x + span * r.range(0.0...0.2), y: p.y + (bottom - p.y) * 0.65)
        var poly = Array(top[k...v])
        poly.append(CGPoint(x: top[v].x, y: bottom))
        poly.append(foot)
        poly.append(m2)
        poly.append(m1)
        return (poly, [p, m1, m2, foot])
    }

    /// A wool snowcap over one peak, with drips along its lower edge.
    static func snowcap(_ ctx: GraphicsContext, top: [CGPoint], peak k: Int, depth: CGFloat, haze: Double,
                        stitch: Color?, shade: [CGPoint]?, kit: EXKit, seed: UInt64) {
        let pk = top[k]
        let sy = pk.y + depth
        var left: [CGPoint] = []
        var lp: CGPoint? = nil
        var i = k
        while i > 0 {
            let a = top[i], b = top[i - 1]
            if b.y >= sy { lp = a.exLerp(b, (sy - a.y) / (b.y - a.y)); break }
            left.insert(b, at: 0)
            i -= 1
        }
        var right: [CGPoint] = []
        var rp: CGPoint? = nil
        i = k
        while i < top.count - 1 {
            let a = top[i], b = top[i + 1]
            if b.y >= sy { rp = a.exLerp(b, (sy - a.y) / (b.y - a.y)); break }
            right.append(b)
            i += 1
        }
        guard let L = lp ?? left.first, let R = rp ?? right.last else { return }
        var upper = [L] + left + [pk] + right + [R]
        if lp == nil { upper.removeFirst() }
        if rp == nil { upper.removeLast() }
        var rng = SeededRandom(seed: seed)
        var lower: [CGPoint] = []
        let n = max(3, Int((R.x - L.x) / 4.2))
        for j in 1..<n {
            let x = R.x + (L.x - R.x) * CGFloat(j) / CGFloat(n)
            let drip: CGFloat = j % 2 == 1 ? rng.range(1.5...5.5) : rng.range(-1.2...0.8)
            lower.append(CGPoint(x: x + rng.range(-0.8...0.8), y: sy + drip))
        }
        let poly = upper + lower
        let path = EXGeo.roundedPolygon(poly, radius: 1.3)
        let wool = EX.mix(EX.hSnow, EX.hHaze, haze * 0.55)
        EXCraft.felt(ctx, path, edge: poly, closed: true,
                     style: EXFeltStyle(color: wool, lift: 1.0, fuzz: 1.7, nap: 0.42, puff: 0.9, fibres: 0.6, hairDensity: 1.3),
                     kit: kit, seed: seed)
        if let shade {
            var c = ctx
            c.clip(to: path)
            c.fill(EXGeo.roundedPolygon(shade, radius: 1.5), with: .color(Color(hex: 0x7F95AA).opacity(0.42)))
        }
        if let stitch {
            var c = ctx
            c.clip(to: path)
            let line = [R] + lower + [L]
            EXCraft.stitches(c, EXGeo.roundedPolyline(EXGeo.offset(line, by: 2.6), radius: 1.5), color: stitch,
                             width: 0.8, dash: [2.0, 1.6])
        }
    }

    // MARK: Sky props

    static func wire(_ ctx: GraphicsContext, from top: CGPoint, to p: CGPoint) {
        var w = Path()
        w.move(to: top)
        w.addLine(to: p)
        ctx.stroke(w, with: .color(EX.shadow.opacity(0.42)), lineWidth: 0.45)
        ctx.stroke(w.offsetBy(dx: -0.3, dy: 0), with: .color(.white.opacity(0.25)), lineWidth: 0.25)
    }

    /// A felt sun: a burnt-orange sunburst behind a goldenrod disc with a stitched ring, hung on a wire.
    static func sun(_ ctx: GraphicsContext, center c: CGPoint, radius r: CGFloat, kit: EXKit, seed: UInt64, wire hang: Bool = true) {
        if hang { wire(ctx, from: CGPoint(x: c.x, y: -2), to: CGPoint(x: c.x, y: c.y - r * 1.3)) }
        var star: [CGPoint] = []
        let rays = 14
        for i in 0..<(rays * 2) {
            let a = CGFloat(i) / CGFloat(rays * 2) * 2 * .pi - .pi / 2
            let rr = i % 2 == 0 ? r * 1.52 : r * 1.02
            star.append(CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr))
        }
        EXCraft.felt(ctx, EXGeo.roundedPolygon(star, radius: 1.4), edge: star, closed: true,
                     style: EXFeltStyle(color: EX.burnt, lift: 1.4, fuzz: 0.9, nap: 0.7), kit: kit, seed: seed)
        let disc = EXGeo.circlePoints(c, r)
        EXCraft.felt(ctx, Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), edge: disc, closed: true,
                     style: EXFeltStyle(color: EX.goldenrod, lift: 1.8, fuzz: 1.0, nap: 0.6), kit: kit, seed: seed &+ 1)
        let ir = r * 0.72
        EXCraft.stitches(ctx, Path(ellipseIn: CGRect(x: c.x - ir, y: c.y - ir, width: ir * 2, height: ir * 2)),
                         color: EX.tomato.opacity(0.85), width: 0.9, dash: [2.2, 1.7])
        // A soft warm bloom around the disc: the set's practical light.
        var bloom = ctx
        bloom.blendMode = .screen
        bloom.fill(Path(ellipseIn: CGRect(x: c.x - r * 3, y: c.y - r * 3, width: r * 6, height: r * 6)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE7A8).opacity(0.35), .clear]),
                                         center: c, startRadius: r, endRadius: r * 3))
    }

    /// Outline of a puffy cloud: the union of a few circles over a flat base, traced by rays from the centre.
    static func cloudOutline(center c: CGPoint, width w: CGFloat, seed: UInt64) -> [CGPoint] {
        var rng = SeededRandom(seed: seed)
        let h = w * 0.5
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-0.30, 0.10, 0.22), (-0.08, -0.12, 0.30), (0.20, -0.04, 0.25), (0.36, 0.12, 0.16)]
        let circles = puffs.map { p in (CGPoint(x: c.x + p.0 * w + rng.range(-1...1), y: c.y + p.1 * h * 1.2 + rng.range(-1...1)), p.2 * w) }
        let baseY = c.y + h * 0.36
        var out: [CGPoint] = []
        let n = 90
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let d = CGPoint(x: cos(a), y: sin(a))
            var best: CGFloat = 0
            for (cc, rr) in circles {
                let oc = c.exMinus(cc)
                let b = oc.x * d.x + oc.y * d.y
                let q = oc.x * oc.x + oc.y * oc.y - rr * rr
                let disc = b * b - q
                if disc >= 0 { best = max(best, -b + sqrt(disc)) }
            }
            var p = c.exPlus(d.exScaled(best))
            if p.y > baseY { p.y = baseY }
            if p.x < c.x - w * 0.52 { p.x = c.x - w * 0.52 }
            if p.x > c.x + w * 0.52 { p.x = c.x + w * 0.52 }
            out.append(p)
        }
        return out
    }

    static func cloud(_ ctx: GraphicsContext, center c: CGPoint, width w: CGFloat, grey: Bool, kit: EXKit, seed: UInt64, hang: Bool = true) {
        let pts = cloudOutline(center: c, width: w, seed: seed)
        if hang {
            let topY = pts.map(\.y).min() ?? c.y
            wire(ctx, from: CGPoint(x: c.x - w * 0.18, y: -2), to: CGPoint(x: c.x - w * 0.18, y: topY + 3))
            wire(ctx, from: CGPoint(x: c.x + w * 0.2, y: -2), to: CGPoint(x: c.x + w * 0.2, y: topY + 4))
        }
        let color = grey ? Color(hex: 0xB9BCB4) : Color(hex: 0xF4EAD2)
        EXCraft.felt(ctx, EXGeo.roundedPolygon(pts, radius: 1), edge: pts, closed: true,
                     style: EXFeltStyle(color: color, lift: 1.8, fuzz: 1.3, nap: 0.5), kit: kit, seed: seed)
        EXCraft.stitches(ctx, EXGeo.roundedPolygon(EXGeo.inset(pts, by: 2.8), radius: 1),
                         color: grey ? Color(hex: 0x5E6A72) : EX.tomato.opacity(0.75), width: 0.75, dash: [2.0, 1.6])
    }

    /// Felt raindrops hung on fishing line.
    static func rain(_ ctx: GraphicsContext, in rect: CGRect, count: Int, kit: EXKit, seed: UInt64) {
        var r = SeededRandom(seed: seed)
        for i in 0..<count {
            let p = CGPoint(x: r.range(rect.minX...rect.maxX), y: r.range(rect.minY...rect.maxY))
            let s = r.range(2.8...4.0)
            var line = Path()
            line.move(to: CGPoint(x: p.x, y: max(-2, p.y - r.range(14...40))))
            line.addLine(to: CGPoint(x: p.x, y: p.y - s * 1.6))
            ctx.stroke(line, with: .color(.white.opacity(0.35)), lineWidth: 0.35)
            var drop: [CGPoint] = [CGPoint(x: p.x, y: p.y - s * 1.9)]
            for k in 0...10 {
                let a = CGFloat(k) / 10 * .pi
                drop.append(CGPoint(x: p.x + cos(a) * s * 0.9, y: p.y + sin(a) * s * 0.9))
            }
            drop = [drop[0]] + drop[1...].reversed()
            EXCraft.felt(ctx, EXGeo.roundedPolygon(drop, radius: 0.6), edge: drop, closed: true,
                         style: EXFeltStyle(color: i % 3 == 0 ? Color(hex: 0x7FA9BC) : Color(hex: 0x9CC2CF), lift: 1.0, fuzz: 0.6,
                                            nap: 0.4, puff: 0.6, fibres: 0),
                         kit: kit, seed: seed &+ UInt64(i))
        }
    }

    /// Wool snow: little pom-poms caught mid-fall.
    static func snowfall(_ ctx: GraphicsContext, in rect: CGRect, count: Int, kit: EXKit, seed: UInt64) {
        var r = SeededRandom(seed: seed)
        for i in 0..<count {
            let p = CGPoint(x: r.range(rect.minX...rect.maxX), y: r.range(rect.minY...rect.maxY))
            let s = r.range(2.0...3.4)
            let pts = EXGeo.circlePoints(p, s, step: 0.7)
            EXCraft.felt(ctx, Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s, width: s * 2, height: s * 2)), edge: pts, closed: true,
                         style: EXFeltStyle(color: EX.snow, lift: 1.2, fuzz: 1.1, nap: 0.3, puff: 0.8, fibres: 0, hairDensity: 1.4),
                         kit: kit, seed: seed &+ UInt64(i))
        }
    }

    /// Sun and clouds for a weather kind, hung behind the ranges. Without sun, a grey cloud takes its place.
    static func skyProps(_ ctx: GraphicsContext, _ w: EXWeather, sun: CGPoint, radius: CGFloat, clouds: [CGPoint],
                         cloudWidth: CGFloat, kit: EXKit, seed: UInt64) {
        if w.showsSun { EXScenery.sun(ctx, center: sun, radius: radius, kit: kit, seed: seed) }
        if !w.showsSun {
            cloud(ctx, center: CGPoint(x: sun.x, y: sun.y - radius * 0.2), width: max(cloudWidth * 1.25, radius * 3.2), grey: true,
                  kit: kit, seed: seed &+ 30)
        }
        let n = min(clouds.count, w.cloudCount)
        for i in 0..<n {
            cloud(ctx, center: clouds[i], width: cloudWidth * (i == 0 ? 1 : 0.8), grey: !w.showsSun, kit: kit, seed: seed &+ UInt64(10 + i))
        }
    }

    /// Felt rain or wool snow, hung in front of the ranges.
    static func precip(_ ctx: GraphicsContext, _ w: EXWeather, in rect: CGRect, count: Int, kit: EXKit, seed: UInt64) {
        if w.rains { rain(ctx, in: rect, count: count, kit: kit, seed: seed &+ 40) }
        if w.snows { snowfall(ctx, in: rect, count: count * 2, kit: kit, seed: seed &+ 50) }
    }

    // MARK: Trees

    /// A model-railway bottle-brush pine: bristles on a wire trunk, lit from the left.
    static func brushTree(_ ctx: GraphicsContext, base: CGPoint, height h: CGFloat, color: UInt32, seed: UInt64) {
        var r = SeededRandom(seed: seed)
        let w = h * 0.40
        var sh = ctx
        sh.addFilter(.blur(radius: 1.3))
        var tri = Path()
        tri.move(to: CGPoint(x: base.x - w * 0.42 + 1.6, y: base.y))
        tri.addLine(to: CGPoint(x: base.x + 2.4, y: base.y - h + 2.5))
        tri.addLine(to: CGPoint(x: base.x + w * 0.5 + 2.0, y: base.y))
        tri.closeSubpath()
        sh.fill(tri, with: .color(EX.shadow.opacity(0.32)))
        EXCraft.contact(ctx, CGRect(x: base.x - w * 0.45, y: base.y - 1.2, width: w * 0.95, height: 2.6), opacity: 0.45, blur: 0.9)
        ctx.fill(Path(CGRect(x: base.x - 0.65, y: base.y - h * 0.18, width: 1.3, height: h * 0.18)), with: .color(Color(hex: 0x4A2E1A)))
        let topY = base.y - h, botY = base.y - h * 0.13
        var light = Path(), mid = Path(), dark = Path()
        var y = topY
        while y < botY {
            let t = (y - topY) / (botY - topY)
            let half = 0.6 + w * 0.5 * t * r.range(0.85...1.12)
            for side in [-1.0, 1.0] as [CGFloat] {
                for _ in 0..<2 {
                    let len = half * r.range(0.5...1.05)
                    let droop = r.range(0.1...1.0) * (0.4 + t)
                    let s = CGPoint(x: base.x + side * 0.2, y: y + r.range(-0.3...0.3))
                    let e = CGPoint(x: base.x + side * len, y: y + droop)
                    let k = r.unit()
                    if side < 0 {
                        if k < 0.55 { light.move(to: s); light.addLine(to: e) } else { mid.move(to: s); mid.addLine(to: e) }
                    } else {
                        if k < 0.6 { dark.move(to: s); dark.addLine(to: e) } else { mid.move(to: s); mid.addLine(to: e) }
                    }
                }
            }
            y += 0.7
        }
        ctx.stroke(dark, with: .color(EX.mix(color, 0x0E1410, 0.42)), style: StrokeStyle(lineWidth: 0.75, lineCap: .round))
        ctx.stroke(mid, with: .color(Color(hex: color)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        ctx.stroke(light, with: .color(EX.mix(color, 0xC9C27A, 0.32)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
    }

    /// Trees planted along a ground polyline (unit points), skipping any unit x ranges given.
    static func forest(_ ctx: GraphicsContext, size: CGSize, ground: [CGPoint], xs: ClosedRange<CGFloat>, count: Int,
                       heights: ClosedRange<CGFloat>, color: UInt32, seed: UInt64, skip: [ClosedRange<CGFloat>] = []) {
        var r = SeededRandom(seed: seed)
        let g = unit(ground, size)
        func groundY(_ x: CGFloat) -> CGFloat {
            for i in 0..<(g.count - 1) where x >= g[i].x && x <= g[i + 1].x {
                let t = (x - g[i].x) / max(0.001, g[i + 1].x - g[i].x)
                return g[i].y + (g[i + 1].y - g[i].y) * t
            }
            return g.last?.y ?? size.height
        }
        var placed: [(CGFloat, CGFloat)] = []
        for i in 0..<count {
            let u = xs.lowerBound + (xs.upperBound - xs.lowerBound) * (CGFloat(i) + r.range(0.15...0.85)) / CGFloat(count)
            if skip.contains(where: { $0.contains(u) }) { continue }
            placed.append((u * size.width, r.range(heights)))
        }
        for (n, t) in placed.enumerated() {
            brushTree(ctx, base: CGPoint(x: t.0, y: groundY(t.0) + 1.5), height: t.1,
                      color: n % 3 == 1 ? EX.hOlive : (n % 3 == 2 ? 0x2B4A4C : EX.hPine), seed: seed &+ UInt64(n * 7))
        }
    }

    // MARK: Field-station props

    /// The summit station: a tiny hut, a mast with a striped windsock and an anemometer.
    /// `mirrored` swaps the sides (hut right, sock blowing left) where text sits to the right.
    static func mast(_ ctx: GraphicsContext, base b: CGPoint, height h: CGFloat, mirrored: Bool = false) {
        var ctx = ctx
        if mirrored {
            ctx.translateBy(x: b.x * 2, y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }
        EXCraft.contact(ctx, CGRect(x: b.x - 9, y: b.y - 1.5, width: 18, height: 3), opacity: 0.4, blur: 1)
        // Hut.
        let hut = CGRect(x: b.x - 7.5, y: b.y - 6.5, width: 9, height: 6.5)
        ctx.fill(Path(hut.offsetBy(dx: 0.8, dy: 0.8)), with: .color(EX.shadow.opacity(0.35)))
        ctx.fill(Path(hut), with: .color(EX.cream))
        ctx.fill(Path(CGRect(x: hut.maxX - 3, y: hut.minY, width: 3, height: hut.height)), with: .color(EX.shadow.opacity(0.18)))
        ctx.fill(Path(CGRect(x: hut.minX + 2, y: hut.minY + 2, width: 2.6, height: 2.4)), with: .color(EX.goldenrod))
        var roof = Path()
        roof.move(to: CGPoint(x: hut.minX - 1.2, y: hut.minY + 0.4))
        roof.addLine(to: CGPoint(x: hut.midX, y: hut.minY - 3.6))
        roof.addLine(to: CGPoint(x: hut.maxX + 1.2, y: hut.minY + 0.4))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(EX.tomato))
        ctx.stroke(roof, with: .color(EX.tomatoDeep), lineWidth: 0.4)
        // Mast.
        let px = b.x + 4
        var pole = Path()
        pole.move(to: CGPoint(x: px, y: b.y))
        pole.addLine(to: CGPoint(x: px, y: b.y - h))
        ctx.stroke(pole.offsetBy(dx: 0.8, dy: 0.6), with: .color(EX.shadow.opacity(0.3)), lineWidth: 1.2)
        ctx.stroke(pole, with: .color(Color(hex: 0x6B4426)), lineWidth: 1.1)
        ctx.stroke(pole.offsetBy(dx: -0.3, dy: 0), with: .color(.white.opacity(0.3)), lineWidth: 0.35)
        // Windsock, stripes alternating tomato and cream, tapering to the right.
        let sy = b.y - h * 0.72
        let segs = 4
        for i in 0..<segs {
            let x0 = px + 0.6 + CGFloat(i) * 3.2, x1 = x0 + 3.2
            let h0 = 3.6 - CGFloat(i) * 0.55, h1 = 3.6 - CGFloat(i + 1) * 0.55
            let droop0 = CGFloat(i) * 0.35, droop1 = CGFloat(i + 1) * 0.35
            var seg = Path()
            seg.move(to: CGPoint(x: x0, y: sy - h0 / 2 + droop0))
            seg.addLine(to: CGPoint(x: x1, y: sy - h1 / 2 + droop1))
            seg.addLine(to: CGPoint(x: x1, y: sy + h1 / 2 + droop1))
            seg.addLine(to: CGPoint(x: x0, y: sy + h0 / 2 + droop0))
            seg.closeSubpath()
            ctx.fill(seg, with: .color(i % 2 == 0 ? EX.tomato : EX.cream))
        }
        // Anemometer.
        let ay = b.y - h
        var bar = Path()
        bar.move(to: CGPoint(x: px - 4.5, y: ay))
        bar.addLine(to: CGPoint(x: px + 4.5, y: ay))
        ctx.stroke(bar, with: .color(EX.inkSoft), lineWidth: 0.6)
        for dx in [-4.5, 0, 4.5] as [CGFloat] {
            ctx.fill(Path(ellipseIn: CGRect(x: px + dx - 1.3, y: ay - 1.3 - (dx == 0 ? 1.2 : 0), width: 2.6, height: 2.2)), with: .color(EX.brass))
        }
    }

    /// A felt weather balloon with stitched gores, a string and a little instrument box. Returns the box centre.
    @discardableResult
    static func balloon(_ ctx: GraphicsContext, center c: CGPoint, radius r: CGFloat, string len: CGFloat, kit: EXKit, seed: UInt64) -> CGPoint {
        let box = CGPoint(x: c.x + 1.5, y: c.y + r + len)
        var s = Path()
        s.move(to: CGPoint(x: c.x, y: c.y + r * 1.05))
        s.addQuadCurve(to: CGPoint(x: box.x, y: box.y - 3), control: CGPoint(x: c.x + 3, y: c.y + r + len * 0.5))
        ctx.stroke(s.offsetBy(dx: 0.6, dy: 0.6), with: .color(EX.shadow.opacity(0.3)), lineWidth: 0.5)
        ctx.stroke(s, with: .color(EX.cream), lineWidth: 0.55)
        // Envelope: slightly pear-shaped.
        var pts: [CGPoint] = []
        for i in 0..<72 {
            let a = CGFloat(i) / 72 * 2 * .pi
            let squash: CGFloat = sin(a) > 0 ? 1 - 0.12 * sin(a) : 1
            pts.append(CGPoint(x: c.x + cos(a) * r * squash, y: c.y + sin(a) * r * 1.06))
        }
        EXCraft.felt(ctx, EXGeo.roundedPolygon(pts, radius: 0.5), edge: pts, closed: true,
                     style: EXFeltStyle(color: EX.tomato, lift: 2.2, fuzz: 1.0, nap: 0.6), kit: kit, seed: seed)
        var inside = ctx
        inside.clip(to: EXGeo.roundedPolygon(pts, radius: 0.5))
        for k in [-0.5, 0.0, 0.5] as [CGFloat] {
            var g = Path()
            g.move(to: CGPoint(x: c.x, y: c.y - r * 1.06))
            g.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r * 1.06), control: CGPoint(x: c.x + k * r * 2.1, y: c.y))
            EXCraft.stitches(inside, g, color: EX.thread.opacity(0.85), width: 0.7, dash: [1.8, 1.5])
        }
        inside.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.62, y: c.y - r * 0.72, width: r * 0.6, height: r * 0.48)),
                    with: .radialGradient(Gradient(colors: [.white.opacity(0.35), .clear]),
                                          center: CGPoint(x: c.x - r * 0.32, y: c.y - r * 0.48), startRadius: 0, endRadius: r * 0.4))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 1.3, y: c.y + r * 1.02, width: 2.6, height: 2)), with: .color(EX.tomatoDeep))
        // Instrument box.
        let bx = CGRect(x: box.x - 3.6, y: box.y - 3, width: 7.2, height: 6)
        ctx.fill(Path(bx.offsetBy(dx: 0.9, dy: 1)), with: .color(EX.shadow.opacity(0.3)))
        ctx.fill(Path(roundedRect: bx, cornerRadius: 0.8), with: .color(EX.cream))
        ctx.fill(Path(CGRect(x: bx.maxX - 2.2, y: bx.minY, width: 2.2, height: bx.height)), with: .color(EX.shadow.opacity(0.15)))
        ctx.fill(Path(ellipseIn: CGRect(x: bx.minX + 1.2, y: bx.minY + 1.4, width: 3.2, height: 3.2)), with: .color(EX.prussian))
        return box
    }

    /// A cable car on a sagging cable between two points; `t` places the cabin along the span.
    static func cableCar(_ ctx: GraphicsContext, from a: CGPoint, to b: CGPoint, sag: CGFloat, at t: CGFloat, kit: EXKit) {
        let ctrl = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + sag * 2)
        func pt(_ u: CGFloat) -> CGPoint {
            let m = 1 - u
            return CGPoint(x: m * m * a.x + 2 * m * u * ctrl.x + u * u * b.x, y: m * m * a.y + 2 * m * u * ctrl.y + u * u * b.y)
        }
        for dy in [0, 2.2] as [CGFloat] {
            var cable = Path()
            cable.move(to: CGPoint(x: a.x, y: a.y + dy))
            cable.addQuadCurve(to: CGPoint(x: b.x, y: b.y + dy), control: CGPoint(x: ctrl.x, y: ctrl.y + dy))
            ctx.stroke(cable.offsetBy(dx: 0.8, dy: 1.6), with: .color(EX.shadow.opacity(0.18)), lineWidth: 0.6)
            ctx.stroke(cable, with: .color(EX.ink.opacity(0.75)), lineWidth: 0.55)
        }
        let p = pt(t)
        let q = pt(min(1, t + 0.02))
        let ang = atan2(q.y - p.y, q.x - p.x)
        // Carriage wheels on the cable.
        for dx in [-2.6, 2.6] as [CGFloat] {
            let w = CGPoint(x: p.x + cos(ang) * dx, y: p.y + sin(ang) * dx)
            ctx.fill(Path(ellipseIn: CGRect(x: w.x - 1.3, y: w.y - 0.6, width: 2.6, height: 2.6)), with: .color(EX.inkSoft))
        }
        // Hanger arm.
        let cabTop = CGPoint(x: p.x, y: p.y + 9)
        var arm = Path()
        arm.move(to: CGPoint(x: p.x, y: p.y + 1))
        arm.addLine(to: cabTop)
        ctx.stroke(arm, with: .color(EX.ink), lineWidth: 0.9)
        // Cabin: painted wood, tomato with a cream band, three windows.
        let cab = CGRect(x: cabTop.x - 11, y: cabTop.y + 1.6, width: 22, height: 15)
        var sh = ctx
        sh.addFilter(.blur(radius: 1.6))
        sh.fill(Path(roundedRect: cab.offsetBy(dx: 1.6, dy: 2.4), cornerRadius: 2.5), with: .color(EX.shadow.opacity(0.4)))
        ctx.fill(Path(roundedRect: CGRect(x: cab.minX + 2, y: cabTop.y, width: cab.width - 4, height: 2.6), cornerRadius: 1), with: .color(EX.cream))
        ctx.fill(Path(roundedRect: cab, cornerRadius: 2.5), with: .color(EX.tomato))
        ctx.fill(Path(CGRect(x: cab.minX, y: cab.minY + 9.6, width: cab.width, height: 2.2)), with: .color(EX.cream))
        for i in 0..<3 {
            let wr = CGRect(x: cab.minX + 2.6 + CGFloat(i) * 6, y: cab.minY + 2.4, width: 4.6, height: 5.6)
            ctx.fill(Path(roundedRect: wr, cornerRadius: 0.8), with: .color(Color(hex: 0x2B3F55)))
            ctx.fill(Path(CGRect(x: wr.minX + 0.6, y: wr.minY + 0.6, width: 1.1, height: 3)), with: .color(.white.opacity(0.45)))
        }
        ctx.fill(Path(roundedRect: cab, cornerRadius: 2.5), with: .linearGradient(
            Gradient(colors: [.white.opacity(0.22), .clear, EX.shadow.opacity(0.28)]),
            startPoint: CGPoint(x: cab.minX, y: cab.minY), endPoint: CGPoint(x: cab.maxX, y: cab.maxY)))
        ctx.stroke(Path(roundedRect: cab, cornerRadius: 2.5), with: .color(EX.tomatoDeep), lineWidth: 0.5)
    }

    /// A wooden pylon: an A-frame tower with a cross arm, standing on a peak.
    static func pylon(_ ctx: GraphicsContext, top t: CGPoint, height h: CGFloat) {
        var frame = Path()
        frame.move(to: CGPoint(x: t.x - h * 0.22, y: t.y + h))
        frame.addLine(to: CGPoint(x: t.x, y: t.y))
        frame.addLine(to: CGPoint(x: t.x + h * 0.22, y: t.y + h))
        frame.move(to: CGPoint(x: t.x - h * 0.13, y: t.y + h * 0.55))
        frame.addLine(to: CGPoint(x: t.x + h * 0.13, y: t.y + h * 0.55))
        frame.move(to: CGPoint(x: t.x - 4, y: t.y))
        frame.addLine(to: CGPoint(x: t.x + 4, y: t.y))
        ctx.stroke(frame.offsetBy(dx: 0.9, dy: 0.9), with: .color(EX.shadow.opacity(0.32)), lineWidth: 1.2)
        ctx.stroke(frame, with: .color(Color(hex: 0x6B4426)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
    }
}
