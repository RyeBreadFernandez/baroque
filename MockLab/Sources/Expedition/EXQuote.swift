import SwiftUI

// Quote widgets. Large: twin felt peaks with a cable car slung between them under a felt sun, and the quote
// typed on a library catalog card with a date-due stamp and an enamel next button. Medium: the catalog card
// centred between two felt peaks, a weather balloon over the right one, the button at the bottom right.
// Small: the quote on a placard hung from a cable over a little felt range.

enum EXQuoteText {
    static func author(_ q: Quote) -> String? {
        guard let a = q.author?.trimmingCharacters(in: .whitespaces), !a.isEmpty else { return nil }
        return "— " + a
    }

    /// A due date two weeks out, stamped on the card like a library return slip.
    static var dueDate: String {
        let d = Calendar.current.date(byAdding: .day, value: 14, to: Mock.now) ?? Mock.now
        return EXDates.string(d, "MMM d").uppercased()
    }
}

/// The catalog card's header: library name and drawer label above a red double rule.
struct EXCardHeader: View {
    var size: CGFloat = 10
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("TERRA FIELD LIBRARY").font(EX.head(size)).kerning(1.5).foregroundStyle(EX.tomato)
            Spacer(minLength: 6)
            Text("QUOTATIONS").font(EX.headMed(size * 0.9)).kerning(1.2).foregroundStyle(EX.inkSoft)
        }
        .lineLimit(1)
    }
}

/// Typewriter size, line pitch and line count for a quote, chosen by length so the typed lines sit on the
/// card's ruled lines (American Typewriter's line box is ascent + descent, about 1.154 em).
struct EXQuoteType {
    var size: CGFloat
    var pitch: CGFloat
    var lines: Int
    var spacing: CGFloat { pitch - size * 1.154 }
    /// Offset of the first rule below the text frame's top: the first baseline plus a hair.
    var firstRule: CGFloat { size * 0.904 + 2.6 }
}

// MARK: - Large

struct EXQuoteLarge: View {
    var quote: Quote
    static let size = Mock.size(.large)
    static let card = CGRect(x: 13, y: 152, width: 322, height: 201)
    static let textTop: CGFloat = 36

    private var type: EXQuoteType {
        quote.text.count <= 120 ? EXQuoteType(size: 16.5, pitch: 24, lines: 4)
            : EXQuoteType(size: 14.5, pitch: 21, lines: quote.author == nil ? 5 : 4)
    }

    var body: some View {
        let s = Self.size
        let c = Self.card
        let t = type
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in Self.drawScene(ctx, size) }
            EXPlaced(rect: c) {
                EXCardStock(seed: 51, lift: 2.6, corner: 2.5, rules: (start: Self.textTop + t.firstRule, step: t.pitch), header: 26, hole: true)
            }
            EXPlaced(rect: CGRect(x: c.minX + 15, y: c.minY + 8, width: c.width - 30, height: 14), alignment: .leading) {
                EXCardHeader(size: 10)
            }
            EXPlaced(rect: CGRect(x: c.minX + 15, y: c.minY + Self.textTop, width: c.width - 30, height: c.height - Self.textTop - 46),
                     alignment: .topLeading) {
                VStack(alignment: .leading, spacing: t.spacing + 2) {
                    Text(quote.text)
                        .font(EX.type(t.size))
                        .lineSpacing(t.spacing)
                        .lineLimit(t.lines)
                        .truncationMode(.tail)
                        .exInk()
                    if let a = EXQuoteText.author(quote) {
                        Text(a.uppercased()).font(EX.headMed(10.5)).kerning(1.1).lineLimit(1).truncationMode(.tail)
                            .foregroundStyle(EX.inkSoft)
                    }
                }
            }
            EXPlaced(rect: CGRect(x: c.minX + 16, y: c.maxY - 38, width: 150, height: 24), alignment: .leading) {
                EXStamp(text: "DATE DUE  \(EXQuoteText.dueDate)", color: EX.teal, angle: -5, size: 9.5)
            }
            EXPlaced(rect: CGRect(x: c.maxX - 52, y: c.maxY - 50, width: 38, height: 38), alignment: .center) {
                EXEnamelButton(diameter: 36)
            }
            EXFinish()
        }
        .frame(width: s.width, height: s.height)
    }

    static func drawScene(_ ctx: GraphicsContext, _ s: CGSize) {
        let kit = EXKit(ctx)
        EXScenery.sky(ctx, CGRect(x: 0, y: 0, width: s.width, height: 180), kit: kit, gloom: 0)
        EXScenery.sun(ctx, center: CGPoint(x: 174, y: 30), radius: 15, kit: kit, seed: 501)
        EXScenery.cloud(ctx, center: CGPoint(x: 112, y: 60), width: 34, grey: false, kit: kit, seed: 502)
        EXScenery.cloud(ctx, center: CGPoint(x: 238, y: 66), width: 28, grey: false, kit: kit, seed: 503)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.30), CGPoint(x: 0.22, y: 0.26), CGPoint(x: 0.31, y: 0.21), CGPoint(x: 0.40, y: 0.255),
            CGPoint(x: 0.5, y: 0.20), CGPoint(x: 0.60, y: 0.255), CGPoint(x: 0.69, y: 0.21), CGPoint(x: 0.78, y: 0.26),
            CGPoint(x: 1.02, y: 0.30)],
            color: EX.hPrussian, haze: 0.5, bottom: 0.6, snow: 7, snowLine: 0.24, lift: 1.2, fuzz: 1.0, seed: 511), kit: kit)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.36), CGPoint(x: 0.2, y: 0.33), CGPoint(x: 0.3, y: 0.29), CGPoint(x: 0.42, y: 0.335),
            CGPoint(x: 0.58, y: 0.335), CGPoint(x: 0.7, y: 0.29), CGPoint(x: 0.8, y: 0.33), CGPoint(x: 1.02, y: 0.36)],
            color: EX.hTeal, haze: 0.15, bottom: 0.6, snow: 6, snowLine: 0.3, stitch: EX.thread.opacity(0.55), lift: 1.8, seed: 512), kit: kit)
        // Twin peaks, mirrored, with pylons for the cable.
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.04, y: 0.30), CGPoint(x: 0.04, y: 0.20), CGPoint(x: 0.11, y: 0.135), CGPoint(x: 0.165, y: 0.11),
            CGPoint(x: 0.22, y: 0.15), CGPoint(x: 0.29, y: 0.24), CGPoint(x: 0.36, y: 0.33), CGPoint(x: 0.43, y: 0.42)],
            color: 0xB2864A, bottom: 0.7, snow: 24, snowLine: 0.15, stitch: EX.thread.opacity(0.7),
            capStitch: EX.tomato.opacity(0.8), lift: 2.6, fuzz: 1.3, seed: 513), kit: kit)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: 0.57, y: 0.42), CGPoint(x: 0.64, y: 0.33), CGPoint(x: 0.71, y: 0.24), CGPoint(x: 0.78, y: 0.15),
            CGPoint(x: 0.835, y: 0.11), CGPoint(x: 0.89, y: 0.135), CGPoint(x: 0.96, y: 0.20), CGPoint(x: 1.04, y: 0.30)],
            color: 0xC0703A, bottom: 0.7, snow: 24, snowLine: 0.15, stitch: EX.thread.opacity(0.7),
            capStitch: EX.mustard.opacity(0.9), lift: 2.6, fuzz: 1.3, seed: 514), kit: kit)
        let a = CGPoint(x: 0.165 * s.width + 2, y: 0.11 * s.height - 14)
        let b = CGPoint(x: 0.835 * s.width - 2, y: 0.11 * s.height - 14)
        EXScenery.pylon(ctx, top: a, height: 15)
        EXScenery.pylon(ctx, top: b, height: 15)
        EXScenery.cableCar(ctx, from: a, to: b, sag: 13, at: 0.5, kit: kit)
        // Foreground meadow and pines in front of the card's top edge.
        let ground = [CGPoint(x: -0.02, y: 0.425), CGPoint(x: 0.15, y: 0.395), CGPoint(x: 0.33, y: 0.415), CGPoint(x: 0.5, y: 0.40),
                      CGPoint(x: 0.67, y: 0.415), CGPoint(x: 0.85, y: 0.395), CGPoint(x: 1.02, y: 0.425)]
        EXScenery.ridge(ctx, size: s, EXRidge(top: ground, color: EX.hOlive, bottom: 1.1, shade: false, lift: 2.2, seed: 515), kit: kit)
        EXScenery.forest(ctx, size: s, ground: ground, xs: 0.0...1.0, count: 16, heights: 12...22, color: EX.hPine, seed: 516)
    }
}

// MARK: - Medium

struct EXQuoteMedium: View {
    var quote: Quote
    static let size = Mock.size(.medium)
    static let card = CGRect(x: 66, y: 10, width: 216, height: 144)
    static let textTop: CGFloat = 30

    private var type: EXQuoteType {
        quote.text.count <= 80 ? EXQuoteType(size: 13, pitch: 18.5, lines: 4)
            : EXQuoteType(size: 11.5, pitch: 16.5, lines: quote.author == nil ? 5 : 4)
    }

    var body: some View {
        let s = Self.size
        let c = Self.card
        let t = type
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in Self.drawScene(ctx, size) }
            EXPlaced(rect: c) {
                EXCardStock(seed: 61, lift: 2.4, corner: 2.2, rules: (start: Self.textTop + t.firstRule, step: t.pitch), header: 22, hole: false)
            }
            EXPlaced(rect: CGRect(x: c.minX + 12, y: c.minY + 6, width: c.width - 24, height: 13), alignment: .leading) {
                EXCardHeader(size: 8.5)
            }
            EXPlaced(rect: CGRect(x: c.minX + 12, y: c.minY + Self.textTop, width: c.width - 24, height: c.height - Self.textTop - 7),
                     alignment: .topLeading) {
                // The date-due stamp only goes on when the quote leaves room for it.
                ViewThatFits(in: .vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        typed(t)
                        Spacer(minLength: 6)
                        EXStamp(text: "DATE DUE  \(EXQuoteText.dueDate)", color: EX.teal, angle: -4, size: 8)
                            .padding(.leading, 2)
                            .padding(.bottom, 2)
                    }
                    typed(t)
                }
            }
            EXPlaced(rect: CGRect(x: 297, y: 115, width: 36, height: 36), alignment: .center) { EXEnamelButton(diameter: 32) }
            EXFinish()
        }
        .frame(width: s.width, height: s.height)
    }

    private func typed(_ t: EXQuoteType) -> some View {
        VStack(alignment: .leading, spacing: t.spacing + 1.5) {
            Text(quote.text)
                .font(EX.type(t.size))
                .lineSpacing(t.spacing)
                .lineLimit(t.lines)
                .truncationMode(.tail)
                .exInk()
            if let a = EXQuoteText.author(quote) {
                Text(a.uppercased()).font(EX.headMed(9.5)).kerning(1).lineLimit(1).truncationMode(.tail)
                    .foregroundStyle(EX.inkSoft)
            }
        }
    }

    static func drawScene(_ ctx: GraphicsContext, _ s: CGSize) {
        let kit = EXKit(ctx)
        EXScenery.sky(ctx, CGRect(origin: .zero, size: s), kit: kit, gloom: 0)
        EXScenery.sun(ctx, center: CGPoint(x: 30, y: 30), radius: 11, kit: kit, seed: 601)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.62), CGPoint(x: 0.06, y: 0.50), CGPoint(x: 0.14, y: 0.60), CGPoint(x: 0.5, y: 0.55),
            CGPoint(x: 0.86, y: 0.60), CGPoint(x: 0.94, y: 0.48), CGPoint(x: 1.02, y: 0.60)],
            color: EX.hPrussian, haze: 0.48, snow: 6, snowLine: 0.55, lift: 1.2, fuzz: 1.0, seed: 611), kit: kit)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.03, y: 0.62), CGPoint(x: 0.03, y: 0.48), CGPoint(x: 0.08, y: 0.37), CGPoint(x: 0.12, y: 0.42),
            CGPoint(x: 0.17, y: 0.58), CGPoint(x: 0.22, y: 0.74)],
            color: 0xB2864A, bottom: 1.1, snow: 15, snowLine: 0.45, stitch: EX.thread.opacity(0.7), capStitch: EX.tomato.opacity(0.8),
            lift: 2.4, seed: 612), kit: kit)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: 0.78, y: 0.74), CGPoint(x: 0.83, y: 0.56), CGPoint(x: 0.88, y: 0.40), CGPoint(x: 0.92, y: 0.34),
            CGPoint(x: 0.97, y: 0.46), CGPoint(x: 1.03, y: 0.60)],
            color: 0xC0703A, bottom: 1.1, snow: 15, snowLine: 0.45, stitch: EX.thread.opacity(0.7), capStitch: EX.mustard.opacity(0.9),
            lift: 2.4, seed: 613), kit: kit)
        EXScenery.balloon(ctx, center: CGPoint(x: 312, y: 22), radius: 9, string: 12, kit: kit, seed: 614)
        let ground = [CGPoint(x: -0.02, y: 0.86), CGPoint(x: 0.08, y: 0.80), CGPoint(x: 0.2, y: 0.85), CGPoint(x: 0.5, y: 0.84),
                      CGPoint(x: 0.8, y: 0.85), CGPoint(x: 0.92, y: 0.80), CGPoint(x: 1.02, y: 0.86)]
        EXScenery.ridge(ctx, size: s, EXRidge(top: ground, color: EX.hOlive, shade: false, lift: 2.2, seed: 615), kit: kit)
        EXScenery.forest(ctx, size: s, ground: ground, xs: 0.0...0.2, count: 5, heights: 12...19, color: EX.hPine, seed: 616)
        EXScenery.forest(ctx, size: s, ground: ground, xs: 0.81...0.86, count: 1, heights: 13...16, color: EX.hPine, seed: 617)
    }
}

// MARK: - Small

struct EXQuoteSmall: View {
    var quote: Quote
    static let size = Mock.size(.small)
    static let card = CGRect(x: 12, y: 22, width: 140, height: 84)

    private var typeSize: (CGFloat, Int) {
        let n = quote.text.count
        if n <= 26 { return (15, 2) }
        if n <= 70 { return (12.5, 3) }
        return (11, 4)
    }

    var body: some View {
        let s = Self.size
        let c = Self.card
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in Self.drawScene(ctx, size) }
            EXPlaced(rect: c) { EXCardStock(seed: 71, lift: 2.4, corner: 2, header: 3) }
            Canvas { ctx, _ in Self.drawHangers(ctx) }
            EXPlaced(rect: CGRect(x: c.minX + 10, y: c.minY + 10, width: c.width - 20, height: c.height - 16), alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.text)
                        .font(EX.type(typeSize.0))
                        .lineSpacing(1)
                        .lineLimit(typeSize.1)
                        .truncationMode(.tail)
                        .exInk()
                    // Author and, for a short quote with room on the line, a little date-due stamp.
                    if quote.text.count <= 70 {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                authorLine
                                Spacer(minLength: 4)
                                EXStamp(text: "DUE \(EXQuoteText.dueDate)", color: EX.teal, angle: -5, size: 7)
                            }
                            authorLine
                        }
                    } else {
                        authorLine
                    }
                }
            }
            EXFinish()
        }
        .frame(width: s.width, height: s.height)
    }

    @ViewBuilder private var authorLine: some View {
        if let a = EXQuoteText.author(quote) {
            Text(a.uppercased()).font(EX.headMed(9)).kerning(1).lineLimit(1).truncationMode(.tail)
                .foregroundStyle(EX.inkSoft)
        }
    }

    /// Two grommets and the strings up to the cable.
    static func drawHangers(_ ctx: GraphicsContext) {
        for x in [card.minX + 22, card.maxX - 22] {
            let g = CGPoint(x: x, y: card.minY + 6)
            var str = Path()
            str.move(to: CGPoint(x: x, y: 13.5))
            str.addLine(to: CGPoint(x: g.x, y: g.y))
            ctx.stroke(str.offsetBy(dx: 0.6, dy: 0.6), with: .color(EX.shadow.opacity(0.35)), lineWidth: 0.7)
            ctx.stroke(str, with: .color(EX.cream), lineWidth: 0.7)
            ctx.fill(Path(ellipseIn: CGRect(x: g.x - 2.4, y: g.y - 2.4, width: 4.8, height: 4.8)), with: .color(EX.brass))
            ctx.fill(Path(ellipseIn: CGRect(x: g.x - 1.2, y: g.y - 1.2, width: 2.4, height: 2.4)), with: .color(EX.shadow.opacity(0.8)))
        }
    }

    static func drawScene(_ ctx: GraphicsContext, _ s: CGSize) {
        let kit = EXKit(ctx)
        EXScenery.sky(ctx, CGRect(origin: .zero, size: s), kit: kit, gloom: 0)
        EXScenery.sun(ctx, center: CGPoint(x: 138, y: 108), radius: 10, kit: kit, seed: 701, wire: false)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.72), CGPoint(x: 0.12, y: 0.62), CGPoint(x: 0.24, y: 0.69), CGPoint(x: 0.40, y: 0.60),
            CGPoint(x: 0.55, y: 0.70), CGPoint(x: 0.70, y: 0.64), CGPoint(x: 1.02, y: 0.74)],
            color: EX.hPrussian, haze: 0.45, snow: 5, snowLine: 0.66, lift: 1.2, fuzz: 1.0, seed: 711), kit: kit)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.86), CGPoint(x: 0.08, y: 0.74), CGPoint(x: 0.17, y: 0.66), CGPoint(x: 0.25, y: 0.71),
            CGPoint(x: 0.33, y: 0.80), CGPoint(x: 0.42, y: 0.70), CGPoint(x: 0.52, y: 0.635), CGPoint(x: 0.61, y: 0.69),
            CGPoint(x: 0.72, y: 0.82), CGPoint(x: 0.80, y: 0.77), CGPoint(x: 0.90, y: 0.84), CGPoint(x: 1.02, y: 0.80)],
            color: 0xB2864A, snow: 9, snowLine: 0.72, stitch: EX.thread.opacity(0.7), capStitch: EX.tomato.opacity(0.8),
            lift: 2.2, seed: 712), kit: kit)
        let ground = [CGPoint(x: -0.02, y: 0.92), CGPoint(x: 0.2, y: 0.87), CGPoint(x: 0.45, y: 0.91), CGPoint(x: 0.7, y: 0.88),
                      CGPoint(x: 1.02, y: 0.92)]
        EXScenery.ridge(ctx, size: s, EXRidge(top: ground, color: EX.hOlive, shade: false, lift: 2.0, seed: 713), kit: kit)
        EXScenery.forest(ctx, size: s, ground: ground, xs: 0.0...1.0, count: 9, heights: 9...14, color: EX.hPine, seed: 714)
        // The cable the placard hangs from, strung edge to edge.
        var cable = Path()
        cable.move(to: CGPoint(x: -2, y: 11))
        cable.addQuadCurve(to: CGPoint(x: s.width + 2, y: 11), control: CGPoint(x: s.width / 2, y: 17))
        ctx.stroke(cable.offsetBy(dx: 0.8, dy: 1.6), with: .color(EX.shadow.opacity(0.2)), lineWidth: 0.7)
        ctx.stroke(cable, with: .color(EX.ink.opacity(0.8)), lineWidth: 0.7)
    }
}

// MARK: - Wallpaper

/// A chunky striped knit, like the crew's sweaters, under a pool of warm light.
struct EXWallpaper: View {
    var body: some View {
        ZStack {
            EX.tex("wall").resizable()
            RadialGradient(colors: [Color(hex: 0xFFE2A6).opacity(0.18), .clear], center: UnitPoint(x: 0.2, y: 0.05), startRadius: 0, endRadius: 700)
                .blendMode(.softLight)
        }
    }
}
