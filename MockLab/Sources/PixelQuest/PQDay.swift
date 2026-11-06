import SwiftUI

// The Day widget: the overworld behind the date, a status window for the weather, a road of
// stepping-stone days, and the Quest Log window with the agenda.

enum DayKit {
    static let goldRamp: [C] = [.gold3, .gold3, .gold2, .gold2, .gold1, .gold1, .gold0]
    static let headRamp: [C] = [.gold3, .gold2, .gold2, .gold1]

    static func weekday(_ d: Date) -> String { fmt("EEEE", d).uppercased() }
    static func shortWeekday(_ d: Date) -> String { fmt("EEE", d).uppercased() }
    static func month(_ d: Date) -> String { fmt("MMMM", d).uppercased() }
    static func shortMonth(_ d: Date) -> String { fmt("MMM", d).uppercased() }
    static func dayNumber(_ d: Date) -> String { fmt("d", d) }

    static func fmt(_ f: String, _ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = f
        return df.string(from: d)
    }

    static func temp(_ v: Double) -> String { "\(Int(v.rounded()))°" }

    static func dueText(_ t: TaskItem) -> String? { Mock.dueLabel(t)?.uppercased() }

    static func dueColor(_ t: TaskItem) -> C {
        if t.isOverdue(asOf: Mock.now) { return .red2 }
        if t.isDueToday(asOf: Mock.now) { return .gold2 }
        return .teal3
    }

    /// Monday-first week containing `date`.
    static func week(of date: Date) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    static func isDay(_ s: DaySnapshot) -> Bool {
        if let w = s.weather, let rise = w.sunrise, let set = w.sunset { return s.date >= rise && s.date < set }
        return s.weather?.isDay ?? true
    }
}

/// A Menlo Bold line with a hard pixel drop shadow.
struct QuestText: View {
    let text: String
    var size: CGFloat = 12
    var color: C = .cream
    var lines: Int = 1

    var body: some View {
        Text(text)
            .font(.custom("Menlo-Bold", size: size))
            .foregroundStyle(PQ.color(color))
            .lineLimit(lines)
            .truncationMode(.tail)
            .lineSpacing(1)
            .shadow(color: PQ.color(.ink), radius: 0, x: 1, y: 1)
    }
}

/// Positions a view's top-leading corner at (x, y) in a topLeading ZStack.
struct Placed<Content: View>: View {
    let x: CGFloat
    let y: CGFloat
    var w: CGFloat?
    var h: CGFloat?
    var align: Alignment = .leading
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: w, height: h, alignment: align)
            .offset(x: x, y: y)
    }
}

// MARK: - Large

struct DayLarge: View {
    let s: DaySnapshot
    static let rowTop = 92
    static let rowH = 14
    static let shown = 5

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelCanvas(buffer: art(), fine: fine)
            ForEach(Array(s.tasks.prefix(Self.shown).enumerated()), id: \.offset) { i, t in
                let top = CGFloat(Self.rowTop + i * Self.rowH) * 2
                Placed(x: 64, y: top + 7, w: textWidth(t), h: 15) { QuestText(text: t.text, size: 12) }
            }
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }

    func dueX(_ t: TaskItem) -> CGFloat? {
        guard let d = DayKit.dueText(t) else { return nil }
        return 326 - CGFloat(PixelFont.width(d)) * PQ.fine
    }

    func textWidth(_ t: TaskItem) -> CGFloat {
        var right: CGFloat = 326
        if let x = dueX(t) { right = x - (t.isOverdue(asOf: Mock.now) ? 18 : 8) }
        return right - 64
    }

    func art() -> PixelBuffer {
        var b = PixelBuffer(174, 183)
        let day = DayKit.isDay(s)
        b.sky(day ? .day : .night, to: 76)
        if day { b.sun(86, 12, r: 4) } else { b.stars(count: 40, below: 50, seed: 7); b.moon(86, 12, r: 4) }
        b.cloud(58, 30, width: 20, seed: 3)
        if day { b.birds([(64, 18), (70, 15)]) }
        b.mountains([Peak(x: 80, y: 14, l: 0.95, r: 0.8, snow: 9), Peak(x: 52, y: 28, snow: 5), Peak(x: 114, y: 22, snow: 6),
                     Peak(x: 148, y: 30, snow: 4), Peak(x: 18, y: 32, snow: 4), Peak(x: 174, y: 24, snow: 5)],
                    bottom: 66, style: .far, seed: 11)
        b.cloud(30, 46, width: 26, seed: 5, tone: (.cloudS, .farB, .farM))
        b.mountains([Peak(x: 64, y: 38, l: 1.1, r: 1.2, snow: 3), Peak(x: 28, y: 42, snow: 2), Peak(x: 102, y: 40, snow: 2),
                     Peak(x: 138, y: 39, snow: 3), Peak(x: 170, y: 44)],
                    bottom: 66, style: .near, seed: 12)
        let back = b.hills(base: 52, amp: 2.5, period: 70, phase: 0.4, bottom: 66, rim: .teal3, body: .teal2, dark: .teal1)
        b.forest(back, sprites: Sprites.darkPines, sink: 2, step: 3...5, seed: 21)
        let front = b.hills(base: 57, amp: 1.5, period: 46, phase: 2.0, bottom: 66, rim: .grass3, body: .grass2, dark: .grass1)
        b.forest(front, sprites: Sprites.pines, sink: 3, step: 5...9, seed: 22)
        b.meadow(top: 64, bottom: 183, seed: 30, flowers: 12)
        b.road(58, 16, seed: 31)

        // Date over the sky.
        let d = s.date
        b.text(DayKit.weekday(d), 8, 8, .cream, outline: .ink)
        b.bigNumber(DayKit.dayNumber(d), 9, 19)
        b.text(DayKit.month(d), 8, 43, .cream, outline: .ink)

        // Status window.
        b.window(98, 6, 70, 46)
        if let w = s.weather {
            b.weatherGlyph(w.symbolName, 104, 10)
            let t = DayKit.temp(w.temperature)
            b.bigNumber(t, 162 - BigDigits.width(t), 11, scale: 1)
        }

        // Week road.
        let week = DayKit.week(of: d)
        let cal = Calendar.current
        for (i, day) in week.enumerated() {
            let x = 8 + i * 23
            let kind: PixelBuffer.TileKind = cal.isDate(day, inSameDayAs: d) ? .today : (day < d ? .past : .future)
            let lift = kind == .today ? 2 : 0
            b.tile(x, 54 - lift, 20, 17 + lift, kind: kind)
            let n = DayKit.dayNumber(day)
            b.text(n, x + (20 - PixelFont.width(n)) / 2, 62, kind == .today ? .earth0 : .ink, shadow: nil)
            if kind == .today { b.sparkle(x - 1, 53); b.sparkle(x + 21, 66) }
        }

        // Quest log.
        b.window(4, 74, 166, 105)
        b.text("QUEST LOG", 11, 80, .gold2, ramp: DayKit.headRamp)
        b.hline(10, 89, 154, .navy0)
        for x in stride(from: 10, to: 164, by: 2) { b.set(x, 90, .navy4) }
        let tasks = Array(s.tasks.prefix(Self.shown))
        for (i, t) in tasks.enumerated() {
            let top = Self.rowTop + i * Self.rowH
            if i == 0 { b.draw(Sprites.glove, 9, top + 3) }
            let icon = Sprites.icon(for: t)
            b.draw(icon, 26 - icon.w / 2, top + 7 - icon.h / 2)
            if i < tasks.count - 1 {
                for x in stride(from: 32, to: 163, by: 3) { b.set(x, top + Self.rowH - 1, .navy1) }
            }
            if t.isOverdue(asOf: Mock.now), let dx = dueX(t) {
                b.draw(Sprites.alert, Int(dx / 2) - 6, top + 3)
            }
        }
        if s.tasks.isEmpty {
            b.draw(Sprites.star, 22, Self.rowTop + 2)
        }
        return b
    }

    func fine(_ ctx: GraphicsContext) {
        let f = PQ.fine
        if let w = s.weather {
            PixelFont.draw(ctx, w.label.uppercased(), x: 206, y: 56, px: f, color: .cream)
            PixelFont.draw(ctx, runs: [("▲", .red2), (DayKit.temp(w.high), .cream), (" ", .cream), ("▼", .sky3), (DayKit.temp(w.low), .cream)],
                           x: 206, y: 69, px: f)
            PixelFont.draw(ctx, runs: [("↑", .gold2), (Mock.time(w.sunrise), .cream), ("  ", .cream), ("↓", .gold1), (Mock.time(w.sunset), .cream)],
                           x: 206, y: 82, px: f)
        } else {
            PixelFont.draw(ctx, s.weatherError ?? "NO WEATHER", x: 206, y: 56, px: f, color: .red2)
        }
        // Day letters on the tiles.
        let week = DayKit.week(of: s.date)
        let cal = Calendar.current
        for (i, day) in week.enumerated() {
            let letter = String(DayKit.shortWeekday(day).prefix(1))
            let cx = CGFloat(8 + i * 23) * 2 + 20
            let today = cal.isDate(day, inSameDayAs: s.date)
            PixelFont.draw(ctx, letter, x: cx - CGFloat(PixelFont.width(letter)) * f / 2, y: today ? 109 : 113, px: f,
                           color: today ? .gold0 : .earth1, shadow: nil)
        }
        let count = "\(s.tasks.count) QUESTS"
        PixelFont.draw(ctx, count, x: 326 - CGFloat(PixelFont.width(count)) * f, y: 163, px: f, color: .creamD)
        for (i, t) in s.tasks.prefix(Self.shown).enumerated() {
            guard let d = DayKit.dueText(t), let x = dueX(t) else { continue }
            let top = CGFloat(Self.rowTop + i * Self.rowH) * 2
            PixelFont.draw(ctx, d, x: x, y: top + 10, px: f, color: DayKit.dueColor(t))
        }
        if s.tasks.count > Self.shown {
            PixelFont.draw(ctx, runs: [("▼", .gold2), ("+\(s.tasks.count - Self.shown) MORE", .creamD)], x: 64, y: 330, px: f)
        }
        if s.tasks.isEmpty {
            PixelFont.draw(ctx, s.taskError ?? "ALL QUESTS CLEAR", x: 64, y: 190, px: f, color: s.taskError == nil ? .cream : .red2)
        }
    }
}

// MARK: - Medium

struct DayMedium: View {
    let s: DaySnapshot
    static let rowTop = 22
    static let rowH = 15
    static let shown = 3

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelCanvas(buffer: art(), fine: fine)
            ForEach(Array(s.tasks.prefix(Self.shown).enumerated()), id: \.offset) { i, t in
                let top = CGFloat(Self.rowTop + i * Self.rowH) * 2
                Placed(x: 162, y: top + 1, w: 168, h: 14) { QuestText(text: t.text, size: 11) }
            }
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }

    func art() -> PixelBuffer {
        var b = PixelBuffer(174, 82)
        let day = DayKit.isDay(s)
        b.sky(day ? .day : .night, to: 64)
        let sunX = 8 + PixelFont.width(DayKit.weekday(s.date)) + 8
        if !day { b.stars(count: 20, below: 40, seed: 7) }
        if sunX <= 58 { if day { b.sun(sunX, 9, r: 3) } else { b.moon(sunX, 9, r: 3) } }
        b.mountains([Peak(x: 40, y: 18, l: 0.9, r: 0.85, snow: 8), Peak(x: 12, y: 30, snow: 4), Peak(x: 66, y: 24, snow: 5)],
                    bottom: 62, style: .far, seed: 41)
        b.mountains([Peak(x: 24, y: 40, snow: 2), Peak(x: 54, y: 38, snow: 3)], bottom: 62, style: .near, seed: 42)
        let back = b.hills(base: 52, amp: 2, period: 40, phase: 0.8, bottom: 64, rim: .teal3, body: .teal2, dark: .teal1)
        b.forest(back, sprites: Sprites.darkPines, sink: 2, step: 3...5, seed: 43, to: 70)
        b.meadow(top: 58, bottom: 82, seed: 44)

        let d = s.date
        b.text(DayKit.weekday(d), 8, 8, .cream, outline: .ink)
        b.bigNumber(DayKit.dayNumber(d), 9, 19)
        b.text(DayKit.month(d), 8, 43, .cream, outline: .ink)

        b.plate(5, 53, 56, 25)
        if let w = s.weather {
            b.weatherGlyph(w.symbolName, 8, 56)
            let t = DayKit.temp(w.temperature)
            b.bigNumber(t, 56 - BigDigits.width(t), 57, scale: 1)
        }

        b.window(64, 4, 106, 75)
        b.text("QUEST LOG", 72, 10, .gold2, ramp: DayKit.headRamp)
        b.hline(70, 19, 94, .navy0)
        for x in stride(from: 70, to: 164, by: 2) { b.set(x, 20, .navy4) }
        for (i, t) in s.tasks.prefix(Self.shown).enumerated() {
            let top = Self.rowTop + i * Self.rowH
            let icon = Sprites.icon(for: t)
            b.draw(icon, 75 - icon.w / 2, top + 4 - icon.h / 2 + 1)
            if i == 0 { b.draw(Sprites.glove, 58, top + 1) }
        }
        if s.tasks.isEmpty { b.draw(Sprites.star, 71, 24) }
        return b
    }

    func fine(_ ctx: GraphicsContext) {
        let f = PQ.fine
        if let w = s.weather {
            PixelFont.draw(ctx, runs: [("▲", .red2), (DayKit.temp(w.high), .cream), (" ", .cream), ("▼", .sky3), (DayKit.temp(w.low), .cream)],
                           x: 18, y: 141, px: f)
        }
        let count = "\(s.tasks.count) QUESTS"
        PixelFont.draw(ctx, count, x: 326 - CGFloat(PixelFont.width(count)) * f, y: 23, px: f, color: .creamD)
        for (i, t) in s.tasks.prefix(Self.shown).enumerated() {
            guard let d = DayKit.dueText(t) else { continue }
            let top = CGFloat(Self.rowTop + i * Self.rowH) * 2
            let text = t.isOverdue(asOf: Mock.now) ? "! " + d : d
            PixelFont.draw(ctx, text, x: 162, y: top + 17, px: f, color: DayKit.dueColor(t))
        }
        if s.tasks.isEmpty {
            PixelFont.draw(ctx, s.taskError ?? "ALL QUESTS CLEAR", x: 162, y: 52, px: f, color: s.taskError == nil ? .cream : .red2)
        }
        if s.tasks.count > Self.shown {
            let more = "+\(s.tasks.count - Self.shown) MORE"
            PixelFont.draw(ctx, runs: [("▼", .gold2), (more, .creamD)], x: 326 - CGFloat(PixelFont.width(runs: [("▼", .gold2), (more, .creamD)])) * f, y: 136, px: f)
        }
    }
}

// MARK: - Small

struct DaySmall: View {
    let s: DaySnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelCanvas(buffer: art(), fine: fine)
            if let t = s.tasks.first {
                Placed(x: 42, y: 81, w: 106, h: 30, align: .topLeading) { QuestText(text: t.text, size: 11, lines: 2) }
            }
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }

    func art() -> PixelBuffer {
        var b = PixelBuffer(82, 82)
        let day = DayKit.isDay(s)
        b.sky(day ? .day : .night, to: 40)
        b.mountains([Peak(x: 52, y: 12, l: 0.9, r: 0.9, snow: 7), Peak(x: 26, y: 24, snow: 3), Peak(x: 78, y: 20, snow: 4)],
                    bottom: 38, style: .far, seed: 51)
        b.mountains([Peak(x: 40, y: 28, snow: 2), Peak(x: 70, y: 30)], bottom: 38, style: .near, seed: 52)
        let back = b.hills(base: 32, amp: 1.5, period: 30, phase: 0.5, bottom: 40, rim: .teal3, body: .teal2, dark: .teal1)
        b.forest(back, sprites: Sprites.tinyPines, sink: 2, step: 2...4, seed: 53)
        b.meadow(top: 36, bottom: 82, seed: 54)

        let d = s.date
        b.bigNumber(DayKit.dayNumber(d), 9, 9)
        let numW = BigDigits.width(DayKit.dayNumber(d)) * 2
        // Two-digit days pull the weekday and month in so the weather still fits at the right.
        let labelX = 9 + numW + (numW > 20 ? 3 : 5)
        b.text(DayKit.shortWeekday(d), labelX, 10, .cream, outline: .ink)
        b.text(DayKit.shortMonth(d), labelX, 21, .cream, outline: .ink)
        if let w = s.weather {
            let labelsRight = labelX + max(PixelFont.width(DayKit.shortWeekday(d)), PixelFont.width(DayKit.shortMonth(d)))
            b.weatherGlyph(w.symbolName, max(61, labelsRight + 3), 6)
            let t = DayKit.temp(w.temperature)
            b.text(t, max(74 - PixelFont.width(t), labelsRight + 2), 22, .gold2, outline: .ink)
        }

        b.window(4, 36, 74, 42)
        if let t = s.tasks.first {
            let icon = Sprites.icon(for: t)
            b.draw(icon, 15 - icon.w / 2, 42)
            b.draw(Sprites.glove, -2, 44)
        }
        return b
    }

    func fine(_ ctx: GraphicsContext) {
        let f = PQ.fine
        if let t = s.tasks.first, let d = DayKit.dueText(t) {
            let text = t.isOverdue(asOf: Mock.now) ? "! " + d : d
            PixelFont.draw(ctx, text, x: 42, y: 115, px: f, color: DayKit.dueColor(t))
        }
        if s.tasks.count > 1 {
            PixelFont.draw(ctx, runs: [("▼", .gold2), ("+\(s.tasks.count - 1) MORE", .creamD)], x: 42, y: 132, px: f)
        } else if s.tasks.isEmpty {
            PixelFont.draw(ctx, s.taskError ?? "ALL CLEAR", x: 20, y: 90, px: f, color: .cream)
        }
    }
}
