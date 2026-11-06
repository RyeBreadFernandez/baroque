import SwiftUI

// The painting behind every Old Master Cover widget, and the giant gilt glyph that stands inside it.
//
// Each canvas is one value study painted in MockLab/Textures/old-master-cover/make.py and glazed at run time exactly
// as Old Master does (shadow colour, then the lower and upper halves of the value as template images in a warm mid
// colour and the light colour, then the brightest lights in the colour of the sun or moon). What is new is depth:
//
//     painting  ->  sun or moon  ->  hero glyph  ->  the same painting through <canvas>-front  ->  weather, varnish
//
// The front mask holds the Matterhorn, the foreground with its firs and one small puff of cloud, so the mountain's
// shoulder runs down in front of the numeral's foot and the cloud drifts across it: the magazine-cover overlap. The
// summit and its hook stand in open sky beside the glyph. The skyline is the Matterhorn's own, traced from a
// photograph taken at the Riffelsee above Zermatt (see make.py and matterhorn.json), at one scale, never exaggerated.
//
// The textures are alpha PNGs at 1 px per point of the iPhone 17 widget sizes, copied into PaintTextures.xcassets
// by scripts/export_cover_textures.py (day-large-lo.png -> CoverDayLargeLo). Every view here is laid out at those
// design sizes; CoverFrame scales the finished widget to the phone's actual widget size.

/// One painted canvas: its textures, where the hero glyph stands, where the sun and moon travel, the open sky.
/// The raw values are the texture file names in MockLab (they also seed the cracks and the snow).
enum CoverCanvas: String {
    case dayLarge = "day-large", dayMedium = "day-medium", daySmall = "day-small"
    case quoteLarge = "quote-large", quoteMedium = "quote-medium", quoteSmall = "quote-small"

    /// The asset catalog name: "day-large" -> "CoverDayLarge".
    private var asset: String {
        switch self {
        case .dayLarge: return "CoverDayLarge"
        case .dayMedium: return "CoverDayMedium"
        case .daySmall: return "CoverDaySmall"
        case .quoteLarge: return "CoverQuoteLarge"
        case .quoteMedium: return "CoverQuoteMedium"
        case .quoteSmall: return "CoverQuoteSmall"
        }
    }

    var lower: Image { Image(asset + "Lo") }
    var upper: Image { Image(asset + "Hi") }
    var glow: Image { Image(asset + "Glow") }
    var front: Image { Image(asset + "Front") }

    var isLarge: Bool { self == .dayLarge || self == .quoteLarge }
    var isQuote: Bool { self == .quoteLarge || self == .quoteMedium || self == .quoteSmall }

    /// The hero glyph's geometry in points, as painted round in make.py (HEROES there).
    var hero: CoverHeroSpec {
        switch self {
        case .dayLarge: return .digits(centerX: 248, baseline: 192, one: 212, two: 168)
        case .dayMedium: return .digits(centerX: 118, baseline: 104, one: 112, two: 84)
        case .daySmall: return .digits(centerX: 116, baseline: 102, one: 110, two: 82)
        case .quoteLarge: return .quote(left: 14, top: 24, size: 400)
        case .quoteMedium: return .quote(left: 14, top: 20, size: 176)
        case .quoteSmall: return .quote(left: 10, top: 12, size: 170)
        }
    }

    /// The arc the sun (or moon) follows across the open sky, in fractions of the widget: kept in the sky the glyph
    /// and the Matterhorn leave open (over the summit, or between the summit ridge and the glyph), so it is seen most
    /// of the day. It rises and sets behind the mountain's flanks; a two-digit date can still cover it, and the gilt
    /// then takes its brightest light from behind.
    var arc: SkyArc {
        switch self {
        case .dayLarge: return SkyArc(centerX: 0.5, horizon: 0.45, radiusX: 0.44, radiusY: 0.42)
        case .quoteLarge: return SkyArc(centerX: 0.82, horizon: 0.24, radiusX: 0.1, radiusY: 0.17)
        case .dayMedium: return SkyArc(centerX: 0.36, horizon: 0.2, radiusX: 0.08, radiusY: 0.14)
        case .quoteMedium: return SkyArc(centerX: 0.12, horizon: 0.13, radiusX: 0.1, radiusY: 0.08)
        case .daySmall: return SkyArc(centerX: 0.58, horizon: 0.2, radiusX: 0.1, radiusY: 0.12)
        case .quoteSmall: return SkyArc(centerX: 0.8, horizon: 0.3, radiusX: 0.1, radiusY: 0.2)
        }
    }

    /// The sky (fractions), where rain and snow fall.
    var openSky: CGRect {
        switch self {
        case .dayLarge: return CGRect(x: 0, y: 0, width: 1, height: 0.58)
        case .quoteLarge: return CGRect(x: 0, y: 0, width: 1, height: 0.48)
        case .dayMedium: return CGRect(x: 0, y: 0, width: 0.47, height: 0.84)
        case .quoteMedium: return CGRect(x: 0, y: 0, width: 0.43, height: 0.86)
        case .daySmall: return CGRect(x: 0, y: 0, width: 1, height: 0.72)
        case .quoteSmall: return CGRect(x: 0, y: 0, width: 1, height: 0.5)
        }
    }
}

/// Where the hero glyph stands. Baskerville's digits are lining and tabular (0.655 em tall on the baseline, half an
/// em wide each); its italic opening quote is 0.265 em tall and 0.405 em wide, inked from 0.14 em in.
enum CoverHeroSpec {
    case digits(centerX: CGFloat, baseline: CGFloat, one: CGFloat, two: CGFloat)
    case quote(left: CGFloat, top: CGFloat, size: CGFloat)

    struct Placement {
        var text: String
        var font: Font
        var origin: CGPoint   // leading edge of the text and its baseline
        var ink: CGRect       // the glyph's inked box (approximate), for its light
    }

    func place(_ text: String) -> Placement {
        switch self {
        case let .digits(cx, baseline, one, two):
            let n = CGFloat(max(1, text.count))
            let size = n > 1 ? two : one
            let half = 0.23 * size * n
            return Placement(text: text, font: .custom("Baskerville", size: size),
                             origin: CGPoint(x: cx - 0.25 * size * n, y: baseline),
                             ink: CGRect(x: cx - half, y: baseline - 0.655 * size, width: 2 * half, height: 0.655 * size))
        case let .quote(left, top, size):
            return Placement(text: "\u{201C}", font: .custom("Baskerville-Italic", size: size),
                             origin: CGPoint(x: left - 0.14 * size, y: top + 0.66 * size),
                             ink: CGRect(x: left, y: top, width: 0.405 * size, height: 0.265 * size))
        }
    }
}

/// The glazes for the time of day and the weather (Old Master's three stops and sun colour), plus the gilt of the
/// hero glyph: its lit face, foot, the bright rim toward the light and the dark depth away from it.
struct CoverLight {
    var shadow: [Color]
    var mid: [Color]
    var light: [Color]
    var glow: Color
    var glowStrength: Double
    var air: Double
    var isDay: Bool
    var gild: [Color]      // face: crown, middle, foot
    var rim: Color
    var deep: Color

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
        var g0, g1, g2, rim, deep: RGB
        func mixed(_ o: Stops, _ t: Double) -> Stops {
            Stops(s0: s0.mixed(o.s0, t), s1: s1.mixed(o.s1, t), m0: m0.mixed(o.m0, t), m1: m1.mixed(o.m1, t),
                  l0: l0.mixed(o.l0, t), l1: l1.mixed(o.l1, t), glow: glow.mixed(o.glow, t),
                  g0: g0.mixed(o.g0, t), g1: g1.mixed(o.g1, t), g2: g2.mixed(o.g2, t), rim: rim.mixed(o.rim, t),
                  deep: deep.mixed(o.deep, t))
        }
    }

    // Day: chocolate shadows, warm umber, peach-cream lights; the gilt pale where the sun strikes, ochre at the foot.
    private static let day = Stops(s0: RGB(0x2C1810), s1: RGB(0x1E100A), m0: RGB(0x8A5F47), m1: RGB(0x946A50),
                                   l0: RGB(0xEBD1B2), l1: RGB(0xF3E1C8), glow: RGB(0xF7CDA0),
                                   g0: RGB(0xF8E4BC), g1: RGB(0xEDC28A), g2: RGB(0xC68E55), rim: RGB(0xFFF5DE), deep: RGB(0x4A2E1C))
    // Sunrise and sunset: amber.
    private static let dusk = Stops(s0: RGB(0x2A130A), s1: RGB(0x1A0B05), m0: RGB(0x8F5134), m1: RGB(0x9A5C3B),
                                    l0: RGB(0xE9B185), l1: RGB(0xF0C49A), glow: RGB(0xF4A064),
                                    g0: RGB(0xF8D9AE), g1: RGB(0xEDB077), g2: RGB(0xBC7643), rim: RGB(0xFFE6C2), deep: RGB(0x452416))
    // Night: an umber nocturne; the gilt turns to moonlit cream, still the brightest thing in the picture.
    private static let night = Stops(s0: RGB(0x0E0805), s1: RGB(0x090503), m0: RGB(0x30221A), m1: RGB(0x372820),
                                     l0: RGB(0x7E6A57), l1: RGB(0x8C7762), glow: RGB(0xF3E6CC),
                                     g0: RGB(0xEFE5D0), g1: RGB(0xD3C2A3), g2: RGB(0x9C876A), rim: RGB(0xFBF4E6), deep: RGB(0x1C130D))
    // Overcast, rain, snow and fog: grey taupe; the gilt goes to pewter cream.
    private static let gray = Stops(s0: RGB(0x2A211B), s1: RGB(0x1E1814), m0: RGB(0x6E6157), m1: RGB(0x776A5F),
                                    l0: RGB(0xC2B6A7), l1: RGB(0xCFC4B6), glow: RGB(0xE6DACA),
                                    g0: RGB(0xF0E6D6), g1: RGB(0xD9C8B0), g2: RGB(0xA8927A), rim: RGB(0xFAF5EC), deep: RGB(0x3A3029))
    private static let grayNight = Stops(s0: RGB(0x120E0B), s1: RGB(0x0C0907), m0: RGB(0x342C26), m1: RGB(0x3B322B),
                                         l0: RGB(0x7C7064), l1: RGB(0x887B6E), glow: RGB(0xD9CDBA),
                                         g0: RGB(0xE2DACC), g1: RGB(0xC0B4A2), g2: RGB(0x8A7D6C), rim: RGB(0xF2ECE2), deep: RGB(0x1A1511))

    init(clock: SkyClock, condition: SkyCondition) {
        var st: Stops
        var strength: Double, air: Double
        if clock.isDay {
            st = Self.day.mixed(Self.dusk, clock.twilight)
            strength = 0.8 + 0.15 * clock.twilight
            air = 0.2 + 0.12 * clock.twilight
        } else {
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
        gild = [st.g0.color, st.g1.color, st.g2.color]
        rim = st.rim.color
        deep = st.deep.color
    }
}

/// The glazed paint with its old varnish and cracks (no sky body): drawn once behind the glyph and once in front of
/// it through the mask. The gilt is laid on top of the varnish, so it keeps its brilliance.
struct CoverPaint: View {
    var canvas: CoverCanvas
    var light: CoverLight
    var center: UnitPoint
    var reach: CGFloat

    var body: some View {
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
            CoverVarnish(strength: light.isDay ? 1 : 0.8)
            CoverCraquelure(seed: UInt64(canvas.rawValue.count) &* 7, opacity: light.isDay ? 1 : 0.7)
        }
    }
}

/// The whole picture: the painting, the sun or moon, the hero glyph standing in it, the peak, firs and cloud in front
/// of the glyph, the weather, and the surface of an old canvas over all of it.
struct CoverScene: View {
    var canvas: CoverCanvas
    var glyph: String
    var clock: SkyClock
    var condition: SkyCondition
    var phase: MoonPhase

    var body: some View {
        let light = CoverLight(clock: clock, condition: condition)
        GeometryReader { geo in
            let size = geo.size
            let u = size.width / 348
            let body = canvas.arc.point(clock.progress, in: size)
            let center = UnitPoint(x: body.x / size.width, y: body.y / size.height)
            let reach = max(size.width, size.height) * (canvas.isLarge ? 0.55 : 0.75)
            let place = canvas.hero.place(glyph)
            ZStack {
                CoverPaint(canvas: canvas, light: light, center: center, reach: reach)
                CoverSkyBody(clock: clock, condition: condition, phase: phase, light: light,
                             radius: (canvas.isLarge ? 9 : 7) * max(u, 0.6))
                    .position(body)
                CoverHero(place: place, light: light, sun: body, size: size, front: canvas.front, scale: canvas.isLarge ? 1 : 0.7)
                // Flattened before masking: masked as a loose stack, its soft edge took the mask twice and drew a dark
                // seam round the peak.
                CoverPaint(canvas: canvas, light: light, center: center, reach: reach)
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

// MARK: - The hero glyph

/// The glyph set at its placement inside a frame the size of the widget (baseline-aligned, so it matches make.py).
struct CoverGlyph: View {
    var place: CoverHeroSpec.Placement
    var size: CGSize

    var body: some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) {
                Text(place.text)
                    .font(place.font)
                    .fixedSize()
                    .alignmentGuide(.top) { $0[.firstTextBaseline] }
                    .offset(x: place.origin.x, y: place.origin.y)
            }
    }
}

/// The numeral (or the opening quote) as raised gilt catching the painting's light: a warm bloom spilling toward
/// the sun and a soft umber shadow thrown away from it, the leaf's depth on the shadow side and a bright rim on the lit
/// side, a face graded from the lit crown to an ochre foot and brightened round the sun, faint brushwork in the leaf,
/// and the soft shade the peak and the cloud throw back onto it where they pass in front.
struct CoverHero: View {
    var place: CoverHeroSpec.Placement
    var light: CoverLight
    var sun: CGPoint
    var size: CGSize
    var front: Image
    var scale: CGFloat

    var body: some View {
        let glyph = CoverGlyph(place: place, size: size)
        let ink = place.ink
        let dx = sun.x - ink.midX, dy = sun.y - ink.midY
        let len = max(1, (dx * dx + dy * dy).squareRoot())
        let to = CGSize(width: dx / len, height: dy / len)  // toward the sun
        let top = UnitPoint(x: 0.5, y: ink.minY / size.height)
        let foot = UnitPoint(x: 0.5, y: ink.maxY / size.height)
        let sunPoint = UnitPoint(x: sun.x / size.width, y: sun.y / size.height)
        ZStack {
            glyph.foregroundStyle(CoverInk.shadow)
                .blur(radius: 8 * scale)
                .offset(x: -to.width * 3 * scale, y: -to.height * 3 * scale + 1.5 * scale)
                .opacity(light.isDay ? 0.5 : 0.6)
            glyph.foregroundStyle(light.glow)
                .blur(radius: 11 * scale)
                .offset(x: to.width * 2.5 * scale, y: to.height * 2.5 * scale)
                .opacity(light.isDay ? 0.32 : 0.26)
                .blendMode(.screen)
            light.deep
                .mask(glyph)
                .offset(x: -to.width * 2.2 * scale, y: -to.height * 2.2 * scale + 0.6 * scale)
            light.rim
                .mask(glyph)
                .offset(x: to.width * 0.9 * scale, y: to.height * 0.9 * scale)
            ZStack {
                LinearGradient(stops: [.init(color: light.gild[0], location: 0), .init(color: light.gild[1], location: 0.5),
                                       .init(color: light.gild[2], location: 1)],
                               startPoint: top, endPoint: foot)
                RadialGradient(colors: [light.rim.opacity(0.6), light.rim.opacity(0.2), .clear], center: sunPoint,
                               startRadius: 0, endRadius: max(size.width, size.height) * 0.62)
                // 0.205, not the mock's 0.16: MockLab loaded this through NSImage, which tints a template with a
                // translucent colour more heavily than the asset catalog does; this matches what the mock showed.
                Image("CoverGilt")
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(light.deep.opacity(0.205))
                // The shade of whatever passes in front: the horn of the peak, the firs, the drifting cloud.
                light.deep.opacity(0.5)
                    .mask { front.resizable().interpolation(.high).blur(radius: 3.5 * scale) }
            }
            .compositingGroup()
            .mask(glyph)
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
    }
}

// MARK: - Sky body and weather (Old Master's, glazed with this light)

/// The sun as a blaze half lost in cloud, or tonight's moon glowing through a veil of cloud.
struct CoverSkyBody: View {
    var clock: SkyClock
    var condition: SkyCondition
    var phase: MoonPhase
    var light: CoverLight
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
                Capsule()
                    .fill(light.lightTop.opacity(0.45))
                    .frame(width: radius * 4.2, height: radius * 0.6)
                    .blur(radius: radius * 0.28)
                    .offset(x: radius * 0.5, y: radius * 0.5)
            }
            .opacity(condition.gray ? 0.55 : 1)
        }
    }
}

/// Rain as a painted veil hanging from the cloud, snow as a few soft flakes, fog as banks of mist, all kept in the
/// open sky (they pass in front of the glyph, thinly).
struct CoverWeather: View {
    var condition: SkyCondition
    var light: CoverLight
    var open: CGRect
    var seed: UInt64

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            let frame = CGRect(x: open.minX * s.width, y: open.minY * s.height, width: open.width * s.width, height: open.height * s.height)
            switch condition {
            case .rain, .storm:
                // 0.2 and 0.26, not the mock's 0.55 and 0.7: through NSImage the mock's light veil came out far
                // fainter than its numbers say, and these match the rain it showed.
                Image("CoverVeil")
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(light.lightTop.opacity(condition == .storm ? 0.26 : 0.2))
                    .frame(width: frame.width, height: frame.height)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0.0), .init(color: .black, location: 0.25),
                                                 .init(color: .black, location: 0.75), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .position(x: frame.midX, y: frame.midY)
            case .snow:
                Canvas { ctx, _ in
                    var rng = SeededRandom(seed &+ 31)
                    let u = s.width / 348
                    let count = Int(14 + 26 * frame.width * frame.height / (348 * 130))
                    for _ in 0..<min(count, 40) {
                        let x = frame.minX + CGFloat(rng.next()) * frame.width
                        let y = frame.minY + CGFloat(0.08 + 0.92 * rng.next()) * frame.height
                        let r = (0.9 + CGFloat(rng.next()) * 1.1) * max(u, 0.7)
                        let halo = CGRect(x: x - r * 2.2, y: y - r * 2.2, width: r * 4.4, height: r * 4.4)
                        ctx.fill(Path(ellipseIn: halo), with: .radialGradient(Gradient(colors: [CoverInk.cream.opacity(0.35), .clear]),
                                                                            center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2.2))
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(CoverInk.cream.opacity(0.85)))
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

// MARK: - Type on the picture

extension View {
    /// Type set on the painted sky: Old Master's soft umber halo under each letter plus a soft local pool of shade
    /// behind the words (an ellipse feathered away to nothing, never a box), so it reads on any cloud.
    func coverOnSky(_ strength: Double = 1) -> some View {
        self
            .background {
                Ellipse()
                    .fill(CoverInk.shadow.opacity(0.42 * strength))
                    .padding(.horizontal, -12)
                    .padding(.vertical, -8)
                    .blur(radius: 9)
            }
            .coverOnPaint(strength)
    }
}

/// The painting's title, set small in the italic like the label on a frame: the mountain is the Matterhorn.
struct CoverPaintingTitle: View {
    var body: some View {
        Text("Matterhorn \u{00B7} 14,692 ft")
            .font(CoverType.italic(9.5))
            .tracking(0.2)
            .foregroundStyle(CoverInk.creamSoft)
            .lineLimit(1)
            .fixedSize()
            .coverOnSky(0.85)
            .accessibilityLabel("Matterhorn, 14,692 feet")
    }
}
