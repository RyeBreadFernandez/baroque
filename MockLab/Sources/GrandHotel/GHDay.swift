import SwiftUI

// Day widgets: the concierge's desk in front of the painted hotel. The date is a postage stamp, the weather a brass
// barometer with a velvet ribbon, the week a cabinet of pigeonholes and the tasks a page of the register, each task a
// numbered room key. Positions are fixed points on the iPhone 17 widget sizes (Mock.size), and the ridge key points
// below are placed around them: the summit rises behind the tower between the stamp and the barometer.

enum GHDayScenes {
    private static func k(_ pts: [(CGFloat, CGFloat)]) -> [CGPoint] { pts.map { CGPoint(x: $0.0, y: $0.1) } }

    static func large(_ snap: DaySnapshot) -> GHSceneSpec {
        GHSceneSpec(
            now: snap.date, weather: snap.weather, horizon: 0.34,
            back: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.30), (0.07, 0.255), (0.14, 0.275), (0.22, 0.225), (0.3, 0.26), (0.38, 0.215), (0.5, 0.235),
                                                        (0.62, 0.215), (0.7, 0.26), (0.78, 0.225), (0.86, 0.275), (0.93, 0.255), (1, 0.30)]), seed: 11),
                        top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.55, snowline: 0.245),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.40), (0.14, 0.37), (0.26, 0.31), (0.34, 0.24), (0.41, 0.17), (0.46, 0.13), (0.5, 0.105),
                                                        (0.54, 0.13), (0.59, 0.17), (0.66, 0.24), (0.74, 0.31), (0.86, 0.37), (1, 0.40)]), seed: 13, roughness: 0.15),
                        top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.7, snowline: 0.205),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.37), (0.1, 0.345), (0.2, 0.36), (0.3, 0.39), (0.4, 0.41), (0.5, 0.42), (0.6, 0.41),
                                                        (0.7, 0.39), (0.8, 0.36), (0.9, 0.345), (1, 0.37)]), seed: 17),
                        top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.45,
                        trees: Trees(height: 5...9, spacing: 5, coverage: 0.7), treeColor: GH.pine)
            ],
            front: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.39), (0.08, 0.405), (0.16, 0.43), (0.26, 0.47), (0.36, 0.50), (0.5, 0.52), (0.64, 0.50),
                                                        (0.74, 0.47), (0.84, 0.43), (0.92, 0.405), (1, 0.39)]), seed: 19),
                        top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.4,
                        trees: Trees(height: 9...15, spacing: 6, coverage: 0.85), treeColor: GH.pineDark)
            ],
            hotel: GHHotelSpec(base: 0.35, width: 128, ledgeBottom: 0.53),
            arc: SkyArc(centerX: 0.5, horizon: 0.33, radiusX: 0.27, radiusY: 0.26),
            bodyRadius: 9, trail: true,
            stars: CGRect(x: 0.3, y: 0.07, width: 0.4, height: 0.12), starCount: 16,
            mist: 0.40, weatherRegion: CGRect(x: 0, y: 0.05, width: 1, height: 0.42))
    }

    static func medium(_ snap: DaySnapshot) -> GHSceneSpec {
        GHSceneSpec(
            now: snap.date, weather: snap.weather, horizon: 0.5,
            back: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.42), (0.08, 0.36), (0.16, 0.39), (0.25, 0.31), (0.34, 0.36), (0.42, 0.30), (0.5, 0.33),
                                                        (0.58, 0.30), (0.66, 0.36), (0.75, 0.31), (0.84, 0.39), (0.92, 0.36), (1, 0.42)]), seed: 41),
                        top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.55, snowline: 0.35),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.60), (0.16, 0.55), (0.28, 0.45), (0.37, 0.33), (0.44, 0.22), (0.5, 0.16), (0.56, 0.22),
                                                        (0.63, 0.33), (0.72, 0.45), (0.84, 0.55), (1, 0.60)]), seed: 43, roughness: 0.15),
                        top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.7, snowline: 0.31),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.50), (0.12, 0.46), (0.25, 0.50), (0.38, 0.55), (0.5, 0.57), (0.62, 0.55), (0.75, 0.50),
                                                        (0.88, 0.46), (1, 0.50)]), seed: 47),
                        top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.45,
                        trees: Trees(height: 5...9, spacing: 5, coverage: 0.7), treeColor: GH.pine)
            ],
            front: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.50), (0.1, 0.52), (0.22, 0.56), (0.36, 0.62), (0.5, 0.64), (0.64, 0.62), (0.78, 0.56),
                                                        (0.9, 0.52), (1, 0.50)]), seed: 49),
                        top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.4,
                        trees: Trees(height: 8...13, spacing: 6, coverage: 0.85), treeColor: GH.pineDark)
            ],
            hotel: GHHotelSpec(base: 0.45, width: 92, ledgeBottom: 0.64),
            arc: SkyArc(centerX: 0.5, horizon: 0.45, radiusX: 0.3, radiusY: 0.36),
            bodyRadius: 7,
            stars: CGRect(x: 0.22, y: 0.12, width: 0.56, height: 0.2), starCount: 10,
            mist: 0.55, weatherRegion: CGRect(x: 0, y: 0.08, width: 1, height: 0.45))
    }

    static func small(_ snap: DaySnapshot) -> GHSceneSpec {
        GHSceneSpec(
            now: snap.date, weather: snap.weather, horizon: 0.52,
            back: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.40), (0.12, 0.33), (0.25, 0.37), (0.38, 0.28), (0.5, 0.32), (0.62, 0.28), (0.75, 0.37),
                                                        (0.88, 0.33), (1, 0.40)]), seed: 51),
                        top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.55, snowline: 0.34),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.62), (0.2, 0.52), (0.32, 0.42), (0.42, 0.30), (0.5, 0.24), (0.58, 0.30), (0.68, 0.42),
                                                        (0.8, 0.52), (1, 0.62)]), seed: 53, roughness: 0.15),
                        top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.7, snowline: 0.37),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.56), (0.2, 0.52), (0.4, 0.56), (0.5, 0.58), (0.6, 0.56), (0.8, 0.52), (1, 0.56)]), seed: 55),
                        top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.45,
                        trees: Trees(height: 7...11, spacing: 6, coverage: 0.7), treeColor: GH.pine)
            ],
            front: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.52), (0.15, 0.55), (0.3, 0.60), (0.5, 0.63), (0.7, 0.60), (0.85, 0.55), (1, 0.52)]), seed: 57),
                        top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.4,
                        trees: Trees(height: 12...18, spacing: 8, coverage: 0.85), treeColor: GH.pineDark)
            ],
            hotel: GHHotelSpec(base: 0.535, width: 60, ledgeBottom: 0.66),
            arc: SkyArc(centerX: 0.5, horizon: 0.5, radiusX: 0.12, radiusY: 0.36),
            bodyRadius: 12,
            stars: CGRect(x: 0.36, y: 0.12, width: 0.28, height: 0.18), starCount: 6,
            mist: 0.57, weatherRegion: CGRect(x: 0, y: 0.08, width: 1, height: 0.5))
    }
}

struct GHDayWidget: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .small: GHDaySmall(snap: snapshot)
        case .medium: GHDayMedium(snap: snapshot)
        case .large: GHDayLarge(snap: snapshot)
        }
    }
}

/// Labels for the weather props.
enum GHWeatherText {
    static func condition(_ snap: DaySnapshot) -> String {
        snap.weather?.label.uppercased() ?? "NO REPORT"
    }

    static func detail(_ snap: DaySnapshot) -> String {
        if let w = snap.weather { return "H \(GHText.temp(w.high))  ·  L \(GHText.temp(w.low))" }
        return (snap.weatherError ?? "Unavailable").uppercased()
    }

    /// Sunrise and sunset, today's.
    static func sun(_ snap: DaySnapshot) -> [String] {
        guard let w = snap.weather, let rise = w.sunrise, let set = w.sunset else { return ["SUNRISE  —", "SUNSET  —"] }
        return ["SUNRISE \(GHDates.clock(rise))", "SUNSET \(GHDates.clock(set))"]
    }
}

// MARK: - Large

struct GHDayLarge: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.large)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GHDayScenes.large(snap))
                .frame(width: s.width, height: s.height)
            GoldFrame(inset: 6, ornament: false)
            GHValance(depth: 22, scallops: 9).ghPlace(0, 0, s.width, 30)

            GHDateStamp(date: snap.date, style: .large).ghPlace(18, 30, 80, 88)
            GHPostmark(year: GHDates.string(snap.date, "yyyy"), diameter: 30, waves: 0)
                .rotationEffect(.degrees(-10))
                .ghPlace(83, 21, 30, 30)
            GHBarometer(weather: snap.weather, diameter: 80).ghPlace(250, 30, 80, 80)

            GHPlaque(lines: GHWeatherText.sun(snap))
                .fixedSize()
                .position(x: 58, y: 138)
            GHPlaque(lines: [GHWeatherText.condition(snap), GHWeatherText.detail(snap)])
                .frame(maxWidth: 100)
                .fixedSize(horizontal: false, vertical: true)
                .position(x: 287, y: 132)

            GHPigeonholes(date: snap.date, tasks: snap.tasks, height: 32).ghPlace(16, 178, 316, 32)
            GHRegister(tasks: snap.tasks, error: snap.taskError, now: snap.date, style: .large).ghPlace(16, 220, 316, 131)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

// MARK: - Medium

struct GHDayMedium: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.medium)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GHDayScenes.medium(snap))
                .frame(width: s.width, height: s.height)
            GoldFrame(inset: 6, ornament: false)
            GHValance(depth: 13, scallops: 12).ghPlace(0, 0, s.width, 21)

            GHDateStamp(date: snap.date, style: .medium).ghPlace(18, 19, 48, 58)
            GHPostmark(year: nil, diameter: 22, waves: 2).rotationEffect(.degrees(-6)).ghPlace(58, 30, 50, 22)
            GHBarometer(weather: snap.weather, diameter: 52).ghPlace(264, 16, 52, 52)
            GHPlaque(lines: [snap.weather == nil ? GHWeatherText.detail(snap) : GHWeatherText.condition(snap)], ribbon: true, size: 8)
                .frame(maxWidth: 104)
                .fixedSize(horizontal: false, vertical: true)
                .position(x: 290, y: 69)

            GHRegister(tasks: snap.tasks, error: snap.taskError, now: snap.date, style: .medium).ghPlace(16, 82, 316, 68)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

// MARK: - Small

struct GHDaySmall: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.small)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GHDayScenes.small(snap))
                .frame(width: s.width, height: s.height)
            GoldFrame(inset: 5, ornament: false)
            GHValance(depth: 11, scallops: 6).ghPlace(0, 0, s.width, 19)

            GHDateStamp(date: snap.date, style: .small).ghPlace(16, 18, 42, 52)
            GHBarometer(weather: snap.weather, diameter: 46).ghPlace(102, 19, 46, 46)

            GHRegister(tasks: snap.tasks, error: snap.taskError, now: snap.date, style: .small).ghPlace(13, 94, 138, 56)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}
