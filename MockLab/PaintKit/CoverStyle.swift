import SwiftUI

// Old Master Cover: the palette, type and the few materials of the shipped widgets (ported from the MockLab mock's
// OMStyle.swift). Plain SwiftUI; the paintings are the Cover* images in PaintTextures.xcassets
// (scripts/export_cover_textures.py).

/// Umber, taupe and cream with one peach accent. Text tokens are checked against the lightest strokes of the dark
/// ground (about #4A3524): cream 9:1, creamSoft 7:1, creamFaint 4.9:1, peach 6.4:1.
enum CoverInk {
    static let umber = Color(hex: 0x3F2C20)
    static let umberDeep = Color(hex: 0x24170F)   // type on cream (today's circle, the button's arrow)
    static let cream = Color(hex: 0xF1E3CC)       // primary type
    static let creamSoft = Color(hex: 0xDCCAAE)   // secondary type
    static let creamFaint = Color(hex: 0xBCA98D)  // labels, past days
    static let peach = Color(hex: 0xE9B79A)       // today and late
    static let shadow = Color(hex: 0x0D0805)      // cast shadows: warm near-black
    /// The painting's dark ground at the foot of the canvases: the widget's container background, and the colour of
    /// any sliver left when a widget's shape differs slightly from the iPhone 17 design size.
    static let ground = Color(hex: 0x24150C)
}

/// Three sizes per widget at most: a display numeral, the body serif, and a small label face.
/// Baskerville (titles, numerals, tasks, quotes) and Avenir Next (labels) both ship on iOS 17.
enum CoverType {
    static func numeral(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
    static func serif(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", size: size) }
    static func label(_ size: CGFloat) -> Font { .custom("AvenirNext-Medium", size: size) }
}

extension Text {
    /// Small spaced capitals in the label face (the author line, the month, the year).
    func coverCaps(_ size: CGFloat, _ color: Color = CoverInk.creamFaint, tracking: CGFloat = 1.4) -> some View {
        self.font(CoverType.label(size)).tracking(tracking).textCase(.uppercase).foregroundStyle(color)
    }

    /// The small lowercase label (due dates, conditions, counts).
    func coverLabel(_ size: CGFloat, _ color: Color = CoverInk.creamFaint) -> some View {
        self.font(CoverType.label(size)).tracking(0.3).foregroundStyle(color)
    }
}

extension View {
    /// Type set straight onto the painting: a soft umber halo under each letter, so it reads on the brightest cloud.
    func coverOnPaint(_ strength: Double = 1) -> some View {
        shadow(color: CoverInk.shadow.opacity(0.75 * strength), radius: 0.6, x: 0, y: 0.8)
            .shadow(color: CoverInk.shadow.opacity(0.55 * strength), radius: 5, x: 0, y: 0)
    }
}

/// The next-quote button: a small cream disc with an umber arrow. The widget wraps it in Button(intent:); the app's
/// preview and the renders show it as is.
struct CoverNextButton: View {
    var body: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(CoverInk.umberDeep)
            .frame(width: 24, height: 24)
            .background {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xF6EBD8), CoverInk.cream, Color(hex: 0xD9C4A4)],
                                         center: UnitPoint(x: 0.38, y: 0.3), startRadius: 0, endRadius: 15))
                    .shadow(color: CoverInk.shadow.opacity(0.5), radius: 2.5, x: 0, y: 1.5)
            }
            .accessibilityLabel("Next quote")
    }
}

// MARK: - The surface of an old painting

/// Yellowed varnish: a warm glaze over the whole picture, deepening toward the edges the way old varnish does.
struct CoverVarnish: View {
    var strength: Double = 1

    var body: some View {
        ZStack {
            Color(hex: 0xC09050).opacity(0.05 * strength)
            RadialGradient(colors: [.clear, Color(hex: 0x1E1006).opacity(0.38 * strength)],
                           center: UnitPoint(x: 0.5, y: 0.45), startRadius: 70, endRadius: 300)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Craquelure: a fine network of cracks in the old paint, a dark hairline with its lit lower lip. Irregular cells on
/// a jittered grid, one Canvas, crisp at any scale and only visible close up.
struct CoverCraquelure: View {
    var seed: UInt64 = 5
    var cell: CGFloat = 7
    var opacity: Double = 1

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed)
            let cols = Int(size.width / cell) + 2
            let rows = Int(size.height / cell) + 2
            var grid: [[CGPoint]] = []
            for r in 0..<rows {
                var row: [CGPoint] = []
                for c in 0..<cols {
                    row.append(CGPoint(x: (CGFloat(c) - 0.5 + CGFloat(rng.signed()) * 0.38) * cell,
                                       y: (CGFloat(r) - 0.5 + CGFloat(rng.signed()) * 0.38) * cell * 0.85))
                }
                grid.append(row)
            }
            var cracks = Path()
            func crack(_ a: CGPoint, _ b: CGPoint) {
                let mx = (a.x + b.x) / 2 + CGFloat(rng.signed()) * cell * 0.14
                let my = (a.y + b.y) / 2 + CGFloat(rng.signed()) * cell * 0.14
                cracks.move(to: a)
                cracks.addLine(to: CGPoint(x: mx, y: my))
                cracks.addLine(to: b)
            }
            for r in 0..<rows {
                for c in 0..<cols {
                    if c + 1 < cols, rng.next() > 0.1 { crack(grid[r][c], grid[r][c + 1]) }
                    if r + 1 < rows, rng.next() > 0.18 { crack(grid[r][c], grid[r + 1][c]) }
                }
            }
            ctx.stroke(cracks, with: .color(CoverInk.shadow.opacity(0.075 * opacity)), lineWidth: 0.3)
            ctx.translateBy(x: 0.25, y: 0.33)
            ctx.stroke(cracks, with: .color(CoverInk.cream.opacity(0.035 * opacity)), lineWidth: 0.25)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Words

enum CoverWords {
    static func month(_ date: Date, short: Bool = false) -> String {
        let f = DateFormatter()
        f.dateFormat = short ? "MMM" : "MMMM"
        return f.string(from: date)
    }

    static func day(_ date: Date) -> String { String(Calendar.current.component(.day, from: date)) }

    /// "4:58": twelve-hour clock whatever the system setting.
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        return f.string(from: date)
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

    static func temp(_ w: WeatherSnapshot?) -> String {
        guard let w else { return "—" }
        return "\(Int(w.temperature.rounded()))°"
    }

    /// "sunset 4:58" while the sun is up, otherwise "sunrise 6:14".
    static func sunEvent(_ w: WeatherSnapshot?, now: Date) -> String? {
        guard let w else { return nil }
        if let set = w.sunset, let rise = w.sunrise {
            let cal = Calendar.current
            let setToday = cal.date(bySettingHour: cal.component(.hour, from: set), minute: cal.component(.minute, from: set), second: 0, of: now) ?? set
            let riseToday = cal.date(bySettingHour: cal.component(.hour, from: rise), minute: cal.component(.minute, from: rise), second: 0, of: now) ?? rise
            if now < riseToday { return "sunrise \(clock(rise))" }
            if now < setToday { return "sunset \(clock(set))" }
            return "sunrise \(clock(rise))"
        }
        return nil
    }

    static func more(_ n: Int) -> String { "+ \(n) more" }

    /// A task's due note against the snapshot's date (not the wall clock): "1d late", "today", "tomorrow", otherwise
    /// "Nov 4". Nil when undated.
    static func due(_ task: TaskItem, now: Date) -> String? {
        guard let due = task.due else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: due)).day ?? 0
        if days < 0 { return "\(-days)d late" }
        if days == 0 { return "today" }
        if days == 1 { return "tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: due)
    }
}

// MARK: - Size

extension BaroqueSize {
    /// The iPhone 17 widget size in points: every Cover layout and painting is made at this size.
    var coverDesignSize: CGSize {
        switch self {
        case .small: return CGSize(width: 164, height: 164)
        case .medium: return CGSize(width: 348, height: 164)
        case .large: return CGSize(width: 348, height: 365)
        }
    }
}

/// Lays a Cover widget out at its iPhone 17 design size, then scales it uniformly to fit the space it is offered,
/// centred. Widget shapes differ by a point or two between iPhones, so the scaled picture can leave a sliver along
/// one edge; it shows the painting's dark ground.
struct CoverFrame<Content: View>: View {
    var size: BaroqueSize
    @ViewBuilder var content: Content

    var body: some View {
        let design = size.coverDesignSize
        GeometryReader { geo in
            let scale = min(geo.size.width / design.width, geo.size.height / design.height)
            content
                .frame(width: design.width, height: design.height)
                .clipped()
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(CoverInk.ground)
    }
}
