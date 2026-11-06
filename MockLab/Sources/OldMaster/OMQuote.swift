import SwiftUI

// The Quote widget: the painting with the quote set like a museum label, in the italic serif with the author in
// spaced capitals under a short rule. Large and medium carry it on the umber panel with the next-quote button in
// its corner; the small one sets it straight onto the painting's dark valley floor. No weather here, so the
// painting follows the clock alone.

struct OMQuote: View {
    var quote: Quote
    var family: Family
    var now: Date = Mock.now

    var body: some View {
        switch family {
        case .large: OMQuoteLarge(quote: quote, now: now)
        case .medium: OMQuoteMedium(quote: quote, now: now)
        case .small: OMQuoteSmall(quote: quote, now: now)
        }
    }
}

struct OMQuotePainting: View {
    var canvas: OMCanvas
    var now: Date

    var body: some View {
        OMPainting(canvas: canvas, clock: SkyClock(now: now, weather: nil), condition: .clear, phase: MoonPhase(date: now))
    }
}

/// The quote in the largest of `sizes` that fits the space it is offered; the last size truncates with an ellipsis.
struct OMQuoteText: View {
    var text: String
    var sizes: [CGFloat]
    var lineLimit: Int
    var color: Color = OMInk.cream

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes.dropLast(), id: \.self) { s in
                Text(text).font(OMType.italic(s)).lineSpacing(s * 0.14).foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(text).font(OMType.italic(sizes.last ?? 13)).lineSpacing((sizes.last ?? 13) * 0.14).foregroundStyle(color)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The label's foot: a short rule and the author in spaced capitals (nothing at all when the author is unknown).
struct OMAuthor: View {
    var author: String?
    var size: CGFloat

    var body: some View {
        if let author, !author.isEmpty {
            HStack(spacing: 7) {
                Rectangle().fill(OMInk.creamFaint.opacity(0.7)).frame(width: 14, height: 0.7)
                Text(author).omCaps(size, OMInk.creamSoft, tracking: 1.5).lineLimit(1).truncationMode(.tail)
            }
        }
    }
}

// MARK: - Large

struct OMQuoteLarge: View {
    var quote: Quote
    var now: Date

    var body: some View {
        ZStack(alignment: .bottom) {
            OMQuotePainting(canvas: .quoteLarge, now: now)
            VStack(alignment: .leading, spacing: 12) {
                OMQuoteText(text: quote.text, sizes: [18, 16.5, 15, 14], lineLimit: 8)
                    .frame(maxHeight: 150, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                if quote.author?.isEmpty == false {
                    OMAuthor(author: quote.author, size: 9)
                        .padding(.trailing, 36) // clear of the button
                } else {
                    Color.clear.frame(height: 12) // the button's row, so a long last line never runs under it
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .padding(.vertical, 16)
            // The label keeps one height for short quotes (so the painting stays framed, the words centred in it)
            // and grows for long ones; the button stays in its bottom corner either way.
            .frame(width: 328, alignment: .leading)
            .frame(minHeight: 150)
            .overlay(alignment: .bottomTrailing) {
                OMNextButton().padding(.trailing, 12).padding(.bottom, 12)
            }
            .omPanel(radius: 13)
            .padding(10)
        }
    }
}

// MARK: - Medium

struct OMQuoteMedium: View {
    var quote: Quote
    var now: Date

    var body: some View {
        ZStack(alignment: .trailing) {
            OMQuotePainting(canvas: .quoteMedium, now: now)
            VStack(alignment: .leading, spacing: 6) {
                // Centred in the space above the author line, like a museum label, whatever its length.
                OMQuoteText(text: quote.text, sizes: [18, 17, 16, 15, 14, 13], lineLimit: 5)
                    .frame(maxHeight: .infinity, alignment: .leading)
                HStack(alignment: .center, spacing: 6) {
                    OMAuthor(author: quote.author, size: 8.5)
                    Spacer(minLength: 0)
                    OMNextButton()
                }
            }
            .padding(.leading, 13)
            .padding(.trailing, 10)
            .padding(.top, 11)
            .padding(.bottom, 10)
            .frame(width: 222, height: 144, alignment: .topLeading)
            .omPanel(radius: 12)
            .padding(10)
        }
    }
}

// MARK: - Small

/// A caption on the painting: the quote over the dark valley floor, a soft umber scrim behind it.
struct OMQuoteSmall: View {
    var quote: Quote
    var now: Date

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            OMQuotePainting(canvas: .quoteSmall, now: now)
            LinearGradient(stops: [.init(color: .clear, location: 0.38), .init(color: OMInk.shadow.opacity(0.55), location: 0.75),
                                   .init(color: OMInk.shadow.opacity(0.65), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                OMQuoteText(text: quote.text, sizes: [15, 13.5, 12.5], lineLimit: 4)
                OMAuthor(author: quote.author, size: 8)
            }
            .frame(maxHeight: 84, alignment: .bottomLeading)
            .omOnPaint()
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
