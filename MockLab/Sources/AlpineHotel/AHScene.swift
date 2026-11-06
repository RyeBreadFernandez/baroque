import SwiftUI

// The matte painting behind every widget: a gouache alpine range in atmospheric layers, a pink grand hotel on a rock
// ledge in the middle distance with its funicular running straight down at the camera, pines in symmetric rows,
// and painted weather. Everything is drawn in one Canvas (no per-tree views). Always daytime, by choice.

enum AHSky {
    case clear, partly, overcast, fog, rain, snow, storm

    init(_ weather: WeatherSnapshot?) {
        guard let code = weather?.code else { self = .clear; return }
        switch code {
        case 0, 1: self = .clear
        case 2: self = .partly
        case 3: self = .overcast
        case 45, 48: self = .fog
        case 51...67, 80...82: self = .rain
        case 71...77, 85, 86: self = .snow
        case 95...99: self = .storm
        default: self = .partly
        }
    }

    var wet: Bool { self == .rain || self == .storm }
    var grey: Bool { !(self == .clear || self == .partly) }
}

struct AHSceneSpec {
    var sky: AHSky = .clear
    /// Vertical key lines as fractions of the scene height.
    var apex: CGFloat = 0.12        // central summit
    var shoulders: CGFloat = 0.32   // flanking summits
    var far: CGFloat = 0.36         // far range
    var base: CGFloat = 0.74        // foot of the massif
    var hills: CGFloat = 0.62       // mint hills at the edges
    var ledge: CGFloat = 0.64       // the hotel's terrace
    var meadow: CGFloat = 0.86      // foreground slopes at the centre
    /// Hotel width in points (0 hides the hotel and its ledge).
    var hotel: CGFloat = 110
    var sign = true
    var funicular = true
    var cableCars = false
    var framingPines: CGFloat = 1
    var pineScale: CGFloat = 1
    var sun = true
    var sunSize: CGFloat = 0.1
    /// Where the two shoulder summits stand (and their mirror), as a fraction of the width.
    var shoulderX: CGFloat = 0.24
    var seed: UInt64 = 7
    var gouache: Double = 0.75
}

struct AHBackdrop: View {
    var spec: AHSceneSpec
    var body: some View {
        Canvas { ctx, size in
            AHScene.paint(ctx, in: CGRect(origin: .zero, size: size), spec: spec)
        }
    }
}

enum AHScene {
    struct Palette {
        var sky: [Color]
        var haze: Color
        var peakLit: Color
        var peakShade: Color
        var farLit: Color
        var farShade: Color
        var clouds: Int
        var deck: Bool
    }

    static func palette(_ sky: AHSky) -> Palette {
        switch sky {
        case .clear:
            return Palette(sky: [AH.skyTop, AH.skyMid, AH.haze], haze: AH.haze, peakLit: AH.peakLit, peakShade: AH.peakShade,
                           farLit: AH.farLit, farShade: AH.farShade, clouds: 2, deck: false)
        case .partly:
            return Palette(sky: [Color(hex: 0x86B0D6), Color(hex: 0xB3CDE6), AH.haze], haze: AH.haze, peakLit: AH.peakLit,
                           peakShade: AH.peakShade, farLit: AH.farLit, farShade: AH.farShade, clouds: 4, deck: false)
        case .overcast, .fog:
            return Palette(sky: [Color(hex: 0xA8AECB), Color(hex: 0xC9C8DC), Color(hex: 0xEEDFE4)], haze: Color(hex: 0xEEE2E7),
                           peakLit: Color(hex: 0xE2BCCB), peakShade: Color(hex: 0xA592BE), farLit: Color(hex: 0xD3CEE2),
                           farShade: Color(hex: 0xB8B2D2), clouds: 0, deck: true)
        case .rain, .storm:
            return Palette(sky: [Color(hex: 0x8790B2), Color(hex: 0xA9ADC8), Color(hex: 0xDCCFDA)], haze: Color(hex: 0xE2D6E0),
                           peakLit: Color(hex: 0xD8B1C4), peakShade: Color(hex: 0x9285B4), farLit: Color(hex: 0xC4BEDA),
                           farShade: Color(hex: 0xA59FC6), clouds: 0, deck: true)
        case .snow:
            return Palette(sky: [Color(hex: 0xAFBDD9), Color(hex: 0xD3D9EB), Color(hex: 0xF4EAF0)], haze: Color(hex: 0xF4ECF2),
                           peakLit: Color(hex: 0xEAC8D6), peakShade: Color(hex: 0xADA0CC), farLit: Color(hex: 0xDCD6EC),
                           farShade: Color(hex: 0xC2BCDD), clouds: 0, deck: true)
        }
    }

    static func paint(_ context: GraphicsContext, in r: CGRect, spec s: AHSceneSpec) {
        var ctx = context
        ctx.clip(to: Path(r))
        let pal = palette(s.sky)
        let w = r.width, h = r.height
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }
        var rng = SeededRandom(seed: s.seed)

        // 1. Sky, laid in with broad horizontal strokes.
        ctx.fill(Path(r), with: .linearGradient(Gradient(colors: pal.sky), startPoint: P(0.5, 0), endPoint: P(0.5, s.base)))
        for _ in 0..<(Int(w * h / 700) + 10) {
            let cw = w * rng.range(0.16...0.5), ch = rng.range(2.5...8)
            let c = P(rng.range(-0.1...1.1), rng.range(0...(s.base * 0.85)))
            let light = rng.unit() < 0.6
            ctx.fill(Path(roundedRect: CGRect(x: c.x - cw / 2, y: c.y - ch / 2, width: cw, height: ch), cornerRadius: ch / 2),
                     with: .color(light ? Color.white.opacity(rng.range(0.05...0.13)) : pal.sky[0].opacity(rng.range(0.06...0.12))))
        }

        // 2. Sun rising behind the summit, with poster halo rings.
        if s.sun && !s.sky.grey {
            sun(ctx, at: P(0.5, s.apex + 0.03), radius: min(w, h) * s.sunSize)
        }
        if pal.deck { cloudDeck(ctx, r: r, until: s.far + 0.02, dark: s.sky.wet, seed: s.seed &+ 3) }

        // 3. Clouds, a symmetric pair (more when partly cloudy).
        let cloudSpots: [(CGFloat, CGFloat, CGFloat)] = [(0.17, 0.16, 0.2), (0.83, 0.2, 0.18), (0.36, 0.08, 0.12), (0.64, 0.1, 0.13)]
        for (i, c) in cloudSpots.prefix(pal.clouds).enumerated() {
            cloud(ctx, center: P(c.0, c.1 + s.apex * 0.3), width: w * c.2 * (h < 120 ? 0.8 : 1), seed: s.seed &+ UInt64(i))
        }

        // 4. Far range: pale lilac, low contrast.
        let farPeaks: [(CGFloat, CGFloat, CGFloat)] = [(-0.04, 0.07, 0.2), (0.13, -0.03, 0.17), (0.3, 0.04, 0.16),
                                                       (0.7, 0.04, 0.16), (0.87, -0.03, 0.17), (1.04, 0.07, 0.2)]
        for (i, f) in farPeaks.enumerated() {
            let pk = AHPeak(apex: P(f.0, s.far + f.1), left: w * f.2, right: w * f.2 * 1.05, base: r.minY + (s.base + 0.04) * h,
                            snow: 0.34, spine: f.0 < 0.5 ? 0.25 : 0.12, seed: s.seed &+ 20 &+ UInt64(i))
            pk.draw(ctx, lit: pal.farLit, shade: pal.farShade, snowLit: AH.snow.opacity(0.92), snowShade: AH.snowShade.opacity(0.85))
        }
        haze(ctx, r: r, from: s.far + 0.08, to: s.base + 0.04, color: pal.haze, strength: 0.75)

        // 5. The massif: two shoulders and the central summit.
        let shoulderW = w * (w > h * 1.6 ? 0.21 : 0.27)
        for (i, x) in [s.shoulderX, 1 - s.shoulderX].enumerated() {
            let pk = AHPeak(apex: P(x, s.shoulders), left: shoulderW, right: shoulderW * 1.08, base: r.minY + (s.base + 0.06) * h,
                            snow: 0.38, spine: 0.2, seed: s.seed &+ 40 &+ UInt64(i))
            pk.draw(ctx, lit: pal.peakLit, shade: pal.peakShade, snowLit: AH.snow, snowShade: AH.snowShade)
        }
        let summitW = w * (w > h * 1.6 ? 0.25 : 0.36)
        let summit = AHPeak(apex: P(0.5, s.apex), left: summitW, right: summitW * 1.04, base: r.minY + (s.base + 0.08) * h,
                            snow: 0.42, spine: 0.16, seed: s.seed &+ 60)
        summit.draw(ctx, lit: pal.peakLit, shade: pal.peakShade, snowLit: AH.snow, snowShade: AH.snowShade)
        haze(ctx, r: r, from: s.base - 0.16, to: s.base + 0.06, color: pal.haze, strength: 0.85)

        // 6. Cable cars on a wire slung across the valley, a mirrored pair.
        if s.cableCars { cableCars(ctx, r: r, y: s.shoulders + 0.16) }

        // 7. Mint hills and the back row of pines.
        let hillTop = s.hills
        var hills = Path()
        hills.move(to: P(-0.02, hillTop))
        hills.addCurve(to: P(0.5, hillTop + 0.1), control1: P(0.18, hillTop - 0.01), control2: P(0.34, hillTop + 0.1))
        hills.addCurve(to: P(1.02, hillTop), control1: P(0.66, hillTop + 0.1), control2: P(0.82, hillTop - 0.01))
        hills.addLine(to: P(1.02, 1.02))
        hills.addLine(to: P(-0.02, 1.02))
        hills.closeSubpath()
        ctx.fill(hills, with: .linearGradient(Gradient(colors: [Color(hex: 0xC4E6D3), AH.mint, AH.mintDeep]),
                                              startPoint: P(0.5, hillTop), endPoint: P(0.5, min(1, hillTop + 0.3))))
        func hillY(_ x: CGFloat) -> CGFloat {
            // matches the curve above closely enough to seat the trees
            let d = abs(x - 0.5) / 0.5
            return hillTop + 0.1 * (1 - d * d) * (1 - 0.15 * d) - 0.005
        }
        var back: [(CGPoint, CGFloat)] = []
        let backH = min(h * 0.11, 15) * s.pineScale
        var x: CGFloat = 0.02
        while x < 0.36 {
            let hh = backH * rng.range(0.75...1.1)
            back.append((P(x, hillY(x) + 0.012), hh))
            back.append((P(1 - x, hillY(1 - x) + 0.012), hh))
            x += rng.range(0.028...0.042) * (h < 120 ? 1.3 : 1)
        }
        pines(ctx, back, body: Color(hex: 0x4F8C82), lit: Color(hex: 0x76AE9E))

        // 8. The ledge, the funicular and the hotel.
        if s.hotel > 0 {
            let cx = r.midX, top = r.minY + s.ledge * h
            ledge(ctx, cx: cx, top: top, bottom: r.maxY + 2, halfTop: s.hotel * 0.6, halfBottom: s.hotel * 0.86, seed: s.seed &+ 80)
            if s.funicular { funicular(ctx, cx: cx, top: top + s.hotel * 0.035, bottom: r.maxY, u: s.hotel / 108) }
            hotel(ctx, cx: cx, base: top, width: s.hotel, sign: s.sign, grey: s.sky.grey)
        }

        // 9. Foreground slopes rising to the edges, with nearer pines and the tall framing pines.
        let m = s.meadow
        var front = Path()
        front.move(to: P(-0.02, m - 0.2))
        front.addCurve(to: P(0.5, m + 0.1), control1: P(0.16, m - 0.12), control2: P(0.3, m + 0.08))
        front.addCurve(to: P(1.02, m - 0.2), control1: P(0.7, m + 0.08), control2: P(0.84, m - 0.12))
        front.addLine(to: P(1.02, 1.02))
        front.addLine(to: P(-0.02, 1.02))
        front.closeSubpath()
        ctx.fill(front, with: .linearGradient(Gradient(colors: [Color(hex: 0x9FD3BA), AH.mintDeep, Color(hex: 0x5FA58C)]),
                                              startPoint: P(0.5, m - 0.2), endPoint: P(0.5, 1)))
        // snow drifts along the crest
        var drift = Path()
        for i in 0..<9 {
            let fx = 0.04 + CGFloat(i) * 0.05
            for side in [fx, 1 - fx] {
                let y = frontY(side, m) + 0.01
                let dw = w * rng.range(0.03...0.06), dh = max(1.4, h * rng.range(0.008...0.014))
                drift.addEllipse(in: CGRect(x: r.minX + side * w - dw / 2, y: r.minY + y * h - dh / 2, width: dw, height: dh))
            }
        }
        ctx.fill(drift, with: .color(AH.snow.opacity(0.85)))

        var near: [(CGPoint, CGFloat)] = []
        let nearH = min(h * 0.18, 26) * s.pineScale
        x = 0.05
        while x < 0.3 {
            let hh = nearH * rng.range(0.7...1.05) * (1 - x * 0.8)
            near.append((P(x, frontY(x, m) + 0.03), hh))
            near.append((P(1 - x, frontY(1 - x, m) + 0.03), hh))
            x += rng.range(0.045...0.06) * (h < 120 ? 1.25 : 1)
        }
        pines(ctx, near, body: AH.pine, lit: AH.pineLit)
        if s.framingPines > 0 {
            let fh = h * 0.52 * s.framingPines
            let frame: [(CGPoint, CGFloat)] = [(P(0.035, 1.03), fh), (P(0.965, 1.03), fh),
                                               (P(0.1, 1.06), fh * 0.78), (P(0.9, 1.06), fh * 0.78)]
            pines(ctx, frame, body: AH.pineDark, lit: AH.pine)
        }

        // 10. Weather over the set.
        switch s.sky {
        case .rain, .storm: rain(ctx, r: r, seed: s.seed &+ 90, heavy: s.sky == .storm)
        case .snow: snowfall(ctx, r: r, seed: s.seed &+ 91)
        case .fog: mist(ctx, r: r, seed: s.seed &+ 92, at: [s.base - 0.06, s.ledge + 0.06, s.meadow - 0.04])
        default: break
        }

        // 11. Gouache brushwork over everything painted.
        AHTex.lay(ctx, AHTex.gouache, in: r, opacity: s.gouache)
    }

    private static func frontY(_ x: CGFloat, _ m: CGFloat) -> CGFloat {
        let d = abs(x - 0.5) / 0.5
        return m + 0.1 - 0.3 * pow(d, 1.25)
    }

    // MARK: Sky pieces

    static func sun(_ ctx: GraphicsContext, at c: CGPoint, radius: CGFloat) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius * 3.2, y: c.y - radius * 3.2, width: radius * 6.4, height: radius * 6.4)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF2C8, opacity: 0.75), Color(hex: 0xFFE9C0, opacity: 0)]),
                                       center: c, startRadius: radius * 0.6, endRadius: radius * 3.2))
        for (k, a) in [(1.55, 0.35), (2.1, 0.22)] {
            let rr = radius * k
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                       with: .color(Color(hex: 0xFFF6DD, opacity: a)), lineWidth: max(0.6, radius * 0.08))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF8DC), Color(hex: 0xFBDD8E)]),
                                       center: CGPoint(x: c.x - radius * 0.3, y: c.y - radius * 0.3), startRadius: 0, endRadius: radius * 1.2))
    }

    static func cloud(_ ctx: GraphicsContext, center c: CGPoint, width cw: CGFloat, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        let hh = cw * 0.34
        var p = Path()
        let puffs = 5
        for i in 0..<puffs {
            let t = CGFloat(i) / CGFloat(puffs - 1)
            let rr = hh * (0.42 + 0.38 * sin(t * .pi)) * rng.range(0.85...1.1)
            let px = c.x - cw / 2 + rr + t * (cw - 2 * rr)
            p.addEllipse(in: CGRect(x: px - rr, y: c.y - rr * 1.15, width: rr * 2, height: rr * 2))
        }
        let flat = CGRect(x: c.x - cw / 2 + hh * 0.3, y: c.y - hh * 0.25, width: cw - hh * 0.6, height: hh * 0.5)
        p.addRoundedRect(in: flat, cornerSize: CGSize(width: hh * 0.25, height: hh * 0.25))
        var clip = Path(CGRect(x: c.x - cw, y: c.y - cw, width: cw * 2, height: cw + hh * 0.25))
        clip = clip.intersection(p)
        // cast shadow on the sky, then the body, then the warm underside
        ctx.fill(clip.offsetBy(dx: hh * 0.08, dy: hh * 0.12), with: .color(Color(hex: 0x8C93C4, opacity: 0.18)))
        ctx.fill(clip, with: .color(Color(hex: 0xFFF8F1)))
        var l = ctx
        l.clip(to: clip)
        l.fill(Path(CGRect(x: c.x - cw, y: c.y - hh * 0.2, width: cw * 2, height: hh)),
               with: .linearGradient(Gradient(colors: [Color(hex: 0xF4C9D6, opacity: 0), Color(hex: 0xE7AFC6, opacity: 0.9)]),
                                     startPoint: CGPoint(x: c.x, y: c.y - hh * 0.3), endPoint: CGPoint(x: c.x, y: c.y + hh * 0.25)))
    }

    static func cloudDeck(_ ctx: GraphicsContext, r: CGRect, until: CGFloat, dark: Bool, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        let rows = 3
        for row in 0..<rows {
            let y = r.minY + r.height * (until * (0.2 + 0.32 * CGFloat(row)))
            var p = Path()
            var x = r.minX - 10
            while x < r.maxX + 10 {
                let rr = r.height * rng.range(0.06...0.11)
                p.addEllipse(in: CGRect(x: x, y: y - rr, width: rr * 2.4, height: rr * 1.7))
                x += rr * 1.6
            }
            let tone = dark ? Color(hex: 0x9DA0BE) : Color(hex: 0xD9D6E6)
            ctx.fill(p, with: .color(tone.opacity(0.55 + 0.15 * Double(row))))
            ctx.fill(p.offsetBy(dx: 0, dy: -2), with: .color(Color.white.opacity(dark ? 0.08 : 0.18)))
        }
    }

    static func haze(_ ctx: GraphicsContext, r: CGRect, from: CGFloat, to: CGFloat, color: Color, strength: Double) {
        let y0 = r.minY + from * r.height, y1 = r.minY + to * r.height
        ctx.fill(Path(CGRect(x: r.minX, y: y0, width: r.width, height: y1 - y0)),
                 with: .linearGradient(Gradient(colors: [color.opacity(0), color.opacity(strength)]),
                                       startPoint: CGPoint(x: 0, y: y0), endPoint: CGPoint(x: 0, y: y1)))
    }

    // MARK: Trees

    /// Model-railway pines: stacked drooping tiers, the lit half picked out on the left (key light from upper left).
    static func pines(_ ctx: GraphicsContext, _ list: [(CGPoint, CGFloat)], body: Color, lit: Color) {
        var dark = Path(), light = Path()
        for (b, hgt) in list {
            let w = hgt * 0.36
            let tiers = 4
            for i in 0..<tiers {
                let f = CGFloat(i) / CGFloat(tiers - 1)
                let top = b.y - hgt + hgt * 0.21 * CGFloat(i)
                let bottom = top + hgt * 0.37
                let half = w * (0.4 + 0.6 * f)
                let droop = hgt * 0.05
                var t = Path()
                t.move(to: CGPoint(x: b.x, y: top))
                t.addLine(to: CGPoint(x: b.x + half, y: bottom))
                t.addQuadCurve(to: CGPoint(x: b.x - half, y: bottom), control: CGPoint(x: b.x, y: bottom - droop * 2))
                t.closeSubpath()
                dark.addPath(t)
                var l = Path()
                l.move(to: CGPoint(x: b.x, y: top + hgt * 0.02))
                l.addLine(to: CGPoint(x: b.x - half * 0.08, y: bottom - droop))
                l.addQuadCurve(to: CGPoint(x: b.x - half * 0.98, y: bottom - 0.3), control: CGPoint(x: b.x - half * 0.55, y: bottom - droop * 1.3))
                l.closeSubpath()
                light.addPath(l)
            }
            dark.addRect(CGRect(x: b.x - hgt * 0.035, y: b.y - hgt * 0.1, width: hgt * 0.07, height: hgt * 0.12))
        }
        ctx.fill(dark, with: .color(body))
        ctx.fill(light, with: .color(lit))
    }

    // MARK: Ledge and funicular

    static func ledge(_ ctx: GraphicsContext, cx: CGFloat, top: CGFloat, bottom: CGFloat, halfTop: CGFloat, halfBottom: CGFloat, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        var left: [CGPoint] = [], right: [CGPoint] = [], spine: [CGPoint] = []
        let n = 7
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let y = top + (bottom - top) * t
            let half = halfTop + (halfBottom - halfTop) * pow(t, 0.6)
            let jl = i == 0 ? 0 : rng.range(-0.07...0.05) * halfTop
            let jr = i == 0 ? 0 : rng.range(-0.05...0.07) * halfTop
            left.append(CGPoint(x: cx - half + jl, y: y))
            right.append(CGPoint(x: cx + half + jr, y: y))
            spine.append(CGPoint(x: cx + halfTop * 0.42 + (halfBottom - halfTop) * 0.4 * t + rng.range(-0.04...0.04) * halfTop, y: y))
        }
        // overhang lip
        var body = Path()
        body.move(to: CGPoint(x: left[0].x - halfTop * 0.06, y: top - halfTop * 0.015))
        body.addLine(to: CGPoint(x: right[0].x + halfTop * 0.06, y: top - halfTop * 0.015))
        right.forEach { body.addLine(to: $0) }
        left.reversed().forEach { body.addLine(to: $0) }
        body.closeSubpath()
        ctx.fill(body, with: .linearGradient(Gradient(colors: [AH.rock, Color(hex: 0xDFAE9F), AH.rockShade]),
                                             startPoint: CGPoint(x: cx, y: top), endPoint: CGPoint(x: cx, y: bottom)))
        var face = Path()
        face.move(to: spine[0])
        spine.dropFirst().forEach { face.addLine(to: $0) }
        right.reversed().forEach { face.addLine(to: $0) }
        face.closeSubpath()
        ctx.fill(face, with: .color(Color(hex: 0x9F7299, opacity: 0.55)))
        // cliff pillars: each a lit sliver and a shadow crack, painted top to bottom like gouache columns
        var l = ctx
        l.clip(to: body)
        var lights = Path(), cracks = Path()
        let cols = max(5, Int(halfTop / 9))
        for k in 0...cols {
            let t = CGFloat(k) / CGFloat(cols)
            var xt = cx - halfTop + 2 * halfTop * t + rng.range(-0.04...0.04) * halfTop
            var xb = cx - halfBottom + 2 * halfBottom * t + rng.range(-0.06...0.06) * halfBottom
            if abs(xt - cx) < halfTop * 0.12 { xt += halfTop * 0.16; xb += halfTop * 0.2 }  // keep the track clear
            let cw = halfTop * rng.range(0.035...0.07)
            var crack = Path(), light = Path()
            let steps = 6
            var leftEdge: [CGPoint] = [], rightEdge: [CGPoint] = []
            for i in 0...steps {
                let f = CGFloat(i) / CGFloat(steps)
                let y = top + halfTop * 0.04 + (bottom - top) * f
                let x = xt + (xb - xt) * f + rng.range(-0.02...0.02) * halfTop
                leftEdge.append(CGPoint(x: x, y: y))
                rightEdge.append(CGPoint(x: x + cw * (0.5 + f), y: y))
            }
            crack.move(to: leftEdge[0]); leftEdge.dropFirst().forEach { crack.addLine(to: $0) }
            rightEdge.reversed().forEach { crack.addLine(to: $0) }; crack.closeSubpath()
            light.move(to: CGPoint(x: leftEdge[0].x - cw * 1.6, y: leftEdge[0].y))
            leftEdge.dropFirst().forEach { light.addLine(to: CGPoint(x: $0.x - cw * 1.4, y: $0.y)) }
            leftEdge.reversed().forEach { light.addLine(to: $0) }; light.closeSubpath()
            cracks.addPath(crack)
            lights.addPath(light)
        }
        l.fill(lights, with: .color(Color(hex: 0xFFE0CC, opacity: 0.42)))
        l.fill(cracks, with: .color(Color(hex: 0x7E5677, opacity: 0.42)))
        // horizontal shelves holding snow, with a few small pines on them
        var shelves = Path()
        var shelfPines: [(CGPoint, CGFloat)] = []
        var y = top + (bottom - top) * 0.22
        while y < bottom - 4 {
            for side in [CGFloat(-1), 1] {
                let f = (y - top) / max(1, bottom - top)
                let half = halfTop + (halfBottom - halfTop) * pow(f, 0.6)
                let x0 = cx + side * half * rng.range(0.35...0.8)
                let len = half * rng.range(0.1...0.22)
                let th = max(1.1, halfTop * 0.028)
                var shelf = Path()
                shelf.move(to: CGPoint(x: x0 - len / 2, y: y + th * 0.6))
                shelf.addQuadCurve(to: CGPoint(x: x0 + len / 2, y: y + th * 0.4), control: CGPoint(x: x0, y: y - th * 0.9))
                shelf.addQuadCurve(to: CGPoint(x: x0 + len * 0.1, y: y + th), control: CGPoint(x: x0 + len * 0.3, y: y + th * 1.6))
                shelf.addQuadCurve(to: CGPoint(x: x0 - len / 2, y: y + th * 0.6), control: CGPoint(x: x0 - len * 0.2, y: y + th * 2.2))
                shelf.closeSubpath()
                shelves.addPath(shelf)
                if rng.unit() < 0.7 {
                    shelfPines.append((CGPoint(x: x0 + rng.range(-0.3...0.3) * len, y: y + 0.6), max(4, halfTop * rng.range(0.1...0.16))))
                }
            }
            y += (bottom - top) * rng.range(0.16...0.24)
        }
        l.fill(shelves.offsetBy(dx: 0, dy: 1), with: .color(Color(hex: 0x7E5677, opacity: 0.35)))
        l.fill(shelves, with: .color(AH.snow.opacity(0.9)))
        AHScene.pines(l, shelfPines, body: AH.pine, lit: AH.pineLit)
        // lit edge on the left face
        var edge = Path()
        edge.move(to: left[0])
        left.dropFirst().prefix(4).forEach { edge.addLine(to: $0) }
        l.stroke(edge, with: .color(Color(hex: 0xFFE3D2, opacity: 0.7)), lineWidth: max(0.8, halfTop * 0.03))
        // snow lip with drips
        var snow = Path()
        snow.move(to: CGPoint(x: left[0].x - halfTop * 0.06, y: top - halfTop * 0.02))
        snow.addLine(to: CGPoint(x: right[0].x + halfTop * 0.06, y: top - halfTop * 0.02))
        var sx = right[0].x + halfTop * 0.06
        while sx > left[0].x - halfTop * 0.06 {
            let step = halfTop * rng.range(0.06...0.12)
            let dip = halfTop * rng.range(0.03...0.11)
            snow.addQuadCurve(to: CGPoint(x: sx - step, y: top + halfTop * 0.02), control: CGPoint(x: sx - step / 2, y: top + dip))
            sx -= step
        }
        snow.closeSubpath()
        ctx.fill(snow, with: .color(AH.snow))
    }

    static func funicular(_ ctx: GraphicsContext, cx: CGFloat, top: CGFloat, bottom: CGFloat, u: CGFloat) {
        let gauge = 2.4 * u
        // bed, rails, ties: perspective widens toward the camera
        var bed = Path()
        bed.move(to: CGPoint(x: cx - gauge * 1.3, y: top))
        bed.addLine(to: CGPoint(x: cx + gauge * 1.3, y: top))
        bed.addLine(to: CGPoint(x: cx + gauge * 2.6, y: bottom))
        bed.addLine(to: CGPoint(x: cx - gauge * 2.6, y: bottom))
        bed.closeSubpath()
        ctx.fill(bed, with: .color(Color(hex: 0x8F6A86, opacity: 0.55)))
        var ties = Path()
        var y = top + 1
        var k: CGFloat = 0
        while y < bottom {
            let t = (y - top) / max(1, bottom - top)
            let half = gauge * (1.2 + 1.3 * t)
            ties.addRect(CGRect(x: cx - half, y: y, width: half * 2, height: max(0.5, 0.45 * u * (1 + t))))
            k += 1
            y += max(1.6, 2.2 * u * (1 + t * 1.2))
        }
        ctx.fill(ties, with: .color(Color(hex: 0x6B4560, opacity: 0.7)))
        var rails = Path()
        for sgn in [CGFloat(-1), 1] {
            rails.move(to: CGPoint(x: cx + sgn * gauge * 0.8, y: top))
            rails.addLine(to: CGPoint(x: cx + sgn * gauge * 1.7, y: bottom))
        }
        ctx.stroke(rails, with: .color(AH.goldDeep), lineWidth: max(0.5, 0.45 * u))
        // the car, halfway down, seen head on
        let t: CGFloat = 0.42
        let cy = top + (bottom - top) * t
        let cw = gauge * (3.2 + 1.6 * t), ch = cw * 0.78
        let car = CGRect(x: cx - cw / 2, y: cy - ch, width: cw, height: ch)
        ctx.fill(Path(ellipseIn: car.insetBy(dx: -cw * 0.1, dy: 0).offsetBy(dx: 0, dy: ch * 0.75).insetBy(dx: 0, dy: ch * 0.38)),
                 with: .color(AH.plum.opacity(0.35)))
        ctx.fill(Path(roundedRect: car, cornerRadius: cw * 0.18), with: .linearGradient(Gradient(colors: [AH.raspberry, AH.raspberryDeep]),
                                                                                      startPoint: CGPoint(x: car.minX, y: car.minY), endPoint: CGPoint(x: car.maxX, y: car.maxY)))
        ctx.fill(Path(roundedRect: CGRect(x: car.minX + cw * 0.14, y: car.minY + ch * 0.18, width: cw * 0.72, height: ch * 0.34), cornerRadius: cw * 0.06),
                 with: .color(AH.butter))
        ctx.fill(Path(CGRect(x: car.minX + cw * 0.47, y: car.minY + ch * 0.18, width: cw * 0.06, height: ch * 0.34)), with: .color(AH.raspberryDeep))
        ctx.fill(Path(CGRect(x: car.minX, y: car.minY + ch * 0.62, width: cw, height: ch * 0.08)), with: .color(AH.cream))
        ctx.fill(Path(roundedRect: CGRect(x: car.minX - cw * 0.06, y: car.minY - ch * 0.08, width: cw * 1.12, height: ch * 0.14), cornerRadius: ch * 0.05),
                 with: .color(AH.cream))
    }

    static func cableCars(_ ctx: GraphicsContext, r: CGRect, y: CGFloat) {
        let y0 = r.minY + r.height * (y - 0.06), sag = r.height * 0.07
        var wire = Path()
        wire.move(to: CGPoint(x: r.minX - 4, y: y0))
        wire.addQuadCurve(to: CGPoint(x: r.maxX + 4, y: y0), control: CGPoint(x: r.midX, y: y0 + sag * 2))
        ctx.stroke(wire, with: .color(AH.plum.opacity(0.55)), lineWidth: 0.6)
        ctx.stroke(wire.offsetBy(dx: 0, dy: 1.6), with: .color(AH.plum.opacity(0.3)), lineWidth: 0.45)
        for fx in [CGFloat(0.28), 0.72] {
            let x = r.minX + r.width * fx
            let t = (x - r.minX) / r.width
            let wy = y0 + sag * 2 * 2 * t * (1 - t)
            let cw = max(7, r.width * 0.03), ch = cw * 0.8
            var hanger = Path()
            hanger.move(to: CGPoint(x: x, y: wy))
            hanger.addLine(to: CGPoint(x: x, y: wy + ch * 0.8))
            ctx.stroke(hanger, with: .color(AH.plum.opacity(0.7)), lineWidth: 0.7)
            let cab = CGRect(x: x - cw / 2, y: wy + ch * 0.8, width: cw, height: ch)
            ctx.fill(Path(roundedRect: cab, cornerRadius: cw * 0.2), with: .color(fx < 0.5 ? AH.raspberry : Color(hex: 0x7C9FD0)))
            ctx.fill(Path(roundedRect: CGRect(x: cab.minX + cw * 0.15, y: cab.minY + ch * 0.18, width: cw * 0.7, height: ch * 0.36), cornerRadius: 0.6),
                     with: .color(AH.cream))
            ctx.fill(Path(CGRect(x: cab.minX - 0.6, y: cab.minY - 0.8, width: cw + 1.2, height: 1.2)), with: .color(AH.cream))
        }
    }

    // MARK: Weather

    static func rain(_ ctx: GraphicsContext, r: CGRect, seed: UInt64, heavy: Bool) {
        var rng = SeededRandom(seed: seed)
        var p = Path()
        let n = Int(r.width * r.height / (heavy ? 28 : 42))
        for _ in 0..<n {
            let x = r.minX + rng.range(-10...(r.width + 10)), y = r.minY + rng.range(-10...r.height)
            let len = rng.range(4...9)
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x - len * 0.22, y: y + len))
        }
        ctx.stroke(p, with: .color(Color(hex: 0xF4EEFF, opacity: 0.6)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        ctx.stroke(p.offsetBy(dx: 0.6, dy: 0.6), with: .color(Color(hex: 0x6E6A9A, opacity: 0.18)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
    }

    static func snowfall(_ ctx: GraphicsContext, r: CGRect, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        var near = Path(), far = Path()
        let n = Int(r.width * r.height / 70)
        for i in 0..<n {
            let x = r.minX + rng.range(0...r.width), y = r.minY + rng.range(0...r.height)
            let big = i % 5 == 0
            let d = big ? rng.range(1.6...2.6) : rng.range(0.7...1.4)
            if big { near.addEllipse(in: CGRect(x: x, y: y, width: d, height: d)) } else { far.addEllipse(in: CGRect(x: x, y: y, width: d, height: d)) }
        }
        ctx.fill(far, with: .color(Color.white.opacity(0.75)))
        ctx.fill(near.offsetBy(dx: 0.4, dy: 0.5), with: .color(Color(hex: 0x8A86B5, opacity: 0.25)))
        ctx.fill(near, with: .color(Color.white.opacity(0.95)))
    }

    static func mist(_ context: GraphicsContext, r: CGRect, seed: UInt64, at bands: [CGFloat]) {
        var rng = SeededRandom(seed: seed)
        var ctx = context
        ctx.addFilter(.blur(radius: max(2, r.height * 0.02)))
        for b in bands {
            for _ in 0..<4 {
                let bw = r.width * rng.range(0.4...0.8), bh = r.height * rng.range(0.04...0.07)
                let x = r.minX + rng.range(-0.2...0.8) * r.width
                let y = r.minY + (b + rng.range(-0.03...0.03)) * r.height
                ctx.fill(Path(roundedRect: CGRect(x: x, y: y - bh / 2, width: bw, height: bh), cornerRadius: bh / 2),
                         with: .color(Color(hex: 0xFBF4F7, opacity: 0.5)))
            }
        }
    }
}

/// A gouache peak: a lit face and a shadow face split along a jagged spine, and a snowcap with dripping fingers
/// and gullies, shaded the same way.
struct AHPeak {
    var apex: CGPoint
    var left: CGFloat
    var right: CGFloat
    var base: CGFloat
    var snow: CGFloat
    var spine: CGFloat
    var seed: UInt64

    func draw(_ ctx: GraphicsContext, lit: Color, shade: Color, snowLit: Color, snowShade: Color) {
        var rng = SeededRandom(seed: seed)
        let h = base - apex.y
        func ridge(_ dir: CGFloat, _ half: CGFloat) -> [CGPoint] {
            var pts: [CGPoint] = []
            let n = 8
            for i in 1..<n {
                let t = CGFloat(i) / CGFloat(n)
                let x = apex.x + dir * half * pow(t, 0.9) + dir * rng.range(-0.035...0.035) * half
                let y = apex.y + h * t + rng.range(-0.045...0.045) * h * (1 - t * 0.6)
                pts.append(CGPoint(x: x, y: y))
            }
            pts.append(CGPoint(x: apex.x + dir * half, y: base))
            return pts
        }
        let lr = ridge(-1, left), rr = ridge(1, right)
        var sp: [CGPoint] = [apex]
        for i in 1...6 {
            let t = CGFloat(i) / 6
            sp.append(CGPoint(x: apex.x + spine * right * pow(t, 0.8) + rng.range(-0.03...0.03) * right * t, y: apex.y + h * t))
        }
        var body = Path()
        body.move(to: apex)
        lr.forEach { body.addLine(to: $0) }
        rr.reversed().forEach { body.addLine(to: $0) }
        body.closeSubpath()
        var shadeP = Path()
        shadeP.move(to: apex)
        sp.dropFirst().forEach { shadeP.addLine(to: $0) }
        rr.reversed().forEach { shadeP.addLine(to: $0) }
        shadeP.closeSubpath()

        ctx.fill(body, with: .linearGradient(Gradient(colors: [lit, lit.opacity(0.92)]), startPoint: apex, endPoint: CGPoint(x: apex.x, y: base)))
        ctx.fill(shadeP, with: .color(shade))
        // soft core shadow along the spine
        var core = ctx
        core.clip(to: shadeP)
        core.stroke(Path { p in p.move(to: sp[0]); sp.dropFirst().forEach { p.addLine(to: $0) } }.offsetBy(dx: right * 0.04, dy: 0),
                    with: .color(Color(hex: 0x6E5A98, opacity: 0.22)), lineWidth: right * 0.08)

        // snowcap
        let sy = apex.y + h * snow
        var cap = Path()
        let x0 = apex.x - left * 1.05, x1 = apex.x + right * 1.05
        cap.move(to: CGPoint(x: x0, y: apex.y - 4))
        cap.addLine(to: CGPoint(x: x0, y: sy - h * 0.1))
        let steps = 13
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = x0 + (x1 - x0) * t
            let finger = i % 2 == 1 ? h * rng.range(0.04...0.17) : -h * rng.range(0.0...0.05)
            let centreBias = (1 - abs(t - 0.5) * 2) * h * 0.06
            cap.addLine(to: CGPoint(x: x, y: sy + finger + centreBias - h * 0.05))
        }
        cap.addLine(to: CGPoint(x: x1, y: apex.y - 4))
        cap.closeSubpath()
        var gullies = Path()
        for _ in 0..<5 {
            let gx = apex.x + rng.range(-0.6...0.6) * (left + right) / 2
            let gy = sy + rng.range(0...0.08) * h
            let len = h * rng.range(0.08...0.2)
            gullies.move(to: CGPoint(x: gx, y: gy))
            gullies.addLine(to: CGPoint(x: gx + (gx < apex.x ? -1 : 1) * len * 0.35, y: gy + len))
        }
        var s = ctx
        s.clip(to: body)
        s.fill(cap, with: .linearGradient(Gradient(colors: [snowLit, snowLit.opacity(0.94)]), startPoint: apex, endPoint: CGPoint(x: apex.x, y: sy)))
        s.stroke(gullies, with: .color(snowLit.opacity(0.75)), style: StrokeStyle(lineWidth: max(0.6, h * 0.012), lineCap: .round))
        // dry-brush highlight on the lit ridge
        var ridgeLine = Path()
        ridgeLine.move(to: apex)
        lr.prefix(3).forEach { ridgeLine.addLine(to: $0) }
        s.stroke(ridgeLine, with: .color(Color.white.opacity(0.75)), lineWidth: max(0.6, h * 0.012))
        s.clip(to: shadeP)
        s.fill(cap, with: .color(snowShade))
        s.stroke(gullies, with: .color(snowShade.opacity(0.9)), style: StrokeStyle(lineWidth: max(0.6, h * 0.012), lineCap: .round))
    }
}

// MARK: - The hotel

extension AHScene {
    /// An original pink grand hotel, perfectly symmetric: a long main block under a raspberry mansard, two taller end
    /// pavilions with cupolas, and a central clock tower with a bell dome and pennant. Lit from the upper left.
    static func hotel(_ ctx: GraphicsContext, cx: CGFloat, base: CGFloat, width W: CGFloat, sign: Bool, grey: Bool) {
        let u = W / 108
        func R(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            CGRect(x: cx + x0 * u, y: base - y1 * u, width: (x1 - x0) * u, height: (y1 - y0) * u)
        }
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cx + x * u, y: base - y * u) }
        func vgrad(_ top: Color, _ bottom: Color, _ y1: CGFloat, _ y0: CGFloat) -> GraphicsContext.Shading {
            .linearGradient(Gradient(colors: [top, bottom]), startPoint: P(0, y1), endPoint: P(0, y0))
        }
        func hgrad(_ l: Color, _ r: Color, _ x0: CGFloat, _ x1: CGFloat) -> GraphicsContext.Shading {
            .linearGradient(Gradient(colors: [l, r]), startPoint: P(x0, 0), endPoint: P(x1, 0))
        }
        let hair = max(0.35, 0.5 * u)

        // contact shadow
        var sh = ctx
        sh.addFilter(.blur(radius: 2.2 * u))
        sh.fill(Path(ellipseIn: R(-58, -3, 60, 4)), with: .color(AH.plum.opacity(0.4)))

        var glass = Path(), glow = Path(), sills = Path(), lintels = Path()
        func window(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ wh: CGFloat, arch: Bool = false, lit: Bool = false) {
            let rect = R(x - ww / 2, y, x + ww / 2, y + wh)
            let p = arch ? UnevenRoundedRectangle(cornerRadii: .init(topLeading: rect.width / 2, topTrailing: rect.width / 2)).path(in: rect) : Path(rect)
            if lit { glow.addPath(p) } else { glass.addPath(p) }
            sills.addRect(R(x - ww / 2 - 0.5, y - 0.8, x + ww / 2 + 0.5, y))
            lintels.addRect(R(x - ww / 2, y + wh - 0.7, x + ww / 2, y + wh))
        }

        // Main block
        ctx.fill(Path(R(-35, 3, 35, 33)), with: vgrad(AH.pinkLight, AH.pink, 33, 3))
        var litCount = 0
        for (row, spec) in [(6.0, 5.0, true), (14.0, 4.2, false), (20.6, 4.2, false), (27.0, 3.6, false)].enumerated() {
            var x: CGFloat = -31.5
            while x <= 31.6 {
                if abs(x) > 12 {
                    litCount += 1
                    window(x, spec.0, spec.2 ? 3.0 : 2.5, spec.1, arch: spec.2, lit: (litCount * 7 + row * 3) % 11 == 0)
                }
                x += 4.5
            }
        }
        var courses = Path()
        for y in [12.0, 18.9, 25.4] { courses.addRect(R(-35, y, 35, y + 0.9)) }
        ctx.fill(courses, with: .color(AH.cream))
        ctx.fill(Path(R(-35, 32.2, 35, 34)), with: .color(AH.cream))
        ctx.fill(Path(R(-35, 31.6, 35, 32.2)), with: .color(AH.pinkDeep.opacity(0.8)))

        // Main mansard with dormers
        var roof = Path()
        roof.move(to: P(-35.5, 34)); roof.addLine(to: P(35.5, 34)); roof.addLine(to: P(32.5, 41)); roof.addLine(to: P(-32.5, 41)); roof.closeSubpath()
        ctx.fill(roof, with: vgrad(AH.raspberry, AH.raspberryDeep, 41, 34))
        var roofLines = Path()
        var rx: CGFloat = -34
        while rx <= 34 { roofLines.move(to: P(rx, 34)); roofLines.addLine(to: P(rx * 0.93, 41)); rx += 2.2 }
        ctx.stroke(roofLines, with: .color(AH.raspberryDeep.opacity(0.55)), lineWidth: hair * 0.7)
        var dormers = Path(), dormerGlass = Path()
        var dx: CGFloat = -29
        while dx <= 29.1 {
            if abs(dx) > 13 {
                let rect = R(dx - 1.6, 35.2, dx + 1.6, 39.4)
                dormers.addPath(UnevenRoundedRectangle(cornerRadii: .init(topLeading: rect.width / 2, topTrailing: rect.width / 2)).path(in: rect))
                let g = R(dx - 0.9, 35.7, dx + 0.9, 38.6)
                dormerGlass.addPath(UnevenRoundedRectangle(cornerRadii: .init(topLeading: g.width / 2, topTrailing: g.width / 2)).path(in: g))
            }
            dx += 5.8
        }
        ctx.fill(dormers, with: .color(AH.cream))
        ctx.fill(dormerGlass, with: .color(AH.glass))
        ctx.fill(Path(R(-33, 40.6, 33, 41.6)), with: .color(AH.goldLight.opacity(0.9)))

        // Rooftop letters either side of the tower
        if sign && W >= 96 {
            let fs = 4.1 * u
            for (word, x) in [("HOTEL", CGFloat(-22.5)), ("TERRA", 22.5)] {
                let t = Text(word).font(AH.futura(fs)).tracking(0.9 * u)
                let c = ctx
                c.draw(t.foregroundColor(AH.raspberryDeep.opacity(0.6)), at: P(x + 0.3, 43.6), anchor: .center)
                c.draw(t.foregroundColor(AH.goldLight), at: P(x, 44), anchor: .center)
                var posts = Path()
                for k in stride(from: x - 9, through: x + 9, by: 4.5) { posts.addRect(R(k - 0.15, 41, k + 0.15, 42.2)) }
                c.fill(posts, with: .color(AH.goldDeep))
            }
        }

        // End pavilions
        for sgn in [CGFloat(-1), 1] {
            let a = sgn < 0 ? -50.0 : 34.0, b = sgn < 0 ? -34.0 : 50.0
            ctx.fill(Path(R(a, 3, b, 39)), with: vgrad(AH.pink, Color(hex: 0xEE96AF), 39, 3))
            // rusticated quoins
            var quoins = Path()
            for k in stride(from: 4.0, to: 37.0, by: 2.6) {
                let wq: CGFloat = Int(k) % 2 == 0 ? 2.2 : 1.4
                quoins.addRect(R(a, k, a + wq, k + 1.8))
                quoins.addRect(R(b - wq, k, b, k + 1.8))
            }
            ctx.fill(quoins, with: .color(AH.cream.opacity(0.85)))
            for wy in [6.0, 14.0, 21.0, 28.0] {
                for wxo in [-3.6, 3.6] { window((a + b) / 2 + wxo, wy, 2.6, wy == 6 ? 5 : 4.2, arch: wy == 6 || wy == 28) }
            }
            var pc = Path()
            for y in [12.0, 18.9, 25.4] { pc.addRect(R(a, y, b, y + 0.9)) }
            pc.addRect(R(a - 0.6, 37.6, b + 0.6, 39.4))
            ctx.fill(pc, with: .color(AH.cream))
            // pavilion mansard
            var pr = Path()
            pr.move(to: P(a - 0.8, 39.4)); pr.addLine(to: P(b + 0.8, 39.4)); pr.addLine(to: P(b - 2.2, 48)); pr.addLine(to: P(a + 2.2, 48)); pr.closeSubpath()
            ctx.fill(pr, with: vgrad(AH.raspberry, AH.raspberryDeep, 48, 39.4))
            ctx.fill(Path(ellipseIn: R((a + b) / 2 - 1.8, 41.6, (a + b) / 2 + 1.8, 45.2)), with: .color(AH.cream))
            ctx.fill(Path(ellipseIn: R((a + b) / 2 - 1.1, 42.3, (a + b) / 2 + 1.1, 44.5)), with: .color(AH.glass))
            ctx.fill(Path(R(a + 2, 47.6, b - 2, 48.6)), with: .color(AH.goldLight.opacity(0.9)))
            // cupola
            let m = (a + b) / 2
            ctx.fill(Path(R(m - 2.6, 48.6, m + 2.6, 52)), with: .color(AH.cream))
            ctx.fill(Path(R(m - 1.2, 49.2, m - 0.4, 51.4)), with: .color(AH.glass))
            ctx.fill(Path(R(m + 0.4, 49.2, m + 1.2, 51.4)), with: .color(AH.glass))
            var dome = Path()
            dome.move(to: P(m - 3, 52)); dome.addQuadCurve(to: P(m, 56.5), control: P(m - 3, 56)); dome.addQuadCurve(to: P(m + 3, 52), control: P(m + 3, 56)); dome.closeSubpath()
            ctx.fill(dome, with: hgrad(AH.raspberry, AH.raspberryDeep, m - 3, m + 3))
            var pole = Path(); pole.move(to: P(m, 56.5)); pole.addLine(to: P(m, 61.5))
            ctx.stroke(pole, with: .color(AH.goldDeep), lineWidth: hair)
            var flag = Path(); flag.move(to: P(m, 61.5)); flag.addLine(to: P(m + sgn * 4.2, 60.4)); flag.addLine(to: P(m, 59.3)); flag.closeSubpath()
            ctx.fill(flag, with: .color(sgn < 0 ? AH.raspberry : Color(hex: 0x86A9D8)))
        }
        // pavilion cast shadow onto the recessed main block (left one only: light from the upper left)
        ctx.fill(Path(R(-34, 3, -31.6, 31.6)), with: .color(AH.plum.opacity(0.16)))
        ctx.fill(Path(R(33.2, 3, 34, 39)), with: .color(AH.plum.opacity(0.12)))

        // Central clock tower
        ctx.fill(Path(R(-10.5, 3, 10.5, 50)), with: hgrad(AH.pinkLight, AH.pink, -10.5, 10.5))
        var tq = Path()
        for k in stride(from: 4.0, to: 48.0, by: 2.6) {
            let wq: CGFloat = Int(k) % 2 == 0 ? 2.0 : 1.3
            tq.addRect(R(-10.5, k, -10.5 + wq, k + 1.8))
            tq.addRect(R(10.5 - wq, k, 10.5, k + 1.8))
        }
        ctx.fill(tq, with: .color(AH.cream.opacity(0.9)))
        for wx in [-4.6, 0.0, 4.6] {
            window(wx, 16, 2.6, 5.4, arch: true, lit: wx == 0)
            window(wx, 25, 2.6, 5.0, arch: true)
        }
        var bal = Path()
        bal.addRect(R(-8.5, 22.2, 8.5, 23))
        for bx in stride(from: -8.0, through: 8.0, by: 1.0) { bal.addRect(R(bx - 0.18, 23, bx + 0.18, 24.2)) }
        bal.addRect(R(-8.5, 24.1, 8.5, 24.6))
        ctx.fill(bal, with: .color(AH.cream))
        // entrance and striped scalloped awning
        let door = R(-3.8, 3, 3.8, 11.2)
        ctx.fill(UnevenRoundedRectangle(cornerRadii: .init(topLeading: door.width / 2, topTrailing: door.width / 2)).path(in: door), with: .color(AH.glass))
        ctx.fill(Path(R(-2.8, 3, 2.8, 8.6)), with: .color(AH.raspberryDeep))
        ctx.fill(Path(R(-0.12, 3, 0.12, 8.6)), with: .color(AH.goldLight))
        var awn = Path(), stripes = Path()
        awn.move(to: P(-5.2, 13.6)); awn.addLine(to: P(5.2, 13.6)); awn.addLine(to: P(6.6, 10.8))
        let scal = 6
        for i in 0..<scal {
            let xa = 6.6 - 13.2 * CGFloat(i) / CGFloat(scal), xb = 6.6 - 13.2 * CGFloat(i + 1) / CGFloat(scal)
            awn.addQuadCurve(to: P(xb, 10.8), control: P((xa + xb) / 2, 9.4))
        }
        awn.closeSubpath()
        for i in 0..<scal where i % 2 == 0 {
            let xa = -6.6 + 13.2 * CGFloat(i) / CGFloat(scal), xb = -6.6 + 13.2 * CGFloat(i + 1) / CGFloat(scal)
            var st = Path(); st.move(to: P(xa * 0.79, 13.6)); st.addLine(to: P(xb * 0.79, 13.6)); st.addLine(to: P(xb, 9)); st.addLine(to: P(xa, 9)); st.closeSubpath()
            stripes.addPath(st)
        }
        ctx.fill(awn, with: .color(AH.cream))
        var aw = ctx
        aw.clip(to: awn)
        aw.fill(stripes, with: .color(AH.raspberry))
        ctx.fill(Path(R(-6.8, 10.2, 6.8, 10.8)).offsetBy(dx: 0, dy: 1.2 * u), with: .color(AH.plum.opacity(0.18)))
        // clock
        let clock = R(-5.4, 37.4, 5.4, 48.2)
        ctx.fill(Path(ellipseIn: clock.insetBy(dx: -0.9 * u, dy: -0.9 * u)), with: .color(AH.gold))
        ctx.fill(Path(ellipseIn: clock), with: .radialGradient(Gradient(colors: [AH.cream, Color(hex: 0xF1E0C8)]),
                                                                 center: CGPoint(x: clock.midX - clock.width * 0.15, y: clock.midY - clock.height * 0.15),
                                                                 startRadius: 0, endRadius: clock.width * 0.7))
        var ticks = Path()
        for k in 0..<12 {
            let a = Double(k) / 12 * 2 * .pi
            let c = CGPoint(x: clock.midX, y: clock.midY)
            let r0 = clock.width * 0.38, r1 = clock.width * 0.46
            ticks.move(to: CGPoint(x: c.x + CGFloat(sin(a)) * r0, y: c.y - CGFloat(cos(a)) * r0))
            ticks.addLine(to: CGPoint(x: c.x + CGFloat(sin(a)) * r1, y: c.y - CGFloat(cos(a)) * r1))
        }
        ctx.stroke(ticks, with: .color(AH.plum), lineWidth: hair * 0.8)
        var hands = Path()
        let cc = CGPoint(x: clock.midX, y: clock.midY)
        for (frac, len) in [((9.0 + 41.0 / 60) / 12, 0.24), (41.0 / 60, 0.36)] {
            let a = frac * 2 * .pi
            hands.move(to: cc)
            hands.addLine(to: CGPoint(x: cc.x + CGFloat(sin(a)) * clock.width * len, y: cc.y - CGFloat(cos(a)) * clock.width * len))
        }
        ctx.stroke(hands, with: .color(AH.plum), style: StrokeStyle(lineWidth: hair * 1.2, lineCap: .round))
        // cornice, drum, bell dome, lantern, pennant
        ctx.fill(Path(R(-11.6, 49.4, 11.6, 51.4)), with: .color(AH.cream))
        ctx.fill(Path(R(-11.6, 49, 11.6, 49.4)), with: .color(AH.pinkDeep))
        ctx.fill(Path(R(-7.6, 51.4, 7.6, 57.4)), with: hgrad(AH.cream, Color(hex: 0xEAD7C4), -7.6, 7.6))
        var cols = Path()
        for k in stride(from: -6.0, through: 6.0, by: 3.0) { cols.addRect(R(k - 0.9, 52, k + 0.9, 56.8)) }
        ctx.fill(cols, with: .color(AH.glass.opacity(0.85)))
        ctx.fill(Path(R(-8.4, 57.2, 8.4, 58.4)), with: .color(AH.cream))
        var bell = Path()
        bell.move(to: P(-8, 58.4))
        bell.addCurve(to: P(0, 73), control1: P(-9.2, 64), control2: P(-2.2, 67.5))
        bell.addCurve(to: P(8, 58.4), control1: P(2.2, 67.5), control2: P(9.2, 64))
        bell.closeSubpath()
        ctx.fill(bell, with: hgrad(Color(hex: 0xD0577B), AH.raspberryDeep, -6, 8))
        var ribs = Path()
        for k in [-4.0, 0.0, 4.0] { ribs.move(to: P(k * 1.6, 58.4)); ribs.addQuadCurve(to: P(0, 73), control: P(k * 1.4, 66)) }
        ctx.stroke(ribs, with: .color(AH.goldLight.opacity(0.85)), lineWidth: hair * 0.8)
        var shine = Path()
        shine.move(to: P(-6.2, 60)); shine.addQuadCurve(to: P(-2.4, 68), control: P(-6.4, 65))
        ctx.stroke(shine, with: .color(Color.white.opacity(0.45)), style: StrokeStyle(lineWidth: hair * 1.4, lineCap: .round))
        ctx.fill(Path(R(-1.8, 72.4, 1.8, 76)), with: .color(AH.cream))
        ctx.fill(Path(ellipseIn: R(-2, 75.4, 2, 78)), with: .color(AH.gold))
        var mast = Path(); mast.move(to: P(0, 78)); mast.addLine(to: P(0, 86))
        ctx.stroke(mast, with: .color(AH.goldDeep), lineWidth: hair)
        var pennant = Path(); pennant.move(to: P(0, 86)); pennant.addQuadCurve(to: P(8, 84.2), control: P(4, 84.4)); pennant.addQuadCurve(to: P(0, 82.4), control: P(4, 82.6)); pennant.closeSubpath()
        ctx.fill(pennant, with: .color(AH.raspberry))
        // tower cast shadow on the main block and roof to its right
        ctx.fill(Path(R(10.5, 3, 13.8, 41)), with: .color(AH.plum.opacity(0.17)))

        // windows, all at once
        ctx.fill(glass, with: .linearGradient(Gradient(colors: [Color(hex: 0x3C2040), AH.glass]), startPoint: P(0, 40), endPoint: P(0, 3)))
        ctx.fill(glow, with: .color(grey ? Color(hex: 0xFFE08A) : AH.butter))
        ctx.fill(lintels, with: .color(Color.black.opacity(0.22)))
        ctx.fill(sills, with: .color(AH.cream))

        // terrace balustrade along the front
        var rail = Path()
        rail.addRect(R(-53, 0, 53, 0.8))
        rail.addRect(R(-53, 2.6, 53, 3.4))
        for bx in stride(from: -52.5, through: 52.5, by: 1.5) { rail.addRect(R(bx - 0.25, 0.8, bx + 0.25, 2.6)) }
        ctx.fill(rail, with: .color(AH.cream))
        ctx.fill(Path(R(-53, -0.6, 53, 0)), with: .color(AH.plum.opacity(0.25)))
    }
}
