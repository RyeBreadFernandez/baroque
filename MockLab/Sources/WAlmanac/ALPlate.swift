import SwiftUI

// The plate at the head of each page: an oil sketch of the Matterhorn from the Riffelsee, tipped in like the plates
// of an old almanac (a raised painted board with a cut edge, a cast shadow and a gold fillet round it).
//
// Each plate is one value study (MockLab/Textures/weather-almanac/make.py) glazed at run time, as the shipped Cover
// paintings are: a shadow colour, then the lower and upper halves of the value as template images in a warm mid and
// a light colour, the near ridges and firs again in olive through their mask, the sun or moon, the land again over
// it (so they set behind the mountain), the lit snow and cloud tops in the sun's colour, then the weather.

enum ALPlateKind: String {
    case large, medium, small

    func layer(_ name: String) -> Image { Mock.texture("weather-almanac/plate-\(rawValue)-\(name)") }

    /// The arc the sun and moon follow, in fractions of the plate: through the open sky left of the summit.
    var arc: SkyArc {
        switch self {
        case .large: return SkyArc(centerX: 0.5, horizon: 0.8, radiusX: 0.46, radiusY: 0.66)
        case .medium: return SkyArc(centerX: 0.5, horizon: 0.86, radiusX: 0.44, radiusY: 0.6)
        case .small: return SkyArc(centerX: 0.5, horizon: 0.86, radiusX: 0.42, radiusY: 0.62)
        }
    }

    var bodyRadius: CGFloat {
        switch self {
        case .large: return 8
        case .medium: return 5.5
        case .small: return 5
        }
    }

    /// The open sky, where rain and snow fall (fractions of the plate).
    var openSky: CGRect {
        switch self {
        case .large: return CGRect(x: 0, y: 0, width: 1, height: 0.86)
        case .medium: return CGRect(x: 0, y: 0, width: 1, height: 0.9)
        case .small: return CGRect(x: 0, y: 0, width: 1, height: 0.9)
        }
    }
}

/// The glazes for the time of day and the weather: espresso shadows, warm umber, cream lights and a pale gold sun by
/// day; amber at sunrise and sunset; an olive nocturne under the moon; grey taupe in cloud and rain. The near ridges
/// take their own olive stops.
struct ALLight {
    var shadow: [Color]
    var mid: [Color]
    var light: [Color]
    var oliveShadow: Color
    var oliveMid: Color
    var oliveLight: Color
    var glow: Color
    var glowStrength: Double
    var air: Double
    var isDay: Bool

    private struct Stops {
        var s0, s1, m0, m1, l0, l1, os, om, ol, glow: ALRGB
        func mixed(_ o: Stops, _ t: Double) -> Stops {
            Stops(s0: s0.mixed(o.s0, t), s1: s1.mixed(o.s1, t), m0: m0.mixed(o.m0, t), m1: m1.mixed(o.m1, t),
                  l0: l0.mixed(o.l0, t), l1: l1.mixed(o.l1, t), os: os.mixed(o.os, t), om: om.mixed(o.om, t),
                  ol: ol.mixed(o.ol, t), glow: glow.mixed(o.glow, t))
        }
    }

    private static let day = Stops(s0: ALRGB(0x2B1B10), s1: ALRGB(0x1E120A), m0: ALRGB(0x9A7A58), m1: ALRGB(0x8A6C4E),
                                   l0: ALRGB(0xF3E5C9), l1: ALRGB(0xEADBBD), os: ALRGB(0x191A0D), om: ALRGB(0x5C6038),
                                   ol: ALRGB(0xC2C094), glow: ALRGB(0xF6D9A0))
    private static let dusk = Stops(s0: ALRGB(0x2B140A), s1: ALRGB(0x1C0C05), m0: ALRGB(0x985B39), m1: ALRGB(0x8E5536),
                                    l0: ALRGB(0xF3C99C), l1: ALRGB(0xEAB98C), os: ALRGB(0x1D150A), om: ALRGB(0x695830),
                                    ol: ALRGB(0xCFAF7C), glow: ALRGB(0xF5A062))
    private static let night = Stops(s0: ALRGB(0x0B0B08), s1: ALRGB(0x070705), m0: ALRGB(0x30332A), m1: ALRGB(0x2A2C23),
                                     l0: ALRGB(0xA19E84), l1: ALRGB(0x8D8A72), os: ALRGB(0x060705), om: ALRGB(0x22271A),
                                     ol: ALRGB(0x5E6649), glow: ALRGB(0xF0E6CA))
    private static let gray = Stops(s0: ALRGB(0x2A241D), s1: ALRGB(0x1F1A15), m0: ALRGB(0x6F675B), m1: ALRGB(0x675F54),
                                    l0: ALRGB(0xCFC7B6), l1: ALRGB(0xC4BBAA), os: ALRGB(0x1D1E15), om: ALRGB(0x56593F),
                                    ol: ALRGB(0xA9A98B), glow: ALRGB(0xE8DECC))
    // Rain and storm: the grey lowered toward slate, the lights dimmed under the cloud.
    private static let stormy = Stops(s0: ALRGB(0x1E1B17), s1: ALRGB(0x15130F), m0: ALRGB(0x58534A), m1: ALRGB(0x4F4A42),
                                      l0: ALRGB(0xADA697), l1: ALRGB(0x9E9787), os: ALRGB(0x151610), om: ALRGB(0x464A35),
                                      ol: ALRGB(0x8E8F74), glow: ALRGB(0xD9D1C1))
    private static let grayNight = Stops(s0: ALRGB(0x0E0D0B), s1: ALRGB(0x0A0908), m0: ALRGB(0x35332C), m1: ALRGB(0x2F2D27),
                                         l0: ALRGB(0x817D6E), l1: ALRGB(0x747062), os: ALRGB(0x0A0B08), om: ALRGB(0x2A2D22),
                                         ol: ALRGB(0x61655A), glow: ALRGB(0xD8CEBA))

    init(clock: SkyClock, condition: SkyCondition) {
        var st: Stops
        var strength: Double, air: Double
        if clock.isDay {
            st = Self.day.mixed(Self.dusk, clock.twilight)
            strength = 0.75 + 0.2 * clock.twilight
            air = 0.22 + 0.14 * clock.twilight
        } else {
            st = Self.night.mixed(Self.dusk, clock.twilight * 0.5)
            strength = 0.85
            air = 0.26
        }
        if condition == .rain || condition == .storm {
            st = st.mixed(clock.isDay ? Self.stormy : Self.grayNight, 0.8)
            strength *= 0.3
            air *= 0.25
        } else if condition.gray {
            st = st.mixed(clock.isDay ? Self.gray : Self.grayNight, 0.75)
            strength *= 0.4
            air *= 0.35
        } else if condition == .partly {
            strength *= 0.85
        }
        shadow = [st.s0.color, st.s1.color]
        mid = [st.m0.color, st.m1.color]
        light = [st.l0.color, st.l1.color]
        oliveShadow = st.os.color
        oliveMid = st.om.color
        oliveLight = st.ol.color
        glow = st.glow.color
        glowStrength = strength
        self.air = air
        isDay = clock.isDay
    }
}

/// The value study glazed: the three stops over everything, then the olive stops through the near ridges' mask.
struct ALPlateGlaze: View {
    var kind: ALPlateKind
    var light: ALLight

    var body: some View {
        ZStack {
            stops(LinearGradient(colors: light.shadow, startPoint: .top, endPoint: .bottom),
                  LinearGradient(colors: light.mid, startPoint: .top, endPoint: .bottom),
                  LinearGradient(colors: light.light, startPoint: .top, endPoint: .bottom))
            stops(light.oliveShadow, light.oliveMid, light.oliveLight)
                .compositingGroup()
                .mask { kind.layer("olive").resizable().interpolation(.high) }
        }
    }

    private func stops<S: ShapeStyle, M: ShapeStyle, L: ShapeStyle>(_ s: S, _ m: M, _ l: L) -> some View {
        ZStack {
            Rectangle().fill(s)
            kind.layer("lo").resizable().renderingMode(.template).interpolation(.high).foregroundStyle(m)
            kind.layer("hi").resizable().renderingMode(.template).interpolation(.high).foregroundStyle(l)
        }
    }
}

/// The painted plate for a snapshot: sky, sun or moon behind the Matterhorn, lit snow, weather, varnish and canvas.
struct ALPlate: View {
    var kind: ALPlateKind
    var snapshot: DaySnapshot

    var body: some View {
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let condition = SkyCondition(code: snapshot.weather?.code)
        let light = ALLight(clock: clock, condition: condition)
        GeometryReader { geo in
            let size = geo.size
            let body = kind.arc.point(clock.progress, in: size)
            let center = UnitPoint(x: body.x / size.width, y: body.y / size.height)
            let reach = max(size.width, size.height) * 0.7
            ZStack {
                ALPlateGlaze(kind: kind, light: light)
                RadialGradient(colors: [light.glow.opacity(light.air), light.glow.opacity(light.air * 0.25), .clear],
                               center: center, startRadius: 0, endRadius: reach * 0.5)
                    .blendMode(.screen)
                if !clock.isDay {
                    ALStars(seed: UInt64(kind.rawValue.count) &* 13, open: kind.openSky, faint: condition.gray)
                }
                ALSkyBody(isDay: clock.isDay, condition: condition, phase: MoonPhase(date: snapshot.date), light: light,
                          radius: kind.bodyRadius)
                    .position(body)
                // The land again over the sun or moon, so they rise and set behind the mountain.
                ALPlateGlaze(kind: kind, light: light)
                    .compositingGroup()
                    .mask { kind.layer("land").resizable().interpolation(.high) }
                kind.layer("glow")
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(RadialGradient(colors: [light.glow, light.glow.opacity(0.5), light.glow.opacity(0.15)],
                                                    center: center, startRadius: 0, endRadius: reach))
                    .opacity(light.glowStrength)
                ALPlateWeather(condition: condition, light: light, open: kind.openSky, seed: UInt64(kind.rawValue.count))
                EllipticalGradient(colors: [.clear, .clear, Color(hex: 0x120A04).opacity(0.42)],
                                   center: UnitPoint(x: 0.5, y: 0.4), startRadiusFraction: 0, endRadiusFraction: 0.75)
                Color(hex: 0xC09050).opacity(clock.isDay ? 0.05 : 0.03)
                CanvasWeave(opacity: 0.75)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The sun as a soft blaze, or tonight's moon in its phase with a halo and a wisp of cloud across it.
struct ALSkyBody: View {
    var isDay: Bool
    var condition: SkyCondition
    var phase: MoonPhase
    var light: ALLight
    var radius: CGFloat

    var body: some View {
        if isDay {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [light.glow.opacity(0.8), light.glow.opacity(0.25), .clear],
                                         center: .center, startRadius: 0, endRadius: radius * 3.4))
                    .frame(width: radius * 6.8, height: radius * 6.8)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFF7E6), Color(hex: 0xFBE6B8).opacity(0.9), .clear],
                                         center: .center, startRadius: 0, endRadius: radius * 1.1))
                    .frame(width: radius * 2.2, height: radius * 2.2)
                    .blur(radius: radius * 0.2)
            }
            .opacity(condition == .rain || condition == .storm ? 0.15 : condition.gray ? 0.35 : 1)
        } else {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [light.glow.opacity(0.45), light.glow.opacity(0.14), .clear],
                                         center: .center, startRadius: radius * 0.6, endRadius: radius * 5))
                    .frame(width: radius * 10, height: radius * 10)
                ZStack {
                    Circle().fill(Color(hex: 0x3A3A2E).opacity(0.35))
                    Image("PaintMoon")
                        .resizable()
                        .scaledToFill()
                        .colorMultiply(Color(hex: 0xF6EDD6))
                        .clipShape(MoonLitShape(phase: phase))
                        .shadow(color: light.glow.opacity(0.9), radius: radius * 0.5)
                }
                .frame(width: radius * 2, height: radius * 2)
                Capsule()
                    .fill(light.light[0].opacity(0.4))
                    .frame(width: radius * 4, height: radius * 0.55)
                    .blur(radius: radius * 0.25)
                    .offset(x: radius * 0.6, y: radius * 0.55)
            }
            .opacity(condition.gray ? 0.5 : 1)
        }
    }
}

/// A scatter of small stars in the night sky of the plate (they sit behind the land).
struct ALStars: View {
    var seed: UInt64
    var open: CGRect
    var faint: Bool

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed &+ 101)
            let n = Int(10 + 18 * size.width * size.height / (324 * 160))
            for _ in 0..<n {
                let x = CGFloat(rng.next()) * size.width
                let y = CGFloat(rng.next()) * size.height * open.height * 0.6
                let r = 0.35 + CGFloat(rng.next()) * 0.6
                let a = (0.35 + 0.55 * rng.next()) * (faint ? 0.3 : 1)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r * 2.5, y: y - r * 2.5, width: r * 5, height: r * 5)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xF3E8CC).opacity(a * 0.3), .clear]),
                                               center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2.5))
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(Color(hex: 0xF6EDD6).opacity(a)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Rain as a painted veil hanging from the cloud, snow as soft flakes, fog as banks of mist, all in the open sky.
struct ALPlateWeather: View {
    var condition: SkyCondition
    var light: ALLight
    var open: CGRect
    var seed: UInt64

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            let frame = CGRect(x: open.minX * s.width, y: open.minY * s.height, width: open.width * s.width,
                               height: open.height * s.height)
            switch condition {
            case .rain, .storm:
                Mock.texture("weather-almanac/veil")
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(light.light[0].opacity(condition == .storm ? 0.95 : 0.85))
                    .scaledToFill()  // one scale, cropped: the slant of the rain never changes
                    .frame(width: frame.width, height: frame.height)
                    .clipped()
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0.0), .init(color: .black, location: 0.2),
                                                 .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .position(x: frame.midX, y: frame.midY)
            case .snow:
                Canvas { ctx, _ in
                    var rng = SeededRandom(seed &+ 31)
                    let u = max(0.7, s.width / 324)
                    let count = min(46, Int(12 + 30 * frame.width * frame.height / (324 * 130)))
                    for _ in 0..<count {
                        let x = frame.minX + CGFloat(rng.next()) * frame.width
                        let y = frame.minY + CGFloat(0.05 + 0.95 * rng.next()) * frame.height
                        let r = (0.8 + CGFloat(rng.next()) * 1.0) * u
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r * 2.2, y: y - r * 2.2, width: r * 4.4, height: r * 4.4)),
                                 with: .radialGradient(Gradient(colors: [Color(hex: 0xF4ECDD).opacity(0.35), .clear]),
                                                       center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2.2))
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(Color(hex: 0xF7F0E2).opacity(0.9)))
                    }
                }
            case .fog:
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(light.light[1].opacity(0.55))
                        .frame(width: frame.width * (0.6 + 0.12 * CGFloat(i)), height: frame.height * 0.14)
                        .blur(radius: frame.height * 0.05)
                        .position(x: frame.minX + frame.width * (0.35 + 0.15 * CGFloat(i)),
                                  y: frame.minY + frame.height * (0.5 + 0.14 * CGFloat(i)))
                }
            default:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }
}

/// The plate tipped into the page: the painting on a raised board with a dark cut edge and a soft shadow cast down
/// onto the paper, and a gold fillet a few points outside it, like the plates of an old almanac.
struct ALTippedPlate: View {
    var kind: ALPlateKind
    var snapshot: DaySnapshot
    var ink: ALInk
    var radius: CGFloat = 3
    var fillet: CGFloat = 3.5

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ALPlate(kind: kind, snapshot: snapshot)
            .clipShape(shape)
            .overlay {
                // The board's cut edge: dark on the shaded sides, a lit hairline along the top and left.
                shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.22), Color.black.opacity(0.55)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
            }
            .background {
                shape.fill(Color.black.opacity(ink.night ? 0.75 : 0.42))
                    .blur(radius: 3)
                    .offset(x: 0.6, y: 2.2)
            }
            .background {
                RoundedRectangle(cornerRadius: radius + fillet, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [ink.rule.opacity(0.7), ink.night ? ink.gild[0] : ink.gild[1], ink.rule.opacity(0.7)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.6)
                    .padding(-fillet)
            }
    }
}
