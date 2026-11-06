import SwiftUI

/// The quote in grisaille on the pale panel, auto-fitted over decreasing sizes like the app's ViewThatFits.
struct FittedQuote: View {
    let quote: Quote
    let sizes: [CGFloat]
    var alignment: TextAlignment = .center

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes, id: \.self) { s in block(s) }
        }
    }

    private func block(_ s: CGFloat) -> some View {
        let h: HorizontalAlignment = alignment == .leading ? .leading : .center
        return VStack(alignment: h, spacing: s * 0.42) {
            Text("\u{201C}\(quote.text)\u{201D}")
                .font(SGFont.quote(s))
                .lineSpacing(s * 0.06)
                .multilineTextAlignment(alignment)
                .foregroundStyle(Ink.grisaille)
                .fixedSize(horizontal: false, vertical: true)
            if let a = quote.author {
                Text("\u{2014} \(a.uppercased())")
                    .font(SGFont.caps(max(8.5, s * 0.48)))
                    .tracking(1)
                    .foregroundStyle(Ink.grisailleSoft)
                    .multilineTextAlignment(alignment)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The next-quote button glyph (the roundel itself is cut into the window).
struct NextGlyph: View {
    var body: some View {
        Image(systemName: "arrow.forward")
            .font(.system(size: 12, weight: .heavy))
            .silverStain()
    }
}

enum Roundel {
    static let radius: CGFloat = 15
    static func center(_ size: CGSize) -> CGPoint {
        CGPoint(x: size.width - Mock.margin - radius, y: size.height - Mock.margin - radius)
    }

    /// A small leaded roundel: a ring of gold segments around a cobalt cabochon.
    static func cut(_ w: inout Window, _ size: CGSize) {
        let c = center(size)
        let n = 8
        for i in 0..<n {
            let a0 = -90 + Double(i) * 45, a1 = a0 + 45
            var p = Pane(path: Geo.sector(c, radius * 0.66, radius, a0, a1), glass: i % 2 == 0 ? .gold : .amber,
                         light: Geo.polar(c, radius * 0.8, (a0 + a1) / 2))
            p.reach = 1.0
            p.texture = .hammered
            p.texAngle = a0
            p.lead = 1.6
            p.bloom = 0.25
            p.rim = 0.6
            w.add(p, front: true)
        }
        w.lead(Geo.circle(c, radius), 2.6, front: true)
        w.jewel(Jewel(center: c, radius: radius * 0.66, glass: .cobalt, lead: 1.6, bloom: 0.3))
    }
}

// MARK: - Large

struct QuoteLarge: View {
    let quote: Quote
    static let size = Mock.size(.large)
    static let sun = CGPoint(x: 174, y: 82)
    static let panel = CGRect(x: 31, y: 187, width: 286, height: 150)

    var body: some View {
        let c = Roundel.center(Self.size)
        ZStack(alignment: .topLeading) {
            GlassView(window: Self.window())
            FittedQuote(quote: quote, sizes: [25, 23, 21, 19, 17, 15, 13])
                .place(CGRect(x: Self.panel.minX + 12, y: Self.panel.minY + 10, width: Self.panel.width - 24, height: Self.panel.height - 30), .center)
            NextGlyph().position(c)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    static func window() -> Window {
        var w = Window()
        Scene.sky(&w, size, sun: sun, radii: [46, 74, 114, 176, 270, 600], rays: 16, rotation: -90, seed: 51, horizon: 110)
        Scene.sunRose(&w, center: sun, radius: 46, petals: 12, seed: 9)
        Scene.mountains(&w, MountainRange(
            ridge: [CGPoint(x: -10, y: 140), CGPoint(x: 30, y: 112), CGPoint(x: 72, y: 70), CGPoint(x: 104, y: 104),
                    CGPoint(x: 128, y: 98), CGPoint(x: 150, y: 126), CGPoint(x: 174, y: 140), CGPoint(x: 198, y: 126),
                    CGPoint(x: 220, y: 98), CGPoint(x: 244, y: 106), CGPoint(x: 278, y: 74), CGPoint(x: 316, y: 108),
                    CGPoint(x: 360, y: 120)],
            base: 250, snowline: 112, seed: 61, facet: 28))
        Scene.mountains(&w, MountainRange(
            ridge: [CGPoint(x: -10, y: 162), CGPoint(x: 44, y: 144), CGPoint(x: 92, y: 156), CGPoint(x: 138, y: 146),
                    CGPoint(x: 180, y: 160), CGPoint(x: 222, y: 144), CGPoint(x: 276, y: 156), CGPoint(x: 318, y: 142),
                    CGPoint(x: 360, y: 152)],
            base: 260, lit: .jade, shade: .emerald, low: .pine, seed: 62, facet: 14))
        Scene.stem(&w, base: CGPoint(x: 24, y: 180), top: CGPoint(x: 34, y: 52), bend: 14, curl: 9,
                   leaves: [(0.22, 1, 34), (0.42, -1, 28), (0.62, 1, 22)], bud: .amber, seed: 63)
        Scene.stem(&w, base: CGPoint(x: 324, y: 180), top: CGPoint(x: 314, y: 52), bend: -14, curl: -9,
                   leaves: [(0.22, -1, 34), (0.42, 1, 28), (0.62, -1, 22)], bud: .amber, seed: 64)
        Scene.border(&w, size, width: 6, segment: 46, seed: 52)
        Scene.frame(&w, panel, width: 9, radius: 10, segment: 34, seed: 53)
        Scene.panel(&w, panel, rows: [panel.height], glass: [.clear], radius: 10, lead: 2.6, inlay: true, seed: 54)
        Roundel.cut(&w, size)
        w.backlight = sun
        w.backlightRadius = 440
        w.vignette = 0.5
        return w
    }
}

// MARK: - Medium

struct QuoteMedium: View {
    let quote: Quote
    static let size = Mock.size(.medium)
    static let sun = CGPoint(x: 302, y: 48)
    static let panel = CGRect(x: 26, y: 26, width: 222, height: 112)

    var body: some View {
        let c = Roundel.center(Self.size)
        ZStack(alignment: .topLeading) {
            GlassView(window: Self.window())
            FittedQuote(quote: quote, sizes: [21, 19, 18, 17, 16, 15, 14, 13, 12])
                .place(Self.panel.insetBy(dx: 10, dy: 7), .center)
            NextGlyph().position(c)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    static func window() -> Window {
        var w = Window()
        Scene.sky(&w, size, sun: sun, radii: [23, 42, 74, 122, 210, 520], rays: 12, rotation: -90, seed: 71, horizon: 90)
        Scene.sunRose(&w, center: sun, radius: 23, petals: 8, seed: 12)
        Scene.mountains(&w, MountainRange(
            ridge: [CGPoint(x: 236, y: 128), CGPoint(x: 256, y: 108), CGPoint(x: 276, y: 84), CGPoint(x: 294, y: 104),
                    CGPoint(x: 310, y: 98), CGPoint(x: 334, y: 74), CGPoint(x: 360, y: 100)],
            base: 210, snowline: 102, seed: 72, facet: 18))
        Scene.mountains(&w, MountainRange(
            ridge: [CGPoint(x: 236, y: 146), CGPoint(x: 268, y: 132), CGPoint(x: 296, y: 142), CGPoint(x: 326, y: 128),
                    CGPoint(x: 360, y: 138)],
            base: 210, lit: .jade, shade: .emerald, low: .pine, seed: 77, facet: 10))
        Scene.border(&w, size, width: 5, segment: 44, seed: 74)
        Scene.frame(&w, panel, width: 8, radius: 9, segment: 30, seed: 75)
        Scene.panel(&w, panel, rows: [panel.height], glass: [.clear], radius: 9, lead: 2.6, inlay: true, seed: 76)
        Roundel.cut(&w, size)
        w.backlight = sun
        w.backlightRadius = 380
        w.vignette = 0.45
        return w
    }
}

// MARK: - Small

struct QuoteSmall: View {
    let quote: Quote
    static let size = Mock.size(.small)
    static let sun = CGPoint(x: 82, y: 146)
    static let panel = CGRect(x: 24, y: 24, width: 116, height: 88)

    var body: some View {
        ZStack(alignment: .topLeading) {
            GlassView(window: Self.window())
            FittedQuote(quote: quote, sizes: [19, 18, 17, 16, 15, 14, 13, 12, 11])
                .place(Self.panel.insetBy(dx: 8, dy: 6), .center)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    static func window() -> Window {
        var w = Window()
        Scene.sky(&w, size, sun: sun, radii: [17, 32, 58, 102, 400], rays: 12, rotation: -90, seed: 81, horizon: 120)
        Scene.sunRose(&w, center: sun, radius: 17, petals: 8, seed: 14)
        Scene.mountains(&w, MountainRange(
            ridge: [CGPoint(x: -10, y: 150), CGPoint(x: 22, y: 124), CGPoint(x: 48, y: 146), CGPoint(x: 64, y: 140),
                    CGPoint(x: 82, y: 160), CGPoint(x: 100, y: 140), CGPoint(x: 116, y: 146), CGPoint(x: 142, y: 122),
                    CGPoint(x: 176, y: 148)],
            base: 210, snowline: 136, seed: 82, facet: 12))
        Scene.border(&w, size, width: 5, segment: 40, seed: 84)
        Scene.frame(&w, panel, width: 7, radius: 8, segment: 28, seed: 85)
        Scene.panel(&w, panel, rows: [panel.height], glass: [.clear], radius: 8, lead: 2.4, inlay: true, seed: 86)
        w.backlight = CGPoint(x: sun.x, y: 110)
        w.backlightRadius = 220
        w.vignette = 0.45
        return w
    }
}
