import SwiftUI

// The day widgets: a landscape print with the weekday tanzaku, the date seal, a weather cartouche and the agenda on a handscroll.

struct WBTemp {
    static func deg(_ v: Double?) -> String { v.map { "\(Int($0.rounded()))°" } ?? "--" }

    /// Large temperature in Bodoni with the degree mark tucked in (the face sets it wide).
    static func big(_ v: Double?, size: CGFloat) -> Text {
        guard let v else { return Text("--").font(WB.bodoni(size)) }
        let n = String(Int(v.rounded()))
        return Text(String(n.dropLast())).font(WB.bodoni(size))
            + Text(String(n.suffix(1))).font(WB.bodoni(size)).kerning(-size * 0.1)
            + Text("°").font(WB.bodoni(size * 0.8))
    }
}

/// Cream type laid on the dark sky band, with a soft sumi halo so it holds on the lighter bokashi.
struct SkyText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(WB.washi)
            .shadow(color: WB.indigoDeep.opacity(0.85), radius: 1.2, x: 0, y: 0.5)
            .shadow(color: WB.indigoDeep.opacity(0.5), radius: 4)
    }
}

extension View {
    func skyText() -> some View { modifier(SkyText()) }
}

struct WeatherCartouche: View {
    var weather: WeatherSnapshot?
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WBTemp.big(weather?.temperature, size: 36)
                .padding(.bottom, -2)
            Text(weather?.label ?? (error ?? "No weather"))
                .font(WB.hoeflerItalic(12.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.bottom, 3)
            Text("H \(WBTemp.deg(weather?.high))  L \(WBTemp.deg(weather?.low))")
                .font(WB.bodoni(12))
                .padding(.bottom, 1)
            HStack(spacing: 3) {
                Image(systemName: "sunrise.fill").font(.system(size: 8.5)).foregroundStyle(WB.vermilionDeep)
                Text(Mock.time(weather?.sunrise))
                Image(systemName: "sunset.fill").font(.system(size: 8.5)).foregroundStyle(WB.vermilionDeep)
                    .padding(.leading, 3)
                Text(Mock.time(weather?.sunset))
            }
            .font(WB.bodoni(11.5))
        }
        .foregroundStyle(WB.sumi)
        .padding(.horizontal, 10)
        .padding(.top, 5)
        .padding(.bottom, 8)
        .background(CartoucheShape(band: WB.celadonDeep, bandWidth: 3, seed: 8))
    }
}

struct AgendaList: View {
    var tasks: [TaskItem]
    var limit: Int
    var rowHeight: CGFloat
    var size: CGFloat = 12.5
    var error: String? = nil

    var body: some View {
        let shown = Array(tasks.prefix(error == nil ? limit : max(0, limit - 1)))
        let extra = tasks.count - shown.count
        VStack(alignment: .leading, spacing: 0) {
            if let error {
                Text(error)
                    .font(WB.hoeflerItalic(11))
                    .foregroundStyle(WB.vermilionDeep)
                    .lineLimit(1)
                    .frame(height: rowHeight)
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { i, t in
                TaskLine(task: t, size: size)
                    .frame(height: rowHeight)
                if i < shown.count - 1 { Rule() }
            }
            if extra > 0 {
                Text("+ \(extra) more")
                    .font(WB.hoeflerItalic(11))
                    .foregroundStyle(WB.sumiSoft)
                    .padding(.leading, 17)
                    .padding(.top, 2)
            }
            if shown.isEmpty {
                Text("Nothing due. A clear sky.")
                    .font(WB.hoeflerItalic(12))
                    .foregroundStyle(WB.sumiSoft)
            }
        }
    }
}

/// Two-digit days are cut a little smaller so they sit inside the seal's border.
func sealSize(_ base: CGFloat, _ d: Date) -> CGFloat { WBDate.day(d).count > 1 ? base * 0.8 : base }

// MARK: large

struct DayLarge: View {
    var s: DaySnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            PrintScene(spec: WBScenes.dayLarge(WBSky.from(s.weather)))
            Tanzaku(kanji: WBDate.weekdayKanji(s.date), word: WBDate.weekday(s.date), width: 30, letter: 12, kanjiSize: 16)
                .offset(x: 16, y: 16)
            Hanko(text: WBDate.day(s.date), font: WB.bodoniBold(sealSize(42, s.date)), size: 58, dy: 1)
                .offset(x: 58, y: 18)
            monthLine.offset(x: 58, y: 82)
            WeatherCartouche(weather: s.weather, error: s.weatherError)
                .fixedSize()
                .frame(width: 112, alignment: .trailing)
                .offset(x: 220, y: 16)
            WeekBand(date: s.date)
                .frame(width: 318, height: 30)
                .offset(x: 15, y: 178)
            Handscroll {
                AgendaList(tasks: s.tasks, limit: 5, rowHeight: 21, error: s.taskError)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
            }
            .frame(width: 324, height: 138, alignment: .top)
            .offset(x: 12, y: 214)
            PrintFrame()
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }

    var monthLine: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(WBDate.month(s.date).uppercased())
                .font(WB.bodoni(12.5))
                .tracking(1.6)
            Text(WBDate.year(s.date))
                .font(WB.bodoniItalic(12))
                .tracking(0.6)
        }
        .skyText()
    }
}

// MARK: medium

struct DayMedium: View {
    var s: DaySnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            PrintScene(spec: WBScenes.dayMedium(WBSky.from(s.weather)))
            Tanzaku(kanji: WBDate.weekdayKanji(s.date), word: WBDate.weekday(s.date), width: 24, letter: 10, kanjiSize: 13)
                .offset(x: 16, y: 16)
            Hanko(text: WBDate.day(s.date), font: WB.bodoniBold(sealSize(33, s.date)), size: 46, dy: 1)
                .offset(x: 50, y: 17)
            Text(WBDate.month(s.date).uppercased())
                .font(WB.bodoni(10))
                .tracking(0.7)
                .fixedSize()
                .skyText()
                .frame(width: 46)
                .offset(x: 50, y: 68)
            Handscroll {
                VStack(alignment: .leading, spacing: 0) {
                    weatherRow.padding(.bottom, 3)
                    Rule()
                    Rule().padding(.top, 1.5)
                    AgendaList(tasks: s.tasks, limit: 3, rowHeight: 21, size: 12, error: s.taskError)
                        .padding(.top, 1)
                }
                .padding(.top, 8)
                .padding(.bottom, 5)
            }
            .frame(width: 230, height: 138, alignment: .top)
            .offset(x: 106, y: 13)
            PrintFrame()
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }

    var weatherRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            WBTemp.big(s.weather?.temperature, size: 19)
            Text(s.weather?.label ?? (s.weatherError ?? "No weather"))
                .font(WB.hoeflerItalic(11.5))
                .lineLimit(1)
            Spacer(minLength: 2)
            Text("H \(WBTemp.deg(s.weather?.high))  L \(WBTemp.deg(s.weather?.low))")
                .font(WB.bodoni(11))
                .foregroundStyle(WB.sumiSoft)
        }
        .foregroundStyle(WB.sumi)
    }
}

// MARK: small

struct DaySmall: View {
    var s: DaySnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            PrintScene(spec: WBScenes.daySmall(WBSky.from(s.weather)))
            Hanko(text: WBDate.day(s.date), font: WB.bodoniBold(sealSize(30, s.date)), size: 42, dy: 1)
                .offset(x: 17, y: 17)
            VStack(alignment: .leading, spacing: -2) {
                WBTemp.big(s.weather?.temperature, size: 22)
                Text(WBDate.monthShort(s.date).uppercased()).font(WB.bodoni(10.5)).tracking(1.2)
            }
            .skyText()
            .offset(x: 66, y: 15)
            Tanzaku(kanji: WBDate.weekdayKanji(s.date), word: WBDate.weekdayShort(s.date), width: 22, letter: 10, kanjiSize: 12)
                .offset(x: 126, y: 15)
            Handscroll(rod: 6, cap: 3) {
                firstTask
                    .padding(.top, 9)
                    .padding(.bottom, 7)
            }
            .frame(width: 148, height: 60, alignment: .top)
            .offset(x: 8, y: 92)
            PrintFrame()
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }

    @ViewBuilder var firstTask: some View {
        if let t = s.tasks.first {
            VStack(alignment: .leading, spacing: 2) {
                TaskLine(task: t, size: 12, lines: 2, showDue: false)
                HStack(spacing: 4) {
                    if let due = Mock.dueLabel(t) {
                        DueNote(label: due, overdue: t.isOverdue(asOf: Mock.now), today: t.isDueToday(asOf: Mock.now), size: 10.5)
                    }
                    Spacer(minLength: 0)
                    if s.tasks.count > 1 {
                        Text("+ \(s.tasks.count - 1) more").font(WB.hoeflerItalic(10.5)).foregroundStyle(WB.sumiSoft)
                    }
                }
            }
        } else {
            Text("Nothing due today").font(WB.hoeflerItalic(12)).foregroundStyle(WB.sumiSoft)
        }
    }
}
