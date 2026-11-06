import SwiftUI

// The Quote widget as a cover headline. A giant gilt opening quotation mark hangs in the painted sky with the horn of
// the peak rising between its two marks; the quote itself is set as the headline in large italic Baskerville on the
// painting's dark ground, the author beneath in small spaced capitals. No weather here, so the painting follows the
// clock alone (the entry's date). The next-quote control sits in the bottom corner (medium and large); a fetch
// error is a quiet peach line beside or under the author.

/// The whole Quote widget, painting included, scaled from its iPhone 17 layout to the space it is offered.
/// `next` is the next-quote control: the widget passes Button(intent: NextQuoteIntent()) { CoverNextButton() },
/// previews and renders pass CoverNextButton(). The small widget has no button and ignores it.
struct CoverQuoteView<Next: View>: View {
    var quote: Quote
    var size: BaroqueSize
    var date: Date
    var error: String?
    var next: Next

    init(quote: Quote, size: BaroqueSize, date: Date, error: String? = nil, @ViewBuilder next: () -> Next) {
        self.quote = quote
        self.size = size
        self.date = date
        self.error = error
        self.next = next()
    }

    var body: some View {
        CoverFrame(size: size) {
            switch size {
            case .large: CoverQuoteLarge(quote: quote, now: date, error: error) { next }
            case .medium: CoverQuoteMedium(quote: quote, now: date, error: error) { next }
            case .small: CoverQuoteSmall(quote: quote, now: date, error: error)
            }
        }
    }
}

struct CoverQuoteScene: View {
    var canvas: CoverCanvas
    var now: Date

    var body: some View {
        CoverScene(canvas: canvas, glyph: "\u{201C}", clock: SkyClock(now: now, weather: nil), condition: .clear,
                   phase: MoonPhase(date: now))
    }
}

/// The quote in the largest of `sizes` that fits the space it is offered; the last size truncates with an ellipsis.
struct CoverQuoteText: View {
    var text: String
    var sizes: [CGFloat]
    var lineLimit: Int

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes.dropLast(), id: \.self) { s in
                line(s).fixedSize(horizontal: false, vertical: true)
            }
            line(sizes.last ?? 13)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ s: CGFloat) -> some View {
        Text(text)
            .font(CoverType.italic(s))
            .lineSpacing(s * 0.08)
            .foregroundStyle(CoverInk.cream)
    }
}

/// The author in small spaced capitals after an em rule; nothing at all when the author is unknown.
struct CoverAuthor: View {
    var author: String?
    var size: CGFloat

    var body: some View {
        if let author, !author.isEmpty {
            HStack(spacing: 7) {
                Rectangle().fill(CoverInk.creamFaint.opacity(0.75)).frame(width: 14, height: 0.7)
                Text(author).coverCaps(size, CoverInk.creamSoft, tracking: 1.6).lineLimit(1).truncationMode(.tail)
            }
        }
    }
}

// MARK: - Large

/// The mark and the peak in the sky above; the headline fills the dark ground below, as large as it fits, and the
/// author shares the bottom line with the button (the error, if any, under the author).
struct CoverQuoteLarge<Next: View>: View {
    var quote: Quote
    var now: Date
    var error: String?
    @ViewBuilder var next: Next

    static var top: CGFloat { 190 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CoverQuoteScene(canvas: .quoteLarge, now: now)
            CoverPaintingTitle()
                .frame(width: 348 - 32, height: Self.top - 14, alignment: .bottomLeading)
                .offset(x: 16)
            VStack(alignment: .leading, spacing: 0) {
                CoverQuoteText(text: quote.text, sizes: [29, 27, 25, 23.5, 22, 20.5, 19, 17.5, 16, 15], lineLimit: 8)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        CoverAuthor(author: quote.author, size: 9)
                        if let error { CoverErrorLine(message: error, size: 8.5) }
                    }
                    Spacer(minLength: 0)
                    next
                }
                .frame(height: error == nil ? 24 : 28)
            }
            .coverOnPaint(0.5)
            .frame(width: 316, height: 365 - Self.top - 14, alignment: .topLeading)
            .offset(x: 16, y: Self.top)
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }
}

// MARK: - Medium

/// The mark and its peak on the left; the headline and author on the dark wood at the right, the button below
/// (the error, if any, beside it).
struct CoverQuoteMedium<Next: View>: View {
    var quote: Quote
    var now: Date
    var error: String?
    @ViewBuilder var next: Next

    var body: some View {
        ZStack(alignment: .topLeading) {
            CoverQuoteScene(canvas: .quoteMedium, now: now)
            // The headline and its author as one block, centred in the column above the button's corner.
            VStack(alignment: .leading, spacing: 8) {
                CoverQuoteText(text: quote.text, sizes: [17.5, 16.5, 15.5, 14.5, 13.5, 13], lineLimit: 5)
                CoverAuthor(author: quote.author, size: 8.5)
            }
            .coverOnPaint(0.5)
            .frame(width: 160, height: 164 - 16 - 40, alignment: .leading)  // ends above the button's corner
            .offset(x: 172, y: 16)
            if let error {
                // In the column, level with the button and clear of it.
                CoverErrorLine(message: error, size: 8)
                    .coverOnPaint(0.5)
                    .frame(width: 348 - 172 - 14 - 24 - 10, height: 24, alignment: .leading)
                    .offset(x: 172, y: 164 - 14 - 24)
            }
            next
                .padding(14)
                .frame(width: 348, height: 164, alignment: .bottomTrailing)
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }
}

// MARK: - Small

/// The mark and its peak fill the top; the quote rests on the dark ground below, the error (if any) at its foot.
struct CoverQuoteSmall: View {
    var quote: Quote
    var now: Date
    var error: String?

    var body: some View {
        let height: CGFloat = error == nil ? 60 : 72
        ZStack(alignment: .topLeading) {
            CoverQuoteScene(canvas: .quoteSmall, now: now)
            VStack(alignment: .leading, spacing: 5) {
                CoverQuoteText(text: quote.text, sizes: [15, 14, 13, 12], lineLimit: 3)
                CoverAuthor(author: quote.author, size: 8)
                if let error { CoverErrorLine(message: error, size: 8) }
            }
            .coverOnPaint(0.6)
            .frame(width: 132, height: height, alignment: .bottomLeading)
            .offset(x: 16, y: 164 - 16 - height)
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }
}
