import SwiftUI

// The Weather widget. The painted sky over the Matterhorn is the sun's path: a fine gilt arc, solid for the daylight
// gone and dashed for what is left, the sun (or tonight's moon) glowing where it is now, sunrise and sunset engraved at
// the arc's feet. The hero is the temperature in raised gilt Baskerville on the painting's dark ground, with the
// condition in italic beside it, high and low, and the month in spaced capitals over the sky.
//
// Every layout is fixed at the iPhone 17 widget size (the paintings are composed round it).

struct SAWeather: View {
    var snap: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .large: SAWeatherLarge(snap: snap)
        case .medium: SAWeatherMedium(snap: snap)
        case .small: SAWeatherSmall(snap: snap)
        }
    }
}

/// What every size reads off the snapshot.
struct SAReading {
    var snap: DaySnapshot
    var clock: SkyClock
    var light: CoverLight

    init(_ snap: DaySnapshot) {
        self.snap = snap
        clock = SkyClock(now: snap.date, weather: snap.weather)
        light = CoverLight(clock: clock, condition: SkyCondition(code: snap.weather?.code))
    }

    var feet: (left: SAWords.Foot, right: SAWords.Foot)? { SAWords.feet(snap, clock: clock) }
    var next: (rise: Bool, time: String, wait: TimeInterval)? { SAWords.next(snap) }
    var month: String { SAWords.month(snap.date) }
}

// MARK: - Large

/// The painting fills the top 60%: the month over the sky, the arc spanning it over the Matterhorn, the times at its
/// feet on the ridge. The dark ground below: the gilt temperature, and beside it the condition, high and low, and how
/// long until the sun next sets (or, at night, when it rises).
struct SAWeatherLarge: View {
    var snap: DaySnapshot

    var body: some View {
        let r = SAReading(snap)
        let size = Mock.size(.large)
        let arc = SACanvas.large.arc
        let left = arc.point(0, in: size), right = arc.point(1, in: size)
        ZStack(alignment: .topLeading) {
            SAScene(canvas: .large, snap: snap)
            SADateline(month: r.month, day: SAWords.day(snap.date), size: 9)
                .saBaseline(x: 16, y: 25, in: size)
            if let feet = r.feet {
                SAFoot(rise: feet.left.rise, time: feet.left.time, light: r.light, markFirst: true, size: 13.5)
                    .saCenterY(leading: left.x - 7.3, y: 221, in: size)
                SAFoot(rise: feet.right.rise, time: feet.right.time, light: r.light, markFirst: false, size: 13.5)
                    .saCenterY(trailing: right.x + 7.3, y: 221, in: size)
            }
            SAGilt(text: SAWords.tempText(snap.weather, size: 100), light: r.light)
                .saBaseline(x: 16, y: 334, in: size)
            SALargeNotes(r: r)
                .frame(width: 150, alignment: .leading)
                .saBaseline(x: 180, y: 286, in: size)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The column beside the large temperature.
struct SALargeNotes: View {
    var r: SAReading

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let w = r.snap.weather {
                Text(SAWords.condition(w))
                    .font(SAType.italic(21))
                    .foregroundStyle(CoverInk.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(SAWords.highLow(w))
                    .coverLabel(10, CoverInk.creamSoft)
                    .padding(.top, 5)
                SARule()
                    .padding(.top, 9)
                Group {
                    if let n = r.next {
                        if r.clock.isDay {
                            Text("sunset in \(SAWords.span(n.wait))")
                        } else {
                            Text("\(n.rise ? "sunrise" : "sunset") \(n.time)")
                        }
                    }
                }
                .font(SAType.italic(13))
                .foregroundStyle(CoverInk.creamSoft)
                .padding(.top, 8)
            } else {
                Text("weather offline")
                    .font(SAType.italic(19))
                    .foregroundStyle(CoverInk.creamSoft)
                SARule()
                    .padding(.top, 9)
                Text(r.snap.weatherError ?? "no weather yet")
                    .coverLabel(9.5, CoverInk.peach)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .coverOnPaint(0.6)
    }
}

// MARK: - Medium

/// Left, on the dark wall of firs: the month, the gilt temperature, the condition and high and low. Right: a wide arc
/// over the Matterhorn with the times at its feet.
struct SAWeatherMedium: View {
    var snap: DaySnapshot

    var body: some View {
        let r = SAReading(snap)
        let size = Mock.size(.medium)
        let arc = SACanvas.medium.arc
        let left = arc.point(0, in: size), right = arc.point(1, in: size)
        ZStack(alignment: .topLeading) {
            SAScene(canvas: .medium, snap: snap)
            SADateline(month: r.month, day: SAWords.day(snap.date), size: 8.5)
                .saBaseline(x: 16, y: 24, in: size)
            if let feet = r.feet {
                SAFoot(rise: feet.left.rise, time: feet.left.time, light: r.light, markFirst: true, size: 12)
                    .saCenterY(leading: left.x - 6.5, y: 136, in: size)
                SAFoot(rise: feet.right.rise, time: feet.right.time, light: r.light, markFirst: false, size: 12)
                    .saCenterY(trailing: right.x + 6.5, y: 136, in: size)
            }
            SAGilt(text: SAWords.tempText(snap.weather, size: 66), light: r.light, depth: 0.75)
                .saBaseline(x: 16, y: 96, in: size)
            Group {
                if let w = snap.weather {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SAWords.condition(w))
                            .font(SAType.italic(14.5))
                            .foregroundStyle(CoverInk.cream)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(Int(w.high.rounded()))°  ·  \(Int(w.low.rounded()))°")
                            .coverLabel(9, CoverInk.creamSoft)
                            .lineLimit(1)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("weather offline")
                            .font(SAType.italic(14))
                            .foregroundStyle(CoverInk.creamSoft)
                        Text(snap.weatherError ?? "no weather yet")
                            .coverLabel(8.5, CoverInk.peach)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(width: 104, alignment: .leading)
            .coverOnPaint(0.6)
            .saBaseline(x: 16, y: 120, in: size)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

// MARK: - Small

/// A compact arc over the peak, the next sun time at the foot it is heading for, and on the dark ground the gilt
/// temperature with the condition.
struct SAWeatherSmall: View {
    var snap: DaySnapshot

    var body: some View {
        let r = SAReading(snap)
        let size = Mock.size(.small)
        let arc = SACanvas.small.arc
        let right = arc.point(1, in: size)
        ZStack(alignment: .topLeading) {
            SAScene(canvas: .small, snap: snap)
            Text(r.month).coverCaps(8, CoverInk.creamSoft, tracking: 2)
                .coverOnSky()
                .saBaseline(x: 16, y: 23, in: size)
            if let n = r.next {
                SAFoot(rise: n.rise, time: n.time, light: r.light, markFirst: false, size: 12.5)
                    .saCenterY(trailing: right.x + 6.5, y: 117, in: size)
            }
            SAGilt(text: SAWords.tempText(snap.weather, size: 52), light: r.light, depth: 0.6)
                .saBaseline(x: 16, y: 145, in: size)
            Group {
                if let w = snap.weather {
                    Text(SAWords.condition(w))
                        .font(SAType.italic(11))
                        .foregroundStyle(CoverInk.creamSoft)
                        .minimumScaleFactor(0.8)
                } else {
                    Text("offline")
                        .font(SAType.italic(11))
                        .foregroundStyle(CoverInk.peach)
                }
            }
            .lineLimit(1)
            .coverOnPaint(0.6)
            .saBaseline(x: 148, y: 144, in: size, trailing: true)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

// MARK: - Pieces

/// The month in spaced capitals, with the day after it, quieter.
struct SADateline: View {
    var month: String
    var day: String?
    var size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(month).coverCaps(size, CoverInk.cream, tracking: 2.6)
            if let day { Text(day).coverCaps(size, CoverInk.creamFaint, tracking: 1.4) }
        }
        .fixedSize()
        .coverOnSky()
    }
}

/// A hairline of cream, brighter in the middle.
struct SARule: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [CoverInk.cream.opacity(0.3), CoverInk.cream.opacity(0.18), CoverInk.cream.opacity(0.02)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.6)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Places a view so its first baseline sits at y, its leading (or trailing) edge at x, in a widget-size layer.
    func saBaseline(x: CGFloat, y: CGFloat, in size: CGSize, trailing: Bool = false) -> some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay(alignment: trailing ? .topTrailing : .topLeading) {
                self.alignmentGuide(.top) { $0[.firstTextBaseline] }
                    .offset(x: trailing ? x - size.width : x, y: y)
            }
    }

    /// Places a view with its vertical centre at y and its leading edge at x.
    func saCenterY(leading x: CGFloat, y: CGFloat, in size: CGSize) -> some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) {
                self.alignmentGuide(.top) { $0[VerticalAlignment.center] }
                    .offset(x: x, y: y)
            }
    }

    /// Places a view with its vertical centre at y and its trailing edge at x.
    func saCenterY(trailing x: CGFloat, y: CGFloat, in size: CGSize) -> some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topTrailing) {
                self.alignmentGuide(.top) { $0[VerticalAlignment.center] }
                    .offset(x: x - size.width, y: y)
            }
    }
}
