import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        if let dir = ProcessInfo.processInfo.environment["EX_STATES_DIR"], !dir.isEmpty {
            EXStates.render(to: URL(fileURLWithPath: dir, isDirectory: true))
        } else {
            MockRunner.run(Expedition())
        }
    }
}

/// Expedition: a 1970s Kodachrome field-station miniature. Felt mountains with wool snowcaps and visible
/// stitching, a mountain cutaway with numbered rooms, embroidered patches, typed logs, rubber stamps, a walnut
/// plinth, a cable car and a weather balloon, all shot frontally under a warm key light with grain and vignette.
struct Expedition: MockAesthetic {
    let name = "Expedition"
    let slug = "expedition"
    let tagline = "A handmade 1970s field station in faded Kodachrome: felt mountains sliced open into numbered rooms, embroidered patches, typed mission logs and library cards under a warm key light."

    @ViewBuilder func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        switch family {
        case .small: EXDaySmall(snap: snapshot)
        case .medium: EXDayMedium(snap: snapshot)
        case .large: EXDayLarge(snap: snapshot)
        }
    }

    @ViewBuilder func quote(_ quote: Quote, family: Family) -> some View {
        switch family {
        case .small: EXQuoteSmall(quote: quote)
        case .medium: EXQuoteMedium(quote: quote)
        case .large: EXQuoteLarge(quote: quote)
        }
    }

    func wallpaper() -> some View { EXWallpaper() }
}
