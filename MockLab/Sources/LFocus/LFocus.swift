import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        NUStates.renderIfRequested()
        MockRunner.run(NextUp())
    }
}

/// Next Up: one thing at a time. The most urgent task (or the quote) is set large on a raised painted card,
/// the rest of the deck waits behind it, and the date and weather shrink to a slim line over the mountains.
struct NextUp: PaintedLayout {
    let name = "Next Up"
    let slug = "layout-next-up"
    let tagline = "One thing at a time: the most urgent task is set large on a raised card with the rest of the deck behind it, and the date and weather shrink to one slim line over the mountains."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        NUDayWidget(snapshot: snapshot, family: family)
    }

    func quote(_ quote: Quote, family: Family) -> some View {
        NUQuoteWidget(quote: quote, family: family, date: Mock.now)
    }

    func wallpaper() -> some View { PaintedWallpaper() }
}
