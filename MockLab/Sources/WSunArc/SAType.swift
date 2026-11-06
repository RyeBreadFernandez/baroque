import SwiftUI

// Type for Sun Arc: the Cover's Baskerville and Avenir Next, the hero temperature in raised gilt, and the words.

enum SAType {
    static func serif(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", size: size) }
    static func label(_ size: CGFloat) -> Font { .custom("AvenirNext-Medium", size: size) }
}

/// Text as raised gilt leaf catching the painting's light (the Cover's hero treatment, for any line of type): a soft
/// umber shadow thrown down and away from the light, the leaf's dark depth on the shadow side and a bright rim on the
/// lit side, a face graded from a pale crown to an ochre foot, and faint brushed hollows in the leaf.
struct SAGilt: View {
    var text: Text
    var light: CoverLight
    /// Points of relief (1 for a hero numeral; less for small type).
    var depth: CGFloat = 1
    /// Toward the light (unit vector, y down): from the upper right, as the Matterhorn is lit.
    var toward = CGSize(width: 0.45, height: -0.89)

    var body: some View {
        let glyph = text.fixedSize()
        let to = toward
        glyph.hidden()
            .overlay {
                glyph.foregroundStyle(CoverInk.shadow)
                    .blur(radius: 5 * depth)
                    .offset(x: -to.width * 2.5 * depth, y: -to.height * 2.5 * depth + 1.5 * depth)
                    .opacity(0.75)
            }
            .overlay {
                glyph.foregroundStyle(light.glow)
                    .blur(radius: 10 * depth)
                    .opacity(light.isDay ? 0.22 : 0.16)
                    .blendMode(.screen)
            }
            .overlay {
                glyph.foregroundStyle(light.deep)
                    .offset(x: -to.width * 1.7 * depth, y: -to.height * 1.7 * depth)
            }
            .overlay {
                glyph.foregroundStyle(light.rim)
                    .offset(x: to.width * 0.7 * depth, y: to.height * 0.7 * depth)
            }
            .overlay {
                ZStack {
                    LinearGradient(stops: [.init(color: light.gild[0], location: 0.22), .init(color: light.gild[1], location: 0.55),
                                           .init(color: light.gild[2], location: 0.86)],
                                   startPoint: .top, endPoint: .bottom)
                    RadialGradient(colors: [light.rim.opacity(0.55), light.rim.opacity(0.12), .clear],
                                   center: UnitPoint(x: 0.75, y: 0.1), startRadius: 0, endRadius: 90 * depth)
                    Image("CoverGilt")
                        .resizable()
                        .renderingMode(.template)
                        .interpolation(.high)
                        .foregroundStyle(light.deep.opacity(0.2))
                }
                .compositingGroup()
                .mask(glyph)
            }
            .compositingGroup()
    }
}

enum SAWords {
    static func month(_ date: Date) -> String { CoverWords.month(date) }
    static func day(_ date: Date) -> String { CoverWords.day(date) }
    static func clock(_ date: Date) -> String { CoverWords.clock(date) }

    static func temp(_ w: WeatherSnapshot?) -> String { CoverWords.temp(w) }

    /// The temperature set for the gilt hero: Baskerville figures with a smaller degree ring raised to their top
    /// (Baskerville's own degree is nearly as tall as the figures). "—" when there is no weather.
    /// Three figures ("108", "-12") set a fifth smaller so they keep clear of the words beside them.
    static func tempText(_ w: WeatherSnapshot?, size: CGFloat) -> Text {
        guard let w else { return blank(size) }
        let figures = "\(Int(w.temperature.rounded()))"
        let s = figures.count >= 3 ? size * 0.8 : size
        return Text(figures).font(SAType.serif(s))
            + Text("°").font(SAType.serif(s * 0.56)).baselineOffset(s * 0.27)
    }

    /// A short gilt dash at the figures' mid-height, for a missing value (Baskerville's em dash at hero size is a bar).
    static func blank(_ size: CGFloat) -> Text {
        Text("–").font(SAType.serif(size)).baselineOffset(size * 0.1)
    }

    /// A count for the gilt numeral, or the short dash when it is unknown.
    static func numeral(_ count: Int?, size: CGFloat) -> Text {
        guard let count else { return blank(size) }
        return Text("\(count)").font(SAType.serif(count >= 100 ? size * 0.8 : size))
    }

    /// Today's sunrise or sunset moved onto the snapshot's day.
    static func today(_ d: Date, at now: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: cal.component(.hour, from: d), minute: cal.component(.minute, from: d), second: 0, of: now) ?? d
    }

    struct Foot { var rise: Bool; var time: String }

    /// The arc's feet: by day sunrise on the left and sunset on the right; by night sunset on the left (the night
    /// began there) and sunrise on the right.
    static func feet(_ snap: DaySnapshot, clock: SkyClock) -> (left: Foot, right: Foot)? {
        guard let w = snap.weather, let rise = w.sunrise, let set = w.sunset else { return nil }
        let r = Foot(rise: true, time: Self.clock(rise)), s = Foot(rise: false, time: Self.clock(set))
        return clock.isDay ? (r, s) : (s, r)
    }

    /// The next sun event: (sunrise?, "4:58", seconds until it).
    static func next(_ snap: DaySnapshot) -> (rise: Bool, time: String, wait: TimeInterval)? {
        guard let w = snap.weather, let rise = w.sunrise, let set = w.sunset else { return nil }
        let now = snap.date
        let r = today(rise, at: now), s = today(set, at: now)
        if now < r { return (true, clock(rise), r.timeIntervalSince(now)) }
        if now < s { return (false, clock(set), s.timeIntervalSince(now)) }
        return (true, clock(rise), r.addingTimeInterval(86_400).timeIntervalSince(now))
    }

    /// "7 h 17 m", "42 m".
    static func span(_ t: TimeInterval) -> String {
        let m = max(0, Int((t / 60).rounded()))
        return m >= 60 ? "\(m / 60) h \(m % 60) m" : "\(m) m"
    }

    /// The moon's phase in words.
    static func phase(_ p: MoonPhase) -> String {
        let f = p.fraction
        switch f {
        case ..<0.03, 0.97...: return "new moon"
        case ..<0.22: return "waxing crescent"
        case ..<0.28: return "first quarter"
        case ..<0.47: return "waxing gibbous"
        case ..<0.53: return "full moon"
        case ..<0.72: return "waning gibbous"
        case ..<0.78: return "last quarter"
        default: return "waning crescent"
        }
    }

    static func highLow(_ w: WeatherSnapshot) -> String {
        "high \(Int(w.high.rounded()))  ·  low \(Int(w.low.rounded()))"
    }

    static func condition(_ w: WeatherSnapshot) -> String { w.label.lowercased() }
}
