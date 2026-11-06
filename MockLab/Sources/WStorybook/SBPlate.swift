import SwiftUI

// The painted plate behind every Weather widget, and what SwiftUI lays over it for the hour and the weather.
//
//     day or night plate  ->  dusk plate (faded in by SkyClock's twilight)  ->  sun or moon and its glitter path
//     on the water  ->  overcast deck (grey weather)  ->  rain, snow or mist
//
// The plates are painted in MockLab/Textures/weather-storybook/make.py (PLATES there holds the same waterline and
// bank as `water` and `bank` here). The sun and moon travel a small arc in the open sky right of the Matterhorn's
// summit, so they never stand behind the type or the peak; tonight's moon is drawn in its real phase.

struct SBPlateSpec {
    var name: String
    var arc: SkyArc          // where the sun and moon travel (fractions of the widget)
    var radius: CGFloat      // the moon's radius, pt
    var water: CGFloat       // the far shore's waterline (fraction of the height)
    var bank: CGFloat        // where the glitter path ends, at the near bank (fraction)

    static func of(_ family: Family) -> SBPlateSpec {
        switch family {
        case .large:
            return SBPlateSpec(name: "large", arc: SkyArc(centerX: 0.84, horizon: 0.36, radiusX: 0.09, radiusY: 0.24),
                               radius: 12.5, water: 0.6, bank: 0.85)
        case .medium:
            return SBPlateSpec(name: "medium", arc: SkyArc(centerX: 0.9, horizon: 0.42, radiusX: 0.05, radiusY: 0.27),
                               radius: 9, water: 0.66, bank: 0.88)
        case .small:
            return SBPlateSpec(name: "small", arc: SkyArc(centerX: 0.86, horizon: 0.36, radiusX: 0.045, radiusY: 0.2),
                               radius: 7.5, water: 0.7, bank: 0.86)
        }
    }
}

/// Colours that shift with the light: day, dusk and night, mixed by the clock.
struct SBLight {
    var isDay: Bool
    var twilight: Double

    init(_ clock: SkyClock) {
        isDay = clock.isDay
        twilight = clock.twilight
    }

    /// day, dusk, night as hex; mixed from the plain light toward dusk by the twilight.
    func pick(_ day: UInt32, _ dusk: UInt32, _ night: UInt32) -> Color {
        let base = isDay ? day : night
        func c(_ h: UInt32, _ s: Int) -> Double { Double((h >> s) & 0xFF) / 255 }
        let t = twilight
        return Color(.sRGB, red: c(base, 16) + (c(dusk, 16) - c(base, 16)) * t,
                     green: c(base, 8) + (c(dusk, 8) - c(base, 8)) * t,
                     blue: c(base, 0) + (c(dusk, 0) - c(base, 0)) * t)
    }
}

struct SBPlate: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        let size = Mock.size(family)
        let spec = SBPlateSpec.of(family)
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let condition = SkyCondition(code: snapshot.weather?.code)
        let light = SBLight(clock)
        ZStack(alignment: .topLeading) {
            plate(spec.name + (clock.isDay ? "-day" : "-night"))
            plate(spec.name + "-dusk").opacity(clock.twilight)
            if !condition.gray {
                SBLuminary(clock: clock, spec: spec, size: size, phase: MoonPhase(date: snapshot.date),
                           veiled: condition == .partly)
            }
            if condition.cloudy {
                SBDeck(spec: spec, light: light, condition: condition)
            }
            if condition.gray {
                SBTypeShade(family: family, size: size)
            }
            switch condition {
            case .rain, .storm: SBRain(spec: spec, size: size)
            case .snow: SBSnow(spec: spec, size: size)
            case .fog: SBMist(spec: spec, size: size, light: light)
            default: EmptyView()
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func plate(_ name: String) -> some View {
        Mock.texture("weather-storybook/\(name)")
            .resizable()
            .interpolation(.high)
            .frame(width: Mock.size(family).width, height: Mock.size(family).height)
    }
}

/// Under a grey sky the plate's own dark passage is covered, so a soft shade is laid back over the upper left, where
/// the type stands.
struct SBTypeShade: View {
    var family: Family
    var size: CGSize

    var body: some View {
        let (cx, cy, rx, ry): (CGFloat, CGFloat, CGFloat, CGFloat) = switch family {
        case .large: (0.2, 0.26, 0.5, 0.3)
        case .medium: (0.26, 0.38, 0.42, 0.55)
        case .small: (0.3, 0.32, 0.55, 0.45)
        }
        Ellipse()
            .fill(EllipticalGradient(colors: [SBInk.night.opacity(0.42), SBInk.night.opacity(0.18), .clear],
                                     center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
            .frame(width: rx * 2 * size.width, height: ry * 2 * size.height)
            .blur(radius: 8)
            .position(x: cx * size.width, y: cy * size.height)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The sun by day or tonight's moon, in a soft halo, and its glitter path across the lake below it.
struct SBLuminary: View {
    var clock: SkyClock
    var spec: SBPlateSpec
    var size: CGSize
    var phase: MoonPhase
    var veiled: Bool

    var body: some View {
        // Kept off the arc's ends, where it would set behind the trees.
        let progress = 0.12 + 0.76 * min(1, max(0, clock.progress))
        let at = spec.arc.point(progress, in: size)
        let r = spec.radius
        let warm = clock.isDay ? SBInk.sunlight : SBInk.moonlight
        let glow = clock.isDay ? Color(hex: 0xFFE8B0).opacity(0.55) : SBInk.moonlight.opacity(0.34)
        ZStack(alignment: .topLeading) {
            SBGlitter(x: at.x, spec: spec, size: size, color: warm, strength: (clock.isDay ? 0.6 : 1.1) * (veiled ? 0.5 : 1),
                      radius: r)
            Circle()
                .fill(RadialGradient(colors: [glow, glow.opacity(0.35), .clear], center: .center, startRadius: r * 0.8,
                                     endRadius: r * 4.6))
                .frame(width: r * 9.2, height: r * 9.2)
                .position(at)
            if clock.isDay {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFFBEA), Color(hex: 0xFCE7AE), Color(hex: 0xF1C676)],
                                         center: UnitPoint(x: 0.42, y: 0.4), startRadius: 0, endRadius: r))
                    .frame(width: r * 1.8, height: r * 1.8)
                    .shadow(color: Color(hex: 0xFFE7A8).opacity(0.9), radius: r * 0.5)
                    .position(at)
            } else {
                ZStack {
                    Circle().fill(Color(hex: 0x2A3A44).opacity(0.5))
                    Image("PaintMoon")
                        .resizable()
                        .scaledToFill()
                        .clipShape(MoonLitShape(phase: phase))
                        .shadow(color: SBInk.moonlight.opacity(0.7), radius: r * 0.35)
                }
                .frame(width: r * 2, height: r * 2)
                .position(at)
            }
        }
        .opacity(veiled ? 0.75 : 1)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Moonlight (or sunlight) broken into short level dabs on the water: a few near the far shore, more and wider
/// toward the near bank, scattered across a path that widens as it comes nearer, over a soft column of light.
struct SBGlitter: View {
    var x: CGFloat
    var spec: SBPlateSpec
    var size: CGSize
    var color: Color
    var strength: Double
    var radius: CGFloat

    var body: some View {
        let top = spec.water * size.height
        let bottom = spec.bank * size.height
        let unit = max(0.6, size.width / 348)
        ZStack(alignment: .topLeading) {
            Ellipse()
                .fill(color.opacity(0.26 * strength))
                .frame(width: 24 * unit, height: (bottom - top) * 0.9)
                .blur(radius: 7 * unit)
                .position(x: x, y: top + (bottom - top) * 0.45)
            // The moon's (or sun's) own image, broken on the water just below the far shore: a glow and three bright
            // level strokes.
            Ellipse()
                .fill(color.opacity(0.4 * strength))
                .frame(width: radius * 2.6, height: radius * 0.7)
                .blur(radius: 2.4 * unit)
                .position(x: x, y: top + radius * 0.55 + 1.5)
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(color.opacity((0.95 - 0.2 * Double(i)) * strength))
                    .frame(width: radius * (1.5 - 0.3 * CGFloat(i)), height: max(0.8, 0.9 * unit))
                    .position(x: x + CGFloat([0, -1.5, 1.2][i]) * unit, y: top + 2 + CGFloat(i) * 2.2 * unit)
            }
            Canvas { ctx, _ in
                var rng = SeededRandom(29)
                var y = top + 1
                while y < bottom - 1 {
                    let t = Double((y - top) / max(1, bottom - top))
                    let spread = CGFloat(1.5 + 13 * t) * unit
                    let count = 1 + Int(rng.next() * (1.5 + 2.5 * t))
                    for _ in 0..<count {
                        let off = CGFloat(rng.signed()) * spread
                        let near = 1 - Double(abs(off) / max(1, spread)) * 0.7
                        let half = CGFloat(1.0 + 4.4 * t) * unit * CGFloat(0.35 + rng.next())
                        let h = CGFloat(0.65 + 0.9 * t) * unit
                        let a = (0.95 - 0.35 * t) * (0.3 + 0.7 * rng.next()) * near * strength
                        ctx.fill(Capsule().path(in: CGRect(x: x + off - half, y: y, width: 2 * half, height: h)),
                                 with: .color(color.opacity(a)))
                    }
                    y += CGFloat(0.9 + 2.2 * t + 1.2 * rng.next()) * unit
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .mask {
            Mock.texture("weather-storybook/\(spec.name)-lake")
                .resizable()
                .frame(width: size.width, height: size.height)
        }
    }
}

/// The overcast deck (a ceiling of painted billows over the sky and in its reflection), or on a part-cloudy day a few
/// whole clouds, in the colour of the hour.
struct SBDeck: View {
    var spec: SBPlateSpec
    var light: SBLight
    var condition: SkyCondition

    var body: some View {
        let dark = condition == .rain || condition == .storm
        let snow = condition == .snow
        let body = dark ? light.pick(0x7E888C, 0x5A4C5C, 0x18242E)
            : snow ? light.pick(0x9EA6A8, 0x7C6C78, 0x2C3A44)
            : light.pick(0x98A2A6, 0x6E5C6C, 0x1E2C38)
        let lit = dark ? light.pick(0xBFC3C0, 0xB08478, 0x34485A)
            : snow ? light.pick(0xE4E4DC, 0xD8B09C, 0x5C7280)
            : light.pick(0xE6E1D2, 0xD9A088, 0x4C6270)
        // A part-cloudy sky gets a few whole clouds; every grey sky gets the deck.
        let layer = condition == .partly ? "scatter" : "deck"
        let amount: Double = condition == .fog ? 0.75 : 1
        ZStack {
            tex(layer).foregroundStyle(body).opacity(amount)
            tex(layer + "-lit").foregroundStyle(lit).opacity(amount * 0.9)
        }
    }

    private func tex(_ suffix: String) -> some View {
        Mock.texture("weather-storybook/\(spec.name)-\(suffix)")
            .renderingMode(.template)
            .resizable()
    }
}

/// Rain: fine slanting strokes across the picture and rings opening on the lake.
struct SBRain: View {
    var spec: SBPlateSpec
    var size: CGSize

    var body: some View {
        let unit = size.width / 348
        ZStack {
            Canvas { ctx, s in
                var rng = SeededRandom(41)
                let n = Int(130 * s.width * s.height / (348 * 365))
                for _ in 0..<n {
                    let x = CGFloat(rng.next()) * s.width * 1.1
                    let y = CGFloat(rng.next()) * s.height * spec.bank
                    let len = CGFloat(6 + 8 * rng.next()) * unit
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - len * 0.28, y: y + len))
                    ctx.stroke(p, with: .color(Color(hex: 0xC8D6DC).opacity(0.18 + 0.25 * rng.next())),
                               lineWidth: 0.7 * max(1, unit))
                }
            }
            Canvas { ctx, s in
                var rng = SeededRandom(43)
                let top = spec.water * s.height, bottom = spec.bank * s.height
                for _ in 0..<Int(40 * s.width / 348) {
                    let y = top + CGFloat(rng.next()) * (bottom - top)
                    let t = (y - top) / max(1, bottom - top)
                    let w = (3 + 6 * t) * unit
                    let rect = CGRect(x: CGFloat(rng.next()) * s.width - w / 2, y: y, width: w, height: w * 0.28)
                    ctx.stroke(Ellipse().path(in: rect), with: .color(Color(hex: 0xC8D6DC).opacity(0.35)), lineWidth: 0.5)
                }
            }
            .mask {
                Mock.texture("weather-storybook/\(spec.name)-lake").resizable()
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Snow: soft flakes of every size drifting over the whole picture.
struct SBSnow: View {
    var spec: SBPlateSpec
    var size: CGSize

    var body: some View {
        let unit = size.width / 348
        Canvas { ctx, s in
            var rng = SeededRandom(47)
            let n = Int(150 * s.width * s.height / (348 * 365))
            for _ in 0..<n {
                let r = CGFloat(0.6 + 1.5 * pow(rng.next(), 2)) * max(1, unit)
                let c = CGPoint(x: CGFloat(rng.next()) * s.width, y: CGFloat(rng.next()) * s.height)
                ctx.fill(Circle().path(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(Color(hex: 0xF6F2E6).opacity(0.55 + 0.4 * rng.next())))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Fog: level banks of mist over the water and the mountain's foot.
struct SBMist: View {
    var spec: SBPlateSpec
    var size: CGSize
    var light: SBLight

    var body: some View {
        let c = light.pick(0xD8DCD6, 0xB89A9A, 0x40525C)
        ZStack(alignment: .topLeading) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(c.opacity(0.55 - 0.1 * Double(i)))
                    .frame(width: size.width * (0.9 - 0.15 * CGFloat(i)), height: size.height * 0.07)
                    .blur(radius: 6)
                    .position(x: size.width * (0.45 + 0.12 * CGFloat(i)),
                              y: size.height * (spec.water - 0.06 + 0.09 * CGFloat(i)))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}
