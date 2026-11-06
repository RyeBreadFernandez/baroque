import SwiftUI

// The Day widget as a storybook title page: the date medallion on the center axis, ringed by the daylight
// dial and standing on the summit of a symmetric range; weather and tasks set out on either side or below.

// MARK: - Geometry

/// Where things go on each size: the medallion and dial in points of the widget, the scenery in fractions of it,
/// so the ridges are always placed around the text.
struct MDDaySpec {
    var canvas: CGSize
    var crest: CGPoint          // medallion center
    var disc: CGFloat           // medallion radius
    var numeral: CGFloat
    var lettering: CGFloat
    var dial: CGFloat           // dial channel centerline radius
    var dialWidth: CGFloat
    var marker: CGFloat         // the "now" pebble
    var horizon: CGFloat
    var fade: ClosedRange<CGFloat>?
    var mist: (CGFloat, CGFloat, CGFloat)
    var ridges: [MountainLayer]
    var cloud: (x: CGFloat, y: CGFloat, w: CGFloat) // the left one; mirrored on the right
    var stars: [CGRect]         // open sky on the left, clear of text; mirrored on the right

    /// Width of each wing beside the dial, inside the 16pt content margin.
    var wing: CGFloat { crest.x - dial - dialWidth / 2 - 8 - 16 }

    static func of(_ size: BaroqueSize) -> MDDaySpec {
        typealias R = MDRidges
        switch size {
        case .large:
            return MDDaySpec(
                canvas: CGSize(width: 348, height: 365), crest: CGPoint(x: 174, y: 70),
                disc: 42, numeral: 42, lettering: 9.5, dial: 50, dialWidth: 8, marker: 12,
                horizon: 0.40, fade: 0.45...0.50, mist: (0.35, 0.42, 0.49),
                ridges: [
                    MountainLayer(profile: R.mirrored([(0, 0.415), (0.05, 0.398), (0.10, 0.372), (0.15, 0.352), (0.20, 0.37),
                                                       (0.26, 0.396), (0.32, 0.388), (0.38, 0.36), (0.44, 0.33), (0.5, 0.302)], seed: 11),
                                  top: R.far.top, bottom: R.far.bottom, rim: 0.6, snowline: 0.37),
                    MountainLayer(profile: R.mirrored([(0, 0.44), (0.08, 0.426), (0.16, 0.41), (0.24, 0.424), (0.32, 0.416),
                                                       (0.40, 0.40), (0.46, 0.41), (0.5, 0.418)], seed: 23),
                                  top: R.mid.top, bottom: R.mid.bottom, rim: 0.35, trees: Trees(height: 4...7, spacing: 5, coverage: 0.55)),
                    MountainLayer(profile: R.mirrored([(0, 0.462), (0.12, 0.452), (0.22, 0.458), (0.32, 0.445), (0.42, 0.452),
                                                       (0.5, 0.447)], seed: 31),
                                  top: R.near.top, bottom: R.near.bottom, rim: 0.25, trees: Trees(height: 6...10, spacing: 5, coverage: 0.8))
                ],
                cloud: (0.14, 0.31, 0.15),
                stars: [CGRect(x: 0.05, y: 0.025, width: 0.26, height: 0.065), CGRect(x: 0.04, y: 0.27, width: 0.2, height: 0.05)])
        case .medium:
            return MDDaySpec(
                canvas: CGSize(width: 348, height: 164), crest: CGPoint(x: 174, y: 76),
                disc: 38, numeral: 36, lettering: 9, dial: 46, dialWidth: 7, marker: 11,
                horizon: 0.72, fade: nil, mist: (0.62, 0.74, 0.84),
                ridges: [
                    MountainLayer(profile: R.mirrored([(0, 0.78), (0.07, 0.745), (0.15, 0.715), (0.23, 0.74), (0.31, 0.77),
                                                       (0.39, 0.735), (0.45, 0.69), (0.5, 0.665)], seed: 41),
                                  top: R.far.top, bottom: R.far.bottom, rim: 0.6, snowline: 0.715),
                    MountainLayer(profile: R.mirrored([(0, 0.85), (0.1, 0.83), (0.2, 0.815), (0.3, 0.83), (0.4, 0.812),
                                                       (0.5, 0.825)], seed: 43),
                                  top: R.mid.top, bottom: R.mid.bottom, rim: 0.35, trees: Trees(height: 4...7, spacing: 5, coverage: 0.55)),
                    MountainLayer(profile: R.mirrored([(0, 0.895), (0.15, 0.88), (0.3, 0.89), (0.42, 0.875), (0.5, 0.885)], seed: 47),
                                  top: R.near.top, bottom: R.near.bottom, rim: 0.25, trees: Trees(height: 6...10, spacing: 5, coverage: 0.8))
                ],
                cloud: (0.325, 0.665, 0.08), stars: [CGRect(x: 0.05, y: 0.05, width: 0.22, height: 0.1)])
        case .small:
            return MDDaySpec(
                canvas: CGSize(width: 164, height: 164), crest: CGPoint(x: 82, y: 63),
                disc: 36, numeral: 33, lettering: 9, dial: 42.5, dialWidth: 6, marker: 10,
                horizon: 0.66, fade: nil, mist: (0.58, 0.68, 0.78),
                ridges: [
                    MountainLayer(profile: R.mirrored([(0, 0.70), (0.1, 0.675), (0.2, 0.655), (0.28, 0.645), (0.36, 0.628),
                                                       (0.44, 0.605), (0.5, 0.59)], seed: 51),
                                  top: R.far.top, bottom: R.far.bottom, rim: 0.6, snowline: 0.655),
                    MountainLayer(profile: R.mirrored([(0, 0.76), (0.15, 0.742), (0.3, 0.752), (0.42, 0.735), (0.5, 0.745)], seed: 53),
                                  top: R.mid.top, bottom: R.mid.bottom, rim: 0.35, trees: Trees(height: 5...8, spacing: 6, coverage: 0.55)),
                    MountainLayer(profile: R.mirrored([(0, 0.83), (0.2, 0.815), (0.36, 0.825), (0.5, 0.81)], seed: 57),
                                  top: R.near.top, bottom: R.near.bottom, rim: 0.25, trees: Trees(height: 7...11, spacing: 6, coverage: 0.75))
                ],
                cloud: (0.14, 0.52, 0.22), stars: [CGRect(x: 0.05, y: 0.07, width: 0.16, height: 0.42)])
        }
    }
}

// MARK: - Widget

struct MDDay: View {
    var snapshot: DaySnapshot
    var size: BaroqueSize

    var body: some View {
        let spec = MDDaySpec.of(size)
        ZStack(alignment: .topLeading) {
            MDDayGround(snapshot: snapshot, spec: spec)
            MDCrest(snapshot: snapshot, spec: spec, showsTimes: size == .large)
            switch size {
            case .large: MDDayLarge(snapshot: snapshot, spec: spec)
            case .medium: MDDayMedium(snapshot: snapshot, spec: spec)
            case .small: MDDaySmall(snapshot: snapshot, spec: spec)
            }
        }
        .frame(width: spec.canvas.width, height: spec.canvas.height)
    }
}

/// The medallion with its dial and the sunrise and sunset times at the dial's ends.
struct MDCrest: View {
    var snapshot: DaySnapshot
    var spec: MDDaySpec
    var showsTimes: Bool

    var body: some View {
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let reach = (spec.dial + spec.marker) * 2 + 24
        let ends = MDDialTime.ends(clock: clock, weather: snapshot.weather)
        ZStack(alignment: .topLeading) {
            MDDial(clock: clock, phase: MoonPhase(date: snapshot.date), radius: spec.dial, width: spec.dialWidth, marker: spec.marker)
                .frame(width: reach, height: reach)
                .position(spec.crest)
            MDMedallion(date: snapshot.date, radius: spec.disc, numeral: spec.numeral, lettering: spec.lettering)
                .position(spec.crest)
            if showsTimes, snapshot.weather?.sunrise != nil {
                // Just below and outside each end of the horseshoe, beside the summit.
                let l = MDArc.point(0, center: spec.crest, radius: spec.dial)
                let r = MDArc.point(1, center: spec.crest, radius: spec.dial)
                ends.left.position(x: l.x - 10, y: l.y + 13)
                ends.right.position(x: r.x + 10, y: r.y + 13)
            }
        }
        .frame(width: spec.canvas.width, height: spec.canvas.height)
    }
}

// MARK: - Weather wings

private func temperature(_ w: WeatherSnapshot?) -> String { w.map { "\(Int($0.temperature.rounded()))°" } ?? "—" }

/// Left wing: the temperature in gold leaf over today's high and low.
struct MDTemperatureWing: View {
    var weather: WeatherSnapshot?
    var size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Text(temperature(weather))
                .font(Serif.font(size, weight: .semibold))
                .foregroundStyle(Gilt.style)
                .lineLimit(1)
                .fixedSize()
            if let w = weather {
                HighLow(high: w.high, low: w.low, size: 10.5)
                    .foregroundStyle(Stone.gold)
            } else {
                Text("No weather")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Stone.goldMuted)
            }
        }
        .legible()
    }
}

/// Right wing: the sky's glyph over the condition.
struct MDConditionWing: View {
    var weather: WeatherSnapshot?
    var glyph: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            WeatherGlyph(symbol: weather?.symbolName ?? "cloud.fill", size: glyph)
                .frame(height: glyph * 1.35)
            Text(weather?.label ?? "Unavailable")
                .font(Serif.font(14, weight: .medium, italic: true))
                .foregroundStyle(Stone.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let w = weather {
                Text("feels \(Int(w.apparent.rounded()))°")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Stone.goldMuted)
            }
        }
        .legible()
    }
}

// MARK: - Large

struct MDDayLarge: View {
    var snapshot: DaySnapshot
    var spec: MDDaySpec

    private let ruleY: CGFloat = 178

    var body: some View {
        let w = spec.canvas.width
        ZStack(alignment: .topLeading) {
            MDTemperatureWing(weather: snapshot.weather, size: 38)
                .frame(width: spec.wing)
                .position(x: 16 + spec.wing / 2, y: spec.crest.y - 6)
            MDConditionWing(weather: snapshot.weather, glyph: 27)
                .frame(width: spec.wing)
                .position(x: w - 16 - spec.wing / 2, y: spec.crest.y - 6)
            VStack(spacing: 7) {
                MDRule(width: 250, gap: 7) {
                    HStack(spacing: 7) {
                        MDSparkle(size: 8)
                        Text("Today")
                            .font(Serif.font(17, weight: .semibold))
                            .foregroundStyle(Stone.gold)
                            .legible()
                            .fixedSize()
                        MDSparkle(size: 8)
                    }
                }
                MDTaskPanel(tasks: snapshot.tasks, error: snapshot.taskError, maxRows: 5, now: snapshot.date)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .frame(width: w, height: spec.canvas.height - ruleY + 10, alignment: .top)
            .offset(y: ruleY - 10)
        }
        .frame(width: w, height: spec.canvas.height)
    }
}

/// Tasks on a raised slab under the heading: rows left-aligned for reading, the footer on the axis.
struct MDTaskPanel: View {
    var tasks: [TaskItem]
    var error: String?
    var maxRows: Int
    var now: Date

    private var shown: Int { min(tasks.count, maxRows) }

    var body: some View {
        VStack(spacing: 0) {
            if tasks.isEmpty {
                Spacer(minLength: 0)
                empty
                Spacer(minLength: 0)
            } else {
                // Rows share the height up to a comfortable pitch; a short list sits in the middle of the slab.
                Spacer(minLength: 0)
                ForEach(Array(tasks.prefix(shown).enumerated()), id: \.element.id) { i, t in
                    TaskRow(task: t, compact: false)
                        .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 30)
                        .overlay(alignment: .top) {
                            if i > 0 { EngravedRule().padding(.leading, 22) }
                        }
                }
                Spacer(minLength: 0)
                if tasks.count > shown || error != nil {
                    VStack(spacing: 2) {
                        if tasks.count > shown {
                            HStack(spacing: 6) {
                                MDHairline(fadesLeading: true, strength: 0.5).frame(width: 22)
                                Text("+\(tasks.count - shown) more")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Stone.goldFaint)
                                    .fixedSize()
                                MDHairline(fadesLeading: false, strength: 0.5).frame(width: 22)
                            }
                        }
                        if let error {
                            // Cached tasks are still shown above; say why they may be stale.
                            MDErrorLine(message: error, prefix: "Cached", color: Stone.copperInk)
                        }
                    }
                    .padding(.top, 3)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .stoneSlab(.panel, radius: 18, depth: 3)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: error == nil ? "checkmark" : "exclamationmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(error == nil ? Stone.sage : Stone.copperInk)
                .raised()
                .frame(width: 36, height: 36)
                .carved(Circle())
            Text(error == nil ? "Nothing due. Nice." : "Couldn't load tasks")
                .font(Serif.font(15, weight: .semibold))
                .foregroundStyle(Stone.gold)
                .raised()
            if let error {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Stone.copperInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Medium

struct MDDayMedium: View {
    var snapshot: DaySnapshot
    var spec: MDDaySpec

    var body: some View {
        let w = spec.canvas.width
        ZStack(alignment: .topLeading) {
            MDGroundWeather(weather: snapshot.weather)
                .frame(width: spec.wing)
                .position(x: 16 + spec.wing / 2, y: spec.crest.y + 2)
            MDWingTasks(tasks: snapshot.tasks, error: snapshot.taskError, now: snapshot.date)
                .frame(width: spec.wing)
                .position(x: w - 16 - spec.wing / 2, y: spec.crest.y + 4)
        }
        .frame(width: w, height: spec.canvas.height)
    }
}

/// The medium's weather wing, centered: glyph and temperature, the condition, high and low.
struct MDGroundWeather: View {
    var weather: WeatherSnapshot?

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 5) {
                WeatherGlyph(symbol: weather?.symbolName ?? "cloud.fill", size: 15)
                Text(temperature(weather))
                    .font(Serif.font(30, weight: .semibold))
                    .foregroundStyle(Gilt.style)
                    .lineLimit(1)
                    .fixedSize()
            }
            Text(weather?.label ?? "Unavailable")
                .font(Serif.font(13, weight: .medium, italic: true))
                .foregroundStyle(Stone.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let w = weather {
                HighLow(high: w.high, low: w.low, size: 10)
                    .foregroundStyle(Stone.gold)
                    .padding(.top, 1)
            }
        }
        .legible()
    }
}

/// The medium's task wing, written on the scene like the weather opposite: the heading and count on the axis
/// of the wing, then the first two tasks (titles may wrap once) in sockets carved into the paint.
struct MDWingTasks: View {
    var tasks: [TaskItem]
    var error: String?
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Today")
                    .font(Serif.font(15, weight: .semibold))
                    .foregroundStyle(Stone.gold)
                    .legible()
                if !tasks.isEmpty { CountPill(count: tasks.count) }
            }
            .frame(maxWidth: .infinity)
            if tasks.isEmpty {
                Group {
                    if let error {
                        MDNote(symbol: "exclamationmark.triangle.fill", text: error, color: Stone.copperInk)
                    } else {
                        MDNote(symbol: "checkmark.circle", text: "Nothing due. Nice.", color: Stone.parchment, iconColor: Stone.sage)
                    }
                }
                .legible()
            } else {
                ForEach(tasks.prefix(2), id: \.id) { t in
                    MDWingRow(task: t, now: now)
                }
                if let error {
                    ErrorLine(message: error, prefix: "Cached", color: Stone.copperInk, fontSize: 9.5)
                        .legible()
                } else if tasks.count > 2 {
                    Text("+\(tasks.count - 2) more")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Stone.goldMuted)
                        .legible()
                        .padding(.leading, 18)
                }
            }
        }
    }
}

/// A task in a narrow column: socket, a title that may wrap once, and how late it is.
struct MDWingRow: View {
    var task: TaskItem
    var now: Date

    private var accent: Color {
        if task.isOverdue { return Stone.copperLight }
        if task.priority >= .high { return Stone.gold }
        return Stone.sage
    }

    private var late: String? {
        guard task.isOverdue, let due = task.due else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: due), to: cal.startOfDay(for: now)).day ?? 1
        return "\(max(1, days))d late"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            TaskSocket(accent: accent, size: 12)
                .padding(.top, 1.5)
            VStack(alignment: .leading, spacing: 1) {
                Text(task.text)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Stone.parchment)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let late {
                    Text(late)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Stone.copperInk)
                }
            }
            .legible()
        }
    }
}

/// A short note with an icon (empty and error states in narrow places).
struct MDNote: View {
    var symbol: String
    var text: String
    var color: Color
    var iconColor: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(iconColor ?? color)
            Text(text)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(color)
    }
}

// MARK: - Small

struct MDDaySmall: View {
    var snapshot: DaySnapshot
    var spec: MDDaySpec

    var body: some View {
        let w = spec.canvas.width
        let rowY: CGFloat = snapshot.taskError == nil ? 125 : 117
        ZStack(alignment: .topLeading) {
            HStack(spacing: 7) {
                WeatherGlyph(symbol: snapshot.weather?.symbolName ?? "cloud.fill", size: 14)
                Text(temperature(snapshot.weather))
                    .font(Serif.font(24, weight: .semibold))
                    .foregroundStyle(Gilt.style)
                    .lineLimit(1)
                    .fixedSize()
                MDCountPebble(count: snapshot.tasks.count, failed: snapshot.taskError != nil)
            }
            .legible()
            .position(x: w / 2, y: rowY)
            if let error = snapshot.taskError {
                MDErrorLine(message: error, color: Stone.copperInk, fontSize: 9.5)
                    .legible()
                    .frame(width: w - 32)
                    .position(x: w / 2, y: 140)
            }
        }
        .frame(width: w, height: spec.canvas.height)
    }
}

/// The task count as a copper pebble: a checklist mark and the number; a check when nothing is due.
struct MDCountPebble: View {
    var count: Int
    var failed: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: failed ? "exclamationmark" : (count == 0 ? "checkmark" : "checklist"))
                .font(.system(size: 8.5, weight: .bold))
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(Stone.parchment)
        .raised()
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(minWidth: 22)
        .background(Pebble(shape: Capsule()))
        .accessibilityLabel(count == 0 ? "Nothing due" : "\(count) tasks")
    }
}

// MARK: - Ground

/// The Day widget's scenery: the painted sky for the time and weather, a glow behind the medallion,
/// mirrored clouds, the symmetric range, valley mist, rain or snow, and the gold frame.
struct MDDayGround: View {
    var snapshot: DaySnapshot
    var spec: MDDaySpec

    var body: some View {
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let condition = SkyCondition(code: snapshot.weather?.code)
        let night = !clock.isDay
        let small = spec.canvas.width < 200
        PaintedSky(palette: SkyPalette(clock: clock, condition: condition), horizon: spec.horizon)
            .overlay {
                if night && !condition.gray {
                    ZStack {
                        ForEach(Array(spec.stars.enumerated()), id: \.offset) { i, r in
                            Stars(region: r, count: small ? 4 : 5, sparkles: 1, seed: 5 + UInt64(i))
                            Stars(region: mirror(r), count: small ? 4 : 5, sparkles: 1, seed: 13 + UInt64(i))
                        }
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                // The medallion stands in its own light, like the sun or moon over the summit.
                Circle()
                    .fill(RadialGradient(colors: [(night ? Stone.moonlight : Stone.goldBright).opacity(condition.gray ? 0.08 : 0.16), .clear],
                                         center: .center, startRadius: spec.disc, endRadius: spec.dial * 1.9))
                    .frame(width: spec.dial * 3.8, height: spec.dial * 3.8)
                    .position(spec.crest)
            }
            .overlay { MDClouds(spec: spec, condition: condition, night: night) }
            .overlay(MountainRange(layers: spec.ridges, night: night, snowLower: condition == .snow ? 0.02 : 0, fade: spec.fade))
            .overlay(mist(night: night))
            .overlay { MDPrecipitation(spec: spec, condition: condition) }
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.32), .clear], center: UnitPoint(x: 0.5, y: 1.08),
                                    startRadius: 0, endRadius: spec.canvas.width * 0.8))
            .overlay(GoldFrame(inset: 6, ornament: false))
            .overlay(SlabBevel())
    }

    private func mirror(_ r: CGRect) -> CGRect { CGRect(x: 1 - r.maxX, y: r.minY, width: r.width, height: r.height) }

    private func mist(night: Bool) -> some View {
        let haze = night ? Color(hex: 0x6F8380) : Color(hex: 0xA9B5A4)
        return LinearGradient(stops: [
            .init(color: haze.opacity(0), location: spec.mist.0),
            .init(color: haze.opacity(0.24), location: spec.mist.1),
            .init(color: haze.opacity(0), location: spec.mist.2)
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }
}

/// A pair of clouds, mirrored about the axis, over the side peaks (fog draws banks at the ridge foot instead).
struct MDClouds: View {
    var spec: MDDaySpec
    var condition: SkyCondition
    var night: Bool

    static func spots(_ spec: MDDaySpec, _ condition: SkyCondition) -> [(center: CGPoint, width: CGFloat)] {
        let c = spec.cloud
        let s = spec.canvas
        let scale: CGFloat
        switch condition {
        case .clear, .fog: return []
        case .partly: scale = 0.75
        default: scale = 1
        }
        return [c.x, 1 - c.x].map { x in (CGPoint(x: x * s.width, y: c.y * s.height), c.w * s.width * scale) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(Self.spots(spec, condition).enumerated()), id: \.offset) { i, c in
                PaintedCloud(night: night, gray: condition.gray, seed: i)
                    .frame(width: c.width, height: c.width * 0.55)
                    .scaleEffect(x: i == 1 ? -1 : 1, y: 1)
                    .position(c.center)
            }
        }
        .frame(width: spec.canvas.width, height: spec.canvas.height)
        .allowsHitTesting(false)
    }
}

/// Rain, snow or fog in front of the ridges, from the mirrored clouds.
struct MDPrecipitation: View {
    var spec: MDDaySpec
    var condition: SkyCondition

    var body: some View {
        let clouds = MDClouds.spots(spec, condition)
        let u = spec.canvas.width / 348
        ZStack(alignment: .topLeading) {
            switch condition {
            case .rain, .storm:
                Canvas { ctx, _ in
                    for c in clouds {
                        let count = Int(c.width / (5 * u))
                        for i in 0..<count {
                            let x = c.center.x - c.width * 0.36 + CGFloat(i) * 5 * u + (i % 2 == 0 ? 0 : 1.5 * u)
                            let y = c.center.y + c.width * 0.26 + (i % 2 == 0 ? 0 : 4 * u)
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: y))
                            p.addLine(to: CGPoint(x: x - 2.5 * u, y: y + 9 * u))
                            ctx.stroke(p, with: .color(Color(hex: 0xA9BDB6).opacity(0.7)),
                                       style: StrokeStyle(lineWidth: 1.1 * u, lineCap: .round, dash: [3 * u, 2.5 * u]))
                        }
                    }
                }
            case .snow:
                Canvas { ctx, _ in
                    var rng = SeededRandom(9)
                    for c in clouds {
                        for _ in 0..<8 {
                            let x = c.center.x + CGFloat(rng.signed()) * c.width * 0.4
                            let y = c.center.y + c.width * 0.3 + CGFloat(rng.next()) * 16 * u
                            let r = (1.0 + CGFloat(rng.next()) * 0.7) * u
                            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Stone.moonlight))
                        }
                    }
                }
            case .fog:
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(Color(hex: 0xA7B6AE).opacity(0.42))
                        .frame(width: spec.canvas.width * (0.42 + 0.12 * CGFloat(i)), height: 5 * u)
                        .blur(radius: 2.5 * u)
                        .position(x: spec.canvas.width / 2, y: spec.canvas.height * spec.mist.1 - CGFloat(4 + 8 * i) * u)
                }
            default:
                EmptyView()
            }
        }
        .frame(width: spec.canvas.width, height: spec.canvas.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
