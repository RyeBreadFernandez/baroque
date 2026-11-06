import SwiftUI

// Quote widgets: the corridor at night. The quote is an intertitle (cream Didot italic under a thin red rule)
// on the dark jade wall, beside a lit doorway: through it, a jade room, a table lamp in a silk shade, and a
// window onto the misty ridges and the stair road.

struct CHDoorwaySpec {
    var opening: CGRect
    var casing: CGFloat
    var floorY: CGFloat            // where the far room's floor meets its back wall
    var window: CGRect             // outer frame of the far room's window
    var windowFrame: CGFloat
    var curtain: CGRect
    var lamp: CGPoint              // centre of the lampshade
    var lampWidth: CGFloat
    var leaf: CGFloat              // width of the open door leaf seen edge-on at the hinge (left)
    var k: CGFloat = 1
    var vista: CHVista = .square
}

enum CHDoorway {
    static func draw(_ ctx: GraphicsContext, size: CGSize, spec d: CHDoorwaySpec, sky: CHSky) {
        let O = d.opening
        let k = d.k

        // The corridor floor below the threshold: dark boards running toward us, a skirting board, and the
        // spill of light out through the door.
        if O.maxY < size.height {
            let fl = CGRect(x: 0, y: O.maxY, width: size.width, height: size.height - O.maxY)
            ctx.fill(Path(fl), with: .linearGradient(Gradient(colors: [Color(hex: 0x140A06), Color(hex: 0x080403)]),
                                                     startPoint: CGPoint(x: 0, y: fl.minY), endPoint: CGPoint(x: 0, y: fl.maxY)))
            var seams = Path()
            let vp = CGPoint(x: O.midX, y: O.maxY - 260 * k)
            for i in -8...14 {
                let x = O.midX + CGFloat(i) * 22 * k
                let far = CHGeo.lerp(vp, CGPoint(x: x, y: size.height + 30), (O.maxY - vp.y) / (size.height + 30 - vp.y))
                seams.move(to: far)
                seams.addLine(to: CGPoint(x: x, y: size.height + 30))
            }
            var fc = ctx
            fc.clip(to: Path(fl))
            fc.stroke(seams, with: .color(.black.opacity(0.55)), lineWidth: 0.7 * k)
            var wedge = Path()
            wedge.move(to: CGPoint(x: O.minX + d.leaf, y: O.maxY))
            wedge.addLine(to: CGPoint(x: O.maxX, y: O.maxY))
            wedge.addLine(to: CGPoint(x: O.maxX + (size.height - O.maxY) * 0.5, y: size.height + 2))
            wedge.addLine(to: CGPoint(x: O.minX + d.leaf - (size.height - O.maxY) * 0.35, y: size.height + 2))
            wedge.closeSubpath()
            var w = fc
            w.addFilter(.blur(radius: 2.5 * k))
            w.blendMode = .screen
            w.fill(wedge, with: .linearGradient(Gradient(colors: [CH.tungsten.opacity(0.5), CH.amber.opacity(0.16), .clear]),
                                                startPoint: CGPoint(x: O.midX, y: O.maxY), endPoint: CGPoint(x: O.midX, y: size.height)))
            fc.stroke(seams, with: .color(.black.opacity(0.35)), lineWidth: 0.6 * k)
            // Skirting along the corridor wall either side of the door.
            let sk = CGRect(x: 0, y: O.maxY - 6 * k, width: size.width, height: 6 * k)
            ctx.fill(Path(sk), with: .color(Color(hex: 0x0B0605)))
            ctx.fill(Path(CGRect(x: 0, y: sk.minY, width: size.width, height: 0.6 * k)), with: .color(CH.tungsten.opacity(0.18)))
        }

        // The far room, clipped to the opening.
        var room = ctx
        room.clip(to: Path(O))
        CHFlock.pattern(room, in: O, tone: .jade, cell: CGSize(width: 24 * k, height: 31 * k), seed: 41)
        // Floor: dark boards running away from us, and a rug.
        let floor = CGRect(x: O.minX, y: d.floorY, width: O.width, height: O.maxY - d.floorY)
        room.fill(Path(floor), with: .linearGradient(Gradient(colors: [Color(hex: 0x4A2414), Color(hex: 0x1A0A06)]),
                                                     startPoint: CGPoint(x: O.midX, y: floor.minY), endPoint: CGPoint(x: O.midX, y: floor.maxY)))
        var boards = Path()
        let vp = CGPoint(x: O.midX + O.width * 0.1, y: d.floorY - O.height * 0.4)
        for i in -6...10 {
            let x = O.minX + CGFloat(i) * O.width / 5
            let top = CHGeo.lerp(vp, CGPoint(x: x, y: O.maxY + 40), (d.floorY - vp.y) / (O.maxY + 40 - vp.y))
            boards.move(to: top)
            boards.addLine(to: CGPoint(x: x, y: O.maxY + 40))
        }
        room.stroke(boards, with: .color(.black.opacity(0.45)), lineWidth: 0.6 * k)
        rug(room, floor: floor, vp: vp, k: k)
        room.fill(Path(CGRect(x: O.minX, y: d.floorY - 2.5 * k, width: O.width, height: 2.5 * k)), with: .color(Color(hex: 0x0A1C14)))   // skirting

        // The window in the far wall, and the curtain half across it.
        let t = d.windowFrame
        let glass = d.window.insetBy(dx: t, dy: t)
        CHExterior.draw(room, in: glass, sky: sky, vista: d.vista, scale: k * 0.8)
        CHGlass.draw(room, in: glass, sky: sky, vista: d.vista, seed: 19, k: k * 0.8)
        CHFrame.draw(room, outer: d.window, thickness: t, mullions: [0.5], sill: true, lampFromLeft: false, k: k * 0.7)
        CHCurtain.draw(room, in: d.curtain, seed: 33, leadingRight: false, base: 0x8A1A1E, k: k * 0.8)
        CHCurtain.rod(room, from: d.window.minX - 6 * k, to: d.curtain.maxX + 4 * k, y: d.curtain.minY + 1, rings: [d.curtain.minX + 4 * k, d.curtain.midX, d.curtain.maxX - 4 * k], k: k * 0.7)

        // Lamplight on the room (not on the view outside): a warm pool around the shade, dark corners.
        let visibleGlass = CGRect(x: glass.minX, y: glass.minY, width: max(0, min(glass.maxX, d.curtain.minX + 2 * k) - glass.minX), height: glass.height)
        CHFlock.light(room, size: size, pools: [CHPool(center: d.lamp, radius: O.width * 1.2, strength: 1),
                                                CHPool(center: CGPoint(x: d.window.midX, y: d.window.maxY), radius: O.width * 0.6, strength: 0.3)],
                      ambient: Color(hex: 0x34322C), exclude: [visibleGlass])
        lamp(room, at: d.lamp, width: d.lampWidth, floorY: d.floorY, k: k)
        CHSmoke.draw(room, from: CGPoint(x: d.lamp.x - d.lampWidth * 1.1, y: d.lamp.y + d.lampWidth * 0.8), height: O.height * 0.55, drift: -0.08,
                     seed: 77, color: Color(hex: 0xE8DCC8), opacity: 0.55, k: k)

        // The open door leaf at the hinge, nearly edge-on.
        if d.leaf > 0 {
            var leaf = Path()
            leaf.move(to: CGPoint(x: O.minX, y: O.minY))
            leaf.addLine(to: CGPoint(x: O.minX + d.leaf, y: O.minY + d.leaf * 0.6))
            leaf.addLine(to: CGPoint(x: O.minX + d.leaf, y: O.maxY - d.leaf * 0.3))
            leaf.addLine(to: CGPoint(x: O.minX, y: O.maxY))
            leaf.closeSubpath()
            var ls = room
            ls.addFilter(.blur(radius: 3 * k))
            ls.fill(leaf.offsetBy(dx: 3 * k, dy: 0), with: .color(.black.opacity(0.6)))
            room.fill(leaf, with: .linearGradient(Gradient(colors: [Color(hex: 0x120806), Color(hex: 0x3A1C10)]),
                                                  startPoint: CGPoint(x: O.minX, y: O.midY), endPoint: CGPoint(x: O.minX + d.leaf, y: O.midY)))
            room.stroke(Path(CGRect(x: O.minX + d.leaf * 0.3, y: O.minY + d.leaf * 1.2, width: d.leaf * 0.4, height: O.height * 0.36)),
                        with: .color(Color(hex: 0x5A2E1A, opacity: 0.7)), lineWidth: 0.6 * k)
            room.fill(Path(CGRect(x: O.minX + d.leaf - 1 * k, y: O.minY + d.leaf * 0.6, width: 1 * k, height: O.height - d.leaf * 0.9)),
                      with: .color(CH.tungsten.opacity(0.7)))
        }
        var inner = room
        inner.addFilter(.blur(radius: 2 * k))
        inner.stroke(Path(O), with: .color(.black.opacity(0.6)), lineWidth: 4 * k)

        // Casing: dark wood across the top and down both sides to the floor; the inner edges catch the light.
        let c = d.casing
        var casing = Path()
        casing.addRect(CGRect(x: O.minX - c, y: O.minY - c, width: O.width + c * 2, height: c))
        casing.addRect(CGRect(x: O.minX - c, y: O.minY, width: c, height: O.height))
        casing.addRect(CGRect(x: O.maxX, y: O.minY, width: c, height: O.height))
        var cs = ctx
        cs.addFilter(.blur(radius: 4 * k))
        cs.fill(casing.offsetBy(dx: 0, dy: 2), with: .color(.black.opacity(0.7)))
        ctx.fill(casing, with: .linearGradient(Gradient(colors: [Color(hex: 0x2E160C), Color(hex: 0x0C0504)]),
                                               startPoint: CGPoint(x: O.minX - c, y: O.minY - c), endPoint: CGPoint(x: O.maxX + c, y: O.maxY)))
        var edge = Path()
        edge.move(to: CGPoint(x: O.minX - 0.5, y: O.maxY)); edge.addLine(to: CGPoint(x: O.minX - 0.5, y: O.minY - 0.5))
        edge.addLine(to: CGPoint(x: O.maxX + 0.5, y: O.minY - 0.5)); edge.addLine(to: CGPoint(x: O.maxX + 0.5, y: O.maxY))
        ctx.stroke(edge, with: .color(CH.tungsten.opacity(0.55)), lineWidth: 0.9 * k)
        var outerEdge = Path()
        outerEdge.move(to: CGPoint(x: O.minX - c + 0.5, y: O.maxY)); outerEdge.addLine(to: CGPoint(x: O.minX - c + 0.5, y: O.minY - c + 0.5))
        outerEdge.addLine(to: CGPoint(x: O.maxX + c - 0.5, y: O.minY - c + 0.5)); outerEdge.addLine(to: CGPoint(x: O.maxX + c - 0.5, y: O.maxY))
        ctx.stroke(outerEdge, with: .color(Color(hex: 0x6A3A22, opacity: 0.5)), lineWidth: 0.5 * k)
        if O.maxY < size.height {
            // Threshold: a brass strip catching the light.
            ctx.fill(Path(CGRect(x: O.minX - c, y: O.maxY - 0.6 * k, width: O.width + c * 2, height: 1.6 * k)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0x8A5A24), CH.tungstenHot.opacity(0.9), Color(hex: 0x8A5A24)]),
                                           startPoint: CGPoint(x: O.minX, y: 0), endPoint: CGPoint(x: O.maxX, y: 0)))
        }
    }

    /// Just the glowing shade, for a lamp in the foreground at the edge of frame.
    static func shade(_ ctx: GraphicsContext, at c: CGPoint, width w: CGFloat, k: CGFloat) {
        let h = w * 0.68
        var glow = ctx
        glow.blendMode = .screen
        let gr = w * 1.4
        glow.fill(Path(ellipseIn: CGRect(x: c.x - gr, y: c.y - gr, width: gr * 2, height: gr * 2)),
                  with: .radialGradient(Gradient(colors: [CH.tungsten.opacity(0.45), CH.amber.opacity(0.14), .clear]), center: c, startRadius: w * 0.3, endRadius: gr))
        var shade = Path()
        shade.move(to: CGPoint(x: c.x - w * 0.3, y: c.y - h / 2))
        shade.addLine(to: CGPoint(x: c.x + w * 0.3, y: c.y - h / 2))
        shade.addLine(to: CGPoint(x: c.x + w * 0.5, y: c.y + h / 2))
        shade.addLine(to: CGPoint(x: c.x - w * 0.5, y: c.y + h / 2))
        shade.closeSubpath()
        ctx.fill(shade, with: .linearGradient(Gradient(colors: [Color(hex: 0xB0581E), Color(hex: 0xF8C878), Color(hex: 0xFFE8B0), Color(hex: 0xE89A50), Color(hex: 0x9A4A18)]),
                                              startPoint: CGPoint(x: c.x - w * 0.5, y: c.y), endPoint: CGPoint(x: c.x + w * 0.5, y: c.y)))
        var pleats = ctx
        pleats.clip(to: shade)
        for i in 0..<13 {
            let t = CGFloat(i) / 12
            var p = Path()
            p.move(to: CGPoint(x: c.x - w * 0.3 + w * 0.6 * t, y: c.y - h / 2))
            p.addLine(to: CGPoint(x: c.x - w * 0.5 + w * t, y: c.y + h / 2))
            pleats.stroke(p, with: .color(Color(hex: 0x8A4014, opacity: 0.35)), lineWidth: 0.6 * k)
        }
        pleats.fill(Path(CGRect(x: c.x - w, y: c.y - h / 2, width: w * 2, height: h * 0.25)), with: .color(Color(hex: 0x5A2408, opacity: 0.35)))
        ctx.fill(Path(CGRect(x: c.x - w * 0.3, y: c.y - h / 2 - 0.8 * k, width: w * 0.6, height: 1.6 * k)), with: .color(Color(hex: 0x6A3010)))
    }

    /// A crimson rug in perspective with a gilt border.
    static func rug(_ ctx: GraphicsContext, floor f: CGRect, vp: CGPoint, k: CGFloat) {
        let nearY = f.maxY - f.height * 0.12, farY = f.minY + f.height * 0.18
        func x(at y: CGFloat, base: CGFloat) -> CGFloat { vp.x + (base - vp.x) * (y - vp.y) / (f.maxY + 40 - vp.y) }
        let l = f.minX + f.width * 0.05, rr = f.maxX - f.width * 0.15
        var rug = Path()
        rug.move(to: CGPoint(x: x(at: farY, base: l), y: farY))
        rug.addLine(to: CGPoint(x: x(at: farY, base: rr), y: farY))
        rug.addLine(to: CGPoint(x: x(at: nearY, base: rr), y: nearY))
        rug.addLine(to: CGPoint(x: x(at: nearY, base: l), y: nearY))
        rug.closeSubpath()
        ctx.fill(rug, with: .linearGradient(Gradient(colors: [Color(hex: 0x6A1418), Color(hex: 0x3A080C)]),
                                            startPoint: CGPoint(x: f.midX, y: farY), endPoint: CGPoint(x: f.midX, y: nearY)))
        let inset: CGFloat = 0.12
        let iy0 = farY + (nearY - farY) * inset, iy1 = nearY - (nearY - farY) * inset
        let il = l + (rr - l) * 0.08, ir = rr - (rr - l) * 0.08
        var border = Path()
        border.move(to: CGPoint(x: x(at: iy0, base: il), y: iy0))
        border.addLine(to: CGPoint(x: x(at: iy0, base: ir), y: iy0))
        border.addLine(to: CGPoint(x: x(at: iy1, base: ir), y: iy1))
        border.addLine(to: CGPoint(x: x(at: iy1, base: il), y: iy1))
        border.closeSubpath()
        ctx.stroke(border, with: .color(Color(hex: 0xC8964A, opacity: 0.7)), lineWidth: 0.7 * k)
        let my = (iy0 + iy1) / 2, mx = x(at: my, base: (il + ir) / 2)
        let dw = (x(at: my, base: ir) - x(at: my, base: il)) * 0.18, dh = (iy1 - iy0) * 0.3
        ctx.stroke(CHDiamond().path(in: CGRect(x: mx - dw, y: my - dh, width: dw * 2, height: dh * 2)), with: .color(Color(hex: 0xC8964A, opacity: 0.6)), lineWidth: 0.6 * k)
    }

    /// A table lamp: a pleated silk shade glowing from inside, a brass stem, a little table.
    static func lamp(_ ctx: GraphicsContext, at c: CGPoint, width w: CGFloat, floorY: CGFloat, k: CGFloat) {
        let h = w * 0.68
        // Table
        let table = CGRect(x: c.x - w * 0.9, y: c.y + h * 0.5 + w * 0.55, width: w * 1.8, height: 2.6 * k)
        ctx.fill(Path(CGRect(x: table.minX + 2 * k, y: table.maxY, width: 1.6 * k, height: floorY + 30 - table.maxY)), with: .color(Color(hex: 0x120806)))
        ctx.fill(Path(CGRect(x: table.maxX - 3.6 * k, y: table.maxY, width: 1.6 * k, height: floorY + 30 - table.maxY)), with: .color(Color(hex: 0x120806)))
        ctx.fill(Path(table), with: .color(Color(hex: 0x24100A)))
        ctx.fill(Path(CGRect(x: table.minX, y: table.minY, width: table.width, height: 0.7 * k)), with: .color(CH.tungsten.opacity(0.7)))
        // Stem and base
        ctx.fill(Path(CGRect(x: c.x - 0.8 * k, y: c.y + h * 0.4, width: 1.6 * k, height: table.minY - c.y - h * 0.4 - 1.5 * k)), with: .color(Color(hex: 0xA8782E)))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - w * 0.22, y: table.minY - 2.6 * k, width: w * 0.44, height: 3 * k)), with: .color(Color(hex: 0x6A4614)))
        // Halo
        var glow = ctx
        glow.blendMode = .screen
        let gr = w * 1.8
        glow.fill(Path(ellipseIn: CGRect(x: c.x - gr, y: c.y - gr, width: gr * 2, height: gr * 2)),
                  with: .radialGradient(Gradient(colors: [CH.tungsten.opacity(0.55), CH.amber.opacity(0.18), .clear]), center: c, startRadius: w * 0.3, endRadius: gr))
        // Shade
        var shade = Path()
        shade.move(to: CGPoint(x: c.x - w * 0.3, y: c.y - h / 2))
        shade.addLine(to: CGPoint(x: c.x + w * 0.3, y: c.y - h / 2))
        shade.addLine(to: CGPoint(x: c.x + w * 0.5, y: c.y + h / 2))
        shade.addQuadCurve(to: CGPoint(x: c.x - w * 0.5, y: c.y + h / 2), control: CGPoint(x: c.x, y: c.y + h / 2 + 2 * k))
        shade.closeSubpath()
        ctx.fill(shade, with: .linearGradient(Gradient(colors: [Color(hex: 0xC8742A), Color(hex: 0xFFE2A0), Color(hex: 0xFFF2C8), Color(hex: 0xF0B060), Color(hex: 0xB0581E)]),
                                              startPoint: CGPoint(x: c.x - w * 0.5, y: c.y), endPoint: CGPoint(x: c.x + w * 0.5, y: c.y)))
        var pleats = ctx
        pleats.clip(to: shade)
        for i in 0..<9 {
            let t = CGFloat(i) / 8
            var p = Path()
            p.move(to: CGPoint(x: c.x - w * 0.3 + w * 0.6 * t, y: c.y - h / 2))
            p.addLine(to: CGPoint(x: c.x - w * 0.5 + w * t, y: c.y + h / 2 + 2 * k))
            pleats.stroke(p, with: .color(Color(hex: 0xA0501A, opacity: 0.35)), lineWidth: 0.5 * k)
        }
        ctx.fill(Path(CGRect(x: c.x - w * 0.3, y: c.y - h / 2 - 0.6 * k, width: w * 0.6, height: 1.2 * k)), with: .color(Color(hex: 0x7A3A14)))
        ctx.stroke(Path(CGRect(x: c.x - w * 0.5, y: c.y + h / 2 + 0.4 * k, width: w, height: 0)), with: .color(CH.tungstenHot), lineWidth: 0.9 * k)
    }
}

// MARK: - Large

struct CHQuoteLarge: View {
    var quote: Quote
    private let size = Mock.size(.large)

    static let spec = CHDoorwaySpec(
        opening: CGRect(x: 26, y: 30, width: 124, height: 270), casing: 8, floorY: 226,
        window: CGRect(x: 40, y: 52, width: 96, height: 118), windowFrame: 4.5,
        curtain: CGRect(x: 112, y: 46, width: 30, height: 136), lamp: CGPoint(x: 120, y: 196), lampWidth: 30, leaf: 14, k: 1,
        vista: .square)

    var body: some View {
        ZStack(alignment: .topLeading) {
            CHWall(family: .large, tone: .jade, pools: [CHPool(center: CGPoint(x: 88, y: 330), radius: 160, strength: 0.65),
                                                        CHPool(center: CGPoint(x: 170, y: 160), radius: 130, strength: 0.3)],
                   ambient: Color(hex: 0x1C1E1C), seed: 9)
            Canvas { ctx, s in
                CHDoorway.draw(ctx, size: s, spec: Self.spec, sky: .misty)
            }
            CHIntertitle(quote: quote, font: 21, authorSize: 9, maxLines: 10)
                .frame(width: 156, height: 262, alignment: .leading)
                .offset(x: 176, y: 22)
            CHNextButton()
                .offset(x: size.width - 44, y: size.height - 44)
            CHVignette(center: UnitPoint(x: 0.4, y: 0.45), strength: 0.8, size: size)
            CHGrain(family: .large, strength: 0.48)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

// MARK: - Medium

struct CHQuoteMedium: View {
    var quote: Quote
    private let size = Mock.size(.medium)

    static let spec = CHDoorwaySpec(
        opening: CGRect(x: 24, y: 16, width: 94, height: 162), casing: 7, floorY: 122,
        window: CGRect(x: 34, y: 30, width: 66, height: 70), windowFrame: 3.5,
        curtain: CGRect(x: 86, y: 25, width: 22, height: 82), lamp: CGPoint(x: 96, y: 104), lampWidth: 22, leaf: 10, k: 0.75,
        vista: .square)

    var body: some View {
        ZStack(alignment: .topLeading) {
            CHWall(family: .medium, tone: .jade, pools: [CHPool(center: CGPoint(x: 140, y: 120), radius: 120, strength: 0.4)],
                   ambient: Color(hex: 0x1C1E1C), cell: CGSize(width: 34, height: 44), seed: 11)
            Canvas { ctx, s in
                CHDoorway.draw(ctx, size: s, spec: Self.spec, sky: .misty)
            }
            CHIntertitle(quote: quote, font: 16.5, authorSize: 8.5, maxLines: 4, ruleWidth: 30, authorInset: 36)
                .frame(width: 192, height: 132, alignment: .leading)
                .offset(x: 140, y: 12)
            CHNextButton()
                .offset(x: size.width - 44, y: size.height - 44)
            CHVignette(center: UnitPoint(x: 0.45, y: 0.45), strength: 0.75, size: size)
            CHGrain(family: .medium, strength: 0.48)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

// MARK: - Small

struct CHQuoteSmall: View {
    var quote: Quote
    private let size = Mock.size(.small)

    static let vista = CHVista(
        far: [CGPoint(x: -0.03, y: 0.56), CGPoint(x: 0.12, y: 0.30), CGPoint(x: 0.3, y: 0.46), CGPoint(x: 0.58, y: 0.14),
              CGPoint(x: 0.76, y: 0.40), CGPoint(x: 1.03, y: 0.30)],
        mid: [CGPoint(x: -0.03, y: 0.70), CGPoint(x: 0.18, y: 0.56), CGPoint(x: 0.32, y: 0.44), CGPoint(x: 0.46, y: 0.58), CGPoint(x: 1.03, y: 0.66)],
        near: [CGPoint(x: -0.03, y: 0.88), CGPoint(x: 0.5, y: 0.84), CGPoint(x: 1.03, y: 0.9)],
        road: 0.3, roadWidth: 0.2, moon: CGPoint(x: 0.2, y: 0.2), lamp: CGPoint(x: 0.66, y: 0.7), seed: 83,
        horizon: 0.6, roadFoot: 0.86)

    private var outer: CGRect { CGRect(x: -8, y: -8, width: 180, height: 86) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CHWall(family: .small, tone: .jade, pools: [CHPool(center: CGPoint(x: 116, y: 96), radius: 80, strength: 0.75, squash: 0.8)],
                   ambient: Color(hex: 0x1C1E1C), cell: CGSize(width: 30, height: 40), seed: 13)
            Canvas { ctx, s in
                let t: CGFloat = 5
                let glass = outer.insetBy(dx: t, dy: t)
                CHExterior.draw(ctx, in: glass, sky: .misty, vista: Self.vista, scale: 0.75)
                CHGlass.draw(ctx, in: glass, sky: .misty, vista: Self.vista, seed: 23, k: 0.75)
                CHFrame.draw(ctx, outer: outer, thickness: t, mullions: [0.5], k: 0.75)
                CHCurtain.draw(ctx, in: CGRect(x: 134, y: -4, width: 36, height: 88), seed: 43, k: 0.8)
                // A lamp standing on the sill: brass stem and foot, the shade glowing over the lower pane.
                let sillY = outer.maxY + 0.5
                let sc = CGPoint(x: 116, y: 58)
                var stemShadow = ctx
                stemShadow.addFilter(.blur(radius: 1.5))
                stemShadow.fill(Path(ellipseIn: CGRect(x: sc.x - 9, y: sillY - 2, width: 20, height: 4)), with: .color(.black.opacity(0.6)))
                ctx.fill(Path(CGRect(x: sc.x - 0.8, y: sc.y + 8, width: 1.6, height: sillY - sc.y - 10)), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xF0C878), Color(hex: 0x8A5A24)]), startPoint: CGPoint(x: sc.x - 1, y: 0), endPoint: CGPoint(x: sc.x + 1, y: 0)))
                ctx.fill(Path(ellipseIn: CGRect(x: sc.x - 7, y: sillY - 3.2, width: 14, height: 4)), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xE8B868), Color(hex: 0x6A4614)]), startPoint: CGPoint(x: 0, y: sillY - 3), endPoint: CGPoint(x: 0, y: sillY + 1)))
                CHDoorway.shade(ctx, at: sc, width: 30, k: 0.8)
            }
            CHIntertitle(quote: quote, font: 16, authorSize: 7.5, maxLines: 3, ruleWidth: 24, gap: 0.28)
                .frame(width: 128, height: 63, alignment: .bottomLeading)
                .offset(x: 16, y: 85)
            CHVignette(center: UnitPoint(x: 0.5, y: 0.5), strength: 0.7, size: size)
            CHGrain(family: .small, strength: 0.48)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}
