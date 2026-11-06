import SwiftUI

// Day widget: the date and weather printed on the sky wall of the box, the week strung across the
// mountains as bunting, and today's tasks on an index card clipped in front of the forest.

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

// MARK: - Shared bits

struct DateStack: View {
    var date: Date
    var numeral: CGFloat
    var monthSize: CGFloat
    var weekday: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(weekday.uppercased())
                .font(.pdAvenir(numeral > 50 ? 11 : 10, "Bold"))
                .tracking(1.8)
                .foregroundStyle(PD.coralDeep)
                .onPaper(PD.skyLow, 0.7)
            PaperLetters(text: Fmt.dayNumber(date), font: .pdRounded(numeral, .heavy), color: PD.coral, lift: 2.2)
                .padding(.top, -numeral * 0.12)
                .padding(.bottom, -numeral * 0.16)
            Text(Fmt.string(date, "MMMM"))
                .font(.pdChalk(monthSize, "Bold"))
                .foregroundStyle(PD.ink)
                .onPaper(PD.skyLow, 0.8)
        }
    }
}

struct TaskLine: View {
    var task: TaskItem
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 7) {
            PunchHole(ring: PD.ring(task.priority))
            Text(task.text)
                .font(.pdRounded(size, .medium))
                .foregroundStyle(PD.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            DueMark(task: task)
                .layoutPriority(1)
        }
    }
}

/// A task row that keeps its due tag inline when it fits, and drops it under the text when it does not.
struct StackedTaskLine: View {
    var task: TaskItem
    var size: CGFloat = 13

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) {
                PunchHole(ring: PD.ring(task.priority))
                Text(task.text).font(.pdRounded(size, .medium)).foregroundStyle(PD.ink).lineLimit(1).fixedSize()
                Spacer(minLength: 6)
                DueMark(task: task)
            }
            HStack(alignment: .top, spacing: 7) {
                PunchHole(ring: PD.ring(task.priority))
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.text).font(.pdRounded(size, .medium)).foregroundStyle(PD.ink).lineLimit(1).truncationMode(.tail)
                    DueMark(task: task, size: 10)
                }
                .padding(.top, 1)
                Spacer(minLength: 0)
            }
        }
    }
}

struct MoreNote: View {
    var count: Int
    var size: CGFloat = 11.5
    var body: some View {
        Text("+\(count) more")
            .font(.pdChalk(size, "Regular"))
            .foregroundStyle(PD.inkSoft)
    }
}

struct SunTimes: View {
    var weather: WeatherSnapshot
    var body: some View {
        HStack(spacing: 7) {
            HStack(spacing: 2) {
                Image(systemName: "sunrise.fill").foregroundStyle(PD.coralDeep)
                Text(Mock.time(weather.sunrise))
            }
            HStack(spacing: 2) {
                Image(systemName: "sunset.fill").foregroundStyle(PD.coralDeep)
                Text(Mock.time(weather.sunset))
            }
        }
        .font(.pdRounded(11.5, .bold))
        .foregroundStyle(PD.ink)
        .onPaper(PD.skyLow, 0.8)
    }
}

// MARK: - Large

struct DayLarge: View {
    var snapshot: DaySnapshot
    private let size = Mock.size(.large)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Diorama(size: size, pieces: scene, glow: pt(0.7, 0.1))
            header
            Bunting(days: Fmt.week(of: snapshot.date), today: snapshot.date, width: size.width, y0: 113, sag: 11,
                    flag: CGSize(width: 34, height: 35))
                .frame(height: size.height, alignment: .top)
            card
                .frame(width: 322, height: 172)
                .position(x: size.width / 2, y: 268)
            Diorama(size: size, pieces: front, sky: false)
            ShadowboxRim(size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    private var header: some View {
        HStack(alignment: .top) {
            DateStack(date: snapshot.date, numeral: 60, monthSize: 15, weekday: Fmt.string(snapshot.date, "EEEE"))
            Spacer()
            if let w = snapshot.weather { weather(w) }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private func weather(_ w: WeatherSnapshot) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack(spacing: 2) {
                WeatherGlyph(symbol: w.symbolName, d: 26)
                    .frame(width: 44, height: 44)
                Text(Fmt.temp(w.temperature))
                    .font(.pdRounded(36, .bold))
                    .foregroundStyle(PD.ink)
                    .onPaper(PD.skyLow, 0.8)
            }
            Text(w.label)
                .font(.pdAvenir(13.5, "DemiBold"))
                .foregroundStyle(PD.ink)
                .onPaper(PD.skyLow, 0.8)
            Text("H \(Fmt.temp(w.high))   L \(Fmt.temp(w.low))")
                .font(.pdRounded(12, .bold))
                .foregroundStyle(PD.inkSoft)
                .onPaper(PD.skyLow, 0.8)
            SunTimes(weather: w)
                .padding(.top, 1)
        }
    }

    private var card: some View {
        let tasks = snapshot.tasks
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Today")
                    .font(.pdChalk(16, "Bold"))
                    .foregroundStyle(PD.ink)
                Spacer()
                CountSticker(count: tasks.count)
            }
            .padding(.leading, 24)
            .frame(height: 24)
            CardRule(red: true)
            ForEach(Array(tasks.prefix(5))) { t in
                TaskLine(task: t, size: 13)
                    .frame(height: 22)
                CardRule()
            }
            ForEach(0..<max(0, 5 - tasks.count), id: \.self) { _ in   // blank ruled lines, as on a real card
                Color.clear.frame(height: 22)
                CardRule()
            }
            if tasks.isEmpty {
                Text("Nothing due. Enjoy the view.")
                    .font(.pdChalk(12, "Regular"))
                    .foregroundStyle(PD.inkSoft)
                    .padding(.leading, 24)
                    .padding(.top, -104)
            }
            if tasks.count > 5 {
                MoreNote(count: tasks.count - 5)
                    .padding(.leading, 24)
                    .frame(height: 18)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background(IndexCard(seed: 11, dogEar: 0))
        .overlay(alignment: .topLeading) {
            PaperClip(color: PD.skyStock)
                .rotationEffect(.degrees(4))
                .offset(x: 14, y: -13)
        }
    }

    private var scene: [Piece] {
        [
            .cloud(pt(0.43, 0.075), 46, 1),
            .cloud(pt(0.565, 0.2), 32, 2),
            .ridge(Ridge(pts: [pt(-0.05, 0.4), pt(0.1, 0.34), pt(0.25, 0.38), pt(0.47, 0.15), pt(0.57, 0.27),
                               pt(0.655, 0.225), pt(0.78, 0.33), pt(0.9, 0.3), pt(1.05, 0.37)],
                         peaks: [3, 5], color: PD.periwinkle, shade: PD.periShade, snow: 12, lift: 2, seed: 101)),
            .ridge(Ridge(pts: [pt(-0.05, 0.38), pt(0.07, 0.325), pt(0.19, 0.41), pt(0.33, 0.35), pt(0.45, 0.43),
                               pt(0.62, 0.375), pt(0.77, 0.31), pt(0.9, 0.4), pt(1.05, 0.36)],
                         peaks: [1, 3, 6], color: PD.teal, shade: PD.tealShade, lift: 2.4, seed: 102)),
            .ridge(Ridge(pts: [pt(-0.05, 0.44), pt(0.18, 0.4), pt(0.4, 0.44), pt(0.62, 0.395), pt(0.85, 0.43), pt(1.05, 0.4)],
                         color: PD.peach, smooth: true, lift: 2.4, seed: 103)),
            .forest(Forest(ground: [pt(-0.05, 0.475), pt(0.3, 0.465), pt(0.6, 0.478), pt(1.05, 0.465)], color: PD.sage,
                           count: 20, heights: 15...22, lift: 2.2, round: true, seed: 104)),
            .forest(Forest(ground: [pt(-0.05, 0.505), pt(0.5, 0.495), pt(1.05, 0.505)], color: PD.pine,
                           count: 13, heights: 19...28, lift: 2.6, seed: 105)),
            .ridge(Ridge(pts: [pt(-0.05, 0.52), pt(0.3, 0.51), pt(0.7, 0.52), pt(1.05, 0.51)],
                         color: PD.meadow, smooth: true, lift: 2.6, seed: 106))
        ]
    }

    /// A meadow strip in front of the card's foot, so the card stands tucked into the grass.
    private var front: [Piece] {
        [
            .ridge(Ridge(pts: [pt(-0.05, 0.958), pt(0.2, 0.948), pt(0.45, 0.962), pt(0.7, 0.95), pt(1.05, 0.958)],
                         color: PD.meadow, smooth: true, lift: 2.4, seed: 107)),
            .tufts([pt(0.06, 0.962), pt(0.33, 0.968), pt(0.62, 0.962), pt(0.9, 0.966)], PD.sage, 8),
            .confetti(CGRect(x: 0.08, y: 0.965, width: 0.84, height: 0.015), 9, 7)
        ]
    }
}

// MARK: - Medium

struct DayMedium: View {
    var snapshot: DaySnapshot
    private let size = Mock.size(.medium)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Diorama(size: size, pieces: scene, glow: pt(0.2, 0.2))
            header
                .padding(.leading, 16)
                .padding(.top, 13)
            card
                .frame(width: 214, height: 138)
                .position(x: 228, y: 85)
            ShadowboxRim(size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 6) {
                DateStack(date: snapshot.date, numeral: 46, monthSize: 13, weekday: Fmt.string(snapshot.date, "EEEE"))
            }
            if let w = snapshot.weather {
                HStack(spacing: 3) {
                    WeatherGlyph(symbol: w.symbolName, d: 16, compact: true)
                        .frame(width: 27, height: 27)
                    Text(Fmt.temp(w.temperature))
                        .font(.pdRounded(18, .bold))
                        .foregroundStyle(PD.ink)
                    Text("\(Int(w.high.rounded()))/\(Int(w.low.rounded()))")
                        .font(.pdRounded(11, .bold))
                        .foregroundStyle(PD.inkSoft)
                }
                .onPaper(PD.skyLow, 0.8)
            }
        }
    }

    private var card: some View {
        let tasks = snapshot.tasks
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(tasks.prefix(3))) { t in
                StackedTaskLine(task: t, size: 13)
            }
            if tasks.count > 3 {
                MoreNote(count: tasks.count - 3, size: 11)
                    .padding(.leading, 24)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.top, 12)
        .background(IndexCard(seed: 21, dogEar: 12))
        .overlay(alignment: .topLeading) {
            PaperClip(color: PD.coral)
                .rotationEffect(.degrees(6))
                .offset(x: -6, y: -12)
        }
    }

    private var scene: [Piece] {
        [
            .cloud(pt(0.27, 0.2), 30, 3),
            .ridge(Ridge(pts: [pt(-0.05, 0.86), pt(0.07, 0.71), pt(0.17, 0.79), pt(0.28, 0.68), pt(0.4, 0.8), pt(0.6, 0.66), pt(0.8, 0.72), pt(1.05, 0.62)],
                         peaks: [1, 3, 5], color: PD.periwinkle, shade: PD.periShade, snow: 6, lift: 1.8, seed: 201)),
            .ridge(Ridge(pts: [pt(-0.05, 0.88), pt(0.14, 0.83), pt(0.3, 0.88), pt(0.5, 0.84), pt(1.05, 0.86)],
                         color: PD.peach, smooth: true, lift: 2, seed: 202)),
            .forest(Forest(ground: [pt(-0.05, 0.95), pt(0.3, 0.935), pt(1.05, 0.95)], color: PD.pine,
                           xs: -0.02...0.38, count: 8, heights: 12...18, lift: 2.2, seed: 203)),
            .ridge(Ridge(pts: [pt(-0.05, 0.97), pt(0.25, 0.96), pt(1.05, 0.975)], color: PD.meadow, smooth: true, lift: 2, seed: 204))
        ]
    }
}

// MARK: - Small

struct DaySmall: View {
    var snapshot: DaySnapshot
    private let size = Mock.size(.small)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Diorama(size: size, pieces: scene, glow: pt(0.8, 0.15))
            header
            card
                .frame(width: 146, height: 66)
                .position(x: 82, y: 120)
            ShadowboxRim(size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Fmt.string(snapshot.date, "EEE").uppercased())
                    .font(.pdAvenir(10, "Bold"))
                    .tracking(1.6)
                    .foregroundStyle(PD.coralDeep)
                    .onPaper(PD.skyLow, 0.7)
                PaperLetters(text: Fmt.dayNumber(snapshot.date), font: .pdRounded(40, .heavy), color: PD.coral, lift: 1.8)
                    .padding(.top, -5)
            }
            Spacer()
            if let w = snapshot.weather {
                VStack(alignment: .trailing, spacing: -2) {
                    WeatherGlyph(symbol: w.symbolName, d: 17, compact: true)
                        .frame(width: 30, height: 30)
                    Text(Fmt.temp(w.temperature))
                        .font(.pdRounded(19, .bold))
                        .foregroundStyle(PD.ink)
                        .onPaper(PD.skyLow, 0.8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
    }

    private var card: some View {
        let tasks = snapshot.tasks
        return VStack(alignment: .leading, spacing: 3) {
            if let first = tasks.first {
                HStack(alignment: .top, spacing: 5) {
                    PunchHole(ring: PD.ring(first.priority))
                    Text(first.text)
                        .font(.pdRounded(12, .medium))
                        .foregroundStyle(PD.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                }
                HStack {
                    DueMark(task: first, size: 9.5)
                    Spacer(minLength: 2)
                    if tasks.count > 1 { MoreNote(count: tasks.count - 1, size: 10.5) }
                }
                .padding(.leading, 22)
            } else {
                Text("All clear today").font(.pdChalk(12)).foregroundStyle(PD.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.top, 7)
        .background(IndexCard(seed: 31, dogEar: 0, lift: 2.8))
        .overlay(alignment: .top) {
            WashiTape(color: PD.coral, width: 34, angle: -4, seed: 4)
                .offset(y: -8)
        }
    }

    private var scene: [Piece] {
        [
            .ridge(Ridge(pts: [pt(-0.05, 0.62), pt(0.18, 0.5), pt(0.33, 0.58), pt(0.56, 0.3), pt(0.7, 0.46), pt(0.82, 0.4), pt(1.05, 0.55)],
                         peaks: [1, 3, 5], color: PD.periwinkle, shade: PD.periShade, snow: 8, lift: 1.8, seed: 301)),
            .ridge(Ridge(pts: [pt(-0.05, 0.6), pt(0.25, 0.54), pt(0.55, 0.6), pt(0.8, 0.53), pt(1.05, 0.58)],
                         color: PD.peach, smooth: true, lift: 2, seed: 302)),
            .forest(Forest(ground: [pt(-0.05, 0.66), pt(0.5, 0.65), pt(1.05, 0.66)], color: PD.pine,
                           count: 11, heights: 12...18, lift: 2.2, seed: 303)),
            .ridge(Ridge(pts: [pt(-0.05, 0.92), pt(0.5, 0.9), pt(1.05, 0.92)], color: PD.meadow, smooth: true, lift: 2, seed: 304))
        ]
    }
}
