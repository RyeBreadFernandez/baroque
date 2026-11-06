import SwiftUI

// The states the demo board doesn't show, rendered on request so they can be checked before porting:
//   TRAIL_STATES=/some/folder swift run --scratch-path .build-layout-trail LTrail
// writes one PNG per state and size into that folder (3x, like the widget renders).
@MainActor
enum TRStates {
    static func renderIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["TRAIL_STATES"], !path.isEmpty else { return }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let base = Mock.day
        let cal = Calendar.current
        let error = "GitHub returned 401. Check the token in Settings."

        var noLate = base
        noLate.tasks = base.tasks.filter { !$0.isOverdue(asOf: base.date) }

        var many = base
        many.tasks = base.tasks + (1...6).map { i in
            TaskItem(text: "Extra errand number \(i)", due: cal.date(byAdding: .day, value: i % 4, to: base.date),
                     priority: .none, sourcePath: "Tasks/Master Task List.md", lineNumber: 40 + i)
        }

        var night = base
        night.date = cal.date(bySettingHour: 21, minute: 30, second: 0, of: base.date) ?? base.date
        night.weather?.code = 61

        let days: [(String, DaySnapshot)] = [
            ("empty", DaySnapshot(date: base.date, weather: base.weather, tasks: [], taskError: nil, weatherError: nil)),
            ("error-cached", DaySnapshot(date: base.date, weather: base.weather, tasks: base.tasks, taskError: error, weatherError: nil)),
            ("error-empty", DaySnapshot(date: base.date, weather: base.weather, tasks: [], taskError: error, weatherError: nil)),
            ("no-weather", DaySnapshot(date: base.date, weather: nil, tasks: base.tasks, taskError: nil, weatherError: "Offline")),
            ("no-late", noLate),
            ("many", many),
            ("night-rain", night)
        ]
        for (name, snap) in days {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { TRDayWidget(snapshot: snap, family: f) }, scale: 3,
                                 to: dir.appendingPathComponent("day-\(name)-\(f.rawValue).png"))
            }
        }

        let long = Quote(text: "The secret of getting ahead is getting started. The secret of getting started is breaking your complex, overwhelming tasks into small manageable tasks, and then starting on the first one, and after that the next, until the mountain is behind you.", author: "Mark Twain, attributed")
        let quotes: [(String, Quote, String?)] = [
            ("short", DemoData.quotes[3], nil),
            ("long", long, nil),
            ("no-author", DemoData.quotes[2], nil),
            ("error", DemoData.quotes[0], "Couldn't refresh quotes. Showing saved ones.")
        ]
        for (name, q, err) in quotes {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { TRQuoteWidget(quote: q, family: f, date: Mock.now, error: err) }, scale: 3,
                                 to: dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png"))
            }
        }
        // The bare grounds, for measuring contrast behind the writing.
        for f in Family.allCases {
            MockRunner.write(WidgetTile(family: f) { TRDayScene(snapshot: base, family: f) }, scale: 3,
                             to: dir.appendingPathComponent("scene-day-\(f.rawValue).png"))
            MockRunner.write(WidgetTile(family: f) { TRQuoteScene(family: f, date: Mock.now) }, scale: 3,
                             to: dir.appendingPathComponent("scene-quote-\(f.rawValue).png"))
        }
        print("Rendered Trail states to \(dir.path)")
    }
}
