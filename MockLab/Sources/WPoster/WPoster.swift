import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // TP_STATES_DIR=/some/folder renders the states the board doesn't show, and leaves out/ alone.
        if TPStates.renderIfRequested() { return }
        WeatherRunner.run(WPoster())
    }
}

struct WPoster: WeatherMock {
    let name = "Travel Poster"
    let slug = "weather-poster"
    let tagline = "A vintage Swiss travel poster of the Matterhorn: the month as its title, a live sun or moon disc riding its arc behind the peak, and the sun's times on the caption band; tasks ride on a railway ticket."

    func weather(_ snapshot: DaySnapshot, family: Family) -> some View { TPWeather(snapshot: snapshot, family: family) }
    func todo(_ snapshot: DaySnapshot, family: Family) -> some View { TPTodo(snapshot: snapshot, family: family) }
    func wallpaper() -> some View { TPWallpaper() }
}

/// The home screen behind the board: the same print, pulled big and dark just after sunset, stars coming out.
struct TPWallpaper: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            let h = s.height * 0.4
            let stage = TPStage(size: s, summit: CGPoint(x: s.width * 0.58, y: s.height * 0.42), height: h,
                                skyBottom: s.height * 0.9, arcCentreX: s.width * 0.55,
                                arcRadius: CGSize(width: s.width * 0.42, height: s.height * 0.5), horizon: s.height * 0.86,
                                disc: s.width * 0.07, pitch: 5,
                                meadow: [CGPoint(x: 0, y: s.height * 0.86), CGPoint(x: s.width * 0.5, y: s.height * 0.89), CGPoint(x: s.width, y: s.height * 0.85)],
                                field: [CGPoint(x: 0, y: s.height * 0.94), CGPoint(x: s.width, y: s.height * 0.95)],
                                spruce: [(s.width * 0.74, s.width, 12, 30, 60), (0, s.width * 0.14, 5, 26, 44)],
                                clouds: [], ceiling: 0, mist: 0, seed: 1908)
            let clock = SkyClock(now: Calendar.current.date(bySettingHour: 17, minute: 20, second: 0, of: Mock.now) ?? Mock.now,
                                 weather: Mock.day.weather)
            let inks = TPInks(clock: clock, condition: .clear)
            TPPrint(stage: stage, inks: inks, clock: clock, condition: .clear, date: Mock.now, showsArc: false, showsDisc: false)
                .overlay(Color(red: 0.03, green: 0.07, blue: 0.1).opacity(0.38))
                .overlay(TPPaper())
        }
    }
}
