import SwiftUI

// States the board doesn't show, rendered only when SB_STATES_DIR is set (nothing is written to out/):
//   SB_STATES_DIR=/some/folder swift run --scratch-path .build-weather-storybook WStorybook
// Weather states at all three sizes and To-do states at small and medium, at 3x: weather-<state>-<size>.png and
// todo-<state>-<size>.png, plus states.png, one sheet of them all at 1x (the size they are seen at on the phone).

@MainActor
enum SBStates {
    /// Returns true when it rendered the states (and the normal run should be skipped).
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["SB_STATES_DIR"], !path.isEmpty else { return false }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let base = Mock.day
        let cal = Calendar.current
        func at(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: Mock.now) ?? Mock.now }
        func with(_ s: DaySnapshot = base, _ f: (inout DaySnapshot) -> Void) -> DaySnapshot { var s = s; f(&s); return s }
        var parts = cal.dateComponents([.year, .month], from: Mock.now)
        parts.day = 28; parts.hour = 9; parts.minute = 41
        let the28th = cal.date(from: parts) ?? Mock.now
        let rain: (inout DaySnapshot) -> Void = { $0.weather?.code = 63; $0.weather?.temperature = 51; $0.weather?.high = 54; $0.weather?.low = 46 }
        let snow: (inout DaySnapshot) -> Void = { $0.weather?.code = 73; $0.weather?.temperature = 28; $0.weather?.high = 31; $0.weather?.low = 19 }

        let weathers: [(String, DaySnapshot)] = [
            ("no-weather", with { $0.weather = nil; $0.weatherError = "Offline" }),
            ("rain", with(base, rain)),
            ("rain-night", with(Mock.night, rain)),
            ("snow", with(base, snow)),
            ("snow-night", with(Mock.night, snow)),
            ("partly", with { $0.weather?.code = 2 }),
            ("fog", with { $0.weather?.code = 45 }),
            ("dusk", with { $0.date = at(16, 45) }),
            ("dawn", with { $0.date = at(6, 20) }),
            ("day-28", DemoData.day(now: the28th)),
        ]
        let long = TaskItem(text: "Write up the full Matterhorn trip itinerary with hut bookings, train times and a fallback day for weather",
                            due: Mock.now, priority: .high, sourcePath: "Tasks/Master Task List.md", lineNumber: 2)
        let error = "GitHub returned 401. Check the token in Settings."
        let todos: [(String, DaySnapshot)] = [
            ("no-tasks", with { $0.tasks = [] }),
            ("task-error", with { $0.tasks = []; $0.taskError = error }),
            ("task-error-cached", with { $0.taskError = error }),
            ("long-task", with { $0.tasks = [long] + base.tasks }),
            ("one-task", with { $0.tasks = Array(base.tasks.prefix(1)) }),
            ("day-28", DemoData.day(now: the28th)),
        ]

        var sheet: [(String, [AnyView])] = []
        for (name, snap) in weathers {
            var row: [AnyView] = []
            for f in [Family.large, .medium, .small] {
                let tile = WidgetTile(family: f) { SBWeather(snapshot: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("weather-\(name)-\(f.rawValue).png"))
                row.append(AnyView(tile))
            }
            sheet.append(("weather \(name)", row))
        }
        for (name, snap) in todos {
            var row: [AnyView] = []
            for f in [Family.medium, .small] {
                let tile = WidgetTile(family: f) { SBTodo(snapshot: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("todo-\(name)-\(f.rawValue).png"))
                row.append(AnyView(tile))
            }
            sheet.append(("todo \(name)", row))
        }
        let board = VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(sheet.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(item.1.enumerated()), id: \.offset) { _, v in v }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: 0x0B1210))
        MockRunner.write(board, scale: 1, to: dir.appendingPathComponent("states.png"))
        print("Rendered Storybook Night states to \(dir.path)")
        return true
    }
}
