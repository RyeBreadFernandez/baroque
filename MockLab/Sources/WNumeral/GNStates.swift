import SwiftUI

// States the board doesn't show, rendered only when GN_STATES_DIR is set (nothing is written to out/):
//   GN_STATES_DIR=/some/folder swift run --scratch-path .build-weather-numeral WNumeral
// Each state at every size, at 3x: weather-<state>-<size>.png and todo-<state>-<size>.png, plus states.png, one sheet
// of them all at 1x (the size they are seen at on the phone).

@MainActor
enum GNStates {
    /// Returns true when it rendered the states (and the normal run should be skipped).
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["GN_STATES_DIR"], !path.isEmpty else { return false }
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
        let long = TaskItem(text: "Write up the full lab report for the pendulum experiment, with every error bar explained and the raw data appended",
                            due: cal.startOfDay(for: Mock.now), priority: .high, sourcePath: "Tasks/Master Task List.md", lineNumber: 2)

        let weather: [(String, DaySnapshot)] = [
            ("no-weather", with { $0.weather = nil; $0.weatherError = "Offline" }),
            ("rain", with { $0.weather?.code = 63; $0.weather?.temperature = 51; $0.weather?.high = 54; $0.weather?.low = 46 }),
            ("snow", with { $0.weather?.code = 73; $0.weather?.temperature = 28; $0.weather?.high = 31; $0.weather?.low = 19 }),
            ("dusk", with { $0.date = at(16, 45) }),
            ("night-cloudy", with { $0.date = at(21, 15); $0.weather?.code = 2 }),
            ("cold", with { $0.weather?.temperature = -12; $0.weather?.code = 3 }),
            ("hot", with { $0.weather?.temperature = 104; $0.weather?.code = 0 }),
            ("day-28", DemoData.day(now: the28th))
        ]
        let todos: [(String, DaySnapshot)] = [
            ("empty", with { $0.tasks = [] }),
            ("task-error", with { $0.taskError = error }),
            ("task-error-empty", with { $0.tasks = []; $0.taskError = error }),
            ("long-title", with { $0.tasks = [long] + Array(base.tasks.prefix(3)) }),
            ("one-task", with { $0.tasks = Array(base.tasks.dropFirst().prefix(1)) }),
            ("day-28", DemoData.day(now: the28th)),
            ("night", Mock.night)
        ]

        var sheet: [(String, [AnyView])] = []
        for (name, snap) in weather {
            var row: [AnyView] = []
            for f in [Family.large, .medium, .small] {
                let tile = WidgetTile(family: f) { GNWeatherView(snap: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("weather-\(name)-\(f.rawValue).png"))
                row.append(AnyView(tile))
            }
            sheet.append(("weather \(name)", row))
        }
        for (name, snap) in todos {
            var row: [AnyView] = []
            for f in [Family.medium, .small] {
                let tile = WidgetTile(family: f) { GNTodoView(snap: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("todo-\(name)-\(f.rawValue).png"))
                row.append(AnyView(tile))
            }
            sheet.append(("todo \(name)", row))
        }
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
        .background(Color(hex: 0x1F271E))
        MockRunner.write(board, scale: 1, to: dir.appendingPathComponent("states.png"))
        print("Rendered Giant Numeral states to \(dir.path)")
        return true
    }
}
