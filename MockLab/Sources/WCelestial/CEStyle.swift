import SwiftUI

// Celestial: an engraved instrument in navy lacquer and gold. Painted navy grounds (Textures/weather-celestial,
// make.py), raised brass rims brushed in circles, and gold engraving drawn as vectors: every engraved line is laid
// as a dark groove, the gold inlay, and a fine highlight on its upper-left lip, under one sheen that catches the
// light at the upper left of each instrument and dims toward the lower right.

// MARK: - Palette

enum CE {
    static let navyDeep   = Color(hex: 0x060C1F)
    static let navy       = Color(hex: 0x0E1A3B)
    static let lapis      = Color(hex: 0x1F4282)
    static let ink        = Color(hex: 0x02050D)   // engraving grooves, cast shadows
    static let goldBright = Color(hex: 0xF8E6B6)
    static let gold       = Color(hex: 0xE4C58F)   // engraving and numerals, ~9:1 on the lacquer
    static let goldMid    = Color(hex: 0xCBA868)
    static let goldDeep   = Color(hex: 0x9E7A40)
    static let goldMuted  = Color(hex: 0xCDB58C)   // secondary type, >= 6:1 on the lacquer
    static let parchment  = Color(hex: 0xEFE3CB)   // task text
    static let copperInk  = Color(hex: 0xEE9F70)   // late tasks and errors
    static let ember      = Color(hex: 0xF0B26A)   // the sun's glow at twilight
}

// MARK: - Type (iOS 17 system fonts)
// Didot for numerals (a high-contrast Didone, the Pinterest date-widget favourite), Copperplate for spaced engraved
// capitals (it was cut after engravers' lettering), Cochin for words (cut after the engraver Charles-Nicolas Cochin).

enum CEFont {
    static func numeral(_ s: CGFloat) -> Font { .custom("Didot", size: s) }
    static func caps(_ s: CGFloat) -> Font { .custom("Copperplate", size: s) }
    static func capsLight(_ s: CGFloat) -> Font { .custom("Copperplate-Light", size: s) }
    static func italic(_ s: CGFloat) -> Font { .custom("Cochin-Italic", size: s) }
    static func text(_ s: CGFloat) -> Font { .custom("Cochin", size: s) }
}

// MARK: - Gold

enum CEGold {
    /// Gold leaf for the big numerals: bright at the top of each figure, a band of light, deeper at the foot.
    static var leaf: LinearGradient {
        LinearGradient(stops: [.init(color: CE.goldBright, location: 0), .init(color: CE.gold, location: 0.38),
                               .init(color: CE.goldMid, location: 0.62), .init(color: CE.goldDeep, location: 0.86),
                               .init(color: CE.goldMid, location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Gold for small engraved type: a gentle top-to-foot fall.
    static var type: LinearGradient {
        LinearGradient(colors: [CE.goldBright, CE.gold, CE.goldMid], startPoint: .top, endPoint: .bottom)
    }

    /// The sheen across a whole instrument: the engraving catches the light at the upper left and dims to the lower
    /// right, with a glint a third of the way across.
    static func sheen(_ rect: CGRect, _ strength: Double = 1) -> GraphicsContext.Shading {
        let k = strength
        return .linearGradient(Gradient(stops: [
            .init(color: CE.gold.opacity(k), location: 0),
            .init(color: CE.goldBright.opacity(k), location: 0.3),
            .init(color: CE.gold.opacity(k), location: 0.46),
            .init(color: CE.goldMid.opacity(k), location: 0.78),
            .init(color: CE.goldDeep.opacity(k), location: 1)
        ]), startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY))
    }
}

extension View {
    /// Gold set into the lacquer: a hard dark lip under each stroke and a soft navy halo, so the type stands off
    /// the paint and reads over the brightest stars.
    func ceInlay(_ strength: Double = 1) -> some View {
        shadow(color: CE.ink.opacity(0.9 * strength), radius: 0.35, x: 0.35, y: 0.8)
            .shadow(color: CE.navyDeep.opacity(0.7 * strength), radius: 2.5, x: 0, y: 0)
    }

    /// The big gold-leaf numeral: raised, with a cut edge and a cast shadow.
    func ceRaisedLeaf() -> some View {
        shadow(color: Color(hex: 0x3B2709).opacity(0.95), radius: 0, x: 0.6, y: 0.9)
            .shadow(color: CE.ink.opacity(0.85), radius: 2.2, x: 1.2, y: 2.4)
    }
}

// MARK: - Engraving

enum CEEngrave {
    /// One engraved line: the groove's shadow, the gold, and a hairline of light on its upper-left lip.
    static func line(_ ctx: GraphicsContext, _ path: Path, width: CGFloat, shading: GraphicsContext.Shading,
                     light: Double = 1, groove: Double = 1) {
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        if groove > 0 {
            ctx.stroke(path.offsetBy(dx: 0.25 + 0.3 * width, dy: 0.35 + 0.45 * width),
                       with: .color(CE.ink.opacity(0.75 * groove)),
                       style: StrokeStyle(lineWidth: width + 0.35, lineCap: .round, lineJoin: .round))
        }
        ctx.stroke(path, with: shading, style: style)
        if light > 0 {
            ctx.stroke(path.offsetBy(dx: -0.15, dy: -0.2), with: .color(CE.goldBright.opacity(0.5 * light)),
                       style: StrokeStyle(lineWidth: max(0.25, width * 0.38), lineCap: .round, lineJoin: .round))
        }
    }

    /// Parallel hatching across `rect` at `angle` (radians, y down), `spacing` apart. With `dash`, each line is broken
    /// into strokes of random length (on) with random gaps (off), the way a burin lifts.
    static func hatch(_ rect: CGRect, angle: Double, spacing: CGFloat, dash: (on: ClosedRange<CGFloat>, off: ClosedRange<CGFloat>)? = nil,
                      jitter: CGFloat = 0.25, seed: UInt64) -> Path {
        let d = CGVector(dx: cos(angle), dy: sin(angle))
        let n = CGVector(dx: -d.dy, dy: d.dx)
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let reach = hypot(rect.width, rect.height) / 2 + 2
        var rng = SeededRandom(seed)
        var p = Path()
        var k = -reach
        while k <= reach {
            let o = CGPoint(x: c.x + n.dx * k, y: c.y + n.dy * k)
            if let dash {
                var t = -reach + CGFloat(rng.next()) * dash.off.upperBound
                while t < reach {
                    let on = dash.on.lowerBound + CGFloat(rng.next()) * (dash.on.upperBound - dash.on.lowerBound)
                    let a = CGPoint(x: o.x + d.dx * t, y: o.y + d.dy * t)
                    let b = CGPoint(x: o.x + d.dx * (t + on), y: o.y + d.dy * (t + on))
                    p.move(to: a)
                    p.addLine(to: b)
                    t += on + dash.off.lowerBound + CGFloat(rng.next()) * (dash.off.upperBound - dash.off.lowerBound)
                }
            } else {
                p.move(to: CGPoint(x: o.x - d.dx * reach, y: o.y - d.dy * reach))
                p.addLine(to: CGPoint(x: o.x + d.dx * reach, y: o.y + d.dy * reach))
            }
            k += spacing * (1 - jitter / 2 + jitter * CGFloat(rng.next()))
        }
        return p
    }

    /// A circle as a path.
    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    /// An arc of the circle (c, r) from `a0` to `a1` (degrees, 0 = right, clockwise with y down).
    static func arc(_ c: CGPoint, _ r: CGFloat, _ a0: Double, _ a1: Double) -> Path {
        var p = Path()
        p.addArc(center: c, radius: r, startAngle: .degrees(a0), endAngle: .degrees(a1), clockwise: false)
        return p
    }

    static func point(_ c: CGPoint, _ r: CGFloat, _ deg: Double) -> CGPoint {
        CGPoint(x: c.x + r * CGFloat(cos(deg * .pi / 180)), y: c.y + r * CGFloat(sin(deg * .pi / 180)))
    }

    /// A four- or eight-pointed engraved star.
    static func star(_ c: CGPoint, _ r: CGFloat, points: Int = 4, pinch: CGFloat = 0.22) -> Path {
        var p = Path()
        let n = points * 2
        for i in 0..<n {
            let a = -Double.pi / 2 + Double(i) * Double.pi / Double(points)
            let rr = i % 2 == 0 ? (points == 8 && (i / 2) % 2 == 1 ? r * 0.55 : r) : r * pinch
            let pt = CGPoint(x: c.x + rr * CGFloat(cos(a)), y: c.y + rr * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// A soft round glow.
    static func glow(_ ctx: GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ color: Color, _ opacity: Double) {
        let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), color.opacity(0)]),
                                                             center: c, startRadius: 0, endRadius: r))
    }
}

// MARK: - Shapes in widget coordinates

/// A fixed path as a Shape (all the instrument's parts are laid out in the widget's own points).
struct CEPathShape: Shape {
    var path: Path
    func path(in rect: CGRect) -> Path { path }
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CEPathShape { CEPathShape(path: path.offsetBy(dx: dx, dy: dy)) }
}

// MARK: - Materials

/// The painted navy lacquer ground (1 px per point).
struct CELacquer: View {
    var family: Family
    var body: some View {
        Mock.texture("weather-celestial/lacquer-\(family.rawValue)")
            .resizable()
            .interpolation(.high)
    }
}

/// A raised brass rim: the band between `outer` and `inner` (even-odd), cut from the brushed brass disc centred on
/// `center`, lit as a rounded bead from the upper left (outer lip bright at the upper left, inner lip bright at the
/// lower right), with a specular hairline along its crest, and casting its shadow outward onto the ground and inward
/// onto the recessed plate.
struct CEBrassRim: View {
    var outer: Path
    var inner: Path
    var crest: Path          // the line along the top of the bead
    var center: CGPoint
    var radius: CGFloat      // the brass disc's radius
    var plate: Path          // the recess the rim shades
    var size: CGSize
    var groove: Path? = nil  // a turned groove cut round the bead

    var body: some View {
        var band = outer
        band.addPath(inner)
        let ring = CEPathShape(path: band)
        let eo = FillStyle(eoFill: true)
        return ZStack {
            // Shadow cast onto the ground round the instrument.
            CEPathShape(path: outer)
                .fill(CE.ink.opacity(0.75))
                .blur(radius: 4)
                .offset(x: 1.5, y: 3.5)
                .clipShape(CEPathShape(path: { var p = Path(CGRect(x: -20, y: -20, width: size.width + 40, height: size.height + 40)); p.addPath(outer); return p }()),
                           style: FillStyle(eoFill: true))
            // Shadow cast into the recess under the rim's inner lip (light from the upper left).
            CEPathShape(path: inner)
                .stroke(CE.ink.opacity(0.85), lineWidth: 7)
                .blur(radius: 3)
                .offset(x: 1.4, y: 2.6)
                .clipShape(CEPathShape(path: plate))
            // The brass itself.
            Mock.texture("weather-celestial/brass")
                .resizable()
                .interpolation(.high)
                .frame(width: radius * 2, height: radius * 2)
                .position(center)
                .frame(width: size.width, height: size.height)
                .clipShape(ring, style: eo)
            // The bead's light: the outer half lit at the upper left, the inner half at the lower right.
            ZStack {
                LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.0), .black.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .mask(CEPathShape(path: outer).stroke(Color.black, lineWidth: 5).blur(radius: 1.2))
                LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0.0), .white.opacity(0.45)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .mask(CEPathShape(path: inner).stroke(Color.black, lineWidth: 4).blur(radius: 1.0))
            }
            .blendMode(.overlay)
            .clipShape(ring, style: eo)
            // Crisp lips and the specular crest.
            CEPathShape(path: outer).stroke(LinearGradient(colors: [CE.goldBright.opacity(0.8), Color(hex: 0x3A2608).opacity(0.9)],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.6)
            CEPathShape(path: inner).stroke(LinearGradient(colors: [Color(hex: 0x2A1B06).opacity(0.95), CE.goldBright.opacity(0.7)],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.6)
            if let groove {
                CEPathShape(path: groove).stroke(Color(hex: 0x2A1B06).opacity(0.75), lineWidth: 0.7)
                CEPathShape(path: groove).offsetBy(dx: 0.35, dy: 0.5).stroke(CE.goldBright.opacity(0.4), lineWidth: 0.4)
            }
            CEPathShape(path: crest).stroke(LinearGradient(stops: [.init(color: .white.opacity(0.75), location: 0),
                                                                   .init(color: .white.opacity(0.0), location: 0.45),
                                                                   .init(color: .white.opacity(0.0), location: 0.75),
                                                                   .init(color: .white.opacity(0.35), location: 1)],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7)
                .blendMode(.screen)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Small slotted brass screws holding the instrument to its board: a domed head lit from the upper left, its slot
/// turned to a different angle on each, casting a short shadow.
struct CEScrews: View {
    var points: [CGPoint]
    var radius: CGFloat
    var size: CGSize

    var body: some View {
        Canvas { ctx, _ in
            for (i, c) in points.enumerated() {
                let r = radius
                ctx.fill(CEEngrave.circle(CGPoint(x: c.x + 0.5, y: c.y + 1.1), r + 0.4), with: .color(CE.ink.opacity(0.7)))
                ctx.fill(CEEngrave.circle(c, r), with: .radialGradient(Gradient(colors: [Color(hex: 0xF6E2AC), Color(hex: 0xB8904A), Color(hex: 0x5A3E17)]),
                                                                      center: CGPoint(x: c.x - 0.35 * r, y: c.y - 0.4 * r), startRadius: 0, endRadius: r * 1.5))
                ctx.stroke(CEEngrave.circle(c, r), with: .color(Color(hex: 0x2E1F08).opacity(0.85)), lineWidth: 0.45)
                let a = [0.6, 2.1, 1.2, 2.7][i % 4]
                let d = CGVector(dx: cos(a) * r * 0.78, dy: sin(a) * r * 0.78)
                var slot = Path()
                slot.move(to: CGPoint(x: c.x - d.dx, y: c.y - d.dy))
                slot.addLine(to: CGPoint(x: c.x + d.dx, y: c.y + d.dy))
                ctx.stroke(slot, with: .color(Color(hex: 0x24170A)), style: StrokeStyle(lineWidth: max(0.6, r * 0.26), lineCap: .butt))
                ctx.stroke(slot.offsetBy(dx: 0.25, dy: 0.45), with: .color(CE.goldBright.opacity(0.45)), style: StrokeStyle(lineWidth: max(0.25, r * 0.08)))
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}
