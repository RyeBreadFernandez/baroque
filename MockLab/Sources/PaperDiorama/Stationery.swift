import SwiftUI

// Stationery tucked into the diorama: index cards, clips, tape, punched holes, tags, bunting, buttons.

// MARK: - Index card

/// A cream index card standing proud of the scene, its lower-right corner folded over.
struct IndexCard: View {
    var seed: UInt64 = 11
    var dogEar: CGFloat = 13
    var lift: CGFloat = 3.4
    var stock: Color = PD.cream

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Sheet(shape: CardCut(seed: seed, dogEar: dogEar), color: stock, seed: seed, grain: 0.75,
                  lightTop: -0.2, lightBottom: 1.6, edge: 1, tooth: 0.6, curl: 0.10)
            if dogEar > 0 {
                Sheet(shape: DogEarFlap(), color: PD.creamFold, seed: seed &+ 1, grain: 0.6, edge: 0.7, tooth: 0.7)
                    .frame(width: dogEar, height: dogEar)
                    .lifted(1.1)
            }
        }
        .lifted(lift)
    }
}

/// The faint printed rules of an index card: blue lines, and the red one under the heading.
struct CardRule: View {
    var red = false
    var bleed: CGFloat = 12
    var body: some View {
        Rectangle()
            .fill(red ? Color(hex: 0xE58A86).opacity(0.85) : Color(hex: 0x8CC0DD).opacity(0.55))
            .frame(height: red ? 1.1 : 0.8)
            .padding(.horizontal, -bleed)
    }
}

// MARK: - Clip and tape

struct ClipWire: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        let x1 = r.minX + 1.2, x2 = r.minX + w - 1.2, x3 = r.minX + 3.6, x4 = r.minX + w - 3.6
        let r1 = (x4 - x3) / 2, r2 = (x2 - x3) / 2, r3 = (x2 - x1) / 2
        let k: CGFloat = 1.333
        let yInnerBottom = r.minY + h - 9.5, yTop = r.minY + 5, yOuterBottom = r.minY + h - 5
        var p = Path()
        p.move(to: CGPoint(x: x4, y: r.minY + h * 0.3))
        p.addLine(to: CGPoint(x: x4, y: yInnerBottom))
        p.addCurve(to: CGPoint(x: x3, y: yInnerBottom), control1: CGPoint(x: x4, y: yInnerBottom + k * r1), control2: CGPoint(x: x3, y: yInnerBottom + k * r1))
        p.addLine(to: CGPoint(x: x3, y: yTop))
        p.addCurve(to: CGPoint(x: x2, y: yTop), control1: CGPoint(x: x3, y: yTop - k * r2), control2: CGPoint(x: x2, y: yTop - k * r2))
        p.addLine(to: CGPoint(x: x2, y: yOuterBottom))
        p.addCurve(to: CGPoint(x: x1, y: yOuterBottom), control1: CGPoint(x: x2, y: yOuterBottom + k * r3), control2: CGPoint(x: x1, y: yOuterBottom + k * r3))
        p.addLine(to: CGPoint(x: x1, y: r.minY + h * 0.2))
        return p
    }
}

/// A plastic-coated paper clip with a little shine along the wire.
struct PaperClip: View {
    var color: Color = PD.coral
    var body: some View {
        ZStack {
            ClipWire().stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            ClipWire().stroke(PD.shadow.opacity(0.25), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .mask(LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing))
            ClipWire().stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
                .offset(x: -0.5, y: -0.3)
        }
        .frame(width: 12, height: 36)
        .lifted(1.3)
    }
}

/// A torn strip of washi tape: translucent, printed with little dots.
struct WashiTape: View {
    var color: Color = PD.mint
    var width: CGFloat = 46
    var angle: Double = -8
    var seed: UInt64 = 3

    var body: some View {
        ZStack {
            Sheet(shape: TapeCut(seed: seed), color: color, seed: seed &+ 20, grain: 0.5, edge: 0.5)
            DotPrint(color: .white.opacity(0.75)).mask(TapeCut(seed: seed))
        }
        .frame(width: width, height: 15)
        .opacity(0.9)
        .lifted(0.7, opacity: 0.8)
        .rotationEffect(.degrees(angle))
    }
}

struct DotPrint: View {
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 3, row = 0
            while y < size.height {
                var x: CGFloat = row % 2 == 0 ? 3 : 7
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(color))
                    x += 8
                }
                y += 4.5; row += 1
            }
        }
    }
}

// MARK: - Task marks

/// A punched hole for the checkbox (it shows the dark forest behind the card), ringed by a
/// coloured hole-reinforcement sticker that carries the priority.
struct PunchHole: View {
    var ring: Color?
    var d: CGFloat = 9

    var body: some View {
        ZStack {
            if let ring {
                Sheet(shape: RingCut(width: 3.6), color: ring, seed: 9, grain: 0.5, edge: 0.6)
                    .frame(width: d + 7.4, height: d + 7.4)
                    .lifted(0.6)
            }
            Circle()
                .fill(LinearGradient(colors: [PD.holeTop, PD.holeLow], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().stroke(PD.shadow.opacity(0.7), lineWidth: 2.4).blur(radius: 0.7).offset(y: 1.1).mask(Circle()))
                .overlay(Circle().trim(from: 0.08, to: 0.42).stroke(Color.white.opacity(0.75), lineWidth: 0.8))
                .frame(width: d, height: d)
        }
        .frame(width: d + 8, height: d + 8)
    }
}

/// A little luggage tag for a due date.
struct TagChip: View {
    var text: String
    var fill: Color
    var ink: Color
    var size: CGFloat = 10.5

    var body: some View {
        Text(text)
            .font(.pdAvenir(size, "Bold"))
            .foregroundStyle(ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.leading, 10)
            .padding(.trailing, 5)
            .padding(.vertical, 1.5)
            .background(Sheet(shape: TagCut(), color: fill, seed: 5, grain: 0.6, edge: 0.7).lifted(0.9))
    }
}

struct DueMark: View {
    var task: TaskItem
    var size: CGFloat = 10.5

    var body: some View {
        if let label = Mock.dueLabel(task) {
            if task.isOverdue(asOf: Mock.now) {
                TagChip(text: label, fill: PD.coralDeep, ink: .white, size: size)
            } else if task.isDueToday(asOf: Mock.now) {
                TagChip(text: label, fill: PD.butter, ink: PD.ink, size: size)
            } else {
                Text(label)
                    .font(.pdAvenir(size + 0.5, "DemiBoldItalic"))
                    .foregroundStyle(PD.inkSoft)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// A round sticker with a number on it (task count).
struct CountSticker: View {
    var count: Int
    var body: some View {
        Text("\(count)")
            .font(.pdRounded(12, .heavy))
            .foregroundStyle(PD.ink)
            .frame(width: 22, height: 22)
            .background(
                ZStack {
                    Sheet(shape: Sunburst(rays: 10, inner: 0.84), color: PD.butter, seed: 41, edge: 0.7)
                    Circle().stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 0.7, dash: [1.6, 1.6])).padding(3.4)
                }
                .lifted(1)
            )
    }
}

// MARK: - Lettering

/// Letters cut from coloured stock and stood off the backdrop: fiber, a lit top edge, a cast shadow.
struct PaperLetters: View {
    var text: String
    var font: Font
    var color: Color
    var lift: CGFloat = 2
    var seed: UInt64 = 3

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .overlay(Fiber(seed: seed).mask(Text(text).font(font)).blendMode(.overlay))
            .compositingGroup()
            .shadow(color: .white.opacity(0.8), radius: 0, x: 0, y: -0.8)
            .lifted(lift)
    }
}

// MARK: - Bunting week strip

struct Bunting: View {
    var days: [Date]
    var today: Date
    var width: CGFloat
    var y0: CGFloat
    var sag: CGFloat
    var flag = CGSize(width: 36, height: 38)

    var body: some View {
        let inset: CGFloat = 16 + flag.width / 2
        let step = (width - inset * 2) / CGFloat(max(1, days.count - 1))
        ZStack(alignment: .topLeading) {
            TwineLine(y0: y0, sag: sag)
                .stroke(PD.twine, style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                .lifted(1.2)
            ForEach(days.indices, id: \.self) { i in
                let x = inset + CGFloat(i) * step
                let isToday = Calendar.current.isDate(days[i], inSameDayAs: today)
                Pennant(date: days[i], isToday: isToday, index: i, size: flag)
                    .rotationEffect(.radians(Double(atan(slope(x)))), anchor: .top)
                    .position(x: x, y: y(x) + flag.height / 2 - 1.5)
            }
        }
        .frame(width: width)
    }

    private func y(_ x: CGFloat) -> CGFloat {
        let t = (x - width / 2) / (width / 2)
        return y0 + sag * (1 - t * t)
    }

    private func slope(_ x: CGFloat) -> CGFloat {
        -2 * sag * (x - width / 2) / ((width / 2) * (width / 2))
    }
}

struct TwineLine: Shape {
    var y0: CGFloat
    var sag: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX - 4, y: y0 - sag * 0.1))
        p.addQuadCurve(to: CGPoint(x: r.maxX + 4, y: y0 - sag * 0.1), control: CGPoint(x: r.midX, y: y0 + sag * 2))
        return p
    }
}

struct Pennant: View {
    var date: Date
    var isToday: Bool
    var index: Int
    var size: CGSize

    private static let stocks: [Color] = [PD.butter, PD.mint, PD.peach, PD.skyStock, Color(hex: 0xF6D3E0), PD.butterLight, PD.mint]

    var body: some View {
        let stock = isToday ? PD.coralDeep : Self.stocks[index % Self.stocks.count]
        let ink = isToday ? Color.white : PD.ink
        let h = isToday ? size.height + 6 : size.height
        let w = isToday ? size.width + 4 : size.width
        VStack(spacing: -1) {
            Text(Fmt.weekdayLetter(date))
                .font(.pdAvenir(isToday ? 10 : 9, "Bold"))
                .foregroundStyle(ink.opacity(0.85))
            Text(Fmt.dayNumber(date))
                .font(.pdRounded(isToday ? 17 : 15, .heavy))
                .foregroundStyle(ink)
        }
        .padding(.top, 4)
        .frame(width: w, height: h, alignment: .top)
        .background(
            ZStack(alignment: .top) {
                Sheet(shape: PennantCut(notch: 8), color: stock, seed: UInt64(index + 50), grain: 0.8, edge: 0.9)
                Rectangle().fill(PD.shadow.opacity(0.18)).frame(height: 2.2)   // hem folded over the twine
            }
        )
        .lifted(isToday ? 2.4 : 1.8)
    }
}

// MARK: - Next quote button

/// A 30 pt button built from two stacked paper discs with a cut-paper refresh arrow.
struct NextButton: View {
    var body: some View {
        ZStack {
            Sheet(shape: Sunburst(rays: 14, inner: 0.9), color: PD.coralDeep, seed: 91, edge: 0.8)
                .frame(width: 30, height: 30)
                .lifted(2)
            Sheet(shape: Circle(), color: PD.butter, seed: 92, edge: 0.8)
                .frame(width: 22, height: 22)
                .lifted(1)
            RefreshArrow()
                .fill(PD.coralDeep)
                .frame(width: 13, height: 13)
                .lifted(0.6)
        }
        .frame(width: 30, height: 30)
    }
}

struct RefreshArrow: Shape {
    /// A clockwise arc with a gap at the top and the arrowhead on its leading end.
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY + r.height * 0.04)
        let rad = r.width * 0.34
        let start = -50.0, end = 235.0      // degrees, increasing = clockwise on screen
        func point(_ deg: Double) -> CGPoint {
            let a = deg * .pi / 180
            return CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad)
        }
        var arc = Path()
        arc.move(to: point(start))
        for i in 1...40 { arc.addLine(to: point(start + (end - start) * Double(i) / 40)) }
        var p = arc.strokedPath(StrokeStyle(lineWidth: r.width * 0.17, lineCap: .round))
        let a = end * .pi / 180
        let base = point(end)
        let tx = CGFloat(-sin(a)), ty = CGFloat(cos(a))     // direction of travel
        let nx = CGFloat(cos(a)), ny = CGFloat(sin(a))      // outward
        let s = r.width * 0.26
        var head = Path()
        head.move(to: CGPoint(x: base.x + tx * s * 1.1, y: base.y + ty * s * 1.1))
        head.addLine(to: CGPoint(x: base.x + nx * s - tx * s * 0.25, y: base.y + ny * s - ty * s * 0.25))
        head.addLine(to: CGPoint(x: base.x - nx * s - tx * s * 0.25, y: base.y - ny * s - ty * s * 0.25))
        head.closeSubpath()
        p.addPath(head)
        return p
    }
}

// MARK: - Formatting

enum Fmt {
    static func string(_ d: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: d)
    }
    static func weekdayLetter(_ d: Date) -> String { String(string(d, "EEEEE")) }
    static func dayNumber(_ d: Date) -> String { string(d, "d") }

    /// Monday-start week containing `date`.
    static func week(of date: Date) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    static func temp(_ t: Double) -> String { "\(Int(t.rounded()))°" }
}
