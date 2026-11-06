import SwiftUI

@main
struct Main {
    @MainActor static func main() { MockRunner.run(FieldJournal()) }
}

/// Field Journal: a naturalist's sketchbook page in daylight. Cream cold-press paper with a deckled fore-edge,
/// loose ink-and-wash mountain studies, washi tape, a taped weather card, pressed plants, and handwriting.
struct FieldJournal: MockAesthetic {
    let name = "Field Journal"
    let slug = "field-journal"
    let tagline = "A naturalist's sketchbook in daylight: ink-and-wash mountains on cold-press paper, washi tape, pressed ferns, and an inked checklist."

    @ViewBuilder func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        switch family {
        case .small: DaySmall(snap: snapshot)
        case .medium: DayMedium(snap: snapshot)
        case .large: DayLarge(snap: snapshot)
        }
    }

    @ViewBuilder func quote(_ quote: Quote, family: Family) -> some View {
        switch family {
        case .small: QuoteSmall(quote: quote)
        case .medium: QuoteMedium(quote: quote)
        case .large: QuoteLarge(quote: quote)
        }
    }

    func wallpaper() -> some View { FJWallpaper() }
}
