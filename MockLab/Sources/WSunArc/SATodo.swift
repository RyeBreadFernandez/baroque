import SwiftUI

// The To-do widget: a serif planner card on the painting's dark ground (a band of dusk sky and fir tips at the top,
// then the near ground in long dark strokes), framed in a gilt hairline. The count is a raised gilt numeral; each
// task has a small copper ring to tick, its title in Baskerville and its due note in the label face; late tasks turn
// peach and their ring holds a peach point. Dashed gilt rules between the rows echo the arc's dashes.

struct SATodo: View {
    var snap: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .small: SATodoSmall(snap: snap)
        default: SATodoMedium(snap: snap)
        }
    }
}

/// The dark ground, glazed for the time of day like the Weather widget (fair-weather glazes: the list does not go
/// grey in the rain), with the gilt hairline frame.
struct SATodoGround: View {
    var name: String
    var snap: DaySnapshot
    /// False on the home screen mock (the user is not a fan of gold frames).
    var framed = true

    var body: some View {
        let light = CoverLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: .clear)
        ZStack {
            SAPaint(lower: Mock.texture("weather-sun-arc/\(name)-lo"), upper: Mock.texture("weather-sun-arc/\(name)-hi"),
                    glow: nil, light: light, center: UnitPoint(x: 0.8, y: -0.1), reach: 300, seed: UInt64(name.count) &* 13)
            CanvasWeave(opacity: 0.8)
            if framed {
                SAGiltFrame(light: light)
                    .padding(7)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A gilt hairline frame cut into the paint: a dark groove with a fine gilt line laid in it, and a small four-point
/// sparkle at the upper right corner, where the light comes from.
struct SAGiltFrame: View {
    var light: CoverLight

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        let gilt = LinearGradient(colors: [light.rim.opacity(0.9), light.gild[1].opacity(0.75), light.gild[2].opacity(0.45),
                                           light.gild[1].opacity(0.6)],
                                  startPoint: .topTrailing, endPoint: .bottomLeading)
        ZStack {
            shape.stroke(CoverInk.shadow.opacity(0.7), lineWidth: 1.8).blur(radius: 0.7).offset(y: 0.5)
            shape.stroke(gilt, lineWidth: 0.6)
            GeometryReader { geo in
                SASparkle(light: light)
                    .frame(width: 9, height: 9)
                    .position(x: geo.size.width - 15, y: 0.3)
            }
        }
    }
}

/// A small four-point gilt sparkle.
struct SASparkle: View {
    var light: CoverLight

    var body: some View {
        ZStack {
            Circle().fill(light.glow.opacity(0.45)).blur(radius: 3).frame(width: 9, height: 9)
            SASparkleShape().fill(LinearGradient(colors: [light.rim, light.gild[1]], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct SASparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * 0.16
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }
}

/// A small copper ring to tick: raised, lit from the upper right, a dark well inside; a peach point when the task is
/// late.
struct SARing: View {
    var late: Bool
    var size: CGFloat = 11

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x120A06), Color(hex: 0x2A1A10)], center: UnitPoint(x: 0.4, y: 0.35),
                                     startRadius: 0, endRadius: size * 0.5))
            Circle()
                .strokeBorder(LinearGradient(colors: [Color(hex: 0xF3C796), Color(hex: 0xC98450), Color(hex: 0x8C4F2B), Color(hex: 0xB9733F)],
                                             startPoint: .topTrailing, endPoint: .bottomLeading),
                              lineWidth: size * 0.13)
            Circle()
                .trim(from: 0.82, to: 0.98)
                .stroke(Color(hex: 0xFFE6C4).opacity(0.85), style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                .padding(size * 0.08)
            if late {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xF7CDB2), CoverInk.peach, Color(hex: 0xB9785A)],
                                         center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.2))
                    .frame(width: size * 0.38, height: size * 0.38)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: CoverInk.shadow.opacity(0.7), radius: 1.2, x: -0.4, y: 0.9)
    }
}

/// A dashed gilt rule, the arc's dashes laid flat.
struct SADashRule: View {
    var light: CoverLight

    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(LinearGradient(colors: [light.gild[1].opacity(0.5), light.gild[2].opacity(0.25), light.gild[2].opacity(0.05)],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 0.6, lineCap: .round, dash: [1.8, 3.2]))
        }
        .frame(height: 1)
    }
}

enum SATasks {
    static func late(_ snap: DaySnapshot) -> Int { snap.tasks.filter { $0.isOverdue(asOf: snap.date) }.count }

    static func due(_ t: TaskItem, _ snap: DaySnapshot) -> String? { Mock.dueLabel(t, now: snap.date) }

    /// The summary turns peach when something is late or the list could not be fetched.
    static func alert(_ snap: DaySnapshot) -> Bool { late(snap) > 0 || (snap.tasks.isEmpty && snap.taskError != nil) }

    static func summary(_ snap: DaySnapshot) -> String {
        if snap.tasks.isEmpty && snap.taskError != nil { return "unavailable" }
        let n = late(snap)
        let today = snap.tasks.filter { $0.isDueToday(asOf: snap.date) }.count
        var parts: [String] = []
        if n > 0 { parts.append("\(n) late") }
        if today > 0 { parts.append("\(today) today") }
        return parts.isEmpty ? (snap.tasks.isEmpty ? "all clear" : "none due today") : parts.joined(separator: " · ")
    }
}

// MARK: - Medium

/// The title and summary at the top left, the gilt count at the top right, then four tasks ruled with gilt dashes.
struct SATodoMedium: View {
    var snap: DaySnapshot
    static let rows = 4

    var body: some View {
        let light = CoverLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: .clear)
        let size = Mock.size(.medium)
        ZStack(alignment: .topLeading) {
            SATodoGround(name: "todo-medium", snap: snap)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("To do").font(SAType.italic(18)).foregroundStyle(CoverInk.cream)
                Text(SATasks.summary(snap)).coverCaps(8, SATasks.alert(snap) ? CoverInk.peach : CoverInk.creamSoft, tracking: 1.6)
            }
            .fixedSize()
            .coverOnSky(0.8)
            .saBaseline(x: 18, y: 33, in: size)
            SAGilt(text: SAWords.numeral(snap.taskError != nil && snap.tasks.isEmpty ? nil : snap.tasks.count, size: 40),
                   light: light, depth: 0.55)
                .saBaseline(x: 331, y: 43, in: size, trailing: true)
            SATaskRows(snap: snap, rows: Self.rows, light: light, size: 13.5, label: 8.5, rowHeight: 23)
                .frame(width: 314)
                .offset(x: 17, y: 50)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Task rows: ring, title (peach when late), due note; dashed rules between; the reason when the list is stale or
/// empty.
struct SATaskRows: View {
    var snap: DaySnapshot
    var rows: Int
    var light: CoverLight
    var size: CGFloat
    var label: CGFloat
    var rowHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snap.tasks.isEmpty {
                SATodoEmpty(snap: snap, size: size + 1, label: label)
                    .padding(.top, 10)
            } else {
                let shown = Array(snap.tasks.prefix(snap.taskError == nil ? rows : rows - 1))
                ForEach(Array(shown.enumerated()), id: \.offset) { i, t in
                    if i > 0 { SADashRule(light: light).padding(.leading, 21) }
                    row(t)
                }
                if let error = snap.taskError {
                    SADashRule(light: light).padding(.leading, 21)
                    Text("cached · \(error)")
                        .coverLabel(label, CoverInk.peach)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: rowHeight)
                        .padding(.leading, 21)
                }
            }
        }
        .coverOnPaint(0.5)
    }

    private func row(_ t: TaskItem) -> some View {
        let late = t.isOverdue(asOf: snap.date)
        let today = t.isDueToday(asOf: snap.date)
        return HStack(alignment: .center, spacing: 10) {
            SARing(late: late, size: 11)
            Text(t.text)
                .font(SAType.serif(size))
                .foregroundStyle(late ? CoverInk.peach : CoverInk.cream)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: 6)
            if let due = SATasks.due(t, snap) {
                Text(due).coverLabel(label, late ? CoverInk.peach : (today ? CoverInk.creamSoft : CoverInk.creamFaint))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(height: rowHeight)
    }
}

/// No tasks: a quiet line, or the reason they could not be fetched.
struct SATodoEmpty: View {
    var snap: DaySnapshot
    var size: CGFloat
    var label: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let error = snap.taskError {
                Text("The tasks could not be fetched.").font(SAType.italic(size)).foregroundStyle(CoverInk.peach)
                    .lineLimit(2)
                Text(error).coverLabel(label, CoverInk.peach).lineLimit(2)
            } else {
                Text("Nothing due today.").font(SAType.italic(size)).foregroundStyle(CoverInk.creamSoft)
                Text("a clear day for the mountains").coverLabel(label)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Small

/// The gilt count and "to do" at the top, then the first two tasks (title over due note) and what is left.
struct SATodoSmall: View {
    var snap: DaySnapshot
    var framed = true

    var body: some View {
        let light = CoverLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: .clear)
        let size = Mock.size(.small)
        ZStack(alignment: .topLeading) {
            SATodoGround(name: "todo-small", snap: snap, framed: framed)
            SAGilt(text: SAWords.numeral(snap.taskError != nil && snap.tasks.isEmpty ? nil : snap.tasks.count, size: 44),
                   light: light, depth: 0.55)
                .saBaseline(x: 16, y: 50, in: size)
            VStack(alignment: .leading, spacing: 1) {
                Text("to do").font(SAType.italic(15)).foregroundStyle(CoverInk.cream)
                Text(SATasks.summary(snap)).coverLabel(8.5, SATasks.alert(snap) ? CoverInk.peach : CoverInk.creamSoft)
            }
            .fixedSize()
            .coverOnSky(0.8)
            .saBaseline(x: snap.tasks.count >= 10 ? 70 : 52, y: 33, in: size)
            SASmallRows(snap: snap, light: light)
                .frame(width: 132, height: 86, alignment: .topLeading)
                .offset(x: 16, y: 62)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

struct SASmallRows: View {
    var snap: DaySnapshot
    var light: CoverLight

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snap.tasks.isEmpty {
                SATodoEmpty(snap: snap, size: 12.5, label: 8.5)
                    .padding(.top, 4)
            } else {
                ForEach(Array(snap.tasks.prefix(2).enumerated()), id: \.offset) { i, t in
                    if i > 0 { SADashRule(light: light).padding(.vertical, 4).padding(.leading, 18) }
                    let late = t.isOverdue(asOf: snap.date)
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        SARing(late: late, size: 10)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.text)
                                .font(SAType.serif(12.5))
                                .foregroundStyle(late ? CoverInk.peach : CoverInk.cream)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(SATasks.due(t, snap) ?? "no date")
                                .coverLabel(8, late ? CoverInk.peach : CoverInk.creamFaint)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    if let error = snap.taskError {
                        Text("cached · \(error)").coverLabel(8, CoverInk.peach).lineLimit(1).truncationMode(.tail)
                    } else if snap.tasks.count > 2 {
                        Text("+ \(snap.tasks.count - 2) more").coverLabel(8, CoverInk.creamFaint)
                    }
                }
                .padding(.leading, 17)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .coverOnPaint(0.5)
    }
}
