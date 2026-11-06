import SwiftUI

// The Weather widget: the storybook plate in its frame, and on the plate's dark passages the month as a chapter
// heading, the temperature, the weather as an emblem and a word, and sunrise and sunset lettered on a ribbon that
// lies on the dark near bank.
//
// Layout (points; the plate's darker passages, kept clear of the Matterhorn, are where the type stands):
//   large 348x365   chapter heading, temperature, weather and high/low down the dark upper-left sky (x 24..170,
//                   y 22..150); the summit stands right of it at (231, 89); the ribbon is centred on the bank at y 333
//   medium 348x164  the heading, then the temperature with the weather beside it, in the sky left of the peak
//                   (x 24..210); the ribbon on the dark bank at the lower left, y 139
//   small 164x164   the month, the temperature with its emblem, the weather word, in the sky left of the peak; the
//                   next of sunrise or sunset on a short ribbon at the foot, y 138

struct SBWeather: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        SBFramed(family: family, ornament: family == .large) {
            SBPlate(snapshot: snapshot, family: family)
        }
        .overlay(alignment: .topLeading) {
            switch family {
            case .large: large
            case .medium: medium
            case .small: small
            }
        }
    }

    private var weather: WeatherSnapshot? { snapshot.weather }
    private var clock: SkyClock { SkyClock(now: snapshot.date, weather: weather) }
    private var condition: SkyCondition { SkyCondition(code: weather?.code) }

    // MARK: Large

    private var large: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                SBChapterHeading(date: snapshot.date, size: .large)
                temperature(64)
                    .padding(.top, 8)
                conditionLine(emblem: 19, font: 15)
                    .padding(.top, 2)
                highLow(11.5)
                    .padding(.top, 5)
            }
            .padding(.leading, 24)
            .padding(.top, 21)

            sunRibbon(height: 21, font: 13.5, glyph: 12)
                .frame(width: Mock.size(.large).width)
                .position(x: Mock.size(.large).width / 2, y: 333)
        }
        .frame(width: Mock.size(.large).width, height: Mock.size(.large).height, alignment: .topLeading)
    }

    // MARK: Medium

    private var medium: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                SBChapterHeading(date: snapshot.date, size: .medium)
                HStack(alignment: .center, spacing: 12) {
                    temperature(48)
                    VStack(alignment: .leading, spacing: 4) {
                        conditionLine(emblem: 16, font: 13.5)
                        highLow(10.5)
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 4)
            }
            .padding(.leading, 24)
            .padding(.top, 19)

            sunRibbon(height: 19, font: 12.5, glyph: 11)
                .fixedSize()
                .position(x: 96, y: 139)
        }
        .frame(width: Mock.size(.medium).width, height: Mock.size(.medium).height, alignment: .topLeading)
    }

    // MARK: Small

    private var small: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                SBChapterHeading(date: snapshot.date, size: .small)
                HStack(alignment: .top, spacing: 5) {
                    temperature(38)
                    if weather != nil {
                        SBConditionEmblem(condition: condition, isDay: clock.isDay, size: 15)
                            .sbLegible(0.8)
                            .padding(.top, 9)
                    }
                }
                .padding(.top, 2)
                Text(weather.map { $0.label } ?? (snapshot.weatherError.map { "No weather · \($0)" } ?? "No weather"))
                    .font(SBFont.italic(11.5))
                    .foregroundStyle(SBInk.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: 74, alignment: .leading)
                    .sbLegible()
            }
            .padding(.leading, 22)
            .padding(.top, 21)

            nextSunRibbon
                .fixedSize()
                .position(x: Mock.size(.small).width / 2, y: 138)
        }
        .frame(width: Mock.size(.small).width, height: Mock.size(.small).height, alignment: .topLeading)
    }

    // MARK: Pieces

    private func temperature(_ size: CGFloat) -> some View {
        // With no weather, a dash at the height of the figures' middle stands in for the number.
        HStack(alignment: .firstTextBaseline, spacing: size * 0.06) {
            if let weather {
                Text("\(Int(weather.temperature.rounded()))°")
            } else {
                Capsule()
                    .frame(width: size * 0.42, height: max(1.5, size * 0.055))
                    .offset(y: -size * 0.24)
                Text("°")
            }
        }
            .font(SBFont.roman(size))
            .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFBF3DE), SBInk.cream, Color(hex: 0xE2D3AE)],
                                            startPoint: .top, endPoint: .bottom))
            .lineLimit(1)
            .fixedSize()
            .sbLegible()
    }

    private func conditionLine(emblem: CGFloat, font: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if let weather {
                SBConditionEmblem(condition: condition, isDay: clock.isDay, size: emblem)
                Text(weather.label)
                    .font(SBFont.italic(font))
                    .foregroundStyle(SBInk.cream)
            } else {
                Text("No weather" + (snapshot.weatherError.map { " · \($0)" } ?? ""))
                    .font(SBFont.italic(font))
                    .foregroundStyle(SBInk.cream)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .sbLegible()
    }

    @ViewBuilder private func highLow(_ size: CGFloat) -> some View {
        if let weather {
            HStack(spacing: 5) {
                Text("High \(Int(weather.high.rounded()))°")
                SBStar(points: 4, inner: 0.35).fill(SBInk.gold).frame(width: 5, height: 5)
                Text("Low \(Int(weather.low.rounded()))°")
            }
            .font(SBFont.roman(size))
            .tracking(0.3)
            .foregroundStyle(SBInk.creamDim)
            .fixedSize()
            .sbLegible()
        }
    }

    private func sunRibbon(height: CGFloat, font: CGFloat, glyph: CGFloat) -> some View {
        SBRibbon(height: height, tail: height * 0.55) {
            HStack(spacing: 6) {
                SBSunGlyph(size: glyph)
                Text(SBText.time(weather?.sunrise))
                SBStar(points: 4, inner: 0.35).fill(SBInk.gold).frame(width: 5, height: 5)
                    .padding(.horizontal, 3)
                SBMoonGlyph(size: glyph)
                Text(SBText.time(weather?.sunset))
            }
            .font(SBFont.roman(font))
            .foregroundStyle(SBInk.cream)
            .padding(.top, 1)
        }
        .fixedSize()
    }

    /// The next of sunrise or sunset (tomorrow's sunrise once the sun has set).
    private var nextSunRibbon: some View {
        let cal = Calendar.current
        func today(_ d: Date?) -> Date? {
            guard let d else { return nil }
            let c = cal.dateComponents([.hour, .minute], from: d)
            return cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: snapshot.date)
        }
        let rise = today(weather?.sunrise), set = today(weather?.sunset)
        let nextIsSunset = rise.map { snapshot.date >= $0 } ?? false && set.map { snapshot.date < $0 } ?? false
        return SBRibbon(height: 18, tail: 9) {
            HStack(spacing: 4) {
                if nextIsSunset { SBMoonGlyph(size: 11) } else { SBSunGlyph(size: 11) }
                Text(nextIsSunset ? "sunset" : "sunrise")
                    .font(SBFont.italic(10.5))
                    .foregroundStyle(SBInk.creamDim)
                Text(SBText.time(nextIsSunset ? weather?.sunset : weather?.sunrise))
                    .font(SBFont.roman(12.5))
                    .foregroundStyle(SBInk.cream)
            }
            .padding(.top, 1)
        }
    }
}

/// The month as the heading of a chapter: "CHAPTER XI" over "November" in capitals with a gilt initial.
struct SBChapterHeading: View {
    enum Size { case large, medium, small }
    var date: Date
    var size: Size

    var body: some View {
        let month = SBText.month(date).uppercased()
        let chapter = SBText.chapter(date).uppercased()
        switch size {
        case .large:
            VStack(alignment: .leading, spacing: 1) {
                Text(chapter)
                    .font(SBFont.roman(9.5))
                    .tracking(2.6)
                    .foregroundStyle(SBInk.gold)
                initialed(month, initial: 26, rest: 17, tracking: 2.4)
                SBFlourish()
                    .stroke(SBGilt.fill, style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                    .frame(width: 96, height: 7)
                    .padding(.top, 2)
            }
            .sbLegible()
        case .medium:
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(chapter)
                    .font(SBFont.roman(9))
                    .tracking(2.2)
                    .foregroundStyle(SBInk.gold)
                SBStar(points: 4, inner: 0.35).fill(SBInk.gold).frame(width: 5, height: 5)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 0.5 }
                initialed(month, initial: 16, rest: 11, tracking: 1.8)
            }
            .sbLegible()
        case .small:
            initialed(month, initial: 15, rest: 10, tracking: 1.6)
                .sbLegible()
        }
    }

    private func initialed(_ word: String, initial: CGFloat, rest: CGFloat, tracking: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0.5) {
            Text(String(word.prefix(1)))
                .font(SBFont.roman(initial))
                .foregroundStyle(SBGilt.fill)
            Text(String(word.dropFirst()))
                .font(SBFont.roman(rest))
                .tracking(tracking)
                .foregroundStyle(SBInk.cream)
        }
        .fixedSize()
    }
}
