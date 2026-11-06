import SwiftUI

// The Quote widget: an owl sage in the overworld speaks the quote in a dialogue window,
// with the author on a name tab and a round ▼ button to page to the next quote.

struct QuoteFit {
    let lines: [String]
    let px: CGFloat
    let yOffset: CGFloat
    var lineH: CGFloat { CGFloat(PixelFont.lineAdvance) * px }

    /// Wrap the quote in the pixel font at the largest pixel size that fits `box`,
    /// shortening lines that would run into `avoid` (the next button). Nil means use the Menlo fallback.
    static func make(_ text: String, box: CGRect, avoid: CGRect?, scales: [CGFloat] = [2, 5.0 / 3.0, 4.0 / 3.0],
                     center: Bool = true) -> QuoteFit? {
        for p in scales {
            let lh = CGFloat(PixelFont.lineAdvance) * p
            let glyphH = 9 * p
            let maxLines = max(1, Int((box.height - glyphH) / lh) + 1)
            let full = Int(box.width / p)
            var cap = full
            func wrap(_ off: CGFloat) -> [String] {
                PixelFont.wrap(text) { i in
                    let y0 = box.minY + off + CGFloat(i) * lh
                    var right = box.maxX
                    if let a = avoid, y0 + glyphH > a.minY - 3 { right = min(right, a.minX - 8) }
                    return min(cap, Int((right - box.minX) / p))
                }
            }
            let greedy = wrap(0)
            guard greedy.count <= maxLines else { continue }
            // Balance the rag: try narrower measures with the same line count and keep the evenest
            // (squared slack on every line but the last, plus a penalty for a short last line).
            var best = full
            var bestCost = Double.infinity
            for c in stride(from: full, through: full / 2, by: -1) {
                cap = c
                let ls = wrap(0)
                guard ls.count == greedy.count else { continue }
                var cost = 0.0
                for (i, l) in ls.enumerated() {
                    let slack = Double(c - PixelFont.width(l))
                    if i < ls.count - 1 { cost += slack * slack } else if Double(PixelFont.width(l)) < Double(c) * 0.45 {
                        let short = Double(c) * 0.45 - Double(PixelFont.width(l))
                        cost += short * short * 2
                    }
                }
                if cost < bestCost { bestCost = cost; best = c }
            }
            cap = best
            let lines = wrap(0)
            if center {
                let blockH = CGFloat(lines.count - 1) * lh + 7 * p
                let off = (max(0, (box.height - blockH) / 2) / p).rounded(.down) * p
                let moved = wrap(off)
                if moved.count == lines.count { return QuoteFit(lines: moved, px: p, yOffset: off) }
            }
            return QuoteFit(lines: lines, px: p, yOffset: 0)
        }
        return nil
    }

    func draw(_ ctx: GraphicsContext, box: CGRect) {
        for (i, line) in lines.enumerated() {
            PixelFont.draw(ctx, line, x: box.minX, y: box.minY + yOffset + CGFloat(i) * lineH, px: px, color: .cream, shadow: .ink)
        }
    }
}

/// Menlo fallback for quotes too long for the pixel font.
struct MenloQuote: View {
    let text: String
    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach([13.0, 12.0, 11.0, 10.0], id: \.self) { size in
                QuestText(text: text, size: size, lines: 20)
                    .fixedSize(horizontal: false, vertical: true)
            }
            QuestText(text: text, size: 10, lines: 20).minimumScaleFactor(0.5)
        }
    }
}

struct NameTab {
    let text: String
    let artW: Int
    let px: CGFloat
}

enum QuoteKit {
    /// The author on a name tab: the 2 pt pixel if it fits, else the fine pixel, else truncated with an ellipsis.
    static func tab(_ author: String, maxArt: Int) -> NameTab {
        let w = PixelFont.width(author)
        if w + 8 <= maxArt { return NameTab(text: author, artW: w + 8, px: 2) }
        let avail = Int(CGFloat(maxArt - 8) * 2 / PQ.fine)
        let text = fitted(author, avail)
        let artW = Int((CGFloat(PixelFont.width(text)) * PQ.fine / 2).rounded(.up)) + 8
        return NameTab(text: text, artW: artW, px: PQ.fine)
    }

    /// Truncate to `avail` font pixels with an ellipsis.
    static func fitted(_ s: String, _ avail: Int) -> String {
        if PixelFont.width(s) <= avail { return s }
        var t = s
        while !t.isEmpty && PixelFont.width(t + "…") > avail { t.removeLast() }
        return t.trimmingCharacters(in: .whitespaces) + "…"
    }

    static func author(_ q: Quote) -> String? {
        guard let a = q.author?.trimmingCharacters(in: .whitespaces), !a.isEmpty else { return nil }
        return a.uppercased()
    }
}

// MARK: - Large

struct QuoteLarge: View {
    let q: Quote
    static let avoid = CGRect(x: 302, y: 319, width: 30, height: 30)

    var box: CGRect { QuoteKit.author(q) == nil ? CGRect(x: 22, y: 222, width: 304, height: 122) : CGRect(x: 22, y: 226, width: 304, height: 118) }
    var tab: NameTab? { QuoteKit.author(q).map { QuoteKit.tab($0, maxArt: 124) } }
    var fit: QuoteFit? { QuoteFit.make(q.text, box: box, avoid: Self.avoid) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelCanvas(buffer: art(), fine: fine)
            if fit == nil {
                Placed(x: box.minX, y: box.minY, w: 270, h: box.height, align: .topLeading) { MenloQuote(text: q.text) }
            }
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) { NextButton().padding(16) }
    }

    func art() -> PixelBuffer {
        var b = PixelBuffer(174, 183)
        b.sky(.day, to: 100)
        b.sun(34, 20, r: 5)
        b.cloud(104, 30, width: 26, seed: 61)
        b.cloud(60, 16, width: 14, seed: 62)
        b.birds([(126, 14), (132, 11), (137, 16)])
        b.mountains([Peak(x: 98, y: 20, l: 0.9, r: 0.85, snow: 11), Peak(x: 62, y: 36, snow: 6), Peak(x: 140, y: 32, snow: 7),
                     Peak(x: 20, y: 44, snow: 4), Peak(x: 174, y: 40, snow: 4)],
                    bottom: 90, style: .far, seed: 63)
        b.mountains([Peak(x: 40, y: 58, l: 1.1, r: 1.0, snow: 3), Peak(x: 122, y: 60, snow: 3), Peak(x: 82, y: 66),
                     Peak(x: 168, y: 62, snow: 2)],
                    bottom: 92, style: .near, seed: 65)
        let back = b.hills(base: 76, amp: 3, period: 64, phase: 1.1, bottom: 96, rim: .teal3, body: .teal2, dark: .teal1)
        b.forest(back, sprites: Sprites.darkPines, sink: 2, step: 3...5, seed: 66)
        let front = b.hills(base: 83, amp: 2, period: 52, phase: 2.6, bottom: 96, rim: .grass3, body: .grass2, dark: .grass1)
        b.forest(front, sprites: Sprites.pines, sink: 3, step: 5...10, seed: 67, to: 120)
        b.meadow(top: 90, bottom: 183, seed: 68, flowers: 10)
        b.chest(58, 86)
        b.boulder(146, 99, w: 18, h: 8)
        b.draw(Sprites.owl, 139, 76)

        b.window(4, 104, 166, 75)
        if let t = tab { b.plate(10, 96, t.artW, 14) }
        return b
    }

    func fine(_ ctx: GraphicsContext) {
        if let t = tab {
            PixelFont.draw(ctx, t.text, x: 28, y: t.px == 2 ? 198 : 201, px: t.px, color: .gold2)
        }
        fit?.draw(ctx, box: box)
    }
}

// MARK: - Medium

struct QuoteMedium: View {
    let q: Quote

    var box: CGRect { QuoteKit.author(q) == nil ? CGRect(x: 22, y: 38, width: 222, height: 106) : CGRect(x: 22, y: 44, width: 222, height: 100) }
    var tab: NameTab? { QuoteKit.author(q).map { QuoteKit.tab($0, maxArt: 114) } }
    var fit: QuoteFit? { QuoteFit.make(q.text, box: box, avoid: nil) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelCanvas(buffer: art(), fine: fine)
            if fit == nil {
                Placed(x: box.minX, y: box.minY, w: box.width, h: box.height, align: .topLeading) { MenloQuote(text: q.text) }
            }
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) { NextButton().padding(16) }
    }

    func art() -> PixelBuffer {
        var b = PixelBuffer(174, 82)
        b.sky(.day, to: 60)
        b.sun(152, 8, r: 3)
        b.cloud(132, 32, width: 16, seed: 71)
        b.mountains([Peak(x: 150, y: 16, l: 0.9, r: 0.9, snow: 8), Peak(x: 120, y: 26, snow: 5), Peak(x: 176, y: 28, snow: 4)],
                    bottom: 60, style: .far, seed: 72)
        b.mountains([Peak(x: 136, y: 38, snow: 2), Peak(x: 168, y: 40, snow: 2)], bottom: 62, style: .near, seed: 73)
        let back = b.hills(base: 50, amp: 2, period: 36, phase: 0.6, bottom: 64, rim: .teal3, body: .teal2, dark: .teal1)
        b.forest(back, sprites: Sprites.darkPines, sink: 2, step: 3...5, seed: 74, from: 120)
        b.meadow(top: 56, bottom: 82, seed: 75, flowers: 4)
        b.boulder(146, 55, w: 16, h: 6)
        b.draw(Sprites.owl, 139, 34)

        b.window(4, 14, 126, 65)
        if let t = tab { b.plate(10, 7, t.artW, 13) }
        return b
    }

    func fine(_ ctx: GraphicsContext) {
        if let t = tab {
            PixelFont.draw(ctx, t.text, x: 28, y: t.px == 2 ? 20 : 22, px: t.px, color: .gold2)
        }
        fit?.draw(ctx, box: box)
    }
}

// MARK: - Small

struct QuoteSmall: View {
    let q: Quote

    var box: CGRect { QuoteKit.author(q) == nil ? CGRect(x: 20, y: 76, width: 126, height: 68) : CGRect(x: 20, y: 76, width: 126, height: 52) }
    var fit: QuoteFit? { QuoteFit.make(q.text, box: box, avoid: nil) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelCanvas(buffer: art(), fine: fine)
            if fit == nil {
                Placed(x: box.minX, y: box.minY, w: box.width, h: box.height, align: .topLeading) { MenloQuote(text: q.text) }
            }
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }

    func art() -> PixelBuffer {
        var b = PixelBuffer(82, 82)
        b.sky(.day, to: 34)
        b.sun(14, 10, r: 3)
        b.mountains([Peak(x: 36, y: 10, l: 0.9, r: 0.9, snow: 7), Peak(x: 12, y: 22, snow: 3), Peak(x: 70, y: 18, snow: 4)],
                    bottom: 34, style: .far, seed: 81)
        b.mountains([Peak(x: 24, y: 26, snow: 2), Peak(x: 54, y: 24, snow: 2)], bottom: 34, style: .near, seed: 82)
        let back = b.hills(base: 28, amp: 1.5, period: 30, phase: 0.2, bottom: 36, rim: .teal3, body: .teal2, dark: .teal1)
        b.forest(back, sprites: Sprites.tinyPines, sink: 2, step: 2...4, seed: 83)
        b.meadow(top: 33, bottom: 82, seed: 84)
        b.window(4, 30, 74, 48)
        b.draw(Sprites.owl, 58, 15)
        return b
    }

    func fine(_ ctx: GraphicsContext) {
        fit?.draw(ctx, box: box)
        if let a = QuoteKit.author(q) {
            let avail = Int(box.width / PQ.fine) - PixelFont.width("— ")
            PixelFont.draw(ctx, runs: [("—", .gold1), (" " + QuoteKit.fitted(a, avail), .gold2)], x: 20, y: 134, px: PQ.fine)
        }
    }
}
