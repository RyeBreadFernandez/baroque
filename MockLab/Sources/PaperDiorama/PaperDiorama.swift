import SwiftUI

@main
struct Main {
    @MainActor static func main() { MockRunner.run(PaperDiorama()) }
}

/// Paper Diorama: every widget is a shadowbox of cut cardstock in daylight. Mountains, hills and
/// pine forest are separate sheets with hand-cut edges and soft shadows between them; the tasks sit
/// on an index card clipped into the scene, with punched-hole checkboxes ringed by priority colour.
struct PaperDiorama: MockAesthetic {
    let name = "Paper Diorama"
    let slug = "paper-diorama"
    let tagline = "A cut-paper shadowbox in bright daylight: layered cardstock mountains, a paper sun, and your day on a clipped index card."

    @MainActor @ViewBuilder
    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        switch family {
        case .small: DaySmall(snapshot: snapshot)
        case .medium: DayMedium(snapshot: snapshot)
        case .large: DayLarge(snapshot: snapshot)
        }
    }

    @MainActor @ViewBuilder
    func quote(_ quote: Quote, family: Family) -> some View {
        switch family {
        case .small: QuoteSmall(quote: quote)
        case .medium: QuoteMedium(quote: quote)
        case .large: QuoteLarge(quote: quote)
        }
    }

    @MainActor @ViewBuilder
    func wallpaper() -> some View { PaperWallpaper() }
}
