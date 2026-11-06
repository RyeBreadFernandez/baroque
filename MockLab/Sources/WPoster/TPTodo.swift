import SwiftUI

// The To-do widget: a railway ticket laid on the poster's deep ground. A vermilion header, the tasks printed in
// rows over a faint guilloche, late ones punched by the conductor, and a stub past the perforation with the count in
// a rubber stamp.

struct TPTodo: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        let size = Mock.size(family)
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let inks = TPInks(clock: clock, condition: .clear)
        ZStack {
            TPGround(inks: inks, family: family)
            ticket(inks)
                .rotationEffect(.degrees(family == .small ? -2.2 : -1.3))
        }
        .frame(width: size.width, height: size.height)
        .overlay(TPPaper())
    }

    // MARK: Content

    private var tasks: [TaskItem] { snapshot.tasks }
    private func isLate(_ t: TaskItem) -> Bool { t.isOverdue(asOf: snapshot.date) }

    private var errorLine: String? {
        guard let e = snapshot.taskError else { return nil }
        return "Not refreshed: \(e)"
    }

    @ViewBuilder
    private func ticket(_ inks: TPInks) -> some View {
        switch family {
        case .small: smallTicket(inks)
        default: mediumTicket(inks)
        }
    }

    private func mediumTicket(_ inks: TPInks) -> some View {
        let w: CGFloat = 326, h: CGFloat = 140, stub: CGFloat = 84
        let shown = Array(tasks.prefix(3))
        return ZStack(alignment: .topLeading) {
            TPTicketCard(size: CGSize(width: w, height: h), perforation: w - stub, inks: inks)
            // Header over the main part.
            HStack(alignment: .firstTextBaseline) {
                Text("TO DO").font(TPType.display(15)).tracking(2.2)
                Spacer()
                Text(TPTodo.dateLine(snapshot.date)).font(TPType.bold(8.5)).tracking(1.6)
            }
            .foregroundStyle(inks.paper.color)
            .padding(.horizontal, 10)
            .frame(width: w - stub - 8, height: 24)
            .background(TPHeaderInk(inks: inks))
            .padding(.leading, 4).padding(.top, 4)
            VStack(alignment: .leading, spacing: 0) {
                if shown.isEmpty {
                    TPEmptyLine(inks: inks, error: errorLine)
                } else {
                    ForEach(Array(shown.enumerated()), id: \.offset) { i, t in
                        TPTaskRow(task: t, due: Mock.dueLabel(t, now: snapshot.date), late: isLate(t), inks: inks, size: 12)
                        if i < shown.count - 1 { TPDottedRule(ink: inks.caption).padding(.vertical, 4) }
                    }
                    Spacer(minLength: 0)
                    footer(inks, more: tasks.count - shown.count)
                }
            }
            .padding(.leading, 14).padding(.trailing, 12)
            .padding(.top, 36).padding(.bottom, 8)
            .frame(width: w - stub, height: h, alignment: .topLeading)
            // The stub.
            VStack(spacing: 2) {
                Text("TERRA").font(TPType.bold(8)).tracking(2.4)
                    .foregroundStyle(inks.caption.color)
                Spacer(minLength: 0)
                TPCountStamp(count: tasks.count, inks: inks, diameter: 62)
                Spacer(minLength: 0)
                Text("ADMIT ONE").font(TPType.condensed(8)).tracking(1.4)
                    .foregroundStyle(inks.caption.color.opacity(0.75))
            }
            .padding(.vertical, 12)
            .frame(width: stub, height: h)
            .offset(x: w - stub)
        }
        .frame(width: w, height: h)
    }

    private func smallTicket(_ inks: TPInks) -> some View {
        let w: CGFloat = 146, h: CGFloat = 146, stubH: CGFloat = 40
        let shown = Array(tasks.prefix(2))
        return ZStack(alignment: .topLeading) {
            TPTicketCard(size: CGSize(width: w, height: h), perforation: h - stubH, inks: inks, horizontal: true)
            Text("TO DO").font(TPType.display(13)).tracking(2)
                .foregroundStyle(inks.paper.color)
                .padding(.horizontal, 8)
                .frame(width: w - 8, height: 20, alignment: .leading)
                .background(TPHeaderInk(inks: inks))
                .padding(.leading, 4).padding(.top, 4)
            VStack(alignment: .leading, spacing: 0) {
                if shown.isEmpty {
                    TPEmptyLine(inks: inks, error: errorLine, compact: true)
                } else {
                    ForEach(Array(shown.enumerated()), id: \.offset) { i, t in
                        TPTaskRow(task: t, due: Mock.dueLabel(t, now: snapshot.date), late: isLate(t), inks: inks, size: 10.5, stacked: true)
                        if i < shown.count - 1 { TPDottedRule(ink: inks.caption).padding(.vertical, 3) }
                    }
                }
            }
            .padding(.leading, 10).padding(.trailing, 8).padding(.top, 30)
            .frame(width: w, height: h - stubH, alignment: .topLeading)
            HStack(alignment: .center, spacing: 0) {
                Group {
                    if errorLine != nil, !shown.isEmpty {
                        Text("SYNC FAILED").foregroundStyle(inks.accent.color)
                    } else if tasks.count > shown.count {
                        Text("+ \(tasks.count - shown.count) MORE").foregroundStyle(inks.caption.color)
                    } else {
                        Text("ADMIT ONE").foregroundStyle(inks.caption.color.opacity(0.75))
                    }
                }
                .font(TPType.bold(8)).tracking(1.2)
                .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.leading, 10).padding(.trailing, 50)
            .frame(width: w, height: stubH)
            .offset(y: h - stubH)
            TPCountStamp(count: tasks.count, inks: inks, diameter: 54)
                .offset(x: w - 58, y: h - stubH - 14)
        }
        .frame(width: w, height: h)
    }

    @ViewBuilder
    private func footer(_ inks: TPInks, more: Int) -> some View {
        if let e = errorLine {
            Text(e).font(TPType.bold(8.5)).tracking(0.6).foregroundStyle(inks.accent.color).lineLimit(1)
        } else if more > 0 {
            Text("+ \(more) MORE ON THE LIST").font(TPType.bold(8)).tracking(1.6).foregroundStyle(inks.caption.color.opacity(0.8))
        }
    }

    static func dateLine(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date).uppercased()
    }
}

/// One task as the ticket prints it: the title, its due label typed in on the right (or under it), late ones in
/// vermilion with a conductor's punch hole.
struct TPTaskRow: View {
    var task: TaskItem
    var due: String?
    var late: Bool
    var inks: TPInks
    var size: CGFloat
    var stacked = false

    var body: some View {
        let ink = inks.caption.color
        if stacked {
            HStack(alignment: .top, spacing: 5) {
                TPPunch(late: late, inks: inks).padding(.top, size * 0.3)
                VStack(alignment: .leading, spacing: 0) {
                    Text(task.text).font(TPType.label(size)).foregroundStyle(ink).lineLimit(1)
                    if let due {
                        Text(due).font(.custom("AmericanTypewriter-Condensed", fixedSize: size * 0.82))
                            .foregroundStyle(late ? inks.accent.color : ink.opacity(0.72))
                    }
                }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TPPunch(late: late, inks: inks).alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 0.5 }
                Text(task.text).font(TPType.label(size)).foregroundStyle(ink).lineLimit(1)
                Spacer(minLength: 6)
                if let due {
                    Text(due).font(.custom("AmericanTypewriter-Condensed", fixedSize: size * 0.88))
                        .foregroundStyle(late ? inks.accent.color : ink.opacity(0.72))
                        .fixedSize()
                }
            }
        }
    }
}

/// A punch hole for late tasks (the ground shows through), a small printed diamond for the rest.
struct TPPunch: View {
    var late: Bool
    var inks: TPInks

    var body: some View {
        ZStack {
            if late {
                Circle().fill(inks.sky[0].color)
                    .overlay(Circle().stroke(inks.accent.color, lineWidth: 1.1).padding(-1.2))
                    .frame(width: 5.5, height: 5.5)
            } else {
                Rectangle().fill(inks.caption.color.opacity(0.75))
                    .frame(width: 3.6, height: 3.6)
                    .rotationEffect(.degrees(45))
            }
        }
        .frame(width: 8, height: 8)
    }
}

struct TPEmptyLine: View {
    var inks: TPInks
    var error: String?
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let error {
                Text("Tasks unavailable").font(TPType.bold(compact ? 10.5 : 12)).foregroundStyle(inks.accent.color)
                Text(error).font(TPType.label(compact ? 8.5 : 9.5)).foregroundStyle(inks.caption.color)
                    .lineLimit(compact ? 3 : 2).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Nothing due.").font(TPType.bold(compact ? 11 : 13)).foregroundStyle(inks.caption.color)
                Text("A clear day for the mountain.").font(TPType.label(compact ? 8.5 : 10)).foregroundStyle(inks.caption.color.opacity(0.8))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, compact ? 2 : 6)
    }
}

struct TPDottedRule: View {
    var ink: TPRGB
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            p.move(to: CGPoint(x: 0, y: size.height / 2))
            p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            ctx.stroke(p, with: .color(ink.color.opacity(0.45)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [0.1, 2.6]))
        }
        .frame(height: 2)
    }
}

/// The vermilion header strip, printed with a halftone fading into its lower edge.
struct TPHeaderInk: View {
    var inks: TPInks
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(inks.accent.color))
            let dots = tpHalftone(in: CGRect(origin: .zero, size: size), pitch: 2.6) { q in
                2.6 * 0.5 * max(0, (q.y / size.height - 0.45) / 0.55)
            }
            ctx.fill(dots, with: .color(inks.discShade.mix(inks.accent, 0.3).color))
        }
    }
}

/// The ticket's card: cream stock with rounded corners, two half-round notches at the perforation and the
/// perforation itself, a faint guilloche across it, and the shadow it casts on the poster's ground.
struct TPTicketCard: View {
    var size: CGSize
    var perforation: CGFloat     // x of the perforation (or y when `horizontal`)
    var inks: TPInks
    var horizontal = false

    var body: some View {
        let shape = TPTicketShape(perforation: perforation, horizontal: horizontal)
        Canvas { ctx, sz in
            let rect = CGRect(origin: .zero, size: sz)
            let card = shape.path(in: rect)
            ctx.fill(card, with: .color(inks.paper.mix(.init(0xFFF8E6), 0.25).color))
            ctx.drawLayer { l in
                l.clip(to: card)
                // Guilloche: two families of fine waves, the ticket printer's security tint.
                var waves = Path()
                var y: CGFloat = 4
                while y < sz.height {
                    waves.move(to: CGPoint(x: 0, y: y))
                    var x: CGFloat = 0
                    while x <= sz.width {
                        waves.addLine(to: CGPoint(x: x, y: y + 1.6 * sin(x / 7 + y / 9)))
                        x += 2
                    }
                    y += 5
                }
                l.stroke(waves, with: .color(inks.sky[2].color.opacity(0.1)), lineWidth: 0.5)
                // The perforation.
                var perf = Path()
                if horizontal {
                    perf.move(to: CGPoint(x: 8, y: perforation)); perf.addLine(to: CGPoint(x: sz.width - 8, y: perforation))
                } else {
                    perf.move(to: CGPoint(x: perforation, y: 8)); perf.addLine(to: CGPoint(x: perforation, y: sz.height - 8))
                }
                l.stroke(perf, with: .color(inks.sky[0].color.opacity(0.55)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [0.1, 3.4]))
                // A thin printed border inside the edge.
                l.stroke(Path(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 4), with: .color(inks.caption.color.opacity(0.35)), lineWidth: 0.6)
            }
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
        .shadow(color: .black.opacity(0.5), radius: 2.5, x: 1.2, y: 2.4)
    }
}

struct TPTicketShape: Shape {
    var perforation: CGFloat
    var horizontal = false

    func path(in rect: CGRect) -> Path {
        var card = Path(roundedRect: rect, cornerRadius: 6)
        let r: CGFloat = 6
        var notches = Path()
        if horizontal {
            notches.addEllipse(in: CGRect(x: rect.minX - r, y: perforation - r, width: 2 * r, height: 2 * r))
            notches.addEllipse(in: CGRect(x: rect.maxX - r, y: perforation - r, width: 2 * r, height: 2 * r))
        } else {
            notches.addEllipse(in: CGRect(x: perforation - r, y: rect.minY - r, width: 2 * r, height: 2 * r))
            notches.addEllipse(in: CGRect(x: perforation - r, y: rect.maxY - r, width: 2 * r, height: 2 * r))
        }
        card = card.subtracting(notches)
        return card
    }
}

/// The count in a rubber stamp: two rings, the number, "TO DO" above and "TASKS" below, in vermilion that
/// printed unevenly, struck at a slant.
struct TPCountStamp: View {
    var count: Int
    var inks: TPInks
    var diameter: CGFloat

    var body: some View {
        let d = diameter
        ZStack {
            Circle().stroke(lineWidth: max(1.6, d * 0.045))
            Circle().stroke(lineWidth: max(0.6, d * 0.014)).padding(d * 0.075)
            Text("\(count)").font(TPType.display(d * (count >= 10 ? 0.36 : 0.42)))
                .offset(y: -d * 0.09)
            Text(count == 1 ? "TASK" : "TASKS").font(TPType.bold(8)).tracking(0.8)
                .offset(y: d * 0.22)
        }
        .foregroundStyle(inks.accent.color)
        .frame(width: d, height: d)
        .mask {
            Mock.texture("weather-poster/stamp").resizable().frame(width: d * 1.2, height: d * 1.2)
        }
        .rotationEffect(.degrees(-14))
        .opacity(0.92)
    }
}

/// The ground under the ticket: the poster's deep sky ink with a halftone band and the litho grain.
struct TPGround: View {
    var inks: TPInks
    var family: Family

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(inks.sky[0].color))
            let y0 = size.height * 0.55, depth = size.height * 0.45
            let lower = CGRect(x: 0, y: y0, width: size.width, height: depth)
            ctx.fill(Path(lower), with: .color(inks.sky[1].color))
            let dots = tpHalftone(in: CGRect(x: 0, y: y0 - 3, width: size.width, height: depth * 0.6), pitch: 3.2) { q in
                3.2 * 0.62 * max(0, 1 - (q.y - y0) / (depth * 0.55))
            }
            ctx.fill(dots, with: .color(inks.sky[0].color))
        }
        .overlay {
            Mock.texture("weather-poster/litho")
                .renderingMode(.template)
                .resizable(resizingMode: .tile)
                .foregroundStyle(inks.paper.color)
                .opacity(0.5)
        }
    }
}
