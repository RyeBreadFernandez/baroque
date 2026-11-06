import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        MockRunner.run(Current())
    }
}

/// The shipped widgets, rendered through the same macOS path as the mocks: the app's own CoverDayView and
/// CoverQuoteView from Shared/ at the iPhone 17 design sizes (and the check that they compile and paint here, with
/// the Cover* textures from Shared/PaintTextures.xcassets). Compare with out/old-master-cover/, the mock they came from.
struct Current: PaintedLayout {
    let name = "Current layout"
    let slug = "layout-current"
    let tagline = "What ships today: Old Master Cover. A giant gilt date stands behind the Matterhorn in a sepia oil painting, with the day's weather, tasks and month on the painting's dark ground."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        CoverDayView(snapshot: snapshot, settings: BaroqueSettings(), size: BaroqueSize(family))
    }

    func quote(_ quote: Quote, family: Family) -> some View {
        CoverQuoteView(quote: quote, size: BaroqueSize(family), date: Mock.now) { CoverNextButton() }
    }

    func wallpaper() -> some View { CurrentWallpaper() }
}

/// The board's home screen: Old Master's Baroque sky of sepia cloud, as on the Cover mock's board.
struct CurrentWallpaper: View {
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
