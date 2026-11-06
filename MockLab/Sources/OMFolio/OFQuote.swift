import SwiftUI

// The Quote widget as a commonplace book (the book a reader copies passages into). Large: a spread, the
// frontispiece plate facing the page, the quote set as the page's text with a dropped initial in rubric, its first
// words in small capitals, justified, and the author beneath in small capitals; the page's lower corner is turned
// up, and turning it brings the next quote. Medium and small: one page, the plate as a headpiece over the text.
// No weather here: the plates and the light in the room follow the clock alone.

struct OFQuote: View {
    var quote: Quote
    var family: Family
    var now: Date = Mock.now

    var body: some View {
        switch family {
        case .large: OFQuoteLarge(quote: quote, now: now)
        case .medium: OFQuoteMedium(quote: quote, now: now)
        case .small: OFQuoteSmall(quote: quote, now: now)
        }
    }
}

struct OFQuoteScene {
    var now: Date
    var clock: SkyClock { SkyClock(now: now, weather: nil) }
    var room: OFRoomLight { OFRoomLight(clock: clock, condition: .clear) }

    func painting(_ plate: OFPlate) -> OFPainting {
        OFPainting(plate: plate, clock: clock, condition: .clear, phase: MoonPhase(date: now))
    }
}

/// The quote as a paragraph: the first letter dropped in rubric, the rest of the first words in small capitals,
/// then the text. The largest of `sizes` whose lines fit wins; the last size ends in an ellipsis if it must.
struct OFQuoteBlock: View {
    var quote: Quote
    var sizes: [CGFloat]
    var initialLines: Int
    var maxLines: Int             // at the last size, with an author line
    var maxLinesAlone: Int        // at the last size, when there is no author
    var author: CGFloat
    var authorLines: Int = 1
    var authorTrailing: CGFloat = 0
    var spacing: CGFloat = 8

    private var hasAuthor: Bool { quote.author?.isEmpty == false }

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes.dropLast(), id: \.self) { s in entry(s, maxLines: .max) }
            entry(sizes.last ?? 13, maxLines: hasAuthor ? maxLines : maxLinesAlone)
        }
    }

    private func entry(_ size: CGFloat, maxLines: Int) -> some View {
        VStack(alignment: .trailing, spacing: spacing) {
            OFQuoteText(text: quote.text, size: size, initialLines: initialLines, maxLines: maxLines)
            if let a = quote.author, !a.isEmpty {
                OFType.smallCaps("— " + a, size: author)
                    .tracking(0.9)
                    .foregroundStyle(OFInk.inkSoft)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(authorLines)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, authorTrailing)
            }
        }
    }
}

struct OFQuoteText: View {
    var text: String
    var size: CGFloat
    var initialLines: Int
    var maxLines: Int

    var body: some View {
        let parts = Self.split(text)
        let lineHeight = (size * 1.36).rounded()
        // The initial's capitals reach from the first line's cap height to the last dropped line's baseline.
        let capHeight = CGFloat(initialLines - 1) * lineHeight + size * 0.68
        var runs: [OFRun] = []
        if !parts.lead.isEmpty {
            runs.append(OFRun(text: parts.lead.lowercased(), font: OFType.serif(size), color: OFInk.ink, tracking: 0.8,
                              smallCaps: size + 1))
        }
        runs.append(OFRun(text: parts.rest, font: OFType.serif(size), color: OFInk.ink))
        return OFParagraph(initial: OFRun(text: parts.initial, font: OFType.serif(capHeight / 0.68), color: OFInk.initial),
                           runs: runs, lineHeight: lineHeight, space: size * 0.27, initialLines: initialLines,
                           initialGap: size * 0.3, maxLines: maxLines, justify: true)
    }

    /// "Begin at once to live." -> ("B", "egin at", "once to live."): the initial, the lead-in
    /// (the rest of the first word and the next one, set in small capitals) and the text.
    static func split(_ text: String) -> (initial: String, lead: String, rest: String) {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let f = body.first, "\"'“‘«".contains(f) { body.removeFirst() }
        guard let first = body.first else { return ("", "", "") }
        let after = String(body.dropFirst())
        var words = after.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var lead: [String] = []
        if after.first != " ", !words.isEmpty { lead.append(words.removeFirst()) }
        if !words.isEmpty, lead.joined().count < 6 { lead.append(words.removeFirst()) }
        return (String(first), lead.joined(separator: " "), words.joined(separator: " "))
    }
}

// MARK: - Large

struct OFQuoteLarge: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let scene = OFQuoteScene(now: now)
        OFBook(binding: .spreadLarge, light: scene.room) {
            OFPlateFrame { scene.painting(.quoteLarge) }
                .ofAt(22, 22, 138, 280)
            VStack(spacing: 2.5) {
                Text.ofCaps("Frontispiece", 10, OFInk.inkFaint, tracking: 1.8)
                Text(OFWords.hour(scene.clock, now: now) + ".")
                    .font(OFType.italic(12))
                    .foregroundStyle(OFInk.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .ofAt(16, 312, 150, 34, alignment: .top)
            Text.ofCaps("Commonplace Book", 10.5, OFInk.inkFaint, tracking: 2.2)
                .lineLimit(1)
                .ofAt(186, 16, 146, 12, alignment: .center)
            OFQuoteBlock(quote: quote, sizes: [23, 21.5, 20, 19, 18, 17, 16, 15, 14], initialLines: 2,
                         maxLines: 11, maxLinesAlone: 13, author: 11.5, authorLines: 2, spacing: 14)
                .ofAt(190, 40, 142, 268, alignment: .center)
            OFTurnedCorner(leg: 28)
                .ofAt(340 - 28, 357.4 - 28, 28, 28)
        }
    }
}

// MARK: - Medium

struct OFQuoteMedium: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let scene = OFQuoteScene(now: now)
        OFBook(binding: .pageMedium, light: scene.room) {
            OFPlateFrame(mark: 3.5) { scene.painting(.quoteMedium) }
                .ofAt(22, 16, 304, 48)
            OFQuoteBlock(quote: quote, sizes: [19, 18, 17, 16, 15, 14, 13], initialLines: 2, maxLines: 3,
                         maxLinesAlone: 4, author: 10, authorTrailing: 24, spacing: 5)
                .ofAt(22, 72, 302, 77, alignment: .center)
            OFTurnedCorner(leg: 24)
                .ofAt(340 - 24, 156.4 - 24, 24, 24)
        }
    }
}

// MARK: - Small

struct OFQuoteSmall: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let scene = OFQuoteScene(now: now)
        OFBook(binding: .pageSmall, light: scene.room) {
            OFPlateFrame(mark: 3.5) { scene.painting(.quoteSmall) }
                .ofAt(22, 17, 122, 54)
            OFQuoteBlock(quote: quote, sizes: [15, 14, 13, 12, 11.5], initialLines: 2, maxLines: 3, maxLinesAlone: 4,
                         author: 9, spacing: 4)
                .ofAt(20, 80, 128, 68, alignment: .center)
        }
    }
}
