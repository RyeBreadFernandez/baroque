import SwiftUI

// Woodblock: palette, type and textures for an original ukiyo-e style print.
enum WB {
    // Inks and paper
    static let washi = Color(hex: 0xF3E9D3)
    static let washiDeep = Color(hex: 0xE7D8B8)
    static let sumi = Color(hex: 0x221E1C)
    static let sumiSoft = Color(hex: 0x4A403A)
    static let indigoDeep = Color(hex: 0x121B36)
    static let indigo = Color(hex: 0x1C2C55)
    static let prussian = Color(hex: 0x245883)
    static let prussianMid = Color(hex: 0x4F7EA3)
    static let prussianPale = Color(hex: 0x9DB7C6)
    static let celadon = Color(hex: 0xB4CDB6)
    static let celadonDeep = Color(hex: 0x6F9686)
    static let vermilion = Color(hex: 0xD2452B)
    static let vermilionDeep = Color(hex: 0xA9341F)
    static let ochre = Color(hex: 0xC9922F)
    static let ochrePale = Color(hex: 0xE6C77F)
    static let blush = Color(hex: 0xE9B9A0)
    static let pine = Color(hex: 0x1D3634)
    static let lacquer = Color(hex: 0x3A2219)

    // Type: Bodoni 72 numerals, Hoefler Text for reading, Hiragino Mincho for the kanji accents.
    static func bodoni(_ s: CGFloat) -> Font { .custom("BodoniSvtyTwoITCTT-Book", fixedSize: s) }
    static func bodoniBold(_ s: CGFloat) -> Font { .custom("BodoniSvtyTwoITCTT-Bold", fixedSize: s) }
    static func bodoniItalic(_ s: CGFloat) -> Font { .custom("BodoniSvtyTwoITCTT-BookIta", fixedSize: s) }
    static func bodoniSC(_ s: CGFloat) -> Font { .custom("BodoniSvtyTwoSCITCTT-Book", fixedSize: s) }
    static func hoefler(_ s: CGFloat) -> Font { .custom("HoeflerText-Regular", fixedSize: s) }
    static func hoeflerItalic(_ s: CGFloat) -> Font { .custom("HoeflerText-Italic", fixedSize: s) }
    static func hoeflerBlack(_ s: CGFloat) -> Font { .custom("HoeflerText-Black", fixedSize: s) }
    static func mincho(_ s: CGFloat) -> Font { .custom("HiraMinProN-W3", fixedSize: s) }
    static func minchoBold(_ s: CGFloat) -> Font { .custom("HiraMinProN-W6", fixedSize: s) }

    // Raster textures from Textures/woodblock/make.py (1 px per point)
    static let washiTex = Mock.texture("woodblock/washi")
    static let grainA = Mock.texture("woodblock/grain_a")
    static let grainB = Mock.texture("woodblock/grain_b")
    static let fibers = Mock.texture("woodblock/fibers")
}

// Calendar words for the cartouches.
enum WBDate {
    static let kanji = ["日", "月", "火", "水", "木", "金", "土"]       // Sunday first, like Calendar.weekday
    static let monthKanji = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二"]

    static func weekdayKanji(_ d: Date) -> String { kanji[Calendar.current.component(.weekday, from: d) - 1] }
    static func weekday(_ d: Date) -> String { fmt("EEEE", d) }
    static func weekdayShort(_ d: Date) -> String { fmt("EEE", d) }
    static func month(_ d: Date) -> String { fmt("MMMM", d) }
    static func monthShort(_ d: Date) -> String { fmt("MMM", d) }
    static func year(_ d: Date) -> String { fmt("yyyy", d) }
    static func day(_ d: Date) -> String { String(Calendar.current.component(.day, from: d)) }

    /// Monday-first week containing `d`.
    static func week(of d: Date) -> [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: d)
        let wd = cal.component(.weekday, from: start)        // 1 = Sunday
        let back = (wd + 5) % 7                               // days since Monday
        let monday = cal.date(byAdding: .day, value: -back, to: start) ?? start
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private static func fmt(_ f: String, _ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = f
        return df.string(from: d)
    }
}

/// What the print's sky shows for the current weather.
enum WBSky {
    case clear, fewClouds, cloudy, fog, rain, snow, storm, night

    static func from(_ w: WeatherSnapshot?) -> WBSky {
        guard let w else { return .fewClouds }
        if w.isDay == false && [0, 1, 2].contains(w.code) { return .night }
        switch w.code {
        case 0: return .clear
        case 1, 2: return .fewClouds
        case 3: return .cloudy
        case 45, 48: return .fog
        case 51...67, 80...82: return .rain
        case 71...77, 85, 86: return .snow
        case 95...99: return .storm
        default: return .cloudy
        }
    }

    var showsSun: Bool { self == .clear || self == .fewClouds }
}
