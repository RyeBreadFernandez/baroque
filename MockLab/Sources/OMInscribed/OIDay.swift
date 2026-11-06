import SwiftUI

// The Day widget, inscribed into its painting. No panel: the painting is planned in three values and each carries
// one kind of information.
//   The cloud ceiling (dark)   the date, a large Baskerville numeral with the month in spaced capitals, and opposite
//                              it the weather.
//   The light                  the sun's path engraved as a sundial over the snowy massif: hour ticks, numerals at
//                              the quarters, sunrise and sunset at its feet, the sun glowing where it is now.
//   The ground (dark)          the week along the fir shore, today circled in cream; the tasks on the still lake,
//                              fine serif lines over hairline ripples, due notes at the right, late ones in peach.
// Type sits in the painting's own darks (painted for it in make.py) with Old Master's soft umber halo.

struct OIDay: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .large: OIDayLarge(snap: snapshot)
        case .medium: OIDayMedium(snap: snapshot)
        case .small: OIDaySmall(snap: snapshot)
        }
    }
}

/// The painting for a snapshot, with its dial.
struct OIDayPainting: View {
    var snap: DaySnapshot
    var canvas: OICanvas
    var numerals: Bool
    var feet: Bool
    var tick: CGFloat

    var body: some View {
        OIPainting(canvas: canvas,
                   clock: SkyClock(now: snap.date, weather: snap.weather),
                   condition: SkyCondition(code: snap.weather?.code),
                   phase: MoonPhase(date: snap.date),
                   dial: OIDial(now: snap.date, weather: snap.weather, numerals: numerals, feet: feet, tick: tick))
    }
}

// MARK: - Large

struct OIDayLarge: View {
    var snap: DaySnapshot

    static let body: CGFloat = 15
    static let label: CGFloat = 9.5

    var body: some View {
        ZStack(alignment: .top) {
            OIDayPainting(snap: snap, canvas: .dayLarge, numerals: true, feet: true, tick: 3.2)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    OIDateBlock(date: snap.date, numeral: 60, month: 10.5, year: 8.5, width: 196)
                    Spacer(minLength: 8)
                    OIWeatherBlock(snap: snap, temp: 28, condition: 13.5, label: Self.label, detail: true)
                        .padding(.top, 3)
                }
                .frame(height: 62, alignment: .top)
                .padding(.top, 10)
                Color.clear.frame(height: 100)
                OIWeekRow(date: snap.date, tasks: snap.tasks, size: 13.5, circle: 22)
                    .frame(height: 24)
                Color.clear.frame(height: 14)
                OITaskList(snap: snap, rows: 5, size: Self.body, label: Self.label, rowHeight: 22.5, count: true)
                    .frame(height: 139)
            }
            .padding(.horizontal, 16)
        }
    }
}

/// The date in the ceiling: the day's numeral, the month in spaced capitals beside it and the year in Roman
/// numerals under the month. Within `width` it spells the month out when it fits and shortens it ("SEP") when it
/// would reach the dial.
struct OIDateBlock: View {
    var date: Date
    var numeral: CGFloat
    var month: CGFloat
    var year: CGFloat?
    var width: CGFloat

    var body: some View {
        ViewThatFits(in: .horizontal) {
            block(OMWords.month(date))
            block(OMWords.month(date, short: true))
        }
        .frame(width: width, alignment: .leading)
        .omOnPaint()
    }

    private func block(_ name: String) -> some View {
        HStack(alignment: .center, spacing: numeral * 0.14) {
            Text(OMWords.day(date))
                .font(OMType.numeral(numeral))
                .foregroundStyle(OMInk.cream)
            VStack(alignment: .leading, spacing: month * 0.3) {
                Text(name).omCaps(month, OMInk.cream, tracking: month * 0.26)
                if let year {
                    Text(OMWords.roman(date)).omCaps(year, OMInk.creamFaint, tracking: year * 0.24)
                }
            }
            .padding(.top, numeral * 0.08)
        }
        .fixedSize()
    }
}

/// The weather opposite the date: the temperature large in the serif, the condition in italic, then the high and
/// low. Offline it says so.
struct OIWeatherBlock: View {
    var snap: DaySnapshot
    var temp: CGFloat
    var condition: CGFloat
    var label: CGFloat
    var detail: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if let w = snap.weather {
                Text(OMWords.temp(w)).font(OMType.serif(temp)).foregroundStyle(OMInk.cream)
                Text(detail ? w.label : w.label.lowercased())
                    .font(detail ? OMType.italic(condition) : OMType.label(condition))
                    .foregroundStyle(OMInk.creamSoft)
                    .lineLimit(1)
                if detail {
                    Text("H \(Int(w.high.rounded()))  ·  L \(Int(w.low.rounded()))").omLabel(label).lineLimit(1)
                        .padding(.top, 2)
                }
            } else {
                Text("—").font(OMType.serif(temp)).foregroundStyle(OMInk.creamSoft)
                Text(snap.weatherError == nil ? "no weather yet" : "weather offline").omLabel(label, OMInk.peach).lineLimit(1)
            }
        }
        .omOnPaint()
    }
}

// MARK: - Medium

struct OIDayMedium: View {
    var snap: DaySnapshot

    static let body: CGFloat = 13.5
    static let label: CGFloat = 9

    var body: some View {
        ZStack(alignment: .top) {
            OIDayPainting(snap: snap, canvas: .dayMedium, numerals: false, feet: false, tick: 2.6)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 6) {
                    OIDateBlock(date: snap.date, numeral: 38, month: 9, year: nil, width: 106)
                    Spacer(minLength: 6)
                    OIWeatherBlock(snap: snap, temp: 21, condition: 9.5, label: Self.label, detail: false)
                        .padding(.top, 2)
                }
                .frame(height: 46, alignment: .top)
                .padding(.top, 6)
                Color.clear.frame(height: 24)
                OITaskList(snap: snap, rows: 3, size: Self.body, label: Self.label, rowHeight: 18.5, count: false)
                    .frame(height: 72)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Small

struct OIDaySmall: View {
    var snap: DaySnapshot

    var body: some View {
        ZStack(alignment: .top) {
            OIDayPainting(snap: snap, canvas: .daySmall, numerals: false, feet: false, tick: 2.2)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 4) {
                    VStack(alignment: .leading, spacing: -4) {
                        Text(OMWords.day(snap.date)).font(OMType.numeral(38)).foregroundStyle(OMInk.cream)
                        Text(OMWords.month(snap.date, short: true)).omCaps(8.5, OMInk.cream, tracking: 2)
                            .padding(.leading, 2)
                    }
                    .fixedSize()
                    Spacer(minLength: 4)
                    Text(OMWords.temp(snap.weather))
                        .font(OMType.serif(19))
                        .foregroundStyle(snap.weather == nil ? OMInk.creamSoft : OMInk.cream)
                        .padding(.top, 4)
                }
                .omOnPaint()
                .padding(.top, 6)
                Spacer(minLength: 0)
                OISmallTask(snap: snap)
                    .frame(height: 50, alignment: .bottomLeading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }
}

/// The small widget's one task: up to two lines of title, then its due date and how many more there are.
struct OISmallTask: View {
    var snap: DaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let first = snap.tasks.first {
                let late = first.isOverdue(asOf: snap.date)
                Text(first.text)
                    .font(OMType.serif(14))
                    .foregroundStyle(late ? OMInk.peach : OMInk.cream)
                    .lineLimit(2)
                    .lineSpacing(-1.5)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    if let error = snap.taskError {
                        OIErrorLine(message: error, size: 8.5).layoutPriority(-1)
                    } else if let due = Mock.dueLabel(first, now: snap.date) {
                        Text(due).omLabel(8.5, late ? OMInk.peach : OMInk.creamSoft)
                    }
                    Spacer(minLength: 2)
                    if snap.tasks.count > 1 { Text(OMWords.more(snap.tasks.count - 1)).omLabel(8.5, OMInk.creamSoft) }
                }
                .lineLimit(1)
            } else if let error = snap.taskError {
                Text("Tasks unavailable").font(OMType.italic(14)).foregroundStyle(OMInk.peach)
                OIErrorLine(message: error, size: 8.5)
            } else {
                Text("Nothing due.").font(OMType.italic(14)).foregroundStyle(OMInk.creamSoft)
                Text("a clear day").omLabel(8.5, OMInk.creamSoft)
            }
        }
        .omOnPaint()
    }
}

// MARK: - Pieces

/// The week along the fir shore: dates only, Monday first, no weekday names. Today sits in a cream disc, past days
/// fade, and a peach point marks a later day with something due.
struct OIWeekRow: View {
    var date: Date
    var tasks: [TaskItem]
    var size: CGFloat
    var circle: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(OIWeek.days(of: date, tasks: tasks).enumerated()), id: \.offset) { _, d in
                ZStack {
                    if d.today {
                        Circle()
                            .fill(RadialGradient(colors: [Color(hex: 0xF7EDDD), OMInk.cream, Color(hex: 0xDDC9AA)],
                                                 center: UnitPoint(x: 0.4, y: 0.32), startRadius: 0, endRadius: circle * 0.6))
                            .frame(width: circle, height: circle)
                            .shadow(color: OMInk.shadow.opacity(0.55), radius: 2, x: 0, y: 1)
                    }
                    Text(d.number)
                        .font(OMType.serif(size))
                        .monospacedDigit()
                        .foregroundStyle(d.today ? OMInk.umberDeep : (d.past ? OMInk.creamFaint : OMInk.cream))
                        .omOnPaint(d.today ? 0 : 1)
                    if d.due && !d.today {
                        Circle().fill(OMInk.peach).frame(width: 3, height: 3).offset(y: circle * 0.5 + 0.5)
                            .shadow(color: OMInk.shadow.opacity(0.6), radius: 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: circle)
            }
        }
    }
}

enum OIWeek {
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

/// The tasks lettered on the still water: titles in the serif (peach when late), due notes in the label face at the
/// right, a hairline ripple under each line, then a foot with what is left over and the count, or why the list is
/// stale.
struct OITaskList: View {
    var snap: DaySnapshot
    var rows: Int
    var size: CGFloat
    var label: CGFloat
    var rowHeight: CGFloat
    var count: Bool

    private var shown: [TaskItem] { Array(snap.tasks.prefix(rows)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snap.tasks.isEmpty {
                empty
            } else {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, t in
                    row(t)
                        .overlay(alignment: .bottom) {
                            if i < shown.count - 1 { OIRipple() }
                        }
                }
                Spacer(minLength: 0)
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .omOnPaint()
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
                Text(due).omLabel(label, late ? OMInk.peach : (today ? OMInk.cream : OMInk.creamSoft))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(height: rowHeight)
    }

    @ViewBuilder
    private var footer: some View {
        let more = snap.tasks.count - shown.count
        if more > 0 || snap.taskError != nil || count {
            HStack(spacing: 8) {
                if more > 0 { Text(OMWords.more(more)).omLabel(label, OMInk.creamSoft).fixedSize() }
                if let error = snap.taskError {
                    OIErrorLine(message: error, size: label, prefix: "cached").layoutPriority(-1)
                }
                Spacer(minLength: 0)
                if count {
                    Text("\(snap.tasks.count) \(snap.tasks.count == 1 ? "task" : "tasks")").omLabel(label, OMInk.creamSoft).fixedSize()
                }
            }
            .lineLimit(1)
            .frame(height: 13)
        }
    }

    @ViewBuilder
    private var empty: some View {
        VStack(alignment: .center, spacing: 5) {
            if let error = snap.taskError {
                Text("The tasks could not be fetched.").font(OMType.italic(size + 1)).foregroundStyle(OMInk.peach)
                OIErrorLine(message: error, size: label)
            } else {
                Text("Nothing due today.").font(OMType.italic(size + 1)).foregroundStyle(OMInk.cream)
                Text("a still day on the water").omLabel(label, OMInk.creamSoft)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

/// A hairline ripple on the water under a task: cream, fading out at both ends.
struct OIRipple: View {
    var body: some View {
        LinearGradient(stops: [.init(color: OMInk.cream.opacity(0), location: 0),
                               .init(color: OMInk.cream.opacity(0.2), location: 0.18),
                               .init(color: OMInk.cream.opacity(0.2), location: 0.82),
                               .init(color: OMInk.cream.opacity(0), location: 1)],
                       startPoint: .leading, endPoint: .trailing)
            .frame(height: 0.6)
    }
}

/// A fetch failure, said plainly in peach and cut short with an ellipsis when space runs out.
struct OIErrorLine: View {
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
