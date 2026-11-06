import SwiftUI

// Foreground props and the proscenium. Each is one Canvas (plus its Text), lit from the upper left with a contact
// shadow, so it reads as an object standing in front of the painted backdrop.

// MARK: - Geometry helpers

enum AHGeo {
    /// Lower half of an ellipse as a polyline (left to right), for scallop trims.
    static func lowerArc(_ e: CGRect, steps: Int = 14) -> Path {
        var p = Path()
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let a = Double.pi * (1 - t)
            let pt = CGPoint(x: e.midX + CGFloat(cos(a)) * e.width / 2, y: e.midY + CGFloat(sin(a)) * e.height / 2)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    /// A point on a dial: `deg` in the math convention (0 = right, 90 = up), y pointing down on screen.
    static func polar(_ c: CGPoint, _ r: CGFloat, _ deg: Double) -> CGPoint {
        CGPoint(x: c.x + CGFloat(cos(deg * .pi / 180)) * r, y: c.y - CGFloat(sin(deg * .pi / 180)) * r)
    }

    /// Text set around a circle, centred on the top (or the bottom, reading left to right).
    static func arcText(_ ctx: GraphicsContext, _ string: String, font: Font, color: Color, center c: CGPoint, radius r: CGFloat,
                        tracking: CGFloat, bottom: Bool = false) {
        let glyphs = string.map { ctx.resolve(Text(String($0)).font(font).foregroundColor(color)) }
        let widths = glyphs.map { $0.measure(in: CGSize(width: 200, height: 200)).width }
        let total = widths.reduce(0, +) + tracking * CGFloat(max(0, glyphs.count - 1))
        var a = bottom ? (Double.pi / 2 + Double(total / r) / 2) : (-Double.pi / 2 - Double(total / r) / 2)
        for (g, w) in zip(glyphs, widths) {
            let step = Double((w / 2) / r)
            a += bottom ? -step : step
            var c2 = ctx
            c2.translateBy(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            c2.rotate(by: .radians(bottom ? a - .pi / 2 : a + .pi / 2))
            c2.draw(g, at: .zero, anchor: .center)
            a += bottom ? -(step + Double(tracking / r)) : (step + Double(tracking / r))
        }
    }
}

// MARK: - Proscenium

/// A raspberry velvet valance with scalloped, gold-edged swags, pleats, a gilt rod and tassels. Casts a soft shadow.
struct AHValance: View {
    var depth: CGFloat
    var scallops: Int

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let band = depth * 0.46
            let r = w / CGFloat(scallops) / 2
            let drop = depth - band
            var shape = Path(CGRect(x: 0, y: 0, width: w, height: band))
            var arcs = Path()
            var swags: [CGRect] = []
            for i in 0..<scallops {
                let cx = r * CGFloat(2 * i + 1)
                let e = CGRect(x: cx - r, y: band - drop, width: 2 * r, height: 2 * drop)
                swags.append(e)
                shape.addEllipse(in: e)
                arcs.addPath(AHGeo.lowerArc(e))
            }
            var sh = ctx
            sh.addFilter(.blur(radius: 2.4))
            sh.fill(shape.offsetBy(dx: 0, dy: 2.6), with: .color(AH.plum.opacity(0.5)))
            ctx.fill(shape, with: .linearGradient(Gradient(colors: [AH.raspberryDeep, AH.raspberry, Color(hex: 0xC6476D)]),
                                                  startPoint: .zero, endPoint: CGPoint(x: 0, y: depth)))
            var v = ctx
            v.clip(to: shape)
            for e in swags {
                // pleats: dark at the gathers, a soft sheen in the belly of each swag
                v.fill(Path(CGRect(x: e.minX, y: 0, width: e.width, height: depth)),
                       with: .linearGradient(Gradient(stops: [.init(color: AH.raspberryDeep.opacity(0.75), location: 0),
                                                              .init(color: .clear, location: 0.3), .init(color: .clear, location: 0.7),
                                                              .init(color: AH.raspberryDeep.opacity(0.75), location: 1)]),
                                             startPoint: CGPoint(x: e.minX, y: 0), endPoint: CGPoint(x: e.maxX, y: 0)))
                v.fill(Path(ellipseIn: e), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFD3E0, opacity: 0.45), .clear]),
                                                                center: CGPoint(x: e.midX - e.width * 0.12, y: band + drop * 0.25),
                                                                startRadius: 0, endRadius: e.width * 0.5))
                var folds = Path()
                for k in [-0.22, 0.0, 0.22] {
                    folds.move(to: CGPoint(x: e.midX + e.width * k * 1.6, y: 0))
                    folds.addQuadCurve(to: CGPoint(x: e.midX + e.width * k, y: band + drop * 0.85), control: CGPoint(x: e.midX + e.width * k * 1.2, y: band))
                }
                v.stroke(folds, with: .color(AH.raspberryDeep.opacity(0.35)), lineWidth: 0.8)
            }
            AHTex.lay(v, AHTex.paper, in: CGRect(x: 0, y: 0, width: w, height: depth), opacity: 0.8)
            // gilt rod and braid
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: max(2, depth * 0.1))),
                     with: .linearGradient(Gradient(colors: [AH.goldLight, AH.gold, AH.goldDeep]), startPoint: .zero, endPoint: CGPoint(x: 0, y: depth * 0.1)))
            var braid = Path()
            var bx: CGFloat = 1
            while bx < w { braid.addEllipse(in: CGRect(x: bx, y: band * 0.78, width: 1.6, height: 1.1)); bx += 2.6 }
            ctx.fill(braid, with: .color(AH.goldLight))
            ctx.stroke(arcs.offsetBy(dx: 0, dy: -0.8), with: .color(AH.goldLight), lineWidth: 0.9)
            ctx.stroke(arcs, with: .color(AH.goldDeep), lineWidth: 0.6)
            // tassels at the gathers
            for i in 1..<scallops {
                let x = r * CGFloat(2 * i)
                var cord = Path()
                cord.move(to: CGPoint(x: x, y: band * 0.8))
                cord.addLine(to: CGPoint(x: x, y: band + drop * 0.35))
                ctx.stroke(cord, with: .color(AH.goldDeep), lineWidth: 0.7)
                let tw = max(2.6, depth * 0.13), th = max(4, depth * 0.24)
                let head = CGRect(x: x - tw * 0.32, y: band + drop * 0.3, width: tw * 0.64, height: tw * 0.6)
                ctx.fill(Path(ellipseIn: head), with: .color(AH.gold))
                var skirt = Path()
                skirt.move(to: CGPoint(x: x - tw * 0.25, y: head.maxY - 0.4))
                skirt.addLine(to: CGPoint(x: x + tw * 0.25, y: head.maxY - 0.4))
                skirt.addLine(to: CGPoint(x: x + tw * 0.5, y: head.maxY + th))
                skirt.addLine(to: CGPoint(x: x - tw * 0.5, y: head.maxY + th))
                skirt.closeSubpath()
                ctx.fill(skirt, with: .linearGradient(Gradient(colors: [AH.goldLight, AH.gold, AH.goldDeep]),
                                                      startPoint: CGPoint(x: x - tw * 0.5, y: 0), endPoint: CGPoint(x: x + tw * 0.5, y: 0)))
            }
        }
        .frame(height: depth + 6, alignment: .top)
    }
}

/// Side curtains drawn open and tied back with gold cord: the proscenium's wings.
struct AHCurtains: View {
    var width: CGFloat    // of each curtain at the top
    var tie: CGFloat      // tie-back height, fraction of the height

    var body: some View {
        Canvas { ctx, size in
            for side in [CGFloat(1), -1] {
                var c = ctx
                if side < 0 { c.translateBy(x: size.width, y: 0); c.scaleBy(x: -1, y: 1) }
                AHCurtains.drawOne(c, size: size, width: width, tie: tie)
            }
        }
    }

    static func drawOne(_ ctx: GraphicsContext, size: CGSize, width cw: CGFloat, tie: CGFloat) {
        let ty = size.height * tie
        var p = Path()
        p.move(to: CGPoint(x: -2, y: 0))
        p.addLine(to: CGPoint(x: cw, y: 0))
        p.addCurve(to: CGPoint(x: cw * 0.42, y: ty), control1: CGPoint(x: cw * 0.95, y: ty * 0.45), control2: CGPoint(x: cw * 0.42, y: ty * 0.8))
        p.addCurve(to: CGPoint(x: cw * 0.9, y: size.height + 2), control1: CGPoint(x: cw * 0.42, y: ty + (size.height - ty) * 0.4), control2: CGPoint(x: cw * 0.8, y: size.height * 0.92))
        p.addLine(to: CGPoint(x: -2, y: size.height + 2))
        p.closeSubpath()
        var sh = ctx
        sh.addFilter(.blur(radius: 3))
        sh.fill(p.offsetBy(dx: 3, dy: 1), with: .color(AH.plum.opacity(0.45)))
        var stops: [Gradient.Stop] = []
        let pleats = 5
        for i in 0...pleats * 2 {
            let t = CGFloat(i) / CGFloat(pleats * 2)
            stops.append(.init(color: i % 2 == 0 ? AH.raspberryDeep : Color(hex: 0xCB4F75), location: t))
        }
        ctx.fill(p, with: .linearGradient(Gradient(stops: stops), startPoint: .zero, endPoint: CGPoint(x: cw * 0.95, y: 0)))
        var l = ctx
        l.clip(to: p)
        l.fill(Path(CGRect(x: 0, y: 0, width: cw, height: size.height)),
               with: .linearGradient(Gradient(colors: [Color.white.opacity(0.12), .clear, AH.plum.opacity(0.25)]),
                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        AHTex.lay(l, AHTex.paper, in: CGRect(origin: .zero, size: size), opacity: 0.9)
        // gold edge braid on the inner hem
        var hem = Path()
        hem.move(to: CGPoint(x: cw, y: 0))
        hem.addCurve(to: CGPoint(x: cw * 0.42, y: ty), control1: CGPoint(x: cw * 0.95, y: ty * 0.45), control2: CGPoint(x: cw * 0.42, y: ty * 0.8))
        hem.addCurve(to: CGPoint(x: cw * 0.9, y: size.height + 2), control1: CGPoint(x: cw * 0.42, y: ty + (size.height - ty) * 0.4), control2: CGPoint(x: cw * 0.8, y: size.height * 0.92))
        ctx.stroke(hem.offsetBy(dx: -1.2, dy: 0), with: .color(AH.goldLight), lineWidth: 1.2)
        ctx.stroke(hem.offsetBy(dx: -2.3, dy: 0), with: .color(AH.goldDeep.opacity(0.7)), lineWidth: 0.5)
        // tie-back cord and tassel
        let knot = CGPoint(x: cw * 0.42, y: ty)
        var cord = Path()
        cord.move(to: CGPoint(x: -2, y: ty - 5))
        cord.addQuadCurve(to: CGPoint(x: knot.x + 2.5, y: ty), control: CGPoint(x: knot.x * 0.5, y: ty + 4))
        ctx.stroke(cord, with: .color(AH.goldDeep), lineWidth: 2.4)
        ctx.stroke(cord, with: .color(AH.goldLight), lineWidth: 1.1)
        ctx.fill(Path(ellipseIn: CGRect(x: knot.x - 0.5, y: ty - 2.6, width: 5.6, height: 5.2)), with: .color(AH.gold))
        var tassel = Path()
        tassel.move(to: CGPoint(x: knot.x + 1.2, y: ty + 2))
        tassel.addLine(to: CGPoint(x: knot.x + 3.8, y: ty + 2))
        tassel.addLine(to: CGPoint(x: knot.x + 5.6, y: ty + 13))
        tassel.addLine(to: CGPoint(x: knot.x - 0.6, y: ty + 13))
        tassel.closeSubpath()
        ctx.fill(tassel, with: .linearGradient(Gradient(colors: [AH.goldLight, AH.gold, AH.goldDeep]),
                                               startPoint: CGPoint(x: knot.x - 0.6, y: 0), endPoint: CGPoint(x: knot.x + 5.6, y: 0)))
    }
}

// MARK: - Cards and frames

/// Pastel card stock with a raspberry rule, a gold hairline inside it and notched corners. Stands off its ground with
/// a contact shadow.
struct AHCard: View {
    var fill: Color = AH.card
    var rule: Color = AH.raspberry
    var corner: CGFloat = 6
    var inset: CGFloat = 4
    var shadow: Bool = true

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            let shape = AHCard.notched(r, corner)
            if shadow {
                var sh = ctx
                sh.addFilter(.blur(radius: 2.2))
                sh.fill(shape.offsetBy(dx: 1, dy: 2.4), with: .color(AH.plum.opacity(0.42)))
            }
            ctx.fill(shape, with: .linearGradient(Gradient(colors: [fill, fill.opacity(0.94)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var c = ctx
            c.clip(to: shape)
            AHTex.lay(c, AHTex.paper, in: r, opacity: 1)
            c.fill(Path(r), with: .linearGradient(Gradient(colors: [Color.white.opacity(0.22), .clear, AH.plum.opacity(0.06)]),
                                                  startPoint: .zero, endPoint: CGPoint(x: size.width * 0.4, y: size.height)))
            let a = r.insetBy(dx: inset, dy: inset)
            ctx.stroke(AHCard.notched(a, corner * 0.8), with: .color(rule), lineWidth: 1.1)
            let b = a.insetBy(dx: 2.2, dy: 2.2)
            ctx.stroke(AHCard.notched(b, corner * 0.6), with: .color(AH.gold), lineWidth: 0.6)
            // a cut edge catching the light along the top
            ctx.stroke(Path { p in p.move(to: CGPoint(x: corner, y: 0.4)); p.addLine(to: CGPoint(x: size.width - corner, y: 0.4)) },
                       with: .color(Color.white.opacity(0.7)), lineWidth: 0.8)
        }
    }

    /// A rectangle with concave quarter-circle notches at the corners (ticket corners).
    static func notched(_ r: CGRect, _ n: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + n, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - n, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + n), control: CGPoint(x: r.maxX - n, y: r.minY + n))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - n))
        p.addQuadCurve(to: CGPoint(x: r.maxX - n, y: r.maxY), control: CGPoint(x: r.maxX - n, y: r.maxY - n))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - n), control: CGPoint(x: r.minX + n, y: r.maxY - n))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + n))
        p.addQuadCurve(to: CGPoint(x: r.minX + n, y: r.minY), control: CGPoint(x: r.minX + n, y: r.minY + n))
        p.closeSubpath()
        return p
    }
}

/// A brass plaque with a bevelled edge and two screw heads.
struct AHPlaque: View {
    var radius: CGFloat = 3
    var screws = true
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            let shape = Path(roundedRect: r, cornerRadius: radius)
            var sh = ctx
            sh.addFilter(.blur(radius: 1.4))
            sh.fill(shape.offsetBy(dx: 0.6, dy: 1.4), with: .color(AH.plum.opacity(0.45)))
            ctx.fill(shape, with: .linearGradient(Gradient(colors: [AH.goldLight, Color(hex: 0xE2C278), AH.gold]),
                                                  startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var c = ctx
            c.clip(to: shape)
            AHTex.lay(c, AHTex.gouache, in: r, opacity: 0.8)
            ctx.stroke(Path(roundedRect: r.insetBy(dx: 1.4, dy: 1.4), cornerRadius: max(0.5, radius - 1)),
                       with: .color(AH.goldDeep.opacity(0.75)), lineWidth: 0.6)
            ctx.stroke(Path(roundedRect: r.insetBy(dx: 0.4, dy: 0.4), cornerRadius: radius), with: .color(Color.white.opacity(0.55)), lineWidth: 0.6)
            if screws {
                for x in [CGFloat(3.6), size.width - 3.6] {
                    let s = CGRect(x: x - 1.1, y: size.height / 2 - 1.1, width: 2.2, height: 2.2)
                    ctx.fill(Path(ellipseIn: s), with: .color(AH.goldDeep))
                    ctx.stroke(Path { p in p.move(to: CGPoint(x: s.minX + 0.4, y: s.midY)); p.addLine(to: CGPoint(x: s.maxX - 0.4, y: s.midY)) },
                               with: .color(AH.goldLight), lineWidth: 0.4)
                }
            }
        }
    }
}

// MARK: - Postage stamp and postmark

/// A perforated postage stamp with an engraved alpine vignette in its panel.
struct AHStamp: View {
    var fill: Color = AH.blush
    var engraving: Bool = true
    var vignette: CGFloat = 0.42   // how much of the panel the engraved peaks fill, from the bottom

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            let pr = max(1.1, min(size.width, size.height) * 0.022)
            let pitch = pr * 3.0
            var holes = Path()
            func row(_ from: CGPoint, _ to: CGPoint) {
                let len = hypot(to.x - from.x, to.y - from.y)
                let n = Int(len / pitch)
                for i in 0...n {
                    let t = CGFloat(i) / CGFloat(max(1, n))
                    let p = CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
                    holes.addEllipse(in: CGRect(x: p.x - pr, y: p.y - pr, width: pr * 2, height: pr * 2))
                }
            }
            row(CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0))
            row(CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height))
            row(CGPoint(x: 0, y: 0), CGPoint(x: 0, y: size.height))
            row(CGPoint(x: size.width, y: 0), CGPoint(x: size.width, y: size.height))
            // contact shadow, then the perforated sheet
            var sh = ctx
            sh.addFilter(.blur(radius: 1.6))
            sh.drawLayer { l in
                l.fill(Path(r.offsetBy(dx: 0.8, dy: 1.8)), with: .color(AH.plum.opacity(0.45)))
                l.blendMode = .destinationOut
                l.fill(holes.offsetBy(dx: 0.8, dy: 1.8), with: .color(.black))
            }
            ctx.drawLayer { l in
                l.fill(Path(r), with: .color(Color(hex: 0xFFFBF3)))
                AHTex.lay(l, AHTex.paper, in: r, opacity: 1)
                l.blendMode = .destinationOut
                l.fill(holes, with: .color(.black))
            }
            let m = max(4, size.width * 0.085)
            let panel = r.insetBy(dx: m, dy: m)
            ctx.fill(Path(panel), with: .color(fill))
            var c = ctx
            c.clip(to: Path(panel))
            if engraving {
                let base = panel.maxY + 1
                let hgt = panel.height * vignette
                let peaks: [(CGFloat, CGFloat, CGFloat)] = [(0.2, 0.62, 0.32), (0.8, 0.62, 0.32), (0.5, 1.0, 0.45)]
                for (i, pk) in peaks.enumerated() {
                    AHPeak(apex: CGPoint(x: panel.minX + panel.width * pk.0, y: base - hgt * pk.1), left: panel.width * pk.2,
                           right: panel.width * pk.2, base: base, snow: 0.4, spine: 0.18, seed: 300 &+ UInt64(i))
                        .draw(c, lit: AH.plum.opacity(0.13), shade: AH.plum.opacity(0.24), snowLit: Color.white.opacity(0.55), snowShade: Color.white.opacity(0.3))
                }
                // engraver's hatching across the sky
                var hatch = Path()
                var y = panel.minY + 2
                while y < base - hgt * 0.9 {
                    hatch.move(to: CGPoint(x: panel.minX, y: y)); hatch.addLine(to: CGPoint(x: panel.maxX, y: y)); y += 1.6
                }
                c.stroke(hatch, with: .color(AH.plum.opacity(0.06)), lineWidth: 0.5)
            }
            AHTex.lay(c, AHTex.paper, in: r, opacity: 1)
            ctx.stroke(Path(panel), with: .color(AH.raspberry), lineWidth: 0.9)
            ctx.stroke(Path(panel.insetBy(dx: 1.8, dy: 1.8)), with: .color(AH.gold.opacity(0.9)), lineWidth: 0.5)
        }
    }
}

/// A circular postmark in plum ink, with text around the ring.
struct AHPostmark: View {
    var top: String
    var bottom: String
    var center: String
    var waves: Int = 0

    var body: some View {
        Canvas { ctx, size in
            let d = min(size.height, size.width)
            let c = CGPoint(x: d / 2, y: size.height / 2)
            let ink = AH.plum.opacity(0.62)
            let r0 = d / 2 - 0.6
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r0, y: c.y - r0, width: r0 * 2, height: r0 * 2)), with: .color(ink), lineWidth: 0.9)
            let r1 = r0 * 0.6
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r1, y: c.y - r1, width: r1 * 2, height: r1 * 2)), with: .color(ink), lineWidth: 0.6)
            let fs = d * 0.13
            AHGeo.arcText(ctx, top, font: AH.futura(fs), color: ink, center: c, radius: (r0 + r1) / 2 - fs * 0.05, tracking: fs * 0.12)
            AHGeo.arcText(ctx, bottom, font: AH.futura(fs), color: ink, center: c, radius: (r0 + r1) / 2 + fs * 0.05, tracking: fs * 0.12, bottom: true)
            ctx.draw(Text(center).font(AH.futura(d * 0.17)).foregroundColor(ink), at: c, anchor: .center)
            if waves > 0 {
                var p = Path()
                for k in 0..<waves {
                    let y = c.y - CGFloat(waves - 1) * d * 0.09 + CGFloat(k) * d * 0.18
                    p.move(to: CGPoint(x: d + 1, y: y))
                    var x = d + 1
                    while x < size.width {
                        p.addQuadCurve(to: CGPoint(x: x + d * 0.3, y: y), control: CGPoint(x: x + d * 0.15, y: y + (Int(x) % 2 == 0 ? -1 : 1) * d * 0.08))
                        x += d * 0.3
                    }
                }
                ctx.stroke(p, with: .color(ink), lineWidth: 0.7)
            }
        }
        .blendMode(.multiply)
    }
}

// MARK: - Barometer

/// A brass aneroid barometer: a pastel scale from rain to fair, a raspberry needle set by the weather code,
/// and the temperature set in the lower half of the face.
struct AHBarometer: View {
    var weather: WeatherSnapshot?
    var diameter: CGFloat
    var showTemp = true

    var body: some View {
        ZStack {
            Canvas { ctx, size in AHBarometer.draw(ctx, d: diameter, sky: weather.map { AHSky($0) }) }
            if showTemp {
                Group {
                    if let w = weather {
                        Text("\(Int(w.temperature.rounded()))").tracking(-diameter * 0.03) + Text("°")
                    } else {
                        Text("– –").tracking(1)
                    }
                }
                .font(AH.futura(diameter * (weather == nil ? 0.17 : 0.25)))
                .foregroundStyle(AH.plum)
                .offset(x: weather == nil ? 0 : diameter * 0.03, y: diameter * 0.235)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    /// Scale position (0 = rain, 1 = fair) to a dial angle: the scale sweeps the upper 220 degrees, leaving the lower
    /// face clear for the temperature.
    static func angle(_ s: Double) -> Double { 200 - 220 * s }

    static func reading(_ sky: AHSky?) -> Double {
        guard let sky else { return 0.5 }
        switch sky {
        case .clear: return 0.84
        case .partly: return 0.68
        case .overcast, .fog: return 0.5
        case .rain: return 0.26
        case .snow: return 0.18
        case .storm: return 0.08
        }
    }

    static func draw(_ ctx: GraphicsContext, d: CGFloat, sky: AHSky?) {
        let c = CGPoint(x: d / 2, y: d / 2)
        func circle(_ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }
        var sh = ctx
        sh.addFilter(.blur(radius: d * 0.035))
        sh.fill(circle(d / 2).offsetBy(dx: d * 0.015, dy: d * 0.04), with: .color(AH.plum.opacity(0.5)))
        // brass bezel
        ctx.fill(circle(d / 2), with: .conicGradient(Gradient(colors: [AH.goldLight, AH.gold, AH.goldDeep, AH.gold, AH.goldLight, Color(hex: 0xE7C985), AH.goldDeep, AH.goldLight]),
                                                     center: c, angle: .degrees(-40)))
        ctx.stroke(circle(d / 2 - 0.5), with: .color(Color.white.opacity(0.5)), lineWidth: 0.7)
        ctx.fill(circle(d * 0.43), with: .color(AH.goldDeep))
        // face
        ctx.fill(circle(d * 0.415), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFFAF0), Color(hex: 0xF3E4CE)]),
                                                         center: CGPoint(x: c.x - d * 0.1, y: c.y - d * 0.12), startRadius: 0, endRadius: d * 0.5))
        var face = ctx
        face.clip(to: circle(d * 0.415))
        AHTex.lay(face, AHTex.paper, in: CGRect(x: 0, y: 0, width: d, height: d), opacity: 0.9)
        // pastel scale: rain (powder) -> change (lilac) -> fair (butter)
        let rs = d * 0.33
        let segs: [(Double, Double, Color)] = [(0, 0.34, Color(hex: 0x9EC3E6)), (0.34, 0.66, Color(hex: 0xC9B6E4)), (0.66, 1, Color(hex: 0xF6D57E))]
        for (a, b, col) in segs {
            var p = Path()
            let steps = 18
            for i in 0...steps {
                let s = a + (b - a) * Double(i) / Double(steps)
                let pt = AHGeo.polar(c, rs, AHBarometer.angle(s))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: d * 0.07, lineCap: .butt))
        }
        var ticks = Path(), major = Path()
        for i in 0...20 {
            let s = Double(i) / 20
            let isMajor = i % 5 == 0
            let a = AHBarometer.angle(s)
            let from = AHGeo.polar(c, rs - d * (isMajor ? 0.06 : 0.04), a), to = AHGeo.polar(c, rs + d * 0.035, a)
            if isMajor { major.move(to: from); major.addLine(to: to) } else { ticks.move(to: from); ticks.addLine(to: to) }
        }
        ctx.stroke(ticks, with: .color(AH.plum.opacity(0.75)), lineWidth: max(0.4, d * 0.008))
        ctx.stroke(major, with: .color(AH.plum), lineWidth: max(0.6, d * 0.014))
        // printed marks inside the scale: a raindrop toward wet, a little sun toward fair (the needle sweeps over them)
        let dropC = AHGeo.polar(c, d * 0.2, AHBarometer.angle(0.1))
        var drop = Path()
        let dr = d * 0.035
        drop.move(to: CGPoint(x: dropC.x, y: dropC.y - dr * 1.8))
        drop.addQuadCurve(to: CGPoint(x: dropC.x, y: dropC.y + dr), control: CGPoint(x: dropC.x + dr * 1.6, y: dropC.y + dr * 0.4))
        drop.addQuadCurve(to: CGPoint(x: dropC.x, y: dropC.y - dr * 1.8), control: CGPoint(x: dropC.x - dr * 1.6, y: dropC.y + dr * 0.4))
        ctx.fill(drop, with: .color(Color(hex: 0x6E97C8)))
        let sunC = AHGeo.polar(c, d * 0.2, AHBarometer.angle(0.9))
        var rays = Path()
        for k in 0..<8 {
            let a = Double(k) * 45
            rays.move(to: AHGeo.polar(sunC, dr * 1.5, a)); rays.addLine(to: AHGeo.polar(sunC, dr * 2.2, a))
        }
        ctx.stroke(rays, with: .color(Color(hex: 0xD9A23A)), lineWidth: max(0.4, d * 0.01))
        ctx.fill(Path(ellipseIn: CGRect(x: sunC.x - dr * 1.1, y: sunC.y - dr * 1.1, width: dr * 2.2, height: dr * 2.2)), with: .color(Color(hex: 0xE8B54A)))
        // needle
        let a = AHBarometer.angle(reading(sky))
        let tip = AHGeo.polar(c, rs + d * 0.02, a)
        let tail = AHGeo.polar(c, d * 0.09, a + 180)
        let side1 = AHGeo.polar(c, d * 0.025, a + 90), side2 = AHGeo.polar(c, d * 0.025, a - 90)
        var needle = Path()
        needle.move(to: tip); needle.addLine(to: side1); needle.addLine(to: tail); needle.addLine(to: side2); needle.closeSubpath()
        var ns = ctx
        ns.addFilter(.blur(radius: 0.8))
        ns.fill(needle.offsetBy(dx: d * 0.012, dy: d * 0.025), with: .color(AH.plum.opacity(0.35)))
        ctx.fill(needle, with: .color(sky == nil ? AH.inkSoft : AH.raspberry))
        ctx.fill(circle(d * 0.05), with: .radialGradient(Gradient(colors: [AH.goldLight, AH.goldDeep]),
                                                        center: CGPoint(x: c.x - d * 0.015, y: c.y - d * 0.015), startRadius: 0, endRadius: d * 0.06))
        // glass: a crescent of reflected light
        var glint = Path()
        glint.move(to: AHGeo.polar(c, d * 0.39, 160))
        glint.addQuadCurve(to: AHGeo.polar(c, d * 0.39, 70), control: AHGeo.polar(c, d * 0.3, 115))
        glint.addQuadCurve(to: AHGeo.polar(c, d * 0.39, 160), control: AHGeo.polar(c, d * 0.5, 115))
        ctx.fill(glint, with: .color(Color.white.opacity(0.45)))
    }
}

// MARK: - Concierge pieces

/// A brass key fob with a stamped room number; raspberry enamel when the task is late.
struct AHKeyTag: View {
    var number: Int
    var urgent: Bool
    var height: CGFloat

    var body: some View {
        let w = height * 1.9
        ZStack(alignment: .leading) {
            Canvas { ctx, size in
                let body = Path(roundedRect: CGRect(x: height * 0.32, y: 0, width: w - height * 0.32, height: height), cornerRadius: height / 2)
                var sh = ctx
                sh.addFilter(.blur(radius: 0.8))
                sh.fill(body.offsetBy(dx: 0.5, dy: 1), with: .color(AH.plum.opacity(0.4)))
                if urgent {
                    ctx.fill(body, with: .linearGradient(Gradient(colors: [Color(hex: 0xD0587D), AH.raspberryDeep]), startPoint: .zero, endPoint: CGPoint(x: 0, y: height)))
                    ctx.stroke(body, with: .color(AH.gold), lineWidth: 0.8)
                } else {
                    ctx.fill(body, with: .linearGradient(Gradient(colors: [AH.goldLight, AH.gold, AH.goldDeep]), startPoint: .zero, endPoint: CGPoint(x: 0, y: height)))
                    ctx.stroke(body, with: .color(AH.goldDeep.opacity(0.8)), lineWidth: 0.5)
                }
                ctx.stroke(Path(roundedRect: CGRect(x: height * 0.32 + 0.6, y: 0.6, width: w - height * 0.32 - 1.2, height: height * 0.45), cornerRadius: height * 0.22),
                           with: .color(Color.white.opacity(0.35)), lineWidth: 0.5)
                // hole and split ring
                let hole = CGRect(x: height * 0.52, y: height / 2 - height * 0.15, width: height * 0.3, height: height * 0.3)
                ctx.fill(Path(ellipseIn: hole), with: .color(AH.plum.opacity(0.75)))
                let ring = CGRect(x: 0, y: height / 2 - height * 0.36, width: height * 0.72, height: height * 0.72)
                ctx.stroke(Path(ellipseIn: ring), with: .color(AH.goldDeep), lineWidth: max(0.8, height * 0.1))
                ctx.stroke(Path(ellipseIn: ring.insetBy(dx: 0.3, dy: 0.3)), with: .color(AH.goldLight.opacity(0.8)), lineWidth: 0.4)
            }
            Text("\(number)")
                .font(AH.futura(height * 0.66))
                .foregroundStyle(urgent ? AH.cream : AH.plum)
                .frame(width: w - height * 0.95, alignment: .center)
                .offset(x: height * 0.88)
        }
        .frame(width: w, height: height, alignment: .leading)
    }
}

/// The due mark beside a task: a slanted rubber stamp when late, burgundy for today, soft plum otherwise.
struct AHDueMark: View {
    var task: TaskItem
    var size: CGFloat

    var body: some View {
        if let label = AHText.due(task) {
            if task.isOverdue(asOf: Mock.now) {
                Text(label)
                    .font(AH.futura(size))
                    .tracking(size * 0.12)
                    .foregroundStyle(AH.raspberry)
                    .padding(.horizontal, size * 0.35)
                    .padding(.vertical, size * 0.08)
                    .overlay(RoundedRectangle(cornerRadius: 1.5).strokeBorder(AH.raspberry, lineWidth: 0.9))
                    .rotationEffect(.degrees(-5))
                    .padding(.trailing, 1)
                    .fixedSize()
            } else if task.isDueToday(asOf: Mock.now) {
                Text(label).font(AH.futura(size)).tracking(size * 0.16).foregroundStyle(AH.burgundy).fixedSize()
            } else {
                Text(label).font(AH.futuraMed(size)).tracking(size * 0.14).foregroundStyle(AH.inkSoft).fixedSize()
            }
        }
    }
}

/// A brass bell push on a lacquered plinth: the "next quote" button.
struct AHBellPush: View {
    var size: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let w = size, h = size * 0.82
            let base = CGRect(x: w * 0.04, y: h * 0.62, width: w * 0.92, height: h * 0.3)
            var sh = ctx
            sh.addFilter(.blur(radius: w * 0.05))
            sh.fill(Path(ellipseIn: base.offsetBy(dx: w * 0.03, dy: h * 0.08)), with: .color(AH.plum.opacity(0.55)))
            // plinth: raspberry lacquer, an ellipse with a visible rim
            ctx.fill(Path(ellipseIn: base.offsetBy(dx: 0, dy: h * 0.05)), with: .color(AH.raspberryDeep))
            ctx.fill(Path(ellipseIn: base), with: .linearGradient(Gradient(colors: [Color(hex: 0xD45C80), AH.raspberry]),
                                                                  startPoint: CGPoint(x: base.minX, y: base.minY), endPoint: CGPoint(x: base.maxX, y: base.maxY)))
            ctx.stroke(Path(ellipseIn: base.insetBy(dx: w * 0.04, dy: h * 0.02)), with: .color(AH.goldLight.opacity(0.8)), lineWidth: 0.6)
            // dome
            var dome = Path()
            let dl = w * 0.16, dr = w * 0.84, dy = h * 0.76
            dome.move(to: CGPoint(x: dl, y: dy))
            dome.addCurve(to: CGPoint(x: w / 2, y: h * 0.2), control1: CGPoint(x: dl, y: h * 0.42), control2: CGPoint(x: w * 0.3, y: h * 0.2))
            dome.addCurve(to: CGPoint(x: dr, y: dy), control1: CGPoint(x: w * 0.7, y: h * 0.2), control2: CGPoint(x: dr, y: h * 0.42))
            dome.addQuadCurve(to: CGPoint(x: dl, y: dy), control: CGPoint(x: w / 2, y: h * 0.86))
            dome.closeSubpath()
            ctx.fill(dome, with: .radialGradient(Gradient(colors: [AH.goldLight, AH.gold, AH.goldDeep]),
                                                 center: CGPoint(x: w * 0.38, y: h * 0.36), startRadius: 0, endRadius: w * 0.5))
            var glint = Path()
            glint.move(to: CGPoint(x: w * 0.27, y: h * 0.56))
            glint.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.28), control: CGPoint(x: w * 0.27, y: h * 0.34))
            ctx.stroke(glint, with: .color(Color.white.opacity(0.75)), style: StrokeStyle(lineWidth: w * 0.045, lineCap: .round))
            // plunger
            let knob = CGRect(x: w * 0.43, y: h * 0.08, width: w * 0.14, height: h * 0.16)
            ctx.fill(Path(roundedRect: knob, cornerRadius: w * 0.05), with: .linearGradient(Gradient(colors: [AH.goldLight, AH.goldDeep]),
                                                                                           startPoint: CGPoint(x: knob.minX, y: 0), endPoint: CGPoint(x: knob.maxX, y: 0)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.4, y: h * 0.04, width: w * 0.2, height: h * 0.08)), with: .color(AH.goldLight))
        }
        .frame(width: size, height: size * 0.82)
    }
}

/// The concierge's pigeonholes for the week: a mint lacquer cabinet, one slot per day with its number in gold leaf,
/// a raspberry seal where something falls due, and today's slot lit from inside.
struct AHPigeonholes: View {
    var date: Date
    var tasks: [TaskItem]

    var body: some View {
        let week = AHDates.week(of: date)
        let cal = Calendar.current
        let due = Set(tasks.compactMap { $0.due.map { cal.startOfDay(for: $0) } })
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let pad: CGFloat = 4, gap: CGFloat = 3
            let slotW = (w - pad * 2 - gap * 6) / 7
            let slotTop: CGFloat = h * 0.16, slotH = h * 0.56
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    let r = CGRect(origin: .zero, size: size)
                    let shape = Path(roundedRect: r, cornerRadius: 3)
                    var sh = ctx
                    sh.addFilter(.blur(radius: 2))
                    sh.fill(shape.offsetBy(dx: 0.5, dy: 2.4), with: .color(AH.plum.opacity(0.45)))
                    ctx.fill(shape, with: .linearGradient(Gradient(colors: [Color(hex: 0xD5EFE2), AH.mintCard, Color(hex: 0x9FCDB7)]),
                                                          startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                    var c = ctx
                    c.clip(to: shape)
                    AHTex.lay(c, AHTex.gouache, in: r, opacity: 0.9)
                    ctx.fill(Path(CGRect(x: 0, y: slotTop * 0.42, width: size.width, height: 0.8)), with: .color(AH.gold))
                    ctx.stroke(shape, with: .color(Color(hex: 0x6FA88F)), lineWidth: 0.6)
                    for (i, d) in week.enumerated() {
                        let x = pad + CGFloat(i) * (slotW + gap)
                        let slot = CGRect(x: x, y: slotTop, width: slotW, height: slotH)
                        let today = cal.isDate(d, inSameDayAs: date)
                        ctx.fill(Path(roundedRect: slot, cornerRadius: 1.5),
                                 with: .linearGradient(Gradient(colors: today ? [Color(hex: 0xC98A3F), Color(hex: 0xF7D98D)] : [Color(hex: 0x2B3F45), Color(hex: 0x4E6A66)]),
                                                       startPoint: CGPoint(x: 0, y: slot.minY), endPoint: CGPoint(x: 0, y: slot.maxY)))
                        // inner top shadow and a bevel on the lower lip
                        ctx.fill(Path(CGRect(x: slot.minX, y: slot.minY, width: slot.width, height: 2.2)), with: .color(Color.black.opacity(0.3)))
                        ctx.fill(Path(CGRect(x: slot.minX - 0.5, y: slot.maxY - 0.2, width: slot.width + 1, height: 1.3)), with: .color(Color.white.opacity(0.6)))
                        if due.contains(cal.startOfDay(for: d)) {
                            let s = CGRect(x: slot.maxX - 7, y: slot.maxY - 7.5, width: 5.6, height: 5.6)
                            ctx.fill(Path(ellipseIn: s.offsetBy(dx: 0.4, dy: 0.6)), with: .color(Color.black.opacity(0.3)))
                            ctx.fill(Path(ellipseIn: s), with: .radialGradient(Gradient(colors: [Color(hex: 0xE0607F), AH.raspberryDeep]),
                                                                              center: CGPoint(x: s.midX - 1, y: s.midY - 1), startRadius: 0, endRadius: 3.6))
                        }
                    }
                }
                ForEach(Array(week.enumerated()), id: \.offset) { i, d in
                    let x = pad + CGFloat(i) * (slotW + gap)
                    let today = cal.isDate(d, inSameDayAs: date)
                    Text(AHDates.string(d, "d"))
                        .font(AH.futura(slotH * 0.5))
                        .foregroundStyle(today ? AH.burgundy : AH.goldLight)
                        .shadow(color: today ? .clear : .black.opacity(0.5), radius: 0, x: 0.5, y: 0.8)
                        .frame(width: slotW, height: slotH)
                        .offset(x: x, y: slotTop)
                    Text(AHDates.string(d, "EEE").uppercased())
                        .font(AH.futura(h * 0.2))
                        .tracking(0.9)
                        .foregroundStyle(today ? AH.raspberry : AH.plum)
                        .frame(width: slotW, height: h - slotTop - slotH)
                        .offset(x: x, y: slotTop + slotH)
                }
            }
        }
    }
}
