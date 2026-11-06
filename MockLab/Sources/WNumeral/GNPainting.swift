import SwiftUI

// The painting behind every Giant Numeral widget, and the huge thin temperature that stands in its fog.
//
// Each canvas is one value study painted in MockLab/Textures/weather-numeral/make.py (the Matterhorn in mist above a
// spruce forest) and glazed at run time with a three-stop gradient map in olive, sage and fog by day, amber at dusk,
// fog-blue at night and grey taupe in bad weather. Depth:
//
//     painting  ->  sun glow or moon  ->  the numeral  ->  the same painting through <canvas>-front  ->  weather
//
// The front mask holds the drifting fog banks (at their own thinness), the near ridges of spruce and the tall spires
// at the edges, so the numeral's foot sinks into the fog and the spruce tops cross it, like the clock on a lock
// screen standing behind the trees. The Matterhorn stays whole behind it.

/// One painted canvas: its textures, where the numeral stands, where the sun and moon travel, the open sky.
enum GNCanvas: String {
    case large = "weather-large", medium = "weather-medium", small = "weather-small"

    init(_ family: Family) {
        switch family {
        case .large: self = .large
        case .medium: self = .medium
        case .small: self = .small
        }
    }

    var size: CGSize {
        switch self {
        case .large: return CGSize(width: 348, height: 365)
        case .medium: return CGSize(width: 348, height: 164)
        case .small: return CGSize(width: 164, height: 164)
        }
    }

    func texture(_ part: String) -> Image { Mock.texture("weather-numeral/\(rawValue)-\(part)") }

    /// The numeral as painted round in make.py (NUMERALS there): left edge, baseline, size for two characters.
    var numeral: GNNumeralSpec {
        switch self {
        case .large: return GNNumeralSpec(left: 14, baseline: 236, size: 200)
        case .medium: return GNNumeralSpec(left: 12, baseline: 142, size: 148)
        case .small: return GNNumeralSpec(left: 10, baseline: 116, size: 100)
        }
    }

    /// The sun's (or moon's) path, in fractions of the widget, through the sky the numeral and the peak leave open.
    var arc: SkyArc {
        switch self {
        case .large: return SkyArc(centerX: 0.36, horizon: 0.27, radiusX: 0.2, radiusY: 0.12)
        case .medium: return SkyArc(centerX: 0.86, horizon: 0.42, radiusX: 0.04, radiusY: 0.2)
        case .small: return SkyArc(centerX: 0.62, horizon: 0.26, radiusX: 0.06, radiusY: 0.08)
        }
    }

    /// Where the painting's light comes from (make.py's sun): the lit snow is glazed from here.
    var light: UnitPoint {
        switch self {
        case .large: return UnitPoint(x: 0.86, y: 0.03)
        case .medium: return UnitPoint(x: 0.92, y: -0.02)
        case .small: return UnitPoint(x: 0.98, y: 0.0)
        }
    }

    /// The sky, where rain and snow fall (fractions).
    var openSky: CGRect {
        switch self {
        case .large: return CGRect(x: 0, y: 0, width: 1, height: 0.66)
        case .medium: return CGRect(x: 0, y: 0, width: 1, height: 0.8)
        case .small: return CGRect(x: 0, y: 0, width: 1, height: 0.72)
        }
    }

    var isLarge: Bool { self == .large }

    /// Whether the day's sun shows as a glow of its own (the small sky is too crowded for it; the moon still shows).
    var showsSun: Bool { self != .small }
}

/// Where the numeral stands: the leading edge of its text, its baseline and its size for two characters (points).
struct GNNumeralSpec {
    var left: CGFloat
    var baseline: CGFloat
    var size: CGFloat
}

/// The glazes for the time of day and the weather, and the colours of the numeral.
struct GNLight {
    var shadow: [Color]
    var mid: [Color]
    var light: [Color]
    var glow: Color
    var glowStrength: Double
    var air: Double
    var isDay: Bool
    var face: [Color]      // the numeral: crown, foot
    var halo: Color        // the luminous mist round the numeral
    var frost: Color       // the veil of the frosted glass
    var deep: Color        // cast shadows

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
        var s0, s1, m0, m1, l0, l1, glow, f0, f1, halo, frost, deep: RGB
        func mixed(_ o: Stops, _ t: Double) -> Stops {
            Stops(s0: s0.mixed(o.s0, t), s1: s1.mixed(o.s1, t), m0: m0.mixed(o.m0, t), m1: m1.mixed(o.m1, t),
                  l0: l0.mixed(o.l0, t), l1: l1.mixed(o.l1, t), glow: glow.mixed(o.glow, t), f0: f0.mixed(o.f0, t),
                  f1: f1.mixed(o.f1, t), halo: halo.mixed(o.halo, t), frost: frost.mixed(o.frost, t),
                  deep: deep.mixed(o.deep, t))
        }
    }

    // Day: forest-black shadows, olive and sage, fog lights; soft gold where the sun strikes the snow.
    private static let day = Stops(s0: RGB(0x1A2119), s1: RGB(0x10150F), m0: RGB(0x5A664B), m1: RGB(0x657154),
                                   l0: RGB(0xC4CAB6), l1: RGB(0xD9DCCD), glow: RGB(0xEAD29B),
                                   f0: RGB(0xF8F6EC), f1: RGB(0xE6E1CB), halo: RGB(0xF1EEDC), frost: RGB(0xDDE1D2),
                                   deep: RGB(0x0B0F0A))
    // Sunrise and sunset: the fog turns amber, the olive warms.
    private static let dusk = Stops(s0: RGB(0x221B12), s1: RGB(0x150F0A), m0: RGB(0x6E5F45), m1: RGB(0x7A684C),
                                    l0: RGB(0xDCC49C), l1: RGB(0xE9D3AE), glow: RGB(0xF2B979),
                                    f0: RGB(0xFBF2DE), f1: RGB(0xEDD8B2), halo: RGB(0xF6DDB4), frost: RGB(0xE8D6B8),
                                    deep: RGB(0x0F0B07))
    // Night: a fog-blue nocturne; the numeral turns to moonlit fog.
    private static let night = Stops(s0: RGB(0x070C12), s1: RGB(0x04070B), m0: RGB(0x1C2935), m1: RGB(0x22303C),
                                     l0: RGB(0x5A6E7E), l1: RGB(0x6B7F8E), glow: RGB(0xDDE6E8),
                                     f0: RGB(0xEAF0F2), f1: RGB(0xBFCCD3), halo: RGB(0xC9D6DE), frost: RGB(0x8EA2B0),
                                     deep: RGB(0x020406))
    // Overcast, rain, snow and fog: grey sage.
    private static let gray = Stops(s0: RGB(0x1C201D), s1: RGB(0x141714), m0: RGB(0x5C635D), m1: RGB(0x666D66),
                                    l0: RGB(0xB7BCB3), l1: RGB(0xC8CCC2), glow: RGB(0xDDE0D6),
                                    f0: RGB(0xF4F4EE), f1: RGB(0xDCDDD4), halo: RGB(0xEDEEE6), frost: RGB(0xD5D8CF),
                                    deep: RGB(0x0B0D0B))
    private static let grayNight = Stops(s0: RGB(0x090D11), s1: RGB(0x06090C), m0: RGB(0x232C33), m1: RGB(0x29323A),
                                         l0: RGB(0x5B6770), l1: RGB(0x67737B), glow: RGB(0xC8D0D3),
                                         f0: RGB(0xE6EAEC), f1: RGB(0xBCC5CA), halo: RGB(0xC2CCD2), frost: RGB(0x8A98A2),
                                         deep: RGB(0x020405))

    init(clock: SkyClock, condition: SkyCondition) {
        var st: Stops
        var strength: Double, air: Double
        if clock.isDay {
            st = Self.day.mixed(Self.dusk, clock.twilight)
            strength = 0.75 + 0.15 * clock.twilight
            air = 0.18 + 0.12 * clock.twilight
        } else {
            st = Self.night.mixed(Self.dusk, clock.twilight * 0.5)
            strength = 0.85
            air = 0.22
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
        face = [st.f0.color, st.f1.color]
        halo = st.halo.color
        frost = st.frost.color
        deep = st.deep.color
    }
}

/// The glazed paint: shadow colour, then the lower and upper halves of the value as template images in the mid and
/// light colours, then the brightest lights in the colour of the sun or moon.
struct GNPaint: View {
    var canvas: GNCanvas
    var light: GNLight
    var center: UnitPoint
    var reach: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(colors: light.shadow, startPoint: .top, endPoint: .bottom)
            canvas.texture("lo")
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .foregroundStyle(LinearGradient(colors: light.mid, startPoint: .top, endPoint: .bottom))
            canvas.texture("hi")
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .foregroundStyle(LinearGradient(colors: light.light, startPoint: .top, endPoint: .bottom))
            RadialGradient(colors: [light.glow.opacity(light.air), light.glow.opacity(light.air * 0.25), .clear],
                           center: center, startRadius: 0, endRadius: reach * 0.5)
                .blendMode(.screen)
            canvas.texture("glow")
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .foregroundStyle(RadialGradient(colors: [light.glow, light.glow.opacity(0.75), light.glow.opacity(0.3)],
                                                center: canvas.light, startRadius: 0, endRadius: reach * 1.3))
                .opacity(light.glowStrength)
        }
    }
}

/// The whole picture, with or without the numeral (the to-do widget uses it bare).
struct GNScene: View {
    var canvas: GNCanvas
    var numeral: String?
    var spec: GNNumeralSpec? = nil   // where the numeral stands, when not the canvas's own place
    var clock: SkyClock
    var condition: SkyCondition
    var phase: MoonPhase
    var showsSkyBody = true

    var body: some View {
        let light = GNLight(clock: clock, condition: condition)
        let size = canvas.size
        let body = canvas.arc.point(clock.progress, in: size)
        let center = UnitPoint(x: body.x / size.width, y: body.y / size.height)
        let reach = max(size.width, size.height) * (canvas.isLarge ? 0.6 : 0.8)
        ZStack {
            GNPaint(canvas: canvas, light: light, center: center, reach: reach)
            if showsSkyBody && (canvas.showsSun || !clock.isDay) {
                GNSkyBody(clock: clock, condition: condition, phase: phase, light: light,
                          radius: canvas.isLarge ? 9 : (canvas == .small ? 6 : 7.5))
                    .position(body)
            }
            if let numeral {
                GNNumeral(text: numeral, spec: spec ?? canvas.numeral, size: size, light: light)
            }
            // Flattened before masking, so the soft edge of the mask is taken once.
            GNPaint(canvas: canvas, light: light, center: center, reach: reach)
                .compositingGroup()
                .mask { canvas.texture("front").resizable().interpolation(.high) }
            GNWeatherFX(condition: condition, light: light, open: canvas.openSky, seed: UInt64(canvas.rawValue.count))
            GNVignette(light: light)
            CanvasWeave(opacity: 0.45)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The edges sink into shade: a soft dark rim round the picture, as on a damp morning.
struct GNVignette: View {
    var light: GNLight

    var body: some View {
        RadialGradient(colors: [.clear, .clear, light.deep.opacity(light.isDay ? 0.28 : 0.4)], center: UnitPoint(x: 0.5, y: 0.42),
                       startRadius: 0, endRadius: 260)
            .blendMode(.multiply)
    }
}

// MARK: - The numeral

/// SF ultralight condensed: the lock screen's clock face. Three characters ("102", "-12") set smaller so they keep
/// clear of the summit.
enum GNNumeralFont {
    static func font(_ size: CGFloat) -> Font { .system(size: size, weight: .ultraLight).width(.condensed) }
}

struct GNGlyph: View {
    var text: String
    var font: Font
    var origin: CGPoint
    var size: CGSize

    var body: some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) {
                Text(text)
                    .font(font)
                    .fixedSize()
                    .alignmentGuide(.top) { $0[.firstTextBaseline] }
                    .offset(x: origin.x, y: origin.y)
            }
    }
}

/// The temperature, huge and thin, in pale fog-white: a soft shade behind it so it reads on any sky, a luminous
/// mist round it, its face graded from the crown to the foot; the fog and spruce in front are drawn after it.
struct GNNumeral: View {
    var text: String
    var spec: GNNumeralSpec
    var size: CGSize
    var light: GNLight

    var body: some View {
        let digits = text.filter { $0 != "°" }.count
        let fontSize = spec.size * (digits >= 3 ? 0.78 : 1)
        let glyph = GNGlyph(text: text, font: GNNumeralFont.font(fontSize), origin: CGPoint(x: spec.left, y: spec.baseline),
                            size: size)
        let k = fontSize / 200
        let top = UnitPoint(x: 0.5, y: (spec.baseline - 0.72 * fontSize) / size.height)
        let foot = UnitPoint(x: 0.5, y: spec.baseline / size.height)
        ZStack {
            glyph.foregroundStyle(light.deep)
                .blur(radius: 6 * k)
                .opacity(light.isDay ? 0.55 : 0.7)
            glyph.foregroundStyle(light.halo)
                .blur(radius: 9 * k)
                .opacity(light.isDay ? 0.4 : 0.32)
                .blendMode(.screen)
            // The edge away from the light, and the lit edge toward it (the light comes from the upper right).
            light.deep.opacity(0.42)
                .mask(glyph)
                .offset(x: -0.75 * k, y: 0.75 * k)
            Color.white.opacity(0.8)
                .mask(glyph)
                .offset(x: 0.5 * k, y: -0.5 * k)
            ZStack {
                LinearGradient(colors: light.face, startPoint: top, endPoint: foot)
                Mock.texture("weather-numeral/frost")
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(light.deep.opacity(0.14))
            }
            .compositingGroup()
            .mask(glyph)
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
    }
}

// MARK: - Sun, moon and weather

/// By day the sun is only a soft brightness in the fog; at night tonight's moon with a halo in the mist.
struct GNSkyBody: View {
    var clock: SkyClock
    var condition: SkyCondition
    var phase: MoonPhase
    var light: GNLight
    var radius: CGFloat

    var body: some View {
        if clock.isDay {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [light.glow.opacity(0.55), light.glow.opacity(0.18), .clear],
                                         center: .center, startRadius: 0, endRadius: radius * 4))
                    .frame(width: radius * 8, height: radius * 8)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFFBEF).opacity(0.9), Color(hex: 0xF4E7C2).opacity(0.5), .clear],
                                         center: .center, startRadius: 0, endRadius: radius * 1.1))
                    .frame(width: radius * 2.2, height: radius * 2.2)
                    .blur(radius: radius * 0.35)
            }
            .opacity(condition.gray ? 0.35 : 0.9)
        } else {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [light.glow.opacity(0.4), light.glow.opacity(0.12), .clear],
                                         center: .center, startRadius: radius * 0.6, endRadius: radius * 5.5))
                    .frame(width: radius * 11, height: radius * 11)
                ZStack {
                    Circle().fill(Color(hex: 0x2A3844).opacity(0.25))
                    Image("PaintMoon")
                        .resizable()
                        .scaledToFill()
                        .colorMultiply(Color(hex: 0xEEF2EE))
                        .clipShape(MoonLitShape(phase: phase))
                        .shadow(color: light.glow.opacity(0.9), radius: radius * 0.5)
                        .shadow(color: light.glow.opacity(0.5), radius: radius * 1.2)
                }
                .frame(width: radius * 2, height: radius * 2)
                // A band of mist drifting across the moon.
                Capsule()
                    .fill(light.light[0].opacity(0.5))
                    .frame(width: radius * 4.6, height: radius * 0.55)
                    .blur(radius: radius * 0.3)
                    .offset(x: -radius * 0.4, y: radius * 0.45)
            }
            .opacity(condition.gray ? 0.5 : 1)
        }
    }
}

/// Rain as a painted veil, snow as soft flakes, fog as banks of mist, all in the open sky.
struct GNWeatherFX: View {
    var condition: SkyCondition
    var light: GNLight
    var open: CGRect
    var seed: UInt64

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            let frame = CGRect(x: open.minX * s.width, y: open.minY * s.height, width: open.width * s.width, height: open.height * s.height)
            switch condition {
            case .rain, .storm:
                Mock.texture("weather-numeral/veil")
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(light.light[0].opacity(condition == .storm ? 0.3 : 0.24))
                    .frame(width: frame.width, height: frame.height)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0.0), .init(color: .black, location: 0.2),
                                                 .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .position(x: frame.midX, y: frame.midY)
            case .snow:
                Canvas { ctx, _ in
                    var rng = SeededRandom(seed &+ 31)
                    let u = s.width / 348
                    let count = Int(16 + 28 * frame.width * frame.height / (348 * 130))
                    let flake = Color(hex: 0xF4F5EF)
                    for _ in 0..<min(count, 44) {
                        let x = frame.minX + CGFloat(rng.next()) * frame.width
                        let y = frame.minY + CGFloat(0.06 + 0.94 * rng.next()) * frame.height
                        let r = (0.8 + CGFloat(rng.next()) * 1.1) * max(u, 0.7)
                        let halo = CGRect(x: x - r * 2.2, y: y - r * 2.2, width: r * 4.4, height: r * 4.4)
                        ctx.fill(Path(ellipseIn: halo), with: .radialGradient(Gradient(colors: [flake.opacity(0.32), .clear]),
                                                                            center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2.2))
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(flake.opacity(0.85)))
                    }
                }
            case .fog:
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(light.light[1].opacity(0.32))
                        .frame(width: frame.width * (0.7 + 0.1 * CGFloat(i)), height: frame.height * 0.08)
                        .blur(radius: frame.height * 0.035)
                        .position(x: frame.minX + frame.width * (0.4 + 0.1 * CGFloat(i)), y: frame.minY + frame.height * (0.5 + 0.14 * CGFloat(i)))
                }
            default:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Frosted glass

/// A pane of frosted, painted-mist glass at `rect` over the picture: the picture seen blurred through it under a fog
/// veil and brushed mist, a bright cut edge along the top, a darker one along the foot, and the shadow it casts.
struct GNGlass<Background: View>: View {
    var rect: CGRect
    var radius: CGFloat
    var light: GNLight
    var blur: CGFloat = 7
    var veil: Double = 0.28
    var smoke: Double = 0.1    // a breath of shade under the frost, so pale type keeps its contrast
    @ViewBuilder var background: Background

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack(alignment: .topLeading) {
            shape
                .fill(light.deep.opacity(light.isDay ? 0.4 : 0.55))
                .frame(width: rect.width, height: rect.height)
                .blur(radius: 5)
                .offset(x: rect.minX, y: rect.minY + 3)
            ZStack {
                // Not blur(opaque: true): ImageRenderer shifted its colours to maroon.
                background
                    .blur(radius: blur)
                light.deep.opacity(light.isDay ? smoke : smoke * 0.8)
                light.frost.opacity(veil)
                Mock.texture("weather-numeral/frost")
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(light.frost.opacity(light.isDay ? 0.3 : 0.2))
                LinearGradient(stops: [.init(color: Color.white.opacity(light.isDay ? 0.12 : 0.07), location: 0),
                                       .init(color: .clear, location: 0.45)],
                               startPoint: UnitPoint(x: 0.5, y: rect.minY / max(1, rect.maxY)), endPoint: .bottom)
            }
            .mask(alignment: .topLeading) {
                shape.frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
            }
            shape
                .strokeBorder(LinearGradient(stops: [.init(color: Color.white.opacity(0.55), location: 0),
                                                     .init(color: Color.white.opacity(0.1), location: 0.4),
                                                     .init(color: light.deep.opacity(0.35), location: 1)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
        .allowsHitTesting(false)
    }
}
