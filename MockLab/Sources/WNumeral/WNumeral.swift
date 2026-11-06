import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // GN_STATES_DIR=/some/folder renders the states the board doesn't show, and leaves out/ alone.
        if GNStates.renderIfRequested() { return }
        WeatherRunner.run(WNumeral())
    }
}

struct WNumeral: WeatherMock {
    let name = "Giant Numeral"
    let slug = "weather-numeral"
    let tagline = "The temperature as a huge thin numeral standing in the fog between the Matterhorn and the spruce, painted in olive, sage and fog, with the sun times on one strip of frosted mist."

    func weather(_ snapshot: DaySnapshot, family: Family) -> some View { GNWeatherView(snap: snapshot, family: family) }
    func todo(_ snapshot: DaySnapshot, family: Family) -> some View { GNTodoView(snap: snapshot, family: family) }
    func wallpaper() -> some View { GNWallpaper() }
}

/// The home screen behind the board: spruce ranks receding into fog under a ghost of the Matterhorn.
struct GNWallpaper: View {
    var body: some View {
        Color(hex: 0x2C3629)
            .overlay {
                Mock.texture("weather-numeral/wallpaper")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            }
            .overlay(CanvasWeave(opacity: 0.5))
            .clipped()
    }
}
