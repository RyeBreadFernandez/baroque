import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // OM_STATES_DIR=/some/folder renders the states the demo board doesn't show, and leaves out/ alone.
        if OMStates.renderIfRequested() { return }
        MockRunner.run(OldMaster())
    }
}

struct OldMaster: PaintedLayout {
    let name = "Old Master"
    let slug = "old-master"
    let tagline = "Original sublime mountain paintings in sepia oils, glazed for the hour and the weather, with the date and tasks on one calm umber panel."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View { OMDay(snapshot: snapshot, family: family) }
    func quote(_ quote: Quote, family: Family) -> some View { OMQuote(quote: quote, family: family) }
    func wallpaper() -> some View { OMWallpaper() }
}

/// The home screen behind the board: a Baroque sky of towering sepia cloud, like the reference's backgrounds.
struct OMWallpaper: View {
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
