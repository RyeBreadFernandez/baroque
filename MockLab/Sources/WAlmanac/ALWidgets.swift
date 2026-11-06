import SwiftUI

// The Almanac widgets. Every page is laid out at the iPhone 17 widget size with fixed positions (points), so the
// plate, the month and the entry sit on one grid: margins 16, the plate inset 12 (10 on small) under its fillet.

// MARK: - Weather

struct ALWeatherLarge: View {
    var snapshot: DaySnapshot

    var body: some View {
        let ink = ALInk.of(snapshot)
        ZStack(alignment: .topLeading) {
            ALPaper(ink: ink)
            ALTippedPlate(kind: .large, snapshot: snapshot, ink: ink)
                .frame(width: 324, height: 160)
                .offset(x: 12, y: 12)
            Text("Matterhorn \u{00B7} 14,692 ft")
                .font(ALType.italic(8.5))
                .foregroundStyle(Color(hex: 0xEFE3CB).opacity(0.85))
                .shadow(color: .black.opacity(0.8), radius: 2)
                .offset(x: 20, y: 156)
            // The month, with the day and the year set small at the right of its line.
            ALMonth(text: ALWords.month(snapshot.date), size: 56, ink: ink)
                .frame(width: 262, alignment: .leading)
                .alBaseline(x: 16, y: 234)
            Text(ALWords.ordinal(snapshot.date))
                .font(ALType.italic(12.5))
                .foregroundStyle(ink.inkSoft)
                .alPressed(ink)
                .frame(width: 316, alignment: .trailing)
                .alBaseline(x: 16, y: 217)
            Text(ALWords.roman(snapshot.date))
                .alCaps(8.5, ink.label, tracking: 1.6)
                .alPressed(ink)
                .frame(width: 317.6, alignment: .trailing)
                .alBaseline(x: 16, y: 234)
            ALRule(ink: ink)
                .frame(width: 316)
                .offset(x: 16, y: 245)
            ALEntryLarge(snapshot: snapshot, ink: ink)
                .frame(width: 316, alignment: .topLeading)
                .offset(x: 16, y: 257)
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }
}

/// The large entry: the cut and the temperature with the condition under it on the left; high and low, the sun
/// times with leaders and the day's light on the right.
struct ALEntryLarge: View {
    var snapshot: DaySnapshot
    var ink: ALInk

    var body: some View {
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        HStack(alignment: .top, spacing: 12) {
            if let w = snapshot.weather {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center, spacing: 8) {
                        ALEngraving(condition: SkyCondition(code: w.code), isDay: clock.isDay, color: ink.ink)
                            .frame(width: 34, height: 34)
                        Text(ALWords.degrees(w.temperature))
                            .font(ALType.display(46))
                            .foregroundStyle(ink.ink)
                            .alPressed(ink)
                    }
                    Text(ALWords.condition(w))
                        .font(ALType.displayItalic(16))
                        .foregroundStyle(ink.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(width: 136, alignment: .leading)
                ALColumnRule(ink: ink)
                    .frame(height: 84)
                VStack(alignment: .leading, spacing: 3) {
                    Text("high \(ALWords.degrees(w.high).dropLast()) \u{00B7} low \(ALWords.degrees(w.low).dropLast())")
                        .font(ALType.body(13))
                        .foregroundStyle(ink.ink)
                    if let sun = ALWords.sun(w, now: snapshot.date) {
                        ALSunRow(label: "sunrise", time: ALWords.clock(sun.rise), next: sun.riseNext, ink: ink)
                        ALSunRow(label: "sunset", time: ALWords.clock(sun.set), next: !sun.riseNext, ink: ink)
                    }
                    if let light = ALWords.daylight(w) {
                        Text(light)
                            .font(ALType.italic(12))
                            .foregroundStyle(ink.label)
                            .padding(.top, 1)
                    }
                }
                .alPressed(ink)
            } else {
                ALNoWeather(error: snapshot.weatherError, ink: ink, size: 14)
            }
        }
    }
}

/// The month, the hero of the page: espresso ink pressed into the paper by day, gold leaf on the board at night.
struct ALMonth: View {
    var text: String
    var size: CGFloat
    var ink: ALInk

    var body: some View {
        if ink.night {
            ALGilt(text: text, font: ALType.display(size), ink: ink, fit: true)
        } else {
            Text(text)
                .font(ALType.display(size))
                .foregroundStyle(ink.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .alPressed(ink)
        }
    }
}

/// A small gold pointer (a solid triangle) set in the gutter beside the next sun event.
struct ALPointer: View {
    var color: Color

    var body: some View {
        Canvas { ctx, s in
            var p = Path()
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: s.width, y: s.height / 2))
            p.addLine(to: CGPoint(x: 0, y: s.height))
            p.closeSubpath()
            ctx.fill(p, with: .color(color))
        }
        .accessibilityHidden(true)
    }
}

/// "sunrise ········ 6:14": the next of the two in full ink with a gold pointer, the other quieter.
struct ALSunRow: View {
    var label: String
    var time: String
    var next: Bool
    var ink: ALInk
    var size: CGFloat = 13
    var pointer = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(label)
                .font(ALType.italic(size))
                .foregroundStyle(next ? ink.ink : ink.inkSoft)
                .overlay(alignment: .leading) {
                    if next && pointer {
                        ALPointer(color: ink.night ? ink.gild[0] : ink.gild[1])
                            .frame(width: 4.5, height: 6)
                            .offset(x: -8.5, y: 0.5)
                    }
                }
            ALLeader(color: ink.rule.opacity(next ? 0.9 : 0.55))
            Text(time)
                .font(ALType.body(size + 0.5))
                .foregroundStyle(next ? ink.ink : ink.inkSoft)
        }
    }
}

struct ALNoWeather: View {
    var error: String?
    var ink: ALInk
    var size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("no weather today")
                .font(ALType.displayItalic(size + 2))
                .foregroundStyle(ink.inkSoft)
            Text(error ?? "the forecast could not be fetched")
                .font(ALType.italic(size - 3))
                .foregroundStyle(ink.rubric)
                .lineLimit(2)
        }
    }
}

struct ALWeatherMedium: View {
    var snapshot: DaySnapshot

    var body: some View {
        let ink = ALInk.of(snapshot)
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        ZStack(alignment: .topLeading) {
            ALPaper(ink: ink)
            ALTippedPlate(kind: .medium, snapshot: snapshot, ink: ink)
                .frame(width: 324, height: 64)
                .offset(x: 12, y: 12)
            // Left: the month, and under it the day and the year.
            ALMonth(text: ALWords.month(snapshot.date), size: 38, ink: ink)
                .frame(width: 190, alignment: .leading)
                .alBaseline(x: 16, y: 123)
            Text("\(ALWords.ordinal(snapshot.date)) \u{00B7} \(ALWords.roman(snapshot.date))")
                .font(ALType.italic(11))
                .foregroundStyle(ink.label)
                .alPressed(ink)
                .frame(width: 190, alignment: .leading)
                .alBaseline(x: 16, y: 141)
            // Right: the entry, flush right on the same three lines.
            if let w = snapshot.weather {
                (Text(ALWords.degrees(w.temperature)).font(ALType.display(24)).foregroundStyle(ink.ink)
                 + Text("  ").font(ALType.body(12))
                 + Text(ALWords.condition(w)).font(ALType.displayItalic(13)).foregroundStyle(ink.inkSoft))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .alPressed(ink)
                    .overlay(alignment: .leading) {
                        ALEngraving(condition: SkyCondition(code: w.code), isDay: clock.isDay, color: ink.ink)
                            .frame(width: 18, height: 18)
                            .offset(x: -24, y: -1)
                    }
                    .frame(width: 124, alignment: .trailing)
                    .alBaseline(x: 208, y: 105)
                Text("high \(ALWords.degrees(w.high).dropLast()) \u{00B7} low \(ALWords.degrees(w.low).dropLast())")
                    .font(ALType.body(11.5))
                    .foregroundStyle(ink.ink)
                    .alPressed(ink)
                    .frame(width: 150, alignment: .trailing)
                    .alBaseline(x: 182, y: 123)
                if let sun = ALWords.sun(w, now: snapshot.date) {
                    sunLine(sun, ink)
                        .alPressed(ink)
                        .frame(width: 150, alignment: .trailing)
                        .alBaseline(x: 182, y: 141)
                }
            } else {
                ALNoWeather(error: snapshot.weatherError, ink: ink, size: 12)
                    .frame(width: 140, alignment: .trailing)
                    .alBaseline(x: 192, y: 110)
            }
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }

    private func sunLine(_ sun: (rise: Date, set: Date, riseNext: Bool), _ ink: ALInk) -> some View {
        let rise = sun.riseNext ? ink.ink : ink.inkSoft
        let set = sun.riseNext ? ink.inkSoft : ink.ink
        return (Text("sunrise ").font(ALType.italic(11)).foregroundStyle(rise)
                + Text(ALWords.clock(sun.rise)).font(ALType.body(11.5)).foregroundStyle(rise)
                + Text("  \u{00B7}  ").font(ALType.body(11)).foregroundStyle(ink.rule)
                + Text("sunset ").font(ALType.italic(11)).foregroundStyle(set)
                + Text(ALWords.clock(sun.set)).font(ALType.body(11.5)).foregroundStyle(set))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

struct ALWeatherSmall: View {
    var snapshot: DaySnapshot

    var body: some View {
        let ink = ALInk.of(snapshot)
        ZStack(alignment: .topLeading) {
            ALPaper(ink: ink)
            ALTippedPlate(kind: .small, snapshot: snapshot, ink: ink, fillet: 3)
                .frame(width: 144, height: 54)
                .offset(x: 10, y: 10)
            ALMonth(text: ALWords.month(snapshot.date, short: true), size: 40, ink: ink)
                .alBaseline(x: 16, y: 104)
            if let w = snapshot.weather {
                Text(ALWords.degrees(w.temperature))
                    .font(ALType.display(30))
                    .foregroundStyle(ink.ink)
                    .alPressed(ink)
                    .frame(width: 132, alignment: .trailing)
                    .alBaseline(x: 16, y: 104)
                ALRule(ink: ink, thick: 0.8)
                    .frame(width: 132)
                    .offset(x: 16, y: 111)
                Text(ALWords.condition(w))
                    .font(ALType.displayItalic(12.5))
                    .foregroundStyle(ink.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 132, alignment: .leading)
                    .alBaseline(x: 16, y: 130)
                if let sun = ALWords.sun(w, now: snapshot.date) {
                    ALSunRow(label: sun.riseNext ? "sunrise" : "sunset", time: ALWords.clock(sun.riseNext ? sun.rise : sun.set),
                             next: true, ink: ink, size: 12, pointer: false)
                        .alPressed(ink)
                        .frame(width: 132)
                        .alBaseline(x: 16, y: 146)
                }
            } else {
                ALRule(ink: ink, thick: 0.8)
                    .frame(width: 132)
                    .offset(x: 16, y: 111)
                ALNoWeather(error: snapshot.weatherError, ink: ink, size: 11)
                    .frame(width: 132, alignment: .leading)
                    .alBaseline(x: 16, y: 130)
            }
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }
}

// MARK: - To do

/// A task's due note: italic, rubric red when late.
struct ALDue: View {
    var task: TaskItem
    var now: Date
    var ink: ALInk
    var size: CGFloat

    var body: some View {
        if let due = Mock.dueLabel(task, now: now) {
            Text(due)
                .font(ALType.italic(size))
                .foregroundStyle(task.isOverdue(asOf: now) ? ink.rubric : ink.label)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

struct ALTodoSmall: View {
    var snapshot: DaySnapshot

    var body: some View {
        let ink = ALInk.of(snapshot)
        let tasks = Array(snapshot.tasks.prefix(2))
        ZStack(alignment: .topLeading) {
            ALPaper(ink: ink)
            Text("to do")
                .alCaps(10, ink.label, tracking: 2.2)
                .alBaseline(x: 16, y: 27)
            Rectangle().fill(ink.rule).frame(width: 34, height: 0.6)
                .offset(x: 16, y: 33)
            ALGilt(text: "\(snapshot.tasks.count)", font: ALType.display(48), ink: ink, sparkle: UnitPoint(x: 0.78, y: 0.3))
                .frame(width: 132, alignment: .trailing)
                .alBaseline(x: 16, y: 52)
            Group {
                if let error = snapshot.taskError {
                    ALTaskTrouble(title: "tasks unavailable", note: error, ink: ink, color: ink.rubric)
                } else if tasks.isEmpty {
                    ALTaskTrouble(title: "nothing to do", note: "a clear page today", ink: ink, color: ink.label)
                } else {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { i, task in
                            ALTaskLine(index: i + 1, task: task, now: snapshot.date, ink: ink, size: 12, stacked: true)
                        }
                    }
                }
            }
            .alPressed(ink)
            .frame(width: 132, alignment: .leading)
            .alBaseline(x: 16, y: 78)
            if snapshot.taskError == nil, snapshot.tasks.count > tasks.count {
                Text("and \(snapshot.tasks.count - tasks.count) more")
                    .font(ALType.italic(10.5))
                    .foregroundStyle(ink.label)
                    .frame(width: 132, alignment: .trailing)
                    .alBaseline(x: 16, y: 146)
            }

        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }
}

struct ALTodoMedium: View {
    var snapshot: DaySnapshot

    var body: some View {
        let ink = ALInk.of(snapshot)
        let tasks = Array(snapshot.tasks.prefix(4))
        let late = snapshot.tasks.filter { $0.isOverdue(asOf: snapshot.date) }.count
        let today = snapshot.tasks.filter { $0.isDueToday(asOf: snapshot.date) }.count
        ZStack(alignment: .topLeading) {
            ALPaper(ink: ink)
            // The left column: the header, the count in gold leaf, and what is late and due today.
            VStack(alignment: .leading, spacing: 0) {
                Text("to do").alCaps(10, ink.label, tracking: 2.2)
                Rectangle().fill(ink.rule).frame(width: 34, height: 0.6).padding(.top, 4)
                Spacer(minLength: 0)
                ALGilt(text: "\(snapshot.tasks.count)", font: ALType.display(66), ink: ink, sparkle: UnitPoint(x: 0.8, y: 0.3))
                    .padding(.leading, -2)
                Spacer(minLength: 0)
                if snapshot.taskError == nil, !snapshot.tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 1) {
                        if late > 0 {
                            Text("\(late) late").font(ALType.italic(11)).foregroundStyle(ink.rubric)
                        }
                        Text("\(today) today").font(ALType.italic(11)).foregroundStyle(ink.label)
                    }
                }
            }
            .alPressed(ink)
            .frame(width: 76, height: 132, alignment: .topLeading)
            .offset(x: 16, y: 16)
            ALColumnRule(ink: ink)
                .frame(height: 132)
                .offset(x: 102, y: 16)
            // The list.
            VStack(alignment: .leading, spacing: 0) {
                if let error = snapshot.taskError {
                    ALTaskTrouble(title: "tasks unavailable", note: error, ink: ink, color: ink.rubric)
                    Spacer(minLength: 0)
                } else if tasks.isEmpty {
                    ALTaskTrouble(title: "nothing to do", note: "a clear page today", ink: ink, color: ink.label)
                    Spacer(minLength: 0)
                } else {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { i, task in
                        ALTaskLine(index: i + 1, task: task, now: snapshot.date, ink: ink, size: 13.5, stacked: false)
                            .frame(height: 26)
                        if i < tasks.count - 1 {
                            Rectangle().fill(ink.rule.opacity(0.35)).frame(height: 0.5)
                        }
                    }
                    Spacer(minLength: 0)
                    if snapshot.tasks.count > tasks.count {
                        Text("and \(snapshot.tasks.count - tasks.count) more")
                            .font(ALType.italic(11))
                            .foregroundStyle(ink.label)
                    }
                }
            }
            .alPressed(ink)
            .frame(width: 214, height: 136, alignment: .topLeading)
            .offset(x: 118, y: 14)
            // The tailpiece: the Matterhorn as a small engraved cut in gold.
            ALEngravedPeak(color: ink.rule)
                .frame(width: 60, height: 30)
                .offset(x: 272, y: 120)
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }
}

/// One numbered line: the number in Didot (rubric when late), the title, and the due note beside it (medium) or
/// under it (small).
struct ALTaskLine: View {
    var index: Int
    var task: TaskItem
    var now: Date
    var ink: ALInk
    var size: CGFloat
    var stacked: Bool

    var body: some View {
        let late = task.isOverdue(asOf: now)
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("\(index)")
                .font(ALType.display(size))
                .foregroundStyle(late ? ink.rubric : ink.rule)
                .frame(width: size * 0.62, alignment: .leading)
            if stacked {
                VStack(alignment: .leading, spacing: 1) {
                    title
                    ALDue(task: task, now: now, ink: ink, size: size - 2)
                }
            } else {
                title
                Spacer(minLength: 6)
                ALDue(task: task, now: now, ink: ink, size: size - 2)
            }
        }
    }

    private var title: some View {
        Text(task.text)
            .font(ALType.body(size))
            .foregroundStyle(ink.ink)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

struct ALTaskTrouble: View {
    var title: String
    var note: String
    var ink: ALInk
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(ALType.displayItalic(15))
                .foregroundStyle(ink.inkSoft)
            Text(note)
                .font(ALType.italic(11))
                .foregroundStyle(color)
                .lineLimit(2)
        }
    }
}

// MARK: - Wallpaper

struct ALWallpaper: View {
    var body: some View {
        Mock.texture("weather-almanac/wallpaper")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
    }
}
