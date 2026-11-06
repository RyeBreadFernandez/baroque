import SwiftUI

/// Neon Rain palette and type: a rain-wet night street at the foot of misty mountains, seen through glass.
/// Deep teal-green shadows, sodium amber, neon red and magenta, electric cyan, a touch of acid green, crushed blacks.
enum NR {
    // Crushed blacks and teal-green shadows
    static let ink = Color(hex: 0x030807)
    static let night = Color(hex: 0x071312)
    static let tealDeep = Color(hex: 0x0B1F1D)
    static let teal = Color(hex: 0x14332F)
    static let tealMist = Color(hex: 0x4A736B)
    static let tealPale = Color(hex: 0x9CC3B8)

    // Light sources
    static let sodium = Color(hex: 0xFF9F38)
    static let sodiumCore = Color(hex: 0xFFE6B8)
    static let red = Color(hex: 0xFF2B45)
    static let redCore = Color(hex: 0xFFD9DC)
    static let magenta = Color(hex: 0xFF34B0)
    static let magentaCore = Color(hex: 0xFFD8F1)
    static let cyan = Color(hex: 0x35EEFF)
    static let cyanCore = Color(hex: 0xE2FEFF)
    static let acid = Color(hex: 0xB8FF3C)
    static let halation = Color(hex: 0xFF4A1E)

    // Type colours
    static let paper = Color(hex: 0xEEF3EC)        // body text, a little green like a cold print
    static let paperDim = Color(hex: 0xA9BDB6)
    static let subtitle = Color(hex: 0xF8E35C)     // the yellow subtitle
    static let late = Color(hex: 0xFF5A66)

    // Type. PostScript names that ship on iOS 17 and macOS.
    static func cond(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-DemiBold", size: size) }
    static func condMedium(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-Medium", size: size) }
    static func condBold(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-Bold", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("AvenirNext-Medium", size: size) }
    static func sub(_ size: CGFloat) -> Font { .custom("AvenirNext-DemiBold", size: size) }
    static func mono(_ size: CGFloat) -> Font { .custom("Menlo-Regular", size: size) }
    static func monoBold(_ size: CGFloat) -> Font { .custom("Menlo-Bold", size: size) }
    static func hanzi(_ size: CGFloat) -> Font { .custom("PingFangHK-Regular", size: size) }
}

enum NRDates {
    static func string(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = format
        return f.string(from: date)
    }

    /// The weekday in Chinese for the neon sign, from Calendar weekday (1 = Sunday). Nothing else is written in Chinese.
    static func hanziWeekday(_ date: Date) -> [String] {
        let names = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        let wd = Calendar(identifier: .gregorian).component(.weekday, from: date)
        return names[(wd - 1 + 7) % 7].map { String($0) }
    }

    /// Monday-first week containing `date`.
    static func week(of date: Date) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    /// The voice-over timestamp, e.g. "TUE 09:41".
    static func stamp(_ date: Date) -> String { string(date, "EEE HH:mm").uppercased() }

    /// "9:41 a.m." for narration lines.
    static func clock(_ date: Date) -> String {
        string(date, "h:mm") + (Calendar.current.component(.hour, from: date) < 12 ? " a.m." : " p.m.")
    }
}

/// How the street and the glass behave for a weather code. The scene is always drawn at night or dusk
/// (a stylistic choice), but it never contradicts the weather the widget shows.
enum NRWeather {
    case clear      // wet street after rain, condensation, a few beads on the glass
    case cloudy     // low cloud dragging over the peaks
    case fog        // mist swallows the mid ridge
    case rain       // run-down streaks, falling rain, splashes
    case snow       // flakes, snowcaps, frost at the pane's edges

    static func from(_ code: Int?) -> NRWeather {
        guard let code else { return .clear }
        switch code {
        case 0, 1: return .clear
        case 2, 3: return .cloudy
        case 45, 48: return .fog
        case 51...67, 80...82, 95...99: return .rain
        case 71...77, 85, 86: return .snow
        default: return .cloudy
        }
    }

    var isWet: Bool { self == .rain }
}

/// One light in the scene, in unit coordinates of the scene rect. The street reflects it and the glass refracts it.
struct NRLight {
    var at: CGPoint
    var color: Color
    var size: CGFloat = 1      // relative brightness and width
}

extension View {
    /// Dark halo so text stays legible over the brightest paint.
    func nrLegible(_ strength: Double = 1) -> some View {
        self
            .shadow(color: .black.opacity(0.9 * strength), radius: 0.8, x: 0, y: 0.5)
            .shadow(color: NR.ink.opacity(0.75 * strength), radius: 4, x: 0, y: 1)
    }

    /// A slight chromatic fringe on bright edges, like a cheap wide-angle lens wide open.
    func nrFringe(_ amount: CGFloat = 0.6, opacity: Double = 0.45) -> some View {
        self
            .background { self.colorMultiply(Color(hex: 0xFF3040)).offset(x: -amount, y: 0).opacity(opacity).blendMode(.screen) }
            .background { self.colorMultiply(Color(hex: 0x30D8FF)).offset(x: amount, y: 0).opacity(opacity).blendMode(.screen) }
    }
}
