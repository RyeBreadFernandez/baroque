import SwiftUI

/// Expedition palette and type: warm faded Kodachrome on a handmade field-station miniature.
enum EX {
    // Felt and paint (hex, so scenery can pre-mix atmospheric haze without iOS 18 Color.mix).
    static let hMustard: UInt32 = 0xD9A12B
    static let hGoldenrod: UInt32 = 0xE8B640
    static let hKhaki: UInt32 = 0xBCA572
    static let hBurnt: UInt32 = 0xC4602A
    static let hTomato: UInt32 = 0xC93C2C
    static let hPrussian: UInt32 = 0x223D5A
    static let hTeal: UInt32 = 0x2F6F72
    static let hCream: UInt32 = 0xF2E5C4
    static let hWalnut: UInt32 = 0x5A3A22
    static let hSnow: UInt32 = 0xF7F1E4
    static let hHaze: UInt32 = 0xC9D9C6     // the backdrop's pale aqua horizon, used for atmospheric layering
    static let hPine: UInt32 = 0x2E5143
    static let hOlive: UInt32 = 0x5C6A30

    static let mustard = Color(hex: hMustard)
    static let goldenrod = Color(hex: hGoldenrod)
    static let mustardDeep = Color(hex: 0xA97814)
    static let khaki = Color(hex: hKhaki)
    static let khakiDeep = Color(hex: 0x7F6B40)
    static let burnt = Color(hex: hBurnt)
    static let tomato = Color(hex: hTomato)
    static let tomatoDeep = Color(hex: 0x952619)
    static let prussian = Color(hex: hPrussian)
    static let teal = Color(hex: hTeal)
    static let cream = Color(hex: hCream)
    static let creamLight = Color(hex: 0xFBF3DE)
    static let walnut = Color(hex: hWalnut)
    static let walnutDeep = Color(hex: 0x3A2414)
    static let snow = Color(hex: hSnow)
    static let brass = Color(hex: 0xC9A04A)
    static let brassLight = Color(hex: 0xF0D68A)
    static let brassDeep = Color(hex: 0x7E5F22)

    /// Typewriter ribbon: a warm near-black.
    static let ink = Color(hex: 0x2A1E16)
    static let inkSoft = Color(hex: 0x5A4636)
    /// Contact and cast shadows: warm umber, never neutral grey.
    static let shadow = Color(hex: 0x2A1508)
    static let thread = Color(hex: 0xF3E6C8)

    // Type. PostScript names that ship on iOS 17 and macOS (checked with NSFont(name:)).
    static func head(_ s: CGFloat) -> Font { .custom("Futura-CondensedExtraBold", size: s) }
    static func headMed(_ s: CGFloat) -> Font { .custom("Futura-CondensedMedium", size: s) }
    static func futura(_ s: CGFloat) -> Font { .custom("Futura-Bold", size: s) }
    static func type(_ s: CGFloat) -> Font { .custom("AmericanTypewriter", size: s) }
    static func typeBold(_ s: CGFloat) -> Font { .custom("AmericanTypewriter-Semibold", size: s) }
    static func typeCond(_ s: CGFloat) -> Font { .custom("AmericanTypewriter-Condensed", size: s) }
    static func typeCondBold(_ s: CGFloat) -> Font { .custom("AmericanTypewriter-CondensedBold", size: s) }
    static func courier(_ s: CGFloat) -> Font { .custom("CourierNewPSMT", size: s) }

    static func tex(_ name: String) -> Image { Mock.texture("expedition/\(name)") }

    /// Linear mix of two hex colours (t = 0 gives a).
    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
        func ch(_ v: UInt32, _ s: UInt32) -> Double { Double((v >> s) & 0xFF) / 255 }
        let r = ch(a, 16) * (1 - t) + ch(b, 16) * t
        let g = ch(a, 8) * (1 - t) + ch(b, 8) * t
        let bl = ch(a, 0) * (1 - t) + ch(b, 0) * t
        return Color(.sRGB, red: r, green: g, blue: bl, opacity: 1)
    }

    static func mixHex(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func ch(_ v: UInt32, _ s: UInt32) -> Double { Double((v >> s) & 0xFF) }
        let r = UInt32((ch(a, 16) * (1 - t) + ch(b, 16) * t).rounded())
        let g = UInt32((ch(a, 8) * (1 - t) + ch(b, 8) * t).rounded())
        let bl = UInt32((ch(a, 0) * (1 - t) + ch(b, 0) * t).rounded())
        return (r << 16) | (g << 8) | bl
    }
}

enum EXDates {
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
}

/// What the miniature set should show for a weather code. The set is always lit as daytime
/// (a stylistic choice: the warm key light is part of the look), whatever the clock says.
enum EXWeather: Equatable {
    case clear, partly, overcast, fog, rain, snow, storm

    init(code: Int?) {
        guard let code else { self = .clear; return }
        switch code {
        case 0, 1: self = .clear
        case 2: self = .partly
        case 3: self = .overcast
        case 45, 48: self = .fog
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: self = .rain
        case 71, 73, 75, 77, 85, 86: self = .snow
        case 95, 96, 99: self = .storm
        default: self = .partly
        }
    }

    var showsSun: Bool { self == .clear || self == .partly }
    var rains: Bool { self == .rain || self == .storm }
    var snows: Bool { self == .snow }
    /// How grey the painted backdrop turns (0 = full Kodachrome).
    var gloom: Double {
        switch self {
        case .clear: return 0
        case .partly: return 0.08
        case .overcast, .fog: return 0.32
        case .rain, .storm: return 0.40
        case .snow: return 0.30
        }
    }
    /// One word for the small widget.
    var short: String {
        switch self {
        case .clear: return "CLEAR"
        case .partly: return "PARTLY"
        case .overcast: return "CLOUDY"
        case .fog: return "FOG"
        case .rain: return "RAIN"
        case .snow: return "SNOW"
        case .storm: return "STORM"
        }
    }
    var cloudCount: Int {
        switch self {
        case .clear: return 1
        case .partly: return 2
        default: return 3
        }
    }
}

extension TaskItem {
    var exLate: Bool { isOverdue(asOf: Mock.now) }
    var exToday: Bool { isDueToday(asOf: Mock.now) }
}

/// Typed strings: the field station's typewriter writes in plain caps for labels.
enum EXCopy {
    static func dueStamp(_ t: TaskItem) -> String? { Mock.dueLabel(t)?.uppercased() }
    static func temp(_ v: Double) -> String { "\(Int(v.rounded()))°" }
}
