import SwiftUI

// States the demo board doesn't show, rendered only when OM_STATES_DIR is set (nothing is written to out/):
//   OM_STATES_DIR=/some/folder swift run --scratch-path .build-old-master OldMaster
// Every state at all three sizes, at 3x: day-<state>-<size>.png and quote-<state>-<size>.png.

@MainActor
enum OMStates {
    /// Returns true when it rendered the states (and the normal run should be skipped).
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["OM_STATES_DIR"], !path.isEmpty else { return false }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let base = Mock.day
        let error = "GitHub returned 401. Check the token in Settings."
        let cal = Calendar.current
        func at(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: Mock.now) ?? Mock.now }
        func with(_ f: (inout DaySnapshot) -> Void) -> DaySnapshot { var s = base; f(&s); return s }

        let days: [(String, DaySnapshot)] = [
            ("no-tasks", with { $0.tasks = [] }),
            ("task-error", with { $0.taskError = error }),
            ("task-error-empty", with { $0.tasks = []; $0.taskError = error }),
            ("no-weather", with { $0.weather = nil; $0.weatherError = "Offline" }),
            ("rain", with { $0.weather?.code = 63; $0.weather?.temperature = 51; $0.weather?.high = 54; $0.weather?.low = 46 }),
            ("snow", with { $0.weather?.code = 73; $0.weather?.temperature = 28; $0.weather?.high = 31; $0.weather?.low = 19 }),
            ("dusk", with { $0.date = at(16, 45) }),
            ("night", with { $0.date = at(21, 0) }),
            ("one-task", with { $0.tasks = Array(base.tasks.prefix(1)) })
        ]
        let long = Quote(text: "The mountains are not there to be conquered. Climb slowly, keep the valley lights in view, and remember that every summit is only a very large stair you have agreed to take one step at a time, all afternoon.",
                         author: "A note left in the hut register at the end of a very long season")
        let quotes: [(String, Quote, Date)] = [
            ("long", long, Mock.now),
            ("nil-author", DemoData.quotes[2], Mock.now),
            ("long-nil-author", Quote(text: long.text, author: nil), Mock.now),
            ("dusk", DemoData.quotes[0], at(17, 30)),
            ("night", DemoData.quotes[1], at(21, 0))
        ]

        for (name, snap) in days {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { OMDay(snapshot: snap, family: f) }, scale: 3,
                                 to: dir.appendingPathComponent("day-\(name)-\(f.rawValue).png"))
            }
        }
        for (name, q, now) in quotes {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { OMQuote(quote: q, family: f, now: now) }, scale: 3,
                                 to: dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png"))
            }
        }
        print("Rendered Old Master states to \(dir.path)")
        return true
    }
}
