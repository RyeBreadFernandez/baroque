import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        if let dir = ProcessInfo.processInfo.environment["CH_STATES_DIR"], !dir.isEmpty {
            CHStates.render(to: URL(fileURLWithPath: dir, isDirectory: true))
        } else {
            MockRunner.run(CrimsonHours())
        }
    }
}

/// Crimson Hours: a rented room in the early sixties, always about an hour after sunset.
struct CrimsonHours: MockAesthetic {
    let name = "Crimson Hours"
    let slug = "crimson-hours"
    let tagline = "Evening in a rented room: crimson flock in tungsten light, a tear-off calendar on its nail, a letter for a list, and misty ridges climbing with lamps beyond the window."

    @ViewBuilder func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        switch family {
        case .small: CHDaySmall(snap: snapshot)
        case .medium: CHDayMedium(snap: snapshot)
        case .large: CHDayLarge(snap: snapshot)
        }
    }

    @ViewBuilder func quote(_ quote: Quote, family: Family) -> some View {
        switch family {
        case .small: CHQuoteSmall(quote: quote)
        case .medium: CHQuoteMedium(quote: quote)
        case .large: CHQuoteLarge(quote: quote)
        }
    }

    func wallpaper() -> some View { CHBoardWallpaper() }
}

/// The home screen behind the board: the same flock wall, large, with one lamp pool and the dark coming in.
struct CHBoardWallpaper: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            CHFlock.pattern(ctx, in: r, tone: .crimson, cell: CGSize(width: 58, height: 76), seed: 99)
            ctx.draw(ctx.resolve(CH.texture("wall-large")), in: r)
            CHFlock.light(ctx, size: size, pools: [CHPool(center: CGPoint(x: size.width * 0.3, y: size.height * 0.25), radius: size.width * 0.75),
                                                   CHPool(center: CGPoint(x: size.width * 0.8, y: size.height * 0.85), radius: size.width * 0.45, strength: 0.5)],
                          ambient: Color(hex: 0x170C0A))
            ctx.fill(Path(r), with: .radialGradient(Gradient(stops: [.init(color: .clear, location: 0.45), .init(color: .black.opacity(0.75), location: 1)]),
                                                    center: CGPoint(x: size.width * 0.45, y: size.height * 0.4), startRadius: 0, endRadius: size.width * 0.8))
        }
    }
}

/// States the demo doesn't show, rendered when CH_STATES_DIR is set (nothing is written to out/).
@MainActor
enum CHStates {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let a = CrimsonHours()
        let base = Mock.day
        var empty = base
        empty.tasks = []
        var failed = base
        failed.tasks = []
        failed.taskError = "GitHub 401: Bad credentials. Check the token in Baroque settings."
        var noWeather = base
        noWeather.weather = nil
        noWeather.weatherError = "The Internet connection appears to be offline."
        var rain = base
        rain.weather?.code = 63
        rain.weather?.temperature = 51
        var snow = base
        snow.weather?.code = 73
        snow.weather?.temperature = 29
        var storm = base
        storm.weather?.code = 95
        var fog = base
        fog.weather?.code = 45
        let days: [(String, DaySnapshot)] = [("empty", empty), ("error", failed), ("noweather", noWeather), ("rain", rain), ("snow", snow), ("storm", storm), ("fog", fog)]
        for (tag, snap) in days {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { a.day(snap, family: f) }, scale: 3, to: dir.appendingPathComponent("day-\(tag)-\(f.rawValue).png"))
            }
        }
        let long = Quote(text: "We spend the evenings walking the same stairs past the same lamps, and only later understand that those were the hours that mattered most, the slow ones, the ones we thought would always come back around again.", author: nil)
        let noAuthor = Quote(text: "Make the quiet thing first, then the loud one.", author: nil)
        let longAuthor = Quote(text: "Good ideas take time.", author: "A very long attribution line, from a letter never sent, 1962")
        for (tag, q) in [("long", long), ("noauthor", noAuthor), ("longauthor", longAuthor)] {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { a.quote(q, family: f) }, scale: 3, to: dir.appendingPathComponent("quote-\(tag)-\(f.rawValue).png"))
            }
        }
        print("Rendered Crimson Hours states to \(dir.path)")
    }
}
