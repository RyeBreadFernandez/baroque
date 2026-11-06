import SwiftUI

// The Next Up Quote widget: the same deck. The quote is set large on a raised card resting on the
// evening scene, the next cards lie loosely stacked behind it, the author sits at the card's foot, and
// the copper next-quote pebble sits on the card's lower corner, as if to turn it over.
struct NUQuoteWidget: View {
    var quote: Quote
    var family: Family
    var date: Date
    var error: String? = nil

    private var style: NUStyle { NUStyle(family) }

    var body: some View {
        Group {
            switch family {
            case .small:
                NUQuoteCard(quote: quote, style: .small, error: error)
                    .background(NUDeck(cards: 2, fan: .tilted, radius: 15))
                    .padding(EdgeInsets(top: 48, leading: 10, bottom: 10, trailing: 10))
            case .medium:
                NUQuoteCard(quote: quote, style: .medium, error: error)
                    .background(NUDeck(cards: 2, fan: .tiltedRight, radius: 18))
                    .overlay(alignment: .bottomTrailing) { flipArrow.offset(x: 9, y: 3) }
                    .padding(EdgeInsets(top: 12, leading: 12, bottom: 14, trailing: 90))
            case .large:
                NUQuoteCard(quote: quote, style: .large, error: error)
                    .background(NUDeck(cards: 2, fan: .tilted, radius: 20, spread: 1.35))
                    .overlay(alignment: .bottomTrailing) { flipArrow.offset(x: 8, y: 8) }
                    .padding(EdgeInsets(top: 76, leading: 18, bottom: 42, trailing: 24))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NUQuoteGround(style: style, date: date))
    }

    /// The widget wraps this in Button(intent: NextQuoteIntent()).
    private var flipArrow: some View {
        NextQuoteArrow()
    }
}

/// A quote set large on a raised espresso card, with a faint gilt quote mark pressed into its face and
/// the author (and any fetch error) at its foot. Shrinks to fit with ViewThatFits the way QuoteView does.
struct NUQuoteCard: View {
    var quote: Quote
    var style: NUStyle
    var error: String? = nil

    private var sizes: [CGFloat] {
        switch style {
        case .small: return [22, 20, 18, 16.5, 15, 14, 13, 12, 11]
        case .medium: return [24, 22, 20, 18.5, 17, 15.5, 14, 13, 12]
        case .large: return [34, 30, 28, 26, 24, 22, 20, 18, 16.5, 15]
        }
    }

    /// Medium and large keep the foot clear of the arrow on the card's lower corner.
    private var arrowRoom: CGFloat { style == .small ? 0 : 30 }
    private var radius: CGFloat { style == .small ? 15 : (style == .medium ? 18 : 20) }
    private var pad: EdgeInsets {
        switch style {
        case .small: return EdgeInsets(top: 12, leading: 12, bottom: 11, trailing: 11)
        case .medium: return EdgeInsets(top: 13, leading: 16, bottom: 12, trailing: 14)
        case .large: return EdgeInsets(top: 20, leading: 20, bottom: 18, trailing: 18)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .vertical) {
                ForEach(sizes, id: \.self) { s in
                    quoteText(s)
                }
                // Too long for every size: fill the space and truncate the tail.
                quoteText(sizes.last ?? 11)
            }
            // Short quotes sit in the middle of the card instead of leaving a hole above the author.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .layoutPriority(1)
            foot
        }
        .padding(pad)
        .background {
            watermark.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .stoneSlab(.panel, radius: radius, depth: style == .small ? 2.5 : 3)
    }

    @ViewBuilder
    private var foot: some View {
        let hasAuthor = !(quote.author ?? "").isEmpty
        if hasAuthor || error != nil {
            VStack(alignment: .leading, spacing: 3) {
                if let a = quote.author, !a.isEmpty {
                    HStack(spacing: style == .small ? 6 : 8) {
                        Rectangle()
                            .fill(Stone.copperLight)
                            .frame(width: style == .small ? 12 : 18, height: 1.5)
                        Text(a)
                            .font(.system(size: style == .small ? 9 : 10, weight: .semibold))
                            .tracking(style == .small ? 0.8 : 1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Stone.gold)
                            .raised()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if let error {
                    ErrorLine(message: error, color: Stone.copperInk, fontSize: style == .small ? 9.5 : 10)
                }
            }
            .padding(.trailing, arrowRoom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, style == .small ? 5 : 8)
        }
    }

    // An oversized opening quote in faint gold leaf pressed into the card's face.
    private var watermark: some View {
        Text("\u{201C}")
            .font(Serif.font(style == .small ? 110 : (style == .medium ? 150 : 200), weight: .bold))
            .foregroundStyle(Stone.gold.opacity(0.16).shadow(.inner(color: .black.opacity(0.5), radius: 2, x: 0, y: 2.5)))
            .shadow(color: Stone.shadow.opacity(0.4), radius: 0, x: 0, y: 1)
            .fixedSize()
            .offset(x: style == .small ? -4 : -6, y: style == .small ? -26 : (style == .medium ? -36 : -46))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityHidden(true)
    }

    private func quoteText(_ s: CGFloat) -> some View {
        Text(quote.text)
            .font(Serif.font(s, weight: .medium, italic: true))
            .foregroundStyle(Stone.parchment)
            .raised()
            .lineSpacing(s > 18 ? 2 : 1)
    }
}
