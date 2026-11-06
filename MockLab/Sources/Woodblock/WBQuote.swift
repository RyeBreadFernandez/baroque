import SwiftUI

// The quote widgets: a dusk print with a low moon, the quote inscribed on the pale sky like a poem on a surimono,
// signed with the author's name and a small seal; a round vermilion seal is the "next quote" button.

struct Signature: View {
    var author: String
    var size: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("— \(author)")
                .font(WB.hoeflerItalic(size))
                .foregroundStyle(WB.sumiSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Hanko(text: "言", font: WB.minchoBold(size * 0.72), size: size * 1.2, seed: 13, tilt: 2)
        }
    }
}

struct QuoteBlock: View {
    var quote: Quote
    var sizes: [CGFloat]
    var authorSize: CGFloat

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes, id: \.self) { s in block(s) }
        }
    }

    func block(_ s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: s * 0.42) {
            Text(quote.text)
                .font(WB.hoefler(s))
                .lineSpacing(s * 0.1)
                .foregroundStyle(WB.sumi)
                .fixedSize(horizontal: false, vertical: true)
            if let a = quote.author, !a.isEmpty {
                Signature(author: a, size: authorSize)
            }
        }
    }
}

struct QuoteLarge: View {
    var q: Quote
    var body: some View {
        ZStack(alignment: .topLeading) {
            PrintScene(spec: WBScenes.quoteLarge)
            QuoteBlock(quote: q, sizes: [28, 27, 26, 25, 24, 22, 20, 18, 16, 15, 14], authorSize: 13.5)
                .frame(width: 316, height: 172, alignment: .topLeading)
                .offset(x: 16, y: 38)
            NextSeal().offset(x: 302, y: 319)
            PrintFrame()
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }
}

struct QuoteMedium: View {
    var q: Quote
    var body: some View {
        ZStack(alignment: .topLeading) {
            PrintScene(spec: WBScenes.quoteMedium)
            QuoteBlock(quote: q, sizes: [22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12], authorSize: 12)
                .frame(width: 316, height: 76, alignment: .topLeading)
                .offset(x: 16, y: 22)
            NextSeal().offset(x: 302, y: 118)
            PrintFrame()
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }
}

struct QuoteSmall: View {
    var q: Quote
    var body: some View {
        ZStack(alignment: .topLeading) {
            PrintScene(spec: WBScenes.quoteSmall)
            QuoteBlock(quote: q, sizes: [22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12], authorSize: 11)
                .frame(width: 132, height: 84, alignment: .topLeading)
                .offset(x: 16, y: 22)
            PrintFrame()
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }
}
