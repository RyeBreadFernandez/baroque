import SwiftUI

// The diorama itself: pieces of cut cardstock stacked back to front inside the box.
// Positions are fractions of the widget so each layout can place its ridges around its text.

struct Ridge {
    var pts: [CGPoint]
    var peaks: [Int] = []
    var color: Color
    var shade: Color? = nil
    var snow: CGFloat = 0
    var smooth = false
    var lift: CGFloat = 2
    var seed: UInt64
}

struct Forest {
    var ground: [CGPoint]
    var color: Color
    var xs: ClosedRange<CGFloat> = -0.02...1.02
    var count: Int
    var heights: ClosedRange<CGFloat>
    var lift: CGFloat = 2
    var round = false          // round broadleaf trees instead of spruce
    var seed: UInt64
}

enum Piece {
    case sun(CGPoint, CGFloat)                 // unit centre, disc diameter
    case cloud(CGPoint, CGFloat, UInt64)       // unit centre, width
    case ridge(Ridge)
    case forest(Forest)
    case cabin(CGPoint, CGFloat)               // unit base centre, width
    case balloon(CGPoint, CGFloat)             // unit centre of envelope, envelope width
    case confetti(CGRect, Int, UInt64)         // unit rect, count
    case tufts([CGPoint], Color, CGFloat)      // unit base points, colour, height
}

struct Diorama: View {
    var size: CGSize
    var pieces: [Piece]
    var sky = true
    var glow: CGPoint? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            if sky { SkySheet(glow: glow) }
            ForEach(pieces.indices, id: \.self) { i in
                PieceView(piece: pieces[i], size: size)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

struct PieceView: View {
    var piece: Piece
    var size: CGSize

    var body: some View {
        switch piece {
        case .sun(let c, let d):
            PaperSun(d: d).position(at(c))
        case .cloud(let c, let w, let seed):
            PaperCloud(width: w, seed: seed).position(at(c))
        case .ridge(let r):
            RidgeView(ridge: r)
        case .forest(let f):
            ForestView(forest: f)
        case .cabin(let c, let w):
            PaperCabin(width: w).position(x: c.x * size.width, y: c.y * size.height - w * 0.45)
        case .balloon(let c, let w):
            PaperBalloon(width: w).position(x: c.x * size.width, y: c.y * size.height + w * 0.42)
        case .confetti(let r, let n, let seed):
            Confetti(rect: r, count: n, seed: seed, size: size)
        case .tufts(let pts, let color, let h):
            TuftsView(points: pts, color: color, height: h, size: size)
        }
    }

    private func at(_ c: CGPoint) -> CGPoint { CGPoint(x: c.x * size.width, y: c.y * size.height) }
}

// MARK: - Sky

/// The back wall of the box: sky-blue stock, warmer toward the horizon, a little sun-warmth, fiber.
struct SkySheet: View {
    var glow: CGPoint?
    var body: some View {
        ZStack {
            LinearGradient(colors: [PD.skyTop, PD.skyLow], startPoint: .top, endPoint: .bottom)
            if let g = glow {
                RadialGradient(colors: [Color(hex: 0xFFF7EC).opacity(0.75), Color(hex: 0xFFF7EC).opacity(0)],
                               center: UnitPoint(x: g.x, y: g.y), startRadius: 0, endRadius: 120)
            }
            Fiber(seed: 4).opacity(0.85).blendMode(.overlay)
        }
    }
}

// MARK: - Sun, clouds

struct PaperSun: View {
    var d: CGFloat
    var body: some View {
        ZStack {
            Sheet(shape: Sunburst(rays: 12, inner: 0.56), color: Color(hex: 0xF7A37C), seed: 31, edge: 0.8)
                .frame(width: d * 1.8, height: d * 1.8)
                .lifted(1)
            Sheet(shape: Sunburst(rays: 12, inner: 0.6, phase: .pi / 12), color: Color(hex: 0xFFC25C), seed: 32, edge: 0.8)
                .frame(width: d * 1.5, height: d * 1.5)
                .lifted(1.1)
            Sheet(shape: Circle(), color: PD.butter, seed: 33)
                .frame(width: d, height: d)
                .lifted(1.6)
            Sheet(shape: Circle(), color: PD.butterLight, seed: 34, edge: 0.8)
                .frame(width: d * 0.62, height: d * 0.62)
                .offset(x: d * 0.07, y: -d * 0.07)
                .lifted(0.9)
        }
        .frame(width: d * 1.8, height: d * 1.8)
    }
}

struct CloudCut: Shape {
    var seed: UInt64
    func path(in r: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let w = r.width, h = r.height
        var p = Path(roundedRect: CGRect(x: r.minX, y: r.minY + h * 0.52, width: w, height: h * 0.48),
                     cornerRadius: h * 0.24)
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(0.12, 0.34, 0.34), (0.30, 0.02, 0.44), (0.58, 0.18, 0.34)]
        for (x, y, s) in puffs {
            let jx = rng.range(-0.03...0.03), jy = rng.range(-0.05...0.05)
            let dw = w * (s + 0.04)
            let dh = h * (1 - y - jy) * 0.95
            p = p.union(Path(ellipseIn: CGRect(x: r.minX + w * (x + jx), y: r.minY + h * (y + jy), width: dw, height: dh)))
        }
        return p
    }
}

struct PaperCloud: View {
    var width: CGFloat
    var seed: UInt64
    var body: some View {
        let h = width * 0.46
        ZStack {
            Sheet(shape: CloudCut(seed: seed &+ 1), color: Color(hex: 0xE4F1F6), seed: seed, edge: 0.8)
                .frame(width: width * 0.8, height: h * 0.85)
                .offset(x: width * 0.22, y: h * 0.12)
                .lifted(1.2)
            Sheet(shape: CloudCut(seed: seed), color: PD.snow, seed: seed &+ 2, tooth: 0.6)
                .frame(width: width, height: h)
                .lifted(1.8)
        }
        .frame(width: width * 1.3, height: h * 1.3)
    }
}

// MARK: - Ridges and forests

struct RidgeView: View {
    var ridge: Ridge
    var body: some View {
        let cut = RidgeCut(top: ridge.pts, smooth: ridge.smooth, seed: ridge.seed)
        let topY = ridge.pts.map(\.y).min() ?? 0
        ZStack {
            Sheet(shape: cut, color: ridge.color, seed: ridge.seed, lightTop: topY, lightBottom: min(1, topY + 0.5))
            if let shade = ridge.shade {
                Sheet(shape: ShadeCut(top: ridge.pts, peaks: ridge.peaks, seed: ridge.seed &+ 3), color: shade,
                      seed: ridge.seed &+ 5, lightTop: topY, lightBottom: min(1, topY + 0.5), edge: 0.8)
                    .mask(cut)
            }
            if ridge.snow > 0 {
                Sheet(shape: SnowcapCut(top: ridge.pts, peaks: ridge.peaks, depth: ridge.snow, seed: ridge.seed &+ 7),
                      color: PD.snow, seed: ridge.seed &+ 8, edge: 0.7, tooth: 0.6)
                    .lifted(0.7)
                    .mask(cut)
            }
        }
        .lifted(ridge.lift)
    }
}

struct ForestCut: Shape {
    var forest: Forest

    func path(in r: CGRect) -> Path {
        var p = RidgeCut(top: forest.ground, smooth: true, seed: forest.seed, wobble: 0.5).path(in: r)
        let ground = Cutter.scaled(forest.ground, in: r)
        var rng = SeededRandom(seed: forest.seed &+ 99)
        let span = forest.xs.upperBound - forest.xs.lowerBound
        for i in 0..<forest.count {
            let fx = forest.xs.lowerBound + span * (CGFloat(i) + rng.range(0.15...0.85)) / CGFloat(forest.count)
            let x = r.minX + fx * r.width
            let h = rng.range(forest.heights)
            let base = groundY(at: x, ground) + 3
            if rng.unit() < 0.12 { continue }   // a clearing now and then
            let t = forest.round ? roundTree(x: x, base: base, h: h * 0.85, rng: &rng)
                                 : tree(x: x, base: base, h: h, lean: rng.range(-0.6...0.6))
            p = p.union(t)
        }
        return p
    }

    private func groundY(at x: CGFloat, _ g: [CGPoint]) -> CGFloat {
        guard let first = g.first else { return 0 }
        var prev = first
        for q in g.dropFirst() {
            if x <= q.x {
                let t = (x - prev.x) / max(0.001, q.x - prev.x)
                return prev.y + (q.y - prev.y) * t
            }
            prev = q
        }
        return prev.y
    }

    /// A tiered spruce: three drooping tiers and a stub of trunk.
    private func tree(x: CGFloat, base: CGFloat, h: CGFloat, lean: CGFloat) -> Path {
        let w = h * 0.74
        let tiers: [(CGFloat, CGFloat, CGFloat)] = [(0.66, 0.25, 0.11), (0.38, 0.39, 0.17), (0.10, 0.5, 0.0)]
        var right: [CGPoint] = []
        for (yy, outer, inner) in tiers {
            right.append(CGPoint(x: x + w * outer, y: base - h * yy + h * 0.03))
            if inner > 0 { right.append(CGPoint(x: x + w * inner, y: base - h * yy - h * 0.07)) }
        }
        var pts = [CGPoint(x: x + lean, y: base - h)]
        pts += right
        pts += [CGPoint(x: x + w * 0.07, y: base - h * 0.08), CGPoint(x: x + w * 0.07, y: base + 4),
                CGPoint(x: x - w * 0.07, y: base + 4), CGPoint(x: x - w * 0.07, y: base - h * 0.08)]
        pts += right.reversed().map { CGPoint(x: 2 * x - $0.x, y: $0.y) }
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }

    /// A round broadleaf tree: two or three overlapping puffs on a short trunk.
    private func roundTree(x: CGFloat, base: CGFloat, h: CGFloat, rng: inout SeededRandom) -> Path {
        let d = h * 0.62
        var p = Path(CGRect(x: x - h * 0.05, y: base - h * 0.4, width: h * 0.1, height: h * 0.4 + 4))
        p = p.union(Path(ellipseIn: CGRect(x: x - d / 2, y: base - h, width: d, height: d * 1.05)))
        let side: CGFloat = rng.unit() < 0.5 ? -1 : 1
        let d2 = d * 0.72
        p = p.union(Path(ellipseIn: CGRect(x: x - d2 / 2 + side * d * 0.32, y: base - h * 0.72, width: d2, height: d2)))
        return p
    }
}

struct ForestView: View {
    var forest: Forest
    var body: some View {
        let topY = (forest.ground.map(\.y).min() ?? 0.5) - 0.08
        Sheet(shape: ForestCut(forest: forest), color: forest.color, seed: forest.seed,
              lightTop: topY, lightBottom: min(1, topY + 0.35), edge: 1)
            .lifted(forest.lift)
    }
}

// MARK: - Little props

struct PaperCabin: View {
    var width: CGFloat
    var body: some View {
        let w = width
        ZStack(alignment: .topLeading) {
            Sheet(shape: Rectangle(), color: PD.coralDeep, seed: 61, edge: 0.6)        // chimney
                .frame(width: w * 0.14, height: w * 0.3)
                .offset(x: w * 0.66, y: w * 0.02)
                .lifted(0.6)
            Sheet(shape: Rectangle(), color: Color(hex: 0xF9E2C6), seed: 62, edge: 0.7) // walls
                .frame(width: w * 0.8, height: w * 0.5)
                .offset(x: w * 0.1, y: w * 0.4)
                .lifted(0.8)
            Sheet(shape: CutPolygon(points: [CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)], seed: 63, wobble: 0.2),
                  color: PD.coral, seed: 64, edge: 0.7)                                  // roof
                .frame(width: w, height: w * 0.46)
                .lifted(1)
            Sheet(shape: Rectangle(), color: PD.pine, seed: 65, edge: 0.5)              // door
                .frame(width: w * 0.16, height: w * 0.27)
                .offset(x: w * 0.56, y: w * 0.63)
                .lifted(0.4)
            Sheet(shape: Rectangle(), color: PD.butter, seed: 66, edge: 0.5)            // window
                .frame(width: w * 0.17, height: w * 0.15)
                .offset(x: w * 0.24, y: w * 0.55)
                .lifted(0.4)
        }
        .frame(width: w, height: w * 0.9, alignment: .topLeading)
    }
}

struct BalloonCut: Shape {
    func path(in r: CGRect) -> Path {
        let rad = r.width / 2
        let cx = r.midX, cy = r.minY + rad
        let ny = r.maxY, nw = r.width * 0.3
        let k: CGFloat = 0.552
        var p = Path()
        p.move(to: CGPoint(x: cx - nw / 2, y: ny))
        p.addCurve(to: CGPoint(x: cx - rad, y: cy),
                   control1: CGPoint(x: cx - nw / 2 - rad * 0.3, y: ny - (ny - cy) * 0.4),
                   control2: CGPoint(x: cx - rad, y: cy + rad * 0.6))
        p.addCurve(to: CGPoint(x: cx, y: r.minY), control1: CGPoint(x: cx - rad, y: cy - rad * k), control2: CGPoint(x: cx - rad * k, y: r.minY))
        p.addCurve(to: CGPoint(x: cx + rad, y: cy), control1: CGPoint(x: cx + rad * k, y: r.minY), control2: CGPoint(x: cx + rad, y: cy - rad * k))
        p.addCurve(to: CGPoint(x: cx + nw / 2, y: ny),
                   control1: CGPoint(x: cx + rad, y: cy + rad * 0.6),
                   control2: CGPoint(x: cx + nw / 2 + rad * 0.3, y: ny - (ny - cy) * 0.4))
        p.closeSubpath()
        return p
    }
}

struct PaperBalloon: View {
    var width: CGFloat
    var body: some View {
        let w = width, eh = w * 1.15
        VStack(spacing: 0) {
            ZStack {
                Sheet(shape: BalloonCut(), color: PD.coral, seed: 71)
                Sheet(shape: Ellipse(), color: PD.butter, seed: 72, edge: 0.6)
                    .frame(width: w * 0.56, height: eh * 1.15)
                    .offset(y: eh * 0.04)
                    .mask(BalloonCut())
                Sheet(shape: Ellipse(), color: PD.mint, seed: 73, edge: 0.6)
                    .frame(width: w * 0.2, height: eh * 1.15)
                    .offset(y: eh * 0.04)
                    .mask(BalloonCut())
            }
            .frame(width: w, height: eh)
            .lifted(2.2)
            BasketRig(width: w)
        }
    }
}

struct BasketRig: View {
    var width: CGFloat
    var body: some View {
        let w = width
        VStack(spacing: 0) {
            Path { p in
                p.move(to: CGPoint(x: w * 0.36, y: 0)); p.addLine(to: CGPoint(x: w * 0.41, y: w * 0.2))
                p.move(to: CGPoint(x: w * 0.64, y: 0)); p.addLine(to: CGPoint(x: w * 0.59, y: w * 0.2))
            }
            .stroke(PD.twine, lineWidth: 0.7)
            .frame(width: w, height: w * 0.2)
            Sheet(shape: RoundedRectangle(cornerRadius: 1.2), color: PD.kraft, seed: 74, edge: 0.6)
                .overlay(Rectangle().fill(Color(hex: 0x8E6440).opacity(0.5)).frame(height: 0.6))
                .frame(width: w * 0.24, height: w * 0.17)
        }
        .lifted(1.6)
    }
}

/// Hole-punch confetti strewn on the meadow, like little flowers.
struct Confetti: View {
    var rect: CGRect
    var count: Int
    var seed: UInt64
    var size: CGSize

    var body: some View {
        let dots = makeDots()
        ZStack(alignment: .topLeading) {
            ForEach(dots.indices, id: \.self) { i in
                Sheet(shape: Circle(), color: dots[i].color, seed: UInt64(i) &+ seed, grain: 0.5, edge: 0.5)
                    .frame(width: dots[i].d, height: dots[i].d)
                    .position(dots[i].p)
            }
        }
        .frame(width: size.width, height: size.height)
        .lifted(0.6)
    }

    private func makeDots() -> [(p: CGPoint, d: CGFloat, color: Color)] {
        var rng = SeededRandom(seed: seed)
        let palette = [PD.butter, PD.snow, PD.coral, PD.peach, PD.snow, PD.butter]
        return (0..<count).map { i in
            let p = CGPoint(x: (rect.minX + rng.unit() * rect.width) * size.width,
                            y: (rect.minY + rng.unit() * rect.height) * size.height)
            return (p, rng.range(2.6...4), palette[i % palette.count])
        }
    }
}

struct TuftCut: Shape {
    func path(in r: CGRect) -> Path {
        let blades: [(CGFloat, CGFloat)] = [(0.0, 0.55), (0.18, 0.95), (0.42, 0.7), (0.6, 1.0), (0.85, 0.6), (1.0, 0.4)]
        var pts: [CGPoint] = [CGPoint(x: r.minX, y: r.maxY)]
        for (i, b) in blades.enumerated() {
            pts.append(CGPoint(x: r.minX + r.width * b.0, y: r.maxY - r.height * b.1))
            if i < blades.count - 1 {
                let nx = (b.0 + blades[i + 1].0) / 2
                pts.append(CGPoint(x: r.minX + r.width * nx, y: r.maxY - r.height * 0.15))
            }
        }
        pts.append(CGPoint(x: r.maxX, y: r.maxY))
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }
}

struct TuftsView: View {
    var points: [CGPoint]
    var color: Color
    var height: CGFloat
    var size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(points.indices, id: \.self) { i in
                Sheet(shape: TuftCut(), color: color, seed: UInt64(i + 40), edge: 0.6)
                    .frame(width: height * 1.1, height: height)
                    .position(x: points[i].x * size.width, y: points[i].y * size.height - height / 2)
            }
        }
        .frame(width: size.width, height: size.height)
        .lifted(1)
    }
}

// MARK: - Weather glyph

/// The weather as paper cut-outs: sun, moon, clouds, and drops, flakes or a bolt under them.
struct WeatherGlyph: View {
    var symbol: String
    var d: CGFloat
    var compact = false

    var body: some View {
        ZStack {
            if symbol.hasPrefix("sun") || symbol.contains(".sun") {
                PaperSun(d: d).offset(x: symbol.hasPrefix("cloud") ? d * 0.25 : 0, y: symbol.hasPrefix("cloud") ? -d * 0.2 : 0)
            }
            if symbol.contains("moon") {
                PaperMoon(d: d)
            }
            if symbol.hasPrefix("cloud") {
                Precipitation(symbol: symbol, d: d).offset(y: d * 0.55)
                PaperCloud(width: d * 1.4, seed: 5).offset(x: -d * 0.12, y: d * 0.15)
            } else if symbol == "sun.min.fill" && !compact {
                PaperCloud(width: d * 0.95, seed: 6).offset(x: -d * 0.55, y: d * 0.42)
            }
        }
        .frame(width: d * 1.8, height: d * 1.8)
    }
}

struct PaperMoon: View {
    var d: CGFloat
    var body: some View {
        Sheet(shape: CrescentCut(), color: PD.butter, seed: 35)
            .frame(width: d, height: d)
            .lifted(1.5)
    }
}

struct CrescentCut: Shape {
    func path(in r: CGRect) -> Path {
        Path(ellipseIn: r).subtracting(Path(ellipseIn: r.offsetBy(dx: r.width * 0.32, dy: -r.height * 0.18)))
    }
}

struct Precipitation: View {
    var symbol: String
    var d: CGFloat
    var body: some View {
        HStack(spacing: d * 0.18) {
            ForEach(0..<3, id: \.self) { i in
                bit.offset(y: i == 1 ? d * 0.12 : 0)
            }
        }
    }

    @ViewBuilder private var bit: some View {
        if symbol.contains("snow") {
            Sheet(shape: Circle(), color: PD.snow, seed: 81).frame(width: d * 0.2, height: d * 0.2).lifted(0.8)
        } else if symbol.contains("bolt") {
            Sheet(shape: CutPolygon(points: [CGPoint(x: 0.6, y: 0), CGPoint(x: 0.15, y: 0.55), CGPoint(x: 0.5, y: 0.55),
                                             CGPoint(x: 0.35, y: 1), CGPoint(x: 0.9, y: 0.4), CGPoint(x: 0.55, y: 0.4)], wobble: 0),
                  color: PD.butter, seed: 82)
                .frame(width: d * 0.3, height: d * 0.45).lifted(0.8)
        } else if symbol.contains("rain") || symbol.contains("drizzle") {
            Sheet(shape: CutPolygon(points: [CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0.68), CGPoint(x: 0.5, y: 1), CGPoint(x: 0, y: 0.68)], wobble: 0),
                  color: Color(hex: 0x6FB3DA), seed: 83)
                .frame(width: d * 0.18, height: d * 0.3).lifted(0.8)
        } else if symbol.contains("fog") {
            Sheet(shape: Capsule(), color: PD.snow, seed: 84).frame(width: d * 0.35, height: d * 0.1).lifted(0.6)
        }
    }
}

// MARK: - The box

/// The shadowbox: a cream mat around the window, and the walls of the box shading the scene's edges.
struct ShadowboxRim: View {
    var size: CGSize
    var mat: CGFloat = 5

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Mock.cornerRadius, style: .continuous)
        ZStack {
            shape.stroke(PD.shadow.opacity(0.35), lineWidth: 16)
                .blur(radius: 9)
                .offset(y: 4)
            Sheet(shape: MatCut(width: mat), color: PD.cream, seed: 90, grain: 0.8, edge: 1, tooth: 0.9)
                .lifted(1.6)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

struct MatCut: Shape {
    var width: CGFloat
    func path(in r: CGRect) -> Path {
        let outer = Path(roundedRect: r.insetBy(dx: -4, dy: -4), cornerRadius: Mock.cornerRadius + 4, style: .continuous)
        let inner = Path(roundedRect: r.insetBy(dx: width, dy: width), cornerRadius: Mock.cornerRadius - width + 1, style: .continuous)
        return outer.subtracting(inner)
    }
}
