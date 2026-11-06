import SwiftUI

// The Quote widget as a page from a storybook: an arched window plate with tonight's moon over the
// ridges, and the quote set on the board under (or beside) it with a gilt drop cap, the author in
// small caps and the next-quote arrow as a copper pebble on the board.

struct PLQuoteWidget: View {
    var quote: Quote
    var family: Family
    var error: String? = nil
    var date: Date = Mock.now

    var body: some View {
        Group {
            switch family {
            case .large: large
            case .medium: medium
            case .small: small
            }
        }
        .frame(width: Mock.size(family).width, height: Mock.size(family).height, alignment: .topLeading)
        .background(PLBoard())
    }

    // MARK: Large: window across the top, the page below.

    // Largest type and tallest window first; a long quote trades window height for type size before
    // it is ever shortened.
    private static let largeFits: [PLQuoteFit] = [
        .init(plate: 136, size: 26), .init(plate: 136, size: 24), .init(plate: 136, size: 22), .init(plate: 136, size: 20),
        .init(plate: 118, size: 19), .init(plate: 104, size: 18), .init(plate: 96, size: 17), .init(plate: 96, size: 15.5),
        .init(plate: 96, size: 14),
        .init(plate: 96, size: 14, keep: 0.8), .init(plate: 96, size: 14, keep: 0.6), .init(plate: 96, size: 14, keep: 0.4)
    ]

    private var large: some View {
        ViewThatFits(in: .vertical) {
            ForEach(Self.largeFits, id: \.self) { fit in
                largePage(fit)
            }
        }
    }

    private func largePage(_ fit: PLQuoteFit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PLPlate(shape: PLArch(rise: min(58, fit.plate * 0.43), corner: 6)) {
                PLQuoteScene(date: date, scene: .large)
            }
            .frame(height: fit.plate)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 0) {
                PLDropCapText(text: fit.text(quote.text), size: fit.size, capLines: 2)
                    .frame(maxHeight: .infinity, alignment: .leading)
                footer(authorSize: 13)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: Medium: the page on the left, a round-headed window on the right.

    private var medium: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PLQuoteText(text: quote.text, sizes: [19, 17.5, 16, 15, 14, 13, 12], capLines: 2)
                    .frame(maxHeight: .infinity, alignment: .leading)
                footer(authorSize: 12)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 16)

            PLPlate(shape: PLArch(rise: 50, corner: 6)) {
                PLQuoteScene(date: date, scene: .medium)
            }
            .frame(width: 100)
            .padding(.trailing, 19)
            .padding(.vertical, 19)
        }
    }

    // MARK: Small: a low arch on top, the quote beneath.

    private static let smallFits: [PLQuoteFit] = [
        .init(plate: 62, size: 16), .init(plate: 62, size: 15), .init(plate: 58, size: 14), .init(plate: 52, size: 13),
        .init(plate: 46, size: 12), .init(plate: 42, size: 11),
        .init(plate: 42, size: 11, keep: 0.75), .init(plate: 42, size: 11, keep: 0.5), .init(plate: 42, size: 11, keep: 0.3)
    ]

    private var small: some View {
        ViewThatFits(in: .vertical) {
            ForEach(Self.smallFits, id: \.self) { fit in
                smallPage(fit)
            }
        }
    }

    private func smallPage(_ fit: PLQuoteFit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PLPlate(shape: PLArch(rise: min(26, fit.plate * 0.45), corner: 5), ruleGap: nil) {
                PLQuoteScene(date: date, scene: .small)
            }
            .frame(height: fit.plate)
            .padding(.horizontal, 17)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 4) {
                PLDropCapText(text: fit.text(quote.text), size: fit.size, capLines: 2)
                    .frame(maxHeight: .infinity, alignment: .leading)
                if let a = quote.author, !a.isEmpty {
                    PLAuthorLine(author: a, size: 10.5, rule: 10)
                }
                if let error {
                    ErrorLine(message: error, color: Stone.copperInk, fontSize: 9.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 11)
            .padding(.bottom, 16)
        }
    }

    // Author (and any fetch error) beside the arrow pebble, in a band the arrow's height.
    private func footer(authorSize: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if let a = quote.author, !a.isEmpty {
                    PLAuthorLine(author: a, size: authorSize, rule: 16)
                }
                if let error {
                    ErrorLine(message: error, color: Stone.copperInk, fontSize: 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            NextQuoteArrow()
        }
        .frame(minHeight: 30)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 6)
    }
}

/// One way to set a quote: the window's height, the type size, and how much of the text to keep.
struct PLQuoteFit: Hashable {
    var plate: CGFloat
    var size: CGFloat
    var keep: Double = 1

    func text(_ full: String) -> String { keep < 1 ? PLQuoteText.shortened(full, keeping: keep) : full }
}

// MARK: - The window's painting

struct PLQuoteScene: View {
    enum Scene { case large, medium, small }

    var date: Date
    var scene: Scene

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let u = min(1, max(0.62, w / 300))
            let horizon = layers(width: w).first.map { $0.profile.keys.map(\.y).min() ?? 0.6 } ?? 0.6
            PaintedSky(palette: .evening, horizon: horizon + 0.08)
                .overlay(RadialGradient(colors: [Color(hex: 0xB0703F).opacity(0.42), .clear],
                                        center: UnitPoint(x: glowX, y: horizon + 0.1), startRadius: 0, endRadius: w * 0.55))
                .overlay(PLStars(region: starRegion, count: starCount, sparkles: scene == .small ? 1 : 2, seed: 7, u: u))
                .overlay {
                    MoonDisc(radius: moonRadius, phase: MoonPhase(date: date))
                        .position(x: geo.size.width * moon.x, y: geo.size.height * moon.y)
                }
                .overlay(MountainRange(layers: layers(width: w), night: true))
                .overlay(LinearGradient(stops: [
                    .init(color: Color(hex: 0x6F8380).opacity(0), location: horizon + 0.02),
                    .init(color: Color(hex: 0x6F8380).opacity(0.16), location: horizon + 0.12),
                    .init(color: Color(hex: 0x6F8380).opacity(0), location: horizon + 0.22)
                ], startPoint: .top, endPoint: .bottom))
                .overlay(LinearGradient(stops: [.init(color: .clear, location: 0.72),
                                                .init(color: Stone.shadow.opacity(0.5), location: 1)],
                                        startPoint: .top, endPoint: .bottom))
        }
    }

    private var moon: CGPoint {
        switch scene {
        case .large: return CGPoint(x: 0.66, y: 0.36)
        case .medium: return CGPoint(x: 0.5, y: 0.28)
        case .small: return CGPoint(x: 0.66, y: 0.44)
        }
    }

    private var moonRadius: CGFloat {
        switch scene {
        case .large: return 15
        case .medium: return 13
        case .small: return 8.5
        }
    }

    private var glowX: CGFloat { scene == .medium ? 0.5 : 0.3 }

    private var starRegion: CGRect {
        switch scene {
        case .large: return CGRect(x: 0.12, y: 0.12, width: 0.42, height: 0.32)
        case .medium: return CGRect(x: 0.14, y: 0.36, width: 0.72, height: 0.14)
        case .small: return CGRect(x: 0.18, y: 0.2, width: 0.32, height: 0.3)
        }
    }

    private var starCount: Int {
        switch scene {
        case .large: return 12
        case .medium: return 6
        case .small: return 5
        }
    }

    private func layers(width w: CGFloat) -> [MountainLayer] {
        let p = PLScenery.p
        let (a, b, c): (CGFloat, CGFloat, CGFloat)
        switch scene {
        case .large: (a, b, c) = (0.60, 0.72, 0.84)
        case .medium: (a, b, c) = (0.60, 0.72, 0.84)
        case .small: (a, b, c) = (0.62, 0.76, 0.88)
        }
        return [
            MountainLayer(profile: RidgeProfile(keys: [
                p(0, a + 0.06), p(0.1, a + 0.01), p(0.2, a + 0.04), p(0.3, a - 0.05), p(0.38, a - 0.12), p(0.46, a - 0.05),
                p(0.56, a - 0.02), p(0.66, a - 0.08), p(0.76, a - 0.01), p(0.88, a + 0.03), p(1, a + 0.0)], seed: 61),
                          top: Color(hex: 0x3D4D48), bottom: Color(hex: 0x2A3733), rim: 0.45, snowline: a - 0.06),
            MountainLayer(profile: RidgeProfile(keys: [
                p(0, b + 0.02), p(0.15, b - 0.03), p(0.3, b + 0.02), p(0.45, b - 0.04), p(0.6, b + 0.01), p(0.75, b - 0.05),
                p(0.9, b), p(1, b - 0.03)], seed: 67),
                          top: Color(hex: 0x1F2B27), bottom: Color(hex: 0x18221E), rim: 0.25,
                          trees: PLScenery.trees(4...7, spacing: 4.5, coverage: 0.6, width: w)),
            MountainLayer(profile: RidgeProfile(keys: [
                p(0, c + 0.02), p(0.2, c - 0.02), p(0.4, c + 0.01), p(0.55, c - 0.03), p(0.7, c), p(0.85, c - 0.04),
                p(1, c - 0.01)], seed: 71),
                          top: Color(hex: 0x131B17), bottom: Color(hex: 0x0D1310), rim: 0.18,
                          trees: PLScenery.trees(5...9, spacing: 5, coverage: 0.8, width: w))
        ]
    }
}

// MARK: - Quote text with a gilt drop cap

/// The quote in italic serif, its first letter dropped two lines deep in gilt. Tries each size in turn
/// (largest first) and keeps the first that fits, like the shipped QuoteView; a quote too long for every
/// size is shortened at a word with an ellipsis.
struct PLQuoteText: View {
    var text: String
    var sizes: [CGFloat]
    var capLines: Int = 2

    var body: some View {
        let smallest = sizes.last ?? 12
        ViewThatFits(in: .vertical) {
            ForEach(sizes, id: \.self) { s in
                PLDropCapText(text: text, size: s, capLines: capLines)
            }
            ForEach([0.8, 0.65, 0.5, 0.35], id: \.self) { f in
                PLDropCapText(text: Self.shortened(text, keeping: f), size: smallest, capLines: capLines)
            }
        }
    }

    static func shortened(_ text: String, keeping fraction: Double) -> String {
        let words = text.split(separator: " ")
        let keep = max(1, Int(Double(words.count) * fraction))
        var s = words.prefix(keep).joined(separator: " ")
        while let last = s.last, ",;:.—-".contains(last) { s.removeLast() }
        return s + "…"
    }
}

struct PLDropCapText: View {
    var text: String
    var size: CGFloat
    var capLines: Int

    private var lineSpacing: CGFloat { size > 18 ? 2 : 1 }

    // The initial's cap height spans from the first line's cap height down to the last dropped line's
    // baseline. Serif metrics: line box ~1.19 em, cap height ~0.70 em.
    private var capSize: CGFloat {
        let line = size * 1.19 + lineSpacing
        return (CGFloat(capLines - 1) * line + size * 0.70) / 0.70
    }

    var body: some View {
        let parts = Self.split(text)
        // A word's own initial ("G|ot") sits close; a one-letter first word ("A| quick") keeps a word space.
        PLDropCapLayout(capLines: capLines, gap: size * (parts.joined ? 0.14 : 0.42), lineSpacing: lineSpacing,
                        wordSpacing: size * 0.25, capInk: capSize * 0.70) {
            Text(parts.initial)
                .font(Serif.font(capSize, weight: .medium))
                .foregroundStyle(Gilt.style)
            ForEach(Array(parts.words.enumerated()), id: \.offset) { _, word in
                Text(word)
            }
        }
        .font(Serif.font(size, weight: .medium, italic: true))
        .foregroundStyle(Stone.parchment)
        .compositingGroup()
        .raised(1.1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    /// The initial (with any opening quotation mark), the remaining words, and whether the first of
    /// them continues the initial's word.
    static func split(_ text: String) -> (initial: String, words: [String], joined: Bool) {
        var rest = Substring(text.trimmingCharacters(in: .whitespacesAndNewlines))
        var initial = ""
        while let c = rest.first, "“\"‘'([«".contains(c) {
            initial.append(c)
            rest = rest.dropFirst()
        }
        if let c = rest.first {
            initial.append(c)
            rest = rest.dropFirst()
        }
        let joined = rest.first.map { !$0.isWhitespace } ?? false
        let words = rest.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
        return (initial, words, joined)
    }
}

/// Words set in lines around a drop cap: subview 0 is the initial, the rest are the words in order.
/// The first `capLines` lines are indented by the initial's width; the initial's baseline sits on the
/// last of them. A quote shorter than that (one line) gets a raised initial instead, standing on the
/// first baseline, with the line moved down to make room. Ragged right, like a storybook's narrow page.
struct PLDropCapLayout: Layout {
    var capLines: Int
    var gap: CGFloat
    var lineSpacing: CGFloat
    var wordSpacing: CGFloat
    var capInk: CGFloat // the initial's cap height in points

    private struct Metrics {
        var capSize: CGSize
        var capBaseline: CGFloat
        var wordSizes: [CGSize]
        var lineHeight: CGFloat
        var wordBaseline: CGFloat
    }

    private func metrics(_ subviews: Subviews) -> Metrics {
        let cap = subviews.first
        let capSize = cap?.sizeThatFits(.unspecified) ?? .zero
        let capBaseline = cap?.dimensions(in: .unspecified)[VerticalAlignment.firstTextBaseline] ?? capSize.height
        let words = subviews.dropFirst()
        let sizes = words.map { $0.sizeThatFits(.unspecified) }
        let lineHeight = sizes.map(\.height).max() ?? 0
        let wordBaseline = words.first?.dimensions(in: .unspecified)[VerticalAlignment.firstTextBaseline] ?? lineHeight * 0.8
        return Metrics(capSize: capSize, capBaseline: capBaseline, wordSizes: sizes, lineHeight: lineHeight, wordBaseline: wordBaseline)
    }

    /// Word index ranges per line.
    private func lines(width: CGFloat, m: Metrics) -> [Range<Int>] {
        var lines: [Range<Int>] = []
        var start = 0, i = 0
        var x: CGFloat = 0
        while i < m.wordSizes.count {
            let indent = lines.count < capLines ? m.capSize.width + gap : 0
            let w = m.wordSizes[i].width
            let needed = i == start ? w : x + wordSpacing + w
            if i > start && needed > width - indent + 0.5 {
                lines.append(start..<i)
                start = i
                x = 0
                continue
            }
            x = needed
            i += 1
        }
        if start < m.wordSizes.count { lines.append(start..<m.wordSizes.count) }
        return lines
    }

    /// Where the initial's baseline falls (on the last dropped line), and how far everything moves down
    /// so a raised initial stays inside the view.
    private func capPlacement(lineCount: Int, m: Metrics) -> (baseline: CGFloat, shift: CGFloat) {
        let dropped = min(capLines, max(1, lineCount))
        let baseline = CGFloat(dropped - 1) * (m.lineHeight + lineSpacing) + m.wordBaseline
        return (baseline, max(0, capInk + 1 - baseline))
    }

    private func height(lineCount: Int, m: Metrics) -> CGFloat {
        let cap = capPlacement(lineCount: lineCount, m: m)
        let text = CGFloat(lineCount) * m.lineHeight + CGFloat(max(0, lineCount - 1)) * lineSpacing
        // The initial ends at its baseline.
        return cap.shift + max(text, cap.baseline + 2)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let m = metrics(subviews)
        let width = proposal.width ?? .infinity
        let ls = lines(width: width, m: m)
        let natural = ls.enumerated().map { li, r -> CGFloat in
            let indent = li < capLines ? m.capSize.width + gap : 0
            let words = r.map { m.wordSizes[$0].width }.reduce(0, +)
            return indent + words + CGFloat(max(0, r.count - 1)) * wordSpacing
        }.max() ?? m.capSize.width
        return CGSize(width: proposal.width ?? natural, height: height(lineCount: ls.count, m: m))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let capView = subviews.first else { return }
        let m = metrics(subviews)
        let ls = lines(width: bounds.width, m: m)
        let cap = capPlacement(lineCount: ls.count, m: m)
        let top = bounds.minY + cap.shift
        capView.place(at: CGPoint(x: bounds.minX, y: top + cap.baseline - m.capBaseline), proposal: .unspecified)
        let words = Array(subviews.dropFirst())
        for (li, r) in ls.enumerated() {
            var x = bounds.minX + (li < capLines ? m.capSize.width + gap : 0)
            let y = top + CGFloat(li) * (m.lineHeight + lineSpacing)
            for i in r {
                words[i].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += m.wordSizes[i].width + wordSpacing
            }
        }
    }
}

// MARK: - Author

/// "— Henry David Thoreau, Walden" in gold small caps after a short copper rule.
struct PLAuthorLine: View {
    var author: String
    var size: CGFloat
    var rule: CGFloat

    var body: some View {
        HStack(spacing: 7) {
            Rectangle()
                .fill(Stone.copperLight)
                .frame(width: rule, height: 1.3)
                .raised()
            Text(author)
                .font(Serif.font(size, weight: .semibold).smallCaps())
                .tracking(0.9)
                .foregroundStyle(Stone.gold)
                .raised()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
