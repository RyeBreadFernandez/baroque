import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // SB_STATES_DIR=/some/folder renders the states the board doesn't show, and leaves out/ alone.
        if SBStates.renderIfRequested() { return }
        WeatherRunner.run(WStorybook())
    }
}

struct WStorybook: WeatherMock {
    let name = "Storybook Night"
    let slug = "weather-storybook"
    let tagline = "A gouache picture-book plate of the Matterhorn over a still lake, framed in dark lacquer and gold filigree; the month is a chapter heading, the sun times are lettered on a ribbon, and the to-do list is written on parchment."

    func weather(_ snapshot: DaySnapshot, family: Family) -> some View { SBWeather(snapshot: snapshot, family: family) }
    func todo(_ snapshot: DaySnapshot, family: Family) -> some View { SBTodo(snapshot: snapshot, family: family) }
    func wallpaper() -> some View { SBWallpaper() }
}

/// The home screen behind the board: a storybook night over a dark wood (its own painting, dimmed).
struct SBWallpaper: View {
    var body: some View {
        SBInk.night
            .overlay {
                Mock.texture("weather-storybook/wallpaper")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            }
            .clipped()
    }
}
