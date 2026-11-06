import SwiftUI

/// Renders the real states the demo board doesn't show, one sheet per state with all three sizes side by side:
/// night, cloud, rain, snow and fog skies; no tasks; a fetch error over cached tasks; no tasks and an error;
/// missing weather; and short, long, unattributed and failed quotes.
@MainActor
enum MDStates {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = Mock.day
        let cal = Calendar.current

        func at(_ hour: Int, _ minute: Int) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: Mock.now) ?? Mock.now
        }
        func day(_ edit: (inout DaySnapshot) -> Void) -> DaySnapshot {
            var s = base
            edit(&s)
            return s
        }
        func weather(_ code: Int, isDay: Bool = true) -> (inout DaySnapshot) -> Void {
            { s in s.weather?.code = code; s.weather?.isDay = isDay }
        }

        let error = "Couldn't reach GitHub. Check the token in Baroque."
        let days: [(String, DaySnapshot)] = [
            ("night", day { s in s.date = at(21, 30); weather(0, isDay: false)(&s) }),
            ("dawn", day { s in s.date = at(6, 40); weather(2)(&s) }),
            ("overcast", day(weather(3))),
            ("rain", day { s in s.date = at(14, 0); weather(63)(&s) }),
            ("snow", day { s in s.date = at(15, 30); weather(73)(&s) }),
            ("fog", day(weather(45))),
            ("storm-night", day { s in s.date = at(19, 10); weather(95, isDay: false)(&s) }),
            ("no-tasks", day { s in s.tasks = [] }),
            ("error-cached", day { s in s.taskError = error }),
            ("error-empty", day { s in s.tasks = []; s.taskError = error }),
            ("no-weather", day { s in s.weather = nil }),
            ("two-tasks", day { s in s.tasks = Array(s.tasks.prefix(2)) }),
            ("long-names", day { s in
                // A Wednesday 30 September: the longest weekday and month on the medallion.
                var year = cal.component(.year, from: Mock.now)
                func sept30(_ y: Int) -> Date? { cal.date(from: DateComponents(year: y, month: 9, day: 30, hour: 16, minute: 20)) }
                while let d = sept30(year), cal.component(.weekday, from: d) != 4 { year += 1 }
                s.date = sept30(year) ?? s.date
            }),
        ]
        for (name, snapshot) in days {
            sheet(HStack(alignment: .top, spacing: 16) {
                ForEach(Family.allCases.reversed(), id: \.self) { f in
                    WidgetTile(family: f) { MDDay(snapshot: snapshot, size: BaroqueSize(f)) }
                }
            }, to: dir.appendingPathComponent("day-\(name).png"))
        }

        let long = Quote(text: "The first principle is that you must not fool yourself, and you are the easiest person to fool. So you have to be very careful about that, and about what you hold true.", author: "Richard Feynman, Cargo Cult Science")
        let quotes: [(String, Quote, String?)] = [
            ("short", DemoData.quotes[3], nil),
            ("long", long, nil),
            ("no-author", DemoData.quotes[2], nil),
            ("orwell", DemoData.quotes[0], nil),
            ("error", DemoData.quotes[0], "Couldn't load Quotes.md. Showing saved quotes."),
        ]
        for (name, quote, err) in quotes {
            sheet(HStack(alignment: .top, spacing: 16) {
                ForEach(Family.allCases.reversed(), id: \.self) { f in
                    WidgetTile(family: f) { MDQuote(quote: quote, size: BaroqueSize(f), date: Mock.now, error: err) }
                }
            }, to: dir.appendingPathComponent("quote-\(name).png"))
        }
        print("Rendered Medallion states to \(dir.path)")
    }

    private static func sheet<V: View>(_ view: V, to url: URL) {
        MockRunner.write(view.padding(16).background(PaintedWallpaper()), scale: 2, to: url)
    }
}
