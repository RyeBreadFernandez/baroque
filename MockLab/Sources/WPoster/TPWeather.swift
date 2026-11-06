import SwiftUI

// The Weather widget: one travel poster per size. The month is the poster's title, in Futura's condensed extra-bold
// printed cream over a vermilion that sits a hair out of register; the temperature and condition are set in poster
// type on the darkest ink; the sun's times run along the bottom as the caption band, on the unprinted paper.

extension TPStage {
    static func weather(_ family: Family) -> TPStage {
        let size = Mock.size(family)
        switch family {
        case .large:
            return TPStage(size: size, summit: CGPoint(x: 204, y: 104), height: 126, skyBottom: 262,
                           arcCentreX: 196, arcRadius: CGSize(width: 140, height: 168), horizon: 250, disc: 29, pitch: 3.4,
                           meadow: [CGPoint(x: 0, y: 252), CGPoint(x: 90, y: 258), CGPoint(x: 190, y: 270), CGPoint(x: 280, y: 262), CGPoint(x: 348, y: 254)],
                           field: [CGPoint(x: 0, y: 262), CGPoint(x: 120, y: 270), CGPoint(x: 220, y: 290), CGPoint(x: 348, y: 300)],
                           spruce: [(240, 345, 9, 22, 40), (196, 236, 3, 14, 22)],
                           clouds: [CGRect(x: 22, y: 96, width: 70, height: 26), CGRect(x: 268, y: 70, width: 58, height: 21)],
                           ceiling: 92, mist: 226, seed: 41)
        case .medium:
            return TPStage(size: size, summit: CGPoint(x: 254, y: 34), height: 77, skyBottom: 150,
                           arcCentreX: 250, arcRadius: CGSize(width: 82, height: 98), horizon: 118, disc: 18, pitch: 3.0,
                           meadow: [CGPoint(x: 0, y: 109), CGPoint(x: 120, y: 115), CGPoint(x: 230, y: 117), CGPoint(x: 348, y: 112)],
                           field: [CGPoint(x: 0, y: 122), CGPoint(x: 180, y: 126), CGPoint(x: 348, y: 124)],
                           spruce: [(290, 346, 6, 14, 24), (150, 176, 2, 9, 14)],
                           clouds: [CGRect(x: 168, y: 34, width: 44, height: 16), CGRect(x: 300, y: 18, width: 34, height: 13)],
                           ceiling: 44, mist: 96, seed: 42)
        case .small:
            return TPStage(size: size, summit: CGPoint(x: 106, y: 46), height: 58, skyBottom: 118,
                           arcCentreX: 102, arcRadius: CGSize(width: 62, height: 64), horizon: 108, disc: 14, pitch: 2.8,
                           meadow: [CGPoint(x: 0, y: 88), CGPoint(x: 60, y: 94), CGPoint(x: 120, y: 106), CGPoint(x: 164, y: 102)],
                           field: [CGPoint(x: 0, y: 95), CGPoint(x: 80, y: 104), CGPoint(x: 164, y: 116)],
                           spruce: [(128, 162, 4, 12, 20)],
                           clouds: [CGRect(x: 104, y: 22, width: 36, height: 13)],
                           ceiling: 36, mist: 88, seed: 43)
        }
    }
}

struct TPWeather: View {
    var snapshot: DaySnapshot
    var family: Family

    private var clock: SkyClock { SkyClock(now: snapshot.date, weather: snapshot.weather) }
    private var condition: SkyCondition { SkyCondition(code: snapshot.weather?.code) }

    var body: some View {
        let size = Mock.size(family)
        let inks = TPInks(clock: clock, condition: condition)
        let stage = TPStage.weather(family)
        ZStack(alignment: .topLeading) {
            TPPrint(stage: stage, inks: inks, clock: clock, condition: condition, date: snapshot.date)
            switch family {
            case .large: large(inks)
            case .medium: medium(inks)
            case .small: small(inks)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .overlay(TPPaper())
    }

    // MARK: Sizes

    private func large(_ inks: TPInks) -> some View {
        ZStack(alignment: .topLeading) {
            TPTitle(text: month, size: 54, inks: inks)
                .padding(.leading, 16).padding(.top, 16)
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                TPTemperature(text: temperature, size: 54, inks: inks)
                VStack(alignment: .leading, spacing: 3) {
                    Text(conditionLine.uppercased())
                        .font(TPType.bold(11)).tracking(1.6)
                    Text(rangeLine)
                        .font(TPType.label(10)).tracking(1.3)
                        .opacity(0.86)
                }
                .foregroundStyle(inks.title.color)
                .lineLimit(1)
                .padding(.bottom, 7)
            }
            .padding(.leading, 16)
            .frame(height: 325 - 4, alignment: .bottomLeading)
            TPCaption(text: sunLine, inks: inks, height: 40)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }

    private func medium(_ inks: TPInks) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                TPTitle(text: month, size: 27, inks: inks)
                TPTemperature(text: temperature, size: 41, inks: inks)
                    .padding(.top, -6)
                Text(conditionLine.uppercased())
                    .font(TPType.bold(9.5)).tracking(1.3)
                    .foregroundStyle(inks.title.color)
                    .lineLimit(1)
                    .padding(.top, -5)
            }
            .padding(.leading, 16).padding(.top, 16)
            TPCaption(text: sunLine, inks: inks, height: 36)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }

    private func small(_ inks: TPInks) -> some View {
        ZStack(alignment: .topLeading) {
            TPTitle(text: month, size: 22, inks: inks)
                .padding(.leading, 16).padding(.top, 16)
            VStack(alignment: .leading, spacing: -2) {
                TPTemperature(text: temperature, size: 30, inks: inks)
                Text(shortCondition.uppercased())
                    .font(TPType.bold(8)).tracking(1.1)
                    .foregroundStyle(inks.title.color)
                    .lineLimit(1)
            }
            .padding(.leading, 16)
            .frame(height: 164 - 34 - 2, alignment: .bottomLeading)
            TPCaption(text: nextSunLine, inks: inks, height: 34)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }

    // MARK: Words

    private var month: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: snapshot.date).uppercased()
    }

    private var temperature: String {
        guard let w = snapshot.weather else { return "–°" }
        return "\(Int(w.temperature.rounded()))°"
    }

    private var conditionLine: String {
        guard let w = snapshot.weather else { return "Weather unavailable" }
        return w.label
    }

    private var shortCondition: String {
        guard let w = snapshot.weather else { return "No weather" }
        return w.label
    }

    private var rangeLine: String {
        guard let w = snapshot.weather else { return snapshot.weatherError ?? "Offline" }
        return "HIGH \(Int(w.high.rounded()))  ·  LOW \(Int(w.low.rounded()))"
    }

    private var sunLine: String {
        "SUNRISE \(TPTime.string(snapshot.weather?.sunrise))   ·   SUNSET \(TPTime.string(snapshot.weather?.sunset))"
    }

    /// The small poster's caption: whichever of the two comes next.
    private var nextSunLine: String {
        guard let w = snapshot.weather, let rise = w.sunrise, let set = w.sunset else { return "SUNSET --" }
        let cal = Calendar.current
        func today(_ d: Date) -> Date {
            let c = cal.dateComponents([.hour, .minute], from: d)
            return cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: snapshot.date) ?? d
        }
        if snapshot.date < today(rise) || snapshot.date > today(set) { return "SUNRISE \(TPTime.string(rise))" }
        return "SUNSET \(TPTime.string(set))"
    }
}

/// Clock times as the poster prints them, "6:14", in the 12-hour style whatever the system's clock setting.
enum TPTime {
    static func string(_ date: Date?) -> String {
        guard let date else { return "--" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }
}

/// The month in poster capitals: cream, over a vermilion pull that slipped a hair down and to the right.
struct TPTitle: View {
    var text: String
    var size: CGFloat
    var inks: TPInks

    var body: some View {
        let slip = max(1, size * 0.03)
        ZStack(alignment: .topLeading) {
            Text(text).foregroundStyle(inks.register.color).offset(x: slip, y: slip * 0.8)
            Text(text).foregroundStyle(inks.title.color)
        }
        .font(TPType.display(size))
        .tracking(size * 0.03)
        .lineLimit(1)
        .fixedSize()
    }
}

struct TPTemperature: View {
    var text: String
    var size: CGFloat
    var inks: TPInks

    var body: some View {
        let slip = max(0.8, size * 0.022)
        ZStack(alignment: .topLeading) {
            Text(text).foregroundStyle(inks.field.mix(.init(0x000000), 0.35).color).offset(x: slip, y: slip)
            Text(text).foregroundStyle(inks.title.color)
        }
        .font(TPType.display(size))
        .lineLimit(1)
        .fixedSize()
    }
}

/// The caption band: the paper left unprinted along the foot of the poster, two rules and the sun's times.
struct TPCaption: View {
    var text: String
    var inks: TPInks
    var height: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(inks.paper.color)
            VStack(spacing: 1.6) {
                Rectangle().fill(inks.caption.color).frame(height: 1.6)
                Rectangle().fill(inks.caption.color).frame(height: 0.6)
            }
            .padding(.top, 3)
            HStack(spacing: 7) {
                TPHorizonSun(rising: true, ink: inks.accent)
                Text(text)
                    .font(TPType.bold(text.count > 20 ? 9.5 : 10))
                    .tracking(text.count > 20 ? 1.6 : 2.0)
                    .foregroundStyle(inks.caption.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                TPHorizonSun(rising: false, ink: inks.accent)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
        }
        .frame(height: height)
    }
}

/// A half sun on the horizon line, with a small chevron for rising or setting.
struct TPHorizonSun: View {
    var rising: Bool
    var ink: TPRGB

    var body: some View {
        Canvas { ctx, size in
            let r: CGFloat = 4
            let c = CGPoint(x: size.width / 2, y: size.height - 1.4)
            var half = Path()
            half.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            half.closeSubpath()
            ctx.fill(half, with: .color(ink.color))
            ctx.fill(Path(CGRect(x: 0, y: size.height - 1.1, width: size.width, height: 1.1)), with: .color(ink.color))
        }
        .frame(width: 12, height: 7)
    }
}
