import SwiftUI

// The Day widget as a book. Large: a spread, the plate of today's mountains facing the day's page (its weather set as
// the plate's caption). The page opens with a running head (the month) and the date as a dropped initial with the
// count beside it; the tasks follow as numbered lines, their due dates in the outer margin as marginal notes; a
// catchword says how many more there are, and the week runs along the foot as folios, today circled in rubric.
// Medium: the same spread, three tasks. Small: one page, the plate as a headpiece.

struct OFDay: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .large: OFDayLarge(snap: snapshot)
        case .medium: OFDayMedium(snap: snapshot)
        case .small: OFDaySmall(snap: snapshot)
        }
    }
}

/// The sky, light and plate painting for a snapshot.
struct OFDayScene {
    var snap: DaySnapshot
    var clock: SkyClock { SkyClock(now: snap.date, weather: snap.weather) }
    var condition: SkyCondition { SkyCondition(code: snap.weather?.code) }
    var room: OFRoomLight { OFRoomLight(clock: clock, condition: condition) }

    func painting(_ plate: OFPlate) -> OFPainting {
        OFPainting(plate: plate, clock: clock, condition: condition, phase: MoonPhase(date: snap.date))
    }

    var day: Int { Calendar.current.component(.day, from: snap.date) }
    var month: String { OMWords.month(snap.date) }
    var late: Int { snap.tasks.filter { $0.isOverdue(asOf: snap.date) }.count }
    var dueToday: Int { snap.tasks.filter { $0.isDueToday(asOf: snap.date) }.count }
}

// MARK: - Large

struct OFDayLarge: View {
    var snap: DaySnapshot

    var body: some View {
        let scene = OFDayScene(snap: snap)
        let shown = Array(snap.tasks.prefix(5))
        let error = snap.tasks.isEmpty ? nil : snap.taskError
        OFBook(binding: .spreadLarge, light: scene.room) {
            // Verso: the plate, its plate-mark, its caption.
            OFPlateFrame { scene.painting(.dayLarge) }
                .ofAt(22, 22, 138, 264)
            OFPlateCaption(snap: snap, detail: true)
                .ofAt(16, 297, 150, 50, alignment: .top)
            // Recto: running head, the opening, the numbered lines, the catchword, the folios.
            Text.ofCaps(scene.month, 10.5, OFInk.inkFaint, tracking: 2.2)
                .lineLimit(1)
                .ofAt(194, 17, 138, 13, alignment: .center)
            OFDayOpening(scene: scene, size: 12.5, initial: 59, lines: 3)
                .ofAt(194, 38, 138, 49)
            if snap.tasks.isEmpty {
                OFBlank(error: snap.taskError)
                    .ofAt(194, 100, 138, 210)
            } else {
                ViewThatFits(in: .vertical) {
                    ForEach([15, 12, 10, 8, 6, 4] as [CGFloat], id: \.self) { s in
                        OFTaskLines(snap: snap, tasks: shown, size: 13, lineLimit: 2, spacing: s)
                    }
                    OFTaskLines(snap: snap, tasks: shown, size: 13, lineLimit: 1, spacing: 6)
                }
                .ofAt(180, 100, 152, error == nil ? 190 : 162)
                if let error {
                    OFFootnote(text: "Cached copy. \(error)", size: 8.5)
                        .ofAt(194, 266, 138, 26, alignment: .bottomLeading)
                }
                OFCatchword(more: snap.tasks.count - shown.count, size: 10.5)
                    .ofAt(194, 295, 138, 14, alignment: .trailing)
            }
            OFFolios(date: snap.date, tasks: snap.tasks, size: 11.5)
                .ofAt(186, 320, 146, 22)
        }
    }
}

/// The plate's caption is the weather: "Plate III. 64°, mostly clear. High 68, low 52; sunset 4:58."
struct OFPlateCaption: View {
    var snap: DaySnapshot
    var detail: Bool

    var body: some View {
        let day = Calendar.current.component(.day, from: snap.date)
        VStack(spacing: detail ? 2.5 : 1.5) {
            Text.ofCaps("Plate " + OFWords.roman(day), detail ? 10 : 9.5, OFInk.inkFaint, tracking: 1.8)
            if let w = snap.weather {
                (Text(OFWords.temp(w)).font(OFType.serif(detail ? 15 : 13)).foregroundStyle(OFInk.ink)
                 + Text(", \(w.label.lowercased()).").font(OFType.italic(detail ? 13.5 : 12)).foregroundStyle(OFInk.ink))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if detail {
                    Text(OFDayPage.weatherDetail(w, now: snap.date))
                        .font(OFType.italic(10.5))
                        .foregroundStyle(OFInk.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            } else {
                Text(snap.weatherError == nil ? "The weather is not yet read." : "The weather could not be read.")
                    .font(OFType.italic(detail ? 12 : 11))
                    .foregroundStyle(snap.weatherError == nil ? OFInk.inkSoft : OFInk.rubric)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The recto's columns: verse numbers hang in the inner margin (0..10), the measure runs 14..116 and the marginal
/// notes sit in the outer margin, 120..152 (x in the page's text block, which starts 6 pt from the spine).
enum OFDayPage {
    static let number: CGFloat = 10, measure: CGFloat = 102, gutter: CGFloat = 4

    /// "High 68, low 52; sunset 4:58."
    static func weatherDetail(_ w: WeatherSnapshot, now: Date) -> String {
        var s = "High \(Int(w.high.rounded())), low \(Int(w.low.rounded()))"
        if let event = OMWords.sunEvent(w, now: now) { s += "; " + event }
        return s + "."
    }
}

/// The chapter opening: the date as a dropped initial in rubric, the count beside it as the first sentence,
/// its first words in small capitals. Medium sets the month on the first line instead of a running head.
/// The longest sentence that keeps within the initial's lines is used (in full, short, then the count alone).
struct OFDayOpening: View {
    var scene: OFDayScene
    var size: CGFloat
    var initial: CGFloat
    var lines: Int
    var month: Bool = false

    var body: some View {
        ViewThatFits(in: .vertical) {
            paragraph(0)
            paragraph(1)
            paragraph(2)
        }
    }

    private func paragraph(_ level: Int) -> OFParagraph {
        let snap = scene.snap
        let n = snap.tasks.count
        let caps = size + 0.5
        var runs: [OFRun] = []
        if month {
            runs.append(OFRun(text: scene.month, font: OFType.serif(size), color: OFInk.ink, tracking: 1.6,
                              smallCaps: size + 1.5, breakAfter: true))
        }
        if n == 0 && snap.taskError != nil {
            runs.append(OFRun(text: "The tasks", font: OFType.serif(size), color: OFInk.ink, tracking: 0.7, smallCaps: caps))
            runs.append(OFRun(text: level == 0 ? "could not be fetched.*" : "failed.*", font: OFType.italic(size), color: OFInk.rubric))
        } else if n == 0 {
            runs.append(OFRun(text: "Nothing due", font: OFType.serif(size), color: OFInk.ink, tracking: 0.7, smallCaps: caps))
            let rest = level == 0 && !month ? "today; the page is clear for the mountains." : "today."
            runs.append(OFRun(text: rest, font: OFType.italic(size), color: OFInk.inkSoft))
        } else {
            let count = "\(OFWords.spelled(n).capitalized(with: nil)) \(n == 1 ? "task" : "tasks")"
            runs.append(OFRun(text: count + (level == 2 ? "." : ""), font: OFType.serif(size), color: OFInk.ink,
                              tracking: 0.7, smallCaps: caps))
            if level < 2 {
                let mark = snap.taskError != nil && !month ? "*" : ""
                runs.append(OFRun(text: Self.sentence(n: n, late: scene.late, today: scene.dueToday, short: month || level == 1) + mark,
                                  font: OFType.italic(size), color: OFInk.inkSoft))
            }
        }
        return OFParagraph(initial: OFRun(text: String(scene.day), font: OFType.serif(initial), color: OFInk.initial),
                           runs: runs, lineHeight: (size * 1.27).rounded(), space: size * 0.28, initialLines: lines,
                           initialGap: 6, justify: false)
    }

    /// "in hand; one is late, two fall due today." Short: "· one late".
    static func sentence(n: Int, late: Int, today: Int, short: Bool) -> String {
        let l = OFWords.spelled(late), t = OFWords.spelled(today)
        if short {
            if late > 0 { return "· \(l) late" }
            if today > 0 { return "· \(t) today" }
            return "· none pressing"
        }
        if n == 1 {
            if late > 0 { return "in hand, and it is late." }
            if today > 0 { return "in hand, due today." }
            return "in hand, not pressing."
        }
        var parts: [String] = []
        if late > 0 { parts.append(late == 1 ? "one is late" : "\(l) are late") }
        if today > 0 { parts.append(today == 1 ? "one falls due today" : "\(t) fall due today") }
        if parts.isEmpty { return "in hand, none of them pressing." }
        return "in hand; " + parts.joined(separator: ", ") + "."
    }
}

/// The tasks as numbered lines: the number hung in the inner margin in old-style figures, the title in the
/// measure (turning over onto a second line with a hanging indent), the due date in the outer margin.
struct OFTaskLines: View {
    var snap: DaySnapshot
    var tasks: [TaskItem]
    var size: CGFloat
    var lineLimit: Int
    var spacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { i, t in
                let late = t.isOverdue(asOf: snap.date)
                let today = t.isDueToday(asOf: snap.date)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(i + 1)")
                        .font(OFType.figures(size * 0.78))
                        .foregroundStyle(OFInk.inkFaint)
                        .frame(width: OFDayPage.number, alignment: .trailing)
                    Text(t.text)
                        .font(OFType.serif(size))
                        .foregroundStyle(late ? OFInk.rubric : OFInk.ink)
                        .lineLimit(lineLimit)
                        .lineSpacing(-1)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: OFDayPage.measure, alignment: .leading)
                        .padding(.leading, OFDayPage.gutter)
                    if let due = Mock.dueLabel(t, now: snap.date) {
                        Text(due)
                            .font(OFType.italic(10))
                            .foregroundStyle(late ? OFInk.rubric : (today ? OFInk.ink : OFInk.inkFaint))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.leading, OFDayPage.gutter)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The catchword at the foot of the text: what is left over, as old books printed the first word of the next page.
struct OFCatchword: View {
    var more: Int
    var size: CGFloat

    var body: some View {
        if more > 0 {
            Text("\(more) more overleaf")
                .font(OFType.italic(size))
                .foregroundStyle(OFInk.inkSoft)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// A fetch failure as a footnote: a short rule, then the reason in small italic rubric.
struct OFFootnote: View {
    var text: String
    var size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Rectangle().fill(OFInk.inkFaint.opacity(0.7)).frame(width: 26, height: 0.6)
            Text("* " + text)
                .font(OFType.italic(size))
                .foregroundStyle(OFInk.rubric)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// No tasks: the rest of the page left blank, said so, or the reason in a footnote.
struct OFBlank: View {
    var error: String?
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error {
                Spacer(minLength: 0)
                OFFootnote(text: error, size: compact ? 8.5 : 9)
            } else {
                Spacer(minLength: 0)
                Text("This page intentionally left blank.")
                    .font(OFType.italic(compact ? 10.5 : 11))
                    .foregroundStyle(OFInk.inkFaint)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The week along the foot as folios (page numbers), Monday first, in old-style figures: today circled in rubric
/// as if by pen, a point under any later day with something due, past days faded.
struct OFFolios: View {
    var date: Date
    var tasks: [TaskItem]
    var size: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(OFWeek.days(of: date, tasks: tasks).enumerated()), id: \.offset) { _, d in
                ZStack {
                    if d.today {
                        OFInkRing()
                            .stroke(OFInk.rubric.opacity(0.85), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                            .frame(width: size * 1.9, height: size * 1.6)
                    }
                    Text(d.number)
                        .font(OFType.figures(size))
                        .foregroundStyle(d.today ? OFInk.rubric : (d.past ? OFInk.inkFaint.opacity(0.7) : OFInk.inkSoft))
                    if d.due {
                        Circle().fill(OFInk.rubric.opacity(0.85)).frame(width: 2.6, height: 2.6).offset(y: size * 0.72)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: size * 1.7)
            }
        }
    }
}

/// A ring drawn by hand: not quite closed, its stroke overrunning where it began.
struct OFInkRing: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let steps = 40
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let a = -2.2 + t * (2 * Double.pi + 0.5)
            let wobble = 1 + 0.05 * sin(t * 9) - 0.04 * t
            let pt = CGPoint(x: c.x + rect.width / 2 * CGFloat(cos(a) * wobble), y: c.y + rect.height / 2 * CGFloat(sin(a) * wobble))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p.applying(CGAffineTransform(translationX: -c.x, y: -c.y).concatenating(CGAffineTransform(rotationAngle: -0.12)).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
    }
}

enum OFWeek {
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

// MARK: - Medium

struct OFDayMedium: View {
    var snap: DaySnapshot

    var body: some View {
        let scene = OFDayScene(snap: snap)
        let shown = Array(snap.tasks.prefix(3))
        OFBook(binding: .spreadMedium, light: scene.room) {
            OFPlateFrame { scene.painting(.dayMedium) }
                .ofAt(20, 17, 140, 96)
            OFPlateCaption(snap: snap, detail: false)
                .ofAt(16, 121, 148, 28, alignment: .top)
            OFDayOpening(scene: scene, size: 11.5, initial: 36, lines: 2, month: true)
                .ofAt(194, 16, 138, 31)
            if snap.tasks.isEmpty {
                OFBlank(error: snap.taskError, compact: true)
                    .ofAt(194, 52, 138, 96)
            } else {
                ViewThatFits(in: .vertical) {
                    OFMediumTasks(snap: snap, shown: shown, lineLimit: 2, spacing: 5)
                    OFMediumTasks(snap: snap, shown: shown, lineLimit: 2, spacing: 2)
                    OFMediumTasks(snap: snap, shown: shown, lineLimit: 1, spacing: 6)
                    OFMediumTasks(snap: snap, shown: shown, lineLimit: 1, spacing: 2)
                }
                .ofAt(180, 53, 152, 95)
            }
        }
    }
}

/// Three numbered lines, then the catchword (or the cached-copy footnote) at the foot.
struct OFMediumTasks: View {
    var snap: DaySnapshot
    var shown: [TaskItem]
    var lineLimit: Int
    var spacing: CGFloat

    var body: some View {
        let more = snap.tasks.count - shown.count
        VStack(alignment: .leading, spacing: 0) {
            OFTaskLines(snap: snap, tasks: shown, size: 12.5, lineLimit: lineLimit, spacing: spacing)
            Spacer(minLength: 3)
            HStack(spacing: 6) {
                if let error = snap.taskError {
                    // The reason gets the line; the catchword shortens to make room for it.
                    Text("* Cached. \(error)")
                        .font(OFType.italic(8.5))
                        .foregroundStyle(OFInk.rubric)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                }
                Spacer(minLength: 0)
                if more > 0 {
                    Text(snap.taskError == nil ? "\(more) more overleaf" : "+\(more) more")
                        .font(OFType.italic(10)).foregroundStyle(OFInk.inkSoft).fixedSize()
                }
            }
            .padding(.leading, OFDayPage.number + OFDayPage.gutter)
            .frame(height: 12)
        }
    }
}

// MARK: - Small

struct OFDaySmall: View {
    var snap: DaySnapshot

    var body: some View {
        let scene = OFDayScene(snap: snap)
        OFBook(binding: .pageSmall, light: scene.room) {
            OFPlateFrame(mark: 3.5) { scene.painting(.daySmall) }
                .ofAt(22, 17, 122, 54)
            Group {
                if let w = snap.weather {
                    (Text(OFWords.temp(w)).font(OFType.serif(12)) + Text(", \(w.label.lowercased()).").font(OFType.italic(11)))
                        .foregroundStyle(OFInk.ink)
                } else {
                    Text(snap.weatherError == nil ? "No weather yet." : "Weather offline.")
                        .font(OFType.italic(11)).foregroundStyle(snap.weatherError == nil ? OFInk.inkSoft : OFInk.rubric)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .ofAt(18, 78, 130, 14, alignment: .center)
            OFSmallEntry(scene: scene)
                .ofAt(20, 95, 128, 52)
        }
    }
}

/// The small page's entry: the date dropped through three lines, the month in small capitals, the first task
/// beside it, then its due date and the count of the rest at the foot.
struct OFSmallEntry: View {
    var scene: OFDayScene

    var body: some View {
        let snap = scene.snap
        let first = snap.tasks.first
        let late = first?.isOverdue(asOf: snap.date) ?? false
        var runs = [OFRun(text: scene.month, font: OFType.serif(11), color: OFInk.ink, tracking: 1.3, smallCaps: 12, breakAfter: true)]
        if let first {
            runs.append(OFRun(text: first.text, font: OFType.serif(12.5), color: late ? OFInk.rubric : OFInk.ink))
        } else if snap.taskError != nil {
            runs.append(OFRun(text: "The tasks could not be fetched.", font: OFType.italic(12), color: OFInk.rubric))
        } else {
            runs.append(OFRun(text: "Nothing due; a clear page.", font: OFType.italic(12), color: OFInk.inkSoft))
        }
        return VStack(alignment: .leading, spacing: 1) {
            OFParagraph(initial: OFRun(text: String(scene.day), font: OFType.serif(48), color: OFInk.initial),
                        runs: runs, lineHeight: 13, space: 3.4, initialLines: 3, initialGap: 5,
                        maxLines: 3, justify: false)
            HStack(spacing: 4) {
                if let error = snap.taskError {
                    Text(first == nil ? error : "cached · \(error)")
                        .font(OFType.italic(9)).foregroundStyle(OFInk.rubric)
                        .lineLimit(1).truncationMode(.tail)
                        .layoutPriority(-1)
                } else if let first, let due = Mock.dueLabel(first, now: snap.date) {
                    Text(due).font(OFType.italic(10)).foregroundStyle(late ? OFInk.rubric : OFInk.inkSoft)
                }
                Spacer(minLength: 2)
                if snap.tasks.count > 1 {
                    Text("+\(snap.tasks.count - 1) more").font(OFType.italic(10)).foregroundStyle(OFInk.inkSoft).fixedSize()
                }
            }
            .frame(height: 12)
        }
    }
}
