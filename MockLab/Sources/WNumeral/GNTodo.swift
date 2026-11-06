import SwiftUI

// The To-do widget: the count stands in the painting as the temperature does in the Weather widget, a big thin
// numeral in the fog behind the spruce, and the tasks lie on a pane of frosted, painted-mist glass beside it (medium)
// or under it (small) — iOS 26's clear widgets, painted — the misty Matterhorn seen blurred through the frost. Each
// task has a round hollow checkbox; late tasks turn warm amber, ring and all.

struct GNTodoView: View {
    var snap: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .small: GNTodoSmall(snap: snap)
        default: GNTodoMedium(snap: snap)
        }
    }
}

/// The painting with the count standing in it.
struct GNTodoGround: View {
    var snap: DaySnapshot
    var canvas: GNCanvas
    var spec: GNNumeralSpec

    var body: some View {
        GNScene(canvas: canvas, numeral: GNTodoWords.count(snap), spec: spec, clock: SkyClock(now: snap.date, weather: snap.weather),
                condition: SkyCondition(code: snap.weather?.code), phase: MoonPhase(date: snap.date))
    }
}

enum GNTodoWords {
    static func count(_ snap: DaySnapshot) -> String {
        if snap.tasks.isEmpty && snap.taskError != nil { return "\u{2013}" }
        return String(snap.tasks.count)
    }

    static func late(_ snap: DaySnapshot) -> Int { snap.tasks.filter { $0.isOverdue(asOf: snap.date) }.count }
}

/// A round hollow checkbox: a thin ring, amber when the task is late.
struct GNCheck: View {
    var late: Bool
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .strokeBorder(late ? GNInk.late : GNInk.fog.opacity(0.85), lineWidth: late ? 1.2 : 0.9)
            .background(Circle().fill(GNInk.shade.opacity(0.12)))
            .frame(width: size, height: size)
            .shadow(color: GNInk.shade.opacity(0.35), radius: 1, y: 0.5)
    }
}

/// One task: ring, title in the serif and its due label.
struct GNTaskRow: View {
    var task: TaskItem
    var now: Date
    var size: CGFloat = 13
    var stacked = false   // due label under the title (small) rather than at the end of the line (medium)

    var body: some View {
        let late = task.isOverdue(asOf: now)
        let due = Mock.dueLabel(task, now: now)
        let dueColor = late ? GNInk.late : (task.isDueToday(asOf: now) ? GNInk.soft : GNInk.faint)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            GNCheck(late: late, size: size * 0.92)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + size * 0.32 }
            if stacked {
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.text)
                        .font(GNType.serif(size))
                        .foregroundStyle(late ? GNInk.late : GNInk.fog)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(due ?? "no date").font(GNType.label(8.5)).tracking(0.3).foregroundStyle(dueColor)
                }
            } else {
                Text(task.text)
                    .font(GNType.serif(size))
                    .foregroundStyle(late ? GNInk.late : GNInk.fog)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                if let due {
                    Text(due).font(GNType.label(9.5)).tracking(0.3).foregroundStyle(dueColor).fixedSize()
                }
            }
        }
    }
}

/// A dotted rule between rows, as on the reminders card.
struct GNDots: View {
    var body: some View {
        Line()
            .stroke(GNInk.fog.opacity(0.28), style: StrokeStyle(lineWidth: 0.7, lineCap: .round, dash: [0.1, 3]))
            .frame(height: 1)
    }

    struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}

/// The empty and error lines.
struct GNTodoNote: View {
    var snap: DaySnapshot
    var size: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if snap.tasks.isEmpty {
                Text(snap.taskError == nil ? "Nothing due." : "No tasks to show.")
                    .font(GNType.word(size + 1)).foregroundStyle(GNInk.fog)
                if snap.taskError == nil {
                    Text("A quiet day in the fog.").font(GNType.word(size - 1)).foregroundStyle(GNInk.soft)
                }
            }
            if let error = snap.taskError {
                GNErrorLine(message: error, size: size - 2.5)
            }
        }
    }
}

struct GNErrorLine: View {
    var message: String
    var size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "exclamationmark.circle").font(.system(size: size, weight: .regular))
            Text("Couldn't refresh \u{00B7} \(message)").font(GNType.label(size)).lineLimit(2)
        }
        .foregroundStyle(GNInk.late)
    }
}

/// "TO DO" in spaced capitals and, when any are, the late count in amber.
struct GNTodoHeader: View {
    var snap: DaySnapshot

    var body: some View {
        let late = GNTodoWords.late(snap)
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("TO DO").gnCaps(8.5, GNInk.fog, tracking: 2.4)
            if late > 0 {
                Text("\(late) late").font(GNType.word(11.5)).foregroundStyle(GNInk.late)
            }
        }
        .lineLimit(1)
        .fixedSize()
    }
}

// MARK: - Medium

/// The count in the painting on the left, under "TO DO"; four tasks on a pane of frosted glass on the right, parted
/// by dotted rules.
struct GNTodoMedium: View {
    var snap: DaySnapshot

    static let card = CGRect(x: 120, y: 8, width: 220, height: 148)
    static let rows = 4

    var body: some View {
        let light = GNLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: SkyCondition(code: snap.weather?.code))
        let ground = GNTodoGround(snap: snap, canvas: .medium, spec: GNCanvas.medium.numeral)
        ZStack(alignment: .topLeading) {
            ground
            GNTodoHeader(snap: snap)
                .gnOnSky()
                .offset(x: 16, y: 16)
            GNGlass(rect: Self.card, radius: 16, light: light, blur: 7, veil: 0.22, smoke: 0.2) { ground }
            VStack(alignment: .leading, spacing: 0) {
                if snap.tasks.isEmpty {
                    Spacer(minLength: 0)
                    GNTodoNote(snap: snap, size: 13)
                    Spacer(minLength: 0)
                } else {
                    let shown = Array(snap.tasks.prefix(Self.rows))
                    ForEach(Array(shown.enumerated()), id: \.offset) { i, t in
                        if i > 0 { GNDots().padding(.leading, 20) }
                        GNTaskRow(task: t, now: snap.date, size: 13)
                            .frame(height: 26)
                    }
                    Spacer(minLength: 0)
                    let more = snap.tasks.count - shown.count
                    if let error = snap.taskError {
                        GNErrorLine(message: error, size: 8.5).lineLimit(1)
                    } else if more > 0 {
                        Text("+ \(more) more").font(GNType.label(9)).tracking(0.3).foregroundStyle(GNInk.soft)
                            .padding(.leading, 20)
                    }
                }
            }
            .frame(width: Self.card.width - 24, height: Self.card.height - 20, alignment: .topLeading)
            .offset(x: Self.card.minX + 12, y: Self.card.minY + 9)
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }
}

// MARK: - Small

/// The count in the painting at the top left with "TO DO" beside it; the first two tasks on a pane of frosted glass
/// across the foot, which passes in front of the count's foot.
struct GNTodoSmall: View {
    var snap: DaySnapshot

    static let card = CGRect(x: 8, y: 72, width: 148, height: 84)
    static let count = GNNumeralSpec(left: 12, baseline: 78, size: 84)

    var body: some View {
        let light = GNLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: SkyCondition(code: snap.weather?.code))
        let ground = GNTodoGround(snap: snap, canvas: .small, spec: Self.count)
        let digits = CGFloat(GNTodoWords.count(snap).count)
        ZStack(alignment: .topLeading) {
            ground
            GNTodoHeader(snap: snap)
                .gnOnSky()
                .offset(x: max(62, 18 + 0.42 * Self.count.size * digits), y: 22)
            GNGlass(rect: Self.card, radius: 14, light: light, blur: 6, veil: 0.22, smoke: 0.2) { ground }
            VStack(alignment: .leading, spacing: 4) {
                if snap.tasks.isEmpty {
                    Spacer(minLength: 0)
                    GNTodoNote(snap: snap, size: 12)
                    Spacer(minLength: 0)
                } else {
                    ForEach(Array(snap.tasks.prefix(snap.taskError == nil ? 2 : 1).enumerated()), id: \.offset) { i, t in
                        if i > 0 { GNDots().padding(.leading, 19) }
                        GNTaskRow(task: t, now: snap.date, size: 12.5, stacked: true)
                    }
                    if let error = snap.taskError {
                        GNErrorLine(message: error, size: 8).lineLimit(2).padding(.top, 2)
                    }
                }
            }
            .frame(width: 164 - 32, height: Self.card.height - 16, alignment: .topLeading)
            .offset(x: 16, y: Self.card.minY + 8)
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }
}
