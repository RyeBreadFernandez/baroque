import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // GH_STATES_DIR=/some/folder renders the states the demo board doesn't show, and leaves out/ alone.
        if GHStates.renderIfRequested() { return }
        MockRunner.run(GrandHotel())
    }
}

/// Grand Hotel: the confectionery alpine hotel set, painted in the app's own storybook construction. Brushed pastel
/// sky and ridges, a painted pink hotel on its ledge, and every prop a raised painted slab or polished pebble.
struct GrandHotel: PaintedLayout {
    let name = "Grand Hotel"
    let slug = "grand-hotel"
    let tagline = "A painted pink grand hotel on its alpine ledge, staged head-on under a velvet valance: the date on a postage stamp, the weather on a brass barometer, the week in pigeonholes and the tasks as room keys, every prop a brushed, raised slab."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        GHDayWidget(snapshot: snapshot, family: family)
    }

    func quote(_ quote: Quote, family: Family) -> some View {
        GHQuoteWidget(quote: quote, family: family)
    }

    func wallpaper() -> some View { GHBoardWallpaper() }
}

/// The home screen behind the board: the hotel corridor's velvet, painted, under a claret vignette, dark enough that
/// the pastel widgets stand off it.
struct GHBoardWallpaper: View {
    var body: some View {
        GHSurface(material: .velvet, weave: 1)
            .overlay(PaintRelief(name: "PaintSky", opacity: 0.35))
            .overlay(RadialGradient(colors: [.clear, Color(hex: 0x2A0A1A).opacity(0.7)], center: .center, startRadius: 200, endRadius: 760))
            .overlay(Color(hex: 0x3A0D22).opacity(0.25))
    }
}

@MainActor
enum GHStates {
    /// Returns true when it rendered the states (and the normal run should be skipped).
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["GH_STATES_DIR"], !path.isEmpty else { return false }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

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
            ("partly", with { $0.weather?.code = 2 }),
            ("dusk", with { $0.date = at(16, 45) }),
            ("night", with { $0.date = at(21, 0) }),
            ("one-task", with { $0.tasks = Array(base.tasks.prefix(1)) })
        ]
        for (name, snap) in days {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { GHDayWidget(snapshot: snap, family: f) }, scale: 3,
                                 to: dir.appendingPathComponent("day-\(name)-\(f.rawValue).png"))
            }
        }

        let long = Quote(text: "The mountains are not there to be conquered. Climb slowly, keep the hotel lights in view, and remember that every summit is only a very large stair you have agreed to take one step at a time, all afternoon.",
                         author: "A guest of the hotel, written in the register at the end of a very long season")
        let quotes: [(String, Quote, Date)] = [
            ("long", long, Mock.now),
            ("no-author", DemoData.quotes[2], Mock.now),
            ("long-no-author", Quote(text: long.text, author: nil), Mock.now),
            ("dusk", DemoData.quotes[0], at(17, 40)),
            ("night", DemoData.quotes[1], at(21, 0))
        ]
        for (name, q, now) in quotes {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { GHQuoteWidget(quote: q, family: f, now: now) }, scale: 3,
                                 to: dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png"))
            }
        }
        print("Rendered Grand Hotel states to \(dir.path)")
        return true
    }
}
