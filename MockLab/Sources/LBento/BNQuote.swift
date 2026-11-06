import SwiftUI

// The Quote widget as a bento box:
//   large, medium   quote slab (hero)        | lancet window: tonight's moon over the ridges
//                   author well with a seal  | the next-quote pebble in its own well
//   small           quote slab with its author
//                   a sliver of window: ridges and the moon

struct BNQuoteWidget: View {
    var quote: Quote
    var size: BaroqueSize
    var canvas: CGSize
    var date: Date
    var error: String? = nil

    var body: some View {
        Group {
            if size == .small { small } else { tall }
        }
        .frame(width: canvas.width, height: canvas.height)
        .overlay(BNRim())
    }

    // Large and medium share one plan: two rows by two columns, the right column the window and the arrow.
    private var tall: some View {
        let g = BN.grid(canvas)
        let rows = g.bnRows([.fr(1), .pt(size == .large ? 50 : 40)])
        let top = rows[0].bnColumns([.fr(1), .pt(80)])
        let bottom = rows[1].bnColumns([.fr(1), .pt(80)])
        let window = top[1], author = bottom[0], arrow = bottom[1]
        // No author and nothing to report: the quote takes the author's cell too, beside the arrow.
        let hasFooter = !(quote.author ?? "").isEmpty || error != nil
        let text = hasFooter ? top[0] : top[0].union(bottom[0])
        return ZStack {
            BNQuoteScene(plan: .plan(size, window: window, canvas: canvas), date: date)
            BNTile(rect: window, material: .window) { Color.clear }
            BNTile(rect: text, material: .slab) {
                BNQuoteText(quote: quote, size: size)
            }
            if hasFooter {
                BNTile(rect: author, material: .well) {
                    BNAuthorWell(author: quote.author, error: error, large: size == .large)
                }
            }
            BNTile(rect: arrow, material: .well) {
                NextQuoteArrow()
            }
            BNStud(size: 8).position(x: top[0].maxX + BN.gutter / 2, y: rows[0].maxY + BN.gutter / 2)
        }
    }

    private var small: some View {
        let g = BN.grid(canvas)
        let rows = g.bnRows([.fr(1), .pt(44)])
        let text = rows[0], window = rows[1]
        return ZStack {
            BNQuoteScene(plan: .plan(.small, window: window, canvas: canvas), date: date)
            BNTile(rect: window, material: .window) { Color.clear }
            BNTile(rect: text, material: .slab) {
                BNQuoteText(quote: quote, size: .small, error: error)
            }
        }
    }
}

/// The quote on its slab, in the largest size that shows all of it. Small also carries the author.
struct BNQuoteText: View {
    var quote: Quote
    var size: BaroqueSize
    var error: String? = nil

    private var textSizes: [CGFloat] {
        switch size {
        case .small: return [17, 15.5, 14, 13, 12, 11]
        case .medium: return [21, 19, 17.5, 16, 15, 14, 13, 12]
        case .large: return [36, 33, 30, 28, 26, 24, 22, 20, 18, 16, 14]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .vertical) {
                ForEach(textSizes, id: \.self) { s in
                    quoteText(s)
                }
                quoteText(textSizes.last ?? 12)
            }
            .frame(maxHeight: .infinity, alignment: .leading)
            .layoutPriority(1)

            if size == .small {
                VStack(alignment: .leading, spacing: 2) {
                    if let a = quote.author, !a.isEmpty {
                        HStack(spacing: 6) {
                            Rectangle().fill(Stone.copperLight).frame(width: 12, height: 1.5)
                            Text(a)
                                .font(.system(size: 9.5, weight: .semibold))
                                .tracking(0.8)
                                .textCase(.uppercase)
                                .foregroundStyle(Stone.gold)
                                .raised()
                                .lineLimit(1)
                                .minimumScaleFactor(0.95)
                        }
                    }
                    if let error {
                        ErrorLine(message: error, color: Stone.copperInk, fontSize: 9.5)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, size == .large ? 15 : (size == .medium ? 13 : 11))
        .padding(.vertical, size == .large ? 14 : (size == .medium ? 9 : 10))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .topLeading) { watermark }
    }

    private func quoteText(_ pointSize: CGFloat) -> some View {
        Text(quote.text)
            .font(Serif.font(pointSize, weight: .medium, italic: true))
            .foregroundStyle(Stone.parchment)
            .raised()
            .lineSpacing(pointSize > 18 ? 2 : 1)
    }

    // An oversized opening quote pressed faintly into the board.
    private var watermark: some View {
        Text("\u{201C}")
            .font(Serif.font(size == .large ? 170 : (size == .medium ? 120 : 96), weight: .bold))
            .foregroundStyle(Stone.gold.opacity(0.11).shadow(.inner(color: .black.opacity(0.5), radius: 2, x: 0, y: 2.5)))
            .shadow(color: Stone.shadow.opacity(0.5), radius: 0, x: 0, y: 1.2)
            .fixedSize()
            .offset(x: size == .large ? -2 : -4, y: size == .large ? -36 : (size == .medium ? -28 : -24))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: BN.radius, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The author carved beside the arrow: a gilt seal with their initial (a sparkle when there is none), then the name.
struct BNAuthorWell: View {
    var author: String?
    var error: String?
    var large: Bool

    private var initial: String? {
        guard let a = author, let c = a.first(where: { $0.isLetter }) else { return nil }
        return String(c).uppercased()
    }

    var body: some View {
        HStack(spacing: large ? 10 : 8) {
            seal
            VStack(alignment: .leading, spacing: 2) {
                if let a = author, !a.isEmpty {
                    Text(a)
                        .font(.system(size: large ? 10.5 : 10, weight: .semibold))
                        .tracking(large ? 1.4 : 1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Stone.gold)
                        .legible()
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                if let error {
                    ErrorLine(message: error, color: Stone.copperInk, fontSize: 9.5)
                        .legible()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, large ? 10 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var seal: some View {
        let d: CGFloat = large ? 30 : 25
        return ZStack {
            Circle().inset(by: 2.5).stroke(Stone.gold.opacity(0.45), lineWidth: 0.7)
            if let initial {
                Text(initial)
                    .font(Serif.font(large ? 16 : 13.5, weight: .semibold, italic: true))
                    .foregroundStyle(Gilt.style)
                    .raised()
            } else {
                Sparkle().fill(Stone.gold).frame(width: d * 0.34, height: d * 0.42)
            }
        }
        .frame(width: d, height: d)
        .carved(Circle())
    }
}
