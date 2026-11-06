import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        if let dir = ProcessInfo.processInfo.environment["AL_STATES_DIR"], !dir.isEmpty {
            ALStates.render(to: URL(fileURLWithPath: dir, isDirectory: true))
        } else {
            WeatherRunner.run(WAlmanac())
        }
    }
}

struct WAlmanac: WeatherMock {
    let name = "Almanac"
    let slug = "weather-almanac"
    let tagline = "A page from an old almanac: a painted plate of the Matterhorn tipped in at its head, the month in "
        + "a big Didone word, and the day's weather typeset beneath it."

    @MainActor @ViewBuilder func weather(_ snapshot: DaySnapshot, family: Family) -> some View {
        switch family {
        case .small: ALWeatherSmall(snapshot: snapshot)
        case .medium: ALWeatherMedium(snapshot: snapshot)
        case .large: ALWeatherLarge(snapshot: snapshot)
        }
    }

    @MainActor @ViewBuilder func todo(_ snapshot: DaySnapshot, family: Family) -> some View {
        switch family {
        case .small, .large: ALTodoSmall(snapshot: snapshot)
        case .medium: ALTodoMedium(snapshot: snapshot)
        }
    }

    @MainActor func wallpaper() -> some View { ALWallpaper() }
}

/// The edge cases, written to $AL_STATES_DIR as one sheet per state (the three Weather sizes and both To-do sizes,
/// scale 2): no weather, rain, snow, dusk, no tasks, a task error, a very long task title, and the 28th; plus
/// other-skies.png, the medium Weather widget under the remaining skies.
@MainActor
enum ALStates {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let cal = Calendar.current
        func at(_ hour: Int, _ minute: Int, day: Int? = nil) -> Date {
            var base = Mock.now
            if let day {
                var c = cal.dateComponents([.year, .month], from: Mock.now)
                c.day = day
                base = cal.date(from: c) ?? Mock.now
            }
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        var noWeather = Mock.day
        noWeather.weather = nil
        noWeather.weatherError = "Open-Meteo did not answer (offline)"

        var rain = Mock.day
        rain.weather?.code = 63
        rain.weather?.temperature = 51
        rain.weather?.high = 55
        rain.weather?.low = 46

        var snow = Mock.day
        snow.weather?.code = 73
        snow.weather?.temperature = 29
        snow.weather?.high = 33
        snow.weather?.low = 21

        let dusk = DemoData.day(now: at(16, 45))

        var empty = Mock.day
        empty.tasks = []

        var taskError = Mock.day
        taskError.tasks = []
        taskError.taskError = "GitHub said 401: check the token in Baroque"

        var long = Mock.day
        if !long.tasks.isEmpty {
            long.tasks[0].text = "Write up the full field report on the Hörnli ridge, with every photograph, map and the "
                + "appendix of measurements"
        }

        let the28th = DemoData.day(now: at(9, 41, day: 28))

        let states: [(String, DaySnapshot)] = [("no-weather", noWeather), ("rain", rain), ("snow", snow), ("dusk", dusk),
                                               ("empty-tasks", empty), ("task-error", taskError),
                                               ("long-title", long), ("the-28th", the28th)]
        let m = WAlmanac()
        for (name, s) in states {
            let sheet = HStack(alignment: .top, spacing: 20) {
                WidgetTile(family: .large) { m.weather(s, family: .large) }
                VStack(spacing: 20) {
                    WidgetTile(family: .medium) { m.weather(s, family: .medium) }
                    WidgetTile(family: .medium) { m.todo(s, family: .medium) }
                    HStack(spacing: 20) {
                        WidgetTile(family: .small) { m.weather(s, family: .small) }
                        WidgetTile(family: .small) { m.todo(s, family: .small) }
                    }
                }
            }
            .padding(20)
            .background(Color(hex: 0x1A140F))
            MockRunner.write(sheet, scale: 2, to: dir.appendingPathComponent("\(name).png"))
        }
        // The other skies, for the engraved cuts and the plate's weather: partly cloudy by day and night, overcast,
        // fog, a storm, and snow at night.
        let skies: [(Int, Bool)] = [(2, true), (2, false), (3, true), (45, true), (95, true), (73, false)]
        let conditions = VStack(spacing: 20) {
            ForEach(Array(skies.enumerated()), id: \.offset) { _, sky in
                let s = sky.1 ? Mock.day : Mock.night
                let snapshot = { () -> DaySnapshot in
                    var x = s
                    x.weather?.code = sky.0
                    return x
                }()
                WidgetTile(family: .medium) { m.weather(snapshot, family: .medium) }
            }
        }
        .padding(20)
        .background(Color(hex: 0x1A140F))
        MockRunner.write(conditions, scale: 2, to: dir.appendingPathComponent("other-skies.png"))
        print("Rendered \(states.count) Almanac states (and the other skies) to \(dir.path)")
    }
}
