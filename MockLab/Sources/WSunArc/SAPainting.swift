import SwiftUI

// The painting behind every Sun Arc Weather widget: the shipped Cover's sepia oil of the Matterhorn, glazed at run
// time with the Cover's own CoverLight, whose sky is the sun's path.
//
//     painting  ->  gilt arc  ->  sun or moon  ->  the same painting through <canvas>-front  ->  weather, weave
//
// The front mask holds the land (ridges, the Matterhorn, the firs), so the arc's feet tuck behind the ridge crest and
// the sun rises and sets behind the hills. The textures are 1 px per point at the iPhone 17 widget sizes, painted in
// MockLab/Textures/weather-sun-arc/make.py.

/// One painted canvas: its textures, the arc the sun follows and the open sky where rain and snow fall.
enum SACanvas: String {
    case large, medium, small

    init(_ family: Family) {
        switch family {
        case .large: self = .large
        case .medium: self = .medium
        case .small: self = .small
        }
    }

    var lower: Image { Mock.texture("\(SALandscape.folder)/\(rawValue)-lo") }
    var upper: Image { Mock.texture("\(SALandscape.folder)/\(rawValue)-hi") }
    var glow: Image { Mock.texture("\(SALandscape.folder)/\(rawValue)-glow") }
    var front: Image { Mock.texture("\(SALandscape.folder)/\(rawValue)-front") }

    var isLarge: Bool { self == .large }

    /// The sun's path, in fractions of the widget (ARC in make.py): the crown clears the summit, the feet stand on
    /// the ridge crest a point or two below the horizon so they tuck behind it.
    var arc: SkyArc {
        if let scene = SALandscape.arcs[rawValue] { return scene }
        switch self {
        case .large: return SkyArc(centerX: 0.5, horizon: 0.575, radiusX: 0.42, radiusY: 0.45)
        case .medium: return SkyArc(centerX: 0.665, horizon: 0.75, radiusX: 0.28, radiusY: 0.5)
        case .small: return SkyArc(centerX: 0.5, horizon: 0.625, radiusX: 0.39, radiusY: 0.42)
        }
    }

    /// The sky (fractions), where rain and snow fall.
    var openSky: CGRect {
        switch self {
        case .large: return CGRect(x: 0, y: 0, width: 1, height: 0.58)
        case .medium: return CGRect(x: 0.36, y: 0, width: 0.64, height: 0.76)
        case .small: return CGRect(x: 0, y: 0, width: 1, height: 0.64)
        }
    }

    /// The arc's sky body radius in points.
    var bodyRadius: CGFloat {
        switch self {
        case .large: return 8
        case .medium: return 6.5
        case .small: return 6
        }
    }
}

/// The glazed paint with the Cover's varnish and craquelure: drawn once behind the arc and once in front of it,
/// through the land mask.
struct SAPaint: View {
    var lower: Image
    var upper: Image
    var glow: Image?
    var light: CoverLight
    var center: UnitPoint
    var reach: CGFloat
    var seed: UInt64
    /// The old varnish and craquelure; false for the sunlit travertine look (TVHome.swift).
    var aged = true

    var body: some View {
        ZStack {
            LinearGradient(colors: light.shadow, startPoint: .top, endPoint: .bottom)
            lower
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .foregroundStyle(LinearGradient(colors: light.mid, startPoint: .top, endPoint: .bottom))
            upper
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .foregroundStyle(LinearGradient(colors: light.light, startPoint: .top, endPoint: .bottom))
            RadialGradient(colors: [light.glow.opacity(light.air), light.glow.opacity(light.air * 0.25), .clear],
                           center: center, startRadius: 0, endRadius: reach * 0.45)
                .blendMode(.screen)
            if let glow {
                glow
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(RadialGradient(colors: [light.glow, light.glow.opacity(0.45), light.glow.opacity(0.12)],
                                                    center: center, startRadius: 0, endRadius: reach))
                    .opacity(light.glowStrength)
            }
            if aged {
                CoverVarnish(strength: light.isDay ? 1 : 0.8)
                CoverCraquelure(seed: seed, opacity: light.isDay ? 1 : 0.7)
            }
        }
    }
}

/// The whole picture for a snapshot: the painting, the gilt arc with the sun or moon on it, the land in front, the
/// weather and the canvas weave.
struct SAScene: View {
    var canvas: SACanvas
    var snap: DaySnapshot

    var body: some View {
        let clock = SkyClock(now: snap.date, weather: snap.weather)
        let condition = SkyCondition(code: snap.weather?.code)
        let light = CoverLight(clock: clock, condition: condition)
        GeometryReader { geo in
            let size = geo.size
            let u = size.width / 348
            let body = canvas.arc.point(clock.progress, in: size)
            let center = UnitPoint(x: body.x / size.width, y: body.y / size.height)
            let reach = max(size.width, size.height) * (canvas.isLarge ? 0.55 : 0.75)
            let seed = UInt64(canvas.rawValue.count) &* 11
            ZStack {
                SAPaint(lower: canvas.lower, upper: canvas.upper, glow: canvas.glow, light: light, center: center,
                        reach: reach, seed: seed)
                SAArcLine(arc: canvas.arc, progress: clock.progress, light: light, known: snap.weather != nil,
                          weight: canvas.isLarge ? 1 : 0.85)
                SASkyBody(isDay: clock.isDay, condition: condition, phase: MoonPhase(date: snap.date), light: light,
                          radius: canvas.bodyRadius * max(u, 0.8))
                    .opacity(snap.weather == nil ? 0.5 : 1)  // no sun times: its place is only an estimate
                    .position(body)
                SAPaint(lower: canvas.lower, upper: canvas.upper, glow: canvas.glow, light: light, center: center,
                        reach: reach, seed: seed)
                    .compositingGroup()
                    .mask { canvas.front.resizable().interpolation(.high) }
                CoverWeather(condition: condition, light: light, open: canvas.openSky, seed: UInt64(canvas.rawValue.count))
                CanvasWeave(opacity: 0.8)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - The sun and the moon on the arc

/// The sun as a small blazing disc ringed in gilt, or tonight's moon in its phase (the lit part of the painted moon,
/// the rest in faint earthshine), each in its own glow.
struct SASkyBody: View {
    var isDay: Bool
    var condition: SkyCondition
    var phase: MoonPhase
    var light: CoverLight
    var radius: CGFloat

    var body: some View {
        let dim = condition.gray ? 0.55 : 1.0
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [light.glow.opacity(isDay ? 0.7 : 0.4), light.glow.opacity(isDay ? 0.22 : 0.12), .clear],
                                     center: .center, startRadius: radius * 0.5, endRadius: radius * (isDay ? 4.2 : 4.8)))
                .frame(width: radius * 10, height: radius * 10)
                .opacity(dim)
            // The fine gilt ring that pins the body to the arc.
            Circle()
                .strokeBorder(LinearGradient(colors: [light.rim, light.gild[1], light.gild[2]], startPoint: .top, endPoint: .bottom),
                              lineWidth: 0.7)
                .frame(width: radius * (isDay ? 2 : 2.5) + 6, height: radius * (isDay ? 2 : 2.5) + 6)
                .shadow(color: CoverInk.shadow.opacity(0.5), radius: 0.8, x: 0, y: 0.6)
                .opacity(0.9 * dim)
            if isDay {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFF8E8), Color(hex: 0xFBE6BC), Color(hex: 0xEFC78C)],
                                         center: UnitPoint(x: 0.42, y: 0.38), startRadius: 0, endRadius: radius * 1.05))
                    .frame(width: radius * 2, height: radius * 2)
                    .shadow(color: light.glow.opacity(0.9), radius: radius * 0.6)
                    .opacity(condition.gray ? 0.7 : 1)
            } else {
                ZStack {
                    Circle().fill(Color(hex: 0x3A2C22).opacity(0.85))
                    Image("PaintMoon")
                        .resizable()
                        .scaledToFill()
                        .colorMultiply(Color(hex: 0x7A6A58))
                        .opacity(0.35)
                        .clipShape(Circle())
                    Image("PaintMoon")
                        .resizable()
                        .scaledToFill()
                        .colorMultiply(Color(hex: 0xF6EBD6))
                        .clipShape(MoonLitShape(phase: phase))
                        .shadow(color: light.glow.opacity(0.8), radius: radius * 0.45)
                }
                .frame(width: radius * 2.5, height: radius * 2.5)
            }
        }
    }
}
