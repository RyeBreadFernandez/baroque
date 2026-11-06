import SwiftUI

// The Quote widget as a margin note: a gold thread down the left margin, a copper pebble at its head for the
// source (like the header of a journal entry), the quote written beside it, low ridges behind.

struct TRQuoteWidget: View {
    var quote: Quote
    var family: Family
    var date: Date
    var error: String? = nil

    var body: some View {
        let size = Mock.size(family)
        ZStack(alignment: .topLeading) {
            TRQuoteScene(family: family, date: date)
            TRMarginNote(quote: quote, family: family, date: date, error: error)
            if family != .small {
                NextQuoteArrow()
                    .position(x: size.width - Mock.margin - 15, y: size.height - Mock.margin - 15)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

struct TRMarginNote: View {
    var quote: Quote
    var family: Family
    var date: Date
    var error: String?

    private var size: CGSize { Mock.size(family) }
    private var threadX: CGFloat { family == .small ? 23 : 25 }
    private var textX: CGFloat { family == .small ? 37 : 42 }
    private var nodeY: CGFloat { family == .small ? 23 : 25 }

    /// The thread runs down the margin and comes to rest on the far ridge.
    private var threadEnd: CGFloat {
        switch family {
        case .large: return size.height * 0.80
        case .medium: return size.height * 0.72
        case .small: return size.height * 0.77
        }
    }

    /// The writing stops where the ridges begin on large, above the next-quote arrow on medium, and at the
    /// margin on small (where every line counts and the halo keeps it legible over the ridges).
    private var textBottom: CGFloat {
        switch family {
        case .large: return size.height * 0.79
        case .medium: return size.height - Mock.margin - 30 - 6
        case .small: return size.height - Mock.margin
        }
    }

    // Largest first; the first size that shows the whole quote wins.
    private var textSizes: [CGFloat] {
        switch family {
        case .small: return [19, 17, 15.5, 14, 13, 12, 11]
        case .medium: return [22, 20, 18.5, 17, 15.5, 14, 13, 12]
        case .large: return [38, 34, 30, 27, 24, 22, 20, 18, 16, 14.5]
        }
    }

    /// The author, or the day's date when the quote has none, as the entry's heading.
    private var source: String {
        if let a = quote.author, !a.isEmpty { return a }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TRThread(x: threadX, top: nodeY, bottom: threadEnd, walked: threadEnd, channel: 5)
            ZStack {
                Circle().fill(Stone.night).frame(width: 12, height: 12).blur(radius: 2)
                Sparkle().fill(Stone.gold).frame(width: 8, height: 10)
                    .shadow(color: Stone.goldBright.opacity(0.6), radius: 2)
            }
            .position(x: threadX, y: threadEnd + 4)
            TRNode(size: family == .small ? 12 : 14)
                .position(x: threadX, y: nodeY)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: family == .small ? 4 : 5) {
                    TRCaps(text: source, color: Stone.gold, size: family == .small ? 9 : 10,
                           tracking: family == .small ? 0.8 : 1.5)
                        .minimumScaleFactor(0.8)
                        .legible()
                        .frame(height: 14)
                    EngravedRule()
                }
                .padding(.trailing, family == .small ? 0 : 4)

                ViewThatFits(in: .vertical) {
                    ForEach(textSizes, id: \.self) { s in
                        quoteText(s)
                    }
                    // Too long for every size: fill the space and truncate the tail.
                    quoteText(textSizes.last ?? 12)
                }
                .padding(.top, family == .small ? 6 : (family == .large ? 12 : 7))
                .frame(maxHeight: .infinity, alignment: .topLeading)

                if let error {
                    ErrorLine(message: error, color: Stone.parchment.opacity(0.9), fontSize: family == .small ? 9.5 : 10)
                        .legible()
                        .padding(.top, 4)
                }
            }
            .padding(.leading, textX)
            .padding(.trailing, Mock.margin)
            .padding(.top, nodeY - 7)
            .frame(width: size.width, height: textBottom, alignment: .topLeading)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func quoteText(_ pointSize: CGFloat) -> some View {
        Text(quote.text)
            .font(Serif.font(pointSize, weight: .medium, italic: true))
            .foregroundStyle(Stone.parchment)
            .legible()
            .lineSpacing(pointSize > 18 ? 2 : 1)
    }
}
