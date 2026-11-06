import SwiftUI

// The Day widget: two things only, the painting and one umber panel. The date leads (the display numeral, then the
// month and the year in Roman numerals), the weather sits opposite it, and the tasks follow in the body serif with
// their due dates in the small label face. Peach marks today and anything late. Three type sizes per widget.

struct OMDay: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .large: OMDayLarge(snap: snapshot)
        case .medium: OMDayMedium(snap: snapshot)
        case .small: OMDaySmall(snap: snapshot)
        }
    }
}

/// The painting for a snapshot: the clock and weather it shows.
struct OMDayPainting: View {
    var snap: DaySnapshot
    var canvas: OMCanvas

    var body: some View {
        OMPainting(canvas: canvas,
                   clock: SkyClock(now: snap.date, weather: snap.weather),
                   condition: SkyCondition(code: snap.weather?.code),
                   phase: MoonPhase(date: snap.date))
    }
}

// MARK: - Large

/// The painting fills the widget; the panel rests on its lower two thirds, leaving the sky, the cloud and the peaks
/// open above it.
struct OMDayLarge: View {
    var snap: DaySnapshot

    static let numeral: CGFloat = 40
    static let body: CGFloat = 14.5
    static let label: CGFloat = 9.5

    var body: some View {
        ZStack(alignment: .bottom) {
            OMDayPainting(snap: snap, canvas: .dayLarge)
            VStack(alignment: .leading, spacing: 0) {
                header
                OMWeekRow(date: snap.date, tasks: snap.tasks, size: Self.body, circle: 25)
                    .padding(.top, 7)
                OMTaskList(snap: snap, rows: 5, size: Self.body, label: Self.label, rowHeight: 21)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 14)
            .padding(.top, 9)
            .padding(.bottom, 10)
            .frame(width: 328, height: 234, alignment: .top)
            .omPanel(radius: 13)
            .padding(10)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 9) {
            Text(OMWords.day(snap.date))
                .font(OMType.numeral(Self.numeral))
                .foregroundStyle(OMInk.cream)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(OMWords.month(snap.date)).font(OMType.serif(Self.body)).foregroundStyle(OMInk.cream)
                Text(OMWords.roman(snap.date)).omCaps(Self.label, tracking: 1.8)
            }
            Spacer(minLength: 8)
            OMWeatherBlock(snap: snap, size: Self.body, label: Self.label, detail: true)
        }
        .frame(height: 46)
    }
}

/// The weather opposite the date: temperature and condition in the body serif, then the high, low and the next
/// sunrise or sunset in the label face. Offline it says so.
struct OMWeatherBlock: View {
    var snap: DaySnapshot
    var size: CGFloat
    var label: CGFloat
    var detail: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 2.5) {
            if let w = snap.weather {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(OMWords.temp(w)).font(OMType.serif(size)).foregroundStyle(OMInk.cream)
                    if detail {
                        Text(w.label).font(OMType.italic(size)).foregroundStyle(OMInk.creamSoft).lineLimit(1)
                    }
                }
                if detail {
                    let parts = ["H \(Int(w.high.rounded()))  L \(Int(w.low.rounded()))", OMWords.sunEvent(w, now: snap.date)].compactMap { $0 }
                    Text(parts.joined(separator: "  ·  ")).omLabel(label).lineLimit(1)
                } else {
                    Text(w.label.lowercased()).omLabel(label).lineLimit(1)
                }
            } else {
                Text("—").font(OMType.serif(size)).foregroundStyle(OMInk.creamSoft)
                Text(snap.weatherError == nil ? "no weather yet" : "weather offline").omLabel(label).lineLimit(1)
            }
        }
    }
}

// MARK: - Medium

/// The painting shows on the left as a narrow upright picture; the panel on the right holds the date, the
/// temperature and three tasks.
struct OMDayMedium: View {
    var snap: DaySnapshot

    static let numeral: CGFloat = 32
    static let body: CGFloat = 13.5
    static let label: CGFloat = 9

    var body: some View {
        ZStack(alignment: .trailing) {
            OMDayPainting(snap: snap, canvas: .dayMedium)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 7) {
                    Text(OMWords.day(snap.date))
                        .font(OMType.numeral(Self.numeral))
                        .foregroundStyle(OMInk.cream)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(OMWords.month(snap.date)).font(OMType.serif(Self.body)).foregroundStyle(OMInk.cream)
                        Text(OMWords.roman(snap.date)).omCaps(Self.label, tracking: 1.6)
                    }
                    Spacer(minLength: 6)
                    OMWeatherBlock(snap: snap, size: Self.body, label: Self.label, detail: false)
                }
                .frame(height: 36)
                OMTaskList(snap: snap, rows: 3, size: Self.body, label: Self.label, rowHeight: 21)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 9)
            .frame(width: 222, height: 144, alignment: .top)
            .omPanel(radius: 12)
            .padding(10)
        }
    }
}

// MARK: - Small

/// The date and the temperature on the painting's dark upper corners; one task on a small panel below.
struct OMDaySmall: View {
    var snap: DaySnapshot

    static let numeral: CGFloat = 34
    static let body: CGFloat = 14
    static let label: CGFloat = 8.5

    var body: some View {
        ZStack {
            OMDayPainting(snap: snap, canvas: .daySmall)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 4) {
                    VStack(alignment: .leading, spacing: -3) {
                        Text(OMWords.day(snap.date)).font(OMType.numeral(Self.numeral)).foregroundStyle(OMInk.cream)
                        Text(OMWords.month(snap.date, short: true)).omCaps(Self.label, OMInk.creamSoft, tracking: 1.6)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(OMWords.temp(snap.weather)).font(OMType.serif(Self.body)).foregroundStyle(OMInk.cream)
                        Text(snap.weather.map { $0.label.lowercased() } ?? "offline").omLabel(Self.label, OMInk.creamSoft).lineLimit(1)
                    }
                    .padding(.top, 6)
                }
                .omOnPaint()
                .padding(.horizontal, 16)
                .padding(.top, 10)
                Spacer(minLength: 0)
                OMSmallTask(snap: snap, size: Self.body, label: Self.label)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(width: 148, height: 64, alignment: .topLeading)
                    .omPanel(radius: 13)
                    .padding(8)
            }
        }
    }
}

/// The small widget's one task: two lines of title, then its due date and the count of the rest.
struct OMSmallTask: View {
    var snap: DaySnapshot
    var size: CGFloat
    var label: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = snap.tasks.first {
                let late = first.isOverdue(asOf: snap.date)
                Text(first.text)
                    .font(OMType.serif(size))
                    .foregroundStyle(late ? OMInk.peach : OMInk.cream)
                    .lineLimit(2)
                    .lineSpacing(-1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 2)
                HStack(spacing: 4) {
                    if let error = snap.taskError {
                        OMErrorLine(message: error, size: label).layoutPriority(-1)
                    } else if let due = Mock.dueLabel(first, now: snap.date) {
                        Text(due).omLabel(label, late ? OMInk.peach : OMInk.creamSoft)
                    }
                    Spacer(minLength: 2)
                    if snap.tasks.count > 1 { Text(OMWords.more(snap.tasks.count - 1)).omLabel(label) }
                }
                .lineLimit(1)
            } else if let error = snap.taskError {
                Text("Tasks unavailable").font(OMType.italic(size)).foregroundStyle(OMInk.peach)
                Spacer(minLength: 2)
                OMErrorLine(message: error, size: label)
            } else {
                Text("Nothing due.").font(OMType.italic(size)).foregroundStyle(OMInk.creamSoft)
                Spacer(minLength: 2)
                Text("a clear day").omLabel(label)
            }
        }
    }
}

// MARK: - Pieces

/// One week as dates, Monday first, no weekday names: today circled in cream as in the reference calendar, past days
/// faded, and a peach point under any later day with something due.
struct OMWeekRow: View {
    var date: Date
    var tasks: [TaskItem]
    var size: CGFloat
    var circle: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(OMWeek.days(of: date, tasks: tasks).enumerated()), id: \.offset) { _, d in
                ZStack {
                    if d.today {
                        Circle()
                            .fill(RadialGradient(colors: [Color(hex: 0xF7EDDD), OMInk.cream, Color(hex: 0xDDC9AA)],
                                                 center: UnitPoint(x: 0.4, y: 0.32), startRadius: 0, endRadius: circle * 0.6))
                            .frame(width: circle, height: circle)
                            .shadow(color: OMInk.shadow.opacity(0.4), radius: 1.5, x: 0, y: 1)
                    }
                    Text(d.number)
                        .font(OMType.serif(size))
                        .monospacedDigit()
                        .foregroundStyle(d.today ? OMInk.umberDeep : (d.past ? OMInk.creamFaint.opacity(0.8) : OMInk.creamSoft))
                    if d.due && !d.today {
                        Circle().fill(OMInk.peach.opacity(0.85)).frame(width: 2.6, height: 2.6).offset(y: circle * 0.5 - 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: circle)
            }
        }
    }
}

enum OMWeek {
    struct Day { var number: String; var today: Bool; var past: Bool; var due: Bool }

    static func days(of date: Date, tasks: [TaskItem]) -> [Day] {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
        let today = cal.startOfDay(for: date)
        return (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i, to: start) ?? start
            let due = tasks.contains { t in t.due.map { cal.isDate($0, inSameDayAs: d) } ?? false }
            return Day(number: String(cal.component(.day, from: d)), today: cal.isDate(d, inSameDayAs: today),
                       past: d < today, due: due && d > today)
        }
    }
}

/// The task list on a panel: titles in the body serif (peach when late), due dates in the label face, then a foot
/// line with what is left over, the count, or why the list is stale.
struct OMTaskList: View {
    var snap: DaySnapshot
    var rows: Int
    var size: CGFloat
    var label: CGFloat
    var rowHeight: CGFloat

    private var shown: [TaskItem] { Array(snap.tasks.prefix(rows)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snap.tasks.isEmpty {
                empty
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
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(t.text)
                .font(OMType.serif(size))
                .foregroundStyle(late ? OMInk.peach : OMInk.cream)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: 4)
            if let due = Mock.dueLabel(t, now: snap.date) {
                Text(due).omLabel(label, late ? OMInk.peach : (today ? OMInk.creamSoft : OMInk.creamFaint))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(height: rowHeight)
    }

    @ViewBuilder
    private var footer: some View {
        let more = snap.tasks.count - shown.count
        if more > 0 || snap.taskError != nil || rows >= 5 {
            HStack(spacing: 8) {
                if more > 0 { Text(OMWords.more(more)).omLabel(label).fixedSize() }
                if let error = snap.taskError {
                    OMErrorLine(message: error, size: label, prefix: "cached").layoutPriority(-1)
                }
                Spacer(minLength: 0)
                if rows >= 5 {
                    Text("\(snap.tasks.count) \(snap.tasks.count == 1 ? "task" : "tasks")").omLabel(label, OMInk.creamSoft).fixedSize()
                }
            }
            .lineLimit(1)
            .frame(height: 12)
        }
    }

    @ViewBuilder
    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let error = snap.taskError {
                Text("The tasks could not be fetched.").font(OMType.italic(size)).foregroundStyle(OMInk.peach)
                OMErrorLine(message: error, size: label)
            } else {
                Text("Nothing due today.").font(OMType.italic(size)).foregroundStyle(OMInk.creamSoft)
                Text("a clear day for the mountains").omLabel(label)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// A fetch failure, said plainly in peach and cut short with an ellipsis when space runs out.
struct OMErrorLine: View {
    var message: String
    var size: CGFloat
    var prefix: String? = nil

    var body: some View {
        Text(prefix.map { "\($0) · \(message)" } ?? message)
            .omLabel(size, OMInk.peach)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
