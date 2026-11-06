import SwiftUI
import AppKit
import UniformTypeIdentifiers

// The weather-first widget set (brief of 2026-11-04): a Weather widget in three sizes that shows the temperature,
// condition, sunrise and sunset and the month (no calendar grid, no tasks), and a separate To-do widget.
// A mock conforms to WeatherMock and calls WeatherRunner.run(_:) from main; files land in MockLab/out/<slug>/.
// Kit and PaintKit both link this file.

protocol WeatherMock {
    associatedtype WeatherBody: View
    associatedtype TodoBody: View
    associatedtype WallpaperBody: View

    var name: String { get }
    var slug: String { get }
    var tagline: String { get }

    /// The whole Weather widget, background included, at exactly `Mock.size(family)`.
    @MainActor @ViewBuilder func weather(_ snapshot: DaySnapshot, family: Family) -> WeatherBody
    /// The whole To-do widget (small and medium), at exactly `Mock.size(family)`.
    @MainActor @ViewBuilder func todo(_ snapshot: DaySnapshot, family: Family) -> TodoBody
    /// Home-screen wallpaper behind the board.
    @MainActor @ViewBuilder func wallpaper() -> WallpaperBody
}

extension Mock {
    /// The demo day at 9:15 PM: the same weather and tasks after sunset, for each widget's night version.
    static let night: DaySnapshot = {
        let at = Calendar.current.date(bySettingHour: 21, minute: 15, second: 0, of: Mock.now) ?? Mock.now
        var snapshot = DemoData.day(now: at)
        snapshot.weather?.isDay = false
        return snapshot
    }()
}

/// Weather large, medium and small plus To-do small on the left; Weather large at night, To-do medium and the
/// name card on the right.
struct WeatherBoard<M: WeatherMock>: View {
    var mock: M

    var body: some View {
        let g: CGFloat = 28
        HStack(alignment: .top, spacing: g) {
            VStack(spacing: g) {
                WidgetTile(family: .large) { mock.weather(Mock.day, family: .large) }
                WidgetTile(family: .medium) { mock.weather(Mock.day, family: .medium) }
                HStack(spacing: 20) {
                    WidgetTile(family: .small) { mock.weather(Mock.day, family: .small) }
                    WidgetTile(family: .small) { mock.todo(Mock.day, family: .small) }
                }
            }
            VStack(spacing: g) {
                WidgetTile(family: .large) { mock.weather(Mock.night, family: .large) }
                WidgetTile(family: .medium) { mock.todo(Mock.day, family: .medium) }
                nameCard
            }
        }
        .padding(g)
        .background { mock.wallpaper() }
        .clipped()
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mock.name)
                .font(.system(size: 26, weight: .bold))
            Text(mock.tagline)
                .font(.system(size: 13, weight: .regular))
                .opacity(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(width: Mock.size(.medium).width, height: Mock.size(.medium).height, alignment: .bottomLeading)
        .background(.black.opacity(0.66), in: RoundedRectangle(cornerRadius: Mock.cornerRadius, style: .continuous))
    }
}

@MainActor
enum WeatherRunner {
    /// Writes weather-<family>.png and weather-<family>-night.png for all three sizes, todo-small.png and
    /// todo-medium.png (all scale 3), board.png (scale 2) and meta.json to MockLab/out/<slug>/.
    static func run<M: WeatherMock>(_ m: M) {
        let dir = Mock.root.appendingPathComponent("out/\(m.slug)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for f in Family.allCases {
            MockRunner.write(WidgetTile(family: f) { m.weather(Mock.day, family: f) }, scale: 3,
                             to: dir.appendingPathComponent("weather-\(f.rawValue).png"))
            MockRunner.write(WidgetTile(family: f) { m.weather(Mock.night, family: f) }, scale: 3,
                             to: dir.appendingPathComponent("weather-\(f.rawValue)-night.png"))
        }
        for f in [Family.small, .medium] {
            MockRunner.write(WidgetTile(family: f) { m.todo(Mock.day, family: f) }, scale: 3,
                             to: dir.appendingPathComponent("todo-\(f.rawValue).png"))
        }
        MockRunner.write(WeatherBoard(mock: m), scale: 2, to: dir.appendingPathComponent("board.png"))
        let meta = ["name": m.name, "slug": m.slug, "tagline": m.tagline, "kind": "weather"]
        if let data = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dir.appendingPathComponent("meta.json"))
        }
        print("Rendered \(m.name) to \(dir.path)")
    }
}
