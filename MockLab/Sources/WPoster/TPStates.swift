import SwiftUI

// States the board doesn't show, rendered only when TP_STATES_DIR is set (nothing is written to out/):
//   TP_STATES_DIR=/some/folder swift run --scratch-path .build-weather-poster WPoster
// Weather at all three sizes and To-do at small and medium, at 3x: weather-<state>-<size>.png and
// todo-<state>-<size>.png, plus states.png, one sheet of them all at 1x (the size they are seen at on the phone).

@MainActor
enum TPStates {
    /// Returns true when it rendered the states (and the normal run should be skipped).
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["TP_STATES_DIR"], !path.isEmpty else { return false }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let base = Mock.day
        let error = "GitHub returned 401. Check the token in Settings."
        let cal = Calendar.current
        func at(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: Mock.now) ?? Mock.now }
        func with(_ f: (inout DaySnapshot) -> Void) -> DaySnapshot { var s = base; f(&s); return s }
        var parts = cal.dateComponents([.year, .month], from: Mock.now)
        parts.day = 28; parts.hour = 9; parts.minute = 41
        let the28th = cal.date(from: parts) ?? Mock.now
        var longTitle = base
        if !longTitle.tasks.isEmpty {
            longTitle.tasks[0].text = "Write up the full methods section of the physics lab report, with every figure and its caption redone"
        }

        let weather: [(String, DaySnapshot)] = [
            ("no-weather", with { $0.weather = nil; $0.weatherError = "Offline" }),
            ("rain", with { $0.weather?.code = 63; $0.weather?.temperature = 51; $0.weather?.high = 54; $0.weather?.low = 46 }),
            ("snow", with { $0.weather?.code = 73; $0.weather?.temperature = 28; $0.weather?.high = 31; $0.weather?.low = 19 }),
            ("dusk", with { $0.date = at(16, 45) }),
            ("partly", with { $0.weather?.code = 2 }),
            ("overcast", with { $0.weather?.code = 3 }),
            ("fog", with { $0.weather?.code = 45 }),
            ("storm", with { $0.weather?.code = 95 }),
            ("dawn", with { $0.date = at(6, 30) }),
            ("night-rain", with { $0.date = at(21, 15); $0.weather?.isDay = false; $0.weather?.code = 63 }),
            ("day-28", DemoData.day(now: the28th)),
            ("cold", with { $0.weather?.temperature = -12; $0.weather?.high = -4; $0.weather?.low = -19; $0.weather?.code = 0 })
        ]
        let todo: [(String, DaySnapshot)] = [
            ("empty", with { $0.tasks = [] }),
            ("task-error", with { $0.taskError = error }),
            ("task-error-empty", with { $0.tasks = []; $0.taskError = error }),
            ("long-title", longTitle),
            ("one-task", with { $0.tasks = Array(base.tasks.prefix(1)) }),
            ("day-28", DemoData.day(now: the28th)),
            ("night", Mock.night)
        ]

        var sheet: [(String, [AnyView])] = []
        for (name, snap) in weather {
            var row: [AnyView] = []
            for f in [Family.large, .medium, .small] {
                let tile = WidgetTile(family: f) { TPWeather(snapshot: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("weather-\(name)-\(f.rawValue).png"))
                row.append(AnyView(tile))
            }
            sheet.append(("weather \(name)", row))
        }
        for (name, snap) in todo {
            var row: [AnyView] = []
            for f in [Family.medium, .small] {
                let tile = WidgetTile(family: f) { TPTodo(snapshot: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("todo-\(name)-\(f.rawValue).png"))
                row.append(AnyView(tile))
            }
            sheet.append(("to-do \(name)", row))
        }
        // One sheet at 1x: weather rows (large, medium, small), then to-do rows two to a line.
        let board = VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(sheet.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.0).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(row.1.enumerated()), id: \.offset) { _, v in v }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: 0x10222B))
        MockRunner.write(board, scale: 1, to: dir.appendingPathComponent("states.png"))
        print("Rendered Travel Poster states to \(dir.path)")
        return true
    }
}
