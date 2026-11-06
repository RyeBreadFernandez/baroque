import SwiftUI

// The room: flocked ogee wallpaper hung in strips (the seams don't quite match), aged by a raster of stains
// and fading, then lit by pools of tungsten light that fall off into velvet dark. Smoke, door jambs, grain.

struct CHWallTone {
    var base: UInt32
    var lattice: UInt32
    var flock: UInt32
    var flockLit: UInt32
    var accent: UInt32

    static let crimson = CHWallTone(base: 0x4C0D12, lattice: 0x7A1D20, flock: 0x6C1419, flockLit: 0xA8352E, accent: 0xB0803E)
    static let jade = CHWallTone(base: 0x0E2C23, lattice: 0x1D4E3D, flock: 0x16473A, flockLit: 0x3E7C62, accent: 0xA8864A)
}

/// A pool of lamp light, in widget points.
struct CHPool {
    var center: CGPoint
    var radius: CGFloat
    var strength: Double = 1
    var squash: CGFloat = 1     // < 1 flattens the pool vertically
}

enum CHFlock {
    /// The wallpaper pattern: an ogee lattice with a six-petal medallion in each cell and gilt dots at the joins.
    static func pattern(_ ctx: GraphicsContext, in r: CGRect, tone: CHWallTone, cell: CGSize = CGSize(width: 40, height: 52), seed: UInt64) {
        ctx.fill(Path(r), with: .color(Color(hex: tone.base)))
        let stripW: CGFloat = 116
        var rng = CHRandom(seed)
        var x0 = r.minX - rng.range(10...40)
        var strip = 0
        while x0 < r.maxX {
            let sr = CGRect(x: x0, y: r.minY, width: stripW, height: r.height)
            var c = ctx
            c.clip(to: Path(sr))
            let dy = rng.range(-3...3)
            let tint = rng.range(-0.03...0.03)
            drawCells(c, in: sr.insetBy(dx: 0, dy: -cell.height), offset: CGPoint(x: -x0.truncatingRemainder(dividingBy: cell.width) * 0, y: dy),
                      tone: tone, cell: cell, phaseX: r.minX)
            if tint > 0 { c.fill(Path(sr), with: .color(.white.opacity(Double(tint)))) } else { c.fill(Path(sr), with: .color(.black.opacity(Double(-tint * 2)))) }
            // The seam: a dark gap and a lifted, lighter edge.
            if strip > 0 || x0 > r.minX {
                ctx.fill(Path(CGRect(x: x0 - 0.35, y: r.minY, width: 0.7, height: r.height)), with: .color(.black.opacity(0.45)))
                ctx.fill(Path(CGRect(x: x0 + 0.35, y: r.minY, width: 0.5, height: r.height)), with: .color(Color(hex: tone.flockLit, opacity: 0.22)))
            }
            x0 += stripW
            strip += 1
        }
    }

    private static func drawCells(_ c: GraphicsContext, in r: CGRect, offset: CGPoint, tone: CHWallTone, cell: CGSize, phaseX: CGFloat) {
        let W = cell.width, H = cell.height
        let k = H * 0.3
        var lattice = Path()
        var petals = Path()
        var rings = Path()
        var dots = Path()
        let cols = Int(r.width / W) + 3
        let rows = Int(r.height / (H / 2)) + 3
        let ox = phaseX - W + offset.x
        let oy = r.minY - H / 2 + offset.y
        for j in 0..<rows {
            for i in 0..<cols {
                let cx = ox + CGFloat(i) * W + (j % 2 == 1 ? W / 2 : 0)
                let cy = oy + CGFloat(j) * H / 2
                guard cx > r.minX - W, cx < r.maxX + W else { continue }
                let T = CGPoint(x: cx, y: cy - H / 2), R = CGPoint(x: cx + W / 2, y: cy)
                let B = CGPoint(x: cx, y: cy + H / 2), L = CGPoint(x: cx - W / 2, y: cy)
                lattice.move(to: T)
                lattice.addCurve(to: R, control1: CGPoint(x: T.x, y: T.y + k), control2: CGPoint(x: R.x, y: R.y - k))
                lattice.addCurve(to: B, control1: CGPoint(x: R.x, y: R.y + k), control2: CGPoint(x: B.x, y: B.y - k))
                // Medallion: six petals around a ring.
                let pr = min(W, H) * 0.27
                for p in 0..<6 {
                    let a = CGFloat(p) / 6 * 2 * .pi - .pi / 2
                    let dir = CGPoint(x: cos(a), y: sin(a))
                    let side = CGPoint(x: -dir.y, y: dir.x)
                    let base = CGPoint(x: cx + dir.x * pr * 0.3, y: cy + dir.y * pr * 0.3)
                    let tip = CGPoint(x: cx + dir.x * pr * 1.25, y: cy + dir.y * pr * 1.25)
                    petals.move(to: base)
                    petals.addQuadCurve(to: tip, control: CGPoint(x: cx + dir.x * pr * 0.85 + side.x * pr * 0.5, y: cy + dir.y * pr * 0.85 + side.y * pr * 0.5))
                    petals.addQuadCurve(to: base, control: CGPoint(x: cx + dir.x * pr * 0.85 - side.x * pr * 0.5, y: cy + dir.y * pr * 0.85 - side.y * pr * 0.5))
                    petals.closeSubpath()
                }
                rings.addEllipse(in: CGRect(x: cx - pr * 0.28, y: cy - pr * 0.28, width: pr * 0.56, height: pr * 0.56))
                // Small leaf sprigs up and down the tips of the lens.
                let lw = W * 0.07, lh = H * 0.11
                for s: CGFloat in [-1, 1] {
                    let ly = cy + s * H * 0.36
                    petals.addEllipse(in: CGRect(x: cx - lw, y: ly - lh / 2, width: lw * 2, height: lh))
                }
                dots.addEllipse(in: CGRect(x: L.x - 1.3, y: L.y - 1.3, width: 2.6, height: 2.6))
                dots.addEllipse(in: CGRect(x: cx - 0.9, y: cy - 0.9, width: 1.8, height: 1.8))
            }
        }
        // Flock: raised pile, so a soft shadow under it and a lit upper edge.
        var under = c
        under.addFilter(.blur(radius: 0.6))
        under.fill(petals.offsetBy(dx: 0.7, dy: 0.9), with: .color(.black.opacity(0.45)))
        c.fill(petals, with: .color(Color(hex: tone.flock)))
        var lit = c
        lit.clip(to: petals)
        lit.fill(petals.offsetBy(dx: 0.6, dy: 0.7), with: .color(Color(hex: tone.base, opacity: 0.0)))
        lit.stroke(petals.offsetBy(dx: -0.35, dy: -0.45), with: .color(Color(hex: tone.flockLit, opacity: 0.55)), lineWidth: 0.7)
        c.stroke(lattice.offsetBy(dx: 0.5, dy: 0.6), with: .color(.black.opacity(0.35)), lineWidth: 1.6)
        c.stroke(lattice, with: .color(Color(hex: tone.lattice)), lineWidth: 1.3)
        c.stroke(lattice.offsetBy(dx: -0.3, dy: -0.35), with: .color(Color(hex: tone.flockLit, opacity: 0.35)), lineWidth: 0.4)
        c.stroke(rings, with: .color(Color(hex: tone.accent, opacity: 0.55)), lineWidth: 0.6)
        c.fill(dots, with: .color(Color(hex: tone.accent, opacity: 0.7)))
    }

    /// Multiplies a light map over what is already drawn: an ambient dark with additive pools of tungsten.
    static func light(_ ctx: GraphicsContext, size: CGSize, pools: [CHPool], ambient: Color = Color(hex: 0x2A1A16), exclude: [CGRect] = []) {
        var m = ctx
        m.blendMode = .multiply
        m.drawLayer { layer in
            layer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ambient))
            defer { for e in exclude { var w = layer; w.blendMode = .normal; w.fill(Path(e), with: .color(.white)) } }
            layer.blendMode = .plusLighter
            for p in pools {
                var l = layer
                l.translateBy(x: p.center.x, y: p.center.y)
                l.scaleBy(x: 1, y: p.squash)
                let rr = p.radius
                l.fill(Path(ellipseIn: CGRect(x: -rr, y: -rr, width: rr * 2, height: rr * 2)),
                       with: .radialGradient(Gradient(stops: [
                        .init(color: Color(hex: 0xFFE6BE, opacity: p.strength), location: 0),
                        .init(color: Color(hex: 0xF0B878, opacity: p.strength * 0.75), location: 0.35),
                        .init(color: Color(hex: 0x8A4A2A, opacity: p.strength * 0.3), location: 0.7),
                        .init(color: .clear, location: 1)]), center: .zero, startRadius: 0, endRadius: rr))
            }
        }
        // Bloom: the brightest part of each pool glows a little.
        var bloom = ctx
        if !exclude.isEmpty {
            var outside = Path(CGRect(origin: .zero, size: size))
            for e in exclude { outside.addRect(e) }
            bloom.clip(to: outside, style: FillStyle(eoFill: true))
        }
        bloom.blendMode = .screen
        for p in pools {
            let rr = p.radius * 0.6
            bloom.fill(Path(ellipseIn: CGRect(x: p.center.x - rr, y: p.center.y - rr * p.squash, width: rr * 2, height: rr * 2 * p.squash)),
                       with: .radialGradient(Gradient(colors: [CH.amber.opacity(0.16 * p.strength), .clear]), center: p.center, startRadius: 0, endRadius: rr))
        }
    }
}

/// The wall behind everything: pattern, age, light.
struct CHWall: View {
    var family: Family
    var tone: CHWallTone = .crimson
    var pools: [CHPool]
    var ambient: Color = Color(hex: 0x2A1A16)
    var cell = CGSize(width: 40, height: 52)
    var seed: UInt64 = 1

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            CHFlock.pattern(ctx, in: r, tone: tone, cell: cell, seed: seed)
            ctx.draw(ctx.resolve(CH.texture("wall-\(family.rawValue)")), in: r)
            CHFlock.light(ctx, size: size, pools: pools, ambient: ambient)
        }
    }
}

enum CHSmoke {
    /// Cigarette smoke: a thin thread rising straight from the ember, then breaking into slow curls that widen
    /// and thin out toward the ceiling. Drawn in one layer, faded at both ends.
    static func draw(_ ctx: GraphicsContext, from origin: CGPoint, height: CGFloat, drift: CGFloat, seed: UInt64,
                     color: Color = Color(hex: 0xD8D2C8), opacity: Double = 0.5, k: CGFloat = 1) {
        let top = origin.y - height
        ctx.drawLayer { layer in
            var rng = CHRandom(seed)
            for s in 0..<3 {
                var pts: [CGPoint] = []
                let freq = rng.range(5.5...8.5)
                let phase = rng.range(0...(2 * .pi))
                let lean = CGFloat(s - 1) * 0.07 + rng.range(-0.03...0.03)
                let steps = 26
                let loopAt = s == 1 ? -1 : Int(rng.range(CGFloat(steps) * 0.45...CGFloat(steps) * 0.75))
                for i in 0...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    // Laminar at first, then turbulent: the sway grows quickly after a third of the way up.
                    let turb = max(0, t - 0.22)
                    let amp = (0.6 + 30 * turb * turb + 6 * turb) * k
                    let x = origin.x + (drift + lean) * height * t + sin(t * freq * .pi + phase) * amp
                        + CHGeo.wobble(t * 20, seed: seed &+ UInt64(s) &* 7, base: 0.5) * amp * 0.5
                    let y = origin.y - height * t
                    pts.append(CGPoint(x: x, y: y))
                    // A curl: now and then the strand rolls over into one wide, lazy loop.
                    if i == loopAt {
                        let r = height * (0.035 + 0.04 * t)
                        let dir: CGFloat = sin(t * freq * .pi + phase) > 0 ? 1 : -1
                        pts.append(CGPoint(x: x + dir * r * 0.9, y: y - r * 0.8))
                        pts.append(CGPoint(x: x + dir * r * 1.7, y: y - r * 0.1))
                        pts.append(CGPoint(x: x + dir * r * 1.0, y: y + r * 0.35))
                    }
                }
                let path = CHGeo.smooth(pts)
                var wide = layer
                wide.addFilter(.blur(radius: 4 * k))
                wide.stroke(path, with: .color(color.opacity(opacity * 0.18)), style: StrokeStyle(lineWidth: 7 * k, lineCap: .round, lineJoin: .round))
                var mid = layer
                mid.addFilter(.blur(radius: 1.4 * k))
                mid.stroke(path, with: .color(color.opacity(opacity * 0.35)), style: StrokeStyle(lineWidth: 2.2 * k, lineCap: .round, lineJoin: .round))
                var fine = layer
                fine.addFilter(.blur(radius: 0.5 * k))
                fine.stroke(path, with: .color(color.opacity(opacity * (s == 0 ? 0.8 : 0.45))), style: StrokeStyle(lineWidth: 0.7 * k, lineCap: .round, lineJoin: .round))
            }
            // Fade in from the ember and out toward the ceiling.
            layer.blendMode = .destinationIn
            let span = CGRect(x: origin.x - height, y: top - 20, width: height * 2, height: height + 30).offsetBy(dx: drift * height * 0.5, dy: 0)
            layer.fill(Path(span), with: .linearGradient(Gradient(stops: [
                .init(color: .clear, location: 0), .init(color: .white.opacity(0.7), location: 0.4),
                .init(color: .white, location: 0.8), .init(color: .white.opacity(0.3), location: 0.97), .init(color: .clear, location: 1)]),
                startPoint: CGPoint(x: origin.x, y: top - 20), endPoint: CGPoint(x: origin.x, y: origin.y + 10)))
        }
    }
}

/// A door jamb at one edge: we are standing in the dark hall looking in.
enum CHJamb {
    static func draw(_ ctx: GraphicsContext, size: CGSize, width w: CGFloat, left: Bool, lintel: CGFloat = 0) {
        let x = left ? 0 : size.width - w
        let r = CGRect(x: x, y: 0, width: w, height: size.height)
        var sh = ctx
        sh.addFilter(.blur(radius: 6))
        sh.fill(Path(r.insetBy(dx: left ? -10 : 0, dy: -10).offsetBy(dx: left ? 5 : -5, dy: 0)), with: .color(.black.opacity(0.75)))
        ctx.fill(Path(r), with: .linearGradient(Gradient(colors: [Color(hex: 0x050303), Color(hex: 0x140806)]),
                                                startPoint: CGPoint(x: left ? r.minX : r.maxX, y: 0), endPoint: CGPoint(x: left ? r.maxX : r.minX, y: 0)))
        // The casing's edge catches the room's light.
        let ex = left ? r.maxX - 0.8 : r.minX + 0.8
        ctx.fill(Path(CGRect(x: ex - 0.5, y: 0, width: 1, height: size.height)),
                 with: .linearGradient(Gradient(colors: [CH.tungsten.opacity(0.05), CH.tungsten.opacity(0.45), CH.tungsten.opacity(0.08)]),
                                       startPoint: CGPoint(x: ex, y: 0), endPoint: CGPoint(x: ex, y: size.height)))
        if lintel > 0 {
            let l = CGRect(x: 0, y: 0, width: size.width, height: lintel)
            var lsh = ctx
            lsh.addFilter(.blur(radius: 5))
            lsh.fill(Path(l.offsetBy(dx: 0, dy: 4)), with: .color(.black.opacity(0.7)))
            ctx.fill(Path(l), with: .color(Color(hex: 0x070404)))
            ctx.fill(Path(CGRect(x: 0, y: lintel - 0.8, width: size.width, height: 0.8)), with: .color(CH.tungsten.opacity(0.25)))
        }
    }
}

/// Film grain over the whole frame.
struct CHGrain: View {
    var family: Family
    var strength: Double = 0.42

    var body: some View {
        CH.texture("grain-\(family.rawValue)")
            .resizable()
            .interpolation(.none)
            .blendMode(.overlay)
            .opacity(strength)
            .allowsHitTesting(false)
    }
}

/// A strong vignette that leaves a lit centre (weighted toward `center`).
struct CHVignette: View {
    var center: UnitPoint = .center
    var strength: Double = 0.8
    var size: CGSize

    var body: some View {
        let d = hypot(size.width, size.height) / 2
        RadialGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .clear, location: 0.5),
            .init(color: .black.opacity(strength * 0.45), location: 0.78),
            .init(color: .black.opacity(strength), location: 1.05)],
                       center: center, startRadius: 0, endRadius: d * 1.05)
            .allowsHitTesting(false)
    }
}
