import SwiftUI

// States the demo board doesn't show, rendered only when NU_STATES_DIR is set (for checking the layout):
// no tasks, a fetch error over cached tasks, a fetch error with nothing cached, one task, missing weather,
// night and rain skies, a long title as the hero, and short, long and erroring quotes.
@MainActor
enum NUStates {
    static func renderIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["NU_STATES_DIR"] else { return }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = Mock.day
        let cal = Calendar.current

        var empty = base
        empty.tasks = []
        var failed = base
        failed.taskError = "GitHub returned 401. Check the token in Baroque."
        var failedEmpty = empty
        failedEmpty.taskError = "GitHub returned 401. Check the token in Baroque."
        var single = base
        single.tasks = Array(base.tasks.prefix(1))
        var noWeather = base
        noWeather.weather = nil
        var longHero = base
        longHero.tasks = Array(base.tasks.dropFirst())
        var night = base
        night.date = cal.date(bySettingHour: 21, minute: 30, second: 0, of: base.date) ?? base.date
        var rain = base
        rain.weather?.code = 63

        let days: [(String, DaySnapshot)] = [
            ("empty", empty), ("error", failed), ("error-empty", failedEmpty), ("single", single),
            ("noweather", noWeather), ("longhero", longHero), ("night", night), ("rain", rain)
        ]
        for (name, snap) in days {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { NUDayWidget(snapshot: snap, family: f) }, scale: 2,
                                 to: dir.appendingPathComponent("day-\(name)-\(f.rawValue).png"))
            }
        }

        let quotes: [(String, Quote, String?)] = [
            ("short", Quote(text: "Begin.", author: nil), nil),
            ("long", Quote(text: "Begin at once to live, and count each separate day as a separate life. Write it down every morning, read it every night, and keep the promise you made to yourself before the day got loud.", author: "Seneca"), nil),
            ("noauthor", DemoData.quotes[2], nil),
            ("error", DemoData.quotes[0], "Couldn't reach GitHub. Showing saved quotes.")
        ]
        for (name, q, err) in quotes {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { NUQuoteWidget(quote: q, family: f, date: Mock.now, error: err) }, scale: 2,
                                 to: dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png"))
            }
        }
        // The bare grounds, for measuring text contrast against the paint under the header and the "Then" list.
        for f in Family.allCases {
            MockRunner.write(WidgetTile(family: f) { NUDayGround(snapshot: base, style: NUStyle(f)) }, scale: 3,
                             to: dir.appendingPathComponent("ground-day-\(f.rawValue).png"))
            MockRunner.write(WidgetTile(family: f) { NUDayGround(snapshot: night, style: NUStyle(f)) }, scale: 3,
                             to: dir.appendingPathComponent("ground-night-\(f.rawValue).png"))
        }
        print("Rendered Next Up states to \(dir.path)")
    }
}
