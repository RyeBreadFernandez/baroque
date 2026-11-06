import SwiftUI

// The Day widget as a magazine cover. The day of the month is the masthead: an enormous gilt Baskerville numeral
// standing inside the painting, the snowy horn of the main peak rising in front of its foot and a puff of cloud
// drifting across one shoulder. The month (and on large the year) is the dateline in small spaced capitals. Below,
// on the painting's own dark ground (no card), an editorial grid: the weather as a cover line, the tasks in the body
// serif with their due notes, and on large the month as dates only, today circled in cream.
//
// Every layout is fixed at the iPhone 17 widget size (the paintings are composed round it); CoverFrame scales it to
// the widget it is given. The sky follows snapshot.date, so it is as current as the timeline entry.

/// The whole Day widget, painting included. Fills the space it is offered (the widget, with content margins off).
struct CoverDayView: View {
    var snapshot: DaySnapshot
    var settings: BaroqueSettings
    var size: BaroqueSize

    var body: some View {
        CoverFrame(size: size) {
            switch size {
            // Task rows: the smaller of the setting and what the layout fits.
            case .large: CoverDayLarge(snap: snapshot, rows: Self.rows(settings, fits: 5))
            case .medium: CoverDayMedium(snap: snapshot, rows: Self.rows(settings, fits: 3))
            case .small: CoverDaySmall(snap: snapshot)
            }
        }
    }

    private static func rows(_ settings: BaroqueSettings, fits: Int) -> Int { max(1, min(settings.maxTasks, fits)) }
}

/// The painting for a snapshot, with today's date as its hero.
struct CoverDayScene: View {
    var snap: DaySnapshot
    var canvas: CoverCanvas

    var body: some View {
        CoverScene(canvas: canvas, glyph: CoverWords.day(snap.date),
                   clock: SkyClock(now: snap.date, weather: snap.weather),
                   condition: SkyCondition(code: snap.weather?.code),
                   phase: MoonPhase(date: snap.date))
    }
}

// MARK: - Large

/// The cover fills the top 60% (dateline, numeral, peak); the dark ground below carries the cover line, then the
/// tasks and the month side by side, parted by a hairline.
struct CoverDayLarge: View {
    var snap: DaySnapshot
    var rows = 5

    static let body: CGFloat = 13
    static let label: CGFloat = 9
    static let groundTop: CGFloat = 218

    var body: some View {
        ZStack(alignment: .topLeading) {
            CoverDayScene(snap: snap, canvas: .dayLarge)
            CoverDateline(left: CoverWords.month(snap.date), right: CoverWords.roman(snap.date), size: 9)
                .padding(.horizontal, 16)
                .padding(.top, 15)
            // The painting's title, like the label on its frame, at the foot of the picture under the mountain.
            CoverPaintingTitle()
                .frame(width: 348 - 32, height: Self.groundTop - 12, alignment: .bottomLeading)
                .offset(x: 16)
            VStack(alignment: .leading, spacing: 0) {
                CoverWeatherLine(snap: snap)
                CoverRule()
                    .padding(.top, 7)
                HStack(alignment: .top, spacing: 0) {
                    CoverTaskList(snap: snap, rows: rows, size: Self.body, label: Self.label, rowHeight: 16.6)
                    CoverRule(vertical: true)
                        .padding(.horizontal, 11)
                    CoverMonth(date: snap.date, tasks: snap.tasks, cell: 15.5, size: 9)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .frame(width: 348, height: 365 - Self.groundTop - 16, alignment: .top)
            .offset(y: Self.groundTop)
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }
}

/// The weather set as a cover line: temperature and condition in the serif, the rest in the label face.
struct CoverWeatherLine: View {
    var snap: DaySnapshot

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let w = snap.weather {
                Text(CoverWords.temp(w)).font(CoverType.serif(18)).foregroundStyle(CoverInk.cream)
                Text(w.label.lowercased()).font(CoverType.italic(15)).foregroundStyle(CoverInk.creamSoft)
                    .lineLimit(1)
                Spacer(minLength: 8)
                let parts = ["high \(Int(w.high.rounded()))", "low \(Int(w.low.rounded()))", CoverWords.sunEvent(w, now: snap.date)]
                Text(parts.compactMap { $0 }.joined(separator: "  ·  ")).coverLabel(9.5).lineLimit(1).fixedSize()
            } else {
                Text("—").font(CoverType.serif(18)).foregroundStyle(CoverInk.creamSoft)
                Text(snap.weatherError == nil ? "no weather yet" : "weather offline").font(CoverType.italic(15))
                    .foregroundStyle(CoverInk.creamFaint)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 19)
    }
}

// MARK: - Medium

/// Left half: a small cover (the month, the numeral behind its peak, the weather on the dark strip below). Right
/// half: three tasks set like cover lines, title over due note, on the dark wood of the near firs.
struct CoverDayMedium: View {
    var snap: DaySnapshot
    var rows = 3

    static let body: CGFloat = 13.5
    static let label: CGFloat = 8.5

    var body: some View {
        ZStack(alignment: .topLeading) {
            CoverDayScene(snap: snap, canvas: .dayMedium)
            Text(CoverWords.month(snap.date)).coverCaps(8.5, CoverInk.creamSoft, tracking: 2.2)
                .coverOnSky()
                .padding(.leading, 16)
                .padding(.top, 15)
            CoverWeatherShort(snap: snap, size: 14)
                .fixedSize()
                .coverOnSky(0.9)
                .frame(width: 140, alignment: .leading)
                .frame(width: 348, height: 164 - 16, alignment: .bottomLeading)
                .padding(.leading, 16)
            CoverTaskLines(snap: snap, rows: rows, size: Self.body, label: Self.label)
                .frame(width: 148, height: 132, alignment: .leading)
                .offset(x: 184, y: 16)
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }
}

/// "64° mostly clear" in the serif, for the medium cover's foot.
struct CoverWeatherShort: View {
    var snap: DaySnapshot
    var size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let w = snap.weather {
                Text(CoverWords.temp(w)).font(CoverType.serif(size)).foregroundStyle(CoverInk.cream)
                Text(w.label.lowercased()).font(CoverType.italic(size - 1.5)).foregroundStyle(CoverInk.creamSoft).lineLimit(1)
            } else {
                Text("—").font(CoverType.serif(size)).foregroundStyle(CoverInk.creamSoft)
                Text(snap.weatherError == nil ? "no weather yet" : "weather offline").font(CoverType.italic(size - 1.5))
                    .foregroundStyle(CoverInk.creamFaint).lineLimit(1)
            }
        }
    }
}

/// Tasks as cover lines: the title in the serif (peach when late), its due note beneath in the label face.
struct CoverTaskLines: View {
    var snap: DaySnapshot
    var rows: Int
    var size: CGFloat
    var label: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snap.tasks.isEmpty {
                CoverEmptyTasks(snap: snap, size: size, label: label)
            } else {
                let shown = Array(snap.tasks.prefix(rows))
                ForEach(Array(shown.enumerated()), id: \.offset) { i, t in
                    let late = t.isOverdue(asOf: snap.date)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.text)
                            .font(CoverType.serif(size))
                            .foregroundStyle(late ? CoverInk.peach : CoverInk.cream)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(CoverWords.due(t, now: snap.date) ?? "no date")
                            .coverLabel(label, late ? CoverInk.peach : (t.isDueToday(asOf: snap.date) ? CoverInk.creamSoft : CoverInk.creamFaint))
                            .lineLimit(1)
                    }
                    .padding(.top, i == 0 ? 0 : 7)
                }
                let more = snap.tasks.count - shown.count
                if more > 0 || snap.taskError != nil {
                    HStack(spacing: 6) {
                        if more > 0 { Text(CoverWords.more(more)).coverLabel(label).fixedSize() }
                        if let error = snap.taskError { CoverErrorLine(message: error, size: label, prefix: "cached") }
                    }
                    .lineLimit(1)
                    .padding(.top, 9)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Small

/// The whole tile is the cover: "NOV" and the temperature in the dark upper corners, the numeral from top to foot
/// behind its peak, and the first task across the dark ground.
struct CoverDaySmall: View {
    var snap: DaySnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            CoverDayScene(snap: snap, canvas: .daySmall)
            HStack(alignment: .firstTextBaseline) {
                Text(CoverWords.month(snap.date, short: true)).coverCaps(8.5, CoverInk.creamSoft, tracking: 1.8).coverOnSky()
                Spacer(minLength: 4)
                Text(CoverWords.temp(snap.weather)).font(CoverType.serif(14)).foregroundStyle(CoverInk.cream).coverOnSky()
            }
            .padding(.horizontal, 16)
            .padding(.top, 13)
            CoverSmallTask(snap: snap)
                .frame(width: 132, height: 30, alignment: .bottomLeading)
                .offset(x: 16, y: 164 - 16 - 30)
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }
}

/// The first task in one line (shrinking a touch before it truncates), its due note and the count of the rest.
struct CoverSmallTask: View {
    var snap: DaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let first = snap.tasks.first {
                let late = first.isOverdue(asOf: snap.date)
                Text(first.text)
                    .font(CoverType.serif(13))
                    .foregroundStyle(late ? CoverInk.peach : CoverInk.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .truncationMode(.tail)
                HStack(spacing: 4) {
                    if let error = snap.taskError {
                        CoverErrorLine(message: error, size: 8.5)
                    } else {
                        Text(CoverWords.due(first, now: snap.date) ?? "no date").coverLabel(8.5, late ? CoverInk.peach : CoverInk.creamSoft)
                    }
                    Spacer(minLength: 2)
                    if snap.tasks.count > 1 { Text(CoverWords.more(snap.tasks.count - 1)).coverLabel(8.5).fixedSize() }
                }
                .lineLimit(1)
            } else if let error = snap.taskError {
                Text("Tasks unavailable").font(CoverType.italic(13)).foregroundStyle(CoverInk.peach)
                CoverErrorLine(message: error, size: 8.5)
            } else {
                Text("Nothing due.").font(CoverType.italic(13)).foregroundStyle(CoverInk.creamSoft)
                Text("a clear day").coverLabel(8.5)
            }
        }
        .coverOnPaint(0.6)
    }
}

// MARK: - Pieces

/// The issue line over the cover: small spaced capitals at both ends (or one).
struct CoverDateline: View {
    var left: String
    var right: String?
    var size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(left).coverCaps(size, CoverInk.creamSoft, tracking: 2.4).coverOnSky()
            Spacer(minLength: 8)
            if let right { Text(right).coverCaps(size, CoverInk.creamSoft, tracking: 2.4).coverOnSky() }
        }
    }
}

/// A hairline of cream across (or down) the ground, the rule of an editorial grid.
struct CoverRule: View {
    var vertical = false

    var body: some View {
        let fill = LinearGradient(colors: [CoverInk.cream.opacity(0.05), CoverInk.cream.opacity(0.22), CoverInk.cream.opacity(0.05)],
                                  startPoint: vertical ? .top : .leading, endPoint: vertical ? .bottom : .trailing)
        if vertical {
            Rectangle().fill(fill).frame(width: 0.6).frame(maxHeight: .infinity)
        } else {
            Rectangle().fill(fill).frame(height: 0.6).frame(maxWidth: .infinity)
        }
    }
}

/// The month as dates only (no weekday names), weeks starting on the locale's first day. It stays quiet (faint
/// figures, past days fainter) so only today, circled in cream as in the reference calendar, and the points under
/// days with something due (peach when it was missed) stand out.
struct CoverMonth: View {
    var date: Date
    var tasks: [TaskItem]
    var cell: CGFloat
    var size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(CoverCalendar.weeks(of: date, tasks: tasks).enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        ZStack {
                            if let d = day {
                                if d.today {
                                    Circle()
                                        .fill(RadialGradient(colors: [Color(hex: 0xF7EDDD), CoverInk.cream, Color(hex: 0xDCC8A8)],
                                                             center: UnitPoint(x: 0.4, y: 0.32), startRadius: 0, endRadius: cell * 0.55))
                                        .frame(width: cell - 1, height: cell - 1)
                                        .shadow(color: CoverInk.shadow.opacity(0.5), radius: 1.2, x: 0, y: 0.8)
                                }
                                Text(d.number)
                                    .font(.custom(d.today ? "AvenirNext-DemiBold" : "AvenirNext-Medium", size: size))
                                    .monospacedDigit()
                                    .foregroundStyle(d.today ? CoverInk.umberDeep : (d.past ? CoverInk.creamFaint.opacity(0.5) : CoverInk.creamFaint))
                                if let late = d.due, !d.today {
                                    Circle()
                                        .fill(late ? CoverInk.peach : CoverInk.cream.opacity(0.85))
                                        .frame(width: 2.4, height: 2.4)
                                        .offset(y: cell * 0.5 - 1.2)
                                }
                            }
                        }
                        .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .fixedSize()
    }
}

enum CoverCalendar {
    /// due: nil when nothing is due that day, otherwise whether it was missed (the day is past).
    struct Day { var number: String; var today: Bool; var past: Bool; var due: Bool? }

    static func weeks(of date: Date, tasks: [TaskItem]) -> [[Day?]] {
        let cal = Calendar.current
        guard let month = cal.dateInterval(of: .month, for: date),
              let count = cal.range(of: .day, in: .month, for: date)?.count else { return [] }
        let today = cal.startOfDay(for: date)
        let lead = (cal.component(.weekday, from: month.start) - cal.firstWeekday + 7) % 7
        var cells: [Day?] = Array(repeating: nil, count: lead)
        for i in 0..<count {
            let d = cal.date(byAdding: .day, value: i, to: month.start) ?? month.start
            let due = tasks.contains { t in t.due.map { cal.isDate($0, inSameDayAs: d) } ?? false }
            cells.append(Day(number: String(i + 1), today: cal.isDate(d, inSameDayAs: today), past: d < today,
                             due: due ? (d < today) : nil))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }
}

/// The large cover's task list: titles in the serif (peach when late), due notes in the label face, then the foot:
/// what is left over and the count, or why the list is stale.
struct CoverTaskList: View {
    var snap: DaySnapshot
    var rows: Int
    var size: CGFloat
    var label: CGFloat
    var rowHeight: CGFloat

    private var shown: [TaskItem] { Array(snap.tasks.prefix(rows)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snap.tasks.isEmpty {
                CoverEmptyTasks(snap: snap, size: size + 1, label: label)
                    .padding(.top, 4)
                Spacer(minLength: 0)
            } else {
                ForEach(shown, id: \.id) { t in row(t) }
                Spacer(minLength: 0)
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ t: TaskItem) -> some View {
        let late = t.isOverdue(asOf: snap.date)
        let today = t.isDueToday(asOf: snap.date)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(t.text)
                .font(CoverType.serif(size))
                .foregroundStyle(late ? CoverInk.peach : CoverInk.cream)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: 2)
            if let due = CoverWords.due(t, now: snap.date) {
                Text(due).coverLabel(label, late ? CoverInk.peach : (today ? CoverInk.creamSoft : CoverInk.creamFaint))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(height: rowHeight)
    }

    private var footer: some View {
        let more = snap.tasks.count - shown.count
        return HStack(spacing: 8) {
            if more > 0 { Text(CoverWords.more(more)).coverLabel(label).fixedSize() }
            if let error = snap.taskError {
                // The error takes the count's place, so the reason stays readable ("cached · No GitHub token. Add…").
                CoverErrorLine(message: error, size: label, prefix: "cached").layoutPriority(-1)
            } else {
                Spacer(minLength: 0)
                Text("\(snap.tasks.count) \(snap.tasks.count == 1 ? "task" : "tasks")").coverLabel(label, CoverInk.creamSoft).fixedSize()
            }
        }
        .lineLimit(1)
        .frame(height: 12)
    }
}

/// No tasks: a quiet line, or the reason they could not be fetched.
struct CoverEmptyTasks: View {
    var snap: DaySnapshot
    var size: CGFloat
    var label: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let error = snap.taskError {
                Text("The tasks could not be fetched.").font(CoverType.italic(size)).foregroundStyle(CoverInk.peach)
                    .lineLimit(2)
                CoverErrorLine(message: error, size: label)
            } else {
                Text("Nothing due today.").font(CoverType.italic(size)).foregroundStyle(CoverInk.creamSoft)
                Text("a clear day for the mountains").coverLabel(label)
            }
        }
    }
}

/// A fetch failure, said plainly in peach and cut short with an ellipsis when space runs out.
struct CoverErrorLine: View {
    var message: String
    var size: CGFloat
    var prefix: String? = nil

    var body: some View {
        Text(prefix.map { "\($0) · \(message)" } ?? message)
            .coverLabel(size, CoverInk.peach)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
