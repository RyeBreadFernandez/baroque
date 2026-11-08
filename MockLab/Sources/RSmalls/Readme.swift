import SwiftUI

// The README's widget pictures (README=1): the shipped widget views (Shared/Rococo*.swift, linked here) with demo data,
// at their design sizes for the gallery, and at the sizes the author's iPhone 15 Pro draws them with large icons, to
// lay onto its home screen screenshots (scripts/readme_images.py).

enum ReadmeRenders {
    struct Shot {
        var name: String
        var size: CGSize
        var view: AnyView
    }

    static var quote: Quote { Quote(text: "Make the quiet thing first, then the loud one.", author: nil) }
    static var longQuote: Quote { DemoData.quotes.first { $0.author == "Seneca" } ?? DemoData.quotes[0] }

    /// The demo day with tasks shaped like the Daily Brief's (examples/Daily Brief/Today.md): a source note on each.
    static var briefDay: DaySnapshot {
        var d = Mock.day
        let cal = Calendar.current
        let today = cal.startOfDay(for: Mock.now)
        func task(_ text: String, _ days: Int?, _ p: TaskPriority = .none, _ line: Int) -> TaskItem {
            TaskItem(text: text, due: days.flatMap { cal.date(byAdding: .day, value: $0, to: today) }, priority: p,
                     sourcePath: "Daily Brief/Today.md", lineNumber: line)
        }
        d.tasks = [
            task("Finish the problem set and upload it to Gradescope. (Canvas, due tonight)", 0, .high, 10),
            task("Send the lab partners the draft of the methods section. (Jamie, email, Nov 5)", -1, .none, 11),
            task("Renew the parking permit before it lapses on Sunday. (Transportation office, email, Nov 4)", 2, .none, 12),
            task("Reply about Saturday's hike: carpool leaves at 7:00 AM. (Hiking club, message, Nov 5)", 1, .none, 13),
            task("Return the library hold on The Painter of Modern Life.", nil, .none, 14),
            task("Book office hours for the essay draft.", nil, .none, 15),
            task("Pump tires, get gas", nil, .none, 16),
        ]
        return d
    }

    /// The widgets at their design sizes (iPhone 17), for the gallery.
    static func gallery() -> [Shot] {
        let day = Mock.day
        func shot(_ name: String, _ size: BaroqueSize, _ view: some View) -> Shot {
            Shot(name: name, size: size.designSize, view: AnyView(view))
        }
        return [
            shot("day-large", .large, RococoDayView(snapshot: day, quote: quote, size: .large)),
            shot("day-medium", .medium, RococoDayView(snapshot: day, quote: nil, size: .medium)),
            shot("day-small", .small, RococoDayView(snapshot: day, quote: nil, size: .small)),
            shot("today-large", .large, RococoTodayView(snapshot: briefDay, size: .large)),
            // States to check by eye (not in the README): short tasks, and a failed fetch over cached tasks.
            shot("check-today-large-short", .large, RococoTodayView(snapshot: day, size: .large)),
            shot("check-today-large-error", .large, RococoTodayView(snapshot: { var d = briefDay; d.taskError = "GitHub rejected the token (401)"; return d }(), size: .large)),
            shot("today-medium", .medium, RococoTodayView(snapshot: day, size: .medium)),
            shot("today-small", .small, RococoTodayView(snapshot: day, size: .small)),
            shot("quote-large", .large, RococoQuoteView(quote: longQuote, size: .large, date: Mock.now, error: nil)),
            shot("quote-medium", .medium, RococoQuoteView(quote: DemoData.quotes[0], size: .medium, date: Mock.now, error: nil)),
            shot("quote-small", .small, RococoQuoteView(quote: DemoData.quotes[3], size: .small, date: Mock.now, error: nil)),
            shot("battery-small", .small, RococoBatteryView(reading: BatteryReading(level: 0.82, charging: false, at: Mock.now))),
            shot("still-life-small", .small, RococoPicture(name: "RococoStillLife")),
            shot("photograph-small", .small, RococoPicture(name: "RococoPhoto-sunset-small")),
            shot("still-life-large", .large, RococoPicture(name: "RococoStillLifeLarge")),
        ]
    }

    /// The widgets on the author's home screen, at the sizes measured on its screenshots (points).
    static func phone() -> [Shot] {
        let day = Mock.day
        let small = CGSize(width: 167, height: 167), large = CGSize(width: 354, height: 353)
        return [
            Shot(name: "phone-day-large", size: large, view: AnyView(RococoDayView(snapshot: day, quote: quote, size: .large))),
            Shot(name: "phone-day-small", size: small, view: AnyView(RococoDayView(snapshot: day, quote: nil, size: .small))),
            Shot(name: "phone-quote-small", size: small, view: AnyView(RococoQuoteView(quote: DemoData.quotes[3], size: .small, date: Mock.now, error: nil))),
            Shot(name: "phone-today-small", size: small, view: AnyView(RococoTodayView(snapshot: day, size: .small))),
        ]
    }

    /// Every photograph in the large Day widget, twice: the list repeats every 30 hours, so the second time each one
    /// comes round it's six hours later in the day (night where it was day). Not in the README; for checking the words.
    @MainActor static func renderHeroChecks(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let first = RococoPhotos.nextChange(after: Mock.now)
        for k in 0..<(RococoPhotos.underWords.count * 2) {
            var day = Mock.day
            day.date = first.addingTimeInterval(Double(k * RococoPhotos.hours) * 3600 + 5400)
            let hour = Calendar.current.component(.hour, from: day.date)
            let view = RococoDayView(snapshot: day, quote: longQuote, size: .large).frame(width: 348, height: 365)
            MockRunner.write(view, scale: 2, to: dir.appendingPathComponent(String(format: "%02d-%@-%02dh.png", k, RococoPhotos.largeName(at: day.date), hour)))
        }
    }

    @MainActor static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for s in gallery() {
            MockRunner.write(s.view.frame(width: s.size.width, height: s.size.height), scale: 3, to: dir.appendingPathComponent("\(s.name).png"))
        }
        for s in phone() {
            MockRunner.write(s.view.frame(width: s.size.width, height: s.size.height), scale: 2, to: dir.appendingPathComponent("\(s.name).png"))
        }
        print("Rendered the README's widgets to \(dir.path)")
    }
}
