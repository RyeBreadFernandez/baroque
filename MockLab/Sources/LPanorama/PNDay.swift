import SwiftUI

// MARK: - Day widget

struct PNDay: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        let s = Mock.size(family)
        let plan = PNPlan.day(family)
        let groundY = (plan.ground * s.height).rounded()
        ZStack(alignment: .topLeading) {
            sky
                .padding(16)
                .frame(width: s.width, alignment: .top)
            if plan.showsTrail {
                PNArcFeet(plan: plan, clock: SkyClock(now: snapshot.date, weather: snapshot.weather),
                          weather: snapshot.weather, fontSize: family == .large ? 11.5 : 10.5)
            }
            ground
                .frame(width: s.width - 32, height: s.height - 16 - groundY, alignment: family == .small ? .leading : .top)
                .offset(x: 16, y: groundY)
        }
        .frame(width: s.width, height: s.height, alignment: .topLeading)
        .background(PNDayGround(snapshot: snapshot, family: family))
    }

    // Written into the sky: the date in the left corner, the weather in the right.
    @ViewBuilder
    private var sky: some View {
        HStack(alignment: .top, spacing: 6) {
            PNDateLine(date: snapshot.date, family: family)
            Spacer(minLength: 0)
            switch family {
            case .small: SkyWeather(weather: snapshot.weather, now: snapshot.date, style: .small)
            default: PNSkyWeather(weather: snapshot.weather, family: family)
            }
        }
    }

    // Written on the valley floor.
    @ViewBuilder
    private var ground: some View {
        switch family {
        case .large:
            PNTaskRun(tasks: snapshot.tasks, error: snapshot.taskError, now: snapshot.date, family: .large)
        case .medium:
            PNTaskRun(tasks: snapshot.tasks, error: snapshot.taskError, now: snapshot.date, family: .medium)
        case .small:
            PNTaskPeek(tasks: snapshot.tasks, error: snapshot.taskError, now: snapshot.date)
        }
    }
}

// MARK: - Sky captions

/// The date as a dateline: a gilt numeral with the weekday, month and year stacked beside it.
/// Small shows the weekday over the numeral.
struct PNDateLine: View {
    var date: Date
    var family: Family

    var body: some View {
        switch family {
        case .large, .medium:
            let large = family == .large
            HStack(alignment: .center, spacing: large ? 8 : 6) {
                numeral(large ? 58 : 40)
                VStack(alignment: .leading, spacing: large ? 1 : 0) {
                    weekday(large ? 11 : 9.5, tracking: large ? 2.4 : 1.6)
                    Text(date, format: .dateTime.month(.wide))
                        .font(Serif.font(large ? 16 : 13, italic: true))
                        .foregroundStyle(Stone.goldMuted)
                        .legible()
                    if large {
                        Text(date, format: .dateTime.year())
                            .font(Serif.font(12, weight: .medium))
                            .foregroundStyle(Stone.goldMuted)
                            .legible()
                    }
                }
                .lineLimit(1)
                .fixedSize()
                .padding(.top, large ? 4 : 1)
            }
        case .small:
            VStack(alignment: .leading, spacing: -2) {
                weekday(9.5, tracking: 1.4)
                numeral(40)
            }
        }
    }

    private func numeral(_ size: CGFloat) -> some View {
        Text(date, format: .dateTime.day())
            .font(Serif.font(size, weight: .medium))
            .foregroundStyle(Gilt.style)
            .legible(1.2)
            .lineLimit(1)
            .fixedSize()
    }

    private func weekday(_ size: CGFloat, tracking: CGFloat) -> some View {
        Text(date, format: .dateTime.weekday(.wide))
            .font(.system(size: size, weight: .bold))
            .tracking(tracking)
            .textCase(.uppercase)
            .foregroundStyle(Stone.copperInk)
            .legible()
            .lineLimit(1)
            .fixedSize()
    }
}

/// Weather kept small in the sky's other corner: glyph and gilt temperature, then the sky's word
/// (large) and the day's high and low.
struct PNSkyWeather: View {
    var weather: WeatherSnapshot?
    var family: Family

    private var temp: String { weather.map { "\(Int($0.temperature.rounded()))°" } ?? "—" }
    private var symbol: String { weather?.symbolName ?? "cloud.fill" }

    var body: some View {
        let large = family == .large
        VStack(alignment: .trailing, spacing: large ? 1 : 0) {
            HStack(alignment: .center, spacing: 4) {
                WeatherGlyph(symbol: symbol, size: large ? 15 : 13)
                Text(temp)
                    .font(Serif.font(large ? 28 : 22, weight: .semibold))
                    .foregroundStyle(Gilt.style)
                    .lineLimit(1)
                    .fixedSize()
            }
            if large || weather == nil {
                Text(weather?.label ?? "Unavailable")
                    .font(Serif.font(large ? 13 : 11.5, weight: .medium, italic: true))
                    .foregroundStyle(Stone.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if let w = weather {
                HighLow(high: w.high, low: w.low, size: large ? 10.5 : 10)
                    .foregroundStyle(Stone.gold)
                    .padding(.top, large ? 1 : 0)
            }
        }
        .legible()
        .frame(maxWidth: large ? 110 : 84, alignment: .trailing)
    }
}

// MARK: - Ground captions

/// Today's tasks written straight onto the valley floor: a carved socket per task, engraved rules between,
/// no slab. Large shows four with a "+N more" line under them; medium shows three with the rest as a copper
/// pebble at the end of the run.
struct PNTaskRun: View {
    var tasks: [TaskItem]
    var error: String?
    var now: Date
    var family: Family

    private var large: Bool { family == .large }
    // A row gives way to the error line when the fetch failed, so cached tasks stay visible above it.
    private var maxRows: Int { large ? 4 : (error == nil ? 3 : 2) }
    private var shown: Int { min(tasks.count, maxRows) }
    private var rest: Int { tasks.count - shown }
    private var rowHeight: CGFloat { large ? 20 : 16 }
    private var gap: CGFloat { large ? 6.5 : 4 }
    private var socket: CGFloat { large ? 14 : 12 }

    var body: some View {
        if tasks.isEmpty {
            PNEmptyGround(error: error, large: large)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(tasks.prefix(shown).enumerated()), id: \.element.id) { i, t in
                    PNTaskLine(task: t, now: now, large: large,
                               trailing: (!large && i == shown - 1 && rest > 0 && error == nil) ? rest : nil)
                        .frame(height: rowHeight)
                        .overlay(alignment: .top) {
                            if i > 0 {
                                EngravedRule()
                                    .padding(.leading, socket + (large ? 9 : 7))
                                    .offset(y: -(gap / 2) - 0.7)
                            }
                        }
                        .padding(.top, i > 0 ? gap : 0)
                }
                if large && (rest > 0 || error != nil) {
                    HStack(spacing: 10) {
                        if rest > 0 {
                            Text("+\(rest) more")
                                .font(Serif.font(12, weight: .medium, italic: true))
                                .foregroundStyle(Stone.goldMuted)
                                .legible()
                                .fixedSize()
                        }
                        if let error {
                            ErrorLine(message: error, prefix: "Cached", color: Stone.copperInk).legible()
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, socket + 9)
                    .padding(.top, 5)
                } else if let error {
                    ErrorLine(message: error, prefix: rest > 0 ? "+\(rest) · Cached" : "Cached", color: Stone.copperInk)
                        .legible()
                        .padding(.leading, socket + 7)
                        .padding(.top, gap)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// One task as a caption: carved socket with its priority gem, the title in parchment, the due day at the end.
struct PNTaskLine: View {
    var task: TaskItem
    var now: Date
    var large: Bool
    /// Medium's last row carries the count of tasks not shown.
    var trailing: Int? = nil

    private var accent: Color {
        if task.isOverdue(asOf: now) { return Stone.copperLight }
        if task.priority >= .high { return Stone.gold }
        return Stone.sage
    }

    private var due: (text: String, late: Bool)? {
        guard let d = task.due else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day ?? 0
        if days < 0 { return ("\(-days)d late", true) }
        if days == 0 { return large ? ("today", false) : nil }
        if days == 1 { return ("tomorrow", false) }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return (f.string(from: d), false)
    }

    var body: some View {
        HStack(spacing: large ? 9 : 7) {
            TaskSocket(accent: accent, size: large ? 14 : 12)
            Text(task.text)
                .font(.system(size: large ? 13.5 : 12, weight: .medium))
                .foregroundStyle(Stone.parchment)
                .legible(0.8)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let due {
                if due.late {
                    Text(due.text)
                        .font(.system(size: large ? 9.5 : 9, weight: .bold))
                        .foregroundStyle(Stone.parchment)
                        .raised()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Pebble(shape: Capsule()))
                        .fixedSize()
                } else {
                    Text(due.text)
                        .font(Serif.font(large ? 12.5 : 11, weight: .medium, italic: true))
                        .foregroundStyle(Stone.goldMuted)
                        .legible()
                        .fixedSize()
                }
            }
            if let trailing {
                PNCountPebble(text: "+\(trailing)")
            }
        }
    }
}

/// A copper pebble with a count, e.g. "+6": the tasks not written out.
struct PNCountPebble: View {
    var text: String
    var size: CGFloat = 11

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Stone.parchment)
            .raised()
            .padding(.horizontal, 6.5)
            .padding(.vertical, 2.5)
            .frame(minWidth: 22)
            .background(Pebble(shape: Capsule()))
            .fixedSize()
            .accessibilityLabel(Text("\(text) more tasks"))
    }
}

/// No tasks (or none and a failed fetch), written on the ground.
struct PNEmptyGround: View {
    var error: String?
    var large: Bool
    var narrow: Bool = false

    private var firstSentence: String? {
        guard let error else { return nil }
        guard let r = error.range(of: ". ") else { return error }
        return String(error[..<r.lowerBound]) + "."
    }

    var body: some View {
        if large {
            VStack(spacing: 7) {
                Image(systemName: error == nil ? "checkmark" : "exclamationmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(error == nil ? Stone.sage : Stone.copperInk)
                    .raised()
                    .frame(width: 32, height: 32)
                    .carved(Circle())
                Text(error == nil ? "Nothing due. Nice." : "Couldn't load tasks")
                    .font(Serif.font(16, weight: .semibold, italic: error == nil))
                    .foregroundStyle(Stone.gold)
                    .legible()
                if let error {
                    Text(error)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Stone.copperInk)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .legible()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: error == nil ? "checkmark" : "exclamationmark")
                        .font(.system(size: 7.5, weight: .heavy))
                        .foregroundStyle(error == nil ? Stone.sage : Stone.copperInk)
                        .frame(width: 13, height: 13)
                        .carved(Circle())
                    Text(error == nil ? "Nothing due. Nice." : "Couldn't load tasks")
                        .font(Serif.font(narrow ? 12 : 13, weight: .semibold, italic: error == nil))
                        .foregroundStyle(error == nil ? Stone.gold : Stone.copperInk)
                        .legible()
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                if let error {
                    // The small widget has room for the first sentence; medium shows the whole message.
                    Text(narrow ? (firstSentence ?? error) : error)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Stone.goldMuted)
                        .lineLimit(2)
                        .legible()
                        .padding(.leading, narrow ? 0 : 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: narrow ? .leading : .topLeading)
            .padding(.top, narrow ? 0 : 4)
        }
    }
}

/// Small widget: the next task written on the ground, with the rest as a copper "+N" pebble.
struct PNTaskPeek: View {
    var tasks: [TaskItem]
    var error: String?
    var now: Date

    var body: some View {
        if let first = tasks.first {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: 6) {
                    TaskSocket(accent: accent(first), size: 12)
                        .padding(.top, 1.5)
                    Text(first.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Stone.parchment)
                        .legible(0.8)
                        .lineLimit(error == nil ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 2)
                    if tasks.count > 1 {
                        PNCountPebble(text: "+\(tasks.count - 1)", size: 10.5)
                    }
                }
                if let error {
                    ErrorLine(message: error, prefix: "Cached", color: Stone.copperInk, fontSize: 9.5)
                        .legible()
                }
            }
        } else {
            PNEmptyGround(error: error, large: false, narrow: true)
        }
    }

    private func accent(_ t: TaskItem) -> Color {
        if t.isOverdue(asOf: now) { return Stone.copperLight }
        if t.priority >= .high { return Stone.gold }
        return Stone.sage
    }
}
