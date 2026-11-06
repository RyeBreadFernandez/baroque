import SwiftUI

// Printed furniture: the sheet's margin and plate mark, cartouches, the hanko seal, the handscroll.

/// The paper margin around the printed image, the sumi border line and the plate mark pressed into the sheet.
struct PrintFrame: View {
    var inset: CGFloat = 5
    var body: some View {
        Canvas { ctx, size in
            let ink = InkSet(ctx)
            let full = CGRect(origin: .zero, size: size)
            let inner = Path(roundedRect: full.insetBy(dx: inset, dy: inset),
                             cornerRadius: Mock.cornerRadius - inset, style: .continuous)
            var margin = Path(full.insetBy(dx: -2, dy: -2))
            margin.addPath(inner)
            var m = ctx
            m.clip(to: margin, style: FillStyle(eoFill: true))
            m.draw(ink.washi, in: grainRect(size, shift: CGPoint(x: 3, y: 3)))
            // plate mark: the image is pressed slightly into the sheet (shade top-left inside, light bottom-right)
            var dark = ctx
            dark.clip(to: inner)
            var d = dark
            d.translateBy(x: 1.2, y: 1.2)
            d.stroke(inner, with: .color(WB.indigoDeep.opacity(0.45)), lineWidth: 1.4)
            var l = dark
            l.translateBy(x: -1.2, y: -1.2)
            l.stroke(inner, with: .color(.white.opacity(0.35)), lineWidth: 1.2)
            ctx.stroke(inner, with: .color(WB.sumi.opacity(0.88)), lineWidth: 1.1)
            var outerHi = ctx
            outerHi.translateBy(x: 0.8, y: 0.8)
            outerHi.stroke(Path(roundedRect: full.insetBy(dx: inset - 1.2, dy: inset - 1.2),
                                cornerRadius: Mock.cornerRadius - inset + 1.2, style: .continuous),
                           with: .color(.white.opacity(0.5)), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }
}

/// A title cartouche: a coloured band printed around a paper panel, both outlined by the key block.
struct CartoucheShape: View {
    var band: Color = WB.ochre
    var bandWidth: CGFloat = 3
    var seed: UInt64 = 1
    var lift: Bool = true

    var body: some View {
        Canvas { ctx, size in
            let ink = InkSet(ctx)
            let outerRect = CGRect(origin: .zero, size: size).insetBy(dx: 0.6, dy: 0.6)
            let outer = Geo.roughRect(outerRect, jitter: 0.22, seed: seed)
            let innerRect = outerRect.insetBy(dx: bandWidth, dy: bandWidth)
            let inner = Geo.roughRect(innerRect, jitter: 0.18, seed: seed &+ 1)
            ctx.printBlock(outer, .color(band), ink: ink, grain: Int(seed % 2), strength: 0.8,
                           grainShift: CGPoint(x: CGFloat(seed % 13), y: 4), misreg: CGSize(width: 0.5, height: 0.4), size: size)
            ctx.paper(inner, ink: ink, size: size, shift: CGPoint(x: CGFloat(seed % 7), y: 2))
            // a faint bokashi wiped into the panel's head
            ctx.fill(inner, with: .linearGradient(Gradient(colors: [band.opacity(0.18), band.opacity(0)]),
                                                  startPoint: CGPoint(x: 0, y: innerRect.minY),
                                                  endPoint: CGPoint(x: 0, y: innerRect.minY + min(24, innerRect.height * 0.4))))
            // inner emboss: the panel is pressed a little into the band
            var c = ctx
            c.clip(to: inner)
            var d = c
            d.translateBy(x: 0.7, y: 0.7)
            d.stroke(inner, with: .color(WB.sumi.opacity(0.25)), lineWidth: 0.9)
            ctx.keyline(outer, width: 0.9, opacity: 0.92, seed: Int(seed % 3))
            ctx.keyline(inner, width: 0.55, opacity: 0.75, seed: Int((seed + 1) % 3))
        }
        .shadow(color: WB.indigoDeep.opacity(lift ? 0.35 : 0), radius: 1.6, x: 0.6, y: 1.2)
    }
}

/// The weekday cartouche: a tall tanzaku with the kanji at its head and the English name stacked below.
struct Tanzaku: View {
    var kanji: String
    var word: String
    var width: CGFloat
    var letter: CGFloat
    var kanjiSize: CGFloat
    var band: Color = WB.ochre

    var body: some View {
        VStack(spacing: 0) {
            Text(kanji)
                .font(WB.minchoBold(kanjiSize))
                .foregroundStyle(WB.vermilionDeep)
                .padding(.bottom, 2)
            Rectangle().fill(WB.sumi.opacity(0.7)).frame(width: width * 0.42, height: 0.7).padding(.bottom, 3)
            ForEach(Array(word.uppercased().enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(WB.bodoni(letter))
                    .frame(height: letter * 1.08)
            }
        }
        .foregroundStyle(WB.sumi)
        .padding(.top, 6)
        .padding(.bottom, 5)
        .frame(width: width)
        .background(CartoucheShape(band: band, bandWidth: 2.6, seed: 3))
    }
}

/// The vermilion seal, stamped by hand: rough edge, worn border, uneven ink and the numeral cut out to bare paper.
struct Hanko: View {
    var text: String
    var font: Font
    var size: CGFloat
    var seed: UInt64 = 7
    var tilt: Double = -3
    var dy: CGFloat = 0

    var body: some View {
        ZStack {
            Canvas { ctx, sz in HankoInk(seed: seed).draw(ctx, sz) }
            WB.washiTex
                .resizable()
                .frame(width: size, height: size)
                .mask(Text(text).font(font).offset(y: dy))
            Canvas { ctx, sz in HankoInk(seed: seed).wear(ctx, sz) }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(tilt))
    }
}

struct HankoInk {
    var seed: UInt64

    func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let ink = InkSet(ctx)
        let r = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
        let outer = Geo.roughRect(r, jitter: size.width * 0.012, seed: seed, steps: 7)
        ctx.printBlock(outer, .linearGradient(Gradient(colors: [WB.vermilion, WB.vermilionDeep]),
                                               startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: size.height)),
                       ink: ink, grain: 1, strength: 0.85, grainShift: CGPoint(x: CGFloat(seed % 40), y: 20), size: size)
        // the cut border inside the seal
        let b = r.insetBy(dx: size.width * 0.075, dy: size.width * 0.075)
        let border = Geo.roughRect(b, jitter: size.width * 0.008, seed: seed &+ 2, steps: 6)
        ctx.stroke(border, with: .color(WB.washi.opacity(0.92)),
                   style: StrokeStyle(lineWidth: max(0.8, size.width * 0.035), lineJoin: .round,
                                      dash: [size.width * 0.5, size.width * 0.04, size.width * 0.3, size.width * 0.03]))
    }

    /// Ink-starved specks and a darker pool where the paste sat thick.
    func wear(_ ctx: GraphicsContext, _ size: CGSize) {
        var rng = SeededRandom(seed: seed &+ 5)
        var specks = Path()
        for _ in 0..<Int(size.width * 0.9) {
            let x = rng.range(2...(size.width - 2)), y = rng.range(2...(size.height - 2))
            let w = rng.range(0.3...1.3)
            specks.addEllipse(in: CGRect(x: x, y: y, width: w, height: w * rng.range(0.5...1)))
        }
        ctx.fill(specks, with: .color(WB.washi.opacity(0.55)))
        let pool = Path(ellipseIn: CGRect(x: size.width * 0.5, y: size.height * 0.45, width: size.width * 0.6, height: size.height * 0.6))
        var c = ctx
        c.clip(to: Path(CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)))
        c.fill(pool, with: .radialGradient(Gradient(colors: [WB.vermilionDeep.opacity(0.35), .clear]),
                                           center: CGPoint(x: size.width * 0.8, y: size.height * 0.75),
                                           startRadius: 0, endRadius: size.width * 0.35))
    }
}

/// A handscroll laid over the print: lacquered rods with brass caps, the paper curling into them, a printed border.
struct Handscroll<Content: View>: View {
    var rod: CGFloat = 7
    var cap: CGFloat = 4
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, rod + 7)
            .background(ScrollPaper(rod: rod).shadow(color: WB.indigoDeep.opacity(0.55), radius: 3, x: 0, y: 2.5))
            .overlay(alignment: .leading) { ScrollRod(cap: cap).frame(width: rod).padding(.vertical, -cap) }
            .overlay(alignment: .trailing) { ScrollRod(cap: cap).frame(width: rod).padding(.vertical, -cap) }
    }
}

struct ScrollPaper: View {
    var rod: CGFloat
    var body: some View {
        Canvas { ctx, size in
            let ink = InkSet(ctx)
            let rect = CGRect(x: rod / 2, y: 0, width: size.width - rod, height: size.height)
            let sheet = Path(rect)
            ctx.paper(sheet, ink: ink, size: size, shift: CGPoint(x: 9, y: 6))
            ctx.fill(sheet, with: .color(.white.opacity(0.12)))
            emboss(ctx, rect: rect)
            // the paper curls into each rod
            for (x0, x1) in [(rect.minX, rect.minX + 12), (rect.maxX, rect.maxX - 12)] {
                ctx.fill(sheet, with: .linearGradient(Gradient(colors: [WB.sumi.opacity(0.28), WB.sumi.opacity(0)]),
                                                      startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: x1, y: 0)))
            }
            // printed double border top and bottom, plus an indigo silk edge
            for y in [CGFloat(1.5), size.height - 1.5] {
                var edge = Path()
                edge.addRect(CGRect(x: rect.minX, y: y - 1.5, width: rect.width, height: 3))
                ctx.printBlock(edge, .color(WB.indigo), ink: ink, grain: 1, strength: 0.6, size: size)
            }
            var rules = Path()
            for y in [CGFloat(5.5), size.height - 5.5] {
                rules.move(to: CGPoint(x: rect.minX + 6, y: y))
                rules.addLine(to: CGPoint(x: rect.maxX - 6, y: y))
            }
            ctx.keyline(rules, width: 0.5, opacity: 0.55, seed: 2)
        }
    }

    /// Karazuri: a seigaiha wave pattern blind-embossed into the paper, visible only as light and shade.
    func emboss(_ ctx: GraphicsContext, rect: CGRect) {
        let r: CGFloat = 13
        var arcs = Path()
        var y = rect.minY - r * 0.5
        var row = 0
        while y < rect.maxY + r {
            var x = rect.minX + (row % 2 == 0 ? 0 : r)
            while x < rect.maxX + r {
                for k in [1, 2, 3] {
                    let rr = r * CGFloat(k) / 3.2
                    let a0 = Angle.degrees(195).radians
                    arcs.move(to: CGPoint(x: x + rr * cos(a0), y: y + rr * sin(a0)))
                    arcs.addArc(center: CGPoint(x: x, y: y), radius: rr,
                                startAngle: .degrees(195), endAngle: .degrees(345), clockwise: false)
                }
                x += r * 2
            }
            y += r * 0.55
            row += 1
        }
        var c = ctx
        c.clip(to: Path(rect.insetBy(dx: 3, dy: 3)))
        var lo = c
        lo.translateBy(x: 0.45, y: 0.55)
        lo.stroke(arcs, with: .color(WB.sumi.opacity(0.05)), lineWidth: 0.8)
        var hi = c
        hi.translateBy(x: -0.45, y: -0.45)
        hi.stroke(arcs, with: .color(.white.opacity(0.4)), lineWidth: 0.8)
    }
}

struct ScrollRod: View {
    var cap: CGFloat
    var body: some View {
        Canvas { ctx, size in
            let ink = InkSet(ctx)
            let w = size.width
            let body = Path(roundedRect: CGRect(x: 0.5, y: cap, width: w - 1, height: size.height - cap * 2), cornerRadius: 1)
            ctx.printBlock(body, .linearGradient(Gradient(stops: [
                .init(color: WB.lacquer, location: 0), .init(color: Color(hex: 0x7A4A32), location: 0.38),
                .init(color: Color(hex: 0xA56C48), location: 0.5), .init(color: WB.lacquer, location: 0.85),
                .init(color: Color(hex: 0x1E120D), location: 1)]),
                startPoint: .zero, endPoint: CGPoint(x: w, y: 0)),
                           ink: ink, grain: 0, strength: 0.7, size: size)
            for y in [CGFloat(0), size.height - cap - 2] {
                let r = CGRect(x: -0.2, y: y, width: w + 0.4, height: cap + 2)
                let capPath = Path(roundedRect: r, cornerRadius: 1.6)
                ctx.fill(capPath, with: .linearGradient(Gradient(stops: [
                    .init(color: Color(hex: 0x7A5418), location: 0), .init(color: WB.ochrePale, location: 0.42),
                    .init(color: WB.ochre, location: 0.62), .init(color: Color(hex: 0x5E3F12), location: 1)]),
                    startPoint: .zero, endPoint: CGPoint(x: w, y: 0)))
                ctx.stroke(capPath, with: .color(WB.sumi.opacity(0.7)), lineWidth: 0.5)
            }
            ctx.stroke(body, with: .color(WB.sumi.opacity(0.7)), lineWidth: 0.5)
        }
        .shadow(color: WB.indigoDeep.opacity(0.5), radius: 1.5, x: 0.5, y: 1.5)
    }
}

/// Round vermilion seal used as the "next quote" button.
struct NextSeal: View {
    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let ink = InkSet(ctx)
                let disc = Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 0.8, dy: 0.8))
                ctx.printBlock(disc, .radialGradient(Gradient(colors: [WB.vermilion, WB.vermilionDeep]),
                                                     center: CGPoint(x: size.width * 0.35, y: size.height * 0.3),
                                                     startRadius: 0, endRadius: size.width * 0.75),
                               ink: ink, grain: 1, strength: 0.8, grainShift: CGPoint(x: 30, y: 12), size: size)
                let ring = Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3))
                ctx.stroke(ring, with: .color(WB.washi.opacity(0.9)),
                           style: StrokeStyle(lineWidth: 0.9, dash: [14, 1.6, 9, 1.2]))
                // raised: light on the upper rim, shade below
                ctx.stroke(disc, with: .linearGradient(Gradient(colors: [.white.opacity(0.55), WB.sumi.opacity(0.5)]),
                                                       startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)),
                           lineWidth: 1.1)
            }
            Image(systemName: "arrow.forward")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(WB.washi)
        }
        .frame(width: 30, height: 30)
        .shadow(color: WB.indigoDeep.opacity(0.55), radius: 2, x: 0.5, y: 1.5)
    }
}
