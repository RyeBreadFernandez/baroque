import SwiftUI

// Panorama: every widget is one painted scene, edge to edge. The date and weather are written into its sky,
// the day is the sun's arc across it (sunrise at the left foot, sunset at the right, the sun at "now"),
// and tasks or the quote are written as captions on the dark valley floor in front of the near ridge.
// All placements are fractions of the widget, like the shipped Landscape.

// MARK: - Plan

/// Where the scene's parts sit in one widget, as fractions of its size.
struct PNPlan {
    /// The sun's (or moon's) path: its feet stand on `horizon`.
    var arc: SkyArc
    /// The PaintedSky horizon stop (the warm haze), kept behind the far ridges.
    var skyHorizon: CGFloat
    /// Top of the caption ground: tasks or the quote are written below this line.
    var ground: CGFloat
    /// Open sky clear of text, for stars at night.
    var stars: CGRect
    var starCount: Int
    var sparkles: Int
    /// Sun radius in points (the moon is drawn a little larger).
    var bodyRadius: CGFloat
    /// The dotted path and the feet times; off on the small widget, which only shows the sun.
    var showsTrail: Bool
    /// Height left clear above each foot for its time label.
    var footClearance: CGFloat

    static func day(_ family: Family) -> PNPlan {
        switch family {
        case .large:
            // The arc spans nearly the full width; date and weather sit in the corners above its shoulders.
            return PNPlan(arc: arc(left: 0.09, right: 0.91, horizon: 0.525, apex: 0.235),
                          skyHorizon: 0.56, ground: 0.622,
                          stars: CGRect(x: 0.44, y: 0.04, width: 0.26, height: 0.16), starCount: 14, sparkles: 2,
                          bodyRadius: 9.5, showsTrail: true, footClearance: 17)
        case .medium:
            // Date on the left, weather on the right, the arc over the peaks between them.
            return PNPlan(arc: arc(left: 0.385, right: 0.715, horizon: 0.405, apex: 0.10),
                          skyHorizon: 0.46, ground: 0.53,
                          stars: CGRect(x: 0.43, y: 0.16, width: 0.26, height: 0.12), starCount: 6, sparkles: 1,
                          bodyRadius: 7, showsTrail: true, footClearance: 15)
        case .small:
            return PNPlan(arc: arc(left: 0.33, right: 0.67, horizon: 0.50, apex: 0.29),
                          skyHorizon: 0.54, ground: 0.655,
                          stars: CGRect(x: 0.38, y: 0.2, width: 0.26, height: 0.1), starCount: 5, sparkles: 1,
                          bodyRadius: 6.5, showsTrail: false, footClearance: 0)
        }
    }

    static func quote(_ family: Family) -> PNPlan {
        // The quote's sky has no sun; `arc` only sets where the moon rides.
        switch family {
        case .large:
            return PNPlan(arc: arc(left: 0.5, right: 0.9, horizon: 0.42, apex: 0.15),
                          skyHorizon: 0.5, ground: 0.632,
                          stars: CGRect(x: 0.05, y: 0.05, width: 0.58, height: 0.17), starCount: 16, sparkles: 3,
                          bodyRadius: 17, showsTrail: false, footClearance: 0)
        case .medium:
            return PNPlan(arc: arc(left: 0.6, right: 0.92, horizon: 0.36, apex: 0.19),
                          skyHorizon: 0.42, ground: 0.555,
                          stars: CGRect(x: 0.05, y: 0.08, width: 0.5, height: 0.18), starCount: 10, sparkles: 2,
                          bodyRadius: 11, showsTrail: false, footClearance: 0)
        case .small:
            return PNPlan(arc: arc(left: 0.55, right: 0.9, horizon: 0.34, apex: 0.2),
                          skyHorizon: 0.42, ground: 0.575,
                          stars: CGRect(x: 0.08, y: 0.08, width: 0.45, height: 0.16), starCount: 6, sparkles: 1,
                          bodyRadius: 8.5, showsTrail: false, footClearance: 0)
        }
    }

    private static func arc(left: CGFloat, right: CGFloat, horizon: CGFloat, apex: CGFloat) -> SkyArc {
        SkyArc(centerX: (left + right) / 2, horizon: horizon, radiusX: (right - left) / 2, radiusY: horizon - apex)
    }
}

// MARK: - Ridges

/// A ridge plus how its brushwork sits: the shipped MountainRange picks the relief's flip and offset from the
/// layer's index, which lands the texture's brightest patch on whichever ridge is third; the panorama writes on
/// the near ridge, so each layer chooses its own.
struct PNLayer {
    var layer: MountainLayer
    var relief: Double = 0.9
    var flip: Bool = false
    var shift: CGFloat = 0 // points the relief is moved down
}

/// The shipped MountainRange (far to near, each ridge lifted off the one behind by a soft shadow, rim light on
/// the crest, spruce, snow) with per-layer relief.
struct PNRange: View {
    var layers: [PNLayer]
    var night: Bool = false
    var snowLower: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(layers.indices, id: \.self) { i in
                layerView(layers[i])
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func layerView(_ item: PNLayer) -> some View {
        let layer = item.layer
        let ridge = RidgeShape(profile: layer.profile)
        let rimColor = night ? Color(hex: 0xD8E0D2) : Stone.goldBright
        return ZStack {
            ridge.fill(LinearGradient(colors: [layer.top, layer.bottom], startPoint: .top, endPoint: .bottom))
            if let line = layer.snowline {
                SnowShape(profile: layer.profile, snowline: line + snowLower)
                    .fill(LinearGradient(colors: night ? [Color(hex: 0xC9CDBF), Color(hex: 0x7E8A84)] : [Color(hex: 0xF0E2C0), Color(hex: 0xA9AC98)],
                                         startPoint: .top, endPoint: .bottom))
            }
            PaintRelief(name: "PaintRidge", opacity: item.relief, flip: item.flip)
                .offset(y: item.shift)
                .clipShape(ridge)
            if let trees = layer.trees {
                TreeLine(profile: layer.profile, trees: trees)
                    .fill(layer.top)
                    .overlay(TreeLine(profile: layer.profile, trees: trees).stroke(rimColor.opacity(layer.rim * 0.35), lineWidth: 0.5))
            }
            RidgeShape(profile: layer.profile, closed: false)
                .stroke(rimColor.opacity(layer.rim), style: StrokeStyle(lineWidth: 0.9, lineJoin: .round))
                .blur(radius: 0.3)
            if night {
                ridge.fill(Color(hex: 0x0A1220).opacity(0.32))
            }
        }
        .compositingGroup()
        .shadow(color: Stone.shadow.opacity(0.5), radius: 3, x: 0, y: -1.2)
    }
}

// Ridge key points per widget. Ridges stay low under the date, the weather and the arc's feet, rise into the
// open sky under the arc, and the nearest ridge becomes the dark valley floor the captions are written on.
// The near ridge takes the relief's darkest rows (shift 0 on large and small, flipped and lowered on medium)
// so the captions sit on quiet paint.
enum PNRidges {
    static func day(_ family: Family) -> [PNLayer] {
        let far = Ridges.far, mid = Ridges.mid, near = Ridges.near
        switch family {
        case .large:
            return [
                // A main peak right of centre with a lower summit beside it and a shoulder, under the arc's crown;
                // low at both ends so the feet times stand clear.
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.552), p(0.07, 0.542), p(0.135, 0.548), p(0.17, 0.522), p(0.2, 0.514), p(0.23, 0.522),
                    p(0.26, 0.5), p(0.3, 0.462),
                    p(0.34, 0.43), p(0.38, 0.398), p(0.41, 0.374), p(0.445, 0.396), p(0.48, 0.382), p(0.52, 0.342),
                    p(0.56, 0.305), p(0.6, 0.33), p(0.635, 0.362), p(0.67, 0.39), p(0.7, 0.402), p(0.74, 0.45),
                    p(0.775, 0.49), p(0.8, 0.508), p(0.83, 0.502), p(0.86, 0.535), p(0.9, 0.546), p(0.95, 0.54),
                    p(1, 0.55)], seed: 211, roughness: 0.16),
                    top: far.top, bottom: far.bottom, rim: 0.6, snowline: 0.405), relief: 0.85, flip: true),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.566), p(0.08, 0.556), p(0.15, 0.546), p(0.22, 0.528), p(0.3, 0.54), p(0.38, 0.522),
                    p(0.46, 0.534), p(0.54, 0.51), p(0.62, 0.53), p(0.7, 0.522), p(0.78, 0.545), p(0.86, 0.556),
                    p(0.94, 0.56), p(1, 0.565)], seed: 223),
                    top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 4...7, spacing: 5, coverage: 0.6)),
                    flip: true, shift: 23),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.594), p(0.12, 0.586), p(0.24, 0.592), p(0.36, 0.578), p(0.48, 0.588), p(0.6, 0.574),
                    p(0.72, 0.586), p(0.86, 0.58), p(1, 0.59)], seed: 227),
                    top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 6...10, spacing: 5, coverage: 0.8)),
                    relief: 0.8)
            ]
        case .medium:
            return [
                // The massif fills the arc between its feet; low under the date, the feet and the weather.
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.45), p(0.08, 0.438), p(0.17, 0.448), p(0.27, 0.435), p(0.33, 0.445), p(0.43, 0.44),
                    p(0.46, 0.415), p(0.49, 0.375), p(0.515, 0.335), p(0.535, 0.32), p(0.555, 0.302), p(0.58, 0.258),
                    p(0.6, 0.218), p(0.62, 0.252), p(0.64, 0.30), p(0.66, 0.362), p(0.682, 0.425), p(0.72, 0.442), p(0.78, 0.44),
                    p(0.84, 0.43), p(0.9, 0.405), p(0.95, 0.418), p(1, 0.43)], seed: 241, roughness: 0.14),
                    top: far.top, bottom: far.bottom, rim: 0.6, snowline: 0.33)),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.478), p(0.1, 0.465), p(0.22, 0.474), p(0.34, 0.455), p(0.46, 0.47), p(0.58, 0.445),
                    p(0.7, 0.465), p(0.82, 0.45), p(0.92, 0.465), p(1, 0.46)], seed: 243, roughness: 0.25),
                    top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 4...6, spacing: 5, coverage: 0.5)),
                    flip: true, shift: 23),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.505), p(0.15, 0.495), p(0.3, 0.503), p(0.45, 0.49), p(0.6, 0.5), p(0.75, 0.487),
                    p(0.9, 0.498), p(1, 0.49)], seed: 247, roughness: 0.3),
                    top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 5...9, spacing: 5, coverage: 0.8)),
                    relief: 0.8, flip: true, shift: 115)
            ]
        case .small:
            return [
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.50), p(0.1, 0.485), p(0.2, 0.46), p(0.3, 0.43), p(0.38, 0.41), p(0.46, 0.385),
                    p(0.53, 0.35), p(0.6, 0.39), p(0.68, 0.37), p(0.76, 0.415), p(0.86, 0.45), p(1, 0.47)], seed: 251),
                    top: far.top, bottom: far.bottom, rim: 0.6, snowline: 0.415)),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.55), p(0.2, 0.525), p(0.4, 0.545), p(0.55, 0.505), p(0.7, 0.53), p(0.85, 0.505), p(1, 0.53)], seed: 253),
                    top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 5...8, spacing: 5.5, coverage: 0.5)),
                    flip: true, shift: 23),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.612), p(0.25, 0.592), p(0.5, 0.607), p(0.75, 0.588), p(1, 0.602)], seed: 257),
                    top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 7...11, spacing: 5.5, coverage: 0.75)),
                    relief: 0.8)
            ]
        }
    }

    // The quote's vista: tall snowy peaks across the sky, a forested middle range, then the valley floor.
    static func quote(_ family: Family) -> [PNLayer] {
        let far = (top: Color(hex: 0x5C6E69), bottom: Color(hex: 0x3A4B47))
        let mid = (top: Color(hex: 0x2F3F3A), bottom: Color(hex: 0x23312C))
        let near = (top: Color(hex: 0x151E1A), bottom: Color(hex: 0x0D1310))
        switch family {
        case .large:
            return [
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.40), p(0.06, 0.37), p(0.12, 0.322), p(0.17, 0.34), p(0.23, 0.272), p(0.28, 0.222),
                    p(0.33, 0.252), p(0.38, 0.30), p(0.44, 0.338), p(0.5, 0.31), p(0.56, 0.352), p(0.62, 0.40),
                    p(0.68, 0.428), p(0.75, 0.40), p(0.82, 0.362), p(0.88, 0.382), p(0.94, 0.418), p(1, 0.41)], seed: 311, roughness: 0.18),
                    top: far.top, bottom: far.bottom, rim: 0.55, snowline: 0.335)),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.50), p(0.1, 0.472), p(0.2, 0.49), p(0.3, 0.452), p(0.4, 0.478), p(0.52, 0.432),
                    p(0.6, 0.458), p(0.7, 0.49), p(0.8, 0.462), p(0.9, 0.48), p(1, 0.47)], seed: 313),
                    top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 4...7, spacing: 4.5, coverage: 0.6)),
                    flip: true, shift: 23),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.588), p(0.15, 0.576), p(0.3, 0.586), p(0.45, 0.57), p(0.6, 0.582), p(0.75, 0.566),
                    p(0.9, 0.578), p(1, 0.572)], seed: 317),
                    top: near.top, bottom: near.bottom, rim: 0.2, trees: Trees(height: 6...11, spacing: 5, coverage: 0.8)),
                    relief: 0.8)
            ]
        case .medium:
            return [
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.36), p(0.07, 0.30), p(0.13, 0.245), p(0.18, 0.28), p(0.25, 0.205), p(0.31, 0.155),
                    p(0.37, 0.21), p(0.44, 0.27), p(0.5, 0.32), p(0.57, 0.29), p(0.64, 0.34), p(0.72, 0.38),
                    p(0.8, 0.36), p(0.88, 0.315), p(0.94, 0.35), p(1, 0.34)], seed: 341, roughness: 0.16),
                    top: far.top, bottom: far.bottom, rim: 0.55, snowline: 0.29)),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.435), p(0.12, 0.40), p(0.25, 0.428), p(0.38, 0.39), p(0.5, 0.418), p(0.62, 0.38),
                    p(0.75, 0.415), p(0.88, 0.395), p(1, 0.41)], seed: 343, roughness: 0.25),
                    top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 4...6, spacing: 4.5, coverage: 0.6)),
                    flip: true, shift: 23),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.505), p(0.2, 0.488), p(0.4, 0.502), p(0.6, 0.478), p(0.8, 0.495), p(1, 0.482)], seed: 347, roughness: 0.3),
                    top: near.top, bottom: near.bottom, rim: 0.2, trees: Trees(height: 5...9, spacing: 5, coverage: 0.8)),
                    relief: 0.8, flip: true, shift: 115)
            ]
        case .small:
            return [
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.36), p(0.1, 0.30), p(0.2, 0.25), p(0.3, 0.29), p(0.42, 0.205), p(0.5, 0.17),
                    p(0.58, 0.22), p(0.68, 0.30), p(0.8, 0.34), p(0.9, 0.31), p(1, 0.335)], seed: 351, roughness: 0.16),
                    top: far.top, bottom: far.bottom, rim: 0.55, snowline: 0.285)),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.43), p(0.2, 0.40), p(0.4, 0.428), p(0.6, 0.39), p(0.8, 0.42), p(1, 0.40)], seed: 353, roughness: 0.25),
                    top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 5...8, spacing: 5, coverage: 0.55)),
                    flip: true, shift: 23),
                PNLayer(layer: MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.522), p(0.25, 0.502), p(0.5, 0.518), p(0.75, 0.495), p(1, 0.51)], seed: 357, roughness: 0.3),
                    top: near.top, bottom: near.bottom, rim: 0.2, trees: Trees(height: 7...11, spacing: 5.5, coverage: 0.75)),
                    relief: 0.8)
            ]
        }
    }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}

// MARK: - Sky

/// The day as a line across the sky: already travelled in gilt from the left foot to the sun,
/// still to come as gold dots down to the right foot. The trail stops short of the horizon to leave
/// room for the time written at each foot.
struct PNArcTrail: View {
    var arc: SkyArc
    var progress: Double
    var footClearance: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let ry = arc.radiusY * size.height
            let p0 = ry > footClearance ? asin(Double(footClearance / ry)) / Double.pi : 0
            let now = min(max(progress, p0), 1 - p0)
            func path(_ a: Double, _ b: Double) -> Path {
                var p = Path()
                guard b > a else { return p }
                let steps = max(2, Int((b - a) * 72))
                for i in 0...steps {
                    let pt = arc.point(a + (b - a) * Double(i) / Double(steps), in: size)
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                return p
            }
            ctx.stroke(path(now, 1 - p0), with: .color(Stone.gold.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 1.25, lineCap: .round, dash: [0.1, 4.2]))
            let from = arc.point(p0, in: size), to = arc.point(now, in: size)
            ctx.stroke(path(p0, now),
                       with: .linearGradient(Gradient(colors: [Stone.gold.opacity(0.22), Stone.goldBright.opacity(0.8)]),
                                             startPoint: from, endPoint: to),
                       style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Behind the ridges: light spreading round the sun or moon, the day's trail, the body itself, and clouds.
/// A copy of the shipped SkyBack with the travelled/remaining trail and sizes in points.
struct PNSkyBack: View {
    var clock: SkyClock
    var condition: SkyCondition
    var arc: SkyArc
    var phase: MoonPhase
    var plan: PNPlan

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let pos = arc.point(clock.progress, in: size)
            let r = plan.bodyRadius
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(RadialGradient(colors: [(clock.isDay ? Stone.goldBright : Stone.moonlight).opacity(condition.gray ? 0.08 : 0.17), .clear],
                                         center: .center, startRadius: 0, endRadius: r * 8))
                    .frame(width: r * 16, height: r * 16)
                    .position(pos)
                if plan.showsTrail {
                    PNArcTrail(arc: arc, progress: clock.progress, footClearance: plan.footClearance)
                }
                Group {
                    if clock.isDay {
                        SunDisc(radius: r).opacity(condition.gray ? 0.5 : 1)
                    } else {
                        MoonDisc(radius: r * 1.12, phase: phase).opacity(condition.gray ? 0.6 : 1)
                    }
                }
                .position(pos)
                ForEach(Array(SkyLayout.clouds(condition, clock: clock, arc: arc, size: size).enumerated()), id: \.offset) { i, c in
                    PaintedCloud(night: !clock.isDay, gray: condition.gray, seed: i)
                        .frame(width: c.width, height: c.width * 0.55)
                        .position(c.center)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The time written at each foot of the arc: sunrise on the left and sunset on the right by day;
/// by night the arc is tonight, from sunset to tomorrow's sunrise. When the sun (or moon) is down at a foot,
/// that time slides inward beside it instead of sitting under it. Hidden when the weather (and so the sun
/// times) is missing.
struct PNArcFeet: View {
    var plan: PNPlan
    var clock: SkyClock
    var weather: WeatherSnapshot?
    var fontSize: CGFloat

    var body: some View {
        GeometryReader { geo in
            if let rise = weather?.sunrise, let set = weather?.sunset {
                let size = geo.size
                let arc = plan.arc
                let l = arc.point(0, in: size), r = arc.point(1, in: size)
                let body = arc.point(clock.progress, in: size)
                let radius = plan.bodyRadius * (clock.isDay ? 1 : 1.12)
                let (a, b) = clock.isDay ? (rise, set) : (set, rise)
                let y = l.y - fontSize * 0.62
                let w = fontSize * 3.2
                let nearY = abs(body.y - y) < radius + fontSize * 0.7
                let nearLeft = nearY && abs(body.x - l.x) < radius + w / 2
                let nearRight = nearY && abs(body.x - r.x) < radius + w / 2
                label(a, sunrise: clock.isDay)
                    .frame(width: w, alignment: nearLeft ? .leading : .center)
                    .position(x: nearLeft ? body.x + radius + 4 + w / 2 : l.x, y: y)
                label(b, sunrise: !clock.isDay)
                    .frame(width: w, alignment: nearRight ? .trailing : .center)
                    .position(x: nearRight ? body.x - radius - 4 - w / 2 : r.x, y: y)
            }
        }
        .allowsHitTesting(false)
    }

    private func label(_ time: Date, sunrise: Bool) -> some View {
        Text(time, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
            .font(Serif.font(fontSize, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(Stone.goldBright)
            .legible(1.3)
            .fixedSize()
            .accessibilityLabel(Text(sunrise ? "Sunrise" : "Sunset"))
    }
}

// MARK: - Grounds

/// The valley floor darkens toward the bottom of the widget so captions read on it; laid over the near
/// ridge's brushwork, never instead of it.
struct PNFloorShade: View {
    var top: CGFloat
    var strength: Double = 0.42

    var body: some View {
        LinearGradient(stops: [
            .init(color: Stone.shadow.opacity(0), location: max(0, top - 0.05)),
            .init(color: Stone.shadow.opacity(strength * 0.7), location: min(1, top + 0.08)),
            .init(color: Stone.shadow.opacity(strength), location: 1)
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }
}

/// A soft haze lying over the bases of the far and middle ridges.
struct PNMist: View {
    var center: CGFloat
    var spread: CGFloat
    var night: Bool
    var strength: Double = 0.24

    var body: some View {
        let haze = night ? Color(hex: 0x6F8380) : Color(hex: 0xA9B5A4)
        LinearGradient(stops: [
            .init(color: haze.opacity(0), location: center - spread),
            .init(color: haze.opacity(strength), location: center),
            .init(color: haze.opacity(0), location: center + spread * 0.7)
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }
}

/// The sky deepens toward the two top corners, where the date and the weather are written, so gold reads over
/// the sky's lighter strokes. Laid under the sun's light, which still spreads over it.
struct PNCornerShade: View {
    var family: Family

    var body: some View {
        let radius: CGFloat = family == .large ? 140 : (family == .medium ? 105 : 80)
        let y: CGFloat = family == .large ? 0.1 : 0.2
        ZStack {
            RadialGradient(colors: [Stone.night.opacity(0.5), Stone.night.opacity(0)],
                           center: UnitPoint(x: family == .small ? 0.15 : 0.12, y: y), startRadius: 0, endRadius: radius)
            RadialGradient(colors: [Stone.night.opacity(0.45), Stone.night.opacity(0)],
                           center: UnitPoint(x: family == .small ? 0.85 : 0.9, y: y), startRadius: 0, endRadius: radius * 0.8)
        }
        .allowsHitTesting(false)
    }
}

/// The Day widget's whole picture: the live sky, the arc of today, ridges, mist and the dark valley floor.
struct PNDayGround: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        let plan = PNPlan.day(family)
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let condition = SkyCondition(code: snapshot.weather?.code)
        let phase = MoonPhase(date: snapshot.date)
        let mistAt: CGFloat = family == .large ? 0.555 : (family == .medium ? 0.455 : 0.56)
        PaintedSky(palette: SkyPalette(clock: clock, condition: condition), horizon: plan.skyHorizon)
            .overlay {
                if !clock.isDay && !condition.gray {
                    Stars(region: plan.stars, count: plan.starCount, sparkles: plan.sparkles)
                    if family == .large {
                        Stars(region: CGRect(x: 0.28, y: 0.27, width: 0.44, height: 0.08), count: 8, sparkles: 1, seed: 5)
                    }
                }
            }
            .overlay(PNCornerShade(family: family))
            .overlay(PNSkyBack(clock: clock, condition: condition, arc: plan.arc, phase: phase, plan: plan))
            .overlay(PNRange(layers: PNRidges.day(family), night: !clock.isDay, snowLower: condition == .snow ? 0.02 : 0))
            .overlay(PNMist(center: mistAt, spread: family == .large ? 0.05 : 0.07, night: !clock.isDay))
            .overlay(SkyFront(clock: clock, condition: condition, arc: plan.arc))
            .overlay(PNFloorShade(top: plan.ground))
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.3), .clear], center: UnitPoint(x: 0.95, y: 1.0), startRadius: 0, endRadius: 300))
            .overlay(GoldFrame(inset: 6))
            .overlay(SlabBevel())
    }
}

/// The Quote widget's picture: an evening sky with tonight's moon over a tall range, the valley floor below.
struct PNQuoteGround: View {
    var family: Family
    var date: Date

    var body: some View {
        let plan = PNPlan.quote(family)
        let ridges = PNRidges.quote(family)
        let peak = ridges.first.map { $0.layer.profile.keys.map(\.y).min() ?? 0.3 } ?? 0.3
        PaintedSky(palette: .evening, horizon: plan.skyHorizon)
            // Afterglow low behind the peaks, and moonlight across the top.
            .overlay(RadialGradient(colors: [Color(hex: 0xB0703F).opacity(0.34), .clear],
                                    center: UnitPoint(x: 0.3, y: plan.skyHorizon), startRadius: 0, endRadius: family == .small ? 120 : 210))
            .overlay(Stars(region: plan.stars, count: plan.starCount, sparkles: plan.sparkles, seed: 7))
            .overlay {
                GeometryReader { geo in
                    let pos = plan.arc.point(0.62, in: geo.size)
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [Stone.moonlight.opacity(0.14), .clear], center: .center,
                                                 startRadius: 0, endRadius: plan.bodyRadius * 7))
                            .frame(width: plan.bodyRadius * 14, height: plan.bodyRadius * 14)
                        MoonDisc(radius: plan.bodyRadius, phase: MoonPhase(date: date))
                    }
                    .position(pos)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .overlay(PNRange(layers: ridges, night: true))
            .overlay(PNMist(center: (peak + plan.ground) / 2 + 0.1, spread: 0.08, night: true, strength: 0.2))
            .overlay(PNFloorShade(top: plan.ground, strength: 0.38))
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.3), .clear], center: UnitPoint(x: 0.95, y: 1.0), startRadius: 0, endRadius: 300))
            .overlay(GoldFrame(inset: 6))
            .overlay(SlabBevel())
    }
}
