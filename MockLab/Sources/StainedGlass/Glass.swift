import SwiftUI

// The leaded-glass engine: panes of backlit jewel glass, lead cames with a specular line, solder joints,
// cabochon jewels, and a bloom pass where the light spills over the lead. Pure SwiftUI (Canvas + Path).

/// One sheet of glass: a luminous core where the light comes through thinnest, darkening to the thick edge.
struct Glass {
    var hi: Color
    var core: Color
    var edge: Color

    init(_ hi: UInt32, _ core: UInt32, _ edge: UInt32) {
        self.hi = Color(hex: hi)
        self.core = Color(hex: core)
        self.edge = Color(hex: edge)
    }

    // Jewel tones
    static let cobalt = Glass(0x9cc4ff, 0x2a5fd6, 0x081a5e)
    static let sapphire = Glass(0xbfe3ff, 0x3f8ee8, 0x0c2f78)
    static let ultramarine = Glass(0x8fa6ff, 0x2b3fc4, 0x0b0f52)
    static let violet = Glass(0xd9b8ff, 0x7a45d6, 0x25095e)
    static let amethyst = Glass(0xf0c4ff, 0x9a4fc9, 0x3a0f5c)
    static let emerald = Glass(0xb6ffcf, 0x1fa65f, 0x053a1d)
    static let jade = Glass(0xc4fff0, 0x23a99a, 0x053c3c)
    static let olive = Glass(0xf0ffb0, 0x7fa82a, 0x243c06)
    static let amber = Glass(0xfff3b8, 0xf2a31f, 0x7a3304)
    static let gold = Glass(0xfffbe0, 0xffd34d, 0xb8650a)
    static let sun = Glass(0xffffff, 0xfff0a0, 0xe8920f)
    static let ruby = Glass(0xffc2b8, 0xe0213c, 0x5c0412)
    static let garnet = Glass(0xff9aa8, 0xa8102e, 0x3a020c)
    static let rose = Glass(0xffd8ea, 0xe0558f, 0x6a0e3a)
    static let skyPale = Glass(0xf0fbff, 0x86c8f2, 0x1d5694)
    // Mountain glass: heather on the lit faces, indigo in shadow, dusk at the foot
    static let heather = Glass(0xffeaf6, 0xcf8fd8, 0x5a2372)
    static let indigo = Glass(0xc8bcff, 0x5b45bd, 0x170b4f)
    static let dusk = Glass(0xa98ad6, 0x3f2378, 0x12052c)
    static let pine = Glass(0x9ff0c0, 0x167a4a, 0x03261a)
    // Snow and pale panels
    static let opal = Glass(0xffffff, 0xeef3ff, 0x9aa8c8)
    static let opalShade = Glass(0xf2f4ff, 0xb9c6e8, 0x5d6b9a)
    static let clear = Glass(0xfffef7, 0xf7f0db, 0xcdbf9a)
    static let clearCeladon = Glass(0xfdfff9, 0xedf2e0, 0xbac6a4)
    static let clearAmber = Glass(0xfffcf2, 0xf8edd2, 0xd1b98a)
    static let clearRose = Glass(0xfff8f6, 0xf8e3dc, 0xd2a69c)
    static let clearBlue = Glass(0xfbfdff, 0xe9eff6, 0xaebccc)
}

enum GlassTexture { case streaky, hammered, cathedral, none }

/// A cut piece of glass. `light` is where the glow is brightest; `reach` scales the glow radius.
struct Pane {
    var path: Path
    var glass: Glass
    var light: CGPoint
    var reach: CGFloat = 0.85
    var texture: GlassTexture = .streaky
    var texAngle: Double = 0
    var texShift: CGPoint = .zero
    var texStrength: Double = 0.55
    var bloom: Double = 0
    var lead: CGFloat = 2.6
    var corners: [CGPoint] = []
    var rim: Double = 0.85
}

/// A cabochon jewel set in a lead ring.
struct Jewel {
    var center: CGPoint
    var radius: CGFloat
    var glass: Glass
    var lead: CGFloat = 1.8
    var bloom: Double = 0.5
}

enum Piece {
    case pane(Pane)
    case lead(Path, CGFloat)
    case jewel(Jewel)
    case paint(Path, CGFloat)   // grisaille trace lines fired onto the glass
}

/// A whole window: scene pieces, then a lighting pass, then front pieces (panels sit above the lighting).
struct Window {
    var scene: [Piece] = []
    var front: [Piece] = []
    var backlight: CGPoint? = nil
    var backlightRadius: CGFloat = 300
    var vignette: Double = 0.45
    var bloomRadius: CGFloat = 7
    var solder: Bool = true

    mutating func add(_ p: Pane, front isFront: Bool = false) {
        if isFront { front.append(.pane(p)) } else { scene.append(.pane(p)) }
    }
    mutating func lead(_ path: Path, _ w: CGFloat = 2.4, front isFront: Bool = false) {
        if isFront { front.append(.lead(path, w)) } else { scene.append(.lead(path, w)) }
    }
    mutating func jewel(_ j: Jewel, front isFront: Bool = true) {
        if isFront { front.append(.jewel(j)) } else { scene.append(.jewel(j)) }
    }
    mutating func paint(_ path: Path, _ w: CGFloat = 0.8, front isFront: Bool = false) {
        if isFront { front.append(.paint(path, w)) } else { scene.append(.paint(path, w)) }
    }
}

enum Lead {
    static let dark = Color(hex: 0x0c0b0a)
    static let body = Color(hex: 0x34302b)
    static let shine = Color(hex: 0xb5ada1)
}

struct GlassTextures {
    var streaky: GraphicsContext.ResolvedImage
    var hammered: GraphicsContext.ResolvedImage
    var cathedral: GraphicsContext.ResolvedImage

    init(_ ctx: GraphicsContext) {
        streaky = ctx.resolve(Mock.texture("stained-glass/streaky"))
        hammered = ctx.resolve(Mock.texture("stained-glass/hammered"))
        cathedral = ctx.resolve(Mock.texture("stained-glass/cathedral"))
    }

    func image(_ t: GlassTexture) -> GraphicsContext.ResolvedImage? {
        switch t {
        case .streaky: return streaky
        case .hammered: return hammered
        case .cathedral: return cathedral
        case .none: return nil
        }
    }
}

enum GlassRenderer {
    static func render(_ w: Window, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let full = CGRect(origin: .zero, size: size)
        ctx.fill(Path(full), with: .color(Lead.dark))
        let tex = GlassTextures(ctx)
        for piece in w.scene { draw(piece, &ctx, tex, size) }
        lighting(w, &ctx, size)
        for piece in w.front { draw(piece, &ctx, tex, size) }
        bloom(w, &ctx)
        if w.solder { solderJoints(w, &ctx, size) }
    }

    static func draw(_ piece: Piece, _ ctx: inout GraphicsContext, _ tex: GlassTextures, _ size: CGSize) {
        switch piece {
        case .pane(let p):
            fill(p, &ctx, tex, size)
            lead(p.path, p.lead, &ctx)
        case .lead(let path, let w):
            lead(path, w, &ctx)
        case .jewel(let j):
            jewel(j, &ctx)
        case .paint(let path, let w):
            var g = ctx
            g.blendMode = .multiply
            g.addFilter(.blur(radius: 0.35))
            g.stroke(path, with: .color(Color(hex: 0x2a1530).opacity(0.5)), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        }
    }

    static func fill(_ p: Pane, _ ctx: inout GraphicsContext, _ tex: GlassTextures, _ size: CGSize) {
        let b = p.path.boundingRect
        guard b.width > 0.5, b.height > 0.5 else { return }
        ctx.drawLayer { l in
            l.clip(to: p.path)
            let r = max(b.width, b.height) * p.reach
            let grad = Gradient(stops: [
                .init(color: p.glass.hi, location: 0),
                .init(color: p.glass.core, location: 0.32),
                .init(color: p.glass.edge, location: 1)
            ])
            l.fill(Path(b.insetBy(dx: -3, dy: -3)), with: .radialGradient(grad, center: p.light, startRadius: 0, endRadius: max(r, 8)))
            if let img = tex.image(p.texture) {
                var t = l
                t.blendMode = .overlay
                t.opacity = p.texStrength
                t.translateBy(x: b.midX, y: b.midY)
                t.rotate(by: .degrees(p.texAngle))
                let side = max(size.width, size.height) * 1.5
                t.draw(img, in: CGRect(x: -side / 2 + p.texShift.x, y: -side / 2 + p.texShift.y, width: side, height: side * 380 / 360))
            }
            // thick glass at the edges: darker toward the lead, scaled so small pieces still glow
            let minDim = min(b.width, b.height)
            var rim = l
            rim.addFilter(.blur(radius: min(2.6, max(0.8, minDim * 0.16))))
            rim.stroke(p.path, with: .color(p.glass.edge.opacity(p.rim)), lineWidth: min(7, max(2.2, minDim * 0.42)))
            // bevel: light catching the upper-left edge of the cut glass just inside the came
            var bevel = l
            bevel.translateBy(x: 1.0, y: 1.1)
            bevel.addFilter(.blur(radius: 0.7))
            bevel.stroke(p.path, with: .color(.white.opacity(0.28 * Double(min(1, minDim / 16)))), lineWidth: p.lead + 2.0)
        }
    }

    static func lead(_ path: Path, _ w: CGFloat, _ ctx: inout GraphicsContext) {
        let style = { (lw: CGFloat) in StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round) }
        ctx.stroke(path, with: .color(Lead.dark), style: style(w + 0.9))
        ctx.stroke(path, with: .color(Lead.body), style: style(w * 0.58))
        var hl = ctx
        hl.translateBy(x: -w * 0.11, y: -w * 0.15)
        hl.stroke(path, with: .color(Lead.shine.opacity(0.55)), style: style(max(0.45, w * 0.16)))
    }

    static func jewel(_ j: Jewel, _ ctx: inout GraphicsContext) {
        let c = j.center, r = j.radius
        let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        // glow behind the jewel
        var glow = ctx
        glow.blendMode = .screen
        glow.addFilter(.blur(radius: r * 0.9))
        glow.fill(disc, with: .color(j.glass.core.opacity(j.bloom)))
        // the domed glass: light pools on the far (lower right) side, as in a backlit cabochon
        let grad = Gradient(stops: [
            .init(color: j.glass.hi, location: 0),
            .init(color: j.glass.core, location: 0.45),
            .init(color: j.glass.edge, location: 1)
        ])
        ctx.fill(disc, with: .radialGradient(grad, center: CGPoint(x: c.x + r * 0.25, y: c.y + r * 0.3), startRadius: 0, endRadius: r * 1.25))
        lead(disc, j.lead, &ctx)
        // specular highlight on the dome
        let s = CGRect(x: c.x - r * 0.62, y: c.y - r * 0.66, width: r * 0.62, height: r * 0.42)
        var spec = ctx
        spec.addFilter(.blur(radius: max(0.3, r * 0.08)))
        spec.fill(Path(ellipseIn: s), with: .color(.white.opacity(0.85)))
    }

    /// Uneven backlight: brighter around the light source, dimmer toward the corners.
    static func lighting(_ w: Window, _ ctx: inout GraphicsContext, _ size: CGSize) {
        guard let src = w.backlight else { return }
        let full = Path(CGRect(origin: .zero, size: size))
        var m = ctx
        m.blendMode = .multiply
        let k = w.vignette
        m.fill(full, with: .radialGradient(Gradient(colors: [
            .white, .white, Color(white: 1 - k * 0.55), Color(white: 1 - k)
        ]), center: src, startRadius: 0, endRadius: w.backlightRadius))
    }

    static func bloom(_ w: Window, _ ctx: inout GraphicsContext) {
        var g = ctx
        g.blendMode = .screen
        g.addFilter(.blur(radius: w.bloomRadius))
        g.drawLayer { l in
            for piece in w.scene + w.front {
                if case .pane(let p) = piece, p.bloom > 0 {
                    l.fill(p.path, with: .color(p.glass.core.opacity(p.bloom)))
                }
            }
        }
    }

    // MARK: solder

    static func solderJoints(_ w: Window, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let panes: [Pane] = (w.scene + w.front).compactMap { if case .pane(let p) = $0 { return p } else { return nil } }
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -1, dy: -1)
        var seen: [CGPoint] = []
        for (i, p) in panes.enumerated() {
            for c in p.corners where bounds.contains(c) {
                if seen.contains(where: { abs($0.x - c.x) < 1.5 && abs($0.y - c.y) < 1.5 }) { continue }
                if covered(c, by: panes[(i + 1)...]) { continue }
                seen.append(c)
                solder(at: c, r: max(1.6, p.lead * 0.78), &ctx)
            }
        }
    }

    /// True when the point and its neighbourhood lie under later panes (so the joint is hidden).
    static func covered(_ p: CGPoint, by later: ArraySlice<Pane>, _ d: CGFloat = 2.4) -> Bool {
        let probes = [p, CGPoint(x: p.x + d, y: p.y), CGPoint(x: p.x - d, y: p.y), CGPoint(x: p.x, y: p.y + d), CGPoint(x: p.x, y: p.y - d)]
        for q in probes where !later.contains(where: { $0.path.contains(q) }) { return false }
        return true
    }

    static func solder(at c: CGPoint, r: CGFloat, _ ctx: inout GraphicsContext) {
        let blob = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.9, width: r * 2, height: r * 1.8))
        ctx.fill(blob, with: .radialGradient(Gradient(colors: [Color(hex: 0x9b958b), Color(hex: 0x4a453f), Lead.dark]),
                                             center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.35), startRadius: 0, endRadius: r * 1.3))
    }
}

// MARK: - geometry helpers

enum Geo {
    static func poly(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }

    static func centroid(_ pts: [CGPoint]) -> CGPoint {
        let n = CGFloat(max(pts.count, 1))
        return CGPoint(x: pts.reduce(0) { $0 + $1.x } / n, y: pts.reduce(0) { $0 + $1.y } / n)
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    static func polar(_ c: CGPoint, _ r: CGFloat, _ deg: Double) -> CGPoint {
        let a = deg * .pi / 180
        return CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
    }

    /// Annular sector between radii r0...r1 and angles a0...a1 (degrees, clockwise on screen).
    static func sector(_ c: CGPoint, _ r0: CGFloat, _ r1: CGFloat, _ a0: Double, _ a1: Double) -> Path {
        var p = Path()
        p.addArc(center: c, radius: r1, startAngle: .degrees(a0), endAngle: .degrees(a1), clockwise: false)
        if r0 > 0.5 {
            p.addArc(center: c, radius: r0, startAngle: .degrees(a1), endAngle: .degrees(a0), clockwise: true)
        } else {
            p.addLine(to: c)
        }
        p.closeSubpath()
        return p
    }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}
