import SwiftUI

// States the board doesn't show, rendered only when SA_STATES_DIR is set (nothing is written to out/):
//   SA_STATES_DIR=/some/folder swift run --scratch-path .build-weather-sun-arc WSunArc
// Weather states at all three sizes and To-do states at small and medium, each at 3x
// (weather-<state>-<size>.png, todo-<state>-<size>.png), plus states.png: every one at 1x, a row per state.

@MainActor
enum SAStates {
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["SA_STATES_DIR"], !path.isEmpty else { return false }
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
        let long = TaskItem(text: "Write up the full field notes from the Hörnli ridge approach, with photos, the gear list and every hut booking for next summer",
                            due: cal.date(byAdding: .day, value: -3, to: cal.startOfDay(for: Mock.now)), priority: .high,
                            sourcePath: "Tasks/Master Task List.md", lineNumber: 2)

        let weather: [(String, DaySnapshot)] = [
            ("no-weather", with { $0.weather = nil; $0.weatherError = "Offline. Open-Meteo could not be reached." }),
            ("rain", with { $0.weather?.code = 63; $0.weather?.temperature = 51; $0.weather?.high = 54; $0.weather?.low = 46 }),
            ("snow", with { $0.weather?.code = 73; $0.weather?.temperature = 28; $0.weather?.high = 31; $0.weather?.low = 19 }),
            ("dusk", with { $0.date = at(16, 45) }),
            ("dawn", with { $0.date = at(6, 30) }),
            ("rain-night", with { $0.date = at(22, 30); $0.weather?.code = 63; $0.weather?.isDay = false
                $0.weather?.temperature = 47; $0.weather?.high = 54; $0.weather?.low = 44 }),
            ("day-28", DemoData.day(now: the28th)),
            ("hot-108", with { $0.weather?.temperature = 108; $0.weather?.high = 112; $0.weather?.low = 81; $0.weather?.code = 3 })
        ]
        let todos: [(String, DaySnapshot)] = [
            ("empty", with { $0.tasks = [] }),
            ("task-error", with { $0.taskError = error }),
            ("task-error-empty", with { $0.tasks = []; $0.taskError = error }),
            ("long-title", with { $0.tasks = [long] + base.tasks }),
            ("day-28", DemoData.day(now: the28th)),
            ("one-task", with { $0.tasks = Array(base.tasks.prefix(1)) })
        ]

        var sheet: [(String, [AnyView])] = []
        for (name, snap) in weather {
            var row: [AnyView] = []
            for f in [Family.large, .medium, .small] {
                let tile = WidgetTile(family: f) { SAWeather(snap: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("weather-\(name)-\(f.rawValue).png"))
                row.append(AnyView(tile))
            }
            sheet.append(("weather \(name)", row))
        }
        for (name, snap) in todos {
            var row: [AnyView] = []
            for f in [Family.medium, .small] {
                let tile = WidgetTile(family: f) { SATodo(snap: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("todo-\(name)-\(f.rawValue).png"))
                row.append(AnyView(tile))
            }
            sheet.append(("todo \(name)", row))
        }
        let board = VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(sheet.enumerated()), id: \.offset) { _, entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.0).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(entry.1.enumerated()), id: \.offset) { _, v in v }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: 0x2A1B12))
        MockRunner.write(board, scale: 1, to: dir.appendingPathComponent("states.png"))
        print("Rendered Sun Arc states to \(dir.path)")
        return true
    }
}
