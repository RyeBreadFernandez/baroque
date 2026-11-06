import SwiftUI
import Foundation

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        MockRunner.run(Plate())
        // Optional: PLATE_STATES_DIR=<folder> also renders the states the demo data never reaches.
        if let dir = ProcessInfo.processInfo.environment["PLATE_STATES_DIR"], !dir.isEmpty {
            PLStates.render(to: URL(fileURLWithPath: dir, isDirectory: true))
        }
    }
}

/// Storybook Plate: figure and ground swapped. The brushed espresso board is the widget; the painting is
/// a framed plate sunk into it, with the date, weather and tasks written on the board around it.
struct Plate: PaintedLayout {
    let name = "Storybook Plate"
    let slug = "layout-plate"
    let tagline = "The painting becomes a framed plate sunk into a brushed board, like a book illustration; the weather is its caption, and the date, ledger of tasks and drop-capped quote are set on the board around it."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        PLDayWidget(snapshot: snapshot, family: family)
    }

    func quote(_ quote: Quote, family: Family) -> some View {
        PLQuoteWidget(quote: quote, family: family)
    }

    func wallpaper() -> some View { PaintedWallpaper() }
}
