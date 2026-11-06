import SwiftUI

// Small hand-made pieces: washi tape, an inked check box, a star doodle, a red-pencil ring,
// weather sketches, a pressed fern and flower, and the round "next quote" tag.

enum TapePattern { case grid, dots, stripes, leaves }

/// Translucent paper tape with torn ends, a printed pattern and a faint sheen.
struct WashiTape: View {
    var color: Color
    var ink: Color
    var pattern: TapePattern
    var seed: UInt64

    static func shape(_ r: CGRect, seed: UInt64) -> Path {
        var rng = SeededRandom(seed: seed)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + rng.range(0...1.5), y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - rng.range(0...1.5), y: r.minY))
        var y = r.minY
        while y < r.maxY {
            y = min(r.maxY, y + rng.range(0.9...2.0))
            p.addLine(to: CGPoint(x: r.maxX - rng.range(0...2.4), y: y))
        }
        p.addLine(to: CGPoint(x: r.minX + rng.range(0...1.5), y: r.maxY))
        y = r.maxY
        while y > r.minY {
            y = max(r.minY, y - rng.range(0.9...2.0))
            p.addLine(to: CGPoint(x: r.minX + rng.range(0...2.4), y: y))
        }
        p.closeSubpath()
        return p
    }

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4)
            let shape = Self.shape(r, seed: seed)
            var sh = ctx
            sh.addFilter(.blur(radius: 0.8))
            sh.fill(shape.offsetBy(dx: 0.3, dy: 0.7), with: .color(.black.opacity(0.16)))
            ctx.fill(shape, with: .color(color.opacity(0.80)))
            var c = ctx
            c.clip(to: shape)
            Page.fibers(c, size: size, seed: seed &+ 3)
            drawPattern(c, r: r)
            // Crinkle: faint diagonal creases.
            var rng = SeededRandom(seed: seed &+ 9)
            for _ in 0..<3 {
                let x = rng.range(r.minX...r.maxX)
                var p = Path()
                p.move(to: CGPoint(x: x, y: r.minY))
                p.addLine(to: CGPoint(x: x + rng.range(-6...6), y: r.maxY))
                c.stroke(p, with: .color(.white.opacity(0.28)), lineWidth: 0.6)
                c.stroke(p.offsetBy(dx: 0.6, dy: 0), with: .color(.black.opacity(0.05)), lineWidth: 0.6)
            }
            c.fill(Path(r), with: .linearGradient(Gradient(colors: [.white.opacity(0.28), .white.opacity(0.0), .white.opacity(0.12)]),
                                                  startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.minX, y: r.maxY)))
            c.stroke(Path(CGRect(x: r.minX - 2, y: r.minY, width: r.width + 4, height: r.height)), with: .color(ink.opacity(0.18)), lineWidth: 0.7)
        }
    }

    private func drawPattern(_ c: GraphicsContext, r: CGRect) {
        switch pattern {
        case .grid:
            var x = r.minX + 2
            while x < r.maxX { c.fill(Path(CGRect(x: x, y: r.minY, width: 0.35, height: r.height)), with: .color(ink.opacity(0.20))); x += 3.2 }
            var y = r.minY + 1.5
            while y < r.maxY { c.fill(Path(CGRect(x: r.minX, y: y, width: r.width, height: 0.35)), with: .color(ink.opacity(0.20))); y += 3.2 }
        case .dots:
            var rng = SeededRandom(seed: seed &+ 21)
            var y = r.minY + 2.5
            var row = 0
            while y < r.maxY {
                var x = r.minX + (row % 2 == 0 ? 2 : 5)
                while x < r.maxX {
                    let d = rng.range(1.1...1.5)
                    c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(.white.opacity(0.75)))
                    x += 6
                }
                y += 3.6
                row += 1
            }
        case .stripes:
            var x = r.minX - r.height
            while x < r.maxX {
                var p = Path()
                p.move(to: CGPoint(x: x, y: r.maxY))
                p.addLine(to: CGPoint(x: x + r.height, y: r.minY))
                c.stroke(p, with: .color(ink.opacity(0.16)), lineWidth: 1.6)
                x += 4.5
            }
        case .leaves:
            var rng = SeededRandom(seed: seed &+ 31)
            var x = r.minX + 3
            while x < r.maxX {
                let y = r.midY + rng.range(-2...2)
                let leaf = Brush.blob(center: CGPoint(x: x, y: y), rx: 2.4, ry: 1.1, irregularity: 0.05, points: 10,
                                      rotation: rng.range(-0.9...0.9), seed: UInt64(x * 7))
                c.fill(leaf, with: .color(ink.opacity(0.28)))
                x += 7
            }
        }
    }
}

/// A hand-ruled check box: four separate strokes that overshoot at the corners.
struct InkBox: View {
    var color: Color = FJ.blueInk
    var seed: UInt64
    var width: CGFloat = 1.0

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: seed)
            let r = CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
            let c = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
            for i in 0..<4 {
                let a = c[i], b = c[(i + 1) % 4]
                let dir = (b - a).normalized
                let start = a - dir * rng.range(0...1.4) + dir.perp * rng.range(-0.4...0.4)
                let end = b + dir * rng.range(0.2...1.6) + dir.perp * rng.range(-0.4...0.4)
                let pts = Brush.wobbly([start, end], amplitude: 0.35, step: 2, seed: seed &+ UInt64(i))
                ctx.ink(pts, color: color, width: width, seed: seed &+ UInt64(i) &* 3, taperIn: 0.15, taperOut: 0.25, opacity: 0.88)
            }
        }
    }
}

/// A quick five-point star doodle with a wash of colour (ochre for high, sienna for highest).
struct StarDoodle: View {
    var wash: Color
    var ink: Color = FJ.ink
    var seed: UInt64

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2 + size.height * 0.04)
            let R = min(size.width, size.height) * 0.48
            var rng = SeededRandom(seed: seed)
            var pts: [CGPoint] = []
            for i in 0..<6 {
                let a = -CGFloat.pi / 2 + CGFloat(i * 2) * (2 * .pi / 5)
                pts.append(CGPoint(x: c.x + cos(a) * R + rng.range(-0.6...0.6), y: c.y + sin(a) * R + rng.range(-0.6...0.6)))
            }
            var fill = Path()
            for i in 0..<10 {
                let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let rr = i % 2 == 0 ? R * 0.9 : R * 0.42
                let p = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
                if i == 0 { fill.move(to: p) } else { fill.addLine(to: p) }
            }
            fill.closeSubpath()
            ctx.wash(fill.offsetBy(dx: 0.6, dy: 0.5), pigment: wash, rim: wash, opacity: 0.95, seed: seed, granulation: 0, blooms: 0, rimWidth: 1, spread: 0.4)
            var line: [CGPoint] = []
            for i in 0..<5 { line.append(contentsOf: Brush.wobbly([pts[i], pts[i + 1]], amplitude: 0.25, step: 1.5, seed: seed &+ UInt64(i))) }
            ctx.ink(line, color: ink, width: 0.95, seed: seed &+ 9, taperIn: 0.05, taperOut: 0.12, opacity: 0.9)
        }
    }
}

/// A red-pencil ring drawn around whatever it overlays.
struct PencilRing: View {
    var color: Color = FJ.redPencil
    var seed: UInt64
    var width: CGFloat = 1.3

    var body: some View {
        Canvas { ctx, size in
            let pts = Brush.loopPoints(in: CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5), turns: 1.14, seed: seed)
            ctx.pencil(Brush.smooth(pts), color: color, width: width, seed: seed, strength: 1.25)
        }
    }
}

/// A hand-drawn underline (ink or pencil), slightly rising.
struct HandUnderline: View {
    var color: Color = FJ.ink
    var seed: UInt64
    var pencil: Bool = false
    var width: CGFloat = 1.1

    var body: some View {
        Canvas { ctx, size in
            let pts = Brush.wobbly([CGPoint(x: 0, y: size.height * 0.65), CGPoint(x: size.width, y: size.height * 0.35)],
                                   amplitude: 0.7, step: 3, seed: seed)
            if pencil {
                ctx.pencil(Brush.smooth(pts), color: color, width: width, seed: seed, strength: 1.1)
            } else {
                ctx.ink(pts, color: color, width: width, seed: seed, taperIn: 0.08, taperOut: 0.45)
            }
        }
    }
}

/// A watercolour dab (for highlighting a day or a label).
struct WashDab: View {
    var color: Color
    var rim: Color? = nil
    var seed: UInt64
    var opacity: Double = 0.8

    var body: some View {
        Canvas { ctx, size in
            let shape = Brush.blob(center: CGPoint(x: size.width / 2, y: size.height / 2), rx: size.width * 0.42, ry: size.height * 0.40,
                                   irregularity: 0.12, points: 16, seed: seed)
            ctx.wash(shape, pigment: color, rim: rim ?? color, opacity: opacity, seed: seed,
                     tooth: FJTex.tooth(ctx), granulation: 0.35, blooms: 1, rimWidth: 1.6)
        }
    }
}

/// Weather sketched in ink and wash; follows the SF Symbol name's meaning.
struct WeatherSketch: View {
    var symbol: String
    var seed: UInt64 = 5

    var body: some View {
        Canvas { ctx, size in
            let tooth = FJTex.tooth(ctx)
            let s = min(size.width, size.height)
            let hasCloud = symbol.contains("cloud")
            let hasSun = symbol.contains("sun")
            let hasMoon = symbol.contains("moon")
            if hasSun {
                let c = hasCloud ? CGPoint(x: size.width * 0.62, y: size.height * 0.38) : CGPoint(x: size.width / 2, y: size.height / 2)
                sun(ctx, center: c, r: s * (hasCloud ? 0.2 : 0.24), tooth: tooth)
            }
            if hasMoon && !hasSun { moon(ctx, center: CGPoint(x: size.width * 0.55, y: size.height * 0.42), r: s * 0.24, tooth: tooth) }
            if hasCloud { cloud(ctx, center: CGPoint(x: size.width * 0.45, y: size.height * 0.58), w: s * 0.72, tooth: tooth) }
            if symbol.contains("rain") || symbol.contains("drizzle") { rain(ctx, size: size) }
            if symbol.contains("snow") { snow(ctx, size: size) }
            if symbol.contains("bolt") { bolt(ctx, size: size) }
        }
    }

    private func sun(_ ctx: GraphicsContext, center c: CGPoint, r: CGFloat, tooth: GraphicsContext.ResolvedImage) {
        let disc = Brush.blob(center: c, rx: r * 1.08, ry: r * 1.0, irregularity: 0.06, points: 16, seed: seed)
        ctx.wash(disc, pigment: FJ.ochre, rim: FJ.sienna, opacity: 0.95, seed: seed, tooth: tooth, granulation: 0.4, blooms: 1, rimWidth: 1.8)
        ctx.ink(Brush.loopPoints(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), turns: 1.05, seed: seed &+ 2),
                color: FJ.ink, width: 0.9, seed: seed &+ 3, taperIn: 0.1, taperOut: 0.2)
        var rng = SeededRandom(seed: seed &+ 4)
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * 2 * .pi + rng.range(-0.08...0.08)
            let r0 = r * 1.32, r1 = r * (i % 2 == 0 ? 1.85 : 1.6)
            ctx.ink([CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0), CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1)],
                    color: FJ.ink, width: 0.85, seed: seed &+ UInt64(i) &+ 10, taperIn: 0.2, taperOut: 0.5)
        }
    }

    private func moon(_ ctx: GraphicsContext, center c: CGPoint, r: CGFloat, tooth: GraphicsContext.ResolvedImage) {
        var p = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        p = p.subtracting(Path(ellipseIn: CGRect(x: c.x - r * 0.45, y: c.y - r * 1.15, width: r * 2, height: r * 2)))
        ctx.wash(p, pigment: FJ.ochrePale, rim: FJ.ochre, opacity: 0.95, seed: seed, tooth: tooth, granulation: 0.3, blooms: 0)
        ctx.stroke(p, with: .color(FJ.ink.opacity(0.8)), lineWidth: 0.8)
    }

    private func cloud(_ ctx: GraphicsContext, center c: CGPoint, w: CGFloat, tooth: GraphicsContext.ResolvedImage) {
        // One scalloped outline: a flat base and four bumps of different sizes along the top.
        let h = w * 0.5
        let base = c.y + h * 0.42
        let left = c.x - w * 0.5, right = c.x + w * 0.5
        let bumps: [(x: CGFloat, r: CGFloat)] = [(0.86, 0.15), (0.6, 0.22), (0.33, 0.26), (0.12, 0.14)]
        // Bottom-left to bottom-right, then the upper envelope of the bumps traced right to left.
        var outline: [CGPoint] = [CGPoint(x: left + w * 0.06, y: base), CGPoint(x: right - w * 0.06, y: base)]
        var x = right - w * 0.02
        while x > left + w * 0.02 {
            var y = base
            for b in bumps {
                let cx = left + b.x * w, r = b.r * w
                let dx = x - cx
                if abs(dx) < r { y = min(y, base - r * 0.95 - sqrt(r * r - dx * dx)) }
            }
            outline.append(CGPoint(x: x, y: min(y, base - 1)))
            x -= 0.9
        }
        let shape = Brush.smooth(outline, closed: true)
        ctx.fill(shape, with: .color(Color(hex: 0xF8F3E7)))
        ctx.wash(shape, pigment: Color(hex: 0xB9C3CF), rim: FJ.indigoGrey, opacity: 0.9, seed: seed &+ 20, tooth: tooth, granulation: 0.45, blooms: 1)
        ctx.ink(Brush.wobbly(outline + [outline[0]], amplitude: 0.2, step: 1.5, seed: seed &+ 21), color: FJ.ink, width: 0.8,
                seed: seed &+ 22, taperIn: 0.02, taperOut: 0.05, opacity: 0.8)
        if symbol.contains("fog") {
            for k in 0..<3 {
                let y = base + 3 + CGFloat(k) * 3.2
                let pts = Brush.wobbly([CGPoint(x: left + CGFloat(k) * 3, y: y), CGPoint(x: right - CGFloat(2 - k) * 3, y: y)], amplitude: 0.6, step: 2, seed: seed &+ UInt64(k))
                ctx.pencil(Brush.smooth(pts), color: FJ.indigoGrey, width: 0.9, seed: seed &+ UInt64(k), strength: 1.1)
            }
        }
    }

    private func rain(_ ctx: GraphicsContext, size: CGSize) {
        for i in 0..<5 {
            let x = size.width * (0.2 + CGFloat(i) * 0.13)
            ctx.ink([CGPoint(x: x, y: size.height * 0.8), CGPoint(x: x - 2.5, y: size.height * 0.98)], color: FJ.ceruleanDeep, width: 0.9, seed: UInt64(i) &+ seed)
        }
    }

    private func snow(_ ctx: GraphicsContext, size: CGSize) {
        for i in 0..<4 {
            let c = CGPoint(x: size.width * (0.22 + CGFloat(i) * 0.18), y: size.height * (i % 2 == 0 ? 0.86 : 0.95))
            for k in 0..<3 {
                let a = CGFloat(k) * .pi / 3
                ctx.ink([CGPoint(x: c.x - cos(a) * 2, y: c.y - sin(a) * 2), CGPoint(x: c.x + cos(a) * 2, y: c.y + sin(a) * 2)],
                        color: FJ.ceruleanDeep, width: 0.6, seed: UInt64(i * 3 + k))
            }
        }
    }

    private func bolt(_ ctx: GraphicsContext, size: CGSize) {
        let pts = [CGPoint(x: size.width * 0.52, y: size.height * 0.7), CGPoint(x: size.width * 0.44, y: size.height * 0.86),
                   CGPoint(x: size.width * 0.54, y: size.height * 0.86), CGPoint(x: size.width * 0.46, y: size.height * 1.0)]
        ctx.ink(pts, color: FJ.sienna, width: 1.1, seed: seed)
    }
}

/// Sunrise / sunset glyph: a half sun on a horizon with a tiny arrow.
struct HorizonSun: View {
    var rising: Bool
    var seed: UInt64

    var body: some View {
        Canvas { ctx, size in
            let base = size.height * 0.78
            let c = CGPoint(x: size.width / 2, y: base)
            let r = size.width * 0.26
            var half = Path()
            half.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            half.closeSubpath()
            ctx.wash(half, pigment: rising ? FJ.ochre : FJ.siennaPale, rim: FJ.sienna, opacity: 0.9, seed: seed, granulation: 0, blooms: 0, rimWidth: 1)
            ctx.ink([CGPoint(x: 0.5, y: base), CGPoint(x: size.width - 0.5, y: base)], color: FJ.ink, width: 0.8, seed: seed, taperIn: 0.1, taperOut: 0.1)
            ctx.stroke(Path { p in p.addArc(center: c, radius: r, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false) },
                       with: .color(FJ.ink.opacity(0.85)), lineWidth: 0.7)
            let ax = size.width / 2
            let top: CGFloat = 0.8, bot = base - r - 1.2
            let tip = rising ? top : bot
            ctx.ink([CGPoint(x: ax, y: rising ? bot : top), CGPoint(x: ax, y: tip)], color: FJ.ink, width: 0.7, seed: seed &+ 1, taperIn: 0.1, taperOut: 0.1)
            let d: CGFloat = rising ? 1.6 : -1.6
            ctx.ink([CGPoint(x: ax - 1.6, y: tip + d), CGPoint(x: ax, y: tip), CGPoint(x: ax + 1.6, y: tip + d)], color: FJ.ink, width: 0.65, seed: seed &+ 2, taperIn: 0.1, taperOut: 0.1)
        }
    }
}

/// A pressed fern frond, painted: curved rachis with alternating, shrinking pinnae in sap green and olive,
/// some browned at the tips, with ink veins and a hair of shadow where it lies on the page.
struct FernSketch: View {
    var seed: UInt64
    var pinnae: Int = 9
    var pressed: Bool = true
    var base = CGPoint(x: 0.08, y: 0.96)      // unit coordinates of the cut stem
    var tip = CGPoint(x: 0.9, y: 0.08)
    var bend = CGPoint(x: 0.28, y: 0.2)
    var pinnaScale: CGFloat = 0.30

    var body: some View {
        Canvas { ctx, size in
            let tooth = FJTex.tooth(ctx)
            var rng = SeededRandom(seed: seed)
            // Rachis: from bottom-left base curving up to the top-right tip.
            let base = CGPoint(x: size.width * self.base.x, y: size.height * self.base.y)
            let tip = CGPoint(x: size.width * self.tip.x, y: size.height * self.tip.y)
            let ctrl = CGPoint(x: size.width * bend.x, y: size.height * bend.y)
            func point(_ t: CGFloat) -> CGPoint {
                let u = 1 - t
                return CGPoint(x: u * u * base.x + 2 * u * t * ctrl.x + t * t * tip.x, y: u * u * base.y + 2 * u * t * ctrl.y + t * t * tip.y)
            }
            let len = (tip - base).length
            var leaves: [(Path, CGPoint, CGPoint, Color)] = []
            for i in 0..<pinnae * 2 {
                let t = 0.12 + CGFloat(i) / CGFloat(pinnae * 2) * 0.84
                let p = point(t)
                let tangent = (point(min(1, t + 0.01)) - point(max(0, t - 0.01))).normalized
                let side: CGFloat = i % 2 == 0 ? 1 : -1
                let dir = (tangent.perp * side + tangent * 0.42).normalized
                let l = len * pinnaScale * (1 - t * 0.72) * rng.range(0.88...1.08)
                let wdt = l * 0.24
                let end = p + dir * l
                let nrm = dir.perp
                var leaf: [CGPoint] = [p]
                // Lobed pinna: alternate full and notched points along both edges (pinnules).
                let lobes = 7
                for k in 1...lobes {
                    let u = CGFloat(k) / CGFloat(lobes + 1)
                    let bulge = sin(min(1, u * 1.15) * .pi * 0.5 + u * .pi * 0.5) * wdt * (k % 2 == 0 ? 0.55 : 1.0)
                    leaf.append(p + dir * (l * u) + nrm * bulge)
                }
                leaf.append(end)
                for k in stride(from: lobes, through: 1, by: -1) {
                    let u = CGFloat(k) / CGFloat(lobes + 1)
                    let bulge = sin(min(1, u * 1.15) * .pi * 0.5 + u * .pi * 0.5) * wdt * (k % 2 == 0 ? 0.5 : 0.95)
                    leaf.append(p + dir * (l * u) - nrm * bulge)
                }
                let browned = rng.unit() < 0.25
                let tone: Color = browned ? FJ.olive : (rng.unit() < 0.5 ? FJ.sap : Color(hex: 0x86A044))
                leaves.append((Brush.smooth(leaf, closed: true), p, end, tone))
            }
            if pressed {
                var sh = ctx
                sh.addFilter(.blur(radius: 0.9))
                for leaf in leaves { sh.fill(leaf.0.offsetBy(dx: 0.6, dy: 0.9), with: .color(.black.opacity(0.10))) }
            }
            for (i, leaf) in leaves.enumerated() {
                ctx.wash(leaf.0, pigment: leaf.3, rim: FJ.sapDeep, opacity: 0.9, seed: seed &+ UInt64(i) &* 5, tooth: tooth,
                         granulation: 0.3, blooms: 0, rimWidth: 1.2, spread: 0.3)
                ctx.ink([leaf.1, leaf.1 + (leaf.2 - leaf.1) * 0.85], color: FJ.sapDeep, width: 0.4, seed: UInt64(i), opacity: 0.7)
            }
            var stem: [CGPoint] = []
            for k in 0...24 { stem.append(point(CGFloat(k) / 24)) }
            ctx.ink(stem, color: Color(hex: 0x6B5A2A), width: 1.1, seed: seed &+ 77, taperIn: 0.0, taperOut: 0.8)
        }
    }
}

/// A pressed forget-me-not sprig: cerulean five-petal flowers with ochre eyes, a stem and two leaves.
struct PressedFlower: View {
    var seed: UInt64

    var body: some View {
        Canvas { ctx, size in
            let tooth = FJTex.tooth(ctx)
            var rng = SeededRandom(seed: seed)
            let base = CGPoint(x: size.width * 0.2, y: size.height * 0.98)
            let heads = [CGPoint(x: size.width * 0.62, y: size.height * 0.2), CGPoint(x: size.width * 0.82, y: size.height * 0.42),
                         CGPoint(x: size.width * 0.42, y: size.height * 0.36)]
            var shadow = ctx
            shadow.addFilter(.blur(radius: 0.8))
            for (i, h) in heads.enumerated() {
                let mid = CGPoint(x: (base.x + h.x) / 2 - 6 + CGFloat(i) * 3, y: (base.y + h.y) / 2 + 4)
                let stem = Brush.smooth([base, mid, h])
                shadow.stroke(stem.offsetBy(dx: 0.5, dy: 0.8), with: .color(.black.opacity(0.12)), lineWidth: 1.4)
                ctx.stroke(stem, with: .color(Color(hex: 0x6C7A35).opacity(0.9)), lineWidth: 0.9)
            }
            for k in 0..<2 {
                let c = CGPoint(x: size.width * (0.28 + CGFloat(k) * 0.12), y: size.height * (0.72 - CGFloat(k) * 0.1))
                let leaf = Brush.blob(center: c, rx: size.width * 0.11, ry: size.width * 0.04, irregularity: 0.05, points: 12,
                                      rotation: k == 0 ? -0.9 : -0.4, seed: seed &+ UInt64(k))
                shadow.fill(leaf.offsetBy(dx: 0.5, dy: 0.8), with: .color(.black.opacity(0.12)))
                ctx.wash(leaf, pigment: FJ.sap, rim: FJ.sapDeep, opacity: 0.9, seed: seed &+ UInt64(k) &+ 40, tooth: tooth, granulation: 0.3, blooms: 0, rimWidth: 1)
            }
            for (i, h) in heads.enumerated() {
                let pr = size.width * (i == 0 ? 0.075 : 0.062)
                let rot = rng.range(0...1.2)
                for p in 0..<5 {
                    let a = rot + CGFloat(p) * 2 * .pi / 5
                    let pc = CGPoint(x: h.x + cos(a) * pr * 0.95, y: h.y + sin(a) * pr * 0.95)
                    let petal = Brush.blob(center: pc, rx: pr * 0.78, ry: pr * 0.66, irregularity: 0.08, points: 12, rotation: a,
                                           seed: seed &+ UInt64(i * 10 + p))
                    shadow.fill(petal.offsetBy(dx: 0.4, dy: 0.7), with: .color(.black.opacity(0.10)))
                    ctx.wash(petal, pigment: Color(hex: 0x7EA6D6), rim: FJ.ceruleanDeep, opacity: 0.95, seed: seed &+ UInt64(i * 10 + p) &+ 100,
                             tooth: tooth, granulation: 0.25, blooms: 0, rimWidth: 1.1, spread: 0.2)
                }
                let eye = Path(ellipseIn: CGRect(x: h.x - pr * 0.42, y: h.y - pr * 0.42, width: pr * 0.84, height: pr * 0.84))
                ctx.wash(eye, pigment: FJ.ochre, rim: FJ.sienna, opacity: 1, seed: seed &+ UInt64(i) &+ 200, granulation: 0, blooms: 0, rimWidth: 0.8)
            }
        }
    }
}

/// The round "next quote" control: a die-cut card tag pasted on the page, washed in sap green, ringed in ink,
/// with a bold inked arrow.
struct NextTag: View {
    var seed: UInt64 = 404

    var body: some View {
        Canvas { ctx, size in
            let pad: CGFloat = 4
            let d = min(size.width, size.height) - pad * 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let disc = Brush.blob(center: c, rx: d / 2, ry: d / 2, irregularity: 0.012, points: 28, seed: seed)
            var sh = ctx
            sh.addFilter(.blur(radius: 1.5))
            sh.fill(disc.offsetBy(dx: 0.7, dy: 1.5), with: .color(Color(hex: 0x3A2814).opacity(0.45)))
            var card = ctx
            card.clip(to: disc)
            card.draw(ctx.resolve(Mock.texture("field-journal/card")), in: CGRect(x: c.x - 40, y: c.y - 40, width: 140, height: 120))
            let inner = Brush.blob(center: c, rx: d * 0.41, ry: d * 0.41, irregularity: 0.04, points: 18, seed: seed &+ 1)
            card.wash(inner, pigment: FJ.sap, rim: FJ.sapDeep, opacity: 0.95, seed: seed &+ 1,
                      tooth: FJTex.tooth(ctx), granulation: 0.5, blooms: 1, rimWidth: 1.6)
            card.fill(disc, with: .radialGradient(Gradient(colors: [.white.opacity(0.25), .clear, Color(hex: 0x5A4128).opacity(0.18)]),
                                                  center: CGPoint(x: c.x - d * 0.2, y: c.y - d * 0.25), startRadius: 0, endRadius: d * 0.75))
            ctx.stroke(disc, with: .color(FJ.ink.opacity(0.4)), lineWidth: 0.5)
            ctx.ink(Brush.loopPoints(in: CGRect(x: c.x - d * 0.43, y: c.y - d * 0.43, width: d * 0.86, height: d * 0.86), turns: 1.06, seed: seed &+ 3),
                    color: FJ.ink, width: 0.8, seed: seed &+ 4, taperIn: 0.1, taperOut: 0.2, opacity: 0.8)
            // Arrow: a slightly rising shaft and an open head.
            let a = CGPoint(x: c.x - d * 0.22, y: c.y + d * 0.03)
            let b = CGPoint(x: c.x + d * 0.22, y: c.y - d * 0.01)
            ctx.ink(Brush.wobbly([a, b], amplitude: 0.3, step: 2, seed: seed &+ 5), color: Color(hex: 0xFBF6EA), width: 3.4, seed: seed &+ 5, taperIn: 0.15, taperOut: 0.05, opacity: 0.55)
            ctx.ink(Brush.wobbly([a, b], amplitude: 0.3, step: 2, seed: seed &+ 5), color: FJ.ink, width: 1.9, seed: seed &+ 5, taperIn: 0.15, taperOut: 0.05)
            let dir = (b - a).normalized
            let h1 = b - dir * d * 0.17 + dir.perp * d * 0.15
            let h2 = b - dir * d * 0.17 - dir.perp * d * 0.15
            ctx.ink([h1, b + dir * 0.4, h2], color: FJ.ink, width: 1.8, seed: seed &+ 6, taperIn: 0.25, taperOut: 0.25)
        }
    }
}

/// A small compass rose doodled in sepia ink, half of each point washed in sienna.
struct CompassRose: View {
    var seed: UInt64 = 77

    var body: some View {
        ZStack(alignment: .top) {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2 + 5)
                let R = min(size.width, size.height - 10) * 0.48
                ctx.ink(Brush.loopPoints(in: CGRect(x: c.x - R * 0.62, y: c.y - R * 0.62, width: R * 1.24, height: R * 1.24), turns: 1.08, seed: seed),
                        color: FJ.ink, width: 0.7, seed: seed &+ 1, taperIn: 0.1, taperOut: 0.2, opacity: 0.75)
                for i in 0..<8 {
                    let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 4
                    let long = i % 2 == 0
                    let len = long ? R : R * 0.55
                    let wdt = long ? R * 0.17 : R * 0.12
                    let tip = CGPoint(x: c.x + cos(a) * len, y: c.y + sin(a) * len)
                    let side = CGPoint(x: cos(a + .pi / 2), y: sin(a + .pi / 2))
                    let l = c + side * wdt, r = c - side * wdt
                    var half = Path()
                    half.move(to: c); half.addLine(to: tip); half.addLine(to: l); half.closeSubpath()
                    if long {
                        ctx.wash(half, pigment: FJ.sienna, rim: FJ.sienna, opacity: 0.8, seed: seed &+ UInt64(i), granulation: 0, blooms: 0, rimWidth: 0.8, spread: 0.2)
                    }
                    ctx.ink([l, tip, r], color: FJ.ink, width: long ? 0.8 : 0.6, seed: seed &+ UInt64(i) &+ 20, taperIn: 0.1, taperOut: 0.1, opacity: 0.85)
                    ctx.ink([c, tip], color: FJ.ink, width: 0.45, seed: seed &+ UInt64(i) &+ 40, taperIn: 0.1, taperOut: 0.3, opacity: 0.6)
                }
            }
            Text("N")
                .font(FJ.italicSemi(10))
                .foregroundStyle(FJ.ink)
                .offset(y: -3)
        }
    }
}
