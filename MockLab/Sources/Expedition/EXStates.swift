import SwiftUI

/// States the demo doesn't show, rendered when EX_STATES_DIR is set (nothing is written to out/):
/// no tasks, a task fetch error, no weather, rain, snow, a very long quote with no author, a short quote with no author.
@MainActor
enum EXStates {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = Mock.day
        var empty = base
        empty.tasks = []
        var failed = base
        failed.tasks = []
        failed.taskError = "Couldn't reach GitHub (offline). Showing nothing cached."
        var noWeather = base
        noWeather.weather = nil
        noWeather.weatherError = "Weather unavailable (offline)"
        var rain = base
        rain.weather?.code = 63
        rain.weather?.temperature = 51
        rain.weather?.high = 55
        rain.weather?.low = 47
        var snow = base
        snow.weather?.code = 73
        snow.weather?.temperature = 29
        snow.weather?.high = 33
        snow.weather?.low = 21

        let days: [(String, DaySnapshot)] = [("empty", empty), ("error", failed), ("noweather", noWeather), ("rain", rain), ("snow", snow)]
        for (name, snap) in days {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { Expedition().day(snap, family: f) }, scale: 3,
                                 to: dir.appendingPathComponent("day-\(name)-\(f.rawValue).png"))
            }
        }
        let long = Quote(text: "The mountains are calling and the trail is long, so pack light, start early, leave the map folded until you are truly lost, and remember that every summit you will ever stand on began as a slow and ordinary walk uphill through weather you did not choose.", author: nil)
        let quotes: [(String, Quote)] = [("long", long), ("noauthor", DemoData.quotes[2])]
        for (name, q) in quotes {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { Expedition().quote(q, family: f) }, scale: 3,
                                 to: dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png"))
            }
        }
        print("Rendered Expedition states to \(dir.path)")
    }
}
