import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        MockRunner.run(Panorama())
        PNStates.renderIfRequested()
    }
}

/// "The view is the widget": the painted landscape fills every widget edge to edge and the information is
/// written lightly into it, like captions in a picture book.
struct Panorama: PaintedLayout {
    let name = "Panorama"
    let slug = "layout-panorama"
    let tagline = "The view is the widget: the sun's arc across the sky is today, and tasks and quotes are written as captions on the dark valley floor below."

    func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        PNDay(snapshot: snapshot, family: family)
    }

    func quote(_ quote: Quote, family: Family) -> some View {
        PNQuote(quote: quote, family: family, date: Mock.now)
    }

    func wallpaper() -> some View { PaintedWallpaper() }
}

/// States the demo board doesn't show (empty, errors, missing weather, night and weather skies, long and short
/// quotes). Run with PN_STATES=<folder> to write them there; the normal run is unchanged.
@MainActor
enum PNStates {
    static func renderIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["PN_STATES"], !path.isEmpty else { return }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let base = Mock.day
        func snap(hour: Int? = nil, minute: Int = 0, code: Int? = nil, weather: Bool = true,
                  tasks: [TaskItem]? = nil, error: String? = nil) -> DaySnapshot {
            var s = base
            if let hour, let d = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base.date) {
                s.date = d
                s.weather?.fetchedAt = d
            }
            if let code { s.weather?.code = code }
            if !weather { s.weather = nil }
            if let tasks { s.tasks = tasks }
            s.taskError = error
            return s
        }
        let err = "GitHub returned 401. Check the token in Baroque's settings."
        let days: [(String, DaySnapshot)] = [
            ("empty", snap(tasks: [])),
            ("error-cached", snap(error: err)),
            ("error-empty", snap(tasks: [], error: err)),
            ("no-weather", snap(weather: false)),
            ("night", snap(hour: 21, minute: 30)),
            ("dawn", snap(hour: 6, minute: 30, code: 2)),
            ("afternoon-rain", snap(hour: 15, minute: 10, code: 63)),
            ("snow", snap(hour: 12, minute: 0, code: 73)),
            ("storm", snap(hour: 13, minute: 20, code: 95)),
            ("fog", snap(hour: 8, minute: 0, code: 45)),
            ("few", snap(tasks: Array(base.tasks.prefix(2))))
        ]
        for (name, s) in days {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { PNDay(snapshot: s, family: f) }, scale: 2,
                                 to: dir.appendingPathComponent("day-\(name)-\(f.rawValue).png"))
            }
        }
        let quotes: [(String, Quote, String?)] = [
            ("short", DemoData.quotes[2], nil),
            ("long", DemoData.quotes[1], nil),
            ("orwell", DemoData.quotes[0], nil),
            ("error", DemoData.quotes[0], "Couldn't refresh quotes. Showing the cached list."),
            ("very-long", Quote(text: "It is not the mountain we conquer but ourselves. The summit is a moment; the climb is what we carry home, step by patient step, through weather we did not choose.", author: "Edmund Hillary, misattributed"), nil)
        ]
        for (name, q, e) in quotes {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { PNQuote(quote: q, family: f, date: Mock.now, error: e) }, scale: 2,
                                 to: dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png"))
            }
        }
        // The bare grounds, for measuring contrast under the text.
        for f in Family.allCases {
            MockRunner.write(WidgetTile(family: f) { PNDayGround(snapshot: base, family: f) }, scale: 2,
                             to: dir.appendingPathComponent("ground-day-\(f.rawValue).png"))
            MockRunner.write(WidgetTile(family: f) { PNQuoteGround(family: f, date: Mock.now) }, scale: 2,
                             to: dir.appendingPathComponent("ground-quote-\(f.rawValue).png"))
        }
        print("Rendered Panorama states to \(dir.path)")
    }
}
