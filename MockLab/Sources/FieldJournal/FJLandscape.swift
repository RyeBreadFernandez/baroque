import SwiftUI

// A loose ink-and-wash mountain sketch: pale sky wash, far ridges in violet grey, a snow-capped middle range
// with its shadow sides washed and hatched, and a sap-green foreground with spruce scribbles.

struct Ridge {
    var keys: [CGPoint]                 // unit coordinates inside the painting rect, left to right
    var pigment: Color
    var rim: Color
    var shadow: Color
    var opacity: Double = 1
    var inkWidth: CGFloat = 0           // 0 = wash only
    var ink: Color = FJ.ink
    var snowline: CGFloat? = nil        // unit y; paper is reserved above it (snow)
    var trees: Int = 0
    var treeHeight: CGFloat = 9
    var hatch: Bool = false
    var fadeDepth: CGFloat = 0.35       // unit height below the ridge's lowest point over which the wash dries out
    var roughness: CGFloat = 0.16
    var granulation: Double = 0.4
    var blooms: Int = 1
    var charge: Color? = nil            // a second pigment dropped wet-in-wet into the lower body
    var glaze: Int = 1                  // repeat the body wash for deeper value
    var seed: UInt64
}

struct Scenery {
    var ridges: [Ridge]
    var sky: CGRect? = nil              // unit rect for the sky wash
    var skyOpacity: Double = 0.55
    var seed: UInt64 = 1
    var birds: CGRect? = nil            // unit rect where a few birds fly
    var fullSky: Bool = false           // a full graded wash with lifted clouds instead of loose strokes
}

enum Landscape {
    static func ridgeLine(_ ridge: Ridge, in rect: CGRect) -> [CGPoint] {
        var pts = ridge.keys.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        var rng = SeededRandom(seed: ridge.seed)
        for pass in 0..<4 {
            var next: [CGPoint] = [pts[0]]
            let k: CGFloat = pass == 0 ? 1 : 0.85
            for i in 0..<(pts.count - 1) {
                let a = pts[i], b = pts[i + 1]
                let d = (b - a).length
                let m = CGPoint(x: (a.x + b.x) / 2 + rng.range(-0.08...0.08) * (b.x - a.x),
                                y: (a.y + b.y) / 2 + rng.range(-1...1) * d * ridge.roughness * k)
                next.append(m)
                next.append(b)
            }
            pts = next
        }
        return pts
    }

    static func y(at x: CGFloat, on line: [CGPoint]) -> CGFloat {
        guard let first = line.first, let last = line.last else { return 0 }
        if x <= first.x { return first.y }
        if x >= last.x { return last.y }
        for i in 1..<line.count where line[i].x >= x {
            let a = line[i - 1], b = line[i]
            let t = (x - a.x) / max(b.x - a.x, 0.001)
            return a.y + (b.y - a.y) * t
        }
        return last.y
    }

    static func paint(_ ctx: GraphicsContext, scene: Scenery, in rect: CGRect, tooth: GraphicsContext.ResolvedImage) {
        if let sky = scene.sky {
            if scene.fullSky {
                paintFullSky(ctx, unit: sky, in: rect, opacity: scene.skyOpacity, seed: scene.seed, tooth: tooth)
            } else {
                paintSky(ctx, unit: sky, in: rect, opacity: scene.skyOpacity, seed: scene.seed, tooth: tooth)
            }
        }
        if let b = scene.birds {
            birds(ctx, in: CGRect(x: rect.minX + b.minX * rect.width, y: rect.minY + b.minY * rect.height,
                                  width: b.width * rect.width, height: b.height * rect.height), count: 3, seed: scene.seed &+ 9)
        }
        for ridge in scene.ridges { paint(ctx, ridge: ridge, in: rect, tooth: tooth) }
    }

    /// A quick sky: a few loose horizontal strokes of cerulean, strongest at the top, with paper left between
    /// them for cloud. Hard edges where the brush ran dry, pooled rims, a little granulation.
    static func paintSky(_ ctx: GraphicsContext, unit: CGRect, in rect: CGRect, opacity: Double, seed: UInt64, tooth: GraphicsContext.ResolvedImage) {
        let r = CGRect(x: rect.minX + unit.minX * rect.width, y: rect.minY + unit.minY * rect.height,
                       width: unit.width * rect.width, height: unit.height * rect.height)
        var rng = SeededRandom(seed: seed)
        let bands = 4
        for i in 0..<bands {
            let t = CGFloat(i) / CGFloat(bands - 1)
            let y = r.minY + r.height * (0.14 + t * 0.62) + rng.range(-3...3)
            let x0 = r.minX + r.width * rng.range(0.0...0.22)
            let x1 = r.maxX - r.width * rng.range(0.0...0.18)
            let pts = Brush.wobbly([CGPoint(x: x0, y: y), CGPoint(x: (x0 + x1) / 2, y: y + rng.range(-3...3)), CGPoint(x: x1, y: y + rng.range(-4...4))],
                                   amplitude: r.height * 0.04, step: 5, seed: seed &+ UInt64(i))
            let width = r.height * (0.26 - t * 0.09)
            let stroke = Brush.tapered(pts, width: width, taperIn: 0.18, taperOut: 0.28, pressureSeed: seed &+ UInt64(i) &* 7, pressureVar: 0.55)
            ctx.wash(stroke, pigment: t < 0.4 ? FJ.cerulean : FJ.ceruleanPale, rim: FJ.ceruleanDeep, opacity: opacity * Double(0.8 - t * 0.35),
                     seed: seed &+ UInt64(i) &* 3, tooth: tooth, granulation: 0.35, blooms: i == 0 ? 2 : 1, rimWidth: 1.4, spread: 1.2)
        }
    }

    /// A graded wash over the whole sky (for big surfaces): deep cerulean at the top paling to the horizon,
    /// with clouds lifted out by blotting.
    static func paintFullSky(_ ctx: GraphicsContext, unit: CGRect, in rect: CGRect, opacity: Double, seed: UInt64, tooth: GraphicsContext.ResolvedImage) {
        let r = CGRect(x: rect.minX + unit.minX * rect.width - 20, y: rect.minY + unit.minY * rect.height - 20,
                       width: unit.width * rect.width + 40, height: unit.height * rect.height + 20)
        let shape = Path(r)
        ctx.wash(shape, pigment: FJ.cerulean, rim: FJ.ceruleanDeep, opacity: opacity * 0.85, seed: seed, tooth: tooth,
                 granulation: 0.4, blooms: 0, rimWidth: 1, spread: 3, fade: (r.minY + r.height * 0.3)...(r.maxY))
        ctx.wash(shape, pigment: FJ.ceruleanPale, rim: FJ.cerulean, opacity: opacity * 0.7, seed: seed &+ 1, tooth: tooth,
                 granulation: 0.2, blooms: 0, rimWidth: 1, spread: 3, fade: (r.minY + r.height * 0.7)...(r.maxY + 10))
        // Blotted clouds: lift pigment back toward paper with soft-edged, flat-bottomed shapes.
        var rng = SeededRandom(seed: seed &+ 2)
        for i in 0..<5 {
            let c = CGPoint(x: r.minX + r.width * (CGFloat(i) + rng.range(0.1...0.9)) / 5, y: r.minY + r.height * rng.range(0.25...0.6))
            let w = r.width * rng.range(0.10...0.17)
            var cloud = Path()
            for k in 0..<4 {
                let rr = w * rng.range(0.22...0.36)
                cloud.addEllipse(in: CGRect(x: c.x - w / 2 + CGFloat(k) * w * 0.28 - rr * 0.3, y: c.y - rr * 1.2, width: rr * 2, height: rr * 1.8))
            }
            cloud.addRoundedRect(in: CGRect(x: c.x - w * 0.55, y: c.y - w * 0.08, width: w * 1.3, height: w * 0.2), cornerSize: CGSize(width: w * 0.1, height: w * 0.1))
            var lift = ctx
            lift.addFilter(.blur(radius: 3))
            lift.fill(cloud, with: .color(FJ.paper.opacity(0.75)))
            var fringe = ctx
            fringe.blendMode = .multiply
            fringe.addFilter(.blur(radius: 1.2))
            fringe.stroke(cloud, with: .color(FJ.cerulean.opacity(0.25)), lineWidth: 1.5)
        }
    }

    static func paint(_ ctx: GraphicsContext, ridge: Ridge, in rect: CGRect, tooth: GraphicsContext.ResolvedImage) {
        let line = ridgeLine(ridge, in: rect)
        let lowest = line.map(\.y).max() ?? rect.maxY
        let fadeEnd = min(lowest + rect.height * ridge.fadeDepth, rect.maxY + 2)
        let fadeStart = min(lowest + rect.height * 0.04, fadeEnd - max(6, rect.height * 0.12))
        let bottom = fadeEnd + 10

        // Body wash, with paper reserved above the snowline.
        var top = line
        if let s = ridge.snowline {
            let sy = rect.minY + s * rect.height
            let jag = Wobble(seed: ridge.seed &+ 99, base: 0.45, octaves: 3)
            top = line.map { p in
                guard p.y < sy else { return p }
                return CGPoint(x: p.x, y: max(p.y + 1.2, sy + jag(p.x) * 3.4 - (sy - p.y) * 0.35))
            }
        }
        var body = Brush.smooth(top)
        let dry = Wobble(seed: ridge.seed &+ 404, base: 0.06, octaves: 3)
        var x = top.last!.x
        var edge: [CGPoint] = []
        while x > top[0].x { edge.append(CGPoint(x: x, y: fadeEnd - 4 + dry(x) * min(10, rect.height * 0.08))); x -= 6 }
        edge.append(CGPoint(x: top[0].x, y: fadeEnd - 4 + dry(top[0].x) * min(10, rect.height * 0.08)))
        for p in edge { body.addLine(to: p) }
        body.closeSubpath()
        _ = bottom
        for g in 0..<max(1, ridge.glaze) {
            ctx.wash(body, pigment: ridge.pigment, rim: ridge.rim, opacity: ridge.opacity, seed: ridge.seed &+ 1 &+ UInt64(g) &* 101, tooth: tooth,
                     granulation: ridge.granulation, blooms: ridge.blooms, rimWidth: 2.0, spread: 1.0 + CGFloat(g), fade: fadeStart...fadeEnd)
        }
        if let charge = ridge.charge {
            var rng = SeededRandom(seed: ridge.seed &+ 555)
            var c = ctx
            c.clip(to: body)
            let highest = line.map(\.y).min() ?? rect.minY
            for k in 0..<3 {
                let cx = rect.minX + rect.width * (CGFloat(k) + rng.range(0.2...0.8)) / 3
                let cy = y(at: cx, on: line) + (lowest - highest) * rng.range(0.25...0.6) + 4
                let blob = Brush.blob(center: CGPoint(x: cx, y: cy), rx: rect.width * rng.range(0.12...0.2), ry: (lowest - highest) * 0.35 + 6,
                                      irregularity: 0.2, points: 18, seed: ridge.seed &+ UInt64(k) &* 71)
                c.wash(blob, pigment: charge, rim: charge, opacity: ridge.opacity * 0.55, seed: ridge.seed &+ UInt64(k) &+ 600, tooth: tooth,
                       granulation: ridge.granulation * 0.6, blooms: 0, rimWidth: 1, spread: 2, soft: 2.5, fade: fadeStart...fadeEnd)
            }
        }

        // Shadow sides: from each peak down its right flank to the next valley, back up a crooked spine.
        let peaks = peakIndices(ridge.keys)
        let keysAbs = ridge.keys.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        var shadows: [Path] = []
        for j in peaks where j + 1 < keysAbs.count {
            let peak = CGPoint(x: keysAbs[j].x, y: y(at: keysAbs[j].x, on: line))
            let valley = CGPoint(x: keysAbs[j + 1].x, y: y(at: keysAbs[j + 1].x, on: line))
            let flank = line.filter { $0.x >= peak.x && $0.x <= valley.x }
            guard flank.count > 2 else { continue }
            let run = valley.x - peak.x
            let drop = max(valley.y - peak.y, 6)
            // A curved gully: down the flank, then back up a crooked spine under the summit.
            let low = CGPoint(x: valley.x - run * 0.3, y: valley.y + drop * 0.55)
            let mid = CGPoint(x: peak.x + run * 0.1, y: peak.y + drop * 0.8)
            let spine = Brush.wobbly([low, mid, CGPoint(x: peak.x + 0.5, y: peak.y + 1)], amplitude: 1.6, step: 3,
                                     seed: ridge.seed &+ UInt64(j) &* 13)
            var p = Brush.smooth(flank)
            for q in spine { p.addLine(to: q) }
            p.closeSubpath()
            shadows.append(p)
            ctx.wash(p, pigment: ridge.shadow, rim: ridge.shadow, opacity: ridge.opacity * 0.55, seed: ridge.seed &+ UInt64(j) &* 7,
                     tooth: tooth, granulation: ridge.granulation * 0.8, blooms: 0, rimWidth: 1.2, spread: 0.5,
                     fade: (peak.y + drop * 0.55)...(low.y + 2))
            if ridge.inkWidth > 0 {
                let upper = Array(spine.suffix(Int(Double(spine.count) * 0.55)))
                ctx.ink(upper, color: ridge.ink, width: ridge.inkWidth * 0.6, seed: ridge.seed &+ UInt64(j), taperIn: 0.6, taperOut: 0.1, opacity: 0.7)
            }
        }
        if ridge.hatch && ridge.inkWidth > 0 { hatch(ctx, shadows: shadows, color: ridge.ink, seed: ridge.seed &+ 51, below: fadeEnd) }

        // Ink contour, broken where the pen lifted.
        if ridge.inkWidth > 0 { contour(ctx, line: line, ridge: ridge) }
        if ridge.trees > 0 { trees(ctx, line: line, ridge: ridge, rect: rect) }
    }

    static func peakIndices(_ keys: [CGPoint]) -> [Int] {
        guard keys.count > 2 else { return [] }
        return (1..<(keys.count - 1)).filter { keys[$0].y < keys[$0 - 1].y && keys[$0].y < keys[$0 + 1].y }
    }

    static func contour(_ ctx: GraphicsContext, line: [CGPoint], ridge: Ridge) {
        var rng = SeededRandom(seed: ridge.seed &+ 77)
        var i = 0
        var piece = 0
        while i < line.count - 2 {
            let len = Int(rng.range(14...30))
            let end = min(line.count - 1, i + len)
            let seg = Array(line[i...end])
            ctx.ink(seg, color: ridge.ink, width: ridge.inkWidth, seed: ridge.seed &+ UInt64(piece), taperIn: 0.18, taperOut: 0.3, opacity: 0.9)
            piece += 1
            i = end + (rng.unit() < 0.45 ? 2 : 0)
        }
    }

    static func hatch(_ ctx: GraphicsContext, shadows: [Path], color: Color, seed: UInt64, below: CGFloat) {
        var rng = SeededRandom(seed: seed)
        for s in shadows {
            var c = ctx
            c.clip(to: s)
            let b = s.boundingRect
            var x = b.minX - b.height
            while x < b.maxX {
                let y0 = b.minY + rng.range(0...b.height * 0.5)
                let len = rng.range(5...10)
                guard y0 < below else { x += 2.6; continue }
                let a = CGPoint(x: x + (y0 - b.minY) * 0.55, y: y0)
                let z = CGPoint(x: a.x + len * 0.5, y: a.y + len)
                c.ink([a, z], color: color, width: 0.55, seed: UInt64(x * 10), taperIn: 0.3, taperOut: 0.4, opacity: 0.5)
                x += rng.range(2.2...3.2)
            }
        }
    }

    static func trees(_ ctx: GraphicsContext, line: [CGPoint], ridge: Ridge, rect: CGRect) {
        var rng = SeededRandom(seed: ridge.seed &+ 303)
        for t in 0..<ridge.trees {
            let x = rect.minX + rect.width * (CGFloat(t) + rng.range(0.1...0.9)) / CGFloat(ridge.trees)
            let base = y(at: x, on: line) + rng.range(1...5)
            let h = ridge.treeHeight * rng.range(0.7...1.25)
            spruce(ctx, base: CGPoint(x: x, y: base), height: h, ink: ridge.ink, seed: ridge.seed &+ UInt64(t) &* 17)
        }
    }

    static func spruce(_ ctx: GraphicsContext, base: CGPoint, height h: CGFloat, ink: Color, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        let w = h * 0.46
        // Jagged silhouette: tiers of drooping branches, widest at the bottom.
        let tiers = max(3, Int(h / 3.2))
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0..<tiers {
            let t = CGFloat(i) / CGFloat(tiers)
            let y = base.y - h * (0.08 + t * 0.86)
            let half = w * 0.5 * (1 - t) + h * 0.03
            left.append(CGPoint(x: base.x - half * rng.range(0.85...1.1), y: y + h * 0.04))
            left.append(CGPoint(x: base.x - half * 0.45, y: y - h * 0.05))
            right.append(CGPoint(x: base.x + half * rng.range(0.85...1.1), y: y + h * 0.04))
            right.append(CGPoint(x: base.x + half * 0.45, y: y - h * 0.05))
        }
        var sil = Path()
        sil.move(to: CGPoint(x: base.x, y: base.y - h * 0.04))
        for p in left { sil.addLine(to: p) }
        sil.addLine(to: CGPoint(x: base.x, y: base.y - h))
        for p in right.reversed() { sil.addLine(to: p) }
        sil.closeSubpath()
        ctx.wash(sil, pigment: FJ.sapDeep, rim: Color(hex: 0x2F4418), opacity: 0.9, seed: seed, granulation: 0, blooms: 0,
                 rimWidth: max(0.8, h * 0.05), spread: max(0.4, h * 0.02))
        ctx.ink([CGPoint(x: base.x, y: base.y + h * 0.04), CGPoint(x: base.x + rng.range(-0.3...0.3), y: base.y - h)], color: ink,
                width: max(0.55, h * 0.04), seed: seed, opacity: 0.85)
        var zig: [CGPoint] = []
        for i in 0..<min(left.count, right.count) where i % 2 == 0 {
            zig.append(left[i])
            zig.append(CGPoint(x: base.x, y: left[i].y - h * 0.06))
            zig.append(right[min(i, right.count - 1)])
        }
        if zig.count > 1 {
            ctx.ink(zig, color: ink, width: max(0.45, h * 0.03), seed: seed &+ 1, taperIn: 0.05, taperOut: 0.3, opacity: 0.6)
        }
    }

    /// A few distant birds: quick ink ticks.
    static func birds(_ ctx: GraphicsContext, in r: CGRect, count: Int, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        for i in 0..<count {
            let c = CGPoint(x: rng.range(r.minX...r.maxX), y: rng.range(r.minY...r.maxY))
            let s = rng.range(2.4...3.6)
            let lift = rng.range(0.6...1.0)
            let pts = [CGPoint(x: c.x - s, y: c.y - s * 0.5 * lift), CGPoint(x: c.x - s * 0.45, y: c.y - s * 0.55),
                       CGPoint(x: c.x, y: c.y), CGPoint(x: c.x + s * 0.5, y: c.y - s * 0.6), CGPoint(x: c.x + s * 1.1, y: c.y - s * 0.45 * lift)]
            ctx.ink(Brush.wobbly(pts, amplitude: 0.1, step: 1, seed: seed &+ UInt64(i)), color: FJ.ink, width: 0.75,
                    seed: seed &+ UInt64(i) &* 3, taperIn: 0.3, taperOut: 0.3, opacity: 0.85)
        }
    }
}

/// Presets per widget, in unit coordinates of the painting rect.
enum Sceneries {
    static func far(_ keys: [CGPoint], seed: UInt64, opacity: Double = 0.75) -> Ridge {
        Ridge(keys: keys, pigment: FJ.violetGrey, rim: FJ.indigoGrey, shadow: FJ.indigoGrey, opacity: opacity,
              fadeDepth: 0.30, roughness: 0.12, granulation: 0.55, blooms: 1, charge: FJ.rose, seed: seed)
    }
    static func mid(_ keys: [CGPoint], snowline: CGFloat?, seed: UInt64, ink: CGFloat = 1.0) -> Ridge {
        Ridge(keys: keys, pigment: Color(hex: 0x7FA2BE), rim: FJ.ceruleanDeep, shadow: Color(hex: 0x5F6FA0), opacity: 0.9,
              inkWidth: ink, snowline: snowline, hatch: true, fadeDepth: 0.42, roughness: 0.17, granulation: 0.65, blooms: 1,
              charge: Color(hex: 0x8E86B8), seed: seed)
    }
    static func near(_ keys: [CGPoint], trees: Int, seed: UInt64, treeHeight: CGFloat = 9) -> Ridge {
        Ridge(keys: keys, pigment: Color(hex: 0x9DB15A), rim: FJ.sapDeep, shadow: FJ.olive, opacity: 0.85,
              inkWidth: 0.8, trees: trees, treeHeight: treeHeight, fadeDepth: 0.5, roughness: 0.10, granulation: 0.45, blooms: 2,
              charge: FJ.ochre, seed: seed)
    }
}
