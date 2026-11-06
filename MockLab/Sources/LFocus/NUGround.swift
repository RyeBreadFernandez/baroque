import SwiftUI

// The painted grounds for Next Up: the shipped sky, sun, moon, stars and ridges, with ridge key points
// written for this layout (fractions of the widget) so the peaks rise in the open space around the card
// and stay low under the slim header and the "Then" list.

enum NURidges {
    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    static func day(_ style: NUStyle) -> [MountainLayer] {
        let far = Ridges.far, mid = Ridges.mid, near = Ridges.near
        switch style {
        case .small:
            // A band between the header and the card: peaks rise in the gap between "TUE 3" and the temperature.
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.31), p(0.10, 0.29), p(0.22, 0.275), p(0.33, 0.26), p(0.40, 0.21), p(0.47, 0.135),
                    p(0.53, 0.175), p(0.58, 0.15), p(0.64, 0.225), p(0.74, 0.26), p(0.86, 0.27), p(1, 0.29)], seed: 101),
                              top: far.top, bottom: far.bottom, rim: 0.6, snowline: 0.205),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.335), p(0.15, 0.31), p(0.3, 0.315), p(0.42, 0.28), p(0.55, 0.295), p(0.7, 0.27),
                    p(0.85, 0.30), p(1, 0.31)], seed: 103),
                              top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 3...6, spacing: 5, coverage: 0.6)),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.37), p(0.3, 0.345), p(0.6, 0.36), p(1, 0.34)], seed: 107),
                              top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 5...8, spacing: 5, coverage: 0.8))
            ]
        case .medium:
            // The right column: snowy peaks between the header and the "Then" list, which stands on the near ridge.
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.42), p(0.3, 0.40), p(0.55, 0.39), p(0.63, 0.35), p(0.69, 0.31), p(0.745, 0.255),
                    p(0.79, 0.29), p(0.84, 0.265), p(0.90, 0.32), p(0.96, 0.345), p(1, 0.36)], seed: 111),
                              top: far.top, bottom: far.bottom, rim: 0.6, snowline: 0.315),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.47), p(0.4, 0.45), p(0.6, 0.43), p(0.69, 0.385), p(0.78, 0.41), p(0.88, 0.375),
                    p(1, 0.41)], seed: 113),
                              top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 4...6, spacing: 5, coverage: 0.55)),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.52), p(0.5, 0.50), p(0.62, 0.475), p(0.74, 0.455), p(0.86, 0.475), p(1, 0.46)], seed: 117, roughness: 0.25),
                              top: Color(hex: 0x1C2722), bottom: Color(hex: 0x111814), rim: 0.3,
                              trees: Trees(height: 6...9, spacing: 5, coverage: 0.8))
            ]
        case .large:
            // A landscape band under the header; the hero card rests on the near ridge.
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.250), p(0.08, 0.236), p(0.16, 0.226), p(0.25, 0.231), p(0.33, 0.222), p(0.41, 0.192),
                    p(0.47, 0.202), p(0.54, 0.168), p(0.59, 0.142), p(0.64, 0.163), p(0.69, 0.154), p(0.75, 0.19),
                    p(0.83, 0.21), p(0.91, 0.2), p(1, 0.222)], seed: 121),
                              top: far.top, bottom: far.bottom, rim: 0.6, snowline: 0.188),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.27), p(0.12, 0.258), p(0.25, 0.262), p(0.36, 0.242), p(0.46, 0.25), p(0.6, 0.228),
                    p(0.72, 0.245), p(0.85, 0.236), p(1, 0.252)], seed: 123),
                              top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 4...7, spacing: 5, coverage: 0.55)),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.288), p(0.15, 0.279), p(0.3, 0.284), p(0.45, 0.271), p(0.6, 0.28), p(0.78, 0.268),
                    p(1, 0.28)], seed: 127),
                              top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 6...10, spacing: 5, coverage: 0.8))
            ]
        }
    }

    // Evening ridges for the quote: a snowy range behind the deck, the card standing in front of it.
    static func quote(_ style: NUStyle) -> [MountainLayer] {
        switch style {
        case .small:
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.30), p(0.14, 0.255), p(0.28, 0.27), p(0.40, 0.195), p(0.49, 0.145), p(0.57, 0.19),
                    p(0.68, 0.225), p(0.80, 0.205), p(0.9, 0.24), p(1, 0.26)], seed: 131),
                              top: Color(hex: 0x3E4D48), bottom: Color(hex: 0x2B3833), rim: 0.45, snowline: 0.205),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.33), p(0.3, 0.30), p(0.6, 0.31), p(1, 0.29)], seed: 133),
                              top: Color(hex: 0x1F2B27), bottom: Color(hex: 0x18221E), rim: 0.2,
                              trees: Trees(height: 4...7, spacing: 4.5, coverage: 0.6))
            ]
        case .medium:
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.52), p(0.5, 0.49), p(0.68, 0.46), p(0.75, 0.41), p(0.81, 0.34), p(0.86, 0.38),
                    p(0.91, 0.32), p(0.96, 0.39), p(1, 0.41)], seed: 141),
                              top: Color(hex: 0x3E4D48), bottom: Color(hex: 0x2B3833), rim: 0.45, snowline: 0.40),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.62), p(0.7, 0.60), p(0.79, 0.56), p(0.88, 0.59), p(1, 0.55)], seed: 143),
                              top: Color(hex: 0x1F2B27), bottom: Color(hex: 0x18221E), rim: 0.2,
                              trees: Trees(height: 4...7, spacing: 4.5, coverage: 0.6)),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.78), p(0.75, 0.76), p(0.85, 0.73), p(0.95, 0.76), p(1, 0.74)], seed: 147),
                              top: Color(hex: 0x131B17), bottom: Color(hex: 0x0D1310), rim: 0.15,
                              trees: Trees(height: 6...10, spacing: 5, coverage: 0.8))
            ]
        case .large:
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.19), p(0.1, 0.16), p(0.2, 0.17), p(0.3, 0.125), p(0.38, 0.14), p(0.46, 0.10),
                    p(0.54, 0.13), p(0.62, 0.15), p(0.7, 0.135), p(0.8, 0.17), p(0.9, 0.16), p(1, 0.18)], seed: 151),
                              top: Color(hex: 0x3E4D48), bottom: Color(hex: 0x2B3833), rim: 0.45, snowline: 0.142),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.235), p(0.2, 0.21), p(0.4, 0.22), p(0.6, 0.20), p(0.8, 0.22), p(1, 0.205)], seed: 153),
                              top: Color(hex: 0x1F2B27), bottom: Color(hex: 0x18221E), rim: 0.2,
                              trees: Trees(height: 4...7, spacing: 4.5, coverage: 0.6)),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.935), p(0.15, 0.92), p(0.3, 0.93), p(0.5, 0.915), p(0.7, 0.928), p(0.85, 0.912),
                    p(1, 0.925)], seed: 157),
                              top: Color(hex: 0x131B17), bottom: Color(hex: 0x0D1310), rim: 0.15,
                              trees: Trees(height: 6...11, spacing: 5, coverage: 0.8))
            ]
        }
    }
}

// MARK: - Day ground

/// The Day widget's ground: the shipped painted sky for the time of day and weather, Next Up's ridges,
/// valley mist, and on the large size the live sun or moon on today's arc above the landscape band.
struct NUDayGround: View {
    var snapshot: DaySnapshot
    var style: NUStyle

    /// Large: the arc spans the landscape band between the header and the hero card.
    static let largeArc = SkyArc(centerX: 0.5, horizon: 0.255, radiusX: 0.33, radiusY: 0.13)

    var body: some View {
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let condition = SkyCondition(code: snapshot.weather?.code)
        let phase = MoonPhase(date: snapshot.date)
        let night = !clock.isDay
        PaintedSky(palette: SkyPalette(clock: clock, condition: condition), horizon: horizon)
            .overlay {
                if night && !condition.gray {
                    Stars(region: starRegion, count: style == .large ? 16 : 6, sparkles: style == .large ? 3 : 1, seed: 5)
                }
            }
            .overlay {
                switch style {
                case .large:
                    SkyBack(clock: clock, condition: condition, arc: Self.largeArc, phase: phase)
                case .medium:
                    // A small sun or moon low over the right-hand peaks.
                    GeometryReader { geo in
                        let u = geo.size.width / 348
                        Group {
                            if clock.isDay { SunDisc(radius: 6 * u) } else { MoonDisc(radius: 6.5 * u, phase: phase) }
                        }
                        .opacity(condition.gray ? 0.55 : 1)
                        .position(x: geo.size.width * 0.70, y: geo.size.height * 0.30)
                    }
                case .small:
                    EmptyView()
                }
            }
            .overlay(MountainRange(layers: NURidges.day(style), night: night, snowLower: condition == .snow ? 0.02 : 0))
            .overlay(mist(night: night))
            .overlay {
                if style == .large { SkyFront(clock: clock, condition: condition, arc: Self.largeArc) }
            }
            // Dusk along the top edge so the slim header keeps its contrast on the brightest sky.
            .overlay(LinearGradient(stops: [.init(color: Stone.night.opacity(0.3), location: 0),
                                            .init(color: Stone.night.opacity(0), location: headerShade)],
                                    startPoint: .top, endPoint: .bottom))
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.35), .clear], center: UnitPoint(x: 0.95, y: 1.0), startRadius: 0, endRadius: 300))
            .overlay(GoldFrame(inset: 6))
            .overlay(SlabBevel())
    }

    private var horizon: CGFloat {
        switch style {
        case .large: return 0.28
        case .medium: return 0.46
        case .small: return 0.32
        }
    }

    private var headerShade: CGFloat {
        switch style {
        case .large: return 0.13
        case .medium: return 0.3
        case .small: return 0.26
        }
    }

    private var starRegion: CGRect {
        switch style {
        case .large: return CGRect(x: 0.08, y: 0.125, width: 0.84, height: 0.05)
        case .medium: return CGRect(x: 0.66, y: 0.22, width: 0.28, height: 0.06)
        case .small: return CGRect(x: 0.40, y: 0.06, width: 0.2, height: 0.05)
        }
    }

    // Valley mist over the ridge bases, where the cards come to rest.
    @ViewBuilder
    private func mist(night: Bool) -> some View {
        let haze = night ? Color(hex: 0x6F8380) : Color(hex: 0xA9B5A4)
        let band: (CGFloat, CGFloat, CGFloat, Double) = {
            switch style {
            case .large: return (0.2, 0.26, 0.31, 0.26)
            case .medium: return (0.36, 0.43, 0.48, 0.2)
            case .small: return (0.22, 0.29, 0.36, 0.22)
            }
        }()
        LinearGradient(stops: [
            .init(color: haze.opacity(0), location: band.0),
            .init(color: haze.opacity(band.3), location: band.1),
            .init(color: haze.opacity(0), location: band.2)
        ], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Quote ground

/// The Quote widget's ground: the shipped evening sky, tonight's moon over a snowy range, and dark ridges.
struct NUQuoteGround: View {
    var style: NUStyle
    var date: Date

    var body: some View {
        let ridges = NURidges.quote(style)
        PaintedSky(palette: .evening, horizon: horizon)
            .overlay(RadialGradient(colors: [Color(hex: 0xB0703F).opacity(0.34), .clear],
                                    center: glowCenter, startRadius: 0, endRadius: style == .small ? 120 : 190))
            .overlay(Stars(region: starRegion, count: style == .large ? 9 : 5, sparkles: style == .large ? 2 : 1, seed: 7))
            .overlay {
                GeometryReader { geo in
                    let u = geo.size.width / 348
                    MoonDisc(radius: moonRadius * u, phase: MoonPhase(date: date))
                        .position(x: geo.size.width * moonAt.x, y: geo.size.height * moonAt.y)
                }
            }
            .overlay(MountainRange(layers: ridges, night: true))
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.35), .clear], center: UnitPoint(x: 0.95, y: 1.0), startRadius: 0, endRadius: 300))
            .overlay(GoldFrame(inset: 6))
            .overlay(SlabBevel())
    }

    private var horizon: CGFloat {
        switch style {
        case .small: return 0.26
        case .medium: return 0.45
        case .large: return 0.17
        }
    }

    private var glowCenter: UnitPoint {
        switch style {
        case .small: return UnitPoint(x: 0.5, y: 0.22)
        case .medium: return UnitPoint(x: 0.86, y: 0.42)
        case .large: return UnitPoint(x: 0.38, y: 0.15)
        }
    }

    private var moonRadius: CGFloat {
        switch style {
        case .small: return 16   // in 348-wide units, so about 7.5 pt on the small widget
        case .medium: return 10.5
        case .large: return 13
        }
    }

    private var moonAt: CGPoint {
        switch style {
        case .small: return CGPoint(x: 0.80, y: 0.15)
        case .medium: return CGPoint(x: 0.90, y: 0.24)
        case .large: return CGPoint(x: 0.82, y: 0.085)
        }
    }

    private var starRegion: CGRect {
        switch style {
        case .small: return CGRect(x: 0.12, y: 0.06, width: 0.32, height: 0.1)
        case .medium: return CGRect(x: 0.79, y: 0.08, width: 0.06, height: 0.2)
        case .large: return CGRect(x: 0.08, y: 0.04, width: 0.6, height: 0.07)
        }
    }
}
