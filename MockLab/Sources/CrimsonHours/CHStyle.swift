import SwiftUI

// Crimson Hours: a rented room in the early sixties, always about an hour after sunset. Inside is tungsten
// light on oxblood flock wallpaper; outside the window the ridges go blue in the mist and a stair road of
// lamps climbs the slope. Everything warm is inside, everything cool is out there.

enum CH {
    // Interior: crimson flock
    static let crimson = Color(hex: 0x8C1A1F)
    static let crimsonLit = Color(hex: 0xC23A2E)

    // Tungsten
    static let tungsten = Color(hex: 0xF6C272)
    static let tungstenHot = Color(hex: 0xFFE3A8)
    static let amber = Color(hex: 0xE0923A)

    // Outside: the last of the dusk on the snow
    static let afterglow = Color(hex: 0xC98462)
    static let snowcap = Color(hex: 0xC9D2D8)

    // Paper and ink
    static let cream = Color(hex: 0xF1E6CB)
    static let ink = Color(hex: 0x2A1912)
    static let inkSoft = Color(hex: 0x4E382B)
    static let redInk = Color(hex: 0xB21F1E)
    static let redPrint = Color(hex: 0xC4262A)

    // Type. PostScript names that ship on both iOS 17 and macOS. Fixed sizes so Dynamic Type can't reflow a widget.
    static func didot(_ s: CGFloat) -> Font { .custom("Didot", fixedSize: s) }
    static func didotItalic(_ s: CGFloat) -> Font { .custom("Didot-Italic", fixedSize: s) }
    static func bodoniBold(_ s: CGFloat) -> Font { .custom("BodoniSvtyTwoITCTT-Bold", fixedSize: s) }
    static func bodoniItalic(_ s: CGFloat) -> Font { .custom("BodoniSvtyTwoITCTT-BookIta", fixedSize: s) }
    static func baskItalic(_ s: CGFloat) -> Font { .custom("Baskerville-Italic", fixedSize: s) }
    static func baskSemiItalic(_ s: CGFloat) -> Font { .custom("Baskerville-SemiBoldItalic", fixedSize: s) }
    /// Copperplate sets lowercase as small caps, so "1d late" reads as a printed label.
    static func label(_ s: CGFloat) -> Font { .custom("Copperplate", fixedSize: s) }
    static func labelBold(_ s: CGFloat) -> Font { .custom("Copperplate-Bold", fixedSize: s) }

    static func texture(_ name: String) -> Image { Mock.texture("crimson-hours/\(name)") }
}

/// Deterministic random numbers (SplitMix64) for the procedural art, so every render is identical.
struct CHRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> CGFloat { CGFloat(Double(next() >> 11) / Double(1 << 53)) }
    mutating func range(_ r: ClosedRange<CGFloat>) -> CGFloat { r.lowerBound + (r.upperBound - r.lowerBound) * unit() }
}

/// Small geometry helpers (functions rather than CGPoint operators, so nothing clashes once ported).
enum CHGeo {
    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
    static func unit(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
    }
    /// A smooth curve through the points (Catmull-Rom as cubic Béziers).
    static func smooth(_ p: [CGPoint], closed: Bool = false) -> Path {
        var path = Path()
        guard p.count > 1 else { return path }
        let n = p.count
        func at(_ i: Int) -> CGPoint { closed ? p[(i % n + n) % n] : p[min(max(i, 0), n - 1)] }
        path.move(to: p[0])
        for i in 0..<(closed ? n : n - 1) {
            let p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2)
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        if closed { path.closeSubpath() }
        return path
    }
    /// Smooth 1-D noise from a few seeded sines.
    static func wobble(_ x: CGFloat, seed: UInt64, base: CGFloat = 0.1, octaves: Int = 3) -> CGFloat {
        var r = CHRandom(seed)
        var amp: CGFloat = 1, freq = base, total: CGFloat = 0, v: CGFloat = 0
        for _ in 0..<octaves {
            v += amp * sin(freq * r.range(0.8...1.25) * x + r.range(0...(2 * .pi)))
            total += amp
            amp *= 0.5
            freq *= 2.1
        }
        return v / total
    }
}

enum CHDates {
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

    static func numberWord(_ n: Int) -> String {
        let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
        return n >= 0 && n < words.count ? words[n] : "\(n)"
    }
}

extension View {
    /// A soft dark halo so light type holds up over paint (two shadows: a tight one and a wide one).
    func chHalo(_ color: Color = .black, radius: CGFloat = 2, opacity: Double = 0.8) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius * 0.6)
            .shadow(color: color.opacity(opacity * 0.7), radius: radius * 2)
    }
}

/// Weather as the window should show it.
struct CHSky {
    var clouds: CGFloat = 0
    var rain: CGFloat = 0           // streaks on the glass
    var snow: CGFloat = 0
    var fog: CGFloat = 0
    var beads: CGFloat = 0          // a few drops left on the glass after rain
    var stars = true
    var moon = true
    var storm = false

    static func from(code: Int?) -> CHSky {
        guard let code else { return CHSky(clouds: 0.35, fog: 0.25, stars: false, moon: false) }
        switch code {
        case 0: return CHSky()
        case 1: return CHSky(clouds: 0.12)
        case 2: return CHSky(clouds: 0.45, stars: true, moon: true)
        case 3: return CHSky(clouds: 0.9, stars: false, moon: false)
        case 45, 48: return CHSky(clouds: 0.5, fog: 0.85, stars: false, moon: false)
        case 51, 53, 55, 56, 57: return CHSky(clouds: 0.85, rain: 0.35, fog: 0.2, stars: false, moon: false)
        case 61, 63, 65, 66, 67, 80, 81, 82: return CHSky(clouds: 1, rain: 1, fog: 0.25, stars: false, moon: false)
        case 71, 73, 75, 77, 85, 86: return CHSky(clouds: 0.85, snow: 1, fog: 0.2, stars: false, moon: false)
        case 95, 96, 99: return CHSky(clouds: 1, rain: 1, fog: 0.15, stars: false, moon: false, storm: true)
        default: return CHSky(clouds: 0.5, stars: false, moon: false)
        }
    }

    /// The quote windows show no forecast, so they get a quiet misty dusk with a few beads left on the glass.
    static let misty = CHSky(clouds: 0.3, fog: 0.35, beads: 1, stars: true, moon: true)
}
