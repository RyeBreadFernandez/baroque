import SwiftUI

// States the demo board doesn't show, rendered only when OC_STATES_DIR is set (nothing is written to out/):
//   OC_STATES_DIR=/some/folder swift run --scratch-path .build-old-master-cover OMCover
// Every state at all three sizes, at 3x: day-<state>-<size>.png and quote-<state>-<size>.png, plus states.png, one
// sheet of them all at 1x (the size they are seen at on the phone).

@MainActor
enum OCStates {
    /// Returns true when it rendered the states (and the normal run should be skipped).
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["OC_STATES_DIR"], !path.isEmpty else { return false }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let base = Mock.day
        let error = "GitHub returned 401. Check the token in Settings."
        let cal = Calendar.current
        func at(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: Mock.now) ?? Mock.now }
        func with(_ f: (inout DaySnapshot) -> Void) -> DaySnapshot { var s = base; f(&s); return s }
        // The 28th of this month at 9:41, its tasks due round it as the demo's are round today.
        var parts = cal.dateComponents([.year, .month], from: Mock.now)
        parts.day = 28; parts.hour = 9; parts.minute = 41
        let the28th = cal.date(from: parts) ?? Mock.now

        let days: [(String, DaySnapshot)] = [
            ("no-tasks", with { $0.tasks = [] }),
            ("task-error", with { $0.taskError = error }),
            ("task-error-empty", with { $0.tasks = []; $0.taskError = error }),
            ("no-weather", with { $0.weather = nil; $0.weatherError = "Offline" }),
            ("rain", with { $0.weather?.code = 63; $0.weather?.temperature = 51; $0.weather?.high = 54; $0.weather?.low = 46 }),
            ("snow", with { $0.weather?.code = 73; $0.weather?.temperature = 28; $0.weather?.high = 31; $0.weather?.low = 19 }),
            ("dusk", with { $0.date = at(16, 45) }),
            ("night", with { $0.date = at(21, 0) }),
            ("day-28", DemoData.day(now: the28th)),
            ("day-11", { var s = DemoData.day(now: cal.date(byAdding: .day, value: 11 - cal.component(.day, from: the28th), to: the28th) ?? the28th); s.tasks = Array(s.tasks.prefix(2)); return s }()),
            ("one-task", with { $0.tasks = Array(base.tasks.prefix(1)) })
        ]
        let long = Quote(text: "The mountains are not there to be conquered. Climb slowly, keep the valley lights in view, and remember that every summit is only a very large stair you have agreed to take one step at a time, all afternoon.",
                         author: "A note left in the hut register at the end of a very long season")
        let quotes: [(String, Quote, Date)] = [
            ("long", long, Mock.now),
            ("nil-author", DemoData.quotes[2], Mock.now),
            ("long-nil-author", Quote(text: long.text, author: nil), Mock.now),
            ("dusk", DemoData.quotes[0], at(16, 45)),
            ("night", DemoData.quotes[1], at(21, 0))
        ]

        var sheet: [(String, AnyView, Family)] = []
        for (name, snap) in days {
            for f in Family.allCases {
                let tile = WidgetTile(family: f) { OCDay(snapshot: snap, family: f) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("day-\(name)-\(f.rawValue).png"))
                sheet.append(("day \(name)", AnyView(tile), f))
            }
        }
        for (name, q, now) in quotes {
            for f in Family.allCases {
                let tile = WidgetTile(family: f) { OCQuote(quote: q, family: f, now: now) }
                MockRunner.write(tile, scale: 3, to: dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png"))
                sheet.append(("quote \(name)", AnyView(tile), f))
            }
        }
        // One sheet at 1x, a row per state: large, medium, small.
        let rows = stride(from: 0, to: sheet.count, by: 3).map { Array(sheet[$0..<min($0 + 3, sheet.count)]) }
        let board = VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.first?.0 ?? "").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(row.reversed().enumerated()), id: \.offset) { _, item in item.1 }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: 0x2A1B12))
        MockRunner.write(board, scale: 1, to: dir.appendingPathComponent("states.png"))
        print("Rendered Old Master Cover states to \(dir.path)")
        return true
    }
}
