import SwiftUI

// Grand Hotel Spare: each widget is two things, the painted scene and one raised slab. No frame but the widget's own
// edge, no props, no second container. The date and the weather are type on the sky, set in two centred columns that
// flank the hotel (a strict three-column grid: date, hotel, weather), and the week, the tasks and the count are type
// on the slab. Three text sizes at most (numerals, body, and one caps size) and one accent, raspberry, besides gold
// leaf and ink.

enum GCSpareInk {
    static let body = GH.espresso
    static let soft = GH.inkSoft
    static let accent = GH.raspberry
}

struct GCSpareDay: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .large: GCSpareDayLarge(snap: snapshot)
        case .medium: GCSpareDayMedium(snap: snapshot)
        case .small: GCSpareDaySmall(snap: snapshot)
        }
    }
}

struct GCSpareQuote: View {
    var quote: Quote
    var family: Family
    var now: Date = Mock.now

    var body: some View {
        switch family {
        case .large: GCSpareQuoteLarge(quote: quote, now: now)
        case .medium: GCSpareQuoteMedium(quote: quote, now: now)
        case .small: GCSpareQuoteSmall(quote: quote, now: now)
        }
    }
}

// MARK: - Type on the sky

/// A centred column of type on the sky: a gilt numeral over one or two lines of capitals.
struct GCSpareColumn: View {
    var numeral: String
    var size: CGFloat
    var lines: [String]

    var body: some View {
        VStack(spacing: 3) {
            GCNumeral(text: numeral, size: size)
                .padding(.bottom, -size * 0.16)
            ForEach(Array(lines.enumerated()), id: \.offset) { i, s in
                Text(s).gcSkyCaps(tracking: i == 0 ? 1.6 : 1.1, medium: i > 0)
            }
        }
    }
}

// MARK: - The week, as type

/// The week set across the top of the slab in the body serif: today in raspberry with a short rule under it, past
/// days in soft ink, and a small ink dot under any other day with something due.
struct GCSpareWeek: View {
    var date: Date
    var tasks: [TaskItem]
    var size: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(GCWeek.days(of: date, tasks: tasks).enumerated()), id: \.offset) { _, d in
                VStack(spacing: 2.5) {
                    Text(d.number)
                        .font(Serif.font(size, weight: d.today ? .bold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(d.today ? GCSpareInk.accent : (d.past ? GCSpareInk.soft.opacity(0.7) : GCSpareInk.body))
                        .ghPressed()
                    ZStack {
                        if d.today {
                            Capsule().fill(GCSpareInk.accent).frame(width: 14, height: 1.6)
                        } else if d.due {
                            Circle().fill(GCSpareInk.soft).frame(width: 3, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - The slab

/// The one slab of a Day widget: on large the week across the top, then the tasks on hairline rules, due dates in
/// plain capitals (raspberry when late), and a foot line with the remainder and the count.
struct GCSpareRegister: View {
    var snap: DaySnapshot
    var family: Family

    private var tasks: [TaskItem] { snap.tasks }
    private var now: Date { snap.date }
    private var maxRows: Int { family == .large ? 5 : (family == .medium ? 3 : 1) }
    private var shown: Int { min(tasks.count, maxRows) }
    private var body_: CGFloat { family == .large ? 13.5 : (family == .medium ? 13 : 12.5) }
    private var rowHeight: CGFloat { family == .large ? 20.5 : 17 }

    var body: some View {
        VStack(spacing: 0) {
            if family == .large {
                GCSpareWeek(date: snap.date, tasks: tasks, size: body_)
                    .padding(.bottom, 5)
                GHRule(color: GH.plum).padding(.bottom, 2)
            }
            if tasks.isEmpty {
                empty.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if family == .small {
                small
            } else {
                rows
                Spacer(minLength: 0)
                footer
            }
        }
        .padding(.horizontal, family == .small ? 10 : 13)
        .padding(.top, family == .large ? 9 : (family == .small ? 8 : 6))
        .padding(.bottom, family == .small ? 6 : 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .gcSlab(radius: family == .small ? 11 : 13, depth: family == .small ? 2.5 : 3)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.prefix(shown).enumerated()), id: \.element.id) { i, t in
                HStack(spacing: 8) {
                    Text(t.text)
                        .font(Serif.font(body_, weight: .medium))
                        .foregroundStyle(GCSpareInk.body)
                        .ghPressed()
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    Spacer(minLength: 6)
                    GCDue(task: t, now: now, todayInk: GCSpareInk.body)
                }
                .frame(height: rowHeight)
                .overlay(alignment: .bottom) {
                    if i < shown - 1 { GHRule(color: GH.plum).opacity(0.6) }
                }
            }
        }
    }

    /// "+ 2 MORE" on the left, the count on the right (large); the remainder alone on medium.
    @ViewBuilder
    private var footer: some View {
        let more = tasks.count - shown
        if more > 0 || snap.taskError != nil || family == .large {
            HStack(spacing: 8) {
                if more > 0 {
                    Text(GCWords.more(more)).gcCardCaps(GCSpareInk.soft, tracking: snap.taskError == nil ? 1.6 : 1)
                }
                if let error = snap.taskError {
                    // A stale cache says why; it shortens itself before the remainder or the count give way.
                    GCErrorLine(message: error, prefix: "Cached").layoutPriority(-1)
                }
                Spacer(minLength: 0)
                if family == .large {
                    Text("\(tasks.count) \(tasks.count == 1 ? "TASK" : "TASKS")").gcCardCaps(GCSpareInk.body, tracking: 1.6)
                }
            }
            .frame(height: 12)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = tasks.first {
                Text(first.text)
                    .font(Serif.font(body_, weight: .medium))
                    .foregroundStyle(GCSpareInk.body)
                    .ghPressed()
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 2)
                HStack(spacing: 4) {
                    if let error = snap.taskError {
                        GCErrorLine(message: error, short: "Sync failed").layoutPriority(-1)
                    } else {
                        GCDue(task: first, now: now, todayInk: GCSpareInk.body)
                    }
                    Spacer(minLength: 2)
                    if tasks.count > 1 { Text(GCWords.more(tasks.count - 1)).gcCardCaps(GCSpareInk.soft, tracking: 1) }
                }
                .frame(height: 11)
            }
        }
    }

    @ViewBuilder
    private var empty: some View {
        let failed = snap.taskError != nil
        VStack(spacing: family == .large ? 5 : 3) {
            Text(failed ? "Couldn't load tasks" : "Nothing due. Nice.")
                .font(Serif.font(body_, weight: .semibold))
                .foregroundStyle(failed ? GCSpareInk.accent : GCSpareInk.body)
                .ghPressed()
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            if let error = snap.taskError {
                Text((family == .small ? GCWords.firstSentence(error) : error).uppercased())
                    .font(GHFont.capsMedium(GCSize.caps))
                    .tracking(0.6)
                    .foregroundStyle(GCSpareInk.soft)
                    .multilineTextAlignment(.center)
                    .lineLimit(family == .large ? 3 : 2)
                    .ghPressed()
            } else {
                Text("EVERY KEY ON ITS HOOK").gcCardCaps(GCSpareInk.soft, tracking: 1.4, medium: true)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Day widgets

struct GCSpareDayLarge: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.large)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.dayLarge(snap, hotelBase: 0.37, hotelWidth: 106, ledgeBottom: 0.52, lift: 0.01, trail: false))
                .frame(width: s.width, height: s.height)
            GCSpareColumn(numeral: GHDates.string(snap.date, "d"), size: 46,
                          lines: [GCWords.month(snap.date)] + (GCWords.sun(snap).map { [$0] } ?? []))
                .frame(width: 104).position(x: 66, y: 66)
            GCSpareColumn(numeral: GCWords.temp(snap), size: 46, lines: [GCWords.condition(snap), GCWords.highLow(snap)])
                .frame(width: 104).position(x: 282, y: 66)
            GCSpareRegister(snap: snap, family: .large).ghPlace(14, 184, 320, 167)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

struct GCSpareDayMedium: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.medium)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.dayMedium(snap, hotelBase: 0.44, hotelWidth: 74))
                .frame(width: s.width, height: s.height)
            GCSpareColumn(numeral: GHDates.string(snap.date, "d"), size: 32, lines: [GCWords.month(snap.date)])
                .frame(width: 104).position(x: 66, y: 38)
            GCSpareColumn(numeral: GCWords.temp(snap), size: 32, lines: [snap.weather == nil ? GCWords.highLow(snap) : GCWords.condition(snap)])
                .frame(width: 104).position(x: 282, y: 38)
            GCSpareRegister(snap: snap, family: .medium).ghPlace(14, 76, 320, 74)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

struct GCSpareDaySmall: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.small)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.daySmall(snap, hotelBase: 0.565, hotelWidth: 44))
                .frame(width: s.width, height: s.height)
            GCSpareColumn(numeral: GHDates.string(snap.date, "d"), size: 30, lines: [GCWords.month(snap.date, short: true)])
                .frame(width: 60).position(x: 42, y: 36)
            GCSpareColumn(numeral: GCWords.temp(snap), size: 30, lines: [])
                .frame(width: 60).position(x: 122, y: 30)
            GCSpareRegister(snap: snap, family: .small).ghPlace(12, 96, 140, 56)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

// MARK: - Quote widgets

struct GCSpareQuoteLarge: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let s = Mock.size(.large)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.quote(now, family: .large, hotelBase: 0.40, hotelWidth: 124))
                .frame(width: s.width, height: s.height)
            GCQuoteCard(quote: quote, sizes: [18, 17, 16, 15, 14, 13, 12], button: true,
                        padding: EdgeInsets(top: 18, leading: 20, bottom: 14, trailing: 20), radius: 13)
                .ghPlace(14, 190, 320, 161)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

struct GCSpareQuoteMedium: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let s = Mock.size(.medium)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.quote(now, family: .medium, hotelBase: 0.335, hotelWidth: 56))
                .frame(width: s.width, height: s.height)
            GCQuoteCard(quote: quote, sizes: [14, 13, 12, 11.5, 11], button: true,
                        padding: EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14), radius: 12)
                .ghPlace(14, 57, 320, 93)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

struct GCSpareQuoteSmall: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let s = Mock.size(.small)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.quote(now, family: .small, hotelBase: 0.37, hotelWidth: 52))
                .frame(width: s.width, height: s.height)
            GCQuoteCard(quote: quote, sizes: [14, 13, 12, 11, 10.5], button: false,
                        padding: EdgeInsets(top: 8, leading: 9, bottom: 8, trailing: 9), radius: 11)
                .ghPlace(12, 66, 140, 86)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}
