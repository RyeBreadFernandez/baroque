import SwiftUI

// Old Master: the palette, type and the few materials. Everything here is plain SwiftUI so it ports to the widget
// extension as is; textures come from Mock.texture (in the app they would be asset catalog images).

/// Umber, taupe and cream with one peach accent. Text tokens are checked against the lightest strokes of the panel
/// (about #4A3524): cream 9:1, creamSoft 7:1, creamFaint 4.9:1, peach 6.4:1.
enum OMInk {
    static let umber = Color(hex: 0x3F2C20)       // the panel
    static let umberDeep = Color(hex: 0x24170F)   // type on cream (today's circle, the button's arrow)
    static let cream = Color(hex: 0xF1E3CC)       // primary type
    static let creamSoft = Color(hex: 0xDCCAAE)   // secondary type
    static let creamFaint = Color(hex: 0xBCA98D)  // labels, past days
    static let peach = Color(hex: 0xE9B79A)       // today and late
    static let shadow = Color(hex: 0x0D0805)      // cast shadows: warm near-black
}

/// Three sizes per widget at most: a display numeral, the body serif, and a small label face.
/// Baskerville (titles, numerals, tasks, quotes) and Avenir Next (labels) both ship on iOS 17.
enum OMType {
    static func numeral(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
    static func serif(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", size: size) }
    static func label(_ size: CGFloat) -> Font { .custom("AvenirNext-Medium", size: size) }
}

extension Text {
    /// Small spaced capitals in the label face (the author line, the year).
    func omCaps(_ size: CGFloat, _ color: Color = OMInk.creamFaint, tracking: CGFloat = 1.4) -> some View {
        self.font(OMType.label(size)).tracking(tracking).textCase(.uppercase).foregroundStyle(color)
    }

    /// The small lowercase label (due dates, conditions, counts), as in the reference calendar.
    func omLabel(_ size: CGFloat, _ color: Color = OMInk.creamFaint) -> some View {
        self.font(OMType.label(size)).tracking(0.3).foregroundStyle(color)
    }
}

extension View {
    /// Type set straight onto the painting: a soft umber halo under each letter, so it reads on the brightest cloud.
    func omOnPaint(_ strength: Double = 1) -> some View {
        shadow(color: OMInk.shadow.opacity(0.75 * strength), radius: 0.6, x: 0, y: 0.8)
            .shadow(color: OMInk.shadow.opacity(0.55 * strength), radius: 5, x: 0, y: 0)
    }

    /// The one panel of a widget: a quiet umber board resting on the painting with a soft cast shadow.
    func omPanel(radius: CGFloat) -> some View { modifier(OMPanel(radius: radius)) }
}

/// A dark-umber board: barely-there brushwork, light falling from above, a faint lit edge on top and a soft shadow.
/// No frame, no inlay: the reference's calm calendar card.
struct OMPanel: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content.background {
            ZStack {
                shape.fill(OMInk.umber)
                    .shadow(color: OMInk.shadow.opacity(0.55), radius: 10, x: 0, y: 5)
                    .shadow(color: OMInk.shadow.opacity(0.45), radius: 1.6, x: 0, y: 1.2)
                Color.clear
                    .overlay {
                        Mock.texture("old-master/panel")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                    }
                    .overlay(LinearGradient(stops: [
                        .init(color: OMInk.cream.opacity(0.05), location: 0),
                        .init(color: .clear, location: 0.35),
                        .init(color: OMInk.shadow.opacity(0.16), location: 1)
                    ], startPoint: .top, endPoint: .bottom))
                    .clipShape(shape)
                shape.strokeBorder(LinearGradient(stops: [
                    .init(color: OMInk.cream.opacity(0.16), location: 0),
                    .init(color: OMInk.cream.opacity(0.0), location: 0.25),
                    .init(color: OMInk.shadow.opacity(0.0), location: 0.7),
                    .init(color: OMInk.shadow.opacity(0.35), location: 1)
                ], startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
            }
        }
    }
}

/// The next-quote button: a small cream disc with an umber arrow.
struct OMNextButton: View {
    var body: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(OMInk.umberDeep)
            .frame(width: 24, height: 24)
            .background {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xF6EBD8), OMInk.cream, Color(hex: 0xD9C4A4)],
                                         center: UnitPoint(x: 0.38, y: 0.3), startRadius: 0, endRadius: 15))
                    .shadow(color: OMInk.shadow.opacity(0.5), radius: 2.5, x: 0, y: 1.5)
            }
            .accessibilityLabel("Next quote")
    }
}

// MARK: - The surface of an old painting

/// Yellowed varnish: a warm glaze over the whole picture, deepening toward the edges the way old varnish does.
struct OMVarnish: View {
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
struct OMCraquelure: View {
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
            ctx.stroke(cracks, with: .color(OMInk.shadow.opacity(0.075 * opacity)), lineWidth: 0.3)
            ctx.translateBy(x: 0.25, y: 0.33)
            ctx.stroke(cracks, with: .color(OMInk.cream.opacity(0.035 * opacity)), lineWidth: 0.25)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Words

enum OMWords {
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
}
