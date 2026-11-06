import SwiftUI

@main
struct Main {
    @MainActor static func main() { MockRunner.run(Topo()) }
}

/// Topo Survey: a vintage topographic survey sheet in daylight. Tan paper with fibres and fold creases, brown contours
/// (bold index contours with elevations) over Swiss-style hillshade, woodland tint, lakes with water lining, a survey grid
/// and zebra neatline. Weather is a legend inset, the week is a scale bar, tasks are numbered waypoints on a dashed route,
/// and the quote sits in the map's cartouche.
struct Topo: MockAesthetic {
    let name = "Topo Survey"
    let slug = "topo"
    let tagline = "A daylight survey sheet: contours over hillshade, the week as a scale bar, tasks as waypoints on a dashed route, quotes in the cartouche."

    @ViewBuilder func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        switch family {
        case .small: TopoDaySmall(snap: snapshot)
        case .medium: TopoDayMedium(snap: snapshot)
        case .large: TopoDayLarge(snap: snapshot)
        }
    }

    @ViewBuilder func quote(_ quote: Quote, family: Family) -> some View {
        switch family {
        case .small: TopoQuoteSmall(quote: quote)
        case .medium: TopoQuoteMedium(quote: quote)
        case .large: TopoQuoteLarge(quote: quote)
        }
    }

    func wallpaper() -> some View {
        Mock.texture("topo/wallpaper").resizable().interpolation(.high).scaledToFill()
    }
}

// MARK: - Palette and type

enum TopoInk {
    static let paper = Color(hex: 0xEDE2C6)
    static let paperLight = Color(hex: 0xF5EDD9)
    static let ink = Color(hex: 0x2A1F15)
    static let inkSoft = Color(hex: 0x4A3A2A)
    static let contour = Color(hex: 0x9C6232)
    static let contourIndex = Color(hex: 0x7A4519)
    static let forest = Color(hex: 0x46652F)
    static let red = Color(hex: 0xB42F25)
    static let redDeep = Color(hex: 0x8E2019)
    static let water = Color(hex: 0x3B78AA)
    static let waterInk = Color(hex: 0x2A64A0)
    static let grid = Color(hex: 0x23405C)
    static let shadow = Color(hex: 0x3A2612)
}

enum TopoFont {
    static func din(_ s: CGFloat) -> Font { .custom("DINCondensed-Bold", fixedSize: s) }
    static func futura(_ s: CGFloat) -> Font { .custom("Futura-Medium", fixedSize: s) }
    static func futuraBold(_ s: CGFloat) -> Font { .custom("Futura-Bold", fixedSize: s) }
    static func futuraItalic(_ s: CGFloat) -> Font { .custom("Futura-MediumItalic", fixedSize: s) }
    static func gill(_ s: CGFloat) -> Font { .custom("GillSans", fixedSize: s) }
    static func gillSemi(_ s: CGFloat) -> Font { .custom("GillSans-SemiBold", fixedSize: s) }
    static func gillItalic(_ s: CGFloat) -> Font { .custom("GillSans-Italic", fixedSize: s) }
    static func menlo(_ s: CGFloat) -> Font { .custom("Menlo-Regular", fixedSize: s) }
    static func quote(_ s: CGFloat) -> Font { .custom("Baskerville-Italic", fixedSize: s) }
}

extension View {
    /// A printed map label's halo: the paper colour spread a hair around the glyphs so contours never cut the text.
    func halo(_ color: Color = TopoInk.paperLight, strength: Double = 1) -> some View {
        self
            .shadow(color: color.opacity(strength), radius: 0.4)
            .shadow(color: color.opacity(strength), radius: 0.8)
            .shadow(color: color.opacity(0.85 * strength), radius: 1.6)
            .shadow(color: color.opacity(0.6 * strength), radius: 3)
    }
}

enum TopoDates {
    static func weekday(_ d: Date) -> String { format(d, "EEEE").uppercased() }
    static func shortWeekday(_ d: Date) -> String { format(d, "EEE").uppercased() }
    static func month(_ d: Date) -> String { format(d, "MMMM").uppercased() }
    static func shortMonth(_ d: Date) -> String { format(d, "MMM").uppercased() }
    static func dayNumber(_ d: Date) -> String { format(d, "d") }
    static func year(_ d: Date) -> String { format(d, "yyyy") }
    static func dayOfYear(_ d: Date) -> Int { Calendar.current.ordinality(of: .day, in: .year, for: d) ?? 1 }
    static func weekOfYear(_ d: Date) -> Int { Calendar(identifier: .iso8601).component(.weekOfYear, from: d) }

    static func week(_ d: Date) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: d)?.start ?? d
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private static func format(_ d: Date, _ f: String) -> String {
        let df = DateFormatter()
        df.dateFormat = f
        return df.string(from: d)
    }
}
