import SwiftUI

// MARK: - Day widgets

struct TopoDayLarge: View {
    let snap: DaySnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            MapSheet(sheet: TopoSheet.dayLarge, grid: 58, gridOrigin: CGPoint(x: 47, y: 61),
                     marginNote: "CONTOUR INTERVAL 40 FEET \u{00B7} DATUM MEAN SEA LEVEL")
            TitleBlock(date: snap.date, numeral: 68, caps: 11, reference: true)
                .offset(x: 16, y: 14)
            WeatherLegendLarge(weather: snap.weather, error: snap.weatherError)
                .frame(width: 132, height: 100)
                .offset(x: 200, y: 16)
            WeekScaleBar(date: snap.date, width: 316)
                .offset(x: 16, y: 126)
            RouteList(tasks: snap.tasks, error: snap.taskError, limit: 5, rowHeight: 28, width: 316)
                .offset(x: 16, y: 172)
            CompassRose(radius: 15)
                .position(x: 246, y: 326)
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }
}

struct TopoDayMedium: View {
    let snap: DaySnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            MapSheet(sheet: TopoSheet.dayMedium, grid: 58, gridOrigin: CGPoint(x: 37, y: 53), easting: 527, northing: 4106)
            TitleBlock(date: snap.date, numeral: 56, caps: 10, reference: false, shortMonth: true)
                .offset(x: 16, y: 14)
            WeatherLegendCompact(weather: snap.weather, error: snap.weatherError)
                .offset(x: 16, y: 106)
            RouteList(tasks: snap.tasks, error: snap.taskError, limit: 3, rowHeight: 26, width: 208,
                      textSize: 12.5, marker: 17, dueSize: 11.5)
                .offset(x: 124, y: 14)
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }
}

struct TopoDaySmall: View {
    let snap: DaySnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            MapSheet(sheet: TopoSheet.daySmall, grid: 54, gridOrigin: CGPoint(x: 29, y: 45), easting: 306, northing: 5218)
            SmallDate(date: snap.date).offset(x: 16, y: 14)
            SmallWeather(weather: snap.weather)
                .frame(width: 70, alignment: .trailing)
                .offset(x: 78, y: 14)
            SmallTask(tasks: snap.tasks, error: snap.taskError)
                .frame(width: 132, height: 58, alignment: .bottomLeading)
                .offset(x: 16, y: 90)
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }
}

// MARK: - Title block

struct TitleBlock: View {
    let date: Date
    var numeral: CGFloat
    var caps: CGFloat
    var reference: Bool
    var shortMonth = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(TopoDates.weekday(date))
                .font(TopoFont.futuraBold(caps)).tracking(caps * 0.24)
                .foregroundColor(TopoInk.red)
            HStack(alignment: .center, spacing: 7) {
                Text(TopoDates.dayNumber(date))
                    .font(TopoFont.din(numeral)).foregroundColor(TopoInk.ink)
                    .frame(height: numeral * 0.82)
                    .offset(y: numeral * 0.1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(shortMonth ? TopoDates.shortMonth(date) : TopoDates.month(date)).font(TopoFont.futuraBold(caps)).tracking(1.1)
                        .foregroundColor(TopoInk.ink)
                    Text(TopoDates.year(date)).font(TopoFont.menlo(caps * 0.82)).foregroundColor(TopoInk.inkSoft)
                    if reference {
                        Text("DAY \(TopoDates.dayOfYear(date)) · WK \(TopoDates.weekOfYear(date))")
                            .font(TopoFont.menlo(7.4)).foregroundColor(TopoInk.inkSoft)
                    }
                }
            }
        }
        .halo()
    }
}

// MARK: - Weather insets

struct WeatherLegendLarge: View {
    let weather: WeatherSnapshot?
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            LegendTitle(text: "CONDITIONS")
            if let w = weather {
                HStack(alignment: .center, spacing: 5) {
                    WeatherGlyph(symbol: w.symbolName, size: 26)
                    Text("\(Int(w.temperature.rounded()))°")
                        .font(TopoFont.din(38)).foregroundColor(TopoInk.ink)
                        .frame(height: 34).offset(y: 4)
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 1) {
                        HiLo(up: true, value: w.high, size: 13)
                        HiLo(up: false, value: w.low, size: 13)
                    }
                }
                Text(w.label).font(TopoFont.gillItalic(12.5)).foregroundColor(TopoInk.ink).lineLimit(1)
                HStack(spacing: 8) {
                    SunTime(rise: true, date: w.sunrise)
                    SunTime(rise: false, date: w.sunset)
                }
            } else {
                Text(error ?? "No weather yet").font(TopoFont.gillItalic(11)).foregroundColor(TopoInk.red).lineLimit(2)
            }
        }
        .padding(.horizontal, 9).padding(.top, 7).padding(.bottom, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PaperSlip())
    }
}

struct WeatherLegendCompact: View {
    let weather: WeatherSnapshot?
    let error: String?

    var body: some View {
        HStack(spacing: 5) {
            if let w = weather {
                WeatherGlyph(symbol: w.symbolName, size: 20)
                Text("\(Int(w.temperature.rounded()))°")
                    .font(TopoFont.din(26)).foregroundColor(TopoInk.ink).frame(height: 24).offset(y: 3)
                VStack(alignment: .leading, spacing: 0) {
                    HiLo(up: true, value: w.high, size: 11)
                    HiLo(up: false, value: w.low, size: 11)
                }
            } else {
                Text(error ?? "No weather").font(TopoFont.gillItalic(10)).foregroundColor(TopoInk.red).lineLimit(2)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(width: 104, height: 42, alignment: .leading)
        .background(PaperSlip())
    }
}

// MARK: - Route of waypoints

struct RouteList: View {
    let tasks: [TaskItem]
    let error: String?
    let limit: Int
    let rowHeight: CGFloat
    let width: CGFloat
    var textSize: CGFloat = 13.5
    var marker: CGFloat = 19
    var dueSize: CGFloat = 12.5

    private let headerHeight: CGFloat = 16
    private var shown: [TaskItem] { Array(tasks.prefix(limit)) }
    private var extra: Int { max(0, tasks.count - limit) }

    private var centers: [CGPoint] {
        var pts = shown.indices.map { CGPoint(x: marker / 2, y: headerHeight + rowHeight * (CGFloat($0) + 0.5)) }
        if extra > 0 { pts.append(CGPoint(x: marker / 2, y: headerHeight + rowHeight * CGFloat(shown.count) + 8)) }
        return pts
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RouteTrail(points: centers)
            header
            ForEach(Array(shown.enumerated()), id: \.offset) { i, t in
                row(i, t).frame(width: width, height: rowHeight).offset(y: headerHeight + rowHeight * CGFloat(i))
            }
            if extra > 0 { more.offset(y: headerHeight + rowHeight * CGFloat(shown.count)) }
            if shown.isEmpty { empty.offset(y: headerHeight + 4) }
        }
        .frame(width: width, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Text("TODAY'S ROUTE").font(TopoFont.futuraBold(7.8)).tracking(1.5).foregroundColor(TopoInk.red).fixedSize()
            Rectangle().fill(TopoInk.red.opacity(0.7)).frame(height: 0.6)
            Text(verbatim: "\(tasks.count) WAYPOINTS").font(TopoFont.menlo(7.2)).foregroundColor(TopoInk.inkSoft).fixedSize()
        }
        .frame(width: width, height: 10)
        .halo()
    }

    private func dueColor(_ t: TaskItem) -> Color {
        if t.isOverdue(asOf: Mock.now) { return TopoInk.red }
        return t.isDueToday(asOf: Mock.now) ? TopoInk.ink : TopoInk.inkSoft
    }

    private func row(_ i: Int, _ t: TaskItem) -> some View {
        HStack(spacing: 7) {
            Waypoint(number: "\(i + 1)", task: t, size: marker)
            Text(t.text)
                .font(TopoFont.gillSemi(textSize)).foregroundColor(TopoInk.ink)
                .lineLimit(1).truncationMode(.tail)
                .halo()
            Spacer(minLength: 4)
            if let due = Mock.dueLabel(t) {
                Text(due.uppercased()).font(TopoFont.din(dueSize)).tracking(0.4)
                    .foregroundColor(dueColor(t)).offset(y: dueSize * 0.1)
                    .halo()
            }
        }
    }

    private var more: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill(TopoInk.paperLight)
                Circle().stroke(TopoInk.red, style: StrokeStyle(lineWidth: 0.9, dash: [1.8, 1.4]))
                Text("+\(extra)").font(TopoFont.din(marker * 0.5)).foregroundColor(TopoInk.red).offset(y: marker * 0.05)
            }
            .frame(width: marker * 0.85, height: marker * 0.85)
            .frame(width: marker)
            Text("\(extra) more waypoint\(extra == 1 ? "" : "s") ahead")
                .font(TopoFont.futuraItalic(9.5)).foregroundColor(TopoInk.inkSoft)
                .halo()
        }
        .frame(height: 16)
    }

    private var empty: some View {
        Text(error ?? "Trail clear: no waypoints today")
            .font(TopoFont.gillItalic(12)).foregroundColor(error == nil ? TopoInk.inkSoft : TopoInk.red)
            .lineLimit(2).frame(width: width, alignment: .leading)
            .padding(.leading, marker + 7)
            .halo()
    }
}

// MARK: - Small parts

struct SmallDate: View {
    let date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(TopoDates.weekday(date)).font(TopoFont.futuraBold(8.6)).tracking(1.6).foregroundColor(TopoInk.red)
            HStack(alignment: .center, spacing: 4) {
                Text(TopoDates.dayNumber(date)).font(TopoFont.din(42)).foregroundColor(TopoInk.ink)
                    .frame(height: 35).offset(y: 4)
                Text(TopoDates.shortMonth(date)).font(TopoFont.futuraBold(9.5)).tracking(1).foregroundColor(TopoInk.ink)
            }
        }
        .halo()
    }
}

struct SmallWeather: View {
    let weather: WeatherSnapshot?
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if let w = weather {
                HStack(spacing: 3) {
                    WeatherGlyph(symbol: w.symbolName, size: 17)
                    Text("\(Int(w.temperature.rounded()))°").font(TopoFont.din(24)).foregroundColor(TopoInk.ink)
                        .frame(height: 22).offset(y: 3)
                }
                Text("H\(Int(w.high.rounded()))  L\(Int(w.low.rounded()))").font(TopoFont.din(10.5)).foregroundColor(TopoInk.inkSoft)
            }
        }
        .halo()
    }
}

struct SmallTask: View {
    let tasks: [TaskItem]
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let t = tasks.first {
                HStack(alignment: .top, spacing: 6) {
                    Waypoint(number: "1", task: t, size: 16).offset(y: 1)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.text).font(TopoFont.gillSemi(12.5)).foregroundColor(TopoInk.ink)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        if let due = Mock.dueLabel(t) {
                            Text(due.uppercased()).font(TopoFont.din(10.5)).tracking(0.4)
                                .foregroundColor(t.isOverdue(asOf: Mock.now) ? TopoInk.red : TopoInk.inkSoft)
                        }
                    }
                    .halo()
                }
                if tasks.count > 1 {
                    Text("+\(tasks.count - 1) more on the route").font(TopoFont.futuraItalic(9)).foregroundColor(TopoInk.inkSoft)
                        .padding(.leading, 22).halo()
                }
            } else {
                Text(error ?? "Trail clear today").font(TopoFont.gillItalic(12))
                    .foregroundColor(error == nil ? TopoInk.inkSoft : TopoInk.red).halo()
            }
        }
    }
}
