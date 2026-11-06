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
            shot("today-medium", .medium, RococoTodayView(snapshot: day, size: .medium)),
            shot("today-small", .small, RococoTodayView(snapshot: day, size: .small)),
            shot("quote-large", .large, RococoQuoteView(quote: longQuote, size: .large, date: Mock.now, error: nil)),
            shot("quote-medium", .medium, RococoQuoteView(quote: DemoData.quotes[0], size: .medium, date: Mock.now, error: nil)),
            shot("quote-small", .small, RococoQuoteView(quote: DemoData.quotes[3], size: .small, date: Mock.now, error: nil)),
            shot("battery-small", .small, RococoBatteryView(reading: BatteryReading(level: 0.82, charging: false, at: Mock.now))),
            shot("still-life-small", .small, RococoPicture(name: "RococoStillLife")),
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
