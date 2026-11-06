import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // OF_STATES_DIR=/some/folder renders the states the demo board doesn't show, and leaves out/ alone.
        if OFStates.renderIfRequested() { return }
        MockRunner.run(OMFolio())
    }
}

struct OMFolio: PaintedLayout {
    let name = "Old Master Folio"
    let slug = "old-master-folio"
    let tagline = "Each widget is an antique book lying open on velvet: a tipped-in oil plate of the mountains faces the day's page, set with a dropped initial, numbered lines and marginal notes."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View { OFDay(snapshot: snapshot, family: family) }
    func quote(_ quote: Quote, family: Family) -> some View { OFQuote(quote: quote, family: family) }
    func wallpaper() -> some View { OFWallpaper() }
}

/// The home screen behind the board: Old Master's sepia Baroque sky.
struct OFWallpaper: View {
    var body: some View {
        Color(hex: 0x2A1B12)
            .overlay {
                Mock.texture("old-master/wallpaper")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            }
            .overlay(CanvasWeave(opacity: 0.7))
            .clipped()
    }
}
