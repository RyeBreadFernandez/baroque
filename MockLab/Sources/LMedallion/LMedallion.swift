import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        MockRunner.run(Medallion())
        // Optional: MD_STATES_DIR=<folder> also renders the states the demo doesn't show (night, weather,
        // no tasks, fetch errors, missing weather, short and long quotes).
        if let dir = ProcessInfo.processInfo.environment["MD_STATES_DIR"] {
            MDStates.render(to: URL(fileURLWithPath: dir, isDirectory: true))
        }
    }
}

/// Centered and symmetrical, like a storybook title page: everything hangs on the vertical axis.
struct Medallion: PaintedLayout {
    let name = "Medallion"
    let slug = "layout-medallion"
    let tagline = "A storybook title page on one center axis: the date in a coin-lettered medallion inside its sunrise-to-sunset dial, standing on a snowy summit between weather and tasks; tonight's moon in an arched window over the quote."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        MDDay(snapshot: snapshot, size: BaroqueSize(family))
    }

    func quote(_ quote: Quote, family: Family) -> some View {
        MDQuote(quote: quote, size: BaroqueSize(family), date: Mock.now)
    }

    func wallpaper() -> some View { PaintedWallpaper() }
}
