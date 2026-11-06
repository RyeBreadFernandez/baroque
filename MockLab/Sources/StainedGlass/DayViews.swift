import SwiftUI

// MARK: - Large

struct DayLarge: View {
    let snap: DaySnapshot
    static let size = Mock.size(.large)
    static let sun = CGPoint(x: 194, y: 52)
    static let lancets = CGRect(x: 16, y: 122, width: 316, height: 42)
    static let panel = CGRect(x: 16, y: 171, width: 316, height: 178)
    static let rowH: CGFloat = 30
    static let gap: CGFloat = 5

    var tasks: [TaskItem] { Array(snap.tasks.prefix(5)) }

    var body: some View {
        let week = Fmt.week(snap.date)
        ZStack(alignment: .topLeading) {
            GlassView(window: Self.window(today: week.today, tasks: tasks))
            DateBlock(date: snap.date, numeral: 60, caps: 13, month: 19)
                .place(CGRect(x: 16, y: 14, width: 150, height: 100))
            if let w = snap.weather {
                WeatherBlock(w: w)
                    .place(CGRect(x: 192, y: 14, width: 140, height: 90), .topTrailing)
            }
            ForEach(0..<7, id: \.self) { i in
                LancetLabel(date: week.days[i], isToday: i == week.today)
                    .place(Self.lancetRect(i).insetBy(dx: 0, dy: 2), .center)
            }
            ForEach(Array(tasks.enumerated()), id: \.offset) { i, t in
                TaskRow(task: t, text: 14, due: 13.5)
                    .place(CGRect(x: Self.panel.minX + 30, y: Self.panel.minY + CGFloat(i) * Self.rowH,
                                  width: Self.panel.width - 42, height: Self.rowH), .leading)
            }
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var footer: some View {
        let y = Self.panel.minY + 5 * Self.rowH
        let more = snap.tasks.count - tasks.count
        return HStack(spacing: 10) {
            if more > 0 {
                Text("+\(more) more").font(SGFont.caps(11)).tracking(1.2)
            }
            Spacer(minLength: 4)
            if let w = snap.weather {
                SunTimes(w: w)
            }
        }
        .foregroundStyle(Ink.grisailleSoft)
        .place(CGRect(x: Self.panel.minX + 16, y: y, width: Self.panel.width - 30, height: Self.panel.maxY - y), .leading)
    }

    static func lancetRect(_ i: Int) -> CGRect {
        let w = (lancets.width - gap * 6) / 7
        return CGRect(x: lancets.minX + CGFloat(i) * (w + gap), y: lancets.minY, width: w, height: lancets.height)
    }

    static func window(today: Int, tasks: [TaskItem]) -> Window {
        var w = Window()
        Scene.sky(&w, size, sun: sun, radii: [27, 50, 92, 150, 240, 600], rays: 14, rotation: -96, seed: 11, horizon: 96)
        Scene.ribbon(&w, through: [CGPoint(x: 74, y: 76), CGPoint(x: 90, y: 60), CGPoint(x: 106, y: 58), CGPoint(x: 122, y: 40)],
                     width: 12, glass: .skyPale, curl: 6, seed: 15)
        Scene.sunRose(&w, center: sun, radius: 27, petals: 10)
        Scene.mountains(&w, MountainRange(
            ridge: [CGPoint(x: -10, y: 124), CGPoint(x: 34, y: 114), CGPoint(x: 76, y: 104), CGPoint(x: 102, y: 90),
                    CGPoint(x: 126, y: 70), CGPoint(x: 150, y: 40), CGPoint(x: 172, y: 66), CGPoint(x: 190, y: 90),
                    CGPoint(x: 210, y: 78), CGPoint(x: 230, y: 62), CGPoint(x: 248, y: 92), CGPoint(x: 300, y: 102),
                    CGPoint(x: 360, y: 110)],
            base: 175, snowline: 84, seed: 3, facet: 24))
        Scene.mountains(&w, MountainRange(
            ridge: [CGPoint(x: -10, y: 128), CGPoint(x: 40, y: 116), CGPoint(x: 88, y: 108), CGPoint(x: 128, y: 118),
                    CGPoint(x: 168, y: 104), CGPoint(x: 206, y: 114), CGPoint(x: 256, y: 104), CGPoint(x: 306, y: 112),
                    CGPoint(x: 360, y: 120)],
            base: 190, lit: .jade, shade: .emerald, low: .pine, seed: 5, facet: 10))
        Scene.border(&w, size, width: 6, segment: 46, seed: 2)
        lancetPanes(&w, today: today)
        let rows = Array(repeating: rowH, count: 5) + [panel.height - 5 * rowH]
        let late = tasks.map { $0.isOverdue(asOf: Mock.now) }
        let alt: [Glass] = [.clear, .clearCeladon, .clear, .clearBlue, .clear]
        let glass: [Glass] = (0..<5).map { i in i < late.count && late[i] ? Glass.clearRose : alt[i] }
        Scene.panel(&w, panel, rows: rows, glass: glass + [.clearAmber], radius: 10, seed: 9)
        for (i, t) in tasks.enumerated() {
            w.jewel(Jewel(center: CGPoint(x: panel.minX + 17, y: panel.minY + CGFloat(i) * rowH + rowH / 2),
                          radius: 5.2, glass: Fmt.bead(t.priority), lead: 1.6, bloom: 0.35))
        }
        w.backlight = sun
        w.backlightRadius = 430
        w.vignette = 0.5
        return w
    }

    static func lancetPanes(_ w: inout Window, today: Int) {
        var rng = SeededRandom(seed: 41)
        let tones: [Glass] = [.cobalt, .violet, .ultramarine, .cobalt, .violet, .emerald, .jade]
        for i in 0..<7 {
            let r = lancetRect(i)
            let isToday = i == today
            var p = Pane(path: Scene.arch(r, head: 13), glass: isToday ? .ruby : tones[i],
                         light: CGPoint(x: r.midX + rng.range(-5...5), y: r.minY + r.height * 0.42))
            p.reach = isToday ? 0.95 : 0.8
            p.texture = isToday ? .hammered : .streaky
            p.texAngle = 90 + Double(rng.range(-25...25))
            p.texShift = CGPoint(x: rng.range(-90...90), y: rng.range(-90...90))
            p.bloom = isToday ? 0.7 : 0
            p.lead = 2.6
            w.add(p, front: true)
        }
    }
}

// MARK: - Medium

struct DayMedium: View {
    let snap: DaySnapshot
    static let size = Mock.size(.medium)
    static let sun = CGPoint(x: 66, y: 118)
    static let panel = CGRect(x: 110, y: 16, width: 222, height: 132)
    static let headH: CGFloat = 29
    static let rowH: CGFloat = 27

    var tasks: [TaskItem] { Array(snap.tasks.prefix(3)) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            GlassView(window: Self.window(tasks: tasks))
            DateBlock(date: snap.date, numeral: 48, caps: 11, month: 16)
                .place(CGRect(x: 16, y: 13, width: 92, height: 92))
            if let w = snap.weather {
                CompactWeather(w: w)
                    .place(CGRect(x: Self.panel.minX + 12, y: Self.panel.minY, width: Self.panel.width - 22, height: Self.headH), .leading)
            }
            ForEach(Array(tasks.enumerated()), id: \.offset) { i, t in
                TaskRow(task: t, text: 13, due: 12, boldHigh: false)
                    .place(CGRect(x: Self.panel.minX + 26, y: Self.panel.minY + Self.headH + CGFloat(i) * Self.rowH,
                                  width: Self.panel.width - 36, height: Self.rowH), .leading)
            }
            let y = Self.panel.minY + Self.headH + 3 * Self.rowH
            let more = snap.tasks.count - tasks.count
            if more > 0 {
                Text("+\(more) more").font(SGFont.caps(10)).tracking(1.1)
                    .foregroundStyle(Ink.grisailleSoft)
                    .place(CGRect(x: Self.panel.minX + 14, y: y, width: Self.panel.width - 28, height: Self.panel.maxY - y), .leading)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    static func window(tasks: [TaskItem]) -> Window {
        var w = Window()
        Scene.sky(&w, size, sun: sun, radii: [18, 36, 66, 112, 190, 500], rays: 12, rotation: -100, seed: 21, horizon: 112)
        Scene.sunRose(&w, center: sun, radius: 18, petals: 8, seed: 4)
        Scene.mountains(&w, MountainRange(
            ridge: [CGPoint(x: -10, y: 132), CGPoint(x: 28, y: 104), CGPoint(x: 62, y: 134), CGPoint(x: 100, y: 102),
                    CGPoint(x: 134, y: 126)],
            base: 200, snowline: 120, seed: 8, facet: 18))
        Scene.mountains(&w, MountainRange(
            ridge: [CGPoint(x: -10, y: 150), CGPoint(x: 36, y: 140), CGPoint(x: 84, y: 148), CGPoint(x: 124, y: 138)],
            base: 200, lit: .jade, shade: .emerald, low: .pine, seed: 9, facet: 8))
        Scene.border(&w, size, width: 5, segment: 44, seed: 12)
        let rows: [CGFloat] = [headH, rowH, rowH, rowH, panel.height - headH - 3 * rowH]
        let late = tasks.map { $0.isOverdue(asOf: Mock.now) }
        var glass: [Glass] = [.clearAmber]
        for i in 0..<3 { glass.append(i < late.count && late[i] ? .clearRose : (i % 2 == 0 ? .clear : .clearCeladon)) }
        glass.append(.clearAmber)
        Scene.panel(&w, panel, rows: rows, glass: glass, radius: 10, seed: 13)
        for (i, t) in tasks.enumerated() {
            w.jewel(Jewel(center: CGPoint(x: panel.minX + 14, y: panel.minY + headH + CGFloat(i) * rowH + rowH / 2),
                          radius: 4.8, glass: Fmt.bead(t.priority), lead: 1.5, bloom: 0.35))
        }
        w.backlight = sun
        w.backlightRadius = 380
        w.vignette = 0.45
        return w
    }
}

// MARK: - Small

struct DaySmall: View {
    let snap: DaySnapshot
    static let size = Mock.size(.small)
    static let sun = CGPoint(x: 90, y: 74)
    static let panel = CGRect(x: 14, y: 94, width: 136, height: 56)
    static let rowH: CGFloat = 38

    var body: some View {
        ZStack(alignment: .topLeading) {
            GlassView(window: Self.window(first: snap.tasks.first))
            VStack(alignment: .leading, spacing: -2) {
                Text(Fmt.string(snap.date, "EEEE").uppercased()).font(SGFont.caps(10.5)).tracking(1.2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Fmt.string(snap.date, "d")).font(SGFont.numeral(38))
                    Text(Fmt.string(snap.date, "MMM")).font(SGFont.italic(15))
                }
            }
            .silverStain()
            .place(CGRect(x: 16, y: 14, width: 100, height: 60))
            if let w = snap.weather {
                VStack(alignment: .trailing, spacing: 0) {
                    Image(systemName: w.symbolName).font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Ink.gold)
                    Text(Fmt.temp(w.temperature)).font(SGFont.numeral(22))
                }
                .silverStain()
                .place(CGRect(x: 98, y: 14, width: 50, height: 50), .topTrailing)
            }
            if let t = snap.tasks.first {
                HStack(alignment: .center, spacing: 0) {
                    Text(t.text).font(SGFont.body(12.5)).foregroundStyle(Ink.grisaille)
                        .lineLimit(2).lineSpacing(-1).truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .place(CGRect(x: Self.panel.minX + 22, y: Self.panel.minY, width: Self.panel.width - 30, height: Self.rowH), .leading)
                footer(t)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private func footer(_ t: TaskItem) -> some View {
        let y = Self.panel.minY + Self.rowH
        let more = snap.tasks.count - 1
        return HStack(spacing: 4) {
            if more > 0 { Text("+\(more) more").font(SGFont.caps(9)).tracking(0.8).foregroundStyle(Ink.grisailleSoft) }
            Spacer(minLength: 2)
            DueLabel(task: t, size: 11)
        }
        .place(CGRect(x: Self.panel.minX + 10, y: y, width: Self.panel.width - 20, height: Self.panel.maxY - y), .leading)
    }

    static func window(first: TaskItem?) -> Window {
        var w = Window()
        Scene.sky(&w, size, sun: sun, radii: [14, 28, 52, 96, 400], rays: 10, rotation: -90, seed: 31, horizon: 70)
        Scene.sunRose(&w, center: sun, radius: 14, petals: 6, seed: 2)
        Scene.mountains(&w, MountainRange(
            ridge: [CGPoint(x: -10, y: 92), CGPoint(x: 16, y: 82), CGPoint(x: 44, y: 66), CGPoint(x: 70, y: 84),
                    CGPoint(x: 90, y: 94), CGPoint(x: 110, y: 82), CGPoint(x: 134, y: 56), CGPoint(x: 176, y: 88)],
            base: 140, snowline: 78, seed: 14, facet: 14))
        Scene.border(&w, size, width: 5, segment: 40, seed: 22)
        let late = first?.isOverdue(asOf: Mock.now) ?? false
        Scene.panel(&w, panel, rows: [rowH, panel.height - rowH], glass: [late ? .clearRose : .clear, .clearAmber], radius: 9, seed: 17)
        if let t = first {
            w.jewel(Jewel(center: CGPoint(x: panel.minX + 12, y: panel.minY + rowH / 2), radius: 4.8,
                          glass: Fmt.bead(t.priority), lead: 1.5, bloom: 0.35))
        }
        w.backlight = CGPoint(x: sun.x, y: sun.y - 10)
        w.backlightRadius = 220
        w.vignette = 0.45
        return w
    }
}

// MARK: - pieces

struct DateBlock: View {
    let date: Date
    var numeral: CGFloat
    var caps: CGFloat
    var month: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: -numeral * 0.1) {
            Text(Fmt.string(date, "EEEE").uppercased()).font(SGFont.caps(caps)).tracking(caps * 0.18)
            Text(Fmt.string(date, "d")).font(SGFont.numeral(numeral))
            Text(Fmt.string(date, "MMMM")).font(SGFont.italic(month))
        }
        .silverStain()
    }
}

struct WeatherBlock: View {
    let w: WeatherSnapshot
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: w.symbolName).font(.system(size: 19, weight: .semibold)).foregroundStyle(Ink.gold)
                Text(Fmt.temp(w.temperature)).font(SGFont.numeral(42))
            }
            Text(w.label).font(SGFont.italic(17))
            Text("H \(Fmt.temp(w.high))   L \(Fmt.temp(w.low))").font(SGFont.bodyBold(12)).tracking(0.6).padding(.top, 2)
        }
        .silverStain()
    }
}

struct CompactWeather: View {
    let w: WeatherSnapshot
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: w.symbolName).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: 0xc27a0c))
            Text(Fmt.temp(w.temperature)).font(SGFont.numeral(17)).foregroundStyle(Ink.grisaille)
            Text(w.label).font(SGFont.italic(13)).foregroundStyle(Ink.grisaille).lineLimit(1)
            Spacer(minLength: 2)
            Text("\(Fmt.temp(w.high)) / \(Fmt.temp(w.low))").font(SGFont.body(11)).foregroundStyle(Ink.grisailleSoft)
        }
    }
}

struct SunTimes: View {
    let w: WeatherSnapshot
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sunrise.fill").font(.system(size: 10))
            Text(Mock.time(w.sunrise)).font(SGFont.body(11))
            Image(systemName: "sunset.fill").font(.system(size: 10)).padding(.leading, 6)
            Text(Mock.time(w.sunset)).font(SGFont.body(11))
        }
        .foregroundStyle(Ink.grisailleSoft)
    }
}

struct LancetLabel: View {
    let date: Date
    let isToday: Bool
    var body: some View {
        VStack(spacing: -1) {
            Text(String(Fmt.string(date, "EEEEE"))).font(SGFont.caps(9)).opacity(isToday ? 1 : 0.85)
            Text(Fmt.string(date, "d")).font(SGFont.numeral(isToday ? 18 : 16))
        }
        .padding(.top, 8)
        .silverStain()
    }
}

struct TaskRow: View {
    let task: TaskItem
    var text: CGFloat
    var due: CGFloat
    var boldHigh = true
    var body: some View {
        HStack(spacing: 8) {
            Text(task.text)
                .font(boldHigh && task.priority >= .high ? SGFont.bodyBold(text) : SGFont.body(text))
                .foregroundStyle(Ink.grisaille)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            DueLabel(task: task, size: due)
        }
    }
}
