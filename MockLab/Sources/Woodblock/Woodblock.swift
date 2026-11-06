import SwiftUI

@main
struct Main {
    @MainActor static func main() { MockRunner.run(Woodblock()) }
}

/// Debug only: WB_SKY=<weather code> re-renders the day widgets under another sky (writes to the same out folder).
let skyOverride: Int? = ProcessInfo.processInfo.environment["WB_SKY"].flatMap { Int($0) }

/// Woodblock: an original ukiyo-e style print. Washi paper, a bokashi Prussian-blue sky, snow-capped ranges cut as
/// separate colour blocks with wood grain and slightly misregistered key lines, kasumi mist bands, sugi and pine
/// silhouettes; a vermilion hanko carries the date, a tanzaku the weekday, and the tasks sit on a handscroll.
struct Woodblock: MockAesthetic {
    let name = "Woodblock"
    let slug = "woodblock"
    let tagline = "An ukiyo-e print on washi: bokashi indigo sky, snow-capped ranges cut as colour blocks, a vermilion date seal, a weekday tanzaku, tasks on a handscroll."

    @MainActor @ViewBuilder func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        let s = Self.applyingOverride(snapshot)
        switch family {
        case .small: DaySmall(s: s)
        case .medium: DayMedium(s: s)
        case .large: DayLarge(s: s)
        }
    }

    static func applyingOverride(_ s: DaySnapshot) -> DaySnapshot {
        guard let code = skyOverride, var w = s.weather else { return s }
        var out = s
        w.code = code % 1000
        w.isDay = code < 1000
        out.weather = w
        return out
    }

    @MainActor @ViewBuilder func quote(_ quote: Quote, family: Family) -> some View {
        switch family {
        case .small: QuoteSmall(q: quote)
        case .medium: QuoteMedium(q: quote)
        case .large: QuoteLarge(q: quote)
        }
    }

    @MainActor @ViewBuilder func wallpaper() -> some View { WBWallpaper() }
}
