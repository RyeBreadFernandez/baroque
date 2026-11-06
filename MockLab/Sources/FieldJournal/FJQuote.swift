import SwiftUI
import CoreText

// Quote widgets: a handwritten entry on a ruled journal page. The ruling is drawn behind whichever
// auto-fitted size wins, at that size's line pitch, so the writing always sits on the lines.

enum HandMetrics {
    static let name = "BradleyHandITCTT-Bold"
    static func line(_ size: CGFloat) -> (ascent: CGFloat, pitch: CGFloat) {
        let f = CTFontCreateWithName(name as CFString, size, nil)
        return (CTFontGetAscent(f), CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f))
    }
    static func spacing(_ size: CGFloat) -> CGFloat { size * 0.12 }
}

/// Printed rules (pale cerulean) every `pitch`, with the first baseline at `baseline` in the host's coordinates.
struct Rules: View {
    var baseline: CGFloat
    var pitch: CGFloat
    var limit: CGFloat = 1000          // last rule may sit at most this far below the text's top
    // The canvas reaches a little past the widget in every direction from wherever the text sits.
    static let left: CGFloat = 40, up: CGFloat = 90, width: CGFloat = 400, height: CGFloat = 420

    var body: some View {
        Canvas { ctx, size in
            var c = ctx
            c.blendMode = .multiply
            var y = Self.up + baseline + 2
            while y > 0 { y -= pitch }
            while y < min(size.height, Self.up + limit) {
                if y > 0 {
                    c.fill(Path(CGRect(x: 0, y: y - 0.35, width: size.width, height: 0.7)), with: .color(Color(hex: 0x8DB6D6).opacity(0.75)))
                    c.fill(Path(CGRect(x: 0, y: y - 0.9, width: size.width, height: 1.8)), with: .color(Color(hex: 0xB9D3E6).opacity(0.25)))
                }
                y += pitch
            }
        }
        .frame(width: Self.width, height: Self.height)
        .offset(x: -Self.left, y: -Self.up)
        .allowsHitTesting(false)
    }
}

struct HandQuote: View {
    var quote: Quote
    var size: CGFloat
    var authorSize: CGFloat
    var ruled: Bool = true
    var authorTrailingInset: CGFloat = 0
    var ruleLimit: CGFloat = 1000

    var body: some View {
        let m = HandMetrics.line(size)
        let gap = HandMetrics.spacing(size)
        VStack(alignment: .leading, spacing: 0) {
            Text(quote.text)
                .font(FJ.hand(size))
                .foregroundStyle(FJ.blueInk)
                .lineSpacing(gap)
                .fixedSize(horizontal: false, vertical: true)
                .background(alignment: .topLeading) {
                    if ruled { Rules(baseline: m.ascent, pitch: m.pitch + gap, limit: ruleLimit) }
                }
            if let a = quote.author, !a.isEmpty {
                Text("\u{2014} \(a)")
                    .font(FJ.italic(authorSize))
                    .foregroundStyle(FJ.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, max(2, m.pitch + gap - size * 1.05))
                    .padding(.trailing, authorTrailingInset)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

/// ViewThatFits over decreasing sizes, as the app does.
struct FittedQuote: View {
    var quote: Quote
    var sizes: [CGFloat]
    var authorSize: CGFloat
    var authorTrailingInset: CGFloat = 0
    var ruleLimit: CGFloat = 1000

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes, id: \.self) { s in
                HandQuote(quote: quote, size: s, authorSize: authorSize, authorTrailingInset: authorTrailingInset, ruleLimit: ruleLimit)
            }
        }
    }
}

/// An opening quote in sienna ink over a loose ochre dab.
struct QuoteMark: View {
    var seed: UInt64
    var size: CGFloat = 64

    var body: some View {
        ZStack(alignment: .topLeading) {
            WashDab(color: FJ.ochrePale, rim: FJ.ochre, seed: seed, opacity: 0.9)
                .frame(width: size * 0.78, height: size * 0.56)
                .offset(x: -size * 0.04, y: -size * 0.04)
            Text("\u{201C}")
                .font(FJ.serifSemi(size))
                .foregroundStyle(FJ.sienna)
                .offset(x: size * 0.02, y: -size * 0.12)
        }
        .frame(width: size * 0.7, height: size * 0.6, alignment: .topLeading)
    }
}

// MARK: - Large

struct QuoteLarge: View {
    var quote: Quote
    static let size = Mock.size(.large)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in
                Page.draw(ctx, size: size, paper: ctx.resolve(Mock.texture(Family.large.paperTexture)), seed: 7)
                margin(ctx, size: size)
                Landscape.paint(ctx, scene: Self.scene, in: CGRect(x: 0, y: 262, width: size.width, height: 103),
                                tooth: FJTex.tooth(ctx))
            }
            QuoteMark(seed: 3).offset(x: 20, y: 10)
            CompassRose().frame(width: 38, height: 44).position(x: 308, y: 40)
            FittedQuote(quote: quote, sizes: [30, 28, 26, 24, 22, 20, 18, 16], authorSize: 15, ruleLimit: 214)
                .frame(width: Self.size.width - 22 - 16, height: 200, alignment: .topLeading)
                .offset(x: 22, y: 60)
            PressedFlower(seed: 12)
                .frame(width: 84, height: 88)
                .rotationEffect(.degrees(-58))
                .position(x: 64, y: 316)
            WashiTape(color: Color(hex: 0xE9C9A6), ink: FJ.sienna, pattern: .stripes, seed: 14)
                .frame(width: 36, height: 12).rotationEffect(.degrees(-18)).position(x: 44, y: 338)
            NextTag().frame(width: 38, height: 38)
                .position(x: Self.size.width - 16 - 15, y: Self.size.height - 16 - 15)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    /// A double margin rule in red pencil, the way field books are ruled.
    private func margin(_ ctx: GraphicsContext, size: CGSize) {
        for (i, x) in [CGFloat(12), 14.6].enumerated() {
            let pts = Brush.wobbly([CGPoint(x: x, y: -2), CGPoint(x: x + 0.4, y: size.height + 2)], amplitude: 0.3, step: 8, seed: 70 + UInt64(i))
            ctx.pencil(Brush.smooth(pts), color: FJ.redPencil, width: 0.7, seed: 80 + UInt64(i), strength: 0.7)
        }
    }

    static let scene = Scenery(ridges: [
        Sceneries.far([CGPoint(x: -0.02, y: 0.36), CGPoint(x: 0.16, y: 0.22), CGPoint(x: 0.34, y: 0.34), CGPoint(x: 0.5, y: 0.16),
                       CGPoint(x: 0.7, y: 0.3), CGPoint(x: 0.86, y: 0.18), CGPoint(x: 1.02, y: 0.3)], seed: 41),
        Sceneries.mid([CGPoint(x: -0.02, y: 0.56), CGPoint(x: 0.14, y: 0.4), CGPoint(x: 0.26, y: 0.24), CGPoint(x: 0.36, y: 0.4),
                       CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.64, y: 0.3), CGPoint(x: 0.76, y: 0.46), CGPoint(x: 1.02, y: 0.56)],
                      snowline: 0.36, seed: 42),
        Sceneries.near([CGPoint(x: -0.02, y: 0.74), CGPoint(x: 0.24, y: 0.62), CGPoint(x: 0.5, y: 0.72), CGPoint(x: 0.74, y: 0.64),
                        CGPoint(x: 1.02, y: 0.72)], trees: 12, seed: 43)
    ], sky: nil, seed: 44)
}

// MARK: - Medium

struct QuoteMedium: View {
    var quote: Quote
    static let size = Mock.size(.medium)

    var body: some View {
        ZStack(alignment: .topLeading) {
            JournalPage(family: .medium, seed: 8)
            FittedQuote(quote: quote, sizes: [24, 22, 21, 20, 19, 18, 17, 16, 15, 14], authorSize: 13, authorTrailingInset: 0)
                .frame(width: 232, height: 128, alignment: .topLeading)
                .offset(x: 16, y: 12)
            FernSketch(seed: 57, pinnae: 10, base: CGPoint(x: 0.85, y: 1.0), tip: CGPoint(x: 0.3, y: 0.0),
                       bend: CGPoint(x: 0.85, y: 0.35), pinnaScale: 0.2)
                .frame(width: 66, height: 96)
                .rotationEffect(.degrees(-10))
                .position(x: 282, y: 98)
            Taped(seed: 51, rotation: 3) {
                MiniStudy(seed: 52).padding(5)
            }
            .frame(width: 76, height: 70)
            .position(x: 296, y: 52)
            WashiTape(color: Color(hex: 0xCBD5B0), ink: FJ.sapDeep, pattern: .grid, seed: 53)
                .frame(width: 40, height: 13).rotationEffect(.degrees(-6)).position(x: 296, y: 18)
            NextTag().frame(width: 38, height: 38)
                .position(x: Self.size.width - 16 - 15, y: Self.size.height - 16 - 15)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }
}

/// A thumbnail watercolour study for the taped postcard.
struct MiniStudy: View {
    var seed: UInt64
    var body: some View {
        Canvas { ctx, size in
            let tooth = FJTex.tooth(ctx)
            let r = CGRect(origin: .zero, size: size)
            let scene = Scenery(ridges: [
                Sceneries.far([CGPoint(x: -0.05, y: 0.5), CGPoint(x: 0.3, y: 0.34), CGPoint(x: 0.6, y: 0.46), CGPoint(x: 1.05, y: 0.3)], seed: seed),
                Sceneries.mid([CGPoint(x: -0.05, y: 0.7), CGPoint(x: 0.25, y: 0.5), CGPoint(x: 0.48, y: 0.22), CGPoint(x: 0.62, y: 0.4),
                               CGPoint(x: 0.8, y: 0.32), CGPoint(x: 1.05, y: 0.6)], snowline: 0.4, seed: seed &+ 1, ink: 0.7),
                Sceneries.near([CGPoint(x: -0.05, y: 0.86), CGPoint(x: 0.5, y: 0.76), CGPoint(x: 1.05, y: 0.84)], trees: 5, seed: seed &+ 2, treeHeight: 6)
            ], sky: CGRect(x: 0, y: 0, width: 1, height: 0.6), skyOpacity: 0.6, seed: seed &+ 3)
            var c = ctx
            c.clip(to: Path(r.insetBy(dx: 1, dy: 1)))
            Landscape.paint(c, scene: scene, in: r, tooth: tooth)
            ctx.pencil(Path(r.insetBy(dx: 1, dy: 1)), color: FJ.pencil, width: 0.5, seed: seed, strength: 0.6)
        }
    }
}

// MARK: - Small

struct QuoteSmall: View {
    var quote: Quote
    static let size = Mock.size(.small)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in
                Page.draw(ctx, size: size, paper: ctx.resolve(Mock.texture(Family.small.paperTexture)), seed: 9)
                Landscape.paint(ctx, scene: Self.scene, in: CGRect(x: 0, y: 106, width: size.width, height: 58),
                                tooth: FJTex.tooth(ctx))
            }
            FittedQuote(quote: quote, sizes: [28, 26, 24, 22, 20, 19, 18, 17, 16, 15, 14, 13], authorSize: 12.5)
                .frame(width: Self.size.width - 32, height: 104, alignment: .topLeading)
                .offset(x: 16, y: 14)
            PressedFlower(seed: 31)
                .frame(width: 50, height: 54)
                .rotationEffect(.degrees(-64))
                .position(x: 34, y: 140)
            WashiTape(color: Color(hex: 0xCBD5B0), ink: FJ.sapDeep, pattern: .grid, seed: 32)
                .frame(width: 28, height: 10).rotationEffect(.degrees(-24)).position(x: 26, y: 152)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    static let scene = Scenery(ridges: [
        Sceneries.far([CGPoint(x: -0.02, y: 0.4), CGPoint(x: 0.3, y: 0.2), CGPoint(x: 0.6, y: 0.36), CGPoint(x: 1.04, y: 0.18)], seed: 61),
        Sceneries.mid([CGPoint(x: -0.02, y: 0.6), CGPoint(x: 0.22, y: 0.36), CGPoint(x: 0.42, y: 0.5), CGPoint(x: 0.7, y: 0.22),
                       CGPoint(x: 0.86, y: 0.4), CGPoint(x: 1.04, y: 0.5)], snowline: 0.36, seed: 62, ink: 0.85),
        Sceneries.near([CGPoint(x: -0.02, y: 0.8), CGPoint(x: 0.5, y: 0.66), CGPoint(x: 1.04, y: 0.78)], trees: 6, seed: 63, treeHeight: 7)
    ], sky: nil, seed: 64)
}
