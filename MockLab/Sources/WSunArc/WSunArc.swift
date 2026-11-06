import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // SA_STATES_DIR=/some/folder renders the states the board doesn't show, and leaves out/ alone.
        if SAStates.renderIfRequested() { return }
        // SA_HOME=1 renders the two home screen pages built round Sun Arc (SAHome.swift), in SA_SCENE's landscape.
        if SAHome.renderIfRequested() { return }
        // SA_TRAV=1 renders Baroque in travertine, after the user's second Pinterest pin (TVHome.swift).
        if TVRender.renderIfRequested() { return }
        // SA_SCENE=<name> renders the Weather widget in another landscape (SALandscape.swift).
        if let scene = SALandscape.name { SALandscape.render(scene); return }
        WeatherRunner.run(WSunArc())
    }
}

struct WSunArc: WeatherMock {
    let name = "Sun Arc"
    let slug = "weather-sun-arc"
    let tagline = "The sky of a sepia oil of the Matterhorn is the sun's path: a fine gilt arc, solid for the daylight gone and dashed for what's left, with the sun or tonight's moon on it, the times engraved at its feet and the temperature in raised gilt below."

    func weather(_ snapshot: DaySnapshot, family: Family) -> some View { SAWeather(snap: snapshot, family: family) }
    func todo(_ snapshot: DaySnapshot, family: Family) -> some View { SATodo(snap: snapshot, family: family) }
    func wallpaper() -> some View { SAWallpaper() }
}

/// The home screen behind the board: a sepia Baroque cloudscape painted for this board.
struct SAWallpaper: View {
    var body: some View {
        Color(hex: 0x2A1B12)
            .overlay {
                Mock.texture("weather-sun-arc/wallpaper")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            }
            .overlay(CanvasWeave(opacity: 0.7))
            .clipped()
    }
}
