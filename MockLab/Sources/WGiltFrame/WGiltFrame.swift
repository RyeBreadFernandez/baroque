import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // GF_STATES_DIR=/some/folder renders the states the demo board doesn't show, and leaves out/ alone.
        if GFStates.renderIfRequested() { return }
        WeatherRunner.run(WGiltFrame())
    }
}

struct WGiltFrame: WeatherMock {
    let name = "Gilt Frame"
    let slug = "weather-gilt-frame"
    let tagline = "An old-master oil of the Matterhorn over the Riffelsee, glazed for the hour and the weather, hangs in a carved gilt frame on oxblood damask, the weather engraved on its brass museum plate."

    func weather(_ snapshot: DaySnapshot, family: Family) -> some View { GFWeather(snapshot: snapshot, family: family) }
    func todo(_ snapshot: DaySnapshot, family: Family) -> some View { GFTodo(snapshot: snapshot, family: family) }
    func wallpaper() -> some View { GFWallpaper() }
}

/// The home screen behind the board: the same oxblood damask, in the half-dark of the gallery, so each widget reads as
/// a lit stretch of wall with its picture.
struct GFWallpaper: View {
    var body: some View {
        GFInk.wallDeep
            .overlay {
                Mock.texture("weather-gilt-frame/wallpaper")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            }
            .clipped()
    }
}
