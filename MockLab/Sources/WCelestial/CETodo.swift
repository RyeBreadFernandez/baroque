import SwiftUI

// The To-do widget: a star chart. A navy plate in a slim brass bezel, worked with faint coordinate arcs, a gold
// hairline frame, the count in an engraved medallion in the corner, and the tasks as the chart's stars: each entry has
// its star (larger for higher priority, copper when late), the stars joined as a constellation, gold rules between.

struct CETodo: View {
    var snapshot: DaySnapshot
    var family: Family

    private var size: CGSize { Mock.size(family) }
    private var shown: Int { family == .medium ? 4 : 2 }

    var body: some View {
        let tasks = Array(snapshot.tasks.prefix(shown))
        ZStack {
            CELacquer(family: family)
            CEChartLines(size: size)
            CEFrame(size: size)
            header
            if let error = snapshot.taskError {
                message(title: "Tasks unavailable", detail: error, warn: true)
            } else if tasks.isEmpty {
                message(title: "A clear sky.", detail: "Nothing due today.", warn: false)
            } else {
                list(tasks)
            }
            CEBrassRim(outer: Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: Mock.cornerRadius, style: .continuous),
                       inner: Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 5, dy: 5), cornerRadius: Mock.cornerRadius - 5, style: .continuous),
                       crest: Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 2.5, dy: 2.5), cornerRadius: Mock.cornerRadius - 2.5, style: .continuous),
                       center: CGPoint(x: size.width / 2, y: size.height / 2), radius: max(size.width, size.height) / 2 + 30,
                       plate: Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 5, dy: 5), cornerRadius: Mock.cornerRadius - 5, style: .continuous),
                       size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Header: the title and the count medallion

    private var header: some View {
        let c = CGPoint(x: size.width - 31, y: 31)
        let count = snapshot.taskError == nil ? snapshot.tasks.count : 0
        return ZStack {
            Text("TASKS")
                .font(CEFont.caps(10))
                .tracking(2.4)
                .foregroundStyle(CEGold.type)
                .ceInlay()
                .fixedSize()
                .position(x: 22 + 23, y: 28)
            Canvas { ctx, _ in
                let sheen = CEGold.sheen(CGRect(x: c.x - 16, y: c.y - 16, width: 32, height: 32))
                ctx.fill(CEEngrave.circle(c, 14.5), with: .color(CE.navyDeep.opacity(0.55)))
                CEEngrave.line(ctx, CEEngrave.circle(c, 14.5), width: 0.9, shading: sheen)
                CEEngrave.line(ctx, CEEngrave.circle(c, 12.6), width: 0.4, shading: sheen, light: 0, groove: 0.5)
                var ticks = Path()
                for i in 0..<24 {
                    let a = Double(i) * 15
                    ticks.move(to: CEEngrave.point(c, 14.5, a))
                    ticks.addLine(to: CEEngrave.point(c, i % 6 == 0 ? 17.6 : 16.2, a))
                }
                ctx.stroke(ticks, with: sheen, lineWidth: 0.45)
            }
            Text(snapshot.taskError == nil ? "\(count)" : "–")
                .font(CEFont.numeral(count > 9 ? 15 : 19))
                .foregroundStyle(CEGold.leaf)
                .ceRaisedLeaf()
                .fixedSize()
                .position(x: c.x, y: c.y + 0.5)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: List

    private func list(_ tasks: [TaskItem]) -> some View {
        let medium = family == .medium
        let top: CGFloat = medium ? 44 : 45
        let row: CGFloat = medium ? 26 : 50
        let starX: [CGFloat] = [27, 33, 26, 32]
        return ZStack(alignment: .topLeading) {
            // The constellation and the rules.
            Canvas { ctx, _ in
                let sheen = CEGold.sheen(CGRect(origin: .zero, size: size))
                var joins = Path()
                for i in tasks.indices {
                    let p = CGPoint(x: starX[i], y: top + row * CGFloat(i) + 9)
                    if i == 0 { joins.move(to: p) } else { joins.addLine(to: p) }
                }
                ctx.stroke(joins, with: .color(CE.gold.opacity(0.45)), style: StrokeStyle(lineWidth: 0.5, dash: [1.2, 1.8]))
                var rules = Path()
                for i in 1..<max(1, tasks.count) {
                    let y = top + row * CGFloat(i) - (medium ? 3 : 5)
                    rules.move(to: CGPoint(x: 44, y: y))
                    rules.addLine(to: CGPoint(x: size.width - 18, y: y))
                }
                CEEngrave.line(ctx, rules, width: 0.45, shading: sheen, light: 0.4, groove: 0.5)
                for (i, t) in tasks.enumerated() {
                    let p = CGPoint(x: starX[i], y: top + row * CGFloat(i) + 9)
                    let late = t.isOverdue(asOf: snapshot.date)
                    let r: CGFloat = 3.2 + CGFloat(max(0, t.priority.rawValue - 2)) * 0.9
                    let color = late ? CE.copperInk : CE.goldBright
                    CEEngrave.glow(ctx, p, r * 2.6, color, late ? 0.5 : 0.35)
                    ctx.fill(CEEngrave.star(p, r, points: 8, pinch: 0.2).offsetBy(dx: 0.3, dy: 0.5), with: .color(CE.ink.opacity(0.8)))
                    ctx.fill(CEEngrave.star(p, r, points: 8, pinch: 0.2), with: .color(color))
                }
            }
            ForEach(Array(tasks.enumerated()), id: \.offset) { i, t in
                entry(t, medium: medium)
                    .frame(width: size.width - 44 - 18, alignment: .leading)
                    .offset(x: 44, y: top + row * CGFloat(i) + (medium ? 0 : -1))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder
    private func entry(_ t: TaskItem, medium: Bool) -> some View {
        let late = t.isOverdue(asOf: snapshot.date)
        let due = Mock.dueLabel(t, now: snapshot.date)?.uppercased()
        let ink = late ? CE.copperInk : CE.parchment
        if medium {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(t.text)
                    .font(CEFont.text(15))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                Spacer(minLength: 0)
                if let due {
                    Text(due)
                        .font(CEFont.caps(8.5))
                        .tracking(0.6)
                        .foregroundStyle(late ? CE.copperInk : CE.goldMuted)
                        .fixedSize()
                }
            }
            .ceInlay()
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(t.text)
                    .font(CEFont.text(13.5))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                if let due {
                    Text(due)
                        .font(CEFont.caps(8))
                        .tracking(0.6)
                        .foregroundStyle(late ? CE.copperInk : CE.goldMuted)
                }
            }
            .ceInlay()
        }
    }

    private func message(title: String, detail: String, warn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(CEFont.italic(family == .medium ? 18 : 15))
                .foregroundStyle(CE.parchment)
            Text(detail)
                .font(CEFont.text(family == .medium ? 12.5 : 11.5))
                .foregroundStyle(warn ? CE.copperInk : CE.goldMuted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .ceInlay()
        .frame(width: size.width - 40, alignment: .leading)
        .position(x: size.width / 2, y: size.height / 2 + 12)
    }
}

/// Faint coordinate lines of a star chart: arcs of declination about a pole below the card and hour lines from it.
struct CEChartLines: View {
    var size: CGSize

    var body: some View {
        Canvas { ctx, _ in
            let pole = CGPoint(x: size.width * 0.62, y: size.height * 2.6)
            var p = Path()
            var r = size.height * 1.75
            while r < size.height * 2.75 {
                p.addArc(center: pole, radius: r, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                r += size.height * 0.24
            }
            for a in stride(from: 236.0, through: 304.0, by: 8) {
                p.move(to: CEEngrave.point(pole, size.height * 1.6, a))
                p.addLine(to: CEEngrave.point(pole, size.height * 2.9, a))
            }
            ctx.stroke(p, with: .color(CE.gold.opacity(0.11)), lineWidth: 0.5)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// The plate's gold hairline frame inside the bezel, with small stars at the corners.
struct CEFrame: View {
    var size: CGSize

    var body: some View {
        Canvas { ctx, _ in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 9.5, dy: 9.5)
            let sheen = CEGold.sheen(CGRect(origin: .zero, size: size))
            CEEngrave.line(ctx, Path(roundedRect: rect, cornerRadius: Mock.cornerRadius - 9.5, style: .continuous), width: 0.6, shading: sheen)
            CEEngrave.line(ctx, Path(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: Mock.cornerRadius - 11.5, style: .continuous),
                           width: 0.3, shading: sheen, light: 0, groove: 0.4)
        }
        .frame(width: size.width, height: size.height)
    }
}
