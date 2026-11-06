import SwiftUI

// Day widgets: the night street at the foot of the mountains through rain-wet glass. The date hangs as a red
// neon numeral with the weekday on a Chinese lightbox, the temperature burns in cyan tubes, the week runs on an
// LED ticker, and the list sits on a pane of smoked glass with expiry-stamp due dates.

private func nrDay(_ d: Date) -> String { NRDates.string(d, "d") }

/// Date, weekday sign and narration timestamp, top-left.
struct NRDateCluster: View {
    var date: Date
    var numeral: CGFloat
    var weekday: CGFloat
    var hanzi: CGFloat?           // weekday lightbox character size; nil hides it
    var month: String = "MMMM yyyy"
    var showClock = true
    var maxTextWidth: CGFloat = 120

    var body: some View {
        HStack(alignment: .top, spacing: numeral * 0.17) {
            if let hanzi {
                NRHanziSign(date: date, size: hanzi)
                    .padding(.top, hanzi * 0.2)
            }
            NRNeonNumerals(text: nrDay(date), height: numeral, color: NR.red, core: NR.redCore)
            VStack(alignment: .leading, spacing: 0) {
                Text(NRDates.string(date, "EEEE").uppercased())
                    .font(NR.condBold(weekday))
                    .tracking(weekday * 0.14)
                    .foregroundStyle(NR.paper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .nrFringe(0.5, opacity: 0.4)
                    .nrLegible()
                Text(NRDates.string(date, month).uppercased())
                    .font(NR.condMedium(weekday * 0.7))
                    .tracking(weekday * 0.1)
                    .foregroundStyle(NR.paperDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .nrLegible()
                if showClock {
                    NRCaption(text: NRDates.clock(Mock.now).uppercased(), size: weekday * 0.56)
                        .padding(.top, weekday * 0.32)
                }
            }
            .frame(maxWidth: maxTextWidth, alignment: .leading)
            .padding(.top, numeral * 0.02)
        }
    }
}

/// Neon temperature with condition, high/low and the next sun event, right-aligned.
struct NRWeatherBlock: View {
    var snap: DaySnapshot
    var numeral: CGFloat
    var label: CGFloat
    var detail = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let w = snap.weather {
                NRNeonNumerals(text: NRWeatherText.temp(w.temperature), height: numeral, color: NR.cyan, core: NR.cyanCore,
                               dimIndex: NRWeatherText.temp(w.temperature).count - 1)
                    .padding(.bottom, numeral * 0.12)
                Text(w.label)
                    .font(NR.cond(label))
                    .foregroundStyle(NR.paper)
                    .lineLimit(1)
                    .nrLegible()
                if detail {
                    Text("H \(NRWeatherText.temp(w.high))  L \(NRWeatherText.temp(w.low))")
                        .font(NR.mono(label * 0.66))
                        .foregroundStyle(NR.paperDim)
                        .nrLegible()
                    if let (name, time) = NRWeatherText.sunEvent(w) {
                        Text("\(name) \(time)")
                            .font(NR.mono(label * 0.66))
                            .tracking(0.6)
                            .foregroundStyle(NR.sodium.opacity(0.95))
                            .nrLegible()
                    }
                }
            } else {
                NRDeadNeon(text: "--°", height: numeral)
                    .padding(.bottom, numeral * 0.12)
                Text("No weather signal")
                    .font(NR.cond(label))
                    .foregroundStyle(NR.paperDim)
                    .lineLimit(1)
                    .nrLegible()
            }
        }
        .fixedSize()
    }
}

/// The list's empty and error lines, in the look's voice.
struct NRListNote: View {
    var snap: DaySnapshot
    var size: CGFloat

    var body: some View {
        if let err = snap.taskError {
            VStack(alignment: .leading, spacing: 4) {
                NRDotStamp(text: "NO SIGNAL", color: NR.red, pitch: size * 0.085, glow: 0.9, seed: 3)
                Text("Tasks didn't load")
                    .font(NR.body(size))
                    .foregroundStyle(NR.paper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(err)
                    .font(NR.mono(size * 0.7))
                    .foregroundStyle(NR.late)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .nrLegible()
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing on the list.")
                    .font(NR.body(size))
                    .foregroundStyle(NR.paper)
                Text("The night is yours.")
                    .font(NR.body(size * 0.85))
                    .italic()
                    .foregroundStyle(NR.sodium)
            }
            .lineLimit(1)
            .nrLegible()
        }
    }
}

enum NRDayScene {
    static func lights(numeral: CGPoint, temp: CGPoint?, hanzi: CGPoint?) -> [NRLight] {
        var l = [NRLight(at: numeral, color: NR.red, size: 1.5)]
        if let temp { l.append(NRLight(at: temp, color: NR.cyan, size: 1.1)) }
        if let hanzi { l.append(NRLight(at: hanzi, color: NR.magenta, size: 0.9)) }
        return l
    }
}

// MARK: - Large

struct NRDayLarge: View {
    var snap: DaySnapshot

    var body: some View {
        let size = Mock.size(.large)
        let weather = NRWeather.from(snap.weather?.code)
        let lights = NRDayScene.lights(numeral: CGPoint(x: 0.17, y: 0.15), temp: CGPoint(x: 0.88, y: 0.1), hanzi: CGPoint(x: 0.06, y: 0.12))
        let spec = NRSceneSpec(
            far: [CGPoint(x: -0.05, y: 0.25), CGPoint(x: 0.14, y: 0.19), CGPoint(x: 0.33, y: 0.22), CGPoint(x: 0.58, y: 0.06),
                  CGPoint(x: 0.74, y: 0.17), CGPoint(x: 0.9, y: 0.13), CGPoint(x: 1.05, y: 0.22)],
            mid: [CGPoint(x: -0.05, y: 0.31), CGPoint(x: 0.18, y: 0.27), CGPoint(x: 0.36, y: 0.3), CGPoint(x: 0.52, y: 0.16),
                  CGPoint(x: 0.64, y: 0.25), CGPoint(x: 0.82, y: 0.22), CGPoint(x: 1.05, y: 0.31)],
            city: 0.32...0.39, street: 0.43, mast: 0.52,
            lamps: [CGPoint(x: 0.38, y: 0.38), CGPoint(x: 0.47, y: 0.33), CGPoint(x: 0.41, y: 0.29), CGPoint(x: 0.5, y: 0.24),
                    CGPoint(x: 0.46, y: 0.21), CGPoint(x: 0.515, y: 0.18)],
            houses: 90,
            signs: [NRSign(at: CGPoint(x: 0.3, y: 0.36), kind: .vbar, color: NR.magenta, core: NR.magentaCore),
                    NRSign(at: CGPoint(x: 0.66, y: 0.37), kind: .box, color: NR.acid, core: .white, scale: 0.8),
                    NRSign(at: CGPoint(x: 0.74, y: 0.345), kind: .ring, color: NR.sodium, core: NR.sodiumCore, scale: 0.8, dim: true),
                    NRSign(at: CGPoint(x: 0.95, y: 0.37), kind: .cup, color: NR.cyan, core: NR.cyanCore, scale: 0.8)],
            lights: lights, weather: weather, moon: CGPoint(x: 0.67, y: 0.05), seed: 11)

        ZStack(alignment: .topLeading) {
            NRSceneView(spec: spec)
            NRGlassView(spec: NRGlassSpec(weather: weather, seed: 21, lights: lights,
                                          keepClear: [CGRect(x: 10, y: 182, width: 328, height: 172), CGRect(x: 14, y: 12, width: 190, height: 66),
                                                      CGRect(x: 236, y: 12, width: 100, height: 92)],
                                          wipes: [CGRect(x: 6, y: 6, width: 210, height: 82), CGRect(x: 228, y: 6, width: 116, height: 104)]))

            NRDateCluster(date: snap.date, numeral: 56, weekday: 17, hanzi: 12)
                .padding(.leading, 16).padding(.top, 16)
            NRWeatherBlock(snap: snap, numeral: 32, label: 14)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16).padding(.top, 16)

            NRWeekTicker(date: snap.date)
                .frame(width: size.width - 24, height: 21)
                .offset(x: 12, y: 153)

            list
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 10)
                .frame(width: size.width - 24, height: 170, alignment: .top)
                .background { NRPanel(seed: 31) }
                .offset(x: 12, y: 184)

            NRFilm(leak: .topTrailing, grain: 0.5)
        }
        .frame(width: size.width, height: size.height)
        .background(NR.ink)
    }

    private var list: some View {
        let shown = Array(snap.tasks.prefix(5))
        let more = snap.tasks.count - shown.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("TO DO")
                    .font(NR.condBold(12.5))
                    .tracking(2.6)
                    .foregroundStyle(NR.paper)
                    .nrFringe(0.4)
                Rectangle().fill(LinearGradient(colors: [NR.magenta.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.7)
                    .padding(.horizontal, 6)
                if snap.taskError == nil {
                    NRDotStamp(text: "\(snap.tasks.count) OPEN", color: NR.sodium, pitch: 1.1, glow: 0.8, seed: 9)
                }
            }
            .padding(.bottom, 6)
            if snap.tasks.isEmpty || snap.taskError != nil {
                NRListNote(snap: snap, size: 14)
                    .padding(.top, 14)
            } else {
                ForEach(Array(shown.enumerated()), id: \.offset) { i, t in
                    NRTaskRow(task: t, font: 13.5, pitch: 1.2)
                        .frame(height: 23.5)
                    if i < shown.count - 1 {
                        Rectangle().fill(LinearGradient(colors: [.white.opacity(0.0), .white.opacity(0.1), .white.opacity(0.0)], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 0.5)
                    }
                }
                if more > 0 {
                    Text("+\(more) MORE")
                        .font(NR.mono(9))
                        .tracking(1.4)
                        .foregroundStyle(NR.paperDim)
                        .padding(.top, 3)
                }
            }
        }
    }
}

// MARK: - Medium

struct NRDayMedium: View {
    var snap: DaySnapshot

    var body: some View {
        let size = Mock.size(.medium)
        let weather = NRWeather.from(snap.weather?.code)
        let lights = NRDayScene.lights(numeral: CGPoint(x: 0.08, y: 0.3), temp: CGPoint(x: 0.12, y: 0.8), hanzi: nil)
        let spec = NRSceneSpec(
            far: [CGPoint(x: -0.05, y: 0.42), CGPoint(x: 0.1, y: 0.36), CGPoint(x: 0.28, y: 0.2), CGPoint(x: 0.44, y: 0.32),
                  CGPoint(x: 0.64, y: 0.18), CGPoint(x: 0.82, y: 0.3), CGPoint(x: 1.05, y: 0.24)],
            mid: [CGPoint(x: -0.05, y: 0.56), CGPoint(x: 0.09, y: 0.5), CGPoint(x: 0.24, y: 0.36), CGPoint(x: 0.36, y: 0.5),
                  CGPoint(x: 0.56, y: 0.4), CGPoint(x: 0.75, y: 0.5), CGPoint(x: 1.05, y: 0.44)],
            city: 0.61...0.7, street: 0.74, mast: 0.24,
            lamps: [CGPoint(x: 0.13, y: 0.7), CGPoint(x: 0.2, y: 0.6), CGPoint(x: 0.16, y: 0.53), CGPoint(x: 0.235, y: 0.42)],
            houses: 60,
            signs: [NRSign(at: CGPoint(x: 0.36, y: 0.67), kind: .vbar, color: NR.magenta, core: NR.magentaCore, scale: 0.75),
                    NRSign(at: CGPoint(x: 0.42, y: 0.69), kind: .zigzag, color: NR.acid, core: .white, scale: 0.55, dim: true)],
            lights: lights, weather: weather, seed: 12, peakCloud: 0.6)

        ZStack(alignment: .topLeading) {
            NRSceneView(spec: spec)
            NRGlassView(spec: NRGlassSpec(weather: weather, seed: 22, lights: lights,
                                          keepClear: [CGRect(x: 160, y: 6, width: 182, height: 152), CGRect(x: 12, y: 12, width: 140, height: 62),
                                                      CGRect(x: 12, y: 116, width: 140, height: 36)],
                                          wipes: [CGRect(x: 4, y: 6, width: 160, height: 76), CGRect(x: 4, y: 108, width: 156, height: 52)]))

            NRDateCluster(date: snap.date, numeral: 46, weekday: 14.5, hanzi: nil, month: "MMMM", showClock: true, maxTextWidth: 84)
                .padding(.leading, 16).padding(.top, 16)

            weatherLine
                .padding(.leading, 16)
                .frame(height: size.height - 16, alignment: .bottom)

            list
                .padding(.horizontal, 12).padding(.top, 9).padding(.bottom, 7)
                .frame(width: 178, height: 146, alignment: .top)
                .background { NRPanel(radius: 12, seed: 32) }
                .offset(x: size.width - 178 - 10, y: 9)

            NRFilm(leak: .topTrailing, grain: 0.5)
        }
        .frame(width: size.width, height: size.height)
        .background(NR.ink)
    }

    private var weatherLine: some View {
        HStack(alignment: .bottom, spacing: 7) {
            if let w = snap.weather {
                NRNeonNumerals(text: NRWeatherText.temp(w.temperature), height: 22, color: NR.cyan, core: NR.cyanCore,
                               dimIndex: NRWeatherText.temp(w.temperature).count - 1)
                VStack(alignment: .leading, spacing: 0) {
                    Text(w.label).font(NR.cond(12.5)).foregroundStyle(NR.paper)
                    Text("H \(NRWeatherText.temp(w.high))  L \(NRWeatherText.temp(w.low))").font(NR.mono(8.5)).foregroundStyle(NR.paperDim)
                }
                .lineLimit(1)
                .nrLegible()
            } else {
                NRDeadNeon(text: "--°", height: 22)
                Text("No weather signal").font(NR.cond(12)).foregroundStyle(NR.paperDim).lineLimit(1).nrLegible()
            }
        }
    }

    private var list: some View {
        let shown = Array(snap.tasks.prefix(3))
        let more = snap.tasks.count - shown.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TO DO").font(NR.condBold(11)).tracking(2.2).foregroundStyle(NR.paper)
                Rectangle().fill(LinearGradient(colors: [NR.magenta.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.7).padding(.horizontal, 4)
                if snap.taskError == nil {
                    NRDotStamp(text: "\(snap.tasks.count) OPEN", color: NR.sodium, pitch: 0.95, glow: 0.8, seed: 9)
                }
            }
            .padding(.bottom, 5)
            if snap.tasks.isEmpty || snap.taskError != nil {
                NRListNote(snap: snap, size: 12.5).padding(.top, 8)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, t in
                        NRTaskRow(task: t, font: 12.5, pitch: 0.95, stampBelow: true)
                    }
                }
                Spacer(minLength: 0)
                if more > 0 {
                    Text("+\(more) MORE").font(NR.mono(8.5)).tracking(1.2).foregroundStyle(NR.paperDim)
                }
            }
        }
    }
}

// MARK: - Small

struct NRDaySmall: View {
    var snap: DaySnapshot

    var body: some View {
        let size = Mock.size(.small)
        let weather = NRWeather.from(snap.weather?.code)
        let lights = NRDayScene.lights(numeral: CGPoint(x: 0.17, y: 0.25), temp: CGPoint(x: 0.82, y: 0.2), hanzi: nil)
        let spec = NRSceneSpec(
            far: [CGPoint(x: -0.05, y: 0.36), CGPoint(x: 0.2, y: 0.3), CGPoint(x: 0.5, y: 0.14), CGPoint(x: 0.72, y: 0.26), CGPoint(x: 1.05, y: 0.2)],
            mid: [CGPoint(x: -0.05, y: 0.46), CGPoint(x: 0.22, y: 0.38), CGPoint(x: 0.42, y: 0.46), CGPoint(x: 0.62, y: 0.28),
                  CGPoint(x: 0.82, y: 0.4), CGPoint(x: 1.05, y: 0.36)],
            city: 0.5...0.57, street: 0.6, mast: 0.62,
            lamps: [CGPoint(x: 0.5, y: 0.57), CGPoint(x: 0.58, y: 0.48), CGPoint(x: 0.54, y: 0.42), CGPoint(x: 0.61, y: 0.33)],
            houses: 40,
            signs: [NRSign(at: CGPoint(x: 0.3, y: 0.53), kind: .vbar, color: NR.magenta, core: NR.magentaCore, scale: 0.7),
                    NRSign(at: CGPoint(x: 0.85, y: 0.54), kind: .ring, color: NR.sodium, core: NR.sodiumCore, scale: 0.6)],
            lights: lights, weather: weather, peakCloud: 0.8)

        ZStack(alignment: .topLeading) {
            NRSceneView(spec: spec)
            NRGlassView(spec: NRGlassSpec(weather: weather, seed: 23, lights: lights,
                                          keepClear: [CGRect(x: 8, y: 92, width: 148, height: 64), CGRect(x: 12, y: 12, width: 140, height: 46)],
                                          wipes: [CGRect(x: 4, y: 4, width: 156, height: 58)]))

            HStack(alignment: .top) {
                NRDateCluster(date: snap.date, numeral: 40, weekday: 13, hanzi: nil, month: "MMM", showClock: false, maxTextWidth: 46)
                Spacer(minLength: 4)
                if let w = snap.weather {
                    NRNeonNumerals(text: NRWeatherText.temp(w.temperature), height: 19, color: NR.cyan, core: NR.cyanCore,
                                   dimIndex: NRWeatherText.temp(w.temperature).count - 1)
                        .padding(.top, 3)
                } else {
                    NRDeadNeon(text: "--°", height: 19).padding(.top, 3)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)

            bottom
                .padding(.horizontal, 16)
                .frame(width: size.width, height: size.height - 16, alignment: .bottom)

            NRFilm(leak: .topTrailing, grain: 0.5)
        }
        .frame(width: size.width, height: size.height)
        .background(NR.ink)
    }

    @ViewBuilder private var bottom: some View {
        if let first = snap.tasks.first, snap.taskError == nil {
            VStack(spacing: 4) {
                NRSubtitle(text: first.text, size: 13, color: NR.paper, lines: 2, minScale: 0.9)
                HStack(spacing: 8) {
                    NRDueStamp(task: first, pitch: 1.0)
                    if snap.tasks.count > 1 {
                        Text("+\(snap.tasks.count - 1) MORE").font(NR.monoBold(8)).tracking(1).foregroundStyle(NR.paperDim).nrLegible()
                    }
                }
            }
            .frame(maxWidth: .infinity)
        } else if snap.taskError != nil {
            VStack(spacing: 3) {
                NRDotStamp(text: "NO SIGNAL", color: NR.red, pitch: 1.0, glow: 0.9, seed: 3)
                NRSubtitle(text: "Tasks didn't load", size: 12, color: NR.paper, lines: 1)
            }
            .frame(maxWidth: .infinity)
        } else {
            NRSubtitle(text: "Nothing on the list. The night is yours.", size: 12, color: NR.paper, lines: 2)
                .frame(maxWidth: .infinity)
        }
    }
}
