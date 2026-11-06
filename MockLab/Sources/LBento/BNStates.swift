import SwiftUI

// The states the demo board doesn't show, rendered on request to check the layout holds up:
//   BN_STATES_DIR=/some/folder swift run --scratch-path .build-layout-bento LBento
// Day: no tasks, a fetch error over cached tasks, an error with nothing cached, missing weather, night,
// dusk, rain, snow. Quote: a long quote at every size, no author, a fetch error.
@MainActor
enum BNStates {
    static func renderIfAsked() {
        guard let path = ProcessInfo.processInfo.environment["BN_STATES_DIR"] else { return }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let cal = Calendar.current
        func at(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date() }
        let error = "GitHub returned 401. Check the token in Settings."

        var empty = Mock.day; empty.tasks = []
        var cached = Mock.day; cached.taskError = error
        var failed = Mock.day; failed.tasks = []; failed.taskError = error
        var noWeather = Mock.day; noWeather.weather = nil
        let night = DemoData.day(now: at(21, 30))
        let dusk = DemoData.day(now: at(16, 50))
        var rain = Mock.day; rain.weather?.code = 63
        var snow = DemoData.day(now: at(7, 10)); snow.weather?.code = 73

        let days: [(String, DaySnapshot)] = [("empty", empty), ("cached-error", cached), ("failed", failed),
                                             ("no-weather", noWeather), ("night", night), ("dusk", dusk),
                                             ("rain", rain), ("snow", snow)]
        for (name, snap) in days {
            write(row: Family.allCases.map { f in AnyView(BNDayWidget(snapshot: snap, size: BaroqueSize(f), canvas: Mock.size(f))) },
                  to: dir.appendingPathComponent("day-\(name).png"))
        }

        let long = DemoData.quotes[1]
        let quotes: [(String, Quote, String?)] = [("long", long, nil),
                                                  ("no-author", DemoData.quotes[2], nil),
                                                  ("error", DemoData.quotes[0], "Couldn't reach GitHub. Showing saved quotes.")]
        for (name, q, err) in quotes {
            write(row: Family.allCases.map { f in
                AnyView(BNQuoteWidget(quote: q, size: BaroqueSize(f), canvas: Mock.size(f), date: Mock.now, error: err))
            }, to: dir.appendingPathComponent("quote-\(name).png"))
        }
        print("Rendered Bento states to \(dir.path)")
    }

    private static func write(row: [AnyView], to url: URL) {
        let view = HStack(alignment: .top, spacing: 20) {
            ForEach(Array(zip(Family.allCases, row)), id: \.0) { f, v in
                WidgetTile(family: f) { v }
            }
        }
        .padding(20)
        .background(PaintedWallpaper())
        MockRunner.write(view, scale: 2, to: url)
    }
}
