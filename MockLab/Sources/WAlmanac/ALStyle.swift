import SwiftUI

// Almanac: the page, its inks and type. A widget is a page from an almanac: a brushed gesso board, cream by day and
// espresso at night, with a painted plate of the Matterhorn tipped in at its head (ALPlate.swift), the month set as a
// big Didone word and the weather typeset beneath it as an almanac entry.

/// An sRGB colour that can be mixed (for the plate's glazes).
struct ALRGB {
    var r, g, b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    func mixed(_ o: ALRGB, _ t: Double) -> ALRGB {
        var m = self
        m.r += (o.r - r) * t
        m.g += (o.g - g) * t
        m.b += (o.b - b) * t
        return m
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
}

/// The page's inks. Day: espresso ink on cream, olive labels, brass rules, rubric red for what is late. Night: the
/// same page as an espresso board, cream ink and gold leaf. Contrast is given on the plain page and, after the slash,
/// on its worst spot (day: the darkest grain near the edge, about #CEBDA3; night: the lit ridges, about #4B3C2B).
struct ALInk {
    var night: Bool
    var paper: [Color]        // the board, top to foot
    var grainDark: Color      // tint of paper-lo (the shade of each stroke, fibres, foxing)
    var grainLight: Color     // tint of paper-hi (the lit ridge of each stroke)
    var grainStrength: Double
    var burn: Color           // the aged edge of the page
    var ink: Color            // primary type
    var inkSoft: Color        // secondary type
    var label: Color          // small capitals and notes (olive by day, sage at night)
    var rule: Color           // gold rules and frames
    var gild: [Color]         // gold leaf: crown, middle, foot
    var gildEdge: Color       // the cut edge of the leaf
    var gildRim: Color        // the sheen
    var rubric: Color         // late
    var lip: Color            // the lit (or shaded) lip of a letterpress impression
    var lipOffset: CGFloat

    static let day = ALInk(
        night: false,
        paper: [Color(hex: 0xF1E7D3), Color(hex: 0xE9DCC3)],
        grainDark: Color(hex: 0x5E4630), grainLight: Color(hex: 0xFFFBF0), grainStrength: 1,
        burn: Color(hex: 0x8A6440),
        ink: Color(hex: 0x23160E),           // 13 / 9.6:1
        inkSoft: Color(hex: 0x4F3B2C),       // 7.8 / 5.7:1
        label: Color(hex: 0x484926),         // 6.9 / 5.1:1
        rule: Color(hex: 0x9A7334),
        gild: [Color(hex: 0xCFA654), Color(hex: 0xA97B30), Color(hex: 0x7A5420)],
        gildEdge: Color(hex: 0x4A3014), gildRim: Color(hex: 0xFFF1C8),
        rubric: Color(hex: 0x88291A),        // 6.5 / 4.8:1
        lip: Color.white.opacity(0.7), lipOffset: 0.6)

    static let night = ALInk(
        night: true,
        paper: [Color(hex: 0x2F241A), Color(hex: 0x221911)],
        grainDark: Color(hex: 0x050302), grainLight: Color(hex: 0xC9A777), grainStrength: 0.75,
        burn: Color(hex: 0x070403),
        ink: Color(hex: 0xEFE3CB),           // 11.9 / 8.3:1
        inkSoft: Color(hex: 0xCDBC9F),       // 8.1 / 5.7:1
        label: Color(hex: 0xB3B286),         // 6.9 / 4.9:1
        rule: Color(hex: 0xC09A55),
        gild: [Color(hex: 0xF6E2AE), Color(hex: 0xDDB86E), Color(hex: 0xB08540)],
        gildEdge: Color(hex: 0x0B0603), gildRim: Color(hex: 0xFFF6DA),
        rubric: Color(hex: 0xE89C76),        // 6.8 / 4.8:1
        lip: Color.black.opacity(0.75), lipOffset: 0.8)

    /// Cream by day, espresso from sunset to sunrise.
    static func of(_ snapshot: DaySnapshot) -> ALInk {
        SkyClock(now: snapshot.date, weather: snapshot.weather).isDay ? .day : .night
    }
}

/// Didot for the month and the numerals (the high-contrast Didone of the almanac's display lines), Bodoni 72 for the
/// entry (sturdier at text sizes), Didot italic for the condition. All ship on iOS 17.
enum ALType {
    static func display(_ size: CGFloat) -> Font { .custom("Didot", size: size) }
    static func displayItalic(_ size: CGFloat) -> Font { .custom("Didot-Italic", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("BodoniSvtyTwoITCTT-Book", size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom("BodoniSvtyTwoITCTT-BookIta", size: size) }
}

extension Text {
    /// Small spaced capitals (the "to do" header, the year): Bodoni capitals set small and tracked open.
    func alCaps(_ size: CGFloat, _ color: Color, tracking: CGFloat = 1.8) -> some View {
        self.font(ALType.body(size)).tracking(tracking).textCase(.uppercase).foregroundStyle(color)
    }
}

extension View {
    /// Sets the view's first baseline at `y` points from the top of the page, its leading edge at `x`, so type sits
    /// on the page's grid whatever its line height. Laid in an overlay of the whole page, so it never moves the page.
    func alBaseline(x: CGFloat, y: CGFloat) -> some View {
        Color.clear.overlay(alignment: .topLeading) {
            alignmentGuide(.top) { $0[.firstTextBaseline] }.offset(x: x, y: y)
        }
    }

    /// Letterpress: the type pressed into the page, with the lit lip of the impression under it (by day) or the
    /// shade of a raised foil (at night).
    func alPressed(_ ink: ALInk) -> some View {
        shadow(color: ink.lip, radius: 0, x: 0, y: ink.lipOffset)
    }
}

// MARK: - The page

/// The page: a brushed gesso board (paper-lo and paper-hi, tinted for the edition), laid lines and chain lines
/// pressed into it, and the aged, darker edge. The texture is 348x365 at 1 px per point; smaller pages use its top
/// left corner, so its grain never scales.
struct ALPaper: View {
    var ink: ALInk

    var body: some View {
        ZStack {
            LinearGradient(colors: ink.paper, startPoint: .top, endPoint: .bottom)
            grain("paper-lo", ink.grainDark, ink.night ? 1 : 0.55)
            grain("paper-hi", ink.grainLight, ink.night ? 0.45 : 1)
            ALLaidLines(color: ink.night ? .black : ink.burn, opacity: ink.night ? 0.5 : 0.35)
            EllipticalGradient(colors: [.clear, .clear, ink.burn.opacity(ink.night ? 0.55 : 0.22)],
                               center: UnitPoint(x: 0.5, y: 0.45), startRadiusFraction: 0, endRadiusFraction: 0.78)
        }
    }

    private func grain(_ name: String, _ color: Color, _ opacity: Double) -> some View {
        Color.clear.overlay(alignment: .topLeading) {
            Mock.texture("weather-almanac/\(name)")
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .foregroundStyle(color)
                .frame(width: 348, height: 365)
                .opacity(opacity * ink.grainStrength)
        }
        .clipped()
    }
}

/// Laid paper: fine laid lines across and wider-spaced chain lines down, pressed faintly into the sheet.
struct ALLaidLines: View {
    var color: Color
    var opacity: Double

    var body: some View {
        Canvas { ctx, size in
            var laid = Path()
            var y: CGFloat = 0.6
            while y < size.height {
                laid.addRect(CGRect(x: 0, y: y, width: size.width, height: 0.35))
                y += 1.6
            }
            var chain = Path()
            var x: CGFloat = 13
            while x < size.width {
                chain.addRect(CGRect(x: x, y: 0, width: 0.6, height: size.height))
                x += 25
            }
            ctx.fill(laid, with: .color(color.opacity(0.045 * opacity)))
            ctx.fill(chain, with: .color(color.opacity(0.07 * opacity)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Gold

/// Gold leaf set in type: the leaf graded from a lit crown to a deep foot, a sheen across it, brushed hollows in the
/// gilt, and its cut edge under it, so it stands a hair proud of the page.
struct ALGilt: View {
    var text: String
    var font: Font
    var ink: ALInk
    /// Lets a long word (a month) shrink to its space, every layer by the same amount.
    var fit = false
    var sparkle: UnitPoint? = nil

    var body: some View {
        ZStack {
            layer.foregroundStyle(ink.gildEdge.opacity(ink.night ? 0.9 : 0.55))
                .offset(x: 0.5, y: 1.1)
            layer.foregroundStyle(LinearGradient(stops: [.init(color: ink.gild[0], location: 0),
                                                         .init(color: ink.gild[1], location: 0.55),
                                                         .init(color: ink.gild[2], location: 1)],
                                                 startPoint: .top, endPoint: .bottom))
            layer.foregroundStyle(LinearGradient(stops: [.init(color: .clear, location: 0.2),
                                                         .init(color: ink.gildRim.opacity(0.75), location: 0.42),
                                                         .init(color: .clear, location: 0.62)],
                                                 startPoint: UnitPoint(x: 0, y: 0.1), endPoint: UnitPoint(x: 1, y: 0.9)))
                .blendMode(.screen)
            layer.hidden().overlay {
                Image("CoverGilt")
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .scaledToFill()
                    .foregroundStyle(ink.gildEdge.opacity(0.22))
                    .mask(layer)
            }
        }
        .compositingGroup()
        .shadow(color: ink.night ? .black.opacity(0.5) : ink.gildEdge.opacity(0.18), radius: 1.5, x: 0, y: 1)
        .overlay {
            if let sparkle {
                GeometryReader { geo in
                    ALSparkle(color: ink.gildRim, size: 9)
                        .position(x: sparkle.x * geo.size.width, y: sparkle.y * geo.size.height)
                }
            }
        }
    }

    @ViewBuilder private var layer: some View {
        if fit {
            Text(text).font(font).lineLimit(1).minimumScaleFactor(0.7)
        } else {
            Text(text).font(font).fixedSize()
        }
    }
}

/// A glint on gold leaf: a four-pointed star with a soft bloom.
struct ALSparkle: View {
    var color: Color
    var size: CGFloat

    var body: some View {
        Canvas { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let r = min(s.width, s.height) / 2
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.7, y: c.y - r * 0.7, width: r * 1.4, height: r * 1.4)),
                     with: .radialGradient(Gradient(colors: [color.opacity(0.7), .clear]), center: c, startRadius: 0,
                                           endRadius: r * 0.7))
            var st = Path()
            let k = r * 0.12
            st.move(to: CGPoint(x: c.x, y: c.y - r))
            st.addLine(to: CGPoint(x: c.x + k, y: c.y - k))
            st.addLine(to: CGPoint(x: c.x + r * 0.8, y: c.y))
            st.addLine(to: CGPoint(x: c.x + k, y: c.y + k))
            st.addLine(to: CGPoint(x: c.x, y: c.y + r))
            st.addLine(to: CGPoint(x: c.x - k, y: c.y + k))
            st.addLine(to: CGPoint(x: c.x - r * 0.8, y: c.y))
            st.addLine(to: CGPoint(x: c.x - k, y: c.y - k))
            st.closeSubpath()
            ctx.fill(st, with: .color(color))
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// An Oxford rule in gold: a thick line over a hairline, catching the light toward the middle.
struct ALRule: View {
    var ink: ALInk
    var thick: CGFloat = 1.1

    var body: some View {
        let gold = LinearGradient(colors: [ink.rule.opacity(0.75), ink.night ? ink.gild[0] : ink.gild[1], ink.rule.opacity(0.75)],
                                  startPoint: .leading, endPoint: .trailing)
        VStack(spacing: 1.6) {
            Rectangle().fill(gold).frame(height: thick)
            Rectangle().fill(gold).frame(height: 0.5)
        }
        .shadow(color: ink.lip.opacity(0.6), radius: 0, x: 0, y: 0.5)
        .accessibilityHidden(true)
    }
}

/// A gold hairline down the page between two columns.
struct ALColumnRule: View {
    var ink: ALInk

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [ink.rule.opacity(0), ink.rule, ink.rule.opacity(0)], startPoint: .top, endPoint: .bottom))
            .frame(width: 0.6)
            .accessibilityHidden(true)
    }
}

/// A dotted leader between a label and its figure, as in an almanac's tables. Its baseline is its bottom, so in a
/// first-baseline HStack the dots sit on the line like full stops.
struct ALLeader: View {
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = 2
            let y = size.height - 1.2
            while x < size.width - 2 {
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.9, height: 0.9)), with: .color(color))
                x += 3.2
            }
        }
        .frame(minWidth: 8, maxWidth: .infinity)
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

// MARK: - Words

enum ALWords {
    static func month(_ date: Date, short: Bool = false) -> String {
        let f = DateFormatter()
        f.dateFormat = short ? "MMM" : "MMMM"
        return f.string(from: date)
    }

    /// "the 3rd", "the 28th".
    static func ordinal(_ date: Date) -> String {
        let n = Calendar.current.component(.day, from: date)
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "the \(n)\(suffix)"
    }

    /// The year in Roman numerals: 2026 -> MMXXVI.
    static func roman(_ date: Date) -> String {
        var n = Calendar.current.component(.year, from: date)
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                      (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var out = ""
        for (v, s) in table { while n >= v { out += s; n -= v } }
        return out
    }

    static func degrees(_ t: Double) -> String { "\(Int(t.rounded()))°" }

    static func condition(_ w: WeatherSnapshot) -> String { w.label.lowercased() }

    /// "4:58": twelve-hour clock whatever the system setting.
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    /// Today's sunrise and sunset and which comes next: sunset while the sun is up, otherwise sunrise.
    static func sun(_ w: WeatherSnapshot?, now: Date) -> (rise: Date, set: Date, riseNext: Bool)? {
        guard let rise = w?.sunrise, let set = w?.sunset else { return nil }
        let cal = Calendar.current
        func today(_ d: Date) -> Date {
            cal.date(bySettingHour: cal.component(.hour, from: d), minute: cal.component(.minute, from: d), second: 0, of: now) ?? d
        }
        let riseNext = now < today(rise) || now >= today(set)
        return (rise, set, riseNext)
    }

    /// "10 h 44 m of light".
    static func daylight(_ w: WeatherSnapshot?) -> String? {
        guard let rise = w?.sunrise, let set = w?.sunset else { return nil }
        let cal = Calendar.current
        let a = cal.component(.hour, from: rise) * 60 + cal.component(.minute, from: rise)
        let b = cal.component(.hour, from: set) * 60 + cal.component(.minute, from: set)
        let m = b - a
        guard m > 0 else { return nil }
        return "\(m / 60) h \(m % 60) m of light"
    }
}
