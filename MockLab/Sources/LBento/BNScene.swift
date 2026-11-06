import SwiftUI

// The scene under the tiles. It is painted across the whole widget (so the gutters show it), but composed
// for the window tile: the arc, the sun or moon and the ridge crests are placed in fractions of the window,
// then converted to the widget's unit coordinates that MountainRange and SkyArc use.

/// Where the scene's pieces go for one widget size.
struct BNScenePlan {
    var horizon: CGFloat              // PaintedSky's horizon, fraction of the widget
    var arc: SkyArc
    var bodyRadius: CGFloat           // sun or moon, points
    var unit: CGFloat                 // scale of clouds, rain and snow (1 = the shipped large widget)
    var trail: Bool                   // the dotted arc of the day
    var layers: [MountainLayer]
    var mist: ClosedRange<CGFloat>    // band of valley haze, fractions of the widget height
    var stars: CGRect                 // unit coordinates of the widget

    /// Builds a plan from window fractions.
    init(window w: CGRect, canvas c: CGSize, arcCenter: CGFloat = 0.5, arcHorizon: CGFloat,
         arcRadius: (x: CGFloat, y: CGFloat), bodyRadius: CGFloat, unit: CGFloat, trail: Bool,
         layers: [MountainLayer], mist: ClosedRange<CGFloat>, stars: CGRect) {
        let o = BN.unit(arcCenter, arcHorizon, in: w, of: c)
        horizon = o.y
        arc = SkyArc(centerX: o.x, horizon: o.y, radiusX: arcRadius.x * w.width / c.width,
                     radiusY: arcRadius.y * w.height / c.height)
        self.bodyRadius = bodyRadius
        self.unit = unit
        self.trail = trail
        self.layers = layers
        let lo = BN.unit(0, mist.lowerBound, in: w, of: c).y, hi = BN.unit(0, mist.upperBound, in: w, of: c).y
        self.mist = lo...hi
        let s0 = BN.unit(stars.minX, stars.minY, in: w, of: c), s1 = BN.unit(stars.maxX, stars.maxY, in: w, of: c)
        self.stars = CGRect(x: s0.x, y: s0.y, width: s1.x - s0.x, height: s1.y - s0.y)
    }

    private static let far = Ridges.far, mid = Ridges.mid, near = Ridges.near

    private static func snow(_ y: CGFloat, _ w: CGRect, _ c: CGSize) -> CGFloat { BN.unit(0, y, in: w, of: c).y }

    // MARK: Day

    static func day(_ size: BaroqueSize, window w: CGRect, canvas c: CGSize) -> BNScenePlan {
        func r(_ k: [(CGFloat, CGFloat)], _ seed: UInt64, _ rough: CGFloat = 0.2) -> RidgeProfile {
            BN.ridge(k, window: w, size: c, seed: seed, roughness: rough)
        }
        switch size {
        case .large:
            // The hero window: today's arc spans it; the big peak stands right of the sun's morning path.
            return BNScenePlan(
                window: w, canvas: c, arcHorizon: 0.8, arcRadius: (0.34, 0.55), bodyRadius: 8.5, unit: 1, trail: true,
                layers: [
                    MountainLayer(profile: r([(0, 0.66), (0.08, 0.61), (0.17, 0.64), (0.27, 0.56), (0.35, 0.6), (0.45, 0.43),
                                              (0.52, 0.49), (0.6, 0.37), (0.68, 0.45), (0.78, 0.52), (0.88, 0.48), (1, 0.6)], 11),
                                  top: far.top, bottom: far.bottom, rim: 0.6, snowline: snow(0.52, w, c)),
                    MountainLayer(profile: r([(0, 0.72), (0.1, 0.68), (0.22, 0.73), (0.35, 0.65), (0.48, 0.71), (0.62, 0.63),
                                              (0.76, 0.7), (0.9, 0.66), (1, 0.72)], 23),
                                  top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 4...7, spacing: 5, coverage: 0.55)),
                    MountainLayer(profile: r([(0, 0.8), (0.15, 0.77), (0.32, 0.82), (0.5, 0.765), (0.7, 0.8), (0.85, 0.755),
                                              (1, 0.79)], 31),
                                  top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 6...10, spacing: 5, coverage: 0.8))
                ],
                mist: 0.56...0.78, stars: CGRect(x: 0.06, y: 0.16, width: 0.88, height: 0.3))
        case .medium:
            // A landscape strip under the date and temperature: a small sun on a small arc, three ridges.
            return BNScenePlan(
                window: w, canvas: c, arcHorizon: 0.78, arcRadius: (0.36, 0.56), bodyRadius: 5, unit: 0.55, trail: true,
                layers: [
                    MountainLayer(profile: r([(0, 0.72), (0.12, 0.64), (0.22, 0.68), (0.34, 0.58), (0.44, 0.62), (0.55, 0.48),
                                              (0.62, 0.42), (0.7, 0.5), (0.8, 0.57), (0.9, 0.53), (1, 0.64)], 41),
                                  top: far.top, bottom: far.bottom, rim: 0.6, snowline: snow(0.58, w, c)),
                    MountainLayer(profile: r([(0, 0.78), (0.15, 0.72), (0.3, 0.77), (0.45, 0.7), (0.6, 0.75), (0.78, 0.69),
                                              (1, 0.76)], 43),
                                  top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 3.5...6, spacing: 4.5, coverage: 0.55)),
                    MountainLayer(profile: r([(0, 0.87), (0.2, 0.83), (0.4, 0.875), (0.6, 0.82), (0.8, 0.865), (1, 0.835)], 47),
                                  top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 5...8, spacing: 5, coverage: 0.8))
                ],
                mist: 0.58...0.8, stars: CGRect(x: 0.06, y: 0.2, width: 0.88, height: 0.28))
        case .small:
            // The weather window: sky and sun above, the temperature written on the dark near ridge below.
            return BNScenePlan(
                window: w, canvas: c, arcHorizon: 0.56, arcRadius: (0.36, 0.42), bodyRadius: 5.5, unit: 0.47, trail: true,
                layers: [
                    MountainLayer(profile: r([(0, 0.5), (0.12, 0.45), (0.25, 0.48), (0.4, 0.38), (0.5, 0.42), (0.62, 0.3),
                                              (0.72, 0.36), (0.84, 0.42), (1, 0.46)], 51),
                                  top: far.top, bottom: far.bottom, rim: 0.6, snowline: snow(0.42, w, c)),
                    MountainLayer(profile: r([(0, 0.56), (0.2, 0.52), (0.4, 0.57), (0.6, 0.5), (0.8, 0.55), (1, 0.52)], 53),
                                  top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 6...9, spacing: 9, coverage: 0.6)),
                    MountainLayer(profile: r([(0, 0.64), (0.25, 0.61), (0.5, 0.65), (0.75, 0.6), (1, 0.63)], 57),
                                  top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 9...13, spacing: 10, coverage: 0.7))
                ],
                mist: 0.42...0.6, stars: CGRect(x: 0.08, y: 0.16, width: 0.84, height: 0.24))
        }
    }
}

// MARK: - Day scene

struct BNDayScene: View {
    var snapshot: DaySnapshot
    var plan: BNScenePlan

    var body: some View {
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let condition = SkyCondition(code: snapshot.weather?.code)
        let phase = MoonPhase(date: snapshot.date)
        let haze = clock.isDay ? Color(hex: 0xA9B5A4) : Color(hex: 0x6F8380)
        PaintedSky(palette: SkyPalette(clock: clock, condition: condition), horizon: plan.horizon)
            .overlay {
                if !clock.isDay && !condition.gray { Stars(region: plan.stars, count: 12, sparkles: 2) }
            }
            .overlay(BNSkyBack(clock: clock, condition: condition, plan: plan, phase: phase))
            .overlay(MountainRange(layers: plan.layers, night: !clock.isDay, snowLower: condition == .snow ? 0.02 : 0))
            .overlay(
                LinearGradient(stops: [
                    .init(color: haze.opacity(0), location: plan.mist.lowerBound),
                    .init(color: haze.opacity(0.16), location: (plan.mist.lowerBound + plan.mist.upperBound) / 2),
                    .init(color: haze.opacity(0), location: plan.mist.upperBound)
                ], startPoint: .top, endPoint: .bottom)
            )
            .overlay(BNSkyFront(clock: clock, condition: condition, plan: plan))
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.35), .clear], center: UnitPoint(x: 0.95, y: 1.0), startRadius: 0, endRadius: 300))
    }
}

// MARK: - Live sky, sized for a window

/// The shipped SkyBack, with the sun or moon and the clouds sized for the window rather than the widget.
struct BNSkyBack: View {
    var clock: SkyClock
    var condition: SkyCondition
    var plan: BNScenePlan
    var phase: MoonPhase

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let pt = plan.arc.point(clock.progress, in: size)
            let r = plan.bodyRadius
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(RadialGradient(colors: [(clock.isDay ? Stone.goldBright : Stone.moonlight).opacity(condition.gray ? 0.08 : 0.16), .clear],
                                         center: .center, startRadius: 0, endRadius: r * 8))
                    .frame(width: r * 16, height: r * 16)
                    .position(pt)
                if plan.trail { ArcTrail(arc: plan.arc) }
                Group {
                    if clock.isDay {
                        SunDisc(radius: r).opacity(condition.gray ? 0.5 : 1)
                    } else {
                        MoonDisc(radius: r * 1.15, phase: phase).opacity(condition.gray ? 0.6 : 1)
                    }
                }
                .position(pt)
                ForEach(Array(BNSkyBack.clouds(condition, clock: clock, plan: plan, size: size).enumerated()), id: \.offset) { i, c in
                    PaintedCloud(night: !clock.isDay, gray: condition.gray, seed: i)
                        .frame(width: c.width, height: c.width * 0.55)
                        .position(c.center)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// SkyLayout.clouds with the window's scale.
    static func clouds(_ condition: SkyCondition, clock: SkyClock, plan: BNScenePlan, size: CGSize) -> [(center: CGPoint, width: CGFloat)] {
        let u = plan.unit, arc = plan.arc
        func at(_ progress: Double, lift: CGFloat) -> CGPoint {
            let pt = arc.point(progress, in: size)
            return CGPoint(x: pt.x, y: pt.y - lift * u)
        }
        switch condition {
        case .clear:
            return []
        case .partly:
            let body = arc.point(clock.progress, in: size)
            return [(CGPoint(x: body.x + 12 * u, y: body.y + 7 * u), 32 * u),
                    (at(clock.progress < 0.5 ? 0.78 : 0.24, lift: 4), 22 * u)]
        case .fog:
            return [(at(0.62, lift: 4), 26 * u)]
        case .overcast, .rain, .snow, .storm:
            return [(at(0.24, lift: 4), 30 * u), (at(0.5, lift: -2), 38 * u), (at(0.77, lift: 6), 29 * u)]
        }
    }
}

/// The shipped SkyFront (rain, snow, lightning, fog), scaled for the window.
struct BNSkyFront: View {
    var clock: SkyClock
    var condition: SkyCondition
    var plan: BNScenePlan

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let u = plan.unit
            let clouds = BNSkyBack.clouds(condition, clock: clock, plan: plan, size: size)
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
                                           style: StrokeStyle(lineWidth: max(0.8, 1.1 * u), lineCap: .round, dash: [3 * u, 2.5 * u]))
                            }
                        }
                    }
                    if condition == .storm, clouds.count > 1 {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: max(8, 12 * u), weight: .bold))
                            .foregroundStyle(Stone.goldBright)
                            .shadow(color: Stone.goldBright.opacity(0.8), radius: 4)
                            .position(x: clouds[1].center.x + 3 * u, y: clouds[1].center.y + clouds[1].width * 0.45)
                    }
                case .snow:
                    Canvas { ctx, _ in
                        var rng = SeededRandom(9)
                        for c in clouds {
                            for _ in 0..<8 {
                                let x = c.center.x + CGFloat(rng.signed()) * c.width * 0.4
                                let y = c.center.y + c.width * 0.3 + CGFloat(rng.next()) * 16 * u
                                let rad = max(0.7, (1.0 + CGFloat(rng.next()) * 0.7) * u)
                                ctx.fill(Path(ellipseIn: CGRect(x: x - rad, y: y - rad, width: rad * 2, height: rad * 2)), with: .color(Stone.moonlight))
                            }
                        }
                    }
                case .fog:
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(Color(hex: 0xA7B6AE).opacity(0.45))
                            .frame(width: plan.arc.radiusX * size.width * (2.2 + 0.4 * CGFloat(i)), height: 5 * max(u, 0.6))
                            .blur(radius: 2.5 * max(u, 0.6))
                            .position(x: plan.arc.centerX * size.width + CGFloat(i - 1) * 8 * u,
                                      y: plan.arc.horizon * size.height - CGFloat(4 + 7 * i) * u)
                    }
                default:
                    EmptyView()
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Quote scene

/// The quote widget's evening: tonight's moon and stars over dark ridges, composed for its window.
struct BNQuotePlan {
    var horizon: CGFloat
    var moon: CGPoint        // unit coordinates of the widget
    var moonRadius: CGFloat
    var glow: CGPoint        // copper afterglow at the horizon, unit coordinates
    var glowRadius: CGFloat
    var stars: [(region: CGRect, count: Int, sparkles: Int)]  // bands of sky clear of the moon and the frame's sparkle
    var layers: [MountainLayer]

    static func plan(_ size: BaroqueSize, window w: CGRect, canvas c: CGSize) -> BNQuotePlan {
        func r(_ k: [(CGFloat, CGFloat)], _ seed: UInt64) -> RidgeProfile { BN.ridge(k, window: w, size: c, seed: seed) }
        func u(_ x: CGFloat, _ y: CGFloat) -> CGPoint { BN.unit(x, y, in: w, of: c) }
        func region(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            let a = u(x0, y0), b = u(x1, y1)
            return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
        }
        let farC = (top: Color(hex: 0x3A4A45), bottom: Color(hex: 0x29372F))
        let midC = (top: Color(hex: 0x1F2B27), bottom: Color(hex: 0x18221E))
        let nearC = (top: Color(hex: 0x131B17), bottom: Color(hex: 0x0D1310))
        switch size {
        case .large:
            // A tall lancet window: the moon high in it, stars, one snowy peak and two wooded ridges at its foot.
            return BNQuotePlan(
                horizon: u(0, 0.7).y, moon: u(0.5, 0.24), moonRadius: 14, glow: u(0.5, 0.7), glowRadius: 120,
                stars: [(region(0.12, 0.06, 0.88, 0.15), 4, 1), (region(0.1, 0.35, 0.9, 0.56), 7, 1)],
                layers: [
                    MountainLayer(profile: r([(0, 0.74), (0.14, 0.69), (0.28, 0.71), (0.42, 0.61), (0.52, 0.54), (0.62, 0.6),
                                              (0.76, 0.66), (0.9, 0.64), (1, 0.7)], 61),
                                  top: farC.top, bottom: farC.bottom, rim: 0.45, snowline: u(0, 0.665).y),
                    MountainLayer(profile: r([(0, 0.8), (0.25, 0.76), (0.5, 0.79), (0.75, 0.745), (1, 0.78)], 67),
                                  top: midC.top, bottom: midC.bottom, rim: 0.25, trees: Trees(height: 5...8, spacing: 5, coverage: 0.65)),
                    MountainLayer(profile: r([(0, 0.88), (0.3, 0.85), (0.6, 0.885), (1, 0.84)], 71),
                                  top: nearC.top, bottom: nearC.bottom, rim: 0.15, trees: Trees(height: 7...11, spacing: 5, coverage: 0.8))
                ])
        case .medium:
            return BNQuotePlan(
                horizon: u(0, 0.66).y, moon: u(0.64, 0.3), moonRadius: 10, glow: u(0.5, 0.66), glowRadius: 80,
                stars: [(region(0.1, 0.12, 0.4, 0.5), 4, 1)],
                layers: [
                    MountainLayer(profile: r([(0, 0.7), (0.2, 0.62), (0.34, 0.65), (0.5, 0.52), (0.62, 0.57), (0.8, 0.62), (1, 0.66)], 61),
                                  top: farC.top, bottom: farC.bottom, rim: 0.45, snowline: u(0, 0.6).y),
                    MountainLayer(profile: r([(0, 0.77), (0.3, 0.72), (0.6, 0.76), (1, 0.71)], 67),
                                  top: midC.top, bottom: midC.bottom, rim: 0.25, trees: Trees(height: 4...7, spacing: 4.5, coverage: 0.65)),
                    MountainLayer(profile: r([(0, 0.87), (0.35, 0.83), (0.7, 0.87), (1, 0.83)], 71),
                                  top: nearC.top, bottom: nearC.bottom, rim: 0.15, trees: Trees(height: 6...9, spacing: 5, coverage: 0.8))
                ])
        case .small:
            // A sliver under the quote: ridges across it, the moon low on the right.
            return BNQuotePlan(
                horizon: u(0, 0.6).y, moon: u(0.8, 0.4), moonRadius: 6.5, glow: u(0.35, 0.65), glowRadius: 70,
                stars: [(region(0.05, 0.14, 0.62, 0.42), 5, 1)],
                layers: [
                    MountainLayer(profile: r([(0, 0.62), (0.1, 0.5), (0.2, 0.56), (0.32, 0.36), (0.42, 0.48), (0.55, 0.42),
                                              (0.68, 0.56), (0.78, 0.62), (0.9, 0.52), (1, 0.58)], 61),
                                  top: farC.top, bottom: farC.bottom, rim: 0.45, snowline: u(0, 0.5).y),
                    MountainLayer(profile: r([(0, 0.73), (0.25, 0.67), (0.5, 0.73), (0.75, 0.69), (1, 0.73)], 67),
                                  top: midC.top, bottom: midC.bottom, rim: 0.25, trees: Trees(height: 7...11, spacing: 9, coverage: 0.6)),
                    MountainLayer(profile: r([(0, 0.85), (0.3, 0.81), (0.6, 0.86), (1, 0.81)], 71),
                                  top: nearC.top, bottom: nearC.bottom, rim: 0.15, trees: Trees(height: 10...14, spacing: 10, coverage: 0.75))
                ])
        }
    }
}

struct BNQuoteScene: View {
    var plan: BNQuotePlan
    var date: Date

    var body: some View {
        PaintedSky(palette: .evening, horizon: plan.horizon)
            .overlay {
                GeometryReader { geo in
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xB0703F).opacity(0.4), .clear], center: .center,
                                             startRadius: 0, endRadius: plan.glowRadius))
                        .frame(width: plan.glowRadius * 2, height: plan.glowRadius * 2)
                        .position(x: plan.glow.x * geo.size.width, y: plan.glow.y * geo.size.height)
                }
            }
            .overlay {
                ForEach(plan.stars.indices, id: \.self) { i in
                    Stars(region: plan.stars[i].region, count: plan.stars[i].count, sparkles: plan.stars[i].sparkles, seed: 7 + UInt64(i) * 4)
                }
            }
            .overlay {
                GeometryReader { geo in
                    MoonDisc(radius: plan.moonRadius, phase: MoonPhase(date: date))
                        .position(x: plan.moon.x * geo.size.width, y: plan.moon.y * geo.size.height)
                }
            }
            .overlay(MountainRange(layers: plan.layers, night: true))
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.35), .clear], center: UnitPoint(x: 0.95, y: 1.0), startRadius: 0, endRadius: 300))
    }
}
