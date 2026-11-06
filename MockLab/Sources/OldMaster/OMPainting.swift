import SwiftUI

// The painting under every widget. Each widget has its own canvas, painted in MockLab/Textures/old-master/make.py
// as a value study (a grisaille underpainting) at 1 px per point. Here it is glazed at run time: the shadow colour
// underneath, then the two halves of the value laid over it as template images, the lower half in a warm mid colour
// and the upper half in the light colour (an exact three-stop gradient map: chocolate, warm umber, cream), and the
// brightest lights (cloud tops, lit snow) glazed again in the colour of the sun or moon, strongest near it.
// So one canvas gives golden morning, amber dusk and a moonlit nocturne, and greys down in bad weather.

/// One painted canvas: its textures, where the sun and moon travel in it, and the open sky (for rain and snow).
enum OMCanvas: String {
    case dayLarge = "day-large", dayMedium = "day-medium", daySmall = "day-small"
    case quoteLarge = "quote-large", quoteMedium = "quote-medium", quoteSmall = "quote-small"

    var lower: Image { Mock.texture("old-master/\(rawValue)-lo") }
    var upper: Image { Mock.texture("old-master/\(rawValue)-hi") }
    var glow: Image { Mock.texture("old-master/\(rawValue)-glow") }

    /// The arc the sun (or moon) follows across the painting's open sky, in fractions of the widget.
    var arc: SkyArc {
        switch self {
        case .dayLarge: return SkyArc(centerX: 0.5, horizon: 0.25, radiusX: 0.40, radiusY: 0.19)
        case .quoteLarge: return SkyArc(centerX: 0.52, horizon: 0.36, radiusX: 0.38, radiusY: 0.27)
        case .dayMedium, .quoteMedium: return SkyArc(centerX: 0.165, horizon: 0.5, radiusX: 0.11, radiusY: 0.36)
        case .daySmall: return SkyArc(centerX: 0.5, horizon: 0.42, radiusX: 0.16, radiusY: 0.26)
        case .quoteSmall: return SkyArc(centerX: 0.5, horizon: 0.4, radiusX: 0.3, radiusY: 0.26)
        }
    }

    /// The sky left open by the layout (fractions), where rain and snow fall.
    var openSky: CGRect {
        switch self {
        case .dayLarge: return CGRect(x: 0, y: 0, width: 1, height: 0.33)
        case .quoteLarge: return CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .dayMedium, .quoteMedium: return CGRect(x: 0, y: 0, width: 0.34, height: 1)
        case .daySmall: return CGRect(x: 0, y: 0.24, width: 1, height: 0.34)
        case .quoteSmall: return CGRect(x: 0, y: 0, width: 1, height: 0.6)
        }
    }

    var isLarge: Bool { self == .dayLarge || self == .quoteLarge }
}

/// The glazes for the time of day and the weather: three stops (shadow, warm mid, light), each a little lighter
/// toward the horizon, and the colour of the sun or moon.
struct OMLight {
    var shadow: [Color]
    var mid: [Color]
    var light: [Color]
    var glow: Color
    var glowStrength: Double
    var air: Double        // how much the light warms the air round the sun or moon
    var isDay: Bool

    var lightTop: Color { light[0] }
    var lightBottom: Color { light[1] }

    private struct RGB {
        var r, g, b: Double
        init(_ hex: UInt32) {
            r = Double((hex >> 16) & 0xFF) / 255; g = Double((hex >> 8) & 0xFF) / 255; b = Double(hex & 0xFF) / 255
        }
        func mixed(_ o: RGB, _ t: Double) -> RGB {
            var m = self
            m.r += (o.r - r) * t; m.g += (o.g - g) * t; m.b += (o.b - b) * t
            return m
        }
        var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
    }

    private struct Stops {
        var s0, s1, m0, m1, l0, l1, glow: RGB
        func mixed(_ o: Stops, _ t: Double) -> Stops {
            Stops(s0: s0.mixed(o.s0, t), s1: s1.mixed(o.s1, t), m0: m0.mixed(o.m0, t), m1: m1.mixed(o.m1, t),
                  l0: l0.mixed(o.l0, t), l1: l1.mixed(o.l1, t), glow: glow.mixed(o.glow, t))
        }
    }

    // Morning and day: chocolate shadows, warm umber, peach-cream lights, gold-peach where the sun breaks through.
    private static let day = Stops(s0: RGB(0x2C1810), s1: RGB(0x1E100A), m0: RGB(0x8A5F47), m1: RGB(0x946A50),
                                   l0: RGB(0xEBD1B2), l1: RGB(0xF3E1C8), glow: RGB(0xF7CDA0))
    // Sunrise and sunset: the whole picture deepens to amber.
    private static let dusk = Stops(s0: RGB(0x2A130A), s1: RGB(0x1A0B05), m0: RGB(0x8F5134), m1: RGB(0x9A5C3B),
                                    l0: RGB(0xE9B185), l1: RGB(0xF0C49A), glow: RGB(0xF4A064))
    // Night: an umber nocturne under the moon.
    private static let night = Stops(s0: RGB(0x0E0805), s1: RGB(0x090503), m0: RGB(0x30221A), m1: RGB(0x372820),
                                     l0: RGB(0x7E6A57), l1: RGB(0x8C7762), glow: RGB(0xF3E6CC))
    // Overcast, rain, snow and fog: the warmth drains to grey taupe.
    private static let gray = Stops(s0: RGB(0x2A211B), s1: RGB(0x1E1814), m0: RGB(0x6E6157), m1: RGB(0x776A5F),
                                    l0: RGB(0xC2B6A7), l1: RGB(0xCFC4B6), glow: RGB(0xE6DACA))
    private static let grayNight = Stops(s0: RGB(0x120E0B), s1: RGB(0x0C0907), m0: RGB(0x342C26), m1: RGB(0x3B322B),
                                         l0: RGB(0x7C7064), l1: RGB(0x887B6E), glow: RGB(0xD9CDBA))

    init(clock: SkyClock, condition: SkyCondition) {
        var st: Stops
        var strength: Double, air: Double
        if clock.isDay {
            st = Self.day.mixed(Self.dusk, clock.twilight)
            strength = 0.8 + 0.15 * clock.twilight
            air = 0.2 + 0.12 * clock.twilight
        } else {
            // Just after sunset (or before dawn) some amber lingers.
            st = Self.night.mixed(Self.dusk, clock.twilight * 0.55)
            strength = 0.9
            air = 0.24
        }
        if condition.gray {
            st = st.mixed(clock.isDay ? Self.gray : Self.grayNight, 0.7)
            strength *= 0.45
            air *= 0.4
        } else if condition == .partly {
            strength *= 0.85
        }
        shadow = [st.s0.color, st.s1.color]
        mid = [st.m0.color, st.m1.color]
        light = [st.l0.color, st.l1.color]
        glow = st.glow.color
        glowStrength = strength
        self.air = air
        isDay = clock.isDay
    }
}

/// The glazed painting with its sky (sun or moon, weather) and the surface of an old canvas over it.
struct OMPainting: View {
    var canvas: OMCanvas
    var clock: SkyClock
    var condition: SkyCondition
    var phase: MoonPhase

    var body: some View {
        let light = OMLight(clock: clock, condition: condition)
        GeometryReader { geo in
            let size = geo.size
            let u = size.width / 348
            let body = canvas.arc.point(clock.progress, in: size)
            let center = UnitPoint(x: body.x / size.width, y: body.y / size.height)
            let reach = max(size.width, size.height) * (canvas.isLarge ? 0.55 : 0.75)
            ZStack {
                LinearGradient(colors: light.shadow, startPoint: .top, endPoint: .bottom)
                canvas.lower
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(LinearGradient(colors: light.mid, startPoint: .top, endPoint: .bottom))
                canvas.upper
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(LinearGradient(colors: light.light, startPoint: .top, endPoint: .bottom))
                // The light breaking through: warm air round the sun or moon.
                RadialGradient(colors: [light.glow.opacity(light.air), light.glow.opacity(light.air * 0.25), .clear],
                               center: center, startRadius: 0, endRadius: reach * 0.45)
                    .blendMode(.screen)
                canvas.glow
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(RadialGradient(colors: [light.glow, light.glow.opacity(0.45), light.glow.opacity(0.12)],
                                                    center: center, startRadius: 0, endRadius: reach))
                    .opacity(light.glowStrength)
                OMSkyBody(clock: clock, condition: condition, phase: phase, light: light, radius: (canvas.isLarge ? 9 : 7) * max(u, 0.6))
                    .position(body)
                OMWeather(condition: condition, light: light, open: canvas.openSky, seed: UInt64(canvas.rawValue.count))
                OMVarnish(strength: light.isDay ? 1 : 0.8)
                OMCraquelure(seed: UInt64(canvas.rawValue.count) &* 7, opacity: light.isDay ? 1 : 0.7)
                CanvasWeave(opacity: 0.8)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The sun as old masters paint it, a blaze half lost in cloud; or tonight's moon glowing through a veil of cloud.
struct OMSkyBody: View {
    var clock: SkyClock
    var condition: SkyCondition
    var phase: MoonPhase
    var light: OMLight
    var radius: CGFloat

    var body: some View {
        if clock.isDay {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [light.glow.opacity(0.75), light.glow.opacity(0.25), .clear],
                                         center: .center, startRadius: 0, endRadius: radius * 3.2))
                    .frame(width: radius * 6.4, height: radius * 6.4)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFF6E4), Color(hex: 0xFBE3B4).opacity(0.85), .clear],
                                         center: .center, startRadius: 0, endRadius: radius * 1.1))
                    .frame(width: radius * 2.2, height: radius * 2.2)
                    .blur(radius: radius * 0.25)
            }
            .opacity(condition.gray ? 0.45 : 1)
        } else {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [light.glow.opacity(0.42), light.glow.opacity(0.14), .clear],
                                         center: .center, startRadius: radius * 0.6, endRadius: radius * 5.5))
                    .frame(width: radius * 11, height: radius * 11)
                ZStack {
                    Circle().fill(Color(hex: 0x4A3A2E).opacity(0.18))
                    Image("PaintMoon")
                        .resizable()
                        .scaledToFill()
                        .colorMultiply(Color(hex: 0xF6EBD6))
                        .clipShape(MoonLitShape(phase: phase))
                        .shadow(color: light.glow.opacity(0.9), radius: radius * 0.5)
                        .shadow(color: light.glow.opacity(0.5), radius: radius * 1.2)
                }
                .frame(width: radius * 2, height: radius * 2)
                // A thin bank of cloud drifting across its face, lit from behind.
                Capsule()
                    .fill(light.lightTop.opacity(0.45))
                    .frame(width: radius * 4.2, height: radius * 0.6)
                    .blur(radius: radius * 0.28)
                    .offset(x: radius * 0.5, y: radius * 0.5)
                Capsule()
                    .fill(light.lightTop.opacity(0.3))
                    .frame(width: radius * 3, height: radius * 0.42)
                    .blur(radius: radius * 0.22)
                    .offset(x: -radius * 0.7, y: -radius * 0.25)
            }
            .opacity(condition.gray ? 0.55 : 1)
        }
    }
}

/// Rain as a painted veil hanging from the cloud, snow as a few soft flakes, fog as banks of mist. Kept sparse.
struct OMWeather: View {
    var condition: SkyCondition
    var light: OMLight
    var open: CGRect
    var seed: UInt64

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            let frame = CGRect(x: open.minX * s.width, y: open.minY * s.height, width: open.width * s.width, height: open.height * s.height)
            switch condition {
            case .rain, .storm:
                Mock.texture("old-master/veil")
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(light.lightTop.opacity(condition == .storm ? 0.85 : 0.72))
                    .frame(width: frame.width, height: frame.height)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0.05), .init(color: .black, location: 0.3),
                                                 .init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .position(x: frame.midX, y: frame.midY)
            case .snow:
                Canvas { ctx, _ in
                    var rng = SeededRandom(seed &+ 31)
                    let u = s.width / 348
                    let count = Int(14 + 26 * frame.width * frame.height / (348 * 130))
                    for _ in 0..<min(count, 40) {
                        let x = frame.minX + CGFloat(rng.next()) * frame.width
                        let y = frame.minY + CGFloat(0.12 + 0.88 * rng.next()) * frame.height
                        let r = (0.9 + CGFloat(rng.next()) * 1.1) * max(u, 0.7)
                        let glow = CGRect(x: x - r * 2.2, y: y - r * 2.2, width: r * 4.4, height: r * 4.4)
                        ctx.fill(Path(ellipseIn: glow), with: .radialGradient(Gradient(colors: [OMInk.cream.opacity(0.35), .clear]),
                                                                            center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2.2))
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(OMInk.cream.opacity(0.85)))
                    }
                }
            case .fog:
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(light.lightBottom.opacity(0.3))
                        .frame(width: frame.width * (0.7 + 0.1 * CGFloat(i)), height: frame.height * 0.07)
                        .blur(radius: frame.height * 0.03)
                        .position(x: frame.minX + frame.width * (0.4 + 0.1 * CGFloat(i)), y: frame.minY + frame.height * (0.55 + 0.13 * CGFloat(i)))
                }
            default:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }
}
