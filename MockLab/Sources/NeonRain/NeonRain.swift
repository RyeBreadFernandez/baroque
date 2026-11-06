import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        if let dir = ProcessInfo.processInfo.environment["NR_STATES_DIR"], !dir.isEmpty {
            NRStates.render(to: URL(fileURLWithPath: dir, isDirectory: true))
        } else {
            MockRunner.run(NeonRain())
        }
    }
}

/// Neon Rain: a night street at the foot of misty mountains, seen through rain-wet glass. Neon tube numerals,
/// a Chinese weekday lightbox, dot-matrix expiry stamps, step-printed tail lights and yellow burned-in subtitles,
/// under heavy grain and halation. Always drawn at night or dusk, whatever the clock says.
struct NeonRain: MockAesthetic {
    let name = "Neon Rain"
    let slug = "neon-rain"
    let tagline = "A rain-wet night street at the foot of misty mountains, seen through fogged glass: neon tube numerals, dot-matrix expiry stamps, step-printed tail lights and yellow subtitles under heavy grain."

    @ViewBuilder func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        switch family {
        case .small: NRDaySmall(snap: snapshot)
        case .medium: NRDayMedium(snap: snapshot)
        case .large: NRDayLarge(snap: snapshot)
        }
    }

    @ViewBuilder func quote(_ quote: Quote, family: Family) -> some View {
        switch family {
        case .small: NRQuoteSmall(quote: quote)
        case .medium: NRQuoteMedium(quote: quote)
        case .large: NRQuoteLarge(quote: quote)
        }
    }

    func wallpaper() -> some View { NRWallpaper() }
}

/// The home screen behind the widgets: the same street, much wider and out of focus, behind a streaming pane.
struct NRWallpaper: View {
    var body: some View {
        let spec = NRSceneSpec(
            far: [CGPoint(x: -0.05, y: 0.22), CGPoint(x: 0.12, y: 0.12), CGPoint(x: 0.3, y: 0.2), CGPoint(x: 0.5, y: 0.06),
                  CGPoint(x: 0.7, y: 0.17), CGPoint(x: 0.86, y: 0.1), CGPoint(x: 1.05, y: 0.2)],
            mid: [CGPoint(x: -0.05, y: 0.36), CGPoint(x: 0.16, y: 0.26), CGPoint(x: 0.34, y: 0.34), CGPoint(x: 0.56, y: 0.18),
                  CGPoint(x: 0.74, y: 0.3), CGPoint(x: 1.05, y: 0.26)],
            near: [CGPoint(x: -0.05, y: 0.48), CGPoint(x: 0.3, y: 0.42), CGPoint(x: 0.6, y: 0.47), CGPoint(x: 1.05, y: 0.43)],
            city: 0.5...0.62, street: 0.68, mast: 0.56,
            lamps: [CGPoint(x: 0.44, y: 0.46), CGPoint(x: 0.52, y: 0.38), CGPoint(x: 0.48, y: 0.3), CGPoint(x: 0.555, y: 0.22)],
            houses: 220,
            signs: [NRSign(at: CGPoint(x: 0.2, y: 0.58), kind: .vbar, color: NR.magenta, core: NR.magentaCore, scale: 2.4),
                    NRSign(at: CGPoint(x: 0.7, y: 0.6), kind: .box, color: NR.cyan, core: NR.cyanCore, scale: 2)],
            lights: NRQuoteScene.lights, weather: .rain, soft: true, seed: 51, tilt: -2)
        ZStack {
            NRSceneView(spec: spec).blur(radius: 4)
            Color.black.opacity(0.42)
            NRGlassView(spec: NRGlassSpec(weather: .rain, seed: 52, lights: NRQuoteScene.lights, fog: 0.6))
            NRFilm(leak: .topTrailing, grain: 0.4)
        }
        .background(NR.ink)
    }
}
