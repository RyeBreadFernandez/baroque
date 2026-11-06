import SwiftUI

// MARK: - Quote widget

/// The shipped quote turned over: the picture on top (a tall range under tonight's moon), the quote written
/// beneath it on the valley floor like the caption under a storybook plate, the author under the quote and the
/// next-quote arrow in the bottom-right corner.
struct PNQuote: View {
    var quote: Quote
    var family: Family
    var date: Date
    var error: String? = nil

    var body: some View {
        let s = Mock.size(family)
        let plan = PNPlan.quote(family)
        let groundY = (plan.ground * s.height).rounded()
        ZStack(alignment: .topLeading) {
            PNCaption(quote: quote, family: family, error: error)
                .frame(width: s.width - 32, height: s.height - 16 - groundY, alignment: .topLeading)
                .offset(x: 16, y: groundY)
            if family != .small {
                NextQuoteArrow()
                    .position(x: s.width - 16 - 15, y: s.height - 16 - 15)
            }
        }
        .frame(width: s.width, height: s.height, alignment: .topLeading)
        .background(PNQuoteGround(family: family, date: date))
    }
}

/// The caption: the quote in italic parchment, shrinking to fit, then the author after a copper dash.
/// Medium and large keep a 40 pt column clear on the right for the arrow.
struct PNCaption: View {
    var quote: Quote
    var family: Family
    var error: String?

    private var textSizes: [CGFloat] {
        switch family {
        case .small: return [16.5, 16, 15, 14, 13, 12, 11]
        case .medium: return [17, 16, 15, 14, 13, 12, 11]
        case .large: return [24, 22.5, 21, 19.5, 18, 17, 16, 15, 14, 13]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .small ? 3 : 5) {
            ViewThatFits(in: .vertical) {
                ForEach(textSizes, id: \.self) { s in quoteText(s) }
                // Too long for every size: fill the space and truncate the tail.
                quoteText(textSizes.last ?? 11)
            }
            .layoutPriority(1)
            VStack(alignment: .leading, spacing: 3) {
                if let a = quote.author, !a.isEmpty {
                    HStack(spacing: 7) {
                        Rectangle()
                            .fill(Stone.copperLight)
                            .frame(width: family == .small ? 12 : 18, height: 1.5)
                            .raised()
                        Text(a)
                            .font(.system(size: family == .small ? 9 : 10, weight: .semibold))
                            .tracking(family == .small ? 0.8 : 1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Stone.gold)
                            .legible()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if let error {
                    ErrorLine(message: error, color: Stone.parchment.opacity(0.9), fontSize: family == .small ? 9.5 : 10)
                        .legible()
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.trailing, family == .small ? 0 : 40)
        .padding(.top, family == .large ? 4 : 1)
    }

    private func quoteText(_ pointSize: CGFloat) -> some View {
        Text(quote.text)
            .font(Serif.font(pointSize, weight: .medium, italic: true))
            .foregroundStyle(Stone.parchment)
            .lineSpacing(pointSize > 17 ? 2 : 0.5)
            .legible()
    }
}
