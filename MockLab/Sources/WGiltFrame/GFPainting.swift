import SwiftUI

// The oil painting inside each frame: the Matterhorn above the Riffelsee (make.py's riffelsee()), one value study
// glazed at run time for the hour and the weather: a golden day, an amber dusk, a moonlit night, grey rain and
// snow. The sun or moon crosses the sky on GFGeometry.arc and lays its path on the lake.

/// The glazes: shadow, mid and light colours of the three-stop gradient map, and the colour of the brightest lights.
struct GFLight {
    var shadow: [Color]
    var mid: [Color]
    var light: [Color]
    var glow: Color
    var glowStrength: Double
    var air: Double
    var isDay: Bool

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

    // Day: a golden sepia, umber shadows and cream lights warmed toward gold.
    private static let day = Stops(s0: RGB(0x2E1C0B), s1: RGB(0x211309), m0: RGB(0x9C743A), m1: RGB(0xA27B42),
                                   l0: RGB(0xF6E0A6), l1: RGB(0xFAEABD), glow: RGB(0xFCD478))
    // Sunrise and sunset: amber and rose.
    private static let dusk = Stops(s0: RGB(0x2A120A), s1: RGB(0x1C0B06), m0: RGB(0x935230), m1: RGB(0x9C5C38),
                                    l0: RGB(0xEDB27C), l1: RGB(0xF2C596), glow: RGB(0xF59A54))
    // Night: a moonlit nocturne in cool umber, the snow and the lake catching silver.
    private static let night = Stops(s0: RGB(0x090807), s1: RGB(0x060505), m0: RGB(0x24211D), m1: RGB(0x282420),
                                     l0: RGB(0x6C675D), l1: RGB(0x747064), glow: RGB(0xEEEADC))
    // Overcast, rain, snow and fog: grey taupe.
    private static let gray = Stops(s0: RGB(0x29221C), s1: RGB(0x1E1915), m0: RGB(0x6E6258), m1: RGB(0x776B60),
                                    l0: RGB(0xC6BBAC), l1: RGB(0xD2C8BA), glow: RGB(0xE8DECF))
    private static let grayNight = Stops(s0: RGB(0x110E0C), s1: RGB(0x0C0A08), m0: RGB(0x332D28), m1: RGB(0x3A332D),
                                         l0: RGB(0x7D7368), l1: RGB(0x887D71), glow: RGB(0xDAD0C0))

    init(clock: SkyClock, condition: SkyCondition) {
        var st: Stops
        var strength: Double, air: Double
        if clock.isDay {
            st = Self.day.mixed(Self.dusk, clock.twilight)
            strength = 0.85 + 0.15 * clock.twilight
            air = 0.24 + 0.12 * clock.twilight
        } else {
            st = Self.night.mixed(Self.dusk, clock.twilight * 0.5)
            strength = 0.95
            air = 0.26
        }
        if condition.gray {
            st = st.mixed(clock.isDay ? Self.gray : Self.grayNight, 0.75)
            strength *= 0.4
            air *= 0.35
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

/// The painting at the size of its frame's sight.
struct GFPainting: View {
    var family: Family
    var snapshot: DaySnapshot

    var body: some View {
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let condition = SkyCondition(code: snapshot.weather?.code)
        let light = GFLight(clock: clock, condition: condition)
        let size = GFGeometry.frame(family).sight.size
        let water = GFGeometry.water(family) * size.height
        let body = GFGeometry.arc(family).point(clock.progress, in: size)
        let center = UnitPoint(x: body.x / size.width, y: body.y / size.height)
        let reach = max(size.width, size.height) * 0.9
        let radius: CGFloat = family == .large ? 7.5 : 5.5
        ZStack(alignment: .topLeading) {
            GFGlaze(name: "painting-\(family.rawValue)", light: light, center: center, reach: reach)
            // The sun or moon, and its path on the water.
            GFSkyBody(isDay: clock.isDay, condition: condition, phase: MoonPhase(date: snapshot.date), light: light,
                      radius: radius)
                .position(body)
                .mask(alignment: .topLeading) { Rectangle().frame(width: size.width, height: water) }
            GFGlint(isDay: clock.isDay, condition: condition, light: light, radius: radius, length: size.height - water)
                .position(x: body.x, y: water + (size.height - water) * 0.42)
                .mask(alignment: .topLeading) {
                    Rectangle().frame(width: size.width, height: size.height - water).offset(y: water + 1)
                }
            GFPaintingWeather(condition: condition, light: light, size: size, water: water)
            CoverVarnish(strength: light.isDay ? 0.8 : 0.7)
            CoverCraquelure(seed: UInt64(17 + family.rawValue.count), cell: 6, opacity: light.isDay ? 1 : 0.6)
            CanvasWeave(opacity: 0.7)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

/// The value study glazed: shadow colour, then the lower and upper halves of the value as template images in the
/// mid and light colours, the air round the sun, then the brightest lights in the sun's (or moon's) colour.
struct GFGlaze: View {
    var name: String
    var light: GFLight
    var center: UnitPoint
    var reach: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(colors: light.shadow, startPoint: .top, endPoint: .bottom)
            Mock.texture("weather-gilt-frame/\(name)-lo")
                .resizable().renderingMode(.template).interpolation(.high)
                .foregroundStyle(LinearGradient(colors: light.mid, startPoint: .top, endPoint: .bottom))
            Mock.texture("weather-gilt-frame/\(name)-hi")
                .resizable().renderingMode(.template).interpolation(.high)
                .foregroundStyle(LinearGradient(colors: light.light, startPoint: .top, endPoint: .bottom))
            RadialGradient(colors: [light.glow.opacity(light.air), light.glow.opacity(light.air * 0.25), .clear],
                           center: center, startRadius: 0, endRadius: reach * 0.5)
                .blendMode(.screen)
            Mock.texture("weather-gilt-frame/\(name)-glow")
                .resizable().renderingMode(.template).interpolation(.high)
                .foregroundStyle(RadialGradient(colors: [light.glow, light.glow.opacity(0.5), light.glow.opacity(0.18)],
                                                center: center, startRadius: 0, endRadius: reach))
                .opacity(light.glowStrength)
        }
    }
}

/// The sun as a blaze in the haze, or tonight's moon in its halo.
struct GFSkyBody: View {
    var isDay: Bool
    var condition: SkyCondition
    var phase: MoonPhase
    var light: GFLight
    var radius: CGFloat

    var body: some View {
        if isDay {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [light.glow.opacity(0.7), light.glow.opacity(0.22), .clear],
                                         center: .center, startRadius: 0, endRadius: radius * 3.4))
                    .frame(width: radius * 6.8, height: radius * 6.8)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFF8E6), Color(hex: 0xFCE6B4).opacity(0.85), .clear],
                                         center: .center, startRadius: 0, endRadius: radius * 1.1))
                    .frame(width: radius * 2.2, height: radius * 2.2)
                    .blur(radius: radius * 0.2)
            }
            .opacity(condition.gray ? 0.35 : 1)
        } else {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [light.glow.opacity(0.45), light.glow.opacity(0.14), .clear],
                                         center: .center, startRadius: radius * 0.6, endRadius: radius * 5))
                    .frame(width: radius * 10, height: radius * 10)
                ZStack {
                    Circle().fill(Color(hex: 0x3A342C).opacity(0.1))
                    Image("PaintMoon")
                        .resizable()
                        .scaledToFill()
                        .colorMultiply(Color(hex: 0xF4EEDC))
                        .clipShape(MoonLitShape(phase: phase))
                        .shadow(color: light.glow.opacity(0.9), radius: radius * 0.5)
                }
                .frame(width: radius * 2, height: radius * 2)
            }
            .opacity(condition.gray ? 0.45 : 1)
        }
    }
}

/// The sun's or moon's path on the lake: a broken column of short level strokes, widening and fading toward the
/// viewer, laid like the touches of a loaded brush.
struct GFGlint: View {
    var isDay: Bool
    var condition: SkyCondition
    var light: GFLight
    var radius: CGFloat
    var length: CGFloat

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(23)
            let cx = size.width / 2
            let top = size.height / 2 - length * 0.42
            var y: CGFloat = top + 1
            while y < top + length {
                let f = (y - top) / length
                y += 1.6 + 2.6 * CGFloat(rng.next()) * (0.6 + f)
                if rng.next() < 0.3 { continue }
                let wdt = radius * (0.5 + 1.6 * f) * CGFloat(0.35 + 0.65 * rng.next())
                let x = cx + CGFloat(rng.signed()) * radius * (0.25 + 0.6 * f)
                let a = (1 - f * 0.8) * (0.35 + 0.65 * rng.next())
                let h: CGFloat = 0.7 + 0.5 * CGFloat(rng.next())
                ctx.fill(Path(roundedRect: CGRect(x: x - wdt / 2, y: y, width: wdt, height: h), cornerRadius: h / 2),
                         with: .color(light.glow.opacity(a)))
            }
        }
        .frame(width: radius * 8, height: length)
        .blur(radius: 0.55)
        .blendMode(.screen)
        .opacity(condition.gray ? 0.2 : (isDay ? 0.5 : 0.7))
    }
}

/// Rain as a painted veil over the sky and rings on the water, snow as soft flakes, fog as banks of mist.
struct GFPaintingWeather: View {
    var condition: SkyCondition
    var light: GFLight
    var size: CGSize
    var water: CGFloat

    var body: some View {
        switch condition {
        case .rain, .storm:
            ZStack(alignment: .topLeading) {
                Image("CoverVeil")
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .foregroundStyle(light.light[0].opacity(condition == .storm ? 0.42 : 0.34))
                    .frame(width: size.width, height: water + 6)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0.05), .init(color: .black, location: 0.3),
                                                 .init(color: .black, location: 0.85), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
                Canvas { ctx, s in
                    var rng = SeededRandom(41)
                    for _ in 0..<Int(10 + s.width / 9) {
                        let x = CGFloat(rng.next()) * s.width
                        let y = water + 3 + CGFloat(rng.next()) * (s.height - water - 6)
                        let r = (1.5 + CGFloat(rng.next()) * 2.5) * (0.6 + (y - water) / max(1, s.height - water))
                        ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.3, width: r * 2, height: r * 0.6)),
                                   with: .color(light.light[0].opacity(0.4)), lineWidth: 0.5)
                    }
                }
            }
        case .snow:
            Canvas { ctx, s in
                var rng = SeededRandom(31)
                let count = Int(18 + 30 * s.width * s.height / (200 * 190))
                for _ in 0..<min(count, 48) {
                    let x = CGFloat(rng.next()) * s.width
                    let y = CGFloat(0.04 + 0.92 * rng.next()) * s.height
                    let r = 0.7 + CGFloat(rng.next()) * 0.9
                    let halo = CGRect(x: x - r * 2.2, y: y - r * 2.2, width: r * 4.4, height: r * 4.4)
                    ctx.fill(Path(ellipseIn: halo), with: .radialGradient(Gradient(colors: [Color(hex: 0xF4EEE2).opacity(0.35), .clear]),
                                                                        center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 2.2))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(Color(hex: 0xF6F1E6).opacity(0.85)))
                }
            }
        case .fog:
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(light.light[1].opacity(0.32))
                        .frame(width: size.width * (0.8 + 0.1 * CGFloat(i)), height: size.height * 0.08)
                        .blur(radius: size.height * 0.03)
                        .position(x: size.width * (0.4 + 0.12 * CGFloat(i)), y: water - size.height * (0.06 + 0.1 * CGFloat(i)))
                }
            }
        default:
            EmptyView()
        }
    }
}
