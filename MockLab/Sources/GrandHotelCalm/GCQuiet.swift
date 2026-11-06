import SwiftUI

// Grand Hotel Quiet: Grand Hotel's arrangement with the ornament taken away. The scene is still on top and the
// register below, the quotes still on cards, but each widget keeps one frame (a slim velvet valance, no tassels, no
// crest), the date and weather are gilt numerals and spaced capitals on the painted sky, the week is one carved
// channel, and the register is one quiet slab with hairline rules.

struct GCQuietDay: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .large: GCQuietDayLarge(snap: snapshot)
        case .medium: GCQuietDayMedium(snap: snapshot)
        case .small: GCQuietDaySmall(snap: snapshot)
        }
    }
}

struct GCQuietQuote: View {
    var quote: Quote
    var family: Family
    var now: Date = Mock.now

    var body: some View {
        switch family {
        case .large: GCQuietQuoteLarge(quote: quote, now: now)
        case .medium: GCQuietQuoteMedium(quote: quote, now: now)
        case .small: GCQuietQuoteSmall(quote: quote, now: now)
        }
    }
}

/// The one frame: a slim velvet valance on its gilt rod.
struct GCQuietValance: View {
    var family: Family

    var body: some View {
        let w = Mock.size(family).width
        switch family {
        case .large: GHValance(depth: 12, scallops: 9, tassels: false, crest: false, braid: false).ghPlace(0, 0, w, 20)
        case .medium: GHValance(depth: 10, scallops: 11, tassels: false, crest: false, braid: false).ghPlace(0, 0, w, 18)
        case .small: GHValance(depth: 9, scallops: 5, tassels: false, crest: false, braid: false).ghPlace(0, 0, w, 17)
        }
    }
}

// MARK: - The date and the weather, on the sky

/// "3" over "NOVEMBER" (and the next sunrise or sunset on large), left aligned.
struct GCQuietDate: View {
    var snap: DaySnapshot
    var numeral: CGFloat
    var shortMonth = false
    var showsSun = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GCNumeral(text: GHDates.string(snap.date, "d"), size: numeral)
                .padding(.bottom, -numeral * 0.16)
            Text(GCWords.month(snap.date, short: shortMonth)).gcSkyCaps(tracking: 1.8)
            if showsSun, let sun = GCWords.sun(snap) {
                Text(sun).gcSkyCaps(tracking: 1.2, medium: true)
            }
        }
    }
}

/// "64°" over the condition (and high and low on large), right aligned.
struct GCQuietWeather: View {
    var snap: DaySnapshot
    var numeral: CGFloat
    var showsCondition = true
    var showsHighLow = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            GCNumeral(text: GCWords.temp(snap), size: numeral)
                .padding(.bottom, -numeral * 0.16)
            if showsCondition {
                Text(GCWords.condition(snap)).gcSkyCaps(tracking: 1.2)
            }
            if showsHighLow {
                Text(GCWords.highLow(snap)).gcSkyCaps(tracking: 1.2, medium: true)
            }
        }
    }
}

// MARK: - The register

/// One quiet slab: a centred heading with the count on large, the tasks on hairline rules with a small room number in
/// the margin, due dates in plain capitals (raspberry when late), and the remainder at the foot.
struct GCQuietRegister: View {
    var tasks: [TaskItem]
    var error: String?
    var now: Date
    var family: Family

    private var maxRows: Int { family == .large ? 5 : (family == .medium ? 3 : 1) }
    private var shown: Int { min(tasks.count, maxRows) }
    private var rowHeight: CGFloat { family == .large ? 19.5 : 17 }
    private var titleSize: CGFloat { family == .large ? 13.5 : (family == .medium ? 13 : 12.5) }

    var body: some View {
        VStack(spacing: 0) {
            if family == .large {
                header
                    .frame(height: 14)
                    .padding(.bottom, 4)
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
        .padding(.horizontal, family == .small ? 10 : 12)
        .padding(.top, family == .large ? 8 : (family == .small ? 8 : 6))
        .padding(.bottom, family == .small ? 6 : 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .gcSlab(radius: family == .small ? 11 : 12, depth: family == .small ? 2.5 : 3)
    }

    private var header: some View {
        ZStack {
            Text("THE REGISTER").gcCardCaps(GH.burgundy, tracking: 2.6)
            HStack {
                Spacer()
                if !tasks.isEmpty {
                    Text("\(tasks.count)")
                        .font(GHFont.caps(9))
                        .monospacedDigit()
                        .foregroundStyle(GH.cream)
                        .raised(0.7)
                        .frame(minWidth: 20, minHeight: 15)
                        .padding(.horizontal, tasks.count > 9 ? 3 : 0)
                        .background(GHPebble(shape: Capsule(), material: .raspberry))
                }
            }
        }
        .overlay(alignment: .bottom) { GHRule(color: GH.plum).offset(y: 3) }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.prefix(shown).enumerated()), id: \.element.id) { i, t in
                row(t, number: i + 1)
                    .frame(height: rowHeight)
                    .overlay(alignment: .bottom) {
                        if i < shown - 1 { GHRule(color: GH.plum).opacity(0.75) }
                    }
            }
        }
    }

    private func row(_ t: TaskItem, number: Int) -> some View {
        HStack(spacing: 7) {
            Text("\(number)")
                .font(GHFont.capsMedium(GCSize.caps))
                .foregroundStyle(t.isOverdue(asOf: now) ? GH.raspberry : GH.inkSoft.opacity(0.85))
                .ghPressed()
                .frame(width: 8, alignment: .trailing)
            Text(t.text)
                .font(Serif.font(titleSize, weight: .medium))
                .foregroundStyle(GH.espresso)
                .ghPressed()
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: 6)
            GCDue(task: t, now: now)
        }
    }

    @ViewBuilder
    private var footer: some View {
        let more = tasks.count - shown
        if more > 0 || error != nil {
            HStack(spacing: 8) {
                if error == nil { Spacer(minLength: 0) }
                if more > 0 { Text(GCWords.more(more)).gcCardCaps(GH.burgundy, tracking: 2) }
                if let error { GCErrorLine(message: error, prefix: "Cached") }
                Spacer(minLength: 0)
            }
            .frame(height: 12)
        }
    }

    /// Small: the first task over two lines, then its due date (or a stale-cache warning) and the count of the rest.
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = tasks.first {
                Text(first.text)
                    .font(Serif.font(titleSize, weight: .medium))
                    .foregroundStyle(GH.espresso)
                    .ghPressed()
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 2)
                HStack(spacing: 4) {
                    if let error {
                        GCErrorLine(message: error, short: "Sync failed").layoutPriority(-1)
                    } else {
                        GCDue(task: first, now: now)
                    }
                    Spacer(minLength: 2)
                    if tasks.count > 1 { Text(GCWords.more(tasks.count - 1)).gcCardCaps(GH.burgundy, tracking: 1) }
                }
                .frame(height: 11)
            }
        }
    }

    @ViewBuilder
    private var empty: some View {
        let failed = error != nil
        VStack(spacing: family == .large ? 5 : 3) {
            Text(failed ? "Couldn't load tasks" : "Nothing due. Nice.")
                .font(Serif.font(family == .small ? 12.5 : 15, weight: .semibold))
                .foregroundStyle(GH.burgundy)
                .ghPressed()
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            if let error {
                Text(family == .small ? GCWords.firstSentence(error) : error)
                    .font(Serif.font(family == .small ? 11 : 12, weight: .medium, italic: true))
                    .foregroundStyle(GH.raspberry)
                    .multilineTextAlignment(.center)
                    .lineLimit(family == .large ? 3 : 2)
                    .ghPressed()
            } else {
                Text("EVERY KEY ON ITS HOOK").gcCardCaps(GH.inkSoft, tracking: 1.4, medium: true)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Day widgets

struct GCQuietDayLarge: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.large)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.dayLarge(snap, hotelBase: 0.355, hotelWidth: 112, ledgeBottom: 0.5, trail: true))
                .frame(width: s.width, height: s.height)
            GCQuietValance(family: .large)

            GCQuietDate(snap: snap, numeral: 52, showsSun: true)
                .padding(.leading, 16).padding(.top, 14)
            GCQuietWeather(snap: snap, numeral: 42, showsHighLow: true)
                .frame(width: s.width - 16, alignment: .trailing)
                .padding(.top, 22)

            GCWeekChannel(date: snap.date, tasks: snap.tasks).ghPlace(16, 179, 316, 26)
            GCQuietRegister(tasks: snap.tasks, error: snap.taskError, now: snap.date, family: .large).ghPlace(16, 213, 316, 138)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

struct GCQuietDayMedium: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.medium)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.dayMedium(snap, hotelBase: 0.45, hotelWidth: 72))
                .frame(width: s.width, height: s.height)
            GCQuietValance(family: .medium)

            GCQuietDate(snap: snap, numeral: 35)
                .padding(.leading, 16).padding(.top, 12)
            GCQuietWeather(snap: snap, numeral: 30, showsCondition: true)
                .frame(width: s.width - 16, alignment: .trailing)
                .padding(.top, 17)

            GCQuietRegister(tasks: snap.tasks, error: snap.taskError, now: snap.date, family: .medium).ghPlace(14, 77, 320, 73)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

struct GCQuietDaySmall: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.small)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.daySmall(snap, hotelBase: 0.555, hotelWidth: 46))
                .frame(width: s.width, height: s.height)
            GCQuietValance(family: .small)

            GCQuietDate(snap: snap, numeral: 33, shortMonth: true)
                .padding(.leading, 16).padding(.top, 12)
            GCQuietWeather(snap: snap, numeral: 27, showsCondition: false)
                .frame(width: s.width - 16, alignment: .trailing)
                .padding(.top, 17)

            GCQuietRegister(tasks: snap.tasks, error: snap.taskError, now: snap.date, family: .small).ghPlace(12, 96, 140, 56)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

// MARK: - Quote widgets

struct GCQuietQuoteLarge: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let s = Mock.size(.large)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.quote(now, family: .large, hotelBase: 0.395, hotelWidth: 128))
                .frame(width: s.width, height: s.height)
            GCQuietValance(family: .large)
            GCQuoteCard(quote: quote, sizes: [18, 17, 16, 15, 14, 13, 12], button: true,
                        padding: EdgeInsets(top: 16, leading: 18, bottom: 15, trailing: 18))
                .ghPlace(16, 190, 316, 161)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

struct GCQuietQuoteMedium: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let s = Mock.size(.medium)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.quote(now, family: .medium, hotelBase: 0.6, hotelWidth: 70, cx: 0.825))
                .frame(width: s.width, height: s.height)
            GCQuietValance(family: .medium)
            GCQuoteCard(quote: quote, sizes: [15, 14, 13, 12, 11.5, 11], button: false,
                        padding: EdgeInsets(top: 11, leading: 13, bottom: 10, trailing: 13), radius: 11)
                .ghPlace(14, 24, 222, 126)
            GCNextButton().ghPlace(302, 120, 30, 30)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

struct GCQuietQuoteSmall: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let s = Mock.size(.small)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GCScenes.quote(now, family: .small, hotelBase: 0.36, hotelWidth: 52))
                .frame(width: s.width, height: s.height)
            GCQuietValance(family: .small)
            GCQuoteCard(quote: quote, sizes: [14, 13, 12, 11, 10.5], button: false,
                        padding: EdgeInsets(top: 8, leading: 9, bottom: 8, trailing: 9), radius: 11)
                .ghPlace(12, 66, 140, 86)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}
