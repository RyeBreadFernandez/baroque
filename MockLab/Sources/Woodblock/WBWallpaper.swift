import SwiftUI

// Home-screen wallpaper: indigo-dyed cotton (aizome) printed with seigaiha waves, grain and a woven weave.
struct WBWallpaper: View {
    var body: some View {
        Canvas { ctx, size in
            let ink = InkSet(ctx)
            let all = Path(CGRect(origin: .zero, size: size))
            ctx.fill(all, with: .linearGradient(Gradient(colors: [Color(hex: 0x1A2850), WB.indigoDeep]),
                                                startPoint: .zero, endPoint: CGPoint(x: size.width * 0.3, y: size.height)))
            waves(ctx, size)
            weave(ctx, size)
            var g = ctx
            g.blendMode = .softLight
            g.opacity = 0.8
            g.draw(ink.grainA, in: CGRect(origin: .zero, size: size))
            ctx.fill(all, with: .radialGradient(Gradient(colors: [.clear, Color.black.opacity(0.45)]),
                                                center: CGPoint(x: size.width / 2, y: size.height * 0.45),
                                                startRadius: size.width * 0.3, endRadius: size.width * 0.85))
        }
    }

    func waves(_ ctx: GraphicsContext, _ size: CGSize) {
        let r: CGFloat = 30
        var row = 0
        var y: CGFloat = -r
        while y < size.height + r {
            var x: CGFloat = row % 2 == 0 ? 0 : r
            while x < size.width + r {
                let disc = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                ctx.fill(disc, with: .linearGradient(Gradient(colors: [Color(hex: 0x1D2C57), Color(hex: 0x16224A)]),
                                                     startPoint: CGPoint(x: 0, y: y - r), endPoint: CGPoint(x: 0, y: y)))
                var rings = Path()
                for k in 1...4 {
                    let rr = r * CGFloat(k) / 4.2
                    rings.addArc(center: CGPoint(x: x, y: y), radius: rr, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                }
                ctx.stroke(rings, with: .color(WB.prussianMid.opacity(0.3)), lineWidth: 1.5)
                x += r * 2
            }
            y += r / 2
            row += 1
        }
    }

    func weave(_ ctx: GraphicsContext, _ size: CGSize) {
        var lines = Path()
        var v: CGFloat = 0
        while v < max(size.width, size.height) {
            if v < size.width { lines.move(to: CGPoint(x: v, y: 0)); lines.addLine(to: CGPoint(x: v, y: size.height)) }
            if v < size.height { lines.move(to: CGPoint(x: 0, y: v)); lines.addLine(to: CGPoint(x: size.width, y: v)) }
            v += 2.5
        }
        ctx.stroke(lines, with: .color(.black.opacity(0.08)), lineWidth: 0.6)
    }
}
