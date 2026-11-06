import SwiftUI

// States the demo board doesn't show, rendered only when GF_STATES_DIR is set (nothing is written to out/):
//   GF_STATES_DIR=/some/folder swift run --scratch-path .build-weather-gilt-frame WGiltFrame
// Each weather state at all three sizes and each to-do state at both, at 3x (weather-<state>-<size>.png,
// todo-<state>-<size>.png), plus states.png, one sheet of them all at 1x (the size they are seen at on the phone).

@MainActor
enum GFStates {
    /// Returns true when it rendered the states (and the normal run should be skipped).
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["GF_STATES_DIR"], !path.isEmpty else { return false }
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
        let longTitle = TaskItem(text: "Write up the full field report on the Hörnli hut approach, with photographs, the route card and every receipt from the trip",
                                 due: cal.date(byAdding: .day, value: -3, to: cal.startOfDay(for: Mock.now)), priority: .high,
                                 sourcePath: "Tasks/Master Task List.md", lineNumber: 2)

        let weather: [(String, DaySnapshot)] = [
            ("no-weather", with { $0.weather = nil; $0.weatherError = "Offline" }),
            ("rain", with { $0.weather?.code = 63; $0.weather?.temperature = 51; $0.weather?.high = 54; $0.weather?.low = 46 }),
            ("snow", with { $0.weather?.code = 73; $0.weather?.temperature = 28; $0.weather?.high = 31; $0.weather?.low = 19 }),
            ("dusk", with { $0.date = at(16, 45) }),
            ("rain-night", with { $0.date = at(21, 15); $0.weather?.code = 63; $0.weather?.isDay = false }),
            ("day-28", DemoData.day(now: the28th))
        ]
        let todos: [(String, DaySnapshot)] = [
            ("empty", with { $0.tasks = [] }),
            ("task-error", with { $0.taskError = error }),
            ("long-title", with { $0.tasks = [longTitle] + Array(base.tasks.prefix(3)) }),
            ("day-28", DemoData.day(now: the28th))
        ]

        var rows: [(String, [AnyView])] = []
        for (name, snap) in weather {
            var row: [AnyView] = []
            for f in [Family.large, .medium, .small] {
                let tile = WidgetTile(family: f) { GFWeather(snapshot: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("weather-\(name)-\(f.rawValue).png"))
                row.append(AnyView(tile))
            }
            rows.append(("weather \(name)", row))
        }
        for (name, snap) in todos {
            var row: [AnyView] = []
            for f in [Family.medium, .small] {
                let tile = WidgetTile(family: f) { GFTodo(snapshot: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("todo-\(name)-\(f.rawValue).png"))
                row.append(AnyView(tile))
            }
            rows.append(("todo \(name)", row))
        }
        let board = VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.0).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(row.1.enumerated()), id: \.offset) { _, item in item }
                    }
                }
            }
        }
        .padding(16)
        .background(GFInk.wallDeep)
        MockRunner.write(board, scale: 1, to: dir.appendingPathComponent("states.png"))
        print("Rendered Gilt Frame states to \(dir.path)")
        return true
    }
}
