import SwiftUI

// The Quote widget in rococo: one of the user's own photographs, repainted in the paintings' colours, with the line
// from the vault written over its darkened side. A short line is set large in script, a longer one in Didot italic.
// The widget wraps the line in its next-quote button (`tap`), so tapping the quote shows the next. The pictures:
// the river (small), the dead tree (medium), the sunset on the beach (large).

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
                tap(AnyView(words))
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
        Group {
            if size == .medium {
                LinearGradient(colors: [.clear, RococoInk.umber.opacity(0.72)], startPoint: UnitPoint(x: 0.4, y: 0.5),
                               endPoint: .trailing)
            } else {
                LinearGradient(colors: [.clear, RococoInk.umber.opacity(size == .small ? 0.7 : 0.62)],
                               startPoint: UnitPoint(x: 0.5, y: size == .small ? 0.3 : 0.4), endPoint: .bottom)
            }
        }
    }

    private var words: some View {
        let width: CGFloat = size == .small ? 136 : (size == .medium ? 142 : 300)
        return VStack(alignment: .leading, spacing: 0) {
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
                    .frame(width: width, alignment: .leading)
                    .frame(maxHeight: size == .large ? 170 : (size == .medium ? 96 : 92), alignment: .bottomLeading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().frame(width: 14, height: 0.8).padding(.top, script ? 14 : 10)
            if let author = quote.author, !author.isEmpty, size != .small || !script {
                Text(author.uppercased())
                    .font(RococoType.sansMedium(size == .large ? 8 : 6.5))
                    .tracking(1.5)
                    .opacity(0.8)
                    .lineLimit(1)
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
        .frame(width: width, alignment: .leading)
        .padding(size == .medium ? EdgeInsets(top: 22, leading: 0, bottom: 0, trailing: 16)
                                 : EdgeInsets(top: 0, leading: size == .small ? 14 : 22, bottom: size == .small ? 14 : 24, trailing: 0))
    }
}
