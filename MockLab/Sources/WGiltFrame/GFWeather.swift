import SwiftUI

// The Weather widget: one gilt frame holding the painting, hung on the damask wall, and one engraved brass plate
// for the month, the temperature, the condition and the sun's times. Large hangs the plate under a square frame,
// medium beside a landscape frame, small sets a one-line plate into the frame's bottom rail.

struct GFWeather: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        let size = Mock.size(family)
        let frame = GFGeometry.frame(family)
        let night = !SkyClock(now: snapshot.date, weather: snapshot.weather).isDay
        let focus = UnitPoint(x: frame.rect.midX / size.width, y: max(0, frame.rect.minY - 30) / size.height)
        ZStack(alignment: .topLeading) {
            GFWall(size: size, focus: focus, night: night)
            GFFrameShadow(texture: frame.texture)
            GFPainting(family: family, snapshot: snapshot)
                .offset(x: frame.sight.minX, y: frame.sight.minY)
            GFFrameGilt(frame: frame, dim: night ? 0.86 : 1)
            plate(night: night)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder
    private func plate(night: Bool) -> some View {
        let dim = night ? 0.84 : 1.0
        switch family {
        case .large:
            GFPlaque(size: CGSize(width: 244, height: 64), dim: dim) { GFLargePlate(snapshot: snapshot) }
                .position(x: 174, y: 312)
        case .medium:
            GFPlaque(size: CGSize(width: 130, height: 120), screws: false, dim: dim) { GFMediumPlate(snapshot: snapshot) }
                .position(x: 268, y: 84)
        case .small:
            GFPlaque(size: CGSize(width: 122, height: 19), screws: false, dim: dim) { GFSmallPlate(snapshot: snapshot) }
                .position(x: 82, y: 139)
        }
    }
}

/// The condition in words: the weather's label, or a readable line when the fetch failed.
private func gfCondition(_ s: DaySnapshot) -> String {
    if let w = s.weather { return w.label }
    if let e = s.weatherError, !e.isEmpty { return "No weather: \(e)" }
    return "No weather yet"
}

/// Large: the temperature cut deep at the left; the month, the condition with the day's range, and both sun times.
struct GFLargePlate: View {
    var snapshot: DaySnapshot

    var body: some View {
        let w = snapshot.weather
        HStack(alignment: .center, spacing: 11) {
            Text(GFWords.temp(w))
                .font(GFType.numeral(42))
                .kerning(-0.5)
                .lineLimit(1)
                .fixedSize()
                .gfEngraved()
                .frame(minWidth: 62, alignment: .center)
            GFRule(vertical: true).frame(height: 42)
            VStack(alignment: .leading, spacing: 2.5) {
                Text("\(GFWords.month(snapshot.date)) \(GFWords.day(snapshot.date))")
                    .font(GFType.caps(11.5))
                    .tracking(2.2)
                    .gfEngraved()
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(gfCondition(snapshot))
                        .font(GFType.italic(14.5))
                        .gfEngraved()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let w {
                        Text("H \(GFWords.degrees(w.high))  L \(GFWords.degrees(w.low))")
                            .font(GFType.caps(8.5))
                            .tracking(0.6)
                            .gfEngraved(GFInk.engravedSoft)
                            .fixedSize()
                    }
                }
                if let w {
                    GFSunTimes(rise: w.sunrise, set: w.sunset, size: 9)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
    }
}

/// Sunrise and sunset, engraved: a small sun on the horizon with its arrow, and the time.
struct GFSunTimes: View {
    var rise: Date?
    var set: Date?
    var size: CGFloat
    var spacing: CGFloat = 10

    var body: some View {
        HStack(spacing: spacing) {
            pair("sunrise.fill", GFWords.clock(rise))
            pair("sunset.fill", GFWords.clock(set))
        }
    }

    private func pair(_ symbol: String, _ time: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.95, weight: .regular))
                .symbolRenderingMode(.monochrome)
            Text(time)
                .font(GFType.caps(size + 1))
                .tracking(0.5)
        }
        .gfEngraved()
        .fixedSize()
    }
}

/// Medium: a tall plate beside the frame, centred like a museum label.
struct GFMediumPlate: View {
    var snapshot: DaySnapshot

    var body: some View {
        let w = snapshot.weather
        VStack(spacing: 0) {
            Text("\(GFWords.month(snapshot.date)) \(GFWords.day(snapshot.date))")
                .font(GFType.caps(10))
                .tracking(1.6)
                .gfEngraved()
                .padding(.bottom, 4)
            GFRule().frame(width: 56)
            Text(GFWords.temp(w))
                .font(GFType.numeral(40))
                .kerning(-0.5)
                .lineLimit(1)
                .fixedSize()
                .gfEngraved()
                .padding(.top, 1)
                .padding(.bottom, -2)
            Text(gfCondition(snapshot))
                .font(GFType.italic(13))
                .gfEngraved()
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
            if let w {
                Text("H \(GFWords.degrees(w.high))  ·  L \(GFWords.degrees(w.low))")
                    .font(GFType.caps(8))
                    .tracking(0.6)
                    .gfEngraved(GFInk.engravedSoft)
                    .padding(.top, 1)
                GFRule().frame(width: 56).padding(.vertical, 5)
                GFSunTimes(rise: w.sunrise, set: w.sunset, size: 8.5, spacing: 7)
            }
        }
        .padding(.horizontal, 8)
    }
}

/// Small: one line on the plate in the frame's bottom rail, with the next sun event.
struct GFSmallPlate: View {
    var snapshot: DaySnapshot

    var body: some View {
        let w = snapshot.weather
        let up = SkyClock(now: snapshot.date, weather: w).isDay
        HStack(spacing: 4) {
            Text(GFWords.temp(w))
                .font(GFType.caps(11))
            dot
            Text(GFWords.shortMonth(snapshot.date))
                .font(GFType.caps(10))
                .tracking(1)
            if let w {
                dot
                Text("\(up ? "↓" : "↑")\(GFWords.clock(up ? w.sunset : w.sunrise))")
                    .font(GFType.caps(10))
            } else {
                dot
                Text("offline").font(GFType.italic(10.5))
            }
        }
        .gfEngraved()
        .lineLimit(1)
        .fixedSize()
    }

    private var dot: some View {
        Text("·").font(GFType.caps(10))
    }
}
