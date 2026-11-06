import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // GC_STATES_DIR=/some/folder renders the states the demo boards don't show (both variants), and leaves out/ alone.
        if GCStates.renderIfRequested() { return }
        MockRunner.run(GCQuiet())
        MockRunner.run(GCSpare())
    }
}

/// Variant A: Grand Hotel's arrangement with the ornament taken away.
struct GCQuiet: PaintedLayout {
    let name = "Grand Hotel Quiet"
    let slug = "grand-hotel-quiet"
    let tagline = "Grand Hotel with the ornament taken away: one slim valance, gilt numerals and spaced capitals on the painted sky, the week in one carved channel, the tasks on one quiet slab."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View { GCQuietDay(snapshot: snapshot, family: family) }
    func quote(_ quote: Quote, family: Family) -> some View { GCQuietQuote(quote: quote, family: family) }
    func wallpaper() -> some View { GCBoardWallpaper() }
}

/// Variant B: the painted scene and one raised slab, nothing else.
struct GCSpare: PaintedLayout {
    let name = "Grand Hotel Spare"
    let slug = "grand-hotel-spare"
    let tagline = "Two things to each widget: the painted scene, and one raised slab. The date and the weather are gilt and capitals flanking the hotel; the week, the tasks and the count are type on the slab."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View { GCSpareDay(snapshot: snapshot, family: family) }
    func quote(_ quote: Quote, family: Family) -> some View { GCSpareQuote(quote: quote, family: family) }
    func wallpaper() -> some View { GCBoardWallpaper() }
}

/// The home screen behind both boards: Grand Hotel's velvet corridor (GHBoardWallpaper's construction), so the Calm
/// boards compare with the Grand Hotel board on the same ground.
struct GCBoardWallpaper: View {
    var body: some View {
        GHSurface(material: .velvet, weave: 1)
            .overlay(PaintRelief(name: "PaintSky", opacity: 0.35))
            .overlay(RadialGradient(colors: [.clear, Color(hex: 0x2A0A1A).opacity(0.7)], center: .center, startRadius: 200, endRadius: 760))
            .overlay(Color(hex: 0x3A0D22).opacity(0.25))
    }
}

@MainActor
enum GCStates {
    /// Returns true when it rendered the states (and the normal run should be skipped).
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["GC_STATES_DIR"], !path.isEmpty else { return false }
        let root = URL(fileURLWithPath: path, isDirectory: true)

        let base = Mock.day
        let error = "GitHub returned 401. Check the token in Settings."
        let cal = Calendar.current
        func at(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: Mock.now) ?? Mock.now }
        func with(_ f: (inout DaySnapshot) -> Void) -> DaySnapshot { var s = base; f(&s); return s }

        let days: [(String, DaySnapshot)] = [
            ("empty", with { $0.tasks = [] }),
            ("error-cached", with { $0.taskError = error }),
            ("error-empty", with { $0.tasks = []; $0.taskError = error }),
            ("no-weather", with { $0.weather = nil; $0.weatherError = "Offline" }),
            ("rain", with { $0.weather?.code = 63; $0.weather?.temperature = 51; $0.weather?.high = 54; $0.weather?.low = 46 }),
            ("snow", with { $0.weather?.code = 73; $0.weather?.temperature = 28; $0.weather?.high = 31; $0.weather?.low = 19 }),
            ("dusk", with { $0.date = at(16, 45) }),
            ("night", with { $0.date = at(21, 0) }),
            ("one-task", with { $0.tasks = Array(base.tasks.prefix(1)) })
        ]
        let long = Quote(text: "The mountains are not there to be conquered. Climb slowly, keep the hotel lights in view, and remember that every summit is only a very large stair you have agreed to take one step at a time, all afternoon.",
                         author: "A guest of the hotel, written in the register at the end of a very long season")
        let quotes: [(String, Quote, Date)] = [
            ("long", long, Mock.now),
            ("no-author", DemoData.quotes[2], Mock.now),
            ("long-no-author", Quote(text: long.text, author: nil), Mock.now),
            ("dusk", DemoData.quotes[0], at(17, 40)),
            ("night", DemoData.quotes[1], at(21, 0))
        ]

        for variant in ["quiet", "spare"] {
            let dir = root.appendingPathComponent(variant, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (name, snap) in days {
                for f in Family.allCases {
                    let url = dir.appendingPathComponent("day-\(name)-\(f.rawValue).png")
                    if variant == "quiet" {
                        MockRunner.write(WidgetTile(family: f) { GCQuietDay(snapshot: snap, family: f) }, scale: 3, to: url)
                    } else {
                        MockRunner.write(WidgetTile(family: f) { GCSpareDay(snapshot: snap, family: f) }, scale: 3, to: url)
                    }
                }
            }
            for (name, q, now) in quotes {
                for f in Family.allCases {
                    let url = dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png")
                    if variant == "quiet" {
                        MockRunner.write(WidgetTile(family: f) { GCQuietQuote(quote: q, family: f, now: now) }, scale: 3, to: url)
                    } else {
                        MockRunner.write(WidgetTile(family: f) { GCSpareQuote(quote: q, family: f, now: now) }, scale: 3, to: url)
                    }
                }
            }
        }
        print("Rendered Grand Hotel Calm states to \(root.path)")
        return true
    }
}
