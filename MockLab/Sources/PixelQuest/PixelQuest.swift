import SwiftUI

@main
struct Main {
    @MainActor static func main() { MockRunner.run(PixelQuest()) }
}

/// Pixel Quest: a 16-bit fantasy overworld. Everything is painted into an indexed framebuffer on a 2 pt grid
/// (dithered sky, snowcapped ranges, pine forests), with JRPG windows for the Quest Log and an owl sage's dialogue box.
struct PixelQuest: MockAesthetic {
    let name = "Pixel Quest"
    let slug = "pixel-quest"
    let tagline = "A 16-bit overworld: dithered skies, snowcapped pixel ranges, a Quest Log window and an owl sage who speaks your quotes."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        switch family {
        case .small: DaySmall(s: snapshot)
        case .medium: DayMedium(s: snapshot)
        case .large: DayLarge(s: snapshot)
        }
    }

    func quote(_ quote: Quote, family: Family) -> some View {
        switch family {
        case .small: QuoteSmall(q: quote)
        case .medium: QuoteMedium(q: quote)
        case .large: QuoteLarge(q: quote)
        }
    }

    func wallpaper() -> some View { Wallpaper() }
}
