import SwiftUI

// The instrument: a navy plate under a raised brass rim. Inside the rim, the limb (a channel with a fine degree scale
// and the month in spaced capitals across the top, like an astrolabe's calendar scale but without the day grid),
// then the plate: the sky above the horizon line with the day ring (sunrise at the east point on the left, sunset at
// the west point on the right, as on an astrolabe's plate), the sun or moon on it at the current time, the weather,
// and the Matterhorn engraved standing on the horizon; below the horizon, the reading.

/// Where everything sits, in the widget's points.
struct CEDial {
    var size: CGSize
    var center: CGPoint
    var rimOuter: CGFloat
    var rimInner: CGFloat
    var limb: CGFloat          // the engraved circle between the limb and the plate
    var ring: CGFloat          // the day ring
    var horizon: CGFloat       // y of the horizon line
    var peakH: CGFloat         // the Matterhorn's pyramid height
    var summitX: CGFloat
    var half: Bool = false     // medium: the sky hemisphere on a flat brass base
    var baseBar: CGFloat = 0   // depth of that base below the horizon
    var monthFont: CGFloat
    var monthRadius: CGFloat
    var monthStep: Double      // degrees between letters
    var line: CGFloat          // engraving line width
    var hatch: CGFloat         // hatching spacing on the mountain
    var sunR: CGFloat          // the sun's outer ray radius
    var tick: CGFloat          // limb tick length

    static func spec(_ family: Family) -> CEDial {
        let s = Mock.size(family)
        switch family {
        case .large:
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            return CEDial(size: s, center: c, rimOuter: 166, rimInner: 152, limb: 130, ring: 113, horizon: c.y,
                          peakH: 64, summitX: c.x - 6, monthFont: 13, monthRadius: 140.5, monthStep: 7.0,
                          line: 0.95, hatch: 1.35, sunR: 16.5, tick: 3.5)
        case .medium:
            let c = CGPoint(x: 122, y: 138)
            return CEDial(size: s, center: c, rimOuter: 110, rimInner: 98.5, limb: 81, ring: 70.5, horizon: c.y,
                          peakH: 39, summitX: c.x - 4, half: true, baseBar: 10, monthFont: 11, monthRadius: 89.75,
                          monthStep: 8.2, line: 0.8, hatch: 1.25, sunR: 11, tick: 3)
        case .small:
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            return CEDial(size: s, center: c, rimOuter: 76, rimInner: 67.5, limb: 55, ring: 47.5, horizon: c.y - 3,
                          peakH: 21, summitX: c.x - 3, monthFont: 9, monthRadius: 61.25, monthStep: 10.2,
                          line: 0.7, hatch: 1.2, sunR: 8.5, tick: 2.5)
        }
    }

    var rect: CGRect { CGRect(origin: .zero, size: size) }
    var dialRect: CGRect { CGRect(x: center.x - rimOuter, y: center.y - rimOuter, width: 2 * rimOuter, height: 2 * rimOuter) }

    // The day ring meets the horizon at the east (left) and west (right) points.
    private var lift: Double { asin(Double(max(-ring, min(ring, horizon - center.y)) / ring)) * 180 / .pi }
    var east: Double { 180 - lift }
    var west: Double { 360 + lift }
    func ringAngle(_ p: Double) -> Double { east + (west - east) * min(1, max(0, p)) }
    func ringPoint(_ p: Double) -> CGPoint { CEEngrave.point(center, ring, ringAngle(p)) }
    func ringPoint(_ p: Double, radius: CGFloat) -> CGPoint { CEEngrave.point(center, radius, ringAngle(p)) }

    /// Half-width of the plate (inside the limb) at height y.
    func chord(_ y: CGFloat) -> CGFloat {
        let d = y - center.y
        return d.magnitude >= limb ? 0 : sqrt(limb * limb - d * d)
    }

    private func dShape(_ r: CGFloat, bottom: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: center.x - r, y: bottom))
        p.addLine(to: CGPoint(x: center.x - r, y: center.y))
        p.addArc(center: center, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.addLine(to: CGPoint(x: center.x + r, y: bottom))
        p.closeSubpath()
        return p
    }

    var rimOuterPath: Path { half ? dShape(rimOuter, bottom: horizon + baseBar) : CEEngrave.circle(center, rimOuter) }
    var rimInnerPath: Path { half ? dShape(rimInner, bottom: horizon) : CEEngrave.circle(center, rimInner) }
    var rimCrestPath: Path {
        let m = (rimOuter + rimInner) / 2
        if half {
            var p = CEEngrave.arc(center, m, 180, 360)
            p.move(to: CGPoint(x: center.x - m, y: horizon + baseBar * 0.5))
            p.addLine(to: CGPoint(x: center.x + m, y: horizon + baseBar * 0.5))
            return p
        }
        return CEEngrave.circle(center, m)
    }
    /// A turned groove round the rim, a third of the way out from its inner lip.
    var rimGroovePath: Path {
        let g = rimInner + (rimOuter - rimInner) * 0.34
        if half {
            var p = CEEngrave.arc(center, g, 180, 360)
            p.move(to: CGPoint(x: center.x - g, y: horizon + baseBar * 0.3))
            p.addLine(to: CGPoint(x: center.x + g, y: horizon + baseBar * 0.3))
            return p
        }
        return CEEngrave.circle(center, g)
    }
    /// The recess inside the rim (limb and plate).
    var recess: Path { rimInnerPath }
    /// The plate inside the limb.
    var plate: Path { half ? dShape(limb, bottom: horizon) : CEEngrave.circle(center, limb) }
    var sky: Path { plate.intersection(Path(CGRect(x: 0, y: -10, width: size.width, height: horizon + 10))) }
    var earth: Path { plate.intersection(Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height))) }

    var peak: CEPeak {
        let w = chord(horizon)
        return CEPeak(summit: CGPoint(x: summitX, y: horizon - 1.36 * peakH), h: peakH, base: horizon,
                      x0: center.x - w - 2, x1: center.x + w + 2)
    }
}

// MARK: - The sky's clock

/// The arc the sun (or by night the moon) is on, with its start and end times, as SkyClock reckons it.
struct CEArc {
    var clock: SkyClock
    var start: Date
    var end: Date
    var rise: Date
    var set: Date

    init(_ snapshot: DaySnapshot) {
        let now = snapshot.date
        let cal = Calendar.current
        func today(_ d: Date?, _ h: Int, _ m: Int) -> Date {
            let c = d.map { cal.dateComponents([.hour, .minute], from: $0) }
            return cal.date(bySettingHour: c?.hour ?? h, minute: c?.minute ?? m, second: 0, of: now) ?? now
        }
        clock = SkyClock(now: now, weather: snapshot.weather)
        rise = today(snapshot.weather?.sunrise, 6, 30)
        set = today(snapshot.weather?.sunset, 17, 45)
        if clock.isDay {
            start = rise; end = set
        } else {
            start = now > set ? set : set.addingTimeInterval(-86_400)
            end = now > set ? rise.addingTimeInterval(86_400) : rise
        }
    }

    /// Whole hours along the arc, as progress 0...1, with whether each is noon or midnight.
    var hours: [(p: Double, major: Bool)] {
        let cal = Calendar.current
        var out: [(Double, Bool)] = []
        guard var t = cal.nextDate(after: start, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) else { return [] }
        let span = end.timeIntervalSince(start)
        while t < end {
            let h = cal.component(.hour, from: t)
            out.append((t.timeIntervalSince(start) / span, h == 12 || h == 0))
            t = t.addingTimeInterval(3600)
        }
        return out
    }
}

// MARK: - Sky

/// The plate's sky, laid over the lacquer: lapis by day, deeper at night, slate under cloud, an ember glow along the
/// horizon at twilight, and the light round the sun or moon.
struct CESky: View {
    var dial: CEDial
    var arc: CEArc
    var condition: SkyCondition

    var body: some View {
        let clock = arc.clock
        let sun = dial.ringPoint(clock.progress)
        let gray = condition.gray
        let top = dial.horizon - dial.limb
        ZStack {
            if clock.isDay {
                LinearGradient(colors: gray ? [Color(hex: 0x2C3850), Color(hex: 0x58647A)] : [Color(hex: 0x1D3F84), Color(hex: 0x5C80B8)],
                               startPoint: UnitPoint(x: 0.5, y: top / dial.size.height),
                               endPoint: UnitPoint(x: 0.5, y: dial.horizon / dial.size.height))
                    .opacity(gray ? 0.6 : 0.62)
                    .blendMode(.screen)
                if !gray {
                    RadialGradient(colors: [Color(hex: 0xF6DFA6).opacity(0.55), Color(hex: 0xB89A5E).opacity(0.18), .clear],
                                   center: UnitPoint(x: sun.x / dial.size.width, y: sun.y / dial.size.height),
                                   startRadius: 0, endRadius: dial.ring * 0.62)
                        .blendMode(.screen)
                }
            } else {
                CE.navyDeep.opacity(0.45)
                RadialGradient(colors: [Stone.moonlight.opacity(gray ? 0.08 : 0.16), .clear],
                               center: UnitPoint(x: sun.x / dial.size.width, y: sun.y / dial.size.height),
                               startRadius: 0, endRadius: dial.ring * 0.5)
                    .blendMode(.screen)
            }
            if gray {
                Color(hex: 0x6D7380).blendMode(.saturation).opacity(0.55)
            }
            if clock.twilight > 0 {
                // Ember along the horizon, strongest on the sun's side.
                RadialGradient(colors: [CE.ember.opacity(0.75), Color(hex: 0xB0627A).opacity(0.3), .clear],
                               center: UnitPoint(x: sun.x / dial.size.width, y: dial.horizon / dial.size.height),
                               startRadius: 0, endRadius: dial.ring * 1.25)
                    .opacity(clock.twilight * (gray ? 0.5 : 1))
                    .blendMode(.screen)
            }
        }
        .frame(width: dial.size.width, height: dial.size.height)
        .clipShape(CEPathShape(path: dial.sky))
    }
}

/// Below the horizon: the plate a shade darker, worked with faint level lines.
struct CEEarth: View {
    var dial: CEDial

    var body: some View {
        ZStack {
            CE.navyDeep.opacity(0.42)
            Canvas { ctx, _ in
                let box = dial.earth.boundingRect
                ctx.clip(to: dial.earth)
                ctx.stroke(CEEngrave.hatch(box, angle: 0, spacing: 3.2, jitter: 0.1, seed: 77), with: .color(CE.gold.opacity(0.09)),
                           lineWidth: 0.4)
                ctx.blendMode = .destinationOut
                ctx.fill(Path(box), with: .linearGradient(Gradient(colors: [.black.opacity(0.9), .black.opacity(0)]),
                                                          startPoint: CGPoint(x: 0, y: dial.horizon),
                                                          endPoint: CGPoint(x: 0, y: dial.horizon + 26)))
            }
        }
        .frame(width: dial.size.width, height: dial.size.height)
        .clipShape(CEPathShape(path: dial.earth))
    }
}

// MARK: - Engraving

struct CEEngraving: View {
    var dial: CEDial
    var arc: CEArc
    var condition: SkyCondition
    var phase: MoonPhase
    var date: Date
    var seed: UInt64 = 5

    var body: some View {
        Canvas { ctx, _ in
            let sheen = CEGold.sheen(dial.dialRect)
            let k = dial.size.width < 200 ? dial.rimOuter / 166 * 1.25 : dial.rimOuter / 166
            let line = dial.line
            let clock = arc.clock
            let pos = dial.ringPoint(clock.progress)

            // Stars set into the sky: a few engraved sparkles, brighter at night.
            ctx.drawLayer { l in
                l.clip(to: dial.sky)
                var rng = SeededRandom(seed)
                let count = dial.half ? 9 : (dial.size.width < 200 ? 6 : 12)
                for _ in 0..<count {
                    let a = 190 + 160 * rng.next()
                    let r = dial.limb * CGFloat(0.35 + 0.55 * rng.next())
                    let pt = CEEngrave.point(dial.center, r, a)
                    if pt.y > dial.horizon - dial.peakH * 0.9 { continue }
                    let s = CGFloat(1.6 + 2.0 * rng.next()) * k * (clock.isDay ? 0.85 : 1.15)
                    if clock.isDay && condition.gray { continue }
                    CEEngrave.glow(l, pt, s * 2.4, CE.goldBright, clock.isDay ? 0.12 : 0.3)
                    l.fill(CEEngrave.star(pt, s), with: .color(CE.goldBright.opacity(clock.isDay ? 0.5 : 0.95)))
                }
            }

            // By night, Cassiopeia engraved in the open sky beside the peak (dotted lines between gold stars).
            if !clock.isDay && dial.size.width > 200 {
                let r = dial.ring
                let o = CGPoint(x: dial.center.x + 0.44 * r, y: dial.horizon - 0.64 * r)
                let pts = [(-1.0, -0.25), (-0.5, 0.3), (0.0, -0.02), (0.48, 0.38), (1.0, -0.12)].map {
                    CGPoint(x: o.x + CGFloat($0.0) * 0.3 * r, y: o.y + CGFloat($0.1) * 0.3 * r)
                }
                var lines = Path()
                lines.addLines(pts)
                ctx.stroke(lines, with: .color(CE.gold.opacity(0.55)), style: StrokeStyle(lineWidth: line * 0.5, dash: [1.4 * k, 2.2 * k]))
                for (i, p) in pts.enumerated() {
                    let s = (i == 2 ? 3.4 : 2.6) * k
                    CEEngrave.glow(ctx, p, s * 2.6, CE.goldBright, 0.3)
                    ctx.fill(CEEngrave.star(p, s), with: .color(CE.goldBright))
                }
            }

            // The day ring: a double engraved line from the east point to the west point, hour ticks outside it.
            CEEngrave.line(ctx, CEEngrave.arc(dial.center, dial.ring, dial.east, dial.west), width: line * 0.85, shading: sheen)
            CEEngrave.line(ctx, CEEngrave.arc(dial.center, dial.ring - 2.2 * k, dial.east + 1.5, dial.west - 1.5), width: line * 0.4,
                           shading: sheen, light: 0, groove: 0.5)
            var ticks = Path()
            for h in arc.hours {
                let a = dial.ringAngle(h.p)
                ticks.move(to: CEEngrave.point(dial.center, dial.ring, a))
                ticks.addLine(to: CEEngrave.point(dial.center, dial.ring + (h.major ? 6 : 3.6) * k, a))
            }
            CEEngrave.line(ctx, ticks, width: line * 0.6, shading: sheen, light: 0.5, groove: 0.6)

            // The sun (or the moon by night) on the ring at the current time, behind the clouds and the mountain.
            if clock.isDay {
                CEGlyph.sun(ctx, at: pos, r: dial.sunR, dim: condition.gray)
            } else {
                CEGlyph.moon(ctx, at: pos, r: dial.sunR * 0.62, phase: phase, glow: true)
            }

            // Weather, engraved.
            CEWeatherMarks.clouds(ctx, dial: dial, condition: condition, night: !clock.isDay, sheen: sheen, k: k)

            // The Matterhorn on the horizon.
            dial.peak.engrave(ctx, fill: clock.isDay ? (condition.gray ? Color(hex: 0x1A2236) : Color(hex: 0x14244A)) : Color(hex: 0x0A1229),
                              sheen: sheen, line: line, spacing: dial.hatch, seed: seed &+ 11)

            CEWeatherMarks.precipitation(ctx, dial: dial, condition: condition, sheen: sheen, k: k, seed: seed &+ 21)

            // The horizon: a double rule across the plate, with diamonds at the east and west points.
            let w = dial.chord(dial.horizon)
            var hz = Path()
            hz.move(to: CGPoint(x: dial.center.x - w, y: dial.horizon))
            hz.addLine(to: CGPoint(x: dial.center.x + w, y: dial.horizon))
            CEEngrave.line(ctx, hz, width: line, shading: sheen)
            if !dial.half {
                var hz2 = Path()
                let w2 = dial.chord(dial.horizon + 2.4 * k)
                hz2.move(to: CGPoint(x: dial.center.x - w2, y: dial.horizon + 2.4 * k))
                hz2.addLine(to: CGPoint(x: dial.center.x + w2, y: dial.horizon + 2.4 * k))
                CEEngrave.line(ctx, hz2, width: line * 0.4, shading: sheen, light: 0, groove: 0.5)
            }
            for p in [0.0, 1.0] {
                let c = dial.ringPoint(p)
                let d = 2.6 * k
                var dm = Path()
                dm.move(to: CGPoint(x: c.x, y: c.y - d))
                dm.addLine(to: CGPoint(x: c.x + d * 0.7, y: c.y))
                dm.addLine(to: CGPoint(x: c.x, y: c.y + d))
                dm.addLine(to: CGPoint(x: c.x - d * 0.7, y: c.y))
                dm.closeSubpath()
                ctx.fill(dm.offsetBy(dx: 0.4, dy: 0.6), with: .color(CE.ink.opacity(0.8)))
                ctx.fill(dm, with: sheen)
            }

            // The limb: the plate's edge cut as a double circle, and a degree scale under the rim.
            let a0 = dial.half ? 180.0 : 0, a1 = dial.half ? 360.0 : 360
            CEEngrave.line(ctx, CEEngrave.arc(dial.center, dial.limb, a0, a1), width: line * 0.9, shading: sheen)
            CEEngrave.line(ctx, CEEngrave.arc(dial.center, dial.limb - 1.8 * k, a0, a1), width: line * 0.4, shading: sheen,
                           light: 0, groove: 0.4)
            var scale = Path()
            var deg = a0
            while deg <= a1 + 0.01 {
                let i = Int((deg - a0) / 3 + 0.5)
                let len = (i % 5 == 0 ? 1.75 : 1.0) * dial.tick
                scale.move(to: CEEngrave.point(dial.center, dial.rimInner - 0.8, deg))
                scale.addLine(to: CEEngrave.point(dial.center, dial.rimInner - 0.8 - len, deg))
                deg += 3
            }
            ctx.stroke(scale, with: sheen, lineWidth: line * 0.45)
            CEEngrave.line(ctx, CEEngrave.arc(dial.center, dial.rimInner - 0.8 - dial.tick * 1.75, a0, a1), width: line * 0.35,
                           shading: sheen, light: 0, groove: 0.3)
        }
        .frame(width: dial.size.width, height: dial.size.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Glyphs

enum CEGlyph {
    /// The engraved sun: a gold-leaf disc with an inner ring, straight rays between flame-like wavy ones, in a glow.
    static func sun(_ ctx: GraphicsContext, at c: CGPoint, r: CGFloat, dim: Bool = false) {
        CEEngrave.glow(ctx, c, r * 2.3, Color(hex: 0xF7DE9C), dim ? 0.25 : 0.55)
        let leaf = GraphicsContext.Shading.linearGradient(Gradient(colors: [CE.goldBright, CE.gold, CE.goldDeep]),
                                                          startPoint: CGPoint(x: c.x - r, y: c.y - r),
                                                          endPoint: CGPoint(x: c.x + r, y: c.y + r))
        var rays = Path()
        var waves = Path()
        let inner = r * 0.46
        for i in 0..<16 {
            let a = Double(i) * .pi / 8 - .pi / 2
            let d = CGVector(dx: cos(a), dy: sin(a))
            let n = CGVector(dx: -d.dy, dy: d.dx)
            if i % 2 == 0 {
                let len = r
                let wb = r * 0.085
                rays.move(to: CGPoint(x: c.x + d.dx * inner + n.dx * wb, y: c.y + d.dy * inner + n.dy * wb))
                rays.addLine(to: CGPoint(x: c.x + d.dx * len, y: c.y + d.dy * len))
                rays.addLine(to: CGPoint(x: c.x + d.dx * inner - n.dx * wb, y: c.y + d.dy * inner - n.dy * wb))
                rays.closeSubpath()
            } else {
                let len = r * 0.8
                let steps = 10
                for s in 0...steps {
                    let t = CGFloat(s) / CGFloat(steps)
                    let along = inner + (len - inner) * t
                    let side = sin(Double(t) * .pi * 2) * Double(r) * 0.07 * Double(1 - t * 0.5)
                    let pt = CGPoint(x: c.x + d.dx * along + n.dx * CGFloat(side), y: c.y + d.dy * along + n.dy * CGFloat(side))
                    if s == 0 { waves.move(to: pt) } else { waves.addLine(to: pt) }
                }
            }
        }
        ctx.fill(rays.offsetBy(dx: 0.4, dy: 0.6), with: .color(CE.ink.opacity(0.6)))
        ctx.fill(rays, with: leaf)
        ctx.stroke(waves.offsetBy(dx: 0.3, dy: 0.5), with: .color(CE.ink.opacity(0.5)), style: StrokeStyle(lineWidth: max(0.45, r * 0.06), lineCap: .round))
        ctx.stroke(waves, with: leaf, style: StrokeStyle(lineWidth: max(0.45, r * 0.06), lineCap: .round))
        let disc = CEEngrave.circle(c, r * 0.42)
        ctx.fill(disc.offsetBy(dx: 0.5, dy: 0.8), with: .color(CE.ink.opacity(0.7)))
        ctx.fill(disc, with: .radialGradient(Gradient(colors: [CE.goldBright, CE.gold, CE.goldDeep]),
                                             center: CGPoint(x: c.x - r * 0.14, y: c.y - r * 0.16), startRadius: 0, endRadius: r * 0.5))
        ctx.stroke(CEEngrave.circle(c, r * 0.29), with: .color(CE.goldDeep.opacity(0.9)),
                   style: StrokeStyle(lineWidth: max(0.35, r * 0.035), dash: [max(0.6, r * 0.07), max(0.5, r * 0.05)]))
        ctx.stroke(disc, with: .color(Color(hex: 0x6E4E1E).opacity(0.9)), lineWidth: max(0.35, r * 0.04))
    }

    /// The moon in its phase: the lit part in gold leaf with a few seas, the rest navy inside an engraved outline.
    static func moon(_ ctx: GraphicsContext, at c: CGPoint, r: CGFloat, phase: MoonPhase, glow: Bool) {
        if glow { CEEngrave.glow(ctx, c, r * 3.4, Stone.moonlight, 0.3) }
        let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
        let disc = Path(ellipseIn: rect)
        ctx.fill(disc.offsetBy(dx: 0.4, dy: 0.7), with: .color(CE.ink.opacity(0.7)))
        ctx.fill(disc, with: .color(Color(hex: 0x0B1534)))
        let lit = MoonLitShape(phase: phase).path(in: rect)
        ctx.fill(lit, with: .radialGradient(Gradient(colors: [CE.goldBright, CE.gold, CE.goldMid]),
                                            center: CGPoint(x: c.x - r * 0.2, y: c.y - r * 0.25), startRadius: 0, endRadius: r * 1.2))
        ctx.drawLayer { l in
            l.clip(to: lit)
            for (dx, dy, s) in [(-0.25, -0.2, 0.22), (0.2, 0.15, 0.16), (-0.05, 0.42, 0.13), (0.35, -0.35, 0.1)] {
                let cc = CGPoint(x: c.x + r * dx, y: c.y + r * dy)
                l.fill(CEEngrave.circle(cc, r * s), with: .color(CE.goldDeep.opacity(0.45)))
            }
        }
        ctx.stroke(disc, with: .color(CE.gold.opacity(0.9)), lineWidth: max(0.4, r * 0.07))
    }
}

// MARK: - Weather marks

enum CEWeatherMarks {
    /// The billows of an engraved cumulus: a row sitting on a flat foot and a crown above, as (centre, radius).
    static func lobes(_ c: CGPoint, _ w: CGFloat) -> [(CGPoint, CGFloat)] {
        let foot = c.y + 0.12 * w
        let row: [(CGFloat, CGFloat)] = [(-0.4, 0.1), (-0.25, 0.15), (-0.03, 0.2), (0.19, 0.16), (0.36, 0.11)]
        var out = row.map { (CGPoint(x: c.x + $0.0 * w, y: foot - $0.1 * w), $0.1 * w) }
        out.append((CGPoint(x: c.x - 0.15 * w, y: foot - 0.33 * w), 0.13 * w))
        out.append((CGPoint(x: c.x + 0.09 * w, y: foot - 0.37 * w), 0.12 * w))
        return out.sorted { $0.0.y - $0.1 < $1.0.y - $1.1 }
    }

    /// An engraved cumulus in the manner of the old celestial charts: billows laid back to front, each outlined over
    /// the one behind it and hatched under its belly, scroll curls in the largest, on a flat ruled foot.
    static func cloud(_ ctx: GraphicsContext, _ c: CGPoint, _ w: CGFloat, fill: Color, sheen: GraphicsContext.Shading, line: CGFloat, seed: UInt64) {
        let foot = c.y + 0.12 * w
        let lobes = lobes(c, w)
        let above = Path(CGRect(x: c.x - w, y: c.y - w, width: 2 * w, height: foot - (c.y - w)))
        let slab = Path(CGRect(x: c.x - 0.4 * w, y: foot - 0.1 * w, width: 0.76 * w, height: 0.1 * w))
        ctx.drawLayer { l in
            l.clip(to: above)
            var body = slab
            for (p, r) in lobes { body.addPath(CEEngrave.circle(p, r)) }
            l.fill(body.offsetBy(dx: 0.8, dy: 1.6), with: .color(CE.ink.opacity(0.3)))
            l.fill(slab, with: .color(fill))
            for (i, (p, r)) in lobes.enumerated() {
                let disc = CEEngrave.circle(p, r)
                l.fill(disc, with: .color(fill))
                l.drawLayer { h in
                    h.clip(to: disc)
                    h.clip(to: Path(CGRect(x: p.x - r, y: p.y + 0.2 * r, width: 2 * r, height: r)))
                    h.opacity = 0.5
                    h.stroke(CEEngrave.hatch(disc.boundingRect, angle: 0, spacing: max(1.1, 0.032 * w), jitter: 0.1, seed: seed &+ UInt64(i)),
                             with: sheen, lineWidth: line * 0.4)
                }
                CEEngrave.line(l, disc, width: line * 0.75, shading: sheen, light: 0.6, groove: 0.45)
            }
        }
        // Scroll curls in the two largest billows.
        var curls = Path()
        for (p, r) in lobes.sorted(by: { $0.1 > $1.1 }).prefix(2) {
            let steps = 18
            for s in 0...steps {
                let t = Double(s) / Double(steps)
                let a = .pi * 0.95 + t * .pi * 1.6
                let rr = r * CGFloat(0.62 - 0.42 * t)
                let pt = CGPoint(x: p.x - 0.1 * r + rr * CGFloat(cos(a)), y: p.y + 0.12 * r + rr * CGFloat(sin(a)))
                if s == 0 { curls.move(to: pt) } else { curls.addLine(to: pt) }
            }
        }
        CEEngrave.line(ctx, curls, width: line * 0.55, shading: sheen, light: 0.4, groove: 0.4)
        var base = Path()
        base.move(to: CGPoint(x: c.x - 0.47 * w, y: foot))
        base.addLine(to: CGPoint(x: c.x + 0.44 * w, y: foot))
        CEEngrave.line(ctx, base, width: line * 0.75, shading: sheen, light: 0.5)
    }

    static func clouds(_ ctx: GraphicsContext, dial: CEDial, condition: SkyCondition, night: Bool, sheen: GraphicsContext.Shading, k: CGFloat) {
        let fill = night ? Color(hex: 0x111D3E) : (condition.gray ? Color(hex: 0x323E58) : Color(hex: 0x2D4C88))
        let r = dial.ring
        let c = dial.center
        let top = dial.horizon
        var placed: [(CGPoint, CGFloat)] = []
        switch condition {
        case .clear:
            break
        case .partly:
            placed = [(CGPoint(x: c.x + 0.42 * r, y: top - 0.66 * r), 0.56 * r), (CGPoint(x: c.x - 0.6 * r, y: top - 0.3 * r), 0.38 * r)]
        case .fog:
            placed = [(CGPoint(x: c.x + 0.42 * r, y: top - 0.7 * r), 0.48 * r)]
        case .overcast, .rain, .snow, .storm:
            placed = [(CGPoint(x: c.x - 0.02 * r, y: top - 0.86 * r), 0.5 * r), (CGPoint(x: c.x - 0.5 * r, y: top - 0.66 * r), 0.56 * r),
                      (CGPoint(x: c.x + 0.47 * r, y: top - 0.7 * r), 0.6 * r)]
        }
        ctx.drawLayer { l in
            l.clip(to: dial.sky)
            for (i, (pt, w)) in placed.enumerated() {
                cloud(l, pt, w, fill: fill, sheen: sheen, line: dial.line, seed: UInt64(40 + i))
            }
        }
    }

    static func precipitation(_ ctx: GraphicsContext, dial: CEDial, condition: SkyCondition, sheen: GraphicsContext.Shading, k: CGFloat, seed: UInt64) {
        let r = dial.ring
        let region = CGRect(x: dial.center.x - r, y: dial.horizon - 0.62 * r, width: 2 * r, height: 0.62 * r)
        ctx.drawLayer { l in
            l.clip(to: dial.sky)
            l.clip(to: Path(region))
            switch condition {
            case .rain, .storm:
                l.opacity = 0.6
                l.stroke(CEEngrave.hatch(region, angle: .pi / 2 + 0.3, spacing: 5.2 * k, dash: (on: 3 * k...6 * k, off: 6 * k...14 * k), jitter: 0.4, seed: seed),
                         with: sheen, style: StrokeStyle(lineWidth: dial.line * 0.6, lineCap: .round))
                if condition == .storm {
                    var bolt = Path()
                    let s = 0.42 * r
                    let o = CGPoint(x: dial.center.x + 0.36 * r, y: dial.horizon - 0.8 * r)
                    bolt.addLines([o, CGPoint(x: o.x - 0.12 * s, y: o.y + 0.4 * s), CGPoint(x: o.x + 0.04 * s, y: o.y + 0.38 * s),
                                   CGPoint(x: o.x - 0.1 * s, y: o.y + 0.85 * s)])
                    l.opacity = 1
                    CEEngrave.line(l, bolt, width: dial.line * 1.3, shading: .color(CE.goldBright))
                }
            case .snow:
                var rng = SeededRandom(seed)
                var flakes = Path()
                let count = Int(26 * r / 113) + 6
                for _ in 0..<count {
                    let p = CGPoint(x: region.minX + region.width * CGFloat(rng.next()), y: region.minY + region.height * CGFloat(rng.next()))
                    let s = (1.3 + 1.2 * CGFloat(rng.next())) * k
                    for j in 0..<3 {
                        let a = Double(j) * .pi / 3 + .pi / 2
                        flakes.move(to: CGPoint(x: p.x - s * CGFloat(cos(a)), y: p.y - s * CGFloat(sin(a))))
                        flakes.addLine(to: CGPoint(x: p.x + s * CGFloat(cos(a)), y: p.y + s * CGFloat(sin(a))))
                    }
                }
                CEEngrave.line(l, flakes, width: dial.line * 0.55, shading: sheen, light: 0.6, groove: 0.6)
            case .fog:
                var fog = Path()
                for i in 0..<4 {
                    let y = dial.horizon - CGFloat(i + 1) * 0.11 * dial.peakH * 1.4
                    let w = dial.chord(y)
                    for s in 0...40 {
                        let t = CGFloat(s) / 40
                        let pt = CGPoint(x: dial.center.x - w + 2 * w * t, y: y + 1.2 * k * CGFloat(sin(Double(t) * 14 + Double(i))))
                        if s == 0 { fog.move(to: pt) } else { fog.addLine(to: pt) }
                    }
                }
                l.opacity = 0.75
                l.stroke(fog, with: sheen, style: StrokeStyle(lineWidth: dial.line * 0.6, lineCap: .round, dash: [9 * k, 3 * k]))
            default:
                break
            }
        }
    }
}
