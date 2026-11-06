import SwiftUI

@main
struct Main {
    @MainActor static func main() { MockRunner.run(StainedGlass()) }
}

/// Art Nouveau cathedral glass lit from behind: jewel panes in lead cames, a rose-window sun,
/// faceted glass mountains, and pale cathedral-glass panels lettered in grisaille.
struct StainedGlass: MockAesthetic {
    let name = "Stained Glass"
    let slug = "stained-glass"
    let tagline = "Backlit Art Nouveau cathedral glass: jewel panes in lead, a rose-window sun over faceted mountains, tasks lettered in grisaille on pale panes."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        switch family {
        case .small: DaySmall(snap: snapshot)
        case .medium: DayMedium(snap: snapshot)
        case .large: DayLarge(snap: snapshot)
        }
    }

    func quote(_ quote: Quote, family: Family) -> some View {
        switch family {
        case .small: QuoteSmall(quote: quote)
        case .medium: QuoteMedium(quote: quote)
        case .large: QuoteLarge(quote: quote)
        }
    }

    func wallpaper() -> some View { GlassWallpaper() }
}
