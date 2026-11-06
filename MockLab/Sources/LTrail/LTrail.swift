import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        MockRunner.run(Trail())
        TRStates.renderIfRequested()
    }
}

/// Tasks as a path through time: Late, Today, Soon and Someday are copper waypoints on a gold thread, the week
/// ahead counts what falls due each day, and a quote becomes a margin note beside the same thread.
struct Trail: PaintedLayout {
    let name = "Trail"
    let slug = "layout-trail"
    let tagline = "Tasks as a path through time: Late, Today, Soon and Someday are copper waypoints on a gold thread, the week ahead counts what's due each day, and quotes become margin notes."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        TRDayWidget(snapshot: snapshot, family: family)
    }

    func quote(_ quote: Quote, family: Family) -> some View {
        TRQuoteWidget(quote: quote, family: family, date: Mock.now)
    }

    func wallpaper() -> some View { PaintedWallpaper() }
}
