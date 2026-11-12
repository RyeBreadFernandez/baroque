import SwiftUI
import WidgetKit

// The Quote widget in rococo: one of the user's own photographs, repainted in the paintings' colours, with the line
// from the vault and who said it written over its darkened side, on a soft dark ground that follows the words. A short
// line is set large in script, a longer one in Didot italic. The widget wraps the line in its next-quote button
// (`tap`), so tapping the quote shows the next. The pictures: the river (small), the dead tree (medium), the sunset
// on the beach (large). The dead tree and the sunset show people, which otherwise go only on the Photograph widget;
// they were chosen for the Quote widget before that rule, and the user kept them (2026-11-11).

struct RococoQuoteView: View {
    var quote: Quote
    var size: BaroqueSize
    var date: Date
    var error: String?
    /// Wraps the quote (the widget passes its next-quote button; the app's preview leaves it as it is).
    var tap: (AnyView) -> AnyView = { $0 }

    var body: some View {
        RococoFrame(size: size) {
            let design = size.designSize
            let night = !SkyClock(now: date, weather: nil).isDay
            ZStack(alignment: .topLeading) {
                RococoPicture(name: picture, night: night)
                ground
                tap(AnyView(words(night: night)))
                    .frame(width: design.width, height: design.height, alignment: alignment)
            }
            .frame(width: design.width, height: design.height)
        }
    }

    private var script: Bool { RococoWords.fitsScript(quote.text) }

    private var picture: String {
        switch size {
        case .small: return "RococoSquare"
        case .medium: return "RococoWide"
        case .large: return "RococoTall"
        }
    }

    /// The side of the painting the words sit on: the right of the wide one, otherwise the foot.
    private var alignment: Alignment {
        size == .medium ? .topTrailing : .bottomLeading
    }

    private var ground: some View {
        // On tinted and clear home screens iOS would draw the shade in the words' own tint. RococoScrim leaves it out
        // there: it reads `rococoAccented` inside RococoFrame, which sets it from the rendering mode.
        RococoScrim {
            if size == .medium {
                LinearGradient(colors: [.clear, RococoInk.umber.opacity(min(0.92, 0.72 * RococoTheme.current.scrim))], startPoint: UnitPoint(x: 0.4, y: 0.5),
                               endPoint: .trailing)
            } else {
                LinearGradient(colors: [.clear, RococoInk.umber.opacity(min(0.92, (size == .small ? 0.7 : 0.62) * RococoTheme.current.scrim))],
                               startPoint: UnitPoint(x: 0.5, y: size == .small ? 0.3 : 0.4), endPoint: .bottom)
            }
        }
    }

    private func words(night: Bool) -> some View {
        let width: CGFloat = size == .small ? 136 : (size == .medium ? 142 : 300)
        // The height the words may take: the widget less their margins (the small one keeps 14 clear at the top, the
        // wide one 14 under its words, the large one 22 at the top). A long line gets what its author and any error
        // line leave, up to its own height, before they are cut.
        let room: CGFloat = size == .small ? 136 : (size == .medium ? 128 : 319)
        return RococoWordsStack(cap: size == .large ? 170 : (size == .medium ? 96 : 92), room: room) {
            if script {
                let parts = quote.text.replacingOccurrences(of: ".", with: "").split(separator: " ").map(String.init)
                let half = (parts.count + 1) / 2
                VStack(alignment: .leading, spacing: size == .large ? -12 : -8) {
                    Text(parts.prefix(half).joined(separator: " ").capitalized)
                    Text(parts.dropFirst(half).joined(separator: " ").capitalized)
                        .padding(.leading, size == .large ? 30 : 18)
                }
                .font(RococoType.script(size == .large ? 46 : (size == .medium ? 31 : 27)))
                .fixedSize()
            } else {
                Text(quote.text)
                    .font(RococoType.italic(size == .large ? 24 : (size == .medium ? 15 : 14)))
                    .lineSpacing(-1)
                    // A long line shrinks a little, then ends in an ellipsis rather than become too small to read.
                    .minimumScaleFactor(size == .large ? 0.6 : 0.75)
                    .lineLimit(size == .large ? 7 : 6)
            }
            Rectangle().frame(width: 14, height: 0.8).padding(.top, script ? 14 : 10)
            // Who said it, from the quote's own author line in the vault (never made up; none, no line).
            if let author = quote.author, !author.isEmpty {
                Text(author.uppercased())
                    .font(RococoType.sansMedium(size == .large ? 8 : 6.5))
                    .tracking(1.5)
                    .opacity(0.85)
                    .lineLimit(2)
                    .padding(.top, 6)
            }
            if let error {
                Text(error.uppercased())
                    .font(RococoType.sansMedium(6.5))
                    .tracking(1.2)
                    .opacity(0.85)
                    .lineLimit(2)
                    .padding(.top, 6)
            }
        }
        .foregroundStyle(RococoInk.cream)
        .shadow(color: RococoInk.shadow.opacity(0.55), radius: 2, x: 0, y: 1)
        // A long line on the small one climbs into the river's bright sky; the sunset and the dead tree need less.
        .modifier(RococoWordsGround(strength: size == .small ? 0.35 : (size == .medium ? 0.25 : 0.32), night: night))
        .frame(width: width, alignment: .leading)
        .padding(size == .medium ? EdgeInsets(top: 22, leading: 0, bottom: 0, trailing: 16)
                                 : EdgeInsets(top: 0, leading: size == .small ? 14 : 22, bottom: size == .small ? 14 : 24, trailing: 0))
    }
}

// MARK: - Words on a photograph

/// A soft umber ground behind words set on a photograph, sized to them, spread past them and blurred, so every line
/// reads at 4.5:1 or better against the paint behind it by day, when the photographs are bright and a long quote
/// climbs into the sky (2026-11-11). Used by the Quote widget and the large Day. Each place sets its own `strength`,
/// the least that keeps its lines at 5:1 on its brightest photograph with the longest quote (measured on MockLab
/// renders; times the theme's darkening behind words). By night the glaze already holds every line past 5:1, so there
/// is no ground and the night pictures stay as they were.
struct RococoWordsGround: ViewModifier {
    var strength: Double
    var night: Bool
    /// How far the ground runs past the words before it fades (over as far again).
    var spread: CGFloat = 20
    /// Set by RococoFrame: the words this grounds are drawn inside one.
    @Environment(\.rococoAccented) private var accented

    func body(content: Content) -> some View {
        content.background {
            // On tinted and clear home screens iOS would draw the ground in the words' own tint.
            if !night && !accented {
                RoundedRectangle(cornerRadius: spread, style: .continuous)
                    .fill(RococoInk.umber.opacity(min(0.9, strength * RococoTheme.current.scrim)))
                    .padding(-spread)
                    .blur(radius: spread / 2)
            }
        }
    }
}

/// Words stacked down a photograph, at their leading edge: the quote first, then the lines that go with it (its author,
/// the rule, the weather, an error). The quote gets the height the others leave inside `room`, up to `cap`, and
/// shrinks into it with its own minimumScaleFactor, so a long quote gives way before its author or the weather is cut.
struct RococoWordsStack: Layout {
    var cap: CGFloat
    var room: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = zip(subviews, proposals(width: proposal.width, subviews)).map { $0.sizeThatFits($1) }
        return CGSize(width: sizes.map(\.width).max() ?? 0, height: sizes.map(\.height).reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for (view, offer) in zip(subviews, proposals(width: proposal.width, subviews)) {
            view.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading, proposal: offer)
            y += view.sizeThatFits(offer).height
        }
    }

    /// The lines after the quote at their own height; the quote in what they leave.
    private func proposals(width: CGFloat?, _ subviews: Subviews) -> [ProposedViewSize] {
        guard !subviews.isEmpty else { return [] }
        let own = ProposedViewSize(width: width, height: nil)
        let others = subviews.dropFirst().map { $0.sizeThatFits(own).height }.reduce(0, +)
        let quote = ProposedViewSize(width: width, height: max(0, min(cap, room - others)))
        return [quote] + Array(repeating: own, count: subviews.count - 1)
    }
}
