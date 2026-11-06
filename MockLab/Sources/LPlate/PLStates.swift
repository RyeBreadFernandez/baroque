import SwiftUI
import Foundation

// The states the demo snapshot never shows, rendered only when PLATE_STATES_DIR is set:
// no tasks, a fetch error over cached tasks, an error with nothing cached, missing weather,
// night and rain skies, very short and very long quotes, and a quote error with and without an author.
@MainActor
enum PLStates {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = Mock.day
        var empty = base
        empty.tasks = []
        var cachedError = base
        cachedError.taskError = "GitHub returned 401. Check the token in Baroque."
        var hardError = cachedError
        hardError.tasks = []
        var noWeather = base
        noWeather.weather = nil
        var night = base
        night.date = Calendar.current.date(bySettingHour: 21, minute: 30, second: 0, of: base.date) ?? base.date
        var rain = base
        rain.weather?.code = 63

        let days: [(String, DaySnapshot)] = [("empty", empty), ("cached-error", cachedError), ("error", hardError),
                                            ("no-weather", noWeather), ("night", night), ("rain", rain)]
        for (name, snap) in days {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { PLDayWidget(snapshot: snap, family: f) }, scale: 2,
                                 to: dir.appendingPathComponent("day-\(name)-\(f.rawValue).png"))
            }
        }

        let short = Quote(text: "Begin.", author: nil)
        let long = Quote(text: "The best time to plant a tree was twenty years ago; the second best time is now, so go outside, dig the hole, set the roots, water it every evening for a month, and then let the patient years do the rest of the work for you.",
                         author: "an unusually long attribution line for a proverb")
        let quotes: [(String, Quote, String?)] = [("short", short, nil), ("long", long, nil),
                                                  ("error", DemoData.quotes[2], "Couldn't refresh quotes. Showing cached."),
                                                  ("author-error", DemoData.quotes[0], "Couldn't refresh quotes. Showing cached.")]
        for (name, q, err) in quotes {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { PLQuoteWidget(quote: q, family: f, error: err) }, scale: 2,
                                 to: dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png"))
            }
        }
        // The bare board, for measuring text contrast against its lightest paint.
        for f in Family.allCases {
            MockRunner.write(WidgetTile(family: f) { PLBoard() }, scale: 2, to: dir.appendingPathComponent("board-\(f.rawValue).png"))
        }
        print("Rendered states to \(dir.path)")
    }
}
