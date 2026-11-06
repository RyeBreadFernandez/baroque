import SwiftUI

/// States the demo doesn't show, rendered when NR_STATES_DIR is set (all three sizes), without touching out/.
/// NR_STATES_DIR=/some/dir swift run --scratch-path .build-neon-rain NeonRain
@MainActor
enum NRStates {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let a = NeonRain()
        let base = Mock.day

        var empty = base
        empty.tasks = []

        var failed = base
        failed.tasks = []
        failed.taskError = "GitHub returned 401: bad credentials"

        var noWeather = base
        noWeather.weather = nil
        noWeather.weatherError = "Open-Meteo timed out"

        var rain = base
        rain.weather?.code = 63
        var snow = base
        snow.weather?.code = 73
        snow.weather?.temperature = 29
        snow.weather?.high = 33
        snow.weather?.low = 21
        var fog = base
        fog.weather?.code = 45

        var longTask = base
        longTask.tasks = [TaskItem(text: "Rewrite the whole methods section of the thesis draft before the committee meeting on Friday morning",
                                   due: Calendar.current.date(byAdding: .day, value: -3, to: Mock.now), priority: .highest,
                                   sourcePath: "x", lineNumber: 1)] + base.tasks

        let days: [(String, DaySnapshot)] = [("empty", empty), ("task-error", failed), ("no-weather", noWeather),
                                             ("rain", rain), ("snow", snow), ("fog", fog), ("long-task", longTask)]
        for (name, snap) in days {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { a.day(snap, family: f) }, scale: 3,
                                 to: dir.appendingPathComponent("day-\(name)-\(f.rawValue).png"))
            }
        }

        let quotes: [(String, Quote)] = [
            ("long-nil-author", Quote(text: "Somewhere between the last train and the first light the city forgets its own name, and every sign still burning is a promise somebody made and could not keep, so I keep walking and counting puddles until the rain decides for me.", author: nil)),
            ("nil-author", DemoData.quotes[2]),
            ("long-author", Quote(text: "Make the quiet thing first, then the loud one.", author: "a very long attribution line from a notebook kept in the back of a taxi, 2026"))
        ]
        for (name, q) in quotes {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { a.quote(q, family: f) }, scale: 3,
                                 to: dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png"))
            }
        }
        print("Rendered Neon Rain states to \(dir.path)")
    }
}
