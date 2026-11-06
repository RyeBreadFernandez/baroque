import SwiftUI

// The To-do widget: a leaf of parchment laid in the same frame, on a deep forest-green ground, with the day's tasks
// written on it in ink: a hand-drawn box for each, the task, and when it is due in italic; late ones in red ink.
//
// Layout (points): the page sits 5-6 pt inside the window (medium 316x134 at 16,15; small 136x136 at 14,14), its own
// texture cast in a soft shadow on the ground. Type keeps 26 pt from the widget's edges on medium, 24 pt on small.

struct SBTodo: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        let page = pageRect
        SBFramed(family: family) {
            ZStack(alignment: .topLeading) {
                Mock.texture("weather-storybook/ground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: Mock.size(family).width, height: Mock.size(family).height)
                Mock.texture("weather-storybook/page-\(family == .small ? "small" : "medium")")
                    .resizable()
                    .frame(width: page.width, height: page.height)
                    .shadow(color: Color.black.opacity(0.65), radius: 3, x: 0, y: 2)
                    .offset(x: page.minX, y: page.minY)
                SBPageCurl()
                    .fill(LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.18)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: page.width, height: page.height)
                    .offset(x: page.minX, y: page.minY)
            }
        }
        .overlay(alignment: .topLeading) {
            content
                .frame(width: page.width - 2 * pad, height: page.height - 2 * pad, alignment: .topLeading)
                .offset(x: page.minX + pad, y: page.minY + pad - 2)
        }
    }

    private var pageRect: CGRect {
        family == .small ? CGRect(x: 14, y: 14, width: 136, height: 136) : CGRect(x: 16, y: 15, width: 316, height: 134)
    }

    private var pad: CGFloat { family == .small ? 10 : 11 }

    private var tasks: [TaskItem] { snapshot.tasks }

    @ViewBuilder private var content: some View {
        if family == .small { small } else { medium }
    }

    // MARK: Medium

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(title: 15, count: 21)
            SBInkRule(seed: 3)
                .stroke(SBInk.ink.opacity(0.55), lineWidth: 0.7)
                .frame(height: 4)
                .padding(.top, 2)
            if let error = snapshot.taskError, tasks.isEmpty {
                errorLines(error, lines: 3)
            } else if tasks.isEmpty {
                emptyLines
            } else {
                // Four rows (the count in the heading says how many more), or three and the error line.
                let shown = snapshot.taskError == nil ? 4 : 3
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(tasks.prefix(shown).enumerated()), id: \.offset) { i, task in
                        row(task, index: i, font: 13)
                            .frame(height: 19.5)
                    }
                }
                .padding(.top, 2)
                if let error = snapshot.taskError { footer(shown: shown, error: error) }
            }
        }
    }

    // MARK: Small

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(title: 13.5, count: 24)
            SBInkRule(seed: 5)
                .stroke(SBInk.ink.opacity(0.55), lineWidth: 0.7)
                .frame(height: 4)
                .padding(.top, 1)
            if let error = snapshot.taskError, tasks.isEmpty {
                errorLines(error, lines: 3)
            } else if tasks.isEmpty {
                emptyLines
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(tasks.prefix(2).enumerated()), id: \.offset) { i, task in
                        smallRow(task, index: i)
                    }
                }
                .padding(.top, 5)
                Spacer(minLength: 0)
                footer(shown: 2, error: snapshot.taskError)
            }
        }
    }

    // MARK: Pieces

    private func header(title: CGFloat, count: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("To do")
                .font(SBFont.italic(title))
                .foregroundStyle(SBInk.ink)
            if family == .medium {
                Text(SBText.chapter(snapshot.date).uppercased())
                    .font(SBFont.roman(8.5))
                    .tracking(1.8)
                    .foregroundStyle(SBInk.inkFaded)
            }
            Spacer(minLength: 4)
            if !tasks.isEmpty {
                Text("\(tasks.count)")
                    .font(SBFont.roman(count))
                    .foregroundStyle(SBInk.inkRed)
                if family == .medium {
                    Text(tasks.count == 1 ? "task" : "tasks")
                        .font(SBFont.italic(11.5))
                        .foregroundStyle(SBInk.inkFaded)
                }
            }
        }
        .lineLimit(1)
    }

    private func row(_ task: TaskItem, index: Int, font: CGFloat) -> some View {
        let late = task.isOverdue
        return HStack(alignment: .center, spacing: 8) {
            SBInkBox(seed: UInt64(index * 7 + 1))
                .stroke(late ? SBInk.inkRed : SBInk.ink, style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                .frame(width: 10, height: 10)
            Text(task.text)
                .font(SBFont.roman(font))
                .foregroundStyle(SBInk.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            if let due = Mock.dueLabel(task, now: snapshot.date) {
                Text(due)
                    .font(SBFont.italic(11))
                    .foregroundStyle(late ? SBInk.inkRed : SBInk.inkFaded)
                    .fixedSize()
            }
        }
        .overlay(alignment: .bottom) {
            SBInkRule(seed: UInt64(index + 11))
                .stroke(SBInk.rule.opacity(0.32), lineWidth: 0.5)
                .frame(height: 2)
                .padding(.leading, 18)
                .offset(y: 1)
        }
    }

    private func smallRow(_ task: TaskItem, index: Int) -> some View {
        let late = task.isOverdue
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            SBInkBox(seed: UInt64(index * 7 + 1))
                .stroke(late ? SBInk.inkRed : SBInk.ink, style: StrokeStyle(lineWidth: 0.85, lineCap: .round))
                .frame(width: 9, height: 9)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 0.5 }
            VStack(alignment: .leading, spacing: 0) {
                Text(task.text)
                    .font(SBFont.roman(11.5))
                    .foregroundStyle(SBInk.ink)
                    .lineLimit(1)
                if let due = Mock.dueLabel(task, now: snapshot.date) {
                    Text(due)
                        .font(SBFont.italic(10))
                        .foregroundStyle(late ? SBInk.inkRed : SBInk.inkFaded)
                }
            }
        }
    }

    @ViewBuilder private func footer(shown: Int, error: String?) -> some View {
        if let error {
            Text("Couldn't refresh: \(error)")
                .font(SBFont.italic(10))
                .foregroundStyle(SBInk.inkRed)
                .lineLimit(1)
                .padding(.top, 3)
        } else if tasks.count > shown {
            Text("and \(tasks.count - shown) more…")
                .font(SBFont.italic(10.5))
                .foregroundStyle(SBInk.inkFaded)
                .padding(.top, 3)
                .padding(.leading, family == .small ? 15 : 18)
        }
    }

    private var emptyLines: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Nothing to do today.")
                .font(SBFont.italic(family == .small ? 13 : 15))
                .foregroundStyle(SBInk.ink)
            Text("The page is blank; the day is yours.")
                .font(SBFont.italic(family == .small ? 10 : 11.5))
                .foregroundStyle(SBInk.inkFaded)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, family == .small ? 10 : 14)
    }

    private func errorLines(_ error: String, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Couldn't fetch your tasks.")
                .font(SBFont.italic(family == .small ? 12.5 : 14.5))
                .foregroundStyle(SBInk.inkRed)
            Text(error)
                .font(SBFont.roman(family == .small ? 10 : 11.5))
                .foregroundStyle(SBInk.inkFaded)
                .lineLimit(lines)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, family == .small ? 8 : 12)
    }
}

/// A box drawn by hand in ink: four strokes, each a little off true and running just past the corner.
struct SBInkBox: Shape {
    var seed: UInt64

    func path(in r: CGRect) -> Path {
        var rng = SeededRandom(seed)
        func j(_ s: CGFloat) -> CGFloat { CGFloat(rng.signed()) * s }
        let w = r.width * 0.07
        let pts = [CGPoint(x: r.minX + j(w), y: r.minY + j(w)), CGPoint(x: r.maxX + j(w), y: r.minY + j(w)),
                   CGPoint(x: r.maxX + j(w), y: r.maxY + j(w)), CGPoint(x: r.minX + j(w), y: r.maxY + j(w))]
        var p = Path()
        for i in 0..<4 {
            let a = pts[i], b = pts[(i + 1) % 4]
            let over: CGFloat = 0.12 + CGFloat(rng.next()) * 0.1
            let s = CGPoint(x: a.x - (b.x - a.x) * over * 0.4, y: a.y - (b.y - a.y) * over * 0.4)
            let e = CGPoint(x: b.x + (b.x - a.x) * over, y: b.y + (b.y - a.y) * over)
            let mid = CGPoint(x: (s.x + e.x) / 2 + j(r.width * 0.05), y: (s.y + e.y) / 2 + j(r.width * 0.05))
            p.move(to: s)
            p.addQuadCurve(to: e, control: mid)
        }
        return p
    }
}

/// A ruled line drawn by hand: level, but not quite.
struct SBInkRule: Shape {
    var seed: UInt64

    func path(in r: CGRect) -> Path {
        var rng = SeededRandom(seed)
        var p = Path()
        let n = 5
        p.move(to: CGPoint(x: r.minX, y: r.midY + CGFloat(rng.signed()) * 0.5))
        for i in 1...n {
            let x = r.minX + r.width * CGFloat(i) / CGFloat(n)
            let cx = x - r.width / CGFloat(n) / 2
            p.addQuadCurve(to: CGPoint(x: x, y: r.midY + CGFloat(rng.signed()) * 0.5),
                           control: CGPoint(x: cx, y: r.midY + CGFloat(rng.signed()) * 0.9))
        }
        return p
    }
}

/// The page's lower-right corner lifting a little off the ground: a shade across its corner.
struct SBPageCurl: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX - 3, y: r.maxY - 26))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 30, y: r.maxY - 3), control: CGPoint(x: r.maxX - 8, y: r.maxY - 8))
        p.addLine(to: CGPoint(x: r.maxX - 3, y: r.maxY - 3))
        p.closeSubpath()
        return p
    }
}
