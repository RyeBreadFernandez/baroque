import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // OC_STATES_DIR=/some/folder renders the states the demo board doesn't show, and leaves out/ alone.
        if OCStates.renderIfRequested() { return }
        MockRunner.run(OMCover())
    }
}

struct OMCover: PaintedLayout {
    let name = "Old Master Cover"
    let slug = "old-master-cover"
    let tagline = "Old Master as a magazine cover: a giant gilt date stands behind the Matterhorn, painted from its true skyline, with the day's grid set on the painting's dark ground."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View { OCDay(snapshot: snapshot, family: family) }
    func quote(_ quote: Quote, family: Family) -> some View { OCQuote(quote: quote, family: family) }
    func wallpaper() -> some View { OCWallpaper() }
}

/// The home screen behind the board: Old Master's Baroque sky of sepia cloud (its texture, reused).
struct OCWallpaper: View {
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
