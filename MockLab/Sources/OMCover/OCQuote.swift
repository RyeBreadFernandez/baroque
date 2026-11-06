import SwiftUI

// The Quote widget as a cover headline. A giant gilt opening quotation mark hangs in the painted sky with the horn of
// the peak rising between its two marks; the quote itself is set as the headline in large italic Baskerville on the
// painting's dark ground, the author beneath in small spaced capitals. No weather here, so the painting follows the
// clock alone. The next-quote button is a small cream disc in the bottom corner (medium and large).

struct OCQuote: View {
    var quote: Quote
    var family: Family
    var now: Date = Mock.now

    var body: some View {
        switch family {
        case .large: OCQuoteLarge(quote: quote, now: now)
        case .medium: OCQuoteMedium(quote: quote, now: now)
        case .small: OCQuoteSmall(quote: quote, now: now)
        }
    }
}

struct OCQuoteScene: View {
    var canvas: OCCanvas
    var now: Date

    var body: some View {
        OCScene(canvas: canvas, glyph: "\u{201C}", clock: SkyClock(now: now, weather: nil), condition: .clear,
                phase: MoonPhase(date: now))
    }
}

/// The quote in the largest of `sizes` that fits the space it is offered; the last size truncates with an ellipsis.
struct OCQuoteText: View {
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
            .font(OMType.italic(s))
            .lineSpacing(s * 0.08)
            .foregroundStyle(OMInk.cream)
    }
}

/// The author in small spaced capitals after an em rule; nothing at all when the author is unknown.
struct OCAuthor: View {
    var author: String?
    var size: CGFloat

    var body: some View {
        if let author, !author.isEmpty {
            HStack(spacing: 7) {
                Rectangle().fill(OMInk.creamFaint.opacity(0.75)).frame(width: 14, height: 0.7)
                Text(author).omCaps(size, OMInk.creamSoft, tracking: 1.6).lineLimit(1).truncationMode(.tail)
            }
        }
    }
}

// MARK: - Large

/// The mark and the peak in the sky above; the headline fills the dark ground below, as large as it fits, and the
/// author shares the bottom line with the button.
struct OCQuoteLarge: View {
    var quote: Quote
    var now: Date

    static let top: CGFloat = 190

    var body: some View {
        ZStack(alignment: .topLeading) {
            OCQuoteScene(canvas: .quoteLarge, now: now)
            OCPaintingTitle()
                .frame(width: 348 - 32, height: Self.top - 14, alignment: .bottomLeading)
                .offset(x: 16)
            VStack(alignment: .leading, spacing: 0) {
                OCQuoteText(text: quote.text, sizes: [29, 27, 25, 23.5, 22, 20.5, 19, 17.5, 16, 15], lineLimit: 8)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                HStack(alignment: .center, spacing: 8) {
                    OCAuthor(author: quote.author, size: 9)
                    Spacer(minLength: 0)
                    OMNextButton()
                }
                .frame(height: 24)
            }
            .omOnPaint(0.5)
            .frame(width: 316, height: 365 - Self.top - 14, alignment: .topLeading)
            .offset(x: 16, y: Self.top)
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }
}

// MARK: - Medium

/// The mark and its peak on the left; the headline and author on the dark wood at the right, the button below.
struct OCQuoteMedium: View {
    var quote: Quote
    var now: Date

    var body: some View {
        ZStack(alignment: .topLeading) {
            OCQuoteScene(canvas: .quoteMedium, now: now)
            // The headline and its author as one block, centred in the column above the button's corner.
            VStack(alignment: .leading, spacing: 8) {
                OCQuoteText(text: quote.text, sizes: [17.5, 16.5, 15.5, 14.5, 13.5, 13], lineLimit: 5)
                OCAuthor(author: quote.author, size: 8.5)
            }
            .omOnPaint(0.5)
            .frame(width: 160, height: 164 - 16 - 40, alignment: .leading)  // ends above the button's corner
            .offset(x: 172, y: 16)
            OMNextButton()
                .padding(14)
                .frame(width: 348, height: 164, alignment: .bottomTrailing)
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }
}

// MARK: - Small

/// The mark and its peak fill the top; the quote rests on the dark ground below.
struct OCQuoteSmall: View {
    var quote: Quote
    var now: Date

    var body: some View {
        ZStack(alignment: .topLeading) {
            OCQuoteScene(canvas: .quoteSmall, now: now)
            VStack(alignment: .leading, spacing: 5) {
                OCQuoteText(text: quote.text, sizes: [15, 14, 13, 12], lineLimit: 3)
                OCAuthor(author: quote.author, size: 8)
            }
            .omOnPaint(0.6)
            .frame(width: 132, height: 60, alignment: .bottomLeading)
            .offset(x: 16, y: 164 - 16 - 60)
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }
}
