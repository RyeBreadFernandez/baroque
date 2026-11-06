import SwiftUI

// The journal page: book cloth at the very edge, a fore-edge of stacked leaves, and the top sheet of
// cold-press paper with a deckled right and bottom edge, loose fibres, and the shade of the binding gutter.

enum Page {
    static let stackInset: CGFloat = 4.6

    /// Points around a rounded rect (clockwise from the top-left), every `step` points.
    static func roundedRectPoints(_ r: CGRect, radius: CGFloat, step: CGFloat = 1.6) -> [CGPoint] {
        var pts: [CGPoint] = []
        let rad = min(radius, min(r.width, r.height) / 2)
        func line(_ a: CGPoint, _ b: CGPoint) {
            let n = max(1, Int((b - a).length / step))
            for i in 0..<n { pts.append(a + (b - a) * (CGFloat(i) / CGFloat(n))) }
        }
        func arc(_ c: CGPoint, from a0: CGFloat) {
            let n = max(2, Int(rad * .pi / 2 / step))
            for i in 0..<n {
                let a = a0 + CGFloat(i) / CGFloat(n) * .pi / 2
                pts.append(CGPoint(x: c.x + cos(a) * rad, y: c.y + sin(a) * rad))
            }
        }
        line(CGPoint(x: r.minX + rad, y: r.minY), CGPoint(x: r.maxX - rad, y: r.minY))
        arc(CGPoint(x: r.maxX - rad, y: r.minY + rad), from: -.pi / 2)
        line(CGPoint(x: r.maxX, y: r.minY + rad), CGPoint(x: r.maxX, y: r.maxY - rad))
        arc(CGPoint(x: r.maxX - rad, y: r.maxY - rad), from: 0)
        line(CGPoint(x: r.maxX - rad, y: r.maxY), CGPoint(x: r.minX + rad, y: r.maxY))
        arc(CGPoint(x: r.minX + rad, y: r.maxY - rad), from: .pi / 2)
        line(CGPoint(x: r.minX, y: r.maxY - rad), CGPoint(x: r.minX, y: r.minY + rad))
        arc(CGPoint(x: r.minX + rad, y: r.minY + rad), from: .pi)
        return pts
    }

    /// A deckled outline: each point pushed in and out along the outward normal by fine noise.
    static func deckle(_ r: CGRect, radius: CGFloat, amount: CGFloat, seed: UInt64) -> Path {
        let base = roundedRectPoints(r, radius: radius, step: 1.1)
        let w = Wobble(seed: seed, base: 0.55, octaves: 4)
        var rng = SeededRandom(seed: seed &+ 7)
        let c = CGPoint(x: r.midX, y: r.midY)
        var out: [CGPoint] = []
        for (i, p) in base.enumerated() {
            let n = (p - c).normalized
            let d = w(CGFloat(i) * 1.1) * amount + rng.range(-0.25...0.25) * amount
            out.append(p + n * d)
        }
        return Brush.smooth(out, closed: true)
    }

    /// The whole page background.
    static func draw(_ ctx: GraphicsContext, size: CGSize, paper: GraphicsContext.ResolvedImage, seed: UInt64, gutter: Bool = true) {
        let full = CGRect(origin: .zero, size: size)
        // Book cloth: a dark sap-green linen, only a sliver of it shows.
        ctx.fill(Path(full), with: .color(FJ.cloth))
        var r = SeededRandom(seed: seed)
        var y: CGFloat = 0
        while y < size.height {
            ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(.white.opacity(r.range(0.02...0.09))))
            y += 1.1
        }
        // Fore-edge: leaves under the top sheet, each a hair further out.
        let k = stackInset
        for i in stride(from: 4, through: 1, by: -1) {
            let off = k * CGFloat(i) / 5
            let rect = CGRect(x: -10, y: -10, width: size.width + 10 - off, height: size.height + 10 - off)
            let p = Path(roundedRect: rect, cornerRadius: Mock.cornerRadius - off * 0.3, style: .continuous)
            let tone = 0.80 + 0.04 * Double(5 - i)
            ctx.fill(p, with: .color(Color(hex: 0xE9DCC0).opacity(1)))
            ctx.fill(p, with: .color(FJ.paperShade.opacity(1 - tone)))
            ctx.stroke(p, with: .color(FJ.ink.opacity(0.22)), lineWidth: 0.4)
        }
        // Top sheet with a soft cast shadow on the stack.
        let sheet = deckle(CGRect(x: -6, y: -6, width: size.width + 6 - k, height: size.height + 6 - k),
                           radius: Mock.cornerRadius + 2, amount: 0.55, seed: seed &+ 3)
        var sh = ctx
        sh.addFilter(.blur(radius: 1.4))
        sh.fill(sheet.offsetBy(dx: 0.9, dy: 1.1), with: .color(.black.opacity(0.32)))
        var pg = ctx
        pg.clip(to: sheet)
        pg.draw(paper, in: full)
        fibers(pg, size: size, seed: seed &+ 11)
        if gutter { gutterShade(pg, size: size) }
        // Deckle rim: thinner paper at the torn edge reads lighter and slightly translucent.
        var rim = ctx
        rim.clip(to: sheet)
        rim.stroke(sheet, with: .color(.white.opacity(0.55)), lineWidth: 1.6)
        ctx.stroke(sheet, with: .color(FJ.ink.opacity(0.18)), lineWidth: 0.35)
    }

    /// Crisp loose fibres on top of the raster tooth.
    static func fibers(_ ctx: GraphicsContext, size: CGSize, seed: UInt64) {
        var r = SeededRandom(seed: seed)
        let count = Int(size.width * size.height / 260)
        for _ in 0..<count {
            let p = CGPoint(x: r.range(0...size.width), y: r.range(0...size.height))
            let len = r.range(2.5...8)
            let a = r.range(0...(.pi))
            let bend = r.range(-0.5...0.5)
            var path = Path()
            path.move(to: p)
            let end = CGPoint(x: p.x + cos(a) * len, y: p.y + sin(a) * len)
            let mid = CGPoint(x: (p.x + end.x) / 2 + cos(a + .pi / 2) * bend * 2, y: (p.y + end.y) / 2 + sin(a + .pi / 2) * bend * 2)
            path.addQuadCurve(to: end, control: mid)
            let dark = r.unit() < 0.55
            let color: Color = dark ? FJ.inkSoft.opacity(r.range(0.06...0.16)) : .white.opacity(r.range(0.25...0.55))
            ctx.stroke(path, with: .color(color), lineWidth: r.range(0.2...0.4))
        }
    }

    /// The page curving into the binding on the left.
    static func gutterShade(_ ctx: GraphicsContext, size: CGSize) {
        var c = ctx
        c.blendMode = .multiply
        c.fill(Path(CGRect(x: 0, y: 0, width: 16, height: size.height)),
               with: .linearGradient(Gradient(stops: [
                    .init(color: Color(hex: 0x8A7458).opacity(0.55), location: 0),
                    .init(color: Color(hex: 0xB9A585).opacity(0.25), location: 0.35),
                    .init(color: .white.opacity(0), location: 1)]),
                                     startPoint: .zero, endPoint: CGPoint(x: 16, y: 0)))
        c.blendMode = .screen
        c.fill(Path(CGRect(x: 10, y: 0, width: 16, height: size.height)),
               with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.10), .white.opacity(0)]),
                                     startPoint: CGPoint(x: 10, y: 0), endPoint: CGPoint(x: 26, y: 0)))
    }
}

/// A view wrapper for the page.
struct JournalPage: View {
    var family: Family
    var seed: UInt64
    var gutter: Bool = true

    var body: some View {
        Canvas { ctx, size in
            let paper = ctx.resolve(Mock.texture(family.paperTexture))
            Page.draw(ctx, size: size, paper: paper, seed: seed, gutter: gutter)
        }
    }
}

/// Heavier, whiter card stock with a deckled edge and a cast shadow; used for the taped weather card.
struct CardStock: View {
    var seed: UInt64
    var lift: CGFloat = 1.0

    var body: some View {
        Canvas { ctx, size in
            let pad: CGFloat = 6
            let r = CGRect(x: pad, y: pad, width: size.width - pad * 2, height: size.height - pad * 2)
            let shape = Page.deckle(r, radius: 2.5, amount: 0.6, seed: seed)
            var sh = ctx
            sh.addFilter(.blur(radius: 2.2 * lift))
            sh.fill(shape.offsetBy(dx: 1.2 * lift, dy: 2.0 * lift), with: .color(Color(hex: 0x3A2814).opacity(0.36)))
            var near = ctx
            near.addFilter(.blur(radius: 0.5))
            near.fill(shape.offsetBy(dx: 0.3, dy: 0.6), with: .color(.black.opacity(0.22)))
            var c = ctx
            c.clip(to: shape)
            c.draw(ctx.resolve(Mock.texture("field-journal/card")), in: r.insetBy(dx: -2, dy: -2))
            Page.fibers(c, size: size, seed: seed &+ 5)
            // A faint light-to-shade gradient: the card bows slightly off the page.
            c.fill(Path(r), with: .linearGradient(Gradient(colors: [.white.opacity(0.18), .clear, Color(hex: 0x6B5236).opacity(0.08)]),
                                                  startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
            var rim = ctx
            rim.clip(to: shape)
            rim.stroke(shape, with: .color(.white.opacity(0.7)), lineWidth: 1.4)
            ctx.stroke(shape, with: .color(FJ.ink.opacity(0.2)), lineWidth: 0.35)
        }
        .padding(-6)
    }
}
