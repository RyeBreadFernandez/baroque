import SwiftUI

// The Weather widget: the temperature as a huge thin numeral standing in the fog between the Matterhorn and the
// spruce, the month in small spaced capitals, a thin white line icon and the condition as a small word in the sky,
// and the sunrise and sunset on one slim strip of frosted, painted-mist glass along the foot.

enum GNInk {
    static let fog = Color(hex: 0xF3F3EC)        // primary type
    static let soft = Color(hex: 0xD6DBCE)       // secondary type
    static let faint = Color(hex: 0xA9B2A0)      // labels
    static let gold = Color(hex: 0xE4D19C)       // soft gold accents
    static let late = Color(hex: 0xF4B47A)       // late tasks: warm amber
    static let shade = Color(hex: 0x0A0E09)      // halos under type
}

enum GNType {
    static func caps(_ size: CGFloat) -> Font { .system(size: size, weight: .medium) }
    static func word(_ size: CGFloat) -> Font { .system(size: size, design: .serif).italic() }
    static func serif(_ size: CGFloat) -> Font { .system(size: size, design: .serif) }
    static func time(_ size: CGFloat) -> Font { .system(size: size, weight: .light).width(.condensed) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
}

enum GNWords {
    static func month(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: date).uppercased()
    }

    static func day(_ date: Date) -> String { String(Calendar.current.component(.day, from: date)) }

    static func temp(_ w: WeatherSnapshot?) -> String {
        guard let w else { return "--" }   // with a degree sign SF set the ring in another weight
        return "\(Int(w.temperature.rounded()))°"
    }

    static func clock(_ date: Date?) -> (String, String) {
        guard let date else { return ("\u{2013}:\u{2013}", "") }
        // POSIX, so a Mac (or phone) set to 24-hour time doesn't turn "h:mm" into "16:58".
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        let g = DateFormatter()
        g.locale = Locale(identifier: "en_US_POSIX")
        g.dateFormat = "a"
        return (f.string(from: date), g.string(from: date).lowercased())
    }

    static func condition(_ snap: DaySnapshot) -> String {
        guard let w = snap.weather else { return snap.weatherError == nil ? "No weather yet" : "Weather offline" }
        return w.label
    }

    /// The next sun event from now: sunset while the sun is up, otherwise the coming sunrise.
    static func nextSun(_ snap: DaySnapshot) -> (rise: Bool, time: Date?) {
        guard let w = snap.weather else { return (false, nil) }
        let clock = SkyClock(now: snap.date, weather: w)
        return clock.isDay ? (false, w.sunset) : (true, w.sunrise)
    }

    /// The thin line symbol for the condition, by day or night.
    static func symbol(_ w: WeatherSnapshot?, isDay: Bool) -> String {
        guard let w else { return "cloud" }
        switch w.code {
        case 0: return isDay ? "sun.max" : "moon.stars"
        case 1: return isDay ? "sun.max" : "moon"
        case 2: return isDay ? "cloud.sun" : "cloud.moon"
        case 3: return "cloud"
        case 45, 48: return "cloud.fog"
        case 51, 53, 55, 56, 57: return "cloud.drizzle"
        case 61, 63, 65, 66, 67: return "cloud.rain"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow"
        case 80, 81, 82: return "cloud.heavyrain"
        case 95, 96, 99: return "cloud.bolt.rain"
        default: return "cloud"
        }
    }
}

extension View {
    /// Type set on the painting: a soft shade under each letter, and a feathered pool of shade behind the words.
    func gnOnPaint(_ strength: Double = 1) -> some View {
        shadow(color: GNInk.shade.opacity(0.7 * strength), radius: 0.6, x: 0, y: 0.6)
            .shadow(color: GNInk.shade.opacity(0.5 * strength), radius: 5, x: 0, y: 0)
    }

    func gnOnSky(_ strength: Double = 1) -> some View {
        background {
            Ellipse()
                .fill(GNInk.shade.opacity(0.3 * strength))
                .padding(.horizontal, -10)
                .padding(.vertical, -7)
                .blur(radius: 8)
        }
        .gnOnPaint(strength)
    }
}

extension Text {
    func gnCaps(_ size: CGFloat, _ color: Color = GNInk.soft, tracking: CGFloat = 2.6) -> some View {
        font(GNType.caps(size)).tracking(tracking).foregroundStyle(color)
    }
}

/// The month in small spaced capitals, the day after it, lighter.
struct GNMonth: View {
    var date: Date
    var size: CGFloat = 9
    var showsDay = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(GNWords.month(date)).gnCaps(size, GNInk.fog)
            if showsDay {
                Text(GNWords.day(date)).gnCaps(size, GNInk.faint, tracking: 1)
            }
        }
        .lineLimit(1)
        .fixedSize()
    }
}

/// The thin white line icon, glowing faintly in the painted sky.
struct GNIcon: View {
    var weather: WeatherSnapshot?
    var isDay: Bool
    var size: CGFloat

    var body: some View {
        Image(systemName: GNWords.symbol(weather, isDay: isDay))
            .symbolRenderingMode(.monochrome)
            .font(.system(size: size, weight: .thin))
            .foregroundStyle(GNInk.fog)
            .shadow(color: Color.white.opacity(0.35), radius: 4)
            .gnOnPaint(0.8)
    }
}

/// The condition as a small italic word, with the icon.
struct GNCondition: View {
    var snap: DaySnapshot
    var iconSize: CGFloat
    var wordSize: CGFloat
    var showsWord = true

    var body: some View {
        let clock = SkyClock(now: snap.date, weather: snap.weather)
        HStack(alignment: .center, spacing: 8) {
            if showsWord && snap.weather != nil {
                Text(GNWords.condition(snap).lowercased())
                    .font(GNType.word(wordSize))
                    .foregroundStyle(snap.weather == nil ? GNInk.late : GNInk.fog)
                    .lineLimit(1)
                    .fixedSize()
                    .gnOnSky(0.9)
            }
            GNIcon(weather: snap.weather, isDay: clock.isDay, size: iconSize)
        }
    }
}

// MARK: - The strip

/// The tiny sun mark: a half sun on the horizon line with a chevron over it, pointing up for sunrise, down for sunset.
struct GNSunMark: View {
    var rise: Bool
    var size: CGFloat = 11

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let line = h * 0.84
            let r = w * 0.24
            var horizon = Path()
            horizon.move(to: CGPoint(x: w * 0.04, y: line))
            horizon.addLine(to: CGPoint(x: w * 0.96, y: line))
            var sun = Path()
            sun.addArc(center: CGPoint(x: w / 2, y: line), radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            var rays = Path()
            for a in [200.0, 235.0, 305.0, 340.0] {
                let rad = a * .pi / 180
                rays.move(to: CGPoint(x: w / 2 + cos(rad) * r * 1.45, y: line + sin(rad) * r * 1.45))
                rays.addLine(to: CGPoint(x: w / 2 + cos(rad) * r * 1.85, y: line + sin(rad) * r * 1.85))
            }
            var chevron = Path()
            let cy = h * 0.04, cw = w * 0.17, ch = h * 0.17
            if rise {
                chevron.move(to: CGPoint(x: w / 2 - cw, y: cy + ch)); chevron.addLine(to: CGPoint(x: w / 2, y: cy))
                chevron.addLine(to: CGPoint(x: w / 2 + cw, y: cy + ch))
            } else {
                chevron.move(to: CGPoint(x: w / 2 - cw, y: cy)); chevron.addLine(to: CGPoint(x: w / 2, y: cy + ch))
                chevron.addLine(to: CGPoint(x: w / 2 + cw, y: cy))
            }
            let style = StrokeStyle(lineWidth: max(0.8, w * 0.07), lineCap: .round, lineJoin: .round)
            ctx.fill(sun, with: .color(GNInk.gold.opacity(0.35)))
            ctx.stroke(sun, with: .color(GNInk.gold), style: style)
            ctx.stroke(horizon, with: .color(GNInk.gold), style: style)
            ctx.stroke(rays, with: .color(GNInk.gold.opacity(0.85)), style: style)
            ctx.stroke(chevron, with: .color(GNInk.fog), style: style)
        }
        .frame(width: size * 1.25, height: size)
    }
}

/// A sun time: the mark, the time in the numeral's face, am or pm small after it.
struct GNSunTime: View {
    var rise: Bool
    var time: Date?
    var size: CGFloat = 15
    var label: Bool = true

    var body: some View {
        let t = GNWords.clock(time)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            GNSunMark(rise: rise, size: size * 0.95)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - size * 0.12 }
            Text(t.0).font(GNType.time(size)).foregroundStyle(GNInk.fog)
            Text(t.1).font(GNType.label(max(8, size * 0.58))).foregroundStyle(GNInk.soft)
            if label {
                Text(rise ? "sunrise" : "sunset").font(GNType.word(size * 0.68)).foregroundStyle(GNInk.faint)
                    .padding(.leading, 2)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .shadow(color: GNInk.shade.opacity(0.45), radius: 2.5)
    }
}

/// High and low between the sun times.
struct GNHighLow: View {
    var weather: WeatherSnapshot
    var size: CGFloat = 12

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("H").font(GNType.caps(size * 0.62)).tracking(1).foregroundStyle(GNInk.faint)
            Text("\(Int(weather.high.rounded()))°").font(GNType.time(size)).foregroundStyle(GNInk.soft)
            Text("L").font(GNType.caps(size * 0.62)).tracking(1).foregroundStyle(GNInk.faint).padding(.leading, 3)
            Text("\(Int(weather.low.rounded()))°").font(GNType.time(size)).foregroundStyle(GNInk.soft)
        }
        .lineLimit(1)
        .fixedSize()
    }
}

/// What the strip carries: both sun times (high and low between them on large), or on small the next sun time and
/// the condition word.
enum GNStripMode { case both, bothWithHighLow, next }

struct GNStripContent: View {
    var snap: DaySnapshot
    var mode: GNStripMode
    var size: CGFloat = 15
    var labels = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let w = snap.weather {
                switch mode {
                case .both, .bothWithHighLow:
                    GNSunTime(rise: true, time: w.sunrise, size: size, label: labels)
                    Spacer(minLength: 6)
                    if mode == .bothWithHighLow {
                        GNHighLow(weather: w, size: size * 0.82)
                        Spacer(minLength: 6)
                    }
                    GNSunTime(rise: false, time: w.sunset, size: size, label: labels)
                case .next:
                    let next = GNWords.nextSun(snap)
                    GNSunTime(rise: next.rise, time: next.time, size: size, label: false)
                    Spacer(minLength: 4)
                    Text(w.label.lowercased())
                        .font(GNType.word(size * 0.8))
                        .foregroundStyle(GNInk.fog)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            } else {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: size * 0.7, weight: .light))
                    .foregroundStyle(GNInk.late)
                let lead = mode == .bothWithHighLow ? "Couldn't load the forecast" : "No forecast"
                Text(snap.weatherError.map { "\(lead) \u{00B7} \($0)" } ?? "Waiting for the forecast")
                    .font(GNType.label(max(8, size * 0.66)))
                    .foregroundStyle(GNInk.soft)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 5)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Layouts

/// The whole Weather widget, at the iPhone 17 size for its family.
struct GNWeatherView: View {
    var snap: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .large: GNWeatherLarge(snap: snap)
        case .medium: GNWeatherMedium(snap: snap)
        case .small: GNWeatherSmall(snap: snap)
        }
    }
}

/// The scene for a snapshot, with its temperature standing in it.
struct GNWeatherScene: View {
    var snap: DaySnapshot
    var canvas: GNCanvas

    var body: some View {
        GNScene(canvas: canvas, numeral: GNWords.temp(snap.weather), clock: SkyClock(now: snap.date, weather: snap.weather),
                condition: SkyCondition(code: snap.weather?.code), phase: MoonPhase(date: snap.date))
    }
}

/// Month top left, condition and icon top right, the numeral beside the peak, the strip on the dark forest.
struct GNWeatherLarge: View {
    var snap: DaySnapshot

    static let strip = CGRect(x: 10, y: 307, width: 328, height: 44)

    var body: some View {
        let light = GNLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: SkyCondition(code: snap.weather?.code))
        ZStack(alignment: .topLeading) {
            GNWeatherScene(snap: snap, canvas: .large)
            GNMonth(date: snap.date, size: 9.5)
                .gnOnSky()
                .offset(x: 16, y: 19)
            GNCondition(snap: snap, iconSize: 23, wordSize: 14)
                .frame(width: 348 - 32, height: 30, alignment: .trailing)
                .offset(x: 16, y: 10)
            GNGlass(rect: Self.strip, radius: 14, light: light, blur: 5) { GNWeatherScene(snap: snap, canvas: .large) }
            GNStripContent(snap: snap, mode: .bothWithHighLow, size: 16)
                .frame(width: Self.strip.width - 24, height: Self.strip.height)
                .offset(x: Self.strip.minX + 12, y: Self.strip.minY)
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }
}

/// The numeral fills the left half; month above it; condition and icon in the open sky right of the peak; the strip
/// across the forest at the bottom right.
struct GNWeatherMedium: View {
    var snap: DaySnapshot

    static let strip = CGRect(x: 170, y: 118, width: 168, height: 36)

    var body: some View {
        let light = GNLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: SkyCondition(code: snap.weather?.code))
        ZStack(alignment: .topLeading) {
            GNWeatherScene(snap: snap, canvas: .medium)
            GNMonth(date: snap.date, size: 8.5)
                .gnOnSky()
                .offset(x: 16, y: 16)
            GNCondition(snap: snap, iconSize: 20, wordSize: 13)
                .frame(width: 348 - 32, height: 26, alignment: .trailing)
                .offset(x: 16, y: 11)
            GNGlass(rect: Self.strip, radius: 12, light: light, blur: 5) { GNWeatherScene(snap: snap, canvas: .medium) }
            GNStripContent(snap: snap, mode: .both, size: 14, labels: false)
                .frame(width: Self.strip.width - 22, height: Self.strip.height)
                .offset(x: Self.strip.minX + 11, y: Self.strip.minY)
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }
}

/// Month and icon on the dark sky; the numeral beside the summit; the strip with the next sun time, high and low.
struct GNWeatherSmall: View {
    var snap: DaySnapshot

    static let strip = CGRect(x: 8, y: 124, width: 148, height: 32)

    var body: some View {
        let light = GNLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: SkyCondition(code: snap.weather?.code))
        ZStack(alignment: .topLeading) {
            GNWeatherScene(snap: snap, canvas: .small)
            GNMonth(date: snap.date, size: 8, showsDay: false)
                .gnOnSky()
                .offset(x: 16, y: 16)
            GNCondition(snap: snap, iconSize: 17, wordSize: 11, showsWord: false)
                .frame(width: 164 - 32, height: 22, alignment: .trailing)
                .offset(x: 16, y: 11)
            GNGlass(rect: Self.strip, radius: 11, light: light, blur: 4.5) { GNWeatherScene(snap: snap, canvas: .small) }
            GNStripContent(snap: snap, mode: .next, size: 13)
                .frame(width: Self.strip.width - 16, height: Self.strip.height)
                .offset(x: Self.strip.minX + 8, y: Self.strip.minY)
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }
}
