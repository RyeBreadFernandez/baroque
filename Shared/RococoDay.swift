import SwiftUI
import WidgetKit

// The Day widget in rococo: small is Sun Arc, the sun's path carved into painted limestone with the day gone inlaid
// in gold; medium adds the days ahead beside it; large is one of the user's photographs, repainted, a new one every
// three hours (RococoPhotos), with the date and the temperature, a line from the vault with who said it, and the
// weather.

struct RococoDayView: View {
    var snapshot: DaySnapshot
    /// The large widget's line from the vault.
    var quote: Quote?
    var size: BaroqueSize

    var body: some View {
        RococoFrame(size: size) {
            switch size {
            case .small: RococoSunArc(snap: snapshot)
            case .medium: RococoSunArcMedium(snap: snapshot)
            case .large: RococoHero(snap: snapshot, quote: quote)
            }
        }
    }
}

/// The sun's path carved as an arc above a carved horizon, the day gone inlaid in gold, the gold sun raised where it
/// is now (the moon in its phase by night); sunrise and sunset under the feet, and the length of the day.
struct RococoSunArc: View {
    var snap: DaySnapshot
    /// False when it sits on a wider slab (RococoSunArcMedium).
    var slab = true

    var body: some View {
        let size = BaroqueSize.small.designSize
        let clock = SkyClock(now: snap.date, weather: snap.weather)
        let arc = SkyArc(centerX: 0.5, horizon: 0.56, radiusX: 0.37, radiusY: 0.4)
        let done = snap.weather == nil ? 0 : min(1, max(0, clock.progress))
        let sun = arc.point(done, in: size)
        ZStack(alignment: .topLeading) {
            if slab { RococoSlab() }
            RococoCarve(shape: RococoLine(), width: 1)
                .frame(width: 140, height: 2)
                .position(x: 82, y: arc.point(0, in: size).y + 1)
            RococoCarve(shape: RococoArcPath(arc: arc, from: 0, to: 1), width: 1.8)
            RococoArcPath(arc: arc, from: 0, to: done)
                .stroke(RococoMaterial.gold.gradient, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .shadow(color: RococoInk.shadow.opacity(0.3), radius: 0.4, x: 0.3, y: 0.5)
            if clock.isDay {
                RococoSun(radius: 8.5).position(sun)
            } else {
                RococoMoon(phase: MoonPhase(date: snap.date), radius: 8).position(sun)
            }
            if let w = snap.weather, let rise = w.sunrise, let set = w.sunset {
                RococoSunTime(time: RococoWords.clock(rise), word: "SUNRISE", leading: true)
                    .rococoBaseline(x: 16, y: 113, in: size)
                RococoSunTime(time: RococoWords.clock(set), word: "SUNSET", leading: false)
                    .rococoBaseline(x: 148, y: 113, in: size, trailing: true)
                Text(RococoWords.daylight(snap).map { "\($0) of light" } ?? "")
                    .font(RococoType.italic(11.5))
                    .foregroundStyle(RococoInk.inkSoft)
                    .rococoBaseline(x: 16, y: 148, in: size)
            } else {
                // The readable error line: no weather, cached or fresh.
                Text(snap.weatherError ?? "No sun times yet.")
                    .font(RococoType.sans(9.5))
                    .foregroundStyle(RococoInk.terracotta)
                    .lineLimit(2)
                    .frame(width: 132, alignment: .leading)
                    .rococoBaseline(x: 16, y: 118, in: size)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

struct RococoSunTime: View {
    var time: String
    var word: String
    var leading: Bool

    var body: some View {
        VStack(alignment: leading ? .leading : .trailing, spacing: 2) {
            Text(time).font(RococoType.serif(17)).foregroundStyle(RococoInk.ink)
            Text(word).font(RococoType.sansMedium(6.5)).tracking(1.6).foregroundStyle(RococoInk.inkSoft)
        }
        .fixedSize()
    }
}

/// The days after today, ruled with carved lines: the day by date, its weather raised, the high and the low. A day
/// likely to rain is named in terracotta.
struct RococoDaysAhead: View {
    var snap: DaySnapshot
    /// True on its own slab (the Days Ahead widget): with no Sun Arc beside it to show the weather's error line, it
    /// shows it itself.
    var showsError = false

    var body: some View {
        let size = BaroqueSize.small.designSize
        // Only the days after the snapshot's own: after midnight, the forecast fetched yesterday still starts with the
        // day that is now today.
        let cal = Calendar.current
        let today = cal.startOfDay(for: snap.date)
        let days = Array((snap.weather?.days ?? []).filter { cal.startOfDay(for: $0.date) > today }.prefix(4))
        ZStack(alignment: .topLeading) {
            Text("The days ahead").font(RococoType.serif(15.5)).foregroundStyle(RococoInk.ink)
                .rococoBaseline(x: 16, y: 29, in: size)
            if days.isEmpty {
                // Beside Sun Arc, Sun Arc shows any weather error; on its own slab it says why there's no forecast.
                Text(showsError ? (snap.weatherError ?? "No forecast yet.") : "No forecast yet.")
                    .font(RococoType.sans(9.5))
                    .foregroundStyle(RococoInk.terracotta)
                    .lineLimit(3)
                    .frame(width: 132, alignment: .leading)
                    .rococoBaseline(x: 16, y: 58, in: size)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                        if i > 0 { RococoCarve(shape: RococoLine(), width: 0.6).frame(height: 1) }
                        HStack(spacing: 0) {
                            Text(RococoWords.dayName(d.date, from: snap.date))
                                .font(RococoType.sans(10.5))
                                .foregroundStyle((d.rain ?? 0) >= 50 ? RococoInk.terracotta : RococoInk.ink)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            let symbol = WeatherCode.symbol(for: d.code)
                            RococoSymbol(name: symbol, material: symbol.hasPrefix("sun") ? .gold : .cream, size: 11)
                                .frame(width: 22)
                            // Wide enough for 112°  88° and -12°  -21° (about 49 points; anything wider shrinks a
                            // little), and the day's name keeps 54, enough for "tomorrow".
                            (Text("\(Int(d.high.rounded()))°").foregroundColor(RococoInk.ink)
                                + Text("  \(Int(d.low.rounded()))°").foregroundColor(RococoInk.inkFaint))
                                .font(RococoType.serif(12))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: 54, alignment: .trailing)
                        }
                        .frame(height: 24)
                    }
                }
                .frame(width: 132)
                .offset(x: 16, y: 42)
                // On its own, a failed fetch is named under the cached days (they end at 141 points).
                if showsError, let error = snap.weatherError {
                    Text(error)
                        .font(RococoType.sans(8))
                        .foregroundStyle(RococoInk.terracotta)
                        .lineLimit(1)
                        .frame(width: 132, alignment: .leading)
                        .rococoBaseline(x: 16, y: 154, in: size)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The days ahead on a slab of their own: the Days Ahead widget (small; 2026-11-11, "make the days ahead its own
/// widget"). The same panel the medium Day shows beside Sun Arc, with the weather's error line when a fetch fails.
struct RococoDaysAheadView: View {
    var snapshot: DaySnapshot

    var body: some View {
        RococoFrame(size: .small) {
            ZStack(alignment: .topLeading) {
                RococoSlab()
                RococoDaysAhead(snap: snapshot, showsError: true)
            }
        }
    }
}

/// Sun Arc on the left, the days ahead on the right, a carved line between, on one slab.
struct RococoSunArcMedium: View {
    var snap: DaySnapshot

    var body: some View {
        let size = BaroqueSize.medium.designSize
        ZStack(alignment: .topLeading) {
            RococoSlab()
            RococoSunArc(snap: snap, slab: false)
            RococoCarve(shape: RococoLine(vertical: true), width: 0.7)
                .frame(width: 2, height: 124)
                .position(x: 174, y: size.height / 2)
            RococoDaysAhead(snap: snap)
                .offset(x: 176)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The large widget: one of the user's photographs in turn (`RococoPhotos.large(at:)`), repainted, its corners
/// darkened as on an old canvas; the date and the temperature at the top right, the line from the vault in italic
/// down the left with who said it, and the weather in spaced capitals. Both sets of words sit on a soft dark ground
/// that follows them (`RococoWordsGround`), so they read on the brightest photograph by day.
struct RococoHero: View {
    var snap: DaySnapshot
    var quote: Quote?
    /// Set by RococoFrame (RococoDayView draws this inside one).
    @Environment(\.rococoAccented) private var accented

    var body: some View {
        let size = BaroqueSize.large.designSize
        let night = !SkyClock(now: snap.date, weather: snap.weather).isDay
        let w = snap.weather
        ZStack(alignment: .topLeading) {
            RococoPicture(name: RococoPhotos.large(at: snap.date), night: night)
            RococoCorners()
            // On tinted and clear home screens iOS would draw these shades in the words' own tint.
            if !accented {
                let k = RococoTheme.current.scrim
                LinearGradient(colors: [Color(hex: 0x3A2C1F).opacity(min(0.9, 0.55 * k)), Color(hex: 0x3A2C1F).opacity(min(0.6, 0.22 * k)), .clear],
                               startPoint: .leading, endPoint: UnitPoint(x: 0.7, y: 0.5))
                LinearGradient(colors: [Color(hex: 0x3A2C1F).opacity(min(0.6, 0.3 * k)), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3))
            }
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(RococoWords.month(snap.date)) \(RococoWords.day(snap.date))")
                    .font(RococoType.serif(17))
                Text(RococoWords.temp(w))
                    .font(RococoType.serif(56))
                    .padding(.top, -4)
            }
            .foregroundStyle(RococoInk.cream)
            .shadow(color: RococoInk.shadow.opacity(0.5), radius: 4, x: 0, y: 1)
            .fixedSize()
            .modifier(RococoWordsGround(strength: 0.18, night: night))
            .rococoBaseline(x: 330, y: 36, in: size, trailing: true)
            // From 112 points down to 22 above the foot. A long line shrinks to keep its author and the weather in
            // place below it.
            RococoWordsStack(cap: 150, room: size.height - 112 - 22) {
                if let quote {
                    Text(quote.text)
                        .font(RococoType.italic(27))
                        .lineSpacing(-1)
                        .foregroundStyle(RococoInk.cream)
                        .minimumScaleFactor(0.5)
                        .lineLimit(6)
                    // Who said it, from the quote's own author line in the vault (never made up; none, no line).
                    if let author = quote.author, !author.isEmpty {
                        Text(author.uppercased())
                            .font(RococoType.sansMedium(8))
                            .tracking(1.5)
                            .foregroundStyle(RococoInk.cream.opacity(0.85))
                            .lineLimit(2)
                            .padding(.top, 9)
                    }
                    Rectangle().fill(RococoInk.cream.opacity(0.75)).frame(width: 20, height: 0.8)
                        .padding(.top, quote.author?.isEmpty == false ? 12 : 16)
                }
                VStack(alignment: .leading, spacing: 6) {
                    if let w {
                        Text(w.label.uppercased())
                        Text("HIGH \(Int(w.high.rounded()))  ·  LOW \(Int(w.low.rounded()))")
                        if let set = w.sunset { Text("SUNSET \(RococoWords.clock(set))") }
                    }
                    if let e = snap.weatherError {
                        Text(e.uppercased()).lineLimit(2)
                    }
                }
                .font(RococoType.sansMedium(8.5))
                .tracking(2.2)
                .foregroundStyle(RococoInk.cream.opacity(0.92))
                .padding(.top, 13)
            }
            .shadow(color: RococoInk.shadow.opacity(0.5), radius: 5, x: 0, y: 1)
            .modifier(RococoWordsGround(strength: 0.16, night: night))
            .frame(width: 196, alignment: .topLeading)
            .offset(x: 22, y: 112)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}
