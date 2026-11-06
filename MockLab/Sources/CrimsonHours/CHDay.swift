import SwiftUI

// Day widgets: the crimson room. A tear-off calendar on its nail, a lacquered window onto the ridges and the
// stair road (the weather written over the evening sky), and the day's tasks on a folded letter in lamplight.

enum CHDayText {
    static func temp(_ w: WeatherSnapshot) -> String { "\(Int(w.temperature.rounded()))°" }
    static func hiLo(_ w: WeatherSnapshot) -> String { "H \(Int(w.high.rounded()))°  ·  L \(Int(w.low.rounded()))°" }
    /// The next of sunset or sunrise, on a 12-hour clock whatever the region's setting.
    static func sunLine(_ w: WeatherSnapshot, now: Date = Mock.now) -> String? {
        if let set = w.sunset, now < set { return "sunset \(CHDates.string(set, "h:mm"))" }
        if let rise = w.sunrise { return "sunrise \(CHDates.string(rise, "h:mm"))" }
        return nil
    }
}

/// Weather lettered over the window's evening sky.
struct CHWeatherBlock: View {
    var weather: WeatherSnapshot?
    var temp: CGFloat
    var label: CGFloat
    var detail: CGFloat
    var showHiLo = true
    var showSun = true

    var body: some View {
        if let w = weather {
            VStack(alignment: .leading, spacing: 0) {
                Text(CHDayText.temp(w))
                    .font(CH.didot(temp))
                    .foregroundStyle(CH.cream)
                    .padding(.bottom, -temp * 0.08)
                Text(w.label)
                    .font(CH.baskItalic(label))
                    .foregroundStyle(CH.cream.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if showHiLo {
                    Text(CHDayText.hiLo(w))
                        .font(CH.label(detail))
                        .foregroundStyle(Color(hex: 0xC4CED6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 3)
                }
                if showSun, let sun = CHDayText.sunLine(w) {
                    Text(sun)
                        .font(CH.label(detail))
                        .foregroundStyle(CH.tungsten)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 1)
                }
            }
            .chHalo(Color(hex: 0x05080C), radius: 2, opacity: 0.9)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("No forecast")
                    .font(CH.baskItalic(label * 1.1))
                    .foregroundStyle(CH.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("weather unavailable")
                    .font(CH.label(detail))
                    .foregroundStyle(Color(hex: 0xC4CED6))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .chHalo(Color(hex: 0x05080C), radius: 2, opacity: 0.9)
        }
    }
}

/// A cigarette resting on the sill, its ember glowing.
enum CHCigarette {
    static func draw(_ ctx: GraphicsContext, at p: CGPoint, length: CGFloat = 9, k: CGFloat = 1) {
        let body = CGRect(x: p.x, y: p.y - 1.7 * k, width: length * k, height: 1.7 * k)
        var sh = ctx
        sh.addFilter(.blur(radius: 0.8))
        sh.fill(Path(body.offsetBy(dx: 0.6, dy: 1.2)), with: .color(.black.opacity(0.6)))
        ctx.fill(Path(roundedRect: body, cornerRadius: 0.8 * k), with: .linearGradient(Gradient(colors: [Color(hex: 0xF4EEE2), Color(hex: 0xB8AE9E)]),
                                                                    startPoint: CGPoint(x: body.minX, y: body.minY), endPoint: CGPoint(x: body.minX, y: body.maxY)))
        ctx.fill(Path(CGRect(x: body.maxX - 2.6 * k, y: body.minY, width: 2.6 * k, height: body.height)), with: .color(Color(hex: 0xC8884A)))
        let e = CGPoint(x: body.minX, y: body.midY)
        var glow = ctx
        glow.blendMode = .screen
        glow.fill(Path(ellipseIn: CGRect(x: e.x - 5 * k, y: e.y - 5 * k, width: 10 * k, height: 10 * k)),
                  with: .radialGradient(Gradient(colors: [Color(hex: 0xFF7A2A, opacity: 0.7), .clear]), center: e, startRadius: 0, endRadius: 5 * k))
        ctx.fill(Path(ellipseIn: CGRect(x: e.x - 1 * k, y: e.y - 0.9 * k, width: 1.8 * k, height: 1.8 * k)), with: .color(Color(hex: 0xFFB060)))
    }
}

// MARK: - Large

struct CHDayLarge: View {
    var snap: DaySnapshot
    private let size = Mock.size(.large)

    static let vista = CHVista(
        far: [CGPoint(x: -0.02, y: 0.70), CGPoint(x: 0.12, y: 0.64), CGPoint(x: 0.24, y: 0.69), CGPoint(x: 0.36, y: 0.63),
              CGPoint(x: 0.47, y: 0.61), CGPoint(x: 0.56, y: 0.34), CGPoint(x: 0.66, y: 0.12), CGPoint(x: 0.76, y: 0.30),
              CGPoint(x: 0.86, y: 0.20), CGPoint(x: 1.02, y: 0.38)],
        mid: [CGPoint(x: -0.02, y: 0.80), CGPoint(x: 0.3, y: 0.76), CGPoint(x: 0.5, y: 0.68), CGPoint(x: 0.64, y: 0.46),
              CGPoint(x: 0.76, y: 0.40), CGPoint(x: 0.9, y: 0.50), CGPoint(x: 1.02, y: 0.56)],
        near: [CGPoint(x: -0.02, y: 0.91), CGPoint(x: 0.4, y: 0.88), CGPoint(x: 0.75, y: 0.93), CGPoint(x: 1.02, y: 0.89)],
        road: 0.72, roadWidth: 0.2, moon: CGPoint(x: 0.82, y: 0.09), lamp: CGPoint(x: 0.12, y: 0.84), seed: 51,
        horizon: 0.68, roadFoot: 0.87, bolt: 0.62)

    private var outer: CGRect { CGRect(x: 142, y: 12, width: 192, height: 152) }

    var body: some View {
        let sky = CHSky.from(code: snap.weather?.code)
        ZStack(alignment: .topLeading) {
            CHWall(family: .large, pools: [CHPool(center: CGPoint(x: 60, y: 40), radius: 240),
                                           CHPool(center: CGPoint(x: 250, y: 330), radius: 170, strength: 0.55)], seed: 3)
            Canvas { ctx, s in
                let t: CGFloat = 7
                let glass = outer.insetBy(dx: t, dy: t)
                CHExterior.draw(ctx, in: glass, sky: sky, vista: Self.vista)
                CHGlass.draw(ctx, in: glass, sky: sky, vista: Self.vista, seed: 7)
                CHFrame.draw(ctx, outer: outer, thickness: t, mullions: [0.5])
                CHCigarette.draw(ctx, at: CGPoint(x: 290, y: outer.maxY + 1.5))
                CHSmoke.draw(ctx, from: CGPoint(x: 290, y: outer.maxY - 1), height: 150, drift: 0.1, seed: 17, opacity: 0.5)
                CHCurtain.draw(ctx, in: CGRect(x: 306, y: 6, width: 48, height: 176), seed: 21)
                CHCurtain.rod(ctx, from: 134, to: s.width, y: 7, rings: [312, 322, 333, 343])
                CHJamb.draw(ctx, size: s, width: 9, left: true)
            }
            CHWeatherBlock(weather: snap.weather, temp: 38, label: 13, detail: 9)
                .frame(width: 80, alignment: .leading)
                .offset(x: 157, y: 22)
            CHTearCalendar(date: snap.date, style: .large, size: CGSize(width: 112, height: 162))
                .offset(x: 18, y: 10)
            CHLedger(tasks: Array(snap.tasks.prefix(5)), total: snap.tasks.count, error: snap.taskError,
                     size: CGSize(width: 320, height: 166), m: .large)
                .rotationEffect(.degrees(-0.5))
                .offset(x: 14, y: 186)
            CHVignette(center: UnitPoint(x: 0.4, y: 0.4), strength: 0.75, size: size)
            CHGrain(family: .large)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

// MARK: - Medium

struct CHDayMedium: View {
    var snap: DaySnapshot
    private let size = Mock.size(.medium)

    static let vista = CHVista(
        far: [CGPoint(x: -0.05, y: 0.36), CGPoint(x: 0.25, y: 0.18), CGPoint(x: 0.5, y: 0.27), CGPoint(x: 0.72, y: 0.10), CGPoint(x: 1.05, y: 0.30)],
        mid: [CGPoint(x: -0.05, y: 0.50), CGPoint(x: 0.3, y: 0.40), CGPoint(x: 0.55, y: 0.32), CGPoint(x: 0.8, y: 0.42), CGPoint(x: 1.05, y: 0.46)],
        near: [CGPoint(x: -0.05, y: 0.60), CGPoint(x: 0.4, y: 0.56), CGPoint(x: 0.7, y: 0.60), CGPoint(x: 1.05, y: 0.57)],
        road: 0.5, roadWidth: 0.5, moon: CGPoint(x: 0.2, y: 0.07), lamp: CGPoint(x: 0.75, y: 0.86), seed: 63,
        horizon: 0.44, roadFoot: 0.56)

    private var outer: CGRect { CGRect(x: 106, y: 10, width: 84, height: 134) }

    var body: some View {
        let sky = CHSky.from(code: snap.weather?.code)
        ZStack(alignment: .topLeading) {
            CHWall(family: .medium, pools: [CHPool(center: CGPoint(x: 70, y: 40), radius: 170),
                                            CHPool(center: CGPoint(x: 280, y: 120), radius: 140, strength: 0.55)], seed: 5)
            Canvas { ctx, s in
                let t: CGFloat = 6
                let glass = outer.insetBy(dx: t, dy: t)
                CHExterior.draw(ctx, in: glass, sky: sky, vista: Self.vista, scale: 0.85)
                CHGlass.draw(ctx, in: glass, sky: sky, vista: Self.vista, seed: 9, k: 0.85)
                CHFrame.draw(ctx, outer: outer, thickness: t, k: 0.85)
                CHJamb.draw(ctx, size: s, width: 7, left: true)
            }
            CHWeatherBlock(weather: snap.weather, temp: 27, label: 11, detail: 7.5, showHiLo: false, showSun: false)
                .frame(width: 64, height: 46, alignment: .bottomLeading)
                .offset(x: 118, y: 88)
            CHTearCalendar(date: snap.date, style: .medium, size: CGSize(width: 82, height: 146))
                .offset(x: 15, y: 7)
            CHLedger(tasks: Array(snap.tasks.prefix(3)), total: snap.tasks.count, error: snap.taskError,
                     size: CGSize(width: 136, height: 148), m: .medium)
                .offset(x: 199, y: 8)
            CHVignette(center: UnitPoint(x: 0.45, y: 0.4), strength: 0.7, size: size)
            CHGrain(family: .medium)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

// MARK: - Small

struct CHDaySmall: View {
    var snap: DaySnapshot
    private let size = Mock.size(.small)

    static let vista = CHVista(
        far: [CGPoint(x: -0.05, y: 0.42), CGPoint(x: 0.3, y: 0.20), CGPoint(x: 0.55, y: 0.30), CGPoint(x: 0.8, y: 0.14), CGPoint(x: 1.05, y: 0.30)],
        mid: [CGPoint(x: -0.05, y: 0.56), CGPoint(x: 0.35, y: 0.44), CGPoint(x: 0.6, y: 0.38), CGPoint(x: 1.05, y: 0.50)],
        near: [CGPoint(x: -0.05, y: 0.72), CGPoint(x: 0.5, y: 0.68), CGPoint(x: 1.05, y: 0.73)],
        road: 0.45, roadWidth: 0.55, moon: CGPoint(x: 0.22, y: 0.1), lamp: CGPoint(x: 0.7, y: 0.9), seed: 71,
        horizon: 0.5, roadFoot: 0.68)

    private var outer: CGRect { CGRect(x: 100, y: -8, width: 72, height: 124) }

    var body: some View {
        let sky = CHSky.from(code: snap.weather?.code)
        ZStack(alignment: .topLeading) {
            CHWall(family: .small, pools: [CHPool(center: CGPoint(x: 50, y: 40), radius: 130),
                                           CHPool(center: CGPoint(x: 90, y: 150), radius: 90, strength: 0.6)], cell: CGSize(width: 34, height: 44), seed: 7)
            Canvas { ctx, s in
                let t: CGFloat = 6
                let glass = outer.insetBy(dx: t, dy: t)
                CHExterior.draw(ctx, in: glass, sky: sky, vista: Self.vista, scale: 0.75)
                CHGlass.draw(ctx, in: glass, sky: sky, vista: Self.vista, seed: 13, k: 0.75)
                CHFrame.draw(ctx, outer: outer, thickness: t, k: 0.75)
            }
            Group {
                if let w = snap.weather {
                    Text(CHDayText.temp(w))
                        .font(CH.didot(24))
                        .foregroundStyle(CH.cream)
                } else {
                    Text("No\nforecast")
                        .font(CH.baskItalic(11))
                        .lineSpacing(-1)
                        .foregroundStyle(CH.cream)
                        .fixedSize()
                }
            }
            .chHalo(Color(hex: 0x05080C), radius: 2, opacity: 0.9)
            .frame(width: 44, alignment: .leading)
            .offset(x: 111, y: 78)
            CHTearCalendar(date: snap.date, style: .small, size: CGSize(width: 80, height: 102))
                .offset(x: 13, y: 7)
            CHSlip(snap: snap)
                .frame(width: 142, height: 34)
                .offset(x: 11, y: 116)
            CHVignette(center: UnitPoint(x: 0.4, y: 0.45), strength: 0.7, size: size)
            CHGrain(family: .small)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The small widget's slip of paper: the first task and how many more.
struct CHSlip: View {
    var snap: DaySnapshot

    var body: some View {
        Canvas { ctx, s in
            let r = CGRect(x: 10, y: 10, width: s.width - 20, height: s.height - 20)
            var sh = ctx
            sh.addFilter(.blur(radius: 3))
            sh.fill(Path(r.offsetBy(dx: 2, dy: 3.5)), with: .color(.black.opacity(0.7)))
            var p = ctx
            p.clip(to: Path(r))
            p.draw(ctx.resolve(CH.texture("paper")), in: CGRect(x: r.minX - 40, y: r.minY - 60, width: 330, height: 190))
            var lit = p
            lit.blendMode = .multiply
            lit.fill(Path(r), with: .linearGradient(Gradient(colors: [Color(hex: 0xFBE8C6), Color(hex: 0xEED0A0), Color(hex: 0xBE9468)]),
                                                    startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
            p.fill(Path(CGRect(x: r.minX + 14, y: r.minY, width: 0.6, height: r.height)), with: .color(CH.redInk.opacity(0.45)))
        }
        .padding(-10)
        .overlay(alignment: .topLeading) { content.padding(.leading, 4).padding(.top, 3) }
    }

    @ViewBuilder private var content: some View {
        if let err = snap.taskError {
            VStack(alignment: .leading, spacing: 0) {
                Text("The list didn't come.")
                    .font(CH.baskItalic(11))
                    .foregroundStyle(CH.redInk)
                    .lineLimit(1)
                Text(err)
                    .font(CH.label(7.5))
                    .foregroundStyle(CH.inkSoft)
                    .lineLimit(1)
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
        } else if let first = snap.tasks.first {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("1")
                        .font(CH.bodoniItalic(10))
                        .foregroundStyle(first.isOverdue(asOf: Mock.now) ? CH.redInk : CH.inkSoft)
                        .frame(width: 14, alignment: .center)
                    Text(first.text)
                        .font(CH.baskItalic(11.5))
                        .foregroundStyle(CH.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.leading, 3)
                        .padding(.trailing, 6)
                }
                HStack(spacing: 6) {
                    CHDueLabel(task: first, size: 7.5)
                    Spacer(minLength: 2)
                    if snap.tasks.count > 1 {
                        Text("+\(snap.tasks.count - 1) more")
                            .font(CH.baskItalic(9.5))
                            .foregroundStyle(CH.inkSoft)
                            .fixedSize()
                    }
                }
                .padding(.leading, 17)
                .padding(.trailing, 6)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("Nothing on the list.")
                    .font(CH.baskItalic(11))
                    .foregroundStyle(CH.ink)
                    .lineLimit(1)
                Text("the evening is yours")
                    .font(CH.label(7.5))
                    .foregroundStyle(CH.inkSoft)
            }
            .padding(.leading, 17)
        }
    }
}
