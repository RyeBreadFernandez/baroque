import SwiftUI

// The painted grounds for the Trail layout: the app's sky, sun, moon, stars, mist and ridges, with ridge key
// points written for this layout's text (fractions of the widget, like Ridges in Landscape.swift).

enum TRRidges {
    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// The medium widget's trail runs along this crest; the waypoints stand on it.
    static let mediumTrail = RidgeProfile(keys: [
        p(0, 0.515), p(0.12, 0.495), p(0.24, 0.51), p(0.36, 0.485), p(0.5, 0.50), p(0.62, 0.48),
        p(0.76, 0.495), p(0.88, 0.475), p(1, 0.49)], seed: 131, roughness: 0.1, levels: 3)

    static func day(_ family: Family) -> [MountainLayer] {
        switch family {
        case .large:
            // Peaks rise between the date (left) and the weather (right), and sink behind the week strip.
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.205), p(0.08, 0.198), p(0.17, 0.194), p(0.26, 0.186), p(0.33, 0.165), p(0.39, 0.138),
                    p(0.45, 0.112), p(0.50, 0.126), p(0.56, 0.088), p(0.62, 0.122), p(0.67, 0.152), p(0.73, 0.19),
                    p(0.83, 0.205), p(1, 0.212)], seed: 111),
                              top: Ridges.far.top, bottom: Ridges.far.bottom, rim: 0.6, snowline: 0.132),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.214), p(0.12, 0.208), p(0.24, 0.200), p(0.34, 0.180), p(0.43, 0.160), p(0.50, 0.170),
                    p(0.58, 0.150), p(0.66, 0.178), p(0.78, 0.205), p(1, 0.216)], seed: 113),
                              top: Ridges.mid.top, bottom: Ridges.mid.bottom, rim: 0.35,
                              trees: Trees(height: 4...7, spacing: 5, coverage: 0.55)),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.222), p(0.18, 0.214), p(0.32, 0.200), p(0.46, 0.188), p(0.56, 0.196), p(0.68, 0.192),
                    p(0.82, 0.212), p(1, 0.22)], seed: 117),
                              top: Ridges.near.top, bottom: Ridges.near.bottom, rim: 0.25,
                              trees: Trees(height: 6...10, spacing: 5, coverage: 0.8))
            ]
        case .medium:
            // Snowy peaks between the date and the weather; the near ridge carries the trail.
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.44), p(0.1, 0.42), p(0.2, 0.40), p(0.3, 0.355), p(0.37, 0.29), p(0.44, 0.215), p(0.49, 0.25),
                    p(0.56, 0.18), p(0.63, 0.245), p(0.70, 0.31), p(0.80, 0.37), p(0.9, 0.41), p(1, 0.43)], seed: 121),
                              top: Ridges.far.top, bottom: Ridges.far.bottom, rim: 0.6, snowline: 0.27),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.47), p(0.14, 0.445), p(0.28, 0.43), p(0.40, 0.375), p(0.50, 0.395), p(0.60, 0.355),
                    p(0.72, 0.405), p(0.86, 0.435), p(1, 0.46)], seed: 123),
                              top: Ridges.mid.top, bottom: Ridges.mid.bottom, rim: 0.35,
                              trees: Trees(height: 5...8, spacing: 5, coverage: 0.6)),
                MountainLayer(profile: mediumTrail,
                              top: Color(hex: 0x1C2722), bottom: Color(hex: 0x101713), rim: 0.3)
            ]
        case .small:
            // Peaks behind the header's middle; the dark near ridge is the ground the trail is cut into.
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.40), p(0.14, 0.385), p(0.28, 0.35), p(0.40, 0.29), p(0.49, 0.235), p(0.56, 0.27),
                    p(0.64, 0.25), p(0.74, 0.31), p(0.86, 0.35), p(1, 0.37)], seed: 141),
                              top: Ridges.far.top, bottom: Ridges.far.bottom, rim: 0.6, snowline: 0.30),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.405), p(0.2, 0.39), p(0.38, 0.36), p(0.52, 0.335), p(0.66, 0.35), p(0.82, 0.345), p(1, 0.37)], seed: 143),
                              top: Ridges.mid.top, bottom: Ridges.mid.bottom, rim: 0.35,
                              trees: Trees(height: 5...8, spacing: 5.5, coverage: 0.6)),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.405), p(0.25, 0.395), p(0.5, 0.385), p(0.75, 0.39), p(1, 0.38)], seed: 147, roughness: 0.12),
                              top: Color(hex: 0x1A2520), bottom: Color(hex: 0x0F1612), rim: 0.25,
                              trees: Trees(height: 6...10, spacing: 5.5, coverage: 0.7))
            ]
        }
    }

    /// Low ridges along the bottom of the margin-note quote; the thread ends on the nearest one.
    static func quote(_ family: Family) -> [MountainLayer] {
        let (a, b, c): (CGFloat, CGFloat, CGFloat)
        switch family {
        case .large: (a, b, c) = (0.79, 0.855, 0.92)
        case .medium: (a, b, c) = (0.70, 0.79, 0.88)
        case .small: (a, b, c) = (0.74, 0.82, 0.90)
        }
        return [
            MountainLayer(profile: RidgeProfile(keys: [
                p(0, a + 0.05), p(0.12, a + 0.01), p(0.24, a + 0.04), p(0.36, a - 0.03), p(0.46, a), p(0.56, a - 0.06),
                p(0.66, a - 0.01), p(0.76, a - 0.05), p(0.86, a + 0.01), p(1, a - 0.02)], seed: 161),
                          top: Color(hex: 0x33423E), bottom: Color(hex: 0x26332F), rim: 0.3, snowline: a - 0.035),
            MountainLayer(profile: RidgeProfile(keys: [
                p(0, b + 0.02), p(0.16, b - 0.02), p(0.32, b + 0.02), p(0.48, b - 0.03), p(0.62, b + 0.01), p(0.78, b - 0.04),
                p(0.9, b), p(1, b - 0.02)], seed: 167),
                          top: Color(hex: 0x1F2B27), bottom: Color(hex: 0x18221E), rim: 0.2,
                          trees: Trees(height: 4...7, spacing: 4.5, coverage: 0.6)),
            MountainLayer(profile: RidgeProfile(keys: [
                p(0, c), p(0.2, c - 0.02), p(0.4, c + 0.01), p(0.55, c - 0.025), p(0.72, c), p(0.86, c - 0.03),
                p(1, c - 0.01)], seed: 171),
                          top: Color(hex: 0x131B17), bottom: Color(hex: 0x0D1310), rim: 0.15,
                          trees: Trees(height: 6...10, spacing: 5, coverage: 0.8))
        ]
    }
}

// The Day ground: painted sky for the hour and weather, the sun or moon on its arc, the ridges, mist,
// rain or snow in front, the gold frame and the bevel.
struct TRDayScene: View {
    var snapshot: DaySnapshot
    var family: Family

    /// Large and medium carry the live sky in the open space between the date and the weather.
    static func arc(_ family: Family) -> SkyArc? {
        switch family {
        case .large: return SkyArc(centerX: 0.565, horizon: 0.19, radiusX: 0.105, radiusY: 0.11)
        case .medium: return SkyArc(centerX: 0.5, horizon: 0.43, radiusX: 0.125, radiusY: 0.27)
        case .small: return nil
        }
    }

    var body: some View {
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let condition = SkyCondition(code: snapshot.weather?.code)
        let arc = Self.arc(family)
        PaintedSky(palette: SkyPalette(clock: clock, condition: condition), horizon: horizon)
            .overlay {
                if !clock.isDay && !condition.gray {
                    Stars(region: starRegion, count: family == .small ? 6 : 14, sparkles: family == .small ? 1 : 3, seed: 13)
                }
            }
            .overlay {
                if let arc {
                    SkyBack(clock: clock, condition: condition, arc: arc, phase: MoonPhase(date: snapshot.date))
                }
            }
            .overlay(MountainRange(layers: TRRidges.day(family), night: !clock.isDay,
                                   snowLower: condition == .snow ? 0.015 : 0, fade: fade))
            .overlay(mist(night: !clock.isDay))
            .overlay(groundShade)
            .overlay {
                if let arc { SkyFront(clock: clock, condition: condition, arc: arc) }
            }
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.35), .clear], center: UnitPoint(x: 0.95, y: 1.0),
                                    startRadius: 0, endRadius: 300))
            .overlay(GoldFrame(inset: 6))
            .overlay(SlabBevel())
    }

    private var horizon: CGFloat {
        switch family {
        case .large: return 0.3
        case .medium: return 0.55
        case .small: return 0.5
        }
    }

    private var starRegion: CGRect {
        switch family {
        case .large: return CGRect(x: 0.36, y: 0.05, width: 0.3, height: 0.06)
        case .medium: return CGRect(x: 0.38, y: 0.08, width: 0.26, height: 0.1)
        case .small: return CGRect(x: 0.42, y: 0.12, width: 0.2, height: 0.1)
        }
    }

    /// Where the ridges dissolve into the valley: under the week strip on large.
    private var fade: ClosedRange<CGFloat>? {
        family == .large ? 0.215...0.33 : nil
    }

    /// Medium and small set their stops straight onto the near ridge: deepen its lower slope so the light
    /// strokes in the paint never sit behind the writing.
    @ViewBuilder
    private var groundShade: some View {
        switch family {
        case .large:
            EmptyView()
        case .medium, .small:
            let from: CGFloat = family == .medium ? 0.52 : 0.42
            LinearGradient(stops: [
                .init(color: Stone.shadow.opacity(0), location: from),
                .init(color: Stone.shadow.opacity(0.42), location: from + 0.16),
                .init(color: Stone.shadow.opacity(0.5), location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder
    private func mist(night: Bool) -> some View {
        let haze = night ? Color(hex: 0x6F8380) : Color(hex: 0xA9B5A4)
        let band: (CGFloat, CGFloat, CGFloat, Double) = {
            switch family {
            case .large: return (0.15, 0.205, 0.26, 0.26)
            case .medium: return (0.36, 0.46, 0.52, 0.2)
            case .small: return (0.30, 0.37, 0.42, 0.22)
            }
        }()
        LinearGradient(stops: [
            .init(color: haze.opacity(0), location: band.0),
            .init(color: haze.opacity(band.3), location: band.1),
            .init(color: haze.opacity(0), location: band.2)
        ], startPoint: .top, endPoint: .bottom)
    }
}

// The Quote ground: the evening sky, a copper glow low on the left, stars, tonight's moon rising on the right,
// and low ridges along the bottom.
struct TRQuoteScene: View {
    var family: Family
    var date: Date

    var body: some View {
        let ridges = TRRidges.quote(family)
        let horizon = ridges.first.map { $0.profile.keys.map(\.y).min() ?? 0.7 } ?? 0.7
        PaintedSky(palette: .evening, horizon: horizon + 0.05)
            .overlay(RadialGradient(colors: [Color(hex: 0xB0703F).opacity(0.36), .clear],
                                    center: UnitPoint(x: 0.3, y: horizon + 0.05), startRadius: 0, endRadius: 190))
            .overlay(Stars(region: CGRect(x: 0.58, y: 0.06, width: 0.36, height: max(0.08, horizon - 0.2)),
                           count: family == .small ? 5 : 9, sparkles: family == .small ? 1 : 2, seed: 7))
            .overlay {
                if family != .small {
                    GeometryReader { geo in
                        let u = geo.size.width / 348
                        MoonDisc(radius: (family == .large ? 14 : 11) * u, phase: MoonPhase(date: date))
                            .position(x: geo.size.width * (family == .large ? 0.72 : 0.68), y: geo.size.height * (horizon + 0.005))
                    }
                }
            }
            .overlay(MountainRange(layers: ridges, night: true))
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.35), .clear], center: UnitPoint(x: 0.95, y: 1.0),
                                    startRadius: 0, endRadius: 300))
            .overlay(GoldFrame(inset: 6))
            .overlay(SlabBevel())
    }
}
