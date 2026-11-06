import SwiftUI

// States the board doesn't show, rendered only when CE_STATES_DIR is set (nothing is written to out/):
//   CE_STATES_DIR=/some/folder swift run --scratch-path .build-weather-celestial WCelestial
// Weather at every size for: no weather (a fetch error), rain, snow, dusk (4:45 PM), the 28th of the month; to-do
// small and medium for: no tasks, a task error, a very long title. All at 3x as weather-<state>-<size>.png and
// todo-<state>-<size>.png, plus states.png, one sheet of them all at 1x (the size they are seen at on the phone).

@MainActor
enum CEStates {
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["CE_STATES_DIR"], !path.isEmpty else { return false }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let base = Mock.day
        let cal = Calendar.current
        func at(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: Mock.now) ?? Mock.now }
        func with(_ f: (inout DaySnapshot) -> Void) -> DaySnapshot { var s = base; f(&s); return s }
        var parts = cal.dateComponents([.year, .month], from: Mock.now)
        parts.day = 28; parts.hour = 9; parts.minute = 41
        let the28th = cal.date(from: parts) ?? Mock.now

        let weather: [(String, DaySnapshot)] = [
            ("no-weather", with { $0.weather = nil; $0.weatherError = "Couldn't reach Open-Meteo (offline)" }),
            ("rain", with { $0.weather?.code = 63; $0.weather?.temperature = 51; $0.weather?.high = 54; $0.weather?.low = 46 }),
            ("snow", with { $0.weather?.code = 73; $0.weather?.temperature = 28; $0.weather?.high = 31; $0.weather?.low = 19 }),
            ("dusk", with { $0.date = at(16, 45) }),
            ("day-28", DemoData.day(now: the28th)),
            ("partly-night", with { $0.date = at(23, 30); $0.weather?.code = 2; $0.weather?.isDay = false })
        ]
        let long = TaskItem(text: "Write up the full lab report for the pendulum experiment, with every error bar and the appendix",
                            due: cal.startOfDay(for: Mock.now), priority: .high, sourcePath: "Tasks/Master Task List.md", lineNumber: 2)
        let todos: [(String, DaySnapshot)] = [
            ("empty", with { $0.tasks = [] }),
            ("error", with { $0.taskError = "GitHub returned 401. Check the token in Settings." }),
            ("long-title", with { $0.tasks.insert(long, at: 0) })
        ]

        var sheet: [(String, [(AnyView, Family)])] = []
        for (name, snap) in weather {
            var row: [(AnyView, Family)] = []
            for f in [Family.large, .medium, .small] {
                let tile = WidgetTile(family: f) { CEWeather(snapshot: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("weather-\(name)-\(f.rawValue).png"))
                row.append((AnyView(tile), f))
            }
            sheet.append(("weather \(name)", row))
        }
        for (name, snap) in todos {
            var row: [(AnyView, Family)] = []
            for f in [Family.medium, .small] {
                let tile = WidgetTile(family: f) { CETodo(snapshot: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("todo-\(name)-\(f.rawValue).png"))
                row.append((AnyView(tile), f))
            }
            sheet.append(("todo \(name)", row))
        }
        let board = VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(sheet.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.0).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(row.1.enumerated()), id: \.offset) { _, item in item.0 }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: 0x060B1A))
        MockRunner.write(board, scale: 1, to: dir.appendingPathComponent("states.png"))
        print("Rendered Celestial states to \(dir.path)")
        return true
    }
}
