import SwiftUI

// The retired widget grounds: the painted skies, ridges and mist the first painted-night Day and Quote widgets
// (Views.swift) were drawn on. Moved out of the app's Baroque/Landscape.swift on 2026-11-11, as nothing there calls
// them since the rococo widgets shipped. They build on the app's Landscape.swift, Theme.swift and Sky.swift, which
// PaintKit compiles through its symlinks.

// MARK: - Ridges

// Ridge layouts per widget size. Ridges stay low where the layout puts text (the date on the left,
// the weather on the right of the large header) and rise in the open space between.
extension Ridges {
    static func day(_ size: BaroqueSize) -> [MountainLayer] {
        switch size {
        case .large:
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.304), p(0.08, 0.302), p(0.16, 0.304), p(0.24, 0.300), p(0.30, 0.282), p(0.35, 0.240),
                    p(0.39, 0.205), p(0.44, 0.178),
                    p(0.49, 0.192), p(0.55, 0.148), p(0.61, 0.186), p(0.67, 0.206), p(0.73, 0.250), p(0.82, 0.276),
                    p(0.91, 0.288), p(1, 0.295)], seed: 11),
                              top: far.top, bottom: far.bottom, rim: 0.6, snowline: 0.205),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.314), p(0.1, 0.312), p(0.2, 0.313), p(0.30, 0.306), p(0.38, 0.268), p(0.46, 0.236), p(0.54, 0.255),
                    p(0.63, 0.228), p(0.71, 0.266), p(0.84, 0.296), p(1, 0.306)], seed: 23),
                              top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 4...7, spacing: 5, coverage: 0.55)),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.324), p(0.14, 0.322), p(0.28, 0.318), p(0.40, 0.292), p(0.50, 0.302), p(0.60, 0.284),
                    p(0.70, 0.305), p(0.85, 0.318), p(1, 0.322)], seed: 31),
                              top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 6...11, spacing: 5, coverage: 0.8))
            ]
        case .medium:
            // Only the left column shows (the task slab covers the rest). The weather sits on the near ridge.
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.54), p(0.05, 0.52), p(0.11, 0.47), p(0.17, 0.50), p(0.24, 0.42), p(0.30, 0.47),
                    p(0.36, 0.44), p(0.44, 0.50), p(0.6, 0.52), p(1, 0.54)], seed: 41),
                              top: far.top, bottom: far.bottom, rim: 0.6, snowline: 0.48),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.60), p(0.08, 0.575), p(0.17, 0.60), p(0.27, 0.565), p(0.36, 0.59), p(0.5, 0.58),
                    p(1, 0.6)], seed: 43, roughness: 0.3),
                              top: Color(hex: 0x1C2722), bottom: Color(hex: 0x111814), rim: 0.3,
                              trees: Trees(height: 6...10, spacing: 5, coverage: 0.8))
            ]
        case .small:
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.50), p(0.14, 0.47), p(0.28, 0.49), p(0.42, 0.42), p(0.52, 0.36), p(0.60, 0.40),
                    p(0.68, 0.37), p(0.80, 0.42), p(0.92, 0.45), p(1, 0.46)], seed: 51),
                              top: far.top, bottom: far.bottom, rim: 0.6, snowline: 0.415),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.56), p(0.2, 0.53), p(0.38, 0.55), p(0.52, 0.49), p(0.66, 0.52), p(0.82, 0.48), p(1, 0.52)], seed: 53),
                              top: mid.top, bottom: mid.bottom, rim: 0.35),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.61), p(0.25, 0.58), p(0.48, 0.61), p(0.7, 0.56), p(1, 0.59)], seed: 57),
                              top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 6...10, spacing: 5.5, coverage: 0.75))
            ]
        }
    }

    // Dark ridges along the bottom of the quote widget; the author line and arrow sit on the nearest one.
    static func quote(_ size: BaroqueSize) -> [MountainLayer] {
        let (a, b, c): (CGFloat, CGFloat, CGFloat)
        switch size {
        case .large: (a, b, c) = (0.64, 0.73, 0.82)
        case .medium: (a, b, c) = (0.52, 0.62, 0.72)
        case .small: (a, b, c) = (0.62, 0.70, 0.78)
        }
        return [
            MountainLayer(profile: RidgeProfile(keys: [
                p(0, a + 0.06), p(0.1, a + 0.02), p(0.2, a + 0.05), p(0.32, a - 0.04), p(0.4, a - 0.01), p(0.5, a - 0.08),
                p(0.6, a - 0.02), p(0.7, a - 0.06), p(0.82, a), p(0.9, a - 0.04), p(1, a + 0.01)], seed: 61),
                          top: Color(hex: 0x33423E), bottom: Color(hex: 0x26332F), rim: 0.3),
            MountainLayer(profile: RidgeProfile(keys: [
                p(0, b + 0.03), p(0.15, b - 0.02), p(0.3, b + 0.02), p(0.45, b - 0.04), p(0.6, b + 0.01), p(0.75, b - 0.05),
                p(0.9, b), p(1, b - 0.03)], seed: 67),
                          top: Color(hex: 0x1F2B27), bottom: Color(hex: 0x18221E), rim: 0.2,
                          trees: Trees(height: 4...7, spacing: 4.5, coverage: 0.6)),
            MountainLayer(profile: RidgeProfile(keys: [
                p(0, c + 0.02), p(0.2, c - 0.02), p(0.4, c + 0.01), p(0.55, c - 0.03), p(0.7, c), p(0.85, c - 0.04),
                p(1, c - 0.01)], seed: 71),
                          top: Color(hex: 0x131B17), bottom: Color(hex: 0x0D1310), rim: 0.15,
                          trees: Trees(height: 6...11, spacing: 5, coverage: 0.8))
        ]
    }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}

// MARK: - Grounds

// The Day widget's ground: the painted sky, mountains, valley mist, and on the large size the live sky.
struct DayBackground: View {
    var snapshot: DaySnapshot
    var size: BaroqueSize

    // Large: the sun's arc fills the open space between the date and the weather.
    static let largeArc = SkyArc(centerX: 0.51, horizon: 0.300, radiusX: 0.155, radiusY: 0.172)

    var body: some View {
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let condition = SkyCondition(code: snapshot.weather?.code)
        let phase = MoonPhase(date: snapshot.date)
        PaintedSky(palette: SkyPalette(clock: clock, condition: condition), horizon: horizon)
            .overlay {
                if !clock.isDay && !condition.gray { Stars(region: starRegion, count: size == .large ? 20 : 6, sparkles: size == .large ? 4 : 1) }
            }
            .overlay {
                switch size {
                case .large:
                    SkyBack(clock: clock, condition: condition, arc: Self.largeArc, phase: phase)
                case .medium:
                    // A small sun or moon beside the numeral, over the ridges.
                    GeometryReader { geo in
                        let u = geo.size.width / 348
                        Group {
                            if clock.isDay { SunDisc(radius: 7 * u) } else { MoonDisc(radius: 7 * u, phase: phase) }
                        }
                        .opacity(condition.gray ? 0.55 : 1)
                        .position(x: geo.size.width * 0.27, y: geo.size.height * 0.31)
                    }
                case .small:
                    EmptyView()
                }
            }
            .overlay(MountainRange(layers: Ridges.day(size), night: !clock.isDay, snowLower: condition == .snow ? 0.02 : 0, fade: fade))
            .overlay(mist(night: !clock.isDay))
            .overlay {
                if size == .large { SkyFront(clock: clock, condition: condition, arc: Self.largeArc) }
            }
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.35), .clear], center: UnitPoint(x: 0.95, y: 1.0), startRadius: 0, endRadius: 300))
            .overlay(GoldFrame(inset: 6))
            .overlay(SlabBevel())
    }

    private var horizon: CGFloat {
        switch size {
        case .large: return 0.30
        case .medium: return 0.55
        case .small: return 0.5
        }
    }

    // Open sky clear of the text: between the date and the weather, or beside the medium's numeral.
    private var starRegion: CGRect {
        switch size {
        case .large: return CGRect(x: 0.30, y: 0.06, width: 0.42, height: 0.14)
        case .medium: return CGRect(x: 0.19, y: 0.18, width: 0.18, height: 0.18)
        case .small: return CGRect(x: 0.40, y: 0.20, width: 0.28, height: 0.16)
        }
    }

    // Where the ridges dissolve into the valley: under the large header and above the small widget's slab.
    private var fade: ClosedRange<CGFloat>? {
        switch size {
        case .large: return 0.295...0.345
        case .small: return 0.56...0.66
        case .medium: return nil
        }
    }

    // Valley mist: a soft haze over the ridge bases where the week strip and the task slab begin.
    @ViewBuilder
    private func mist(night: Bool) -> some View {
        let haze = night ? Color(hex: 0x6F8380) : Color(hex: 0xA9B5A4)
        switch size {
        case .large:
            LinearGradient(stops: [
                .init(color: haze.opacity(0), location: 0.25),
                .init(color: haze.opacity(0.28), location: 0.31),
                .init(color: haze.opacity(0), location: 0.38)
            ], startPoint: .top, endPoint: .bottom)
        case .small:
            LinearGradient(stops: [
                .init(color: haze.opacity(0), location: 0.50),
                .init(color: haze.opacity(0.25), location: 0.58),
                .init(color: haze.opacity(0), location: 0.68)
            ], startPoint: .top, endPoint: .bottom)
        case .medium:
            // A thin haze between the two ridges only; the near ridge stays solid under the weather.
            LinearGradient(stops: [
                .init(color: haze.opacity(0), location: 0.44),
                .init(color: haze.opacity(0.2), location: 0.56),
                .init(color: haze.opacity(0), location: 0.6)
            ], startPoint: .top, endPoint: .bottom)
        }
    }
}

// The Quote widget's ground: an evening sky with tonight's moon rising behind dark ridges along the bottom.
struct QuoteBackground: View {
    var size: BaroqueSize
    var date: Date = Date()

    var body: some View {
        let ridges = Ridges.quote(size)
        let horizon = ridges.first.map { $0.profile.keys.map(\.y).min() ?? 0.6 } ?? 0.6
        PaintedSky(palette: .evening, horizon: horizon + 0.06)
            .overlay(RadialGradient(colors: [Color(hex: 0xB0703F).opacity(0.38), .clear],
                                    center: UnitPoint(x: 0.3, y: horizon + 0.06), startRadius: 0, endRadius: 190))
            .overlay(Stars(region: CGRect(x: 0.55, y: 0.05, width: 0.4, height: max(0.1, horizon - 0.15)),
                           count: size == .small ? 6 : 9, sparkles: size == .small ? 1 : 2, seed: 7))
            .overlay {
                if size != .small {
                    GeometryReader { geo in
                        let u = geo.size.width / 348
                        MoonDisc(radius: (size == .large ? 15 : 12) * u, phase: MoonPhase(date: date))
                            .position(x: geo.size.width * 0.80, y: geo.size.height * (horizon + 0.01))
                    }
                }
            }
            .overlay(MountainRange(layers: ridges, night: true))
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.35), .clear], center: UnitPoint(x: 0.95, y: 1.0), startRadius: 0, endRadius: 300))
            .overlay(GoldFrame(inset: 6))
            .overlay(SlabBevel())
    }
}
