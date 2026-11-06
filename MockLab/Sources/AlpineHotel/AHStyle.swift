import SwiftUI

/// Alpine Hotel palette and type: confectionery pastels (pink, lilac, powder blue, cream, mint) with raspberry and
/// burgundy accents and gold leaf. Text on pastel is always burgundy, plum or espresso.
enum AH {
    // Sky and air
    static let skyTop = Color(hex: 0x79A9D4)
    static let skyMid = Color(hex: 0xA9CAE8)
    static let haze = Color(hex: 0xF6DEDD)
    // Painted ranges
    static let farLit = Color(hex: 0xD6CCEA)
    static let farShade = Color(hex: 0xB3A8D8)
    static let peakLit = Color(hex: 0xF2BDCC)
    static let peakShade = Color(hex: 0xA68BC4)
    static let snow = Color(hex: 0xFFFAF5)
    static let snowShade = Color(hex: 0xC9CBEC)
    // Hills, pines, rock
    static let mint = Color(hex: 0xB2DEC9)
    static let mintDeep = Color(hex: 0x7FC0A6)
    static let pine = Color(hex: 0x2D6961)
    static let pineLit = Color(hex: 0x4E9485)
    static let pineDark = Color(hex: 0x1E4846)
    static let rock = Color(hex: 0xEFC6AE)
    static let rockShade = Color(hex: 0xBE90A8)
    // Hotel
    static let pink = Color(hex: 0xF3A1B8)
    static let pinkLight = Color(hex: 0xFAC4D2)
    static let pinkDeep = Color(hex: 0xDB829D)
    static let raspberry = Color(hex: 0xB3375E)
    static let raspberryDeep = Color(hex: 0x841C40)
    static let cream = Color(hex: 0xFFF6E8)
    static let glass = Color(hex: 0x5A3255)
    // Ink
    static let burgundy = Color(hex: 0x6A1733)
    static let plum = Color(hex: 0x45203E)
    static let espresso = Color(hex: 0x3A2421)
    static let inkSoft = Color(hex: 0x74496A)
    // Gold leaf and brass
    static let gold = Color(hex: 0xC99D46)
    static let goldLight = Color(hex: 0xF5E0A0)
    static let goldDeep = Color(hex: 0x87621F)
    // Card stocks and lacquers
    static let card = Color(hex: 0xFCF3E4)
    static let lilac = Color(hex: 0xDED2F0)
    static let mintCard = Color(hex: 0xC5E7D6)
    static let butter = Color(hex: 0xF9E8B2)
    static let powder = Color(hex: 0xC3DBF0)
    static let blush = Color(hex: 0xF8D2DB)
    static let wall = Color(hex: 0xF2B9C8)
    static let wallDeep = Color(hex: 0xD98BA3)

    // Type. PostScript names that ship on iOS 17 and macOS. Fixed sizes: widgets ignore Dynamic Type.
    static func futura(_ s: CGFloat) -> Font { .custom("Futura-Bold", fixedSize: s) }
    static func futuraMed(_ s: CGFloat) -> Font { .custom("Futura-Medium", fixedSize: s) }
    static func futuraItalic(_ s: CGFloat) -> Font { .custom("Futura-MediumItalic", fixedSize: s) }
    static func futuraCond(_ s: CGFloat) -> Font { .custom("Futura-CondensedExtraBold", fixedSize: s) }
    static func futuraCondMed(_ s: CGFloat) -> Font { .custom("Futura-CondensedMedium", fixedSize: s) }
    /// The one flourish per widget: either the script or the engraved Didot.
    static func snell(_ s: CGFloat) -> Font { .custom("SnellRoundhand-Bold", fixedSize: s) }
    static func didot(_ s: CGFloat) -> Font { .custom("Didot-Bold", fixedSize: s) }
    static func didotItalic(_ s: CGFloat) -> Font { .custom("Didot-Italic", fixedSize: s) }
}

enum AHTex {
    static var gouache: Image { Mock.texture("alpine-hotel/gouache") }
    static var paper: Image { Mock.texture("alpine-hotel/paper") }
    static var grain: Image { Mock.texture("alpine-hotel/grain") }

    /// Lays a grey-centred texture over what the context has drawn inside `rect`.
    static func lay(_ ctx: GraphicsContext, _ image: Image, in rect: CGRect, mode: GraphicsContext.BlendMode = .softLight, opacity: Double) {
        var c = ctx
        c.blendMode = mode
        c.opacity = opacity
        c.draw(c.resolve(image), in: rect)
    }
}

enum AHDates {
    static func string(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = format
        return f.string(from: date)
    }

    /// Monday-first week containing `date`.
    static func week(of date: Date) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    /// "THREE", "TWENTY-THREE": the day of the month as a chapter number.
    static func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .spellOut
        return (f.string(from: NSNumber(value: n)) ?? "\(n)").uppercased()
    }
}

enum AHText {
    static func temp(_ v: Double) -> String { "\(Int(v.rounded()))°" }

    /// "1D LATE", "TODAY", "TOMORROW", "NOV 4".
    static func due(_ task: TaskItem) -> String? { Mock.dueLabel(task)?.uppercased() }

    static func more(_ n: Int) -> String { "+ \(n) MORE" }

    /// "6:14", "4:58": twelve-hour clock whatever the system setting.
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }
}

extension View {
    /// Places a view at an absolute frame inside a full-widget ZStack (the widget sizes are fixed points).
    func ahPlace(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View {
        frame(width: w, height: h).position(x: x + w / 2, y: y + h / 2)
    }

    /// Wide-tracked Futura caps, the voice of every title and label.
    func ahCaps(_ size: CGFloat, _ color: Color, tracking: CGFloat? = nil, bold: Bool = true) -> some View {
        font(bold ? AH.futura(size) : AH.futuraMed(size))
            .tracking(tracking ?? size * 0.22)
            .foregroundStyle(color)
    }
}

/// The finish on every frame: a soft warm key light from above, a mauve vignette and film grain.
struct AHFinish: ViewModifier {
    var vignette: Double = 0.55
    var grain: Double = 0.42

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { g in
                    RadialGradient(colors: [Color(hex: 0xFFE7BE, opacity: 0.55), Color(hex: 0xFFE7BE, opacity: 0)],
                                   center: UnitPoint(x: 0.5, y: -0.08), startRadius: 0,
                                   endRadius: max(g.size.width, g.size.height) * 0.8)
                }
                .blendMode(.softLight)
            }
            .overlay {
                GeometryReader { g in
                    RadialGradient(stops: [.init(color: .white, location: 0), .init(color: .white, location: 0.52),
                                           .init(color: Color(hex: 0xB07A97), location: 1)],
                                   center: UnitPoint(x: 0.5, y: 0.46), startRadius: 0,
                                   endRadius: hypot(g.size.width, g.size.height) * 0.6)
                }
                .blendMode(.multiply)
                .opacity(vignette)
            }
            .overlay {
                AHTex.grain.resizable(resizingMode: .tile).blendMode(.overlay).opacity(grain)
            }
            .compositingGroup()
    }
}
