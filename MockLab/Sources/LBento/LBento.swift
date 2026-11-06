import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        MockRunner.run(Bento())
        BNStates.renderIfAsked()
    }
}

/// Bento: every widget is a box of separate painted tiles, one fact per tile, with the mountain scene in the
/// gutters and framed in one window tile. Same paint, slabs, wells, pebbles and gilt as the shipped widgets.
struct Bento: PaintedLayout {
    let name = "Bento"
    let slug = "layout-bento"
    let tagline = "A box of small painted tiles, one fact each: a framed window onto the live sky, a gilt date page, carved weather and week wells, and a task slab, with the mountains in the gutters."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        BNDayWidget(snapshot: snapshot, size: BaroqueSize(family), canvas: Mock.size(family))
    }

    func quote(_ quote: Quote, family: Family) -> some View {
        BNQuoteWidget(quote: quote, size: BaroqueSize(family), canvas: Mock.size(family), date: Mock.now)
    }

    func wallpaper() -> some View { PaintedWallpaper() }
}
