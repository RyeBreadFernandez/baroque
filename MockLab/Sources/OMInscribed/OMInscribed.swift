import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // OI_STATES_DIR=/some/folder renders the states the demo board doesn't show, and leaves out/ alone.
        if OIStates.renderIfRequested() { return }
        MockRunner.run(OMInscribed())
    }
}

struct OMInscribed: PaintedLayout {
    let name = "Old Master Inscribed"
    let slug = "old-master-inscribed"
    let tagline = "No panel: sepia mountain paintings composed for their words, the date in the cloud, the day as an engraved sundial, the tasks on a still dark lake."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View { OIDay(snapshot: snapshot, family: family) }
    func quote(_ quote: Quote, family: Family) -> some View { OIQuote(quote: quote, family: family) }
    func wallpaper() -> some View { OIWallpaper() }
}

/// The home screen behind the board: Old Master's Baroque sky of sepia cloud.
struct OIWallpaper: View {
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
