import SwiftUI

// Day widgets: a journal page with the date written in, the weather on a taped sketch card,
// the week on a strip of washi tape, a watercolour mountain study, and an inked checklist.

// MARK: - Shared pieces

struct DateHeading: View {
    var date: Date
    var numeral: CGFloat
    var weekday: CGFloat
    var month: CGFloat
    var monthStyle: String = "MMMM"

    var body: some View {
        VStack(alignment: .leading, spacing: -numeral * 0.12) {
            Text(FJDates.string(date, "EEEE"))
                .font(FJ.italic(weekday))
                .foregroundStyle(FJ.inkSoft)
            HStack(alignment: .firstTextBaseline, spacing: numeral * 0.12) {
                Text(FJDates.string(date, "d"))
                    .font(FJ.serifSemi(numeral))
                    .foregroundStyle(FJ.ink)
                VStack(alignment: .leading, spacing: -month * 0.25) {
                    Text(FJDates.string(date, monthStyle))
                        .font(FJ.hand(month))
                        .foregroundStyle(FJ.blueInk)
                    Text(FJDates.string(date, "yyyy"))
                        .font(FJ.italic(month * 0.74))
                        .foregroundStyle(FJ.inkSoft)
                }
            }
        }
        .fixedSize()
    }
}

struct DueMark: View {
    var task: TaskItem
    var size: CGFloat

    var body: some View {
        if let label = Mock.dueLabel(task) {
            if task.isOverdue(asOf: Mock.now) {
                Text(label)
                    .font(FJ.hand(size))
                    .foregroundStyle(FJ.redPencil)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background { PencilRing(seed: 71).padding(.horizontal, -2).padding(.vertical, -3) }
                    .fixedSize()
            } else if task.isDueToday(asOf: Mock.now) {
                Text(label)
                    .font(FJ.hand(size))
                    .foregroundStyle(FJ.ceruleanDeep)
                    .background(alignment: .bottom) {
                        HandUnderline(color: FJ.cerulean, seed: UInt64(task.lineNumber), pencil: true, width: 1.4)
                            .frame(height: 4).offset(y: 1)
                    }
                    .fixedSize()
            } else {
                Text(label)
                    .font(FJ.hand(size))
                    .foregroundStyle(FJ.inkSoft)
                    .fixedSize()
            }
        }
    }
}

struct PriorityMark: View {
    var priority: TaskPriority
    var size: CGFloat
    var seed: UInt64

    var body: some View {
        switch priority {
        case .highest:
            HStack(spacing: -size * 0.3) {
                StarDoodle(wash: FJ.sienna, seed: seed).frame(width: size, height: size)
                StarDoodle(wash: FJ.sienna, seed: seed &+ 1).frame(width: size * 0.8, height: size * 0.8).offset(y: -size * 0.2)
            }
        case .high:
            StarDoodle(wash: FJ.ochre, seed: seed).frame(width: size, height: size)
        case .medium:
            StarDoodle(wash: .clear, ink: FJ.pencil, seed: seed).frame(width: size * 0.8, height: size * 0.8).opacity(0.85)
        default:
            EmptyView()
        }
    }
}

struct TaskRow: View {
    var task: TaskItem
    var font: CGFloat
    var dueSize: CGFloat
    var lines: Int = 1
    var showDue: Bool = true

    var body: some View {
        HStack(alignment: lines > 1 ? .top : .center, spacing: 6) {
            InkBox(color: FJ.blueInk, seed: UInt64(task.lineNumber) &* 11, width: 1.0)
                .frame(width: font * 0.86, height: font * 0.86)
                .padding(.top, lines > 1 ? font * 0.3 : 0)
            Text(task.text)
                .font(FJ.note(font))
                .foregroundStyle(FJ.blueInk)
                .lineLimit(lines)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            PriorityMark(priority: task.priority, size: font * 0.9, seed: UInt64(task.lineNumber) &* 5)
            Spacer(minLength: 4)
            if showDue { DueMark(task: task, size: dueSize) }
        }
    }
}

/// Faint hand-ruled pencil guide lines.
struct PencilRules: View {
    var pitch: CGFloat
    var count: Int
    var first: CGFloat
    var seed: UInt64

    var body: some View {
        Canvas { ctx, size in
            for i in 0..<count {
                let y = first + CGFloat(i) * pitch
                let pts = Brush.wobbly([CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y + 0.6)], amplitude: 0.35, step: 6, seed: seed &+ UInt64(i))
                ctx.pencil(Brush.smooth(pts), color: FJ.pencil, width: 0.6, seed: seed &+ UInt64(i), strength: 0.45)
            }
        }
    }
}

struct WeekStrip: View {
    var date: Date
    var tape: Color = Color(hex: 0xCBD5B0)

    var body: some View {
        let days = FJDates.week(of: date)
        let cal = Calendar.current
        ZStack {
            WashiTape(color: tape, ink: FJ.sapDeep, pattern: .grid, seed: 61)
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                    DayCell(day: d, today: cal.isDate(d, inSameDayAs: date))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 26)
        }
    }
}

struct DayCell: View {
    var day: Date
    var today: Bool

    var body: some View {
        VStack(spacing: -3) {
            Text(String(FJDates.string(day, "EEEEE")))
                .font(FJ.italicSemi(10.5))
                .foregroundStyle(today ? FJ.ink : FJ.inkSoft)
            Text(FJDates.string(day, "d"))
                .font(FJ.hand(17))
                .foregroundStyle(today ? FJ.ink : FJ.blueInk.opacity(0.85))
        }
        .background {
            if today {
                ZStack {
                    WashDab(color: FJ.ochre, rim: FJ.sienna, seed: 88, opacity: 0.9).frame(width: 34, height: 34)
                    Canvas { ctx, size in
                        let pts = Brush.loopPoints(in: CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2), turns: 1.12, seed: 9)
                        ctx.ink(pts, color: FJ.ink, width: 1.0, seed: 3, taperIn: 0.1, taperOut: 0.3, opacity: 0.85)
                    }
                    .frame(width: 33, height: 33)
                }
            }
        }
    }
}

struct WeatherCardContent: View {
    var weather: WeatherSnapshot?
    var temp: CGFloat = 34

    var body: some View {
        if let w = weather {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 3) {
                    WeatherSketch(symbol: w.symbolName).frame(width: temp * 0.95, height: temp * 0.95)
                    Text("\(Int(w.temperature.rounded()))°")
                        .font(FJ.hand(temp))
                        .foregroundStyle(FJ.ink)
                }
                Text(w.label)
                    .font(FJ.italic(13))
                    .foregroundStyle(FJ.ink)
                    .padding(.top, -2)
                Text("H \(Int(w.high.rounded()))°  ·  L \(Int(w.low.rounded()))°")
                    .font(FJ.note(11))
                    .foregroundStyle(FJ.blueInk)
                HStack(spacing: 3) {
                    HorizonSun(rising: true, seed: 3).frame(width: 13, height: 10)
                    Text(Mock.time(w.sunrise))
                    HorizonSun(rising: false, seed: 4).frame(width: 13, height: 10).padding(.leading, 5)
                    Text(Mock.time(w.sunset))
                }
                .font(FJ.note(11))
                .foregroundStyle(FJ.inkSoft)
            }
        } else {
            Text("weather unavailable")
                .font(FJ.italic(12))
                .foregroundStyle(FJ.inkSoft)
        }
    }
}

struct Taped<Content: View>: View {
    var seed: UInt64
    var rotation: Double
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            CardStock(seed: seed)
            content
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Large

struct DayLarge: View {
    var snap: DaySnapshot
    static let size = Mock.size(.large)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in
                Page.draw(ctx, size: size, paper: ctx.resolve(Mock.texture(Family.large.paperTexture)), seed: 3)
                Landscape.paint(ctx, scene: Self.scene, in: CGRect(x: 0, y: 0, width: size.width, height: 150),
                                tooth: FJTex.tooth(ctx))
            }
            DateHeading(date: snap.date, numeral: 58, weekday: 17, month: 19)
                .offset(x: 18, y: 13)
            Taped(seed: 21, rotation: 2.4) {
                WeatherCardContent(weather: snap.weather)
                    .frame(width: 112, alignment: .leading)
            }
            .frame(width: 130, height: 108)
            .position(x: 268, y: 68)
            WashiTape(color: Color(hex: 0xB9D2E2), ink: FJ.ceruleanDeep, pattern: .dots, seed: 5)
                .frame(width: 46, height: 15).rotationEffect(.degrees(-38)).position(x: 210, y: 20)
            WashiTape(color: Color(hex: 0xB9D2E2), ink: FJ.ceruleanDeep, pattern: .dots, seed: 6)
                .frame(width: 46, height: 15).rotationEffect(.degrees(-38)).position(x: 330, y: 118)
            WeekStrip(date: snap.date)
                .frame(width: 368, height: 38)
                .rotationEffect(.degrees(-0.8))
                .position(x: 174, y: 148)
            FernSketch(seed: 19, pinnae: 17, base: CGPoint(x: 1.04, y: 0.62), tip: CGPoint(x: 0.0, y: 0.40),
                       bend: CGPoint(x: 0.55, y: 0.78), pinnaScale: 0.10)
                .frame(width: 200, height: 40)
                .position(x: 256, y: 344)
            WashiTape(color: Color(hex: 0xE9C9A6), ink: FJ.sienna, pattern: .stripes, seed: 18)
                .frame(width: 34, height: 12).rotationEffect(.degrees(-80)).position(x: 322, y: 346)
            checklist
                .frame(width: Self.size.width - 32, alignment: .topLeading)
                .offset(x: 16, y: 172)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    private var checklist: some View {
        let shown = Array(snap.tasks.prefix(5))
        let more = snap.tasks.count - shown.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("To do")
                    .font(FJ.italicSemi(18))
                    .foregroundStyle(FJ.ink)
                    .background(alignment: .bottom) { HandUnderline(seed: 2).frame(height: 5).offset(y: 2).padding(.horizontal, -2) }
                Spacer()
                Text("\(snap.tasks.count) open")
                    .font(FJ.italic(13))
                    .foregroundStyle(FJ.inkSoft)
            }
            .frame(height: 26)
            ForEach(shown) { t in
                TaskRow(task: t, font: 14.5, dueSize: 14)
                    .frame(height: 26)
            }
            if more > 0 {
                Text("+\(more) more")
                    .font(FJ.hand(13))
                    .foregroundStyle(FJ.pencil)
                    .frame(height: 18)
            }
        }
        .background(alignment: .topLeading) {
            PencilRules(pitch: 26, count: shown.count, first: 26 + 24, seed: 40)
                .frame(height: 26 * CGFloat(shown.count + 1) + 4)
                .padding(.leading, 18)
        }
    }

    static let scene = Scenery(ridges: [
        Sceneries.far([CGPoint(x: -0.02, y: 0.72), CGPoint(x: 0.16, y: 0.66), CGPoint(x: 0.32, y: 0.70), CGPoint(x: 0.45, y: 0.50),
                       CGPoint(x: 0.53, y: 0.42), CGPoint(x: 0.62, y: 0.50), CGPoint(x: 0.72, y: 0.36), CGPoint(x: 0.86, y: 0.46),
                       CGPoint(x: 1.02, y: 0.38)], seed: 11, opacity: 0.6),
        Sceneries.mid([CGPoint(x: -0.02, y: 0.84), CGPoint(x: 0.18, y: 0.77), CGPoint(x: 0.34, y: 0.70), CGPoint(x: 0.44, y: 0.50),
                       CGPoint(x: 0.53, y: 0.19), CGPoint(x: 0.6, y: 0.36), CGPoint(x: 0.67, y: 0.27), CGPoint(x: 0.76, y: 0.54),
                       CGPoint(x: 0.88, y: 0.46), CGPoint(x: 1.02, y: 0.62)], snowline: 0.42, seed: 12, ink: 1.2),
        Sceneries.near([CGPoint(x: -0.02, y: 0.9), CGPoint(x: 0.2, y: 0.80), CGPoint(x: 0.4, y: 0.87), CGPoint(x: 0.6, y: 0.78),
                        CGPoint(x: 0.8, y: 0.85), CGPoint(x: 1.02, y: 0.79)], trees: 16, seed: 13)
    ], sky: CGRect(x: 0.26, y: 0.0, width: 0.5, height: 0.62), skyOpacity: 0.72, seed: 14,
       birds: CGRect(x: 0.33, y: 0.12, width: 0.12, height: 0.12))
}

// MARK: - Medium (an open spread: date, weather and a study on the left leaf; the list on the right)

struct DayMedium: View {
    var snap: DaySnapshot
    static let size = Mock.size(.medium)
    static let fold: CGFloat = 124

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in
                Page.draw(ctx, size: size, paper: ctx.resolve(Mock.texture(Family.medium.paperTexture)), seed: 4, gutter: false)
                Landscape.paint(ctx, scene: Self.scene, in: CGRect(x: 0, y: 58, width: Self.fold + 4, height: 106),
                                tooth: FJTex.tooth(ctx))
                Spread.fold(ctx, x: Self.fold, height: size.height)
            }
            DateHeading(date: snap.date, numeral: 40, weekday: 13.5, month: 15, monthStyle: "MMM")
                .offset(x: 16, y: 13)
            compactWeather
                .position(x: 64, y: 116)
            checklist
                .frame(width: Self.size.width - Self.fold - 30, alignment: .topLeading)
                .offset(x: Self.fold + 14, y: 12)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    private var compactWeather: some View {
        Taped(seed: 33, rotation: -2.5) {
            HStack(spacing: 1) {
                WeatherSketch(symbol: snap.weather?.symbolName ?? "cloud.fill").frame(width: 22, height: 22)
                Text(snap.weather.map { "\(Int($0.temperature.rounded()))°" } ?? "--")
                    .font(FJ.hand(23))
                    .foregroundStyle(FJ.ink)
                VStack(alignment: .leading, spacing: -4) {
                    Text(snap.weather.map { "H \(Int($0.high.rounded()))°" } ?? "")
                    Text(snap.weather.map { "L \(Int($0.low.rounded()))°" } ?? "")
                }
                .font(FJ.note(10.5))
                .foregroundStyle(FJ.blueInk)
                .padding(.leading, 3)
            }
        }
        .frame(width: 104, height: 40)
        .overlay(alignment: .top) {
            WashiTape(color: Color(hex: 0xE9C9A6), ink: FJ.sienna, pattern: .stripes, seed: 8)
                .frame(width: 36, height: 12).rotationEffect(.degrees(5)).offset(x: 4, y: -7)
        }
    }

    private var checklist: some View {
        let shown = Array(snap.tasks.prefix(3))
        let more = snap.tasks.count - shown.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("To do")
                    .font(FJ.italicSemi(15))
                    .foregroundStyle(FJ.ink)
                    .background(alignment: .bottom) { HandUnderline(seed: 2).frame(height: 5).offset(y: 2).padding(.horizontal, -2) }
                Spacer()
                Text("\(snap.tasks.count) open")
                    .font(FJ.italic(12))
                    .foregroundStyle(FJ.inkSoft)
            }
            .frame(height: 20)
            ForEach(shown) { t in
                StackedTaskRow(task: t, font: 13.5, dueSize: 12.5)
                    .frame(height: 35, alignment: .top)
            }
            if more > 0 {
                Text("+\(more) more")
                    .font(FJ.hand(12.5))
                    .foregroundStyle(FJ.pencil)
                    .frame(height: 14)
            }
        }
    }

    static let scene = Scenery(ridges: [
        Sceneries.far([CGPoint(x: -0.02, y: 0.36), CGPoint(x: 0.2, y: 0.24), CGPoint(x: 0.42, y: 0.34), CGPoint(x: 0.62, y: 0.16),
                       CGPoint(x: 0.82, y: 0.28), CGPoint(x: 1.04, y: 0.22)], seed: 21, opacity: 0.6),
        Sceneries.mid([CGPoint(x: -0.02, y: 0.56), CGPoint(x: 0.18, y: 0.42), CGPoint(x: 0.36, y: 0.26), CGPoint(x: 0.5, y: 0.38),
                       CGPoint(x: 0.7, y: 0.12), CGPoint(x: 0.84, y: 0.3), CGPoint(x: 1.04, y: 0.46)], snowline: 0.32, seed: 22, ink: 1.0),
        Sceneries.near([CGPoint(x: -0.02, y: 0.86), CGPoint(x: 0.3, y: 0.76), CGPoint(x: 0.6, y: 0.84), CGPoint(x: 1.04, y: 0.74)],
                       trees: 7, seed: 23, treeHeight: 8)
    ], sky: CGRect(x: 0.1, y: 0.0, width: 0.9, height: 0.5), skyOpacity: 0.5, seed: 24)
}

/// Task text on one line with the due mark tucked beneath, for narrow columns.
struct StackedTaskRow: View {
    var task: TaskItem
    var font: CGFloat
    var dueSize: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            InkBox(color: FJ.blueInk, seed: UInt64(task.lineNumber) &* 11, width: 1.0)
                .frame(width: font * 0.86, height: font * 0.86)
                .padding(.top, font * 0.62)
            VStack(alignment: .leading, spacing: task.isOverdue(asOf: Mock.now) ? -1 : -4) {
                HStack(spacing: 4) {
                    Text(task.text)
                        .font(FJ.note(font))
                        .foregroundStyle(FJ.blueInk)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    PriorityMark(priority: task.priority, size: font * 0.9, seed: UInt64(task.lineNumber) &* 5)
                }
                DueMark(task: task, size: dueSize)
                    .padding(.leading, task.isOverdue(asOf: Mock.now) ? 0 : 1)
            }
        }
    }
}

enum Spread {
    /// The fold of an open book: both leaves curve down into the gutter, with sewing thread at the centre.
    static func fold(_ ctx: GraphicsContext, x: CGFloat, height: CGFloat) {
        var c = ctx
        c.blendMode = .multiply
        let l: CGFloat = 26, r: CGFloat = 14
        let span = l + r
        let at = l / span
        c.fill(Path(CGRect(x: x - l, y: 0, width: span, height: height)),
               with: .linearGradient(Gradient(stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: Color(hex: 0xD9C8A8).opacity(0.5), location: at * 0.55),
                    .init(color: Color(hex: 0xA48B66).opacity(0.55), location: at * 0.88),
                    .init(color: Color(hex: 0x6E5A40).opacity(0.7), location: at),
                    .init(color: Color(hex: 0xA48B66).opacity(0.45), location: at + (1 - at) * 0.18),
                    .init(color: Color(hex: 0xE2D4B8).opacity(0.35), location: at + (1 - at) * 0.55),
                    .init(color: .white.opacity(0), location: 1)]),
                                     startPoint: CGPoint(x: x - l, y: 0), endPoint: CGPoint(x: x + r, y: 0)))
        c.blendMode = .screen
        c.fill(Path(CGRect(x: x + 4, y: 0, width: 10, height: height)),
               with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.16), .white.opacity(0)]),
                                     startPoint: CGPoint(x: x + 4, y: 0), endPoint: CGPoint(x: x + 14, y: 0)))
        c.blendMode = .normal
        c.fill(Path(CGRect(x: x - 0.3, y: 0, width: 0.6, height: height)), with: .color(Color(hex: 0x4E3C28).opacity(0.45)))
        var y: CGFloat = 22
        while y < height - 12 {
            var p = Path()
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y + 10))
            c.stroke(p.offsetBy(dx: 0.4, dy: 0.4), with: .color(Color(hex: 0x4E3C28).opacity(0.35)), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
            c.stroke(p, with: .color(Color(hex: 0xEFE3C6)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            y += 34
        }
    }
}

// MARK: - Small

struct DaySmall: View {
    var snap: DaySnapshot
    static let size = Mock.size(.small)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in
                Page.draw(ctx, size: size, paper: ctx.resolve(Mock.texture(Family.small.paperTexture)), seed: 5)
                Landscape.paint(ctx, scene: Self.scene, in: CGRect(x: 0, y: 26, width: size.width, height: 78),
                                tooth: FJTex.tooth(ctx))
            }
            VStack(alignment: .leading, spacing: -6) {
                Text(FJDates.string(snap.date, "EEE"))
                    .font(FJ.italic(14))
                    .foregroundStyle(FJ.inkSoft)
                Text(FJDates.string(snap.date, "d"))
                    .font(FJ.serifSemi(40))
                    .foregroundStyle(FJ.ink)
            }
            .offset(x: 16, y: 13)
            if let w = snap.weather {
                HStack(spacing: 1) {
                    WeatherSketch(symbol: w.symbolName).frame(width: 22, height: 22)
                    Text("\(Int(w.temperature.rounded()))°")
                        .font(FJ.hand(22))
                        .foregroundStyle(FJ.ink)
                }
                .frame(width: Self.size.width - 32, alignment: .trailing)
                .offset(x: 16, y: 14)
            }
            firstTask
                .frame(width: Self.size.width - 30, alignment: .topLeading)
                .offset(x: 15, y: 98)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    @ViewBuilder private var firstTask: some View {
        if let t = snap.tasks.first {
            VStack(alignment: .leading, spacing: 1) {
                TaskRow(task: t, font: 13, dueSize: 12, lines: 2, showDue: false)
                HStack(spacing: 6) {
                    DueMark(task: t, size: 12.5)
                    Spacer(minLength: 0)
                    if snap.tasks.count > 1 {
                        Text("+\(snap.tasks.count - 1) more")
                            .font(FJ.hand(12))
                            .foregroundStyle(FJ.pencil)
                    }
                }
                .padding(.leading, 17)
            }
        } else {
            Text("Nothing due. Go outside.")
                .font(FJ.note(13))
                .foregroundStyle(FJ.blueInk)
        }
    }

    static let scene = Scenery(ridges: [
        Sceneries.far([CGPoint(x: -0.02, y: 0.5), CGPoint(x: 0.3, y: 0.30), CGPoint(x: 0.52, y: 0.44), CGPoint(x: 0.74, y: 0.26),
                       CGPoint(x: 1.04, y: 0.42)], seed: 31),
        Sceneries.mid([CGPoint(x: -0.02, y: 0.66), CGPoint(x: 0.3, y: 0.5), CGPoint(x: 0.5, y: 0.26), CGPoint(x: 0.64, y: 0.42),
                       CGPoint(x: 0.78, y: 0.34), CGPoint(x: 1.04, y: 0.6)], snowline: 0.42, seed: 32, ink: 0.9),
        Sceneries.near([CGPoint(x: -0.02, y: 0.82), CGPoint(x: 0.4, y: 0.72), CGPoint(x: 0.7, y: 0.8), CGPoint(x: 1.04, y: 0.7)],
                       trees: 6, seed: 33, treeHeight: 7)
    ], sky: CGRect(x: 0.3, y: 0.0, width: 0.7, height: 0.55), skyOpacity: 0.5, seed: 34)
}
