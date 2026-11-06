import SwiftUI

/// The weather as a small engraved cut, as an almanac prints it beside the day's entry: a rayed sun with a hatched
/// disc, a crescent moon with stars, a scalloped cloud shaded with hatching, rain falling in slanted strokes, snow as
/// six-pointed stars, mist as level lines, a storm as a bolt. One Canvas in the ink of the page.
struct ALEngraving: View {
    var condition: SkyCondition
    var isDay: Bool
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let o = CGPoint(x: (size.width - s) / 2, y: (size.height - s) / 2)
            let lw = max(0.6, s * 0.032)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
            switch condition {
            case .clear:
                if isDay { sun(&ctx, p(0.5, 0.5), s * 1, lw, p) } else { moon(&ctx, p(0.5, 0.5), s, lw, p, stars: true) }
            case .partly:
                if isDay { sun(&ctx, p(0.36, 0.36), s * 0.72, lw, p) } else { moon(&ctx, p(0.38, 0.36), s * 0.72, lw, p, stars: false) }
                cloud(&ctx, origin: p(0.22, 0.34), scale: s * 0.78, lw: lw, clearUnder: true)
            case .overcast:
                cloud(&ctx, origin: p(0.3, 0.06), scale: s * 0.66, lw: lw * 0.85, clearUnder: false)
                cloud(&ctx, origin: p(0.04, 0.24), scale: s * 0.86, lw: lw, clearUnder: true)
            case .fog:
                cloud(&ctx, origin: p(0.1, 0.0), scale: s * 0.8, lw: lw, clearUnder: false)
                for (i, y) in [0.68, 0.8, 0.92].enumerated() {
                    var line = Path()
                    let x0 = 0.12 + 0.06 * CGFloat(i % 2)
                    line.move(to: p(x0, y))
                    line.addCurve(to: p(0.88 - 0.06 * CGFloat(i % 2), y), control1: p(0.35, y - 0.04), control2: p(0.62, y + 0.04))
                    ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                }
            case .rain:
                cloud(&ctx, origin: p(0.08, 0.0), scale: s * 0.84, lw: lw, clearUnder: false)
                for i in 0..<5 {
                    let x = 0.22 + 0.13 * CGFloat(i)
                    let y = 0.7 + (i % 2 == 0 ? 0 : 0.07)
                    var d = Path()
                    d.move(to: p(x, y))
                    d.addLine(to: p(x - 0.06, y + 0.16))
                    ctx.stroke(d, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                }
            case .snow:
                cloud(&ctx, origin: p(0.08, 0.0), scale: s * 0.84, lw: lw, clearUnder: false)
                for (x, y) in [(0.26, 0.8), (0.5, 0.88), (0.74, 0.8)] {
                    flake(&ctx, p(x, y), s * 0.075, lw * 0.9)
                }
            case .storm:
                cloud(&ctx, origin: p(0.08, 0.0), scale: s * 0.84, lw: lw, clearUnder: false)
                var bolt = Path()
                bolt.move(to: p(0.56, 0.6))
                bolt.addLine(to: p(0.4, 0.8))
                bolt.addLine(to: p(0.5, 0.8))
                bolt.addLine(to: p(0.4, 0.98))
                bolt.addLine(to: p(0.64, 0.74))
                bolt.addLine(to: p(0.53, 0.74))
                bolt.addLine(to: p(0.62, 0.6))
                bolt.closeSubpath()
                ctx.fill(bolt, with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }

    // A rayed sun: long tapered rays between short straight ones, a ring, and a disc hatched on its shaded side.
    private func sun(_ ctx: inout GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ lw: CGFloat,
                     _ p: (CGFloat, CGFloat) -> CGPoint) {
        let r = s * 0.18
        var rays = Path()
        for i in 0..<16 {
            let a = Double(i) * Double.pi / 8 - Double.pi / 2
            let ca = CGFloat(cos(a)), sa = CGFloat(sin(a))
            if i % 2 == 0 {
                let w = s * 0.034
                let r0 = r * 1.42, r1 = s * 0.48
                rays.move(to: CGPoint(x: c.x + ca * r0 - sa * w, y: c.y + sa * r0 + ca * w))
                rays.addLine(to: CGPoint(x: c.x + ca * r1, y: c.y + sa * r1))
                rays.addLine(to: CGPoint(x: c.x + ca * r0 + sa * w, y: c.y + sa * r0 - ca * w))
                rays.closeSubpath()
            }
        }
        ctx.fill(rays, with: .color(color))
        var short = Path()
        for i in 0..<16 where i % 2 == 1 {
            let a = Double(i) * Double.pi / 8 - Double.pi / 2
            let ca = CGFloat(cos(a)), sa = CGFloat(sin(a))
            short.move(to: CGPoint(x: c.x + ca * r * 1.42, y: c.y + sa * r * 1.42))
            short.addLine(to: CGPoint(x: c.x + ca * s * 0.36, y: c.y + sa * s * 0.36))
        }
        ctx.stroke(short, with: .color(color), style: StrokeStyle(lineWidth: lw * 0.8, lineCap: .round))
        let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.stroke(disc, with: .color(color), lineWidth: lw)
        // Hatching across the lower right of the disc, the side away from the light.
        ctx.drawLayer { layer in
            let lit = Path(ellipseIn: CGRect(x: c.x - r * 1.25, y: c.y - r * 1.25, width: r * 1.9, height: r * 1.9))
            layer.clip(to: disc.subtracting(lit))
            var hatch = Path()
            var y = c.y - r
            while y < c.y + r {
                hatch.move(to: CGPoint(x: c.x - r, y: y))
                hatch.addLine(to: CGPoint(x: c.x + r, y: y))
                y += max(1.1, r * 0.22)
            }
            layer.stroke(hatch, with: .color(color), lineWidth: lw * 0.6)
        }
    }

    // A crescent moon, hatched along its inner edge, with a couple of four-pointed stars.
    private func moon(_ ctx: inout GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ lw: CGFloat,
                      _ p: (CGFloat, CGFloat) -> CGPoint, stars: Bool) {
        let r = s * 0.3
        let outer = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        let ir = r * 0.86
        let ic = CGPoint(x: c.x + r * 0.42, y: c.y - r * 0.22)
        let inner = Path(ellipseIn: CGRect(x: ic.x - ir, y: ic.y - ir, width: ir * 2, height: ir * 2))
        let crescent = outer.subtracting(inner)
        ctx.drawLayer { layer in
            layer.clip(to: crescent)
            var hatch = Path()
            var x = c.x - r
            while x < c.x + r {
                hatch.move(to: CGPoint(x: x, y: c.y - r))
                hatch.addLine(to: CGPoint(x: x + r * 0.5, y: c.y + r))
                x += max(1.1, r * 0.16)
            }
            layer.stroke(hatch, with: .color(color), lineWidth: lw * 0.55)
        }
        ctx.stroke(crescent, with: .color(color), lineWidth: lw)
        if stars {
            star(&ctx, p(0.78, 0.26), s * 0.09)
            star(&ctx, p(0.86, 0.6), s * 0.06)
        }
    }

    private func star(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        var st = Path()
        let k = r * 0.22
        st.move(to: CGPoint(x: c.x, y: c.y - r))
        st.addLine(to: CGPoint(x: c.x + k, y: c.y - k))
        st.addLine(to: CGPoint(x: c.x + r, y: c.y))
        st.addLine(to: CGPoint(x: c.x + k, y: c.y + k))
        st.addLine(to: CGPoint(x: c.x, y: c.y + r))
        st.addLine(to: CGPoint(x: c.x - k, y: c.y + k))
        st.addLine(to: CGPoint(x: c.x - r, y: c.y))
        st.addLine(to: CGPoint(x: c.x - k, y: c.y - k))
        st.closeSubpath()
        ctx.fill(st, with: .color(color))
    }

    private func flake(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ lw: CGFloat) {
        var f = Path()
        for i in 0..<3 {
            let a = Double(i) * Double.pi / 3 + Double.pi / 2
            let dx = CGFloat(cos(a)) * r, dy = CGFloat(sin(a)) * r
            f.move(to: CGPoint(x: c.x - dx, y: c.y - dy))
            f.addLine(to: CGPoint(x: c.x + dx, y: c.y + dy))
        }
        ctx.stroke(f, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }

    /// A scalloped cloud in a unit box at `origin`, `scale` points across: its outline, and level hatching in its
    /// shaded belly. With clearUnder, whatever was drawn beneath it is erased first (a cloud passing over the sun).
    private func cloud(_ ctx: inout GraphicsContext, origin: CGPoint, scale: CGFloat, lw: CGFloat, clearUnder: Bool) {
        func q(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * scale, y: origin.y + y * scale) }
        var path = Path()
        func arc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ a0: Double, _ a1: Double, first: Bool = false) {
            let steps = 14
            for i in 0...steps {
                let a = (a0 + (a1 - a0) * Double(i) / Double(steps)) * Double.pi / 180
                let pt = q(cx + r * CGFloat(cos(a)), cy + r * CGFloat(sin(a)))
                if first && i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
        }
        arc(0.25, 0.6, 0.15, 90, 250, first: true)    // the left billow
        arc(0.47, 0.46, 0.21, 200, 330)               // the crown
        arc(0.74, 0.58, 0.16, 250, 450)               // the right billow, down to the base
        path.closeSubpath()
        if clearUnder {
            var eraser = ctx
            eraser.blendMode = .clear
            eraser.fill(path, with: .color(.black))
            eraser.stroke(path, with: .color(.black), lineWidth: lw * 3)
        }
        ctx.drawLayer { layer in
            layer.clip(to: path)
            var hatch = Path()
            var y = 0.6
            while y < 0.76 {
                hatch.move(to: q(0.05, y))
                hatch.addLine(to: q(0.95, y))
                y += 0.045
            }
            layer.stroke(hatch, with: .color(color), lineWidth: lw * 0.55)
        }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineJoin: .round))
    }
}
