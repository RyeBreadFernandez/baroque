import SwiftUI

// The painted set behind each Calm widget: Grand Hotel's sky, ridges and hotel (GHScene), with the hotel in its plain
// dress (no funicular, no cable cars, fewer windows, one pennant), thinner rain and snow, and fewer stars. Key points
// are fractions of the widget, placed around the type and the slab of each layout: the summit rises behind the tower,
// the side ridges stay low under the date and the weather.

enum GCScenes {
    private static func k(_ pts: [(CGFloat, CGFloat)]) -> [CGPoint] { pts.map { CGPoint(x: $0.0, y: $0.1) } }

    /// Rain and snow at a little under half Grand Hotel's density.
    static let weatherDensity: CGFloat = 0.42

    // MARK: Day

    /// Large: date top left, weather top right, the hotel between them; `lift` raises the whole range (0 = Quiet).
    static func dayLarge(_ snap: DaySnapshot, hotelBase: CGFloat, hotelWidth: CGFloat, ledgeBottom: CGFloat, lift: CGFloat = 0, trail: Bool) -> GHSceneSpec {
        let l = lift
        return GHSceneSpec(
            now: snap.date, weather: snap.weather, horizon: 0.34 + l,
            back: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.31 + l), (0.08, 0.285 + l), (0.16, 0.30 + l), (0.24, 0.255 + l), (0.32, 0.27 + l), (0.4, 0.225 + l),
                                                        (0.5, 0.24 + l), (0.6, 0.225 + l), (0.68, 0.27 + l), (0.76, 0.255 + l), (0.84, 0.30 + l), (0.92, 0.285 + l),
                                                        (1, 0.31 + l)]), seed: 11),
                        top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.5, snowline: 0.26 + l),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.41 + l), (0.14, 0.38 + l), (0.26, 0.32 + l), (0.34, 0.25 + l), (0.41, 0.18 + l), (0.46, 0.14 + l),
                                                        (0.5, 0.115 + l), (0.54, 0.14 + l), (0.59, 0.18 + l), (0.66, 0.25 + l), (0.74, 0.32 + l), (0.86, 0.38 + l),
                                                        (1, 0.41 + l)]), seed: 13, roughness: 0.15),
                        top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.6, snowline: 0.215 + l),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.38 + l), (0.12, 0.36 + l), (0.24, 0.375 + l), (0.36, 0.40 + l), (0.5, 0.415 + l), (0.64, 0.40 + l),
                                                        (0.76, 0.375 + l), (0.88, 0.36 + l), (1, 0.38 + l)]), seed: 17),
                        top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.4,
                        trees: Trees(height: 5...8, spacing: 7, coverage: 0.55), treeColor: GH.pine)
            ],
            front: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.40 + l), (0.1, 0.415 + l), (0.2, 0.44 + l), (0.32, 0.475 + l), (0.5, 0.50 + l), (0.68, 0.475 + l),
                                                        (0.8, 0.44 + l), (0.9, 0.415 + l), (1, 0.40 + l)]), seed: 19),
                        top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.35,
                        trees: Trees(height: 9...14, spacing: 8, coverage: 0.7), treeColor: GH.pineDark)
            ],
            hotel: GHHotelSpec(base: hotelBase, width: hotelWidth, ledgeBottom: ledgeBottom, funicular: false, simple: true),
            arc: SkyArc(centerX: 0.5, horizon: 0.33 + l, radiusX: 0.27, radiusY: 0.26),
            bodyRadius: 9, trail: trail,
            stars: CGRect(x: 0.3, y: 0.07, width: 0.4, height: 0.12), starCount: 9,
            mist: 0.40 + l, weatherRegion: CGRect(x: 0.28, y: 0.04, width: 0.44, height: 0.3), weatherDensity: weatherDensity)
    }

    /// Medium: date left, weather right, a small hotel between them, the slab below.
    static func dayMedium(_ snap: DaySnapshot, hotelBase: CGFloat, hotelWidth: CGFloat) -> GHSceneSpec {
        GHSceneSpec(
            now: snap.date, weather: snap.weather, horizon: 0.48,
            back: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.46), (0.1, 0.42), (0.2, 0.44), (0.3, 0.37), (0.4, 0.33), (0.5, 0.35), (0.6, 0.33),
                                                        (0.7, 0.37), (0.8, 0.44), (0.9, 0.42), (1, 0.46)]), seed: 41),
                        top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.5, snowline: 0.38),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.62), (0.18, 0.57), (0.3, 0.46), (0.38, 0.33), (0.45, 0.22), (0.5, 0.17), (0.55, 0.22),
                                                        (0.62, 0.33), (0.7, 0.46), (0.82, 0.57), (1, 0.62)]), seed: 43, roughness: 0.15),
                        top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.6, snowline: 0.31),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.52), (0.14, 0.49), (0.28, 0.52), (0.4, 0.56), (0.5, 0.57), (0.6, 0.56), (0.72, 0.52),
                                                        (0.86, 0.49), (1, 0.52)]), seed: 47),
                        top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.4,
                        trees: Trees(height: 5...8, spacing: 7, coverage: 0.55), treeColor: GH.pine)
            ],
            front: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.53), (0.12, 0.55), (0.26, 0.59), (0.4, 0.63), (0.5, 0.64), (0.6, 0.63), (0.74, 0.59),
                                                        (0.88, 0.55), (1, 0.53)]), seed: 49),
                        top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.35,
                        trees: Trees(height: 8...12, spacing: 8, coverage: 0.7), treeColor: GH.pineDark)
            ],
            hotel: GHHotelSpec(base: hotelBase, width: hotelWidth, ledgeBottom: hotelBase + 0.16, funicular: false, simple: true),
            arc: SkyArc(centerX: 0.5, horizon: 0.45, radiusX: 0.3, radiusY: 0.36),
            bodyRadius: 7,
            stars: CGRect(x: 0.3, y: 0.1, width: 0.4, height: 0.2), starCount: 6,
            mist: 0.55, weatherRegion: CGRect(x: 0.3, y: 0.06, width: 0.4, height: 0.4), weatherDensity: weatherDensity)
    }

    /// Small: the date and temperature in the top corners, a small hotel between and below them, the slab under it.
    static func daySmall(_ snap: DaySnapshot, hotelBase: CGFloat, hotelWidth: CGFloat) -> GHSceneSpec {
        GHSceneSpec(
            now: snap.date, weather: snap.weather, horizon: 0.52,
            back: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.44), (0.14, 0.40), (0.28, 0.42), (0.4, 0.35), (0.5, 0.37), (0.6, 0.35), (0.72, 0.42),
                                                        (0.86, 0.40), (1, 0.44)]), seed: 51),
                        top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.5, snowline: 0.40),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.62), (0.2, 0.55), (0.32, 0.45), (0.42, 0.33), (0.5, 0.27), (0.58, 0.33), (0.68, 0.45),
                                                        (0.8, 0.55), (1, 0.62)]), seed: 53, roughness: 0.15),
                        top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.6, snowline: 0.39),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.57), (0.2, 0.54), (0.4, 0.58), (0.5, 0.59), (0.6, 0.58), (0.8, 0.54), (1, 0.57)]), seed: 55),
                        top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.4,
                        trees: Trees(height: 6...9, spacing: 8, coverage: 0.55), treeColor: GH.pine)
            ],
            front: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.55), (0.15, 0.57), (0.3, 0.61), (0.5, 0.64), (0.7, 0.61), (0.85, 0.57), (1, 0.55)]), seed: 57),
                        top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.35,
                        trees: Trees(height: 10...15, spacing: 10, coverage: 0.7), treeColor: GH.pineDark)
            ],
            hotel: GHHotelSpec(base: hotelBase, width: hotelWidth, ledgeBottom: hotelBase + 0.14, funicular: false, simple: true),
            arc: SkyArc(centerX: 0.5, horizon: 0.5, radiusX: 0.08, radiusY: 0.34),
            bodyRadius: 8,
            stars: CGRect(x: 0.34, y: 0.1, width: 0.32, height: 0.16), starCount: 4,
            mist: 0.58, weatherRegion: CGRect(x: 0.3, y: 0.06, width: 0.4, height: 0.42), weatherDensity: weatherDensity)
    }

    // MARK: Quote

    /// The quote widgets have no weather: the sky follows the clock only. `cx` moves the hotel off centre.
    static func quote(_ now: Date, family: Family, hotelBase: CGFloat, hotelWidth: CGFloat, cx: CGFloat = 0.5) -> GHSceneSpec {
        switch family {
        case .large:
            return GHSceneSpec(
                now: now, horizon: 0.38,
                back: [
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.33), (0.08, 0.30), (0.16, 0.315), (0.24, 0.27), (0.32, 0.29), (0.4, 0.25), (0.5, 0.265),
                                                            (0.6, 0.25), (0.68, 0.29), (0.76, 0.27), (0.84, 0.315), (0.92, 0.30), (1, 0.33)]), seed: 61),
                            top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.5, snowline: 0.285),
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.45), (0.14, 0.41), (0.26, 0.35), (0.34, 0.27), (0.41, 0.20), (0.46, 0.155), (0.5, 0.13),
                                                            (0.54, 0.155), (0.59, 0.20), (0.66, 0.27), (0.74, 0.35), (0.86, 0.41), (1, 0.45)]), seed: 63, roughness: 0.15),
                            top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.6, snowline: 0.235),
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.42), (0.12, 0.395), (0.24, 0.41), (0.36, 0.44), (0.5, 0.455), (0.64, 0.44), (0.76, 0.41),
                                                            (0.88, 0.395), (1, 0.42)]), seed: 67),
                            top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.4,
                            trees: Trees(height: 5...8, spacing: 7, coverage: 0.55), treeColor: GH.pine)
                ],
                front: [
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.44), (0.1, 0.455), (0.22, 0.48), (0.36, 0.515), (0.5, 0.535), (0.64, 0.515), (0.78, 0.48),
                                                            (0.9, 0.455), (1, 0.44)]), seed: 69),
                            top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.35,
                            trees: Trees(height: 9...14, spacing: 8, coverage: 0.7), treeColor: GH.pineDark)
                ],
                hotel: GHHotelSpec(cx: cx, base: hotelBase, width: hotelWidth, ledgeBottom: hotelBase + 0.17, funicular: false, simple: true),
                arc: SkyArc(centerX: 0.5, horizon: 0.36, radiusX: 0.32, radiusY: 0.25),
                bodyRadius: 10,
                stars: CGRect(x: 0.15, y: 0.07, width: 0.7, height: 0.14), starCount: 10,
                mist: 0.44, weatherRegion: .zero)
        case .medium:
            // The summit stands behind the hotel, wherever the layout puts it.
            let p = cx
            return GHSceneSpec(
                now: now, horizon: 0.5,
                back: [
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.40), (0.12, 0.36), (0.24, 0.38), (0.36, 0.33), (0.48, 0.36), (0.6, 0.31), (0.72, 0.34),
                                                            (0.84, 0.30), (0.92, 0.33), (1, 0.36)]), seed: 71),
                            top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.5, snowline: 0.35),
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.60), (max(0.02, p - 0.4), 0.56), (p - 0.22, 0.42), (p - 0.12, 0.28), (p - 0.05, 0.19), (p, 0.15),
                                                            (p + 0.05, 0.19), (p + 0.12, 0.28), (min(0.98, p + 0.22), 0.42), (1, 0.5)]), seed: 73, roughness: 0.15),
                            top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.6, snowline: 0.3),
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.56), (0.16, 0.53), (0.32, 0.56), (0.5, 0.60), (0.66, 0.57), (0.82, 0.54), (1, 0.56)]), seed: 75),
                            top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.4,
                            trees: Trees(height: 5...8, spacing: 7, coverage: 0.55), treeColor: GH.pine)
                ],
                front: [
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.66), (0.14, 0.68), (0.3, 0.72), (0.5, 0.75), (0.7, 0.72), (0.86, 0.68), (1, 0.66)]), seed: 77),
                            top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.35,
                            trees: Trees(height: 9...13, spacing: 8, coverage: 0.7), treeColor: GH.pineDark)
                ],
                hotel: GHHotelSpec(cx: cx, base: hotelBase, width: hotelWidth, ledgeBottom: hotelBase + 0.2, funicular: false, simple: true),
                arc: SkyArc(centerX: cx, horizon: 0.48, radiusX: 0.16, radiusY: 0.36),
                bodyRadius: 7,
                stars: CGRect(x: max(0, cx - 0.2), y: 0.08, width: 0.4, height: 0.2), starCount: 7,
                mist: 0.64, weatherRegion: .zero)
        case .small:
            return GHSceneSpec(
                now: now, horizon: 0.42,
                back: [
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.36), (0.14, 0.31), (0.28, 0.33), (0.4, 0.27), (0.5, 0.29), (0.6, 0.27), (0.72, 0.33),
                                                            (0.86, 0.31), (1, 0.36)]), seed: 81),
                            top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.5, snowline: 0.31),
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.50), (0.2, 0.44), (0.32, 0.34), (0.42, 0.22), (0.5, 0.16), (0.58, 0.22), (0.68, 0.34),
                                                            (0.8, 0.44), (1, 0.50)]), seed: 83, roughness: 0.15),
                            top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.6, snowline: 0.28),
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.45), (0.2, 0.42), (0.4, 0.46), (0.5, 0.47), (0.6, 0.46), (0.8, 0.42), (1, 0.45)]), seed: 85),
                            top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.4,
                            trees: Trees(height: 6...9, spacing: 8, coverage: 0.55), treeColor: GH.pine)
                ],
                front: [
                    GHLayer(profile: RidgeProfile(keys: k([(0, 0.46), (0.15, 0.48), (0.3, 0.52), (0.5, 0.55), (0.7, 0.52), (0.85, 0.48), (1, 0.46)]), seed: 87),
                            top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.35,
                            trees: Trees(height: 10...15, spacing: 10, coverage: 0.7), treeColor: GH.pineDark)
                ],
                hotel: GHHotelSpec(cx: cx, base: hotelBase, width: hotelWidth, ledgeBottom: hotelBase + 0.14, funicular: false, simple: true),
                arc: SkyArc(centerX: 0.5, horizon: 0.4, radiusX: 0.36, radiusY: 0.28),
                bodyRadius: 8,
                stars: CGRect(x: 0.12, y: 0.08, width: 0.76, height: 0.16), starCount: 5,
                mist: 0.5, weatherRegion: .zero)
        }
    }
}
