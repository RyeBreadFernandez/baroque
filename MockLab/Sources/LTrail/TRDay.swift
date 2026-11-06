import SwiftUI

// The Day widget as a trail through time. Every view returns the whole widget at its exact size.

struct TRDayWidget: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        let size = Mock.size(family)
        ZStack(alignment: .topLeading) {
            TRDayScene(snapshot: snapshot, family: family)
            switch family {
            case .large: TRDayLarge(snapshot: snapshot)
            case .medium: TRDayMedium(snapshot: snapshot)
            case .small: TRDaySmall(snapshot: snapshot)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Large

/// Date and weather in the sky, the week ahead with its pips, then the trail: Late, Today, Soon, Someday
/// as copper waypoints on a gold thread down the left of a painted slab, each with its tasks beside it.
struct TRDayLarge: View {
    var snapshot: DaySnapshot

    // Fixed bands (333 pt inside the margins) so the ridges in TRRidges.day(.large) line up with them.
    static let header: CGFloat = 54
    static let strip: CGFloat = 40
    static let gap: CGFloat = 7
    static var slab: CGFloat { Mock.size(.large).height - 32 - header - strip - gap * 2 }

    var body: some View {
        let agenda = TRAgenda(now: snapshot.date, tasks: snapshot.tasks)
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                TRDateLine(date: snapshot.date, style: .large)
                    .padding(.top, 2)
                Spacer(minLength: 8)
                TRWeather(weather: snapshot.weather, style: .large)
            }
            .frame(height: Self.header, alignment: .top)
            TRWeekPips(agenda: agenda)
                .frame(height: Self.strip)
                .padding(.top, Self.gap)
            TRTimeline(agenda: agenda, error: snapshot.taskError, height: Self.slab)
                .padding(.top, Self.gap)
        }
        .padding(Mock.margin)
        .frame(width: Mock.size(.large).width, height: Mock.size(.large).height, alignment: .top)
    }
}

/// The vertical trail on its slab. Rows have fixed heights so the thread can be drawn straight through
/// the nodes, and so we can work out how many rows fit before laying anything out.
struct TRTimeline: View {
    var agenda: TRAgenda
    var error: String?
    var height: CGFloat
    var maxRows: Int = 6

    static let labelH: CGFloat = 17
    static let rowH: CGFloat = 21
    static let gapH: CGFloat = 4
    static let footH: CGFloat = 16
    static let pad = EdgeInsets(top: 9, leading: 10, bottom: 8, trailing: 12)
    static let column: CGFloat = 20
    static let spacing: CGFloat = 8

    enum Row: Identifiable {
        case label(TRSection)
        case task(TaskItem, TRStage)
        case clear
        case gap(Int)

        var id: String {
            switch self {
            case .label(let s): return "label-\(s.id)"
            case .task(let t, _): return t.id
            case .clear: return "clear"
            case .gap(let i): return "gap-\(i)"
            }
        }

        var height: CGFloat {
            switch self {
            case .label: return TRTimeline.labelH
            case .task, .clear: return TRTimeline.rowH
            case .gap: return TRTimeline.gapH
            }
        }

        var hasNode: Bool {
            if case .gap = self { return false }
            return true
        }
    }

    private struct Plan {
        var rows: [Row]
        var hidden: Int
    }

    private func rows(_ sections: [TRSection]) -> [Row] {
        var out: [Row] = []
        for (i, s) in sections.enumerated() {
            if i > 0 { out.append(.gap(i)) }
            out.append(.label(s))
            if s.total == 0 {
                out.append(.clear)
            } else {
                out += s.tasks.map { .task($0, s.stage) }
            }
        }
        return out
    }

    private var plan: Plan {
        let room = height - Self.pad.top - Self.pad.bottom
        var best = Plan(rows: [], hidden: 0)
        for n in stride(from: maxRows, through: 1, by: -1) {
            let sections = agenda.trail(rows: n)
            let r = rows(sections)
            let shown = sections.reduce(0) { $0 + $1.tasks.count }
            let hidden = agenda.tasks.count - shown
            let need = r.reduce(0) { $0 + $1.height } + (error != nil ? Self.footH : 0)
            best = Plan(rows: r, hidden: hidden)
            if need <= room { break }
        }
        return best
    }

    var body: some View {
        Group {
            if agenda.tasks.isEmpty {
                empty
            } else {
                trail(plan)
            }
        }
        .padding(Self.pad)
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .stoneSlab(.panel, radius: 18, depth: 3)
    }

    // MARK: Trail

    private func trail(_ plan: Plan) -> some View {
        // Node centres down the column, and where today's stretch ends (the wire is solid to there).
        var y: CGFloat = 0
        var centers: [CGFloat] = []
        var walked: CGFloat = 0
        var inToday = false
        for row in plan.rows {
            if row.hasNode { centers.append(y + row.height / 2) }
            switch row {
            case .label(let s): inToday = s.stage == .today
            case .task, .clear: break
            case .gap: inToday = false
            }
            if inToday || walked == 0 { walked = y + row.height / 2 }
            y += row.height
        }
        let top = centers.first ?? 0
        let last = centers.last ?? 0
        // When the far end is trimmed, the dashed wire runs on a little past the last stop.
        let tail = plan.hidden > 0 ? min(y + 2, last + 9) : last

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(plan.rows) { row in
                    rowView(row).frame(height: row.height)
                }
            }
            .background(alignment: .topLeading) {
                TRThread(x: Self.column / 2, top: top, bottom: tail, walked: walked)
            }
            Spacer(minLength: 0)
            footer
        }
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        switch row {
        case .label(let s):
            HStack(spacing: Self.spacing) {
                TRNode(size: s.stage == .today ? 13 : 11, here: s.stage == .today)
                    .frame(width: Self.column)
                TRCaps(text: s.stage.title, color: s.stage.ink, size: 10, tracking: 1.8)
                    .raised()
                if s.total > 1 {
                    Text("\(s.total)")
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Stone.goldFaint)
                        .raised()
                }
                EngravedRule()
                    .padding(.leading, 2)
                if s.total > s.tasks.count {
                    // The rest of this stretch, trimmed to fit.
                    Text("+\(s.total - s.tasks.count) more")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Stone.goldFaint)
                        .raised()
                        .fixedSize()
                }
            }
        case .task(let t, let stage):
            HStack(spacing: Self.spacing) {
                TaskSocket(accent: trAccent(t, stage: stage), size: 12)
                    .frame(width: Self.column)
                Text(t.text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Stone.parchment)
                    .raised(0.8)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if stage != .today, let due = agenda.dueLabel(t) {
                    TRDue(text: due, late: stage == .late)
                }
            }
        case .clear:
            HStack(spacing: Self.spacing) {
                TaskSocket(accent: Stone.sage, size: 12)
                    .frame(width: Self.column)
                Text("Nothing due today")
                    .font(Serif.font(13, weight: .medium, italic: true))
                    .foregroundStyle(Stone.goldMuted)
                    .raised()
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        case .gap:
            Color.clear
        }
    }

    /// Cached tasks are still on the trail above; the footer says why they may be stale.
    @ViewBuilder
    private var footer: some View {
        if let error {
            ErrorLine(message: error, prefix: "Cached", color: Stone.copperInk)
                .padding(.leading, Self.column + Self.spacing)
                .frame(height: Self.footH, alignment: .bottom)
        }
    }

    // MARK: Empty

    /// No tasks: today's stop, then the open trail and a quiet message (or the error, when nothing is cached).
    private var empty: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Self.spacing) {
                TRNode(size: 13, here: true)
                    .frame(width: Self.column)
                TRCaps(text: TRStage.today.title, color: Stone.gold, size: 10, tracking: 1.8)
                    .raised()
                EngravedRule()
            }
            .frame(height: Self.labelH)
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Image(systemName: error == nil ? "checkmark" : "exclamationmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(error == nil ? Stone.sage : Stone.copperInk)
                    .raised()
                    .frame(width: 36, height: 36)
                    .carved(Circle())
                Text(error == nil ? "Nothing due. Nice." : "Couldn't load tasks")
                    .font(Serif.font(15, weight: .semibold))
                    .foregroundStyle(Stone.gold)
                    .raised()
                if let error {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Stone.copperInk)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, Self.column)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .background(alignment: .topLeading) {
            GeometryReader { geo in
                TRThread(x: Self.column / 2, top: Self.labelH / 2, bottom: geo.size.height - 6, walked: Self.labelH / 2)
            }
        }
    }
}

// MARK: - Medium

/// A trail along the near ridge's crest with three or four stops (Late, Today, Tomorrow, Later). Each stop's
/// pebble carries its count; its name and first task stand on the dark ridge below.
struct TRDayMedium: View {
    var snapshot: DaySnapshot

    static let trailDrop: CGFloat = 3 // the path runs just under the lit rim of the crest

    var body: some View {
        let size = Mock.size(.medium)
        let agenda = TRAgenda(now: snapshot.date, tasks: snapshot.tasks)
        let stops = agenda.waypoints
        let crest = TRRidges.mediumTrail.crest(in: CGRect(origin: .zero, size: size))
        let colW = (size.width - Mock.margin * 2) / CGFloat(stops.count)
        let xs = stops.indices.map { Mock.margin + colW * (CGFloat($0) + 0.5) }
        let ys = xs.map { RidgeProfile.height(at: $0, on: crest) + Self.trailDrop }
        let hereX = stops.firstIndex { $0.kind == .today }.map { xs[$0] } ?? xs[0]
        // With an error line along the bottom, the writing tucks up under the trail to make room.
        let textTop = (ys.max() ?? 84) + (snapshot.taskError == nil ? 13 : 9)
        let empty = agenda.tasks.isEmpty

        ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 8) {
                TRDateLine(date: snapshot.date, style: .medium)
                Spacer(minLength: 8)
                TRWeather(weather: snapshot.weather, style: .medium)
            }
            .padding(.horizontal, Mock.margin)
            .padding(.top, Mock.margin)

            TRCrestTrail(crest: crest, drop: Self.trailDrop, walkedX: hereX)

            ForEach(Array(stops.enumerated()), id: \.element.id) { i, stop in
                Group {
                    if stop.tasks.isEmpty {
                        TREmptyNode(size: 12, here: stop.kind == .today)
                    } else {
                        TRNode(size: stop.kind == .today ? 17 : 15, here: stop.kind == .today, count: stop.tasks.count)
                    }
                }
                .position(x: xs[i], y: ys[i])

                stopText(stop, showsTitle: !empty)
                    .frame(width: colW - 6, height: 38, alignment: .top)
                    .position(x: xs[i], y: textTop + 19)
            }

            if empty {
                emptyMessage
                    .padding(.horizontal, Mock.margin)
                    .frame(width: size.width, height: size.height - Mock.margin - textTop - 15, alignment: .top)
                    .position(x: size.width / 2, y: (textTop + 15 + size.height - Mock.margin) / 2)
            } else if let error = snapshot.taskError {
                // Cached tasks are still at their stops; say why they may be stale.
                ErrorLine(message: error, prefix: "Cached", color: Stone.copperInk, fontSize: 9.5)
                    .legible()
                    .padding(.horizontal, Mock.margin)
                    .frame(width: size.width)
                    .position(x: size.width / 2, y: size.height - Mock.margin - 6)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func stopText(_ stop: TRWaypoint, showsTitle: Bool) -> some View {
        VStack(spacing: 1) {
            TRCaps(text: stop.title, color: stop.ink, size: 9.5, tracking: 1.3)
            if showsTitle {
                Text(stop.tasks.first?.text ?? "Clear")
                    .font(stop.tasks.isEmpty ? Serif.font(11.5, italic: true) : .system(size: 11, weight: .medium))
                    .foregroundStyle(stop.tasks.isEmpty ? Stone.goldMuted : Stone.parchment)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .lineSpacing(-1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .legible()
    }

    /// Nothing at any stop: one quiet line under the trail, or why the tasks couldn't be loaded.
    @ViewBuilder
    private var emptyMessage: some View {
        if let error = snapshot.taskError {
            VStack(spacing: 1) {
                Text("Couldn't load tasks")
                    .font(Serif.font(13, weight: .semibold))
                    .foregroundStyle(Stone.gold)
                Text(error)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Stone.copperInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .legible()
        } else {
            Label {
                Text("Nothing due. Nice.")
            } icon: {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Stone.sage)
            }
            .font(Serif.font(13, weight: .medium, italic: true))
            .foregroundStyle(Stone.goldMuted)
            .legible()
        }
    }
}

/// The dashed gold path along the ridge crest, solid up to today's stop.
struct TRCrestTrail: View {
    var crest: [CGPoint]
    var drop: CGFloat
    var walkedX: CGFloat

    var body: some View {
        let walked = path { $0.x <= walkedX + 0.5 }
        let ahead = path { $0.x >= walkedX - 4 }
        ZStack {
            walked.stroke(Stone.shadow.opacity(0.75), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .offset(y: 0.9)
            walked.stroke(LinearGradient(colors: [Stone.goldBright, Stone.gold], startPoint: .top, endPoint: .bottom),
                          style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            ahead.stroke(Stone.shadow.opacity(0.75), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [2.6, 3.6]))
                .offset(y: 0.9)
            ahead.stroke(Stone.gold.opacity(0.9), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [2.6, 3.6]))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func path(_ keep: (CGPoint) -> Bool) -> Path {
        var p = Path()
        var started = false
        for pt in crest where keep(pt) && pt.x > 7 && pt.x < 341 {
            let q = CGPoint(x: pt.x, y: pt.y + drop)
            if started { p.addLine(to: q) } else { p.move(to: q); started = true }
        }
        return p
    }
}

// MARK: - Small

/// A short vertical trail cut into the ridge: what's late, how many today, and what's next.
struct TRDaySmall: View {
    var snapshot: DaySnapshot

    static let column: CGFloat = 16

    private enum Stop: Identifiable {
        case late(TaskItem, count: Int)
        case today(count: Int)
        case next(TaskItem, label: String)
        case note(String)

        var id: String {
            switch self {
            case .late: return "late"
            case .today: return "today"
            case .next(let t, _): return "next-" + t.id
            case .note: return "note"
            }
        }

        var height: CGFloat {
            switch self {
            case .today: return 22
            case .note: return 30
            default: return 27
            }
        }
    }

    private func stops(_ agenda: TRAgenda) -> [Stop] {
        if agenda.tasks.isEmpty {
            return [.today(count: 0), .note(snapshot.taskError ?? "Nothing due. Nice.")]
        }
        var out: [Stop] = []
        let late = agenda.late
        if let first = late.first { out.append(.late(first, count: late.count)) }
        out.append(.today(count: agenda.dueToday.count))
        let ahead = agenda.tasks.filter { agenda.stage($0) != .late }
        for t in ahead.prefix(out.count == 2 ? 1 : 2) {
            // The today stop already says "today"; anything further on names its day.
            let word = t == ahead.first ? "Next" : "Then"
            let due = agenda.stage(t) == .today ? nil : agenda.dueLabel(t)
            out.append(.next(t, label: due.map { "\(word) · \($0)" } ?? word))
        }
        return out
    }

    var body: some View {
        let agenda = TRAgenda(now: snapshot.date, tasks: snapshot.tasks)
        let list = stops(agenda)
        var y: CGFloat = 0
        var centers: [CGFloat] = []
        for s in list {
            centers.append(y + (s.height == 27 ? 8 : s.height / 2))
            y += s.height + 4
        }
        let todayY = list.firstIndex { if case .today = $0 { return true }; return false }.map { centers[$0] } ?? 0

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                TRDateLine(date: snapshot.date, style: .small)
                Spacer(minLength: 0)
                TRWeather(weather: snapshot.weather, style: .small)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(list) { stop in
                    stopView(stop).frame(height: stop.height, alignment: .top)
                }
            }
            .background(alignment: .topLeading) {
                TRThread(x: Self.column / 2, top: centers.first ?? 0, bottom: centers.last ?? 0, walked: todayY, channel: 5)
            }
            if let error = snapshot.taskError, !agenda.tasks.isEmpty {
                ErrorLine(message: error, color: Stone.copperInk, fontSize: 9.5)
                    .legible()
                    .padding(.top, 2)
            }
        }
        .padding(Mock.margin)
        .frame(width: Mock.size(.small).width, height: Mock.size(.small).height, alignment: .topLeading)
    }

    @ViewBuilder
    private func stopView(_ stop: Stop) -> some View {
        switch stop {
        case .late(let t, let count):
            HStack(alignment: .top, spacing: 5) {
                TRNode(size: 10).frame(width: Self.column, height: 16)
                VStack(alignment: .leading, spacing: 0) {
                    TRCaps(text: count > 1 ? "\(count) late" : "Late", color: Stone.copperInk, size: 9, tracking: 1.2)
                    Text(t.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Stone.parchment)
                        .lineLimit(1)
                }
                .legible()
            }
        case .today(let count):
            HStack(spacing: 5) {
                Group {
                    if count > 0 { TRNode(size: 16, here: true, count: count) } else { TRNode(size: 12, here: true) }
                }
                .frame(width: Self.column)
                Text(count > 0 ? "due today" : "Today")
                    .font(Serif.font(13, weight: .semibold, italic: count > 0))
                    .foregroundStyle(Stone.gold)
                    .legible()
                    .lineLimit(1)
            }
        case .next(let t, let label):
            HStack(alignment: .top, spacing: 5) {
                TaskSocket(accent: trAccent(t, stage: .today), size: 11)
                    .frame(width: Self.column, height: 16)
                VStack(alignment: .leading, spacing: 0) {
                    TRCaps(text: label, color: Stone.goldMuted, size: 9, tracking: 1.2)
                    Text(t.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Stone.parchment)
                        .lineLimit(1)
                }
                .legible()
            }
        case .note(let text):
            HStack(alignment: .top, spacing: 5) {
                TREmptyNode(size: 10).frame(width: Self.column, height: 14)
                Text(text)
                    .font(snapshot.taskError == nil ? Serif.font(12, italic: true) : .system(size: 10.5, weight: .semibold))
                    .foregroundStyle(snapshot.taskError == nil ? Stone.goldMuted : Stone.copperInk)
                    .lineLimit(2)
                    .legible()
            }
        }
    }
}
