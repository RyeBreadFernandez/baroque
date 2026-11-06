import SwiftUI

// The painted set behind every widget: the app's brushed sky (PaintedSky's construction, a pastel SkyPalette that
// follows SkyClock and SkyCondition), layered ridges built like MountainRange (RidgeProfile, SnowShape, TreeLine and
// a brush relief per layer) recoloured to the hotel palette, and the hotel itself painted on its rock ledge. Units are
// fractions of the scene's frame, as in Landscape.swift, so the art lines up with the props laid over it.

// MARK: - Sky palette

/// The hotel's sky through the day: powder blue and blush by day, rose and apricot at sunrise and sunset, lilac and
/// indigo at night; greyed toward lavender when the weather closes in.
enum GHSkyPalette {
    private struct RGB {
        var r, g, b: Double
        init(_ hex: UInt32) {
            r = Double((hex >> 16) & 0xFF) / 255; g = Double((hex >> 8) & 0xFF) / 255; b = Double(hex & 0xFF) / 255
        }
        func mixed(_ o: RGB, _ t: Double) -> RGB {
            var m = self
            m.r += (o.r - r) * t; m.g += (o.g - g) * t; m.b += (o.b - b) * t
            return m
        }
        var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
    }

    static func make(clock: SkyClock, condition: SkyCondition) -> SkyPalette {
        var top = clock.isDay ? RGB(0x6E9ED2) : RGB(0x16142F)
        var mid = clock.isDay ? RGB(0xA9CAEA) : RGB(0x2B2452)
        var horizon = clock.isDay ? RGB(0xF7D9E0) : RGB(0x574273)
        var ground = clock.isDay ? RGB(0xCFE8D9) : RGB(0x1F1B35)
        if condition.gray {
            top = top.mixed(clock.isDay ? RGB(0x9198BA) : RGB(0x1E1D2E), 0.7)
            mid = mid.mixed(clock.isDay ? RGB(0xB5B6D2) : RGB(0x2E2C42), 0.7)
            horizon = horizon.mixed(clock.isDay ? RGB(0xDCCFDD) : RGB(0x4A4259), 0.7)
            ground = ground.mixed(RGB(0xBFCBC8), clock.isDay ? 0.5 : 0)
        }
        // Rose and apricot low in the sky around sunrise and sunset.
        let tw = clock.twilight
        horizon = horizon.mixed(RGB(0xF5A988), 0.8 * tw)
        mid = mid.mixed(RGB(0xE39AB6), 0.6 * tw)
        top = top.mixed(clock.isDay ? RGB(0x8C82C4) : RGB(0x3B2F66), 0.45 * tw)
        var p = SkyPalette.evening
        p.top = top.color
        p.mid = mid.color
        p.horizon = horizon.color
        p.ground = ground.color
        return p
    }
}

/// A relief overlay from the hotel's textures, stretched over what it decorates (as PaintRelief).
struct GHRelief: View {
    var image: Image
    var opacity: Double
    var flip = false

    var body: some View {
        Color.clear
            .overlay {
                image
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .scaleEffect(x: flip ? -1 : 1, y: 1)
            }
            .opacity(opacity)
            .clipped()
            .allowsHitTesting(false)
    }
}

/// PaintedSky's construction: a graded wash laid in with long brush strokes, on canvas. By day the strokes carry
/// lavender shadows; at night the shipped PaintSky relief is used as it is.
struct GHPaintedSky: View {
    var palette: SkyPalette
    var horizon: CGFloat
    var night: Bool

    var body: some View {
        LinearGradient(stops: [
            .init(color: palette.top, location: 0),
            .init(color: palette.mid, location: horizon * 0.6),
            .init(color: palette.horizon, location: horizon),
            .init(color: palette.ground, location: min(1, horizon + 0.22))
        ], startPoint: .top, endPoint: .bottom)
        .overlay {
            if night { PaintRelief(name: "PaintSky", opacity: 0.95) } else { GHRelief(image: GHTex.skyRelief, opacity: 0.95) }
        }
        .overlay(CanvasWeave(opacity: 0.6))
    }
}

// MARK: - Ridges

/// One ridge of the set: MountainLayer plus the colour of its spruce (pines on mint hills are darker than the hill).
struct GHLayer {
    var profile: RidgeProfile
    var top: Color
    var bottom: Color
    var rim: Double = 0.5
    var snowline: CGFloat? = nil
    var trees: Trees? = nil
    var treeColor: Color? = nil
}

/// MountainRange in the hotel palette: each ridge filled, snowcapped, brushed with the ridge relief, crested with
/// spruce and a lit rim, and lifted off the one behind by a soft plum shadow, like cut paper.
struct GHMountainRange: View {
    var layers: [GHLayer]
    var night: Bool
    var snowLower: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(layers.indices, id: \.self) { i in
                layerView(layers[i], index: i)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func layerView(_ layer: GHLayer, index: Int) -> some View {
        let ridge = RidgeShape(profile: layer.profile)
        let rimColor = night ? Color(hex: 0xDCD6F2) : Color(hex: 0xFFF3E6)
        return ZStack {
            ridge.fill(LinearGradient(colors: [layer.top, layer.bottom], startPoint: .top, endPoint: .bottom))
            if let line = layer.snowline {
                SnowShape(profile: layer.profile, snowline: line + snowLower)
                    .fill(LinearGradient(colors: night ? [Color(hex: 0xCFCBE6), Color(hex: 0x8A82AE)] : [Color(hex: 0xFFFBF6), Color(hex: 0xD5CDEB)],
                                         startPoint: .top, endPoint: .bottom))
            }
            Group {
                if night {
                    PaintRelief(name: "PaintRidge", opacity: 0.75, flip: index % 2 == 1)
                } else {
                    GHRelief(image: GHTex.ridgeRelief, opacity: 1, flip: index % 2 == 1)
                }
            }
            .offset(y: CGFloat(index) * 23)
            .clipShape(ridge)
            if let trees = layer.trees {
                TreeLine(profile: layer.profile, trees: trees)
                    .fill(layer.treeColor ?? layer.top)
                    .overlay(TreeLine(profile: layer.profile, trees: trees).stroke(rimColor.opacity(layer.rim * 0.4), lineWidth: 0.5))
            }
            RidgeShape(profile: layer.profile, closed: false)
                .stroke(rimColor.opacity(layer.rim), style: StrokeStyle(lineWidth: 0.9, lineJoin: .round))
                .blur(radius: 0.3)
            if night {
                ridge.fill(Color(hex: 0x15123A).opacity(0.42))
            }
        }
        .compositingGroup()
        .shadow(color: GH.shadow.opacity(night ? 0.55 : 0.32), radius: 3, x: 0, y: -1.2)
    }
}

/// The hotel palette's ridge colours, far to near.
enum GHRidgeColors {
    static let far = (top: Color(hex: 0xD3C8EA), bottom: Color(hex: 0xB1A5D5))
    static let peak = (top: Color(hex: 0xEDB5C8), bottom: Color(hex: 0xBD90B4))
    static let hill = (top: Color(hex: 0xA9D8C1), bottom: Color(hex: 0x82BFA5))
    static let near = (top: Color(hex: 0x7DBDA3), bottom: Color(hex: 0x4E8F7C))
}

// MARK: - Clouds and weather

/// A billowing cloud in the hotel's sky (PaintedCloud's construction): shaded body brushed with the sky relief, the
/// upper rim lit by the sun or moon.
struct GHCloud: View {
    var night: Bool
    var gray: Bool
    var seed: Int = 0

    var body: some View {
        let colors: [Color] = night ? [Color(hex: 0x5D5282), Color(hex: 0x2F2852)]
            : (gray ? [Color(hex: 0xD6D0E2), Color(hex: 0x9F98B8)] : [Color(hex: 0xFFF8F4), Color(hex: 0xE0CFE6)])
        let rim = night ? Stone.moonlight : Color(hex: 0xFFF6E0)
        CloudShape()
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay(GHRelief(image: GHTex.skyRelief, opacity: 0.9, flip: seed % 2 == 1).clipShape(CloudShape()))
            .overlay(
                CloudShape()
                    .stroke(LinearGradient(colors: [rim.opacity(gray ? 0.5 : 0.9), rim.opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)),
                            lineWidth: 2.2)
                    .blur(radius: 0.5)
                    .clipShape(CloudShape())
            )
            .shadow(color: GH.shadow.opacity(0.3), radius: 2.5, x: 0, y: 1.5)
    }
}

/// Rain, snow, a bolt or fog banks over the sky, batched in one Canvas.
struct GHWeatherFront: View {
    var condition: SkyCondition
    var night: Bool
    var region: CGRect // unit coordinates of the scene
    /// Fraction of the usual rain or snow to draw (1 = Grand Hotel's density).
    var density: CGFloat = 1

    var body: some View {
        Canvas { ctx, size in
            let u = size.width / 348
            let r = CGRect(x: region.minX * size.width, y: region.minY * size.height,
                           width: region.width * size.width, height: region.height * size.height)
            var rng = SeededRandom(23)
            switch condition {
            case .rain, .storm:
                var p = Path()
                let count = Int(r.width * r.height / (230 * u * u) * density) + 4
                for _ in 0..<count {
                    let x = r.minX + CGFloat(rng.next()) * r.width
                    let y = r.minY + CGFloat(rng.next()) * r.height
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - 2.4 * u, y: y + 8 * u))
                }
                ctx.stroke(p, with: .color(night ? Color(hex: 0xB9B3DA).opacity(0.55) : Color(hex: 0xF4F1FB).opacity(0.8)),
                           style: StrokeStyle(lineWidth: 1.1 * max(u, 0.6), lineCap: .round))
                ctx.stroke(p.offsetBy(dx: 0.6, dy: 0.8), with: .color(Color(hex: 0x6B5A98).opacity(0.25)),
                           style: StrokeStyle(lineWidth: 0.8 * max(u, 0.6), lineCap: .round))
                if condition == .storm {
                    var bolt = Path()
                    let b = CGPoint(x: r.minX + r.width * 0.7, y: r.minY + r.height * 0.15)
                    bolt.move(to: b)
                    bolt.addLine(to: CGPoint(x: b.x - 5 * u, y: b.y + 11 * u))
                    bolt.addLine(to: CGPoint(x: b.x - 1 * u, y: b.y + 11 * u))
                    bolt.addLine(to: CGPoint(x: b.x - 4 * u, y: b.y + 21 * u))
                    bolt.addLine(to: CGPoint(x: b.x + 4 * u, y: b.y + 8 * u))
                    bolt.addLine(to: CGPoint(x: b.x, y: b.y + 8 * u))
                    bolt.closeSubpath()
                    var g = ctx
                    g.addFilter(.blur(radius: 3 * u))
                    g.fill(bolt, with: .color(Stone.goldBright.opacity(0.8)))
                    ctx.fill(bolt, with: .color(Stone.goldBright))
                }
            case .snow:
                var flakes = Path(), glow = Path()
                let count = Int(r.width * r.height / (160 * u * u) * density) + 5
                for _ in 0..<count {
                    let x = r.minX + CGFloat(rng.next()) * r.width
                    let y = r.minY + CGFloat(rng.next()) * r.height
                    let s = (0.7 + CGFloat(rng.next()) * 0.8) * max(u, 0.6)
                    flakes.addEllipse(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2))
                    glow.addEllipse(in: CGRect(x: x - s * 1.8, y: y - s * 1.8, width: s * 3.6, height: s * 3.6))
                }
                ctx.fill(glow, with: .color(Color.white.opacity(0.12)))
                ctx.fill(flakes.offsetBy(dx: 0.4, dy: 0.6), with: .color(Color(hex: 0x6B5A98).opacity(0.3)))
                ctx.fill(flakes, with: .color(Color(hex: 0xFFFDFB)))
            case .fog:
                var g = ctx
                g.addFilter(.blur(radius: 3 * u))
                for i in 0..<3 {
                    let y = r.maxY - CGFloat(i) * 10 * u - 4 * u
                    let w = r.width * (0.6 + 0.12 * CGFloat(i))
                    g.fill(Path(roundedRect: CGRect(x: r.midX - w / 2 + CGFloat(i) * 12 * u, y: y, width: w, height: 6 * u), cornerRadius: 3 * u),
                           with: .color(Color(hex: night ? 0x8C84AE : 0xF4EEF6).opacity(0.6)))
                }
            default:
                break
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - The set

/// Where the hotel stands in a scene.
struct GHHotelSpec {
    var cx: CGFloat = 0.5       // fraction of the width
    var base: CGFloat           // fraction of the height: the terrace it stands on
    var width: CGFloat          // points
    var ledgeBottom: CGFloat    // fraction of the height
    var funicular = true
    var cableCars: CGFloat? = nil // wire height, fraction of the height
    /// Fewer windows, one pennant, no slates, cresting, dormers, balcony or sparkles, and a bare ledge: the hotel as it
    /// reads at widget scale (Grand Hotel Calm).
    var simple = false
}

/// Everything a scene needs; the props are laid over it by the widget.
struct GHSceneSpec {
    var now: Date
    var weather: WeatherSnapshot? = nil
    var horizon: CGFloat
    var back: [GHLayer]
    var front: [GHLayer] = []
    var hotel: GHHotelSpec? = nil
    var arc: SkyArc
    var bodyRadius: CGFloat = 9
    /// Puts the sun or moon at a fixed point (unit coordinates) instead of on the arc.
    var bodyAt: CGPoint? = nil
    var showsBody = true
    var trail = false
    var stars: CGRect
    var starCount = 12
    var mist: CGFloat? = nil      // fraction of the height where valley mist lies
    var weatherRegion: CGRect = CGRect(x: 0, y: 0, width: 1, height: 0.4)
    /// Fraction of the usual rain or snow (GHWeatherFront.density).
    var weatherDensity: CGFloat = 1
}

struct GHScene: View {
    var spec: GHSceneSpec

    var body: some View {
        let clock = SkyClock(now: spec.now, weather: spec.weather)
        let condition = SkyCondition(code: spec.weather?.code)
        let night = !clock.isDay
        let phase = MoonPhase(date: spec.now)
        GHPaintedSky(palette: GHSkyPalette.make(clock: clock, condition: condition), horizon: spec.horizon, night: night)
            .overlay {
                if night && !condition.gray {
                    Stars(region: spec.stars, count: spec.starCount, sparkles: max(1, spec.starCount / 5), seed: 5)
                }
            }
            .overlay {
                GeometryReader { geo in
                    let size = geo.size
                    let u = size.width / 348
                    let pt = spec.bodyAt.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) } ?? spec.arc.point(clock.progress, in: size)
                    ZStack(alignment: .topLeading) {
                        // Light from the sun or moon spreading through the sky around it.
                        Circle()
                            .fill(RadialGradient(colors: [(night ? Stone.moonlight : Color(hex: 0xFFF0C8)).opacity(condition.gray ? 0.12 : 0.35), .clear],
                                                 center: .center, startRadius: 0, endRadius: 70 * u))
                            .frame(width: 140 * u, height: 140 * u)
                            .position(pt)
                        if spec.trail { ArcTrail(arc: spec.arc).opacity(0.8) }
                        if spec.showsBody {
                            Group {
                                if night {
                                    MoonDisc(radius: spec.bodyRadius * u, phase: phase).opacity(condition.gray ? 0.6 : 1)
                                } else {
                                    SunDisc(radius: spec.bodyRadius * u).opacity(condition.gray ? 0.55 : 1)
                                }
                            }
                            .position(pt)
                        }
                        ForEach(Array(SkyLayout.clouds(condition, clock: clock, arc: spec.arc, size: size).enumerated()), id: \.offset) { i, c in
                            GHCloud(night: night, gray: condition.gray, seed: i)
                                .frame(width: c.width, height: c.width * 0.55)
                                .position(c.center)
                        }
                    }
                }
            }
            .overlay(GHMountainRange(layers: spec.back, night: night, snowLower: condition == .snow ? 0.03 : 0))
            .overlay {
                if let mist = spec.mist { GHMist(at: mist, night: night) }
            }
            .overlay {
                if let hotel = spec.hotel {
                    Canvas { ctx, size in
                        GHHotel.paintSet(ctx, size: size, spec: hotel, light: GHLight(clock: clock, condition: condition), now: spec.now)
                    }
                }
            }
            .overlay(GHMountainRange(layers: spec.front, night: night, snowLower: condition == .snow ? 0.03 : 0))
            .overlay(GHWeatherFront(condition: condition, night: night, region: spec.weatherRegion, density: spec.weatherDensity))
    }
}

/// Valley haze: a soft band of blush (lilac at night) where the hills meet.
struct GHMist: View {
    var at: CGFloat
    var night: Bool

    var body: some View {
        let haze = night ? Color(hex: 0x8D82B5) : Color(hex: 0xFBEAF0)
        LinearGradient(stops: [
            .init(color: haze.opacity(0), location: max(0, at - 0.07)),
            .init(color: haze.opacity(night ? 0.3 : 0.55), location: at),
            .init(color: haze.opacity(0), location: min(1, at + 0.07))
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }
}

// MARK: - The hotel

/// How the set is lit: 0 by day to 1 at night, the sunrise/sunset warmth, and grey weather.
struct GHLight {
    var night: Double
    var twilight: Double
    var gray: Bool

    init(clock: SkyClock, condition: SkyCondition) {
        night = clock.isDay ? 0 : 1
        twilight = clock.twilight
        gray = condition.gray
    }

    /// Windows lit after dark, at dusk, and on grey days.
    var lamps: Double { max(night, twilight * 0.8, gray ? 0.5 : 0) }
}

enum GHHotel {
    /// The rock ledge, the funicular, cable cars and the hotel, in one pass.
    static func paintSet(_ ctx: GraphicsContext, size: CGSize, spec: GHHotelSpec, light: GHLight, now: Date) {
        let cx = spec.cx * size.width
        let base = spec.base * size.height
        let u = spec.width / 108
        if let wire = spec.cableCars {
            cableCars(ctx, size: size, y: wire * size.height, u: u, light: light)
        }
        ledge(ctx, cx: cx, top: base, bottom: spec.ledgeBottom * size.height, halfTop: 56 * u, halfBottom: 80 * u, u: u, light: light, simple: spec.simple)
        if spec.funicular {
            funicular(ctx, cx: cx, top: base + 1 * u, bottom: spec.ledgeBottom * size.height, u: u, light: light)
        }
        hotel(ctx, cx: cx, base: base, u: u, light: light, now: now, simple: spec.simple)
    }

    // MARK: Ledge

    static func ledge(_ ctx: GraphicsContext, cx: CGFloat, top: CGFloat, bottom: CGFloat, halfTop: CGFloat, halfBottom: CGFloat, u: CGFloat, light: GHLight,
                      simple: Bool = false) {
        var rng = SeededRandom(71)
        var left: [CGPoint] = [], right: [CGPoint] = []
        let n = 7
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let y = top + (bottom - top) * t
            let half = halfTop + (halfBottom - halfTop) * pow(t, 0.6)
            let jl = i == 0 ? 0 : CGFloat(rng.signed()) * 0.06 * halfTop
            let jr = i == 0 ? 0 : CGFloat(rng.signed()) * 0.06 * halfTop
            left.append(CGPoint(x: cx - half + jl, y: y))
            right.append(CGPoint(x: cx + half + jr, y: y))
        }
        var body = Path()
        body.move(to: CGPoint(x: left[0].x - halfTop * 0.05, y: top - 1.2 * u))
        body.addLine(to: CGPoint(x: right[0].x + halfTop * 0.05, y: top - 1.2 * u))
        right.forEach { body.addLine(to: $0) }
        left.reversed().forEach { body.addLine(to: $0) }
        body.closeSubpath()

        // shadow cast down the slope behind
        var sh = ctx
        sh.addFilter(.blur(radius: 4 * u))
        sh.fill(body.offsetBy(dx: 3 * u, dy: 2 * u), with: .color(GH.shadow.opacity(0.3)))

        ctx.fill(body, with: .linearGradient(Gradient(colors: [Color(hex: 0xF6CDBE), Color(hex: 0xEDB2B4), Color(hex: 0xC897B4)]),
                                             startPoint: CGPoint(x: cx, y: top), endPoint: CGPoint(x: cx, y: bottom)))
        var l = ctx
        l.clip(to: body)
        // the face turned from the light: right of a jagged spine
        var face = Path()
        var spine: [CGPoint] = []
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            spine.append(CGPoint(x: cx + halfTop * 0.32 + (halfBottom - halfTop) * 0.45 * t + CGFloat(rng.signed()) * 0.05 * halfTop,
                                 y: top + (bottom - top) * t))
        }
        face.move(to: spine[0])
        spine.dropFirst().forEach { face.addLine(to: $0) }
        face.addLine(to: CGPoint(x: right[n].x + 10, y: bottom))
        face.addLine(to: CGPoint(x: right[0].x + 10, y: top))
        face.closeSubpath()
        l.fill(face, with: .color(Color(hex: 0x9A5F8E).opacity(0.26)))
        // brushwork
        var rel = l
        rel.opacity = 0.7
        rel.draw(rel.resolve(GHTex.ridgeRelief), in: CGRect(x: cx - halfBottom, y: top - 4, width: halfBottom * 2, height: (bottom - top) * 2.2))
        // cliff columns: lit slivers and shadow cracks
        var lights = Path(), cracks = Path()
        let cols = max(5, Int(halfTop / (8 * max(u, 0.6))))
        for k in 0...cols {
            let t = CGFloat(k) / CGFloat(cols)
            var xt = cx - halfTop + 2 * halfTop * t + CGFloat(rng.signed()) * 0.04 * halfTop
            var xb = cx - halfBottom + 2 * halfBottom * t + CGFloat(rng.signed()) * 0.06 * halfBottom
            if abs(xt - cx) < halfTop * 0.12 { xt += halfTop * 0.16; xb += halfTop * 0.2 } // keep the track clear
            let cw = halfTop * CGFloat(0.03 + rng.next() * 0.04)
            var crack = Path(), sliver = Path()
            crack.move(to: CGPoint(x: xt, y: top + 2 * u))
            crack.addLine(to: CGPoint(x: xb, y: bottom))
            crack.addLine(to: CGPoint(x: xb + cw * 1.6, y: bottom))
            crack.addLine(to: CGPoint(x: xt + cw * 0.6, y: top + 2 * u))
            crack.closeSubpath()
            sliver.move(to: CGPoint(x: xt - cw * 1.4, y: top + 2 * u))
            sliver.addLine(to: CGPoint(x: xb - cw * 2.2, y: bottom))
            sliver.addLine(to: CGPoint(x: xb, y: bottom))
            sliver.addLine(to: CGPoint(x: xt, y: top + 2 * u))
            sliver.closeSubpath()
            cracks.addPath(crack)
            lights.addPath(sliver)
        }
        l.fill(lights, with: .color(Color(hex: 0xFFE6D6).opacity(0.32)))
        l.fill(cracks, with: .color(Color(hex: 0x8A4F7E).opacity(0.3)))
        // snow shelves with small spruce
        var shelves = Path(), pines = Path()
        var y = top + (bottom - top) * 0.25
        while !simple && y < bottom - 3 * u {
            for side in [CGFloat(-1), 1] {
                let f = (y - top) / max(1, bottom - top)
                let half = halfTop + (halfBottom - halfTop) * pow(f, 0.6)
                let x0 = cx + side * half * CGFloat(0.4 + rng.next() * 0.4)
                let len = half * CGFloat(0.1 + rng.next() * 0.12)
                let th = max(1, 1.6 * u)
                shelves.addEllipse(in: CGRect(x: x0 - len / 2, y: y - th / 2, width: len, height: th))
                if rng.next() < 0.75 {
                    pines.addPath(TreeLine.spruce(x: x0 + CGFloat(rng.signed()) * len * 0.3, base: y, height: max(4, 7 * u * CGFloat(0.7 + rng.next() * 0.6))))
                }
            }
            y += (bottom - top) * CGFloat(0.18 + rng.next() * 0.08)
        }
        l.fill(shelves.offsetBy(dx: 0, dy: 0.8), with: .color(Color(hex: 0x6E3F68).opacity(0.3)))
        l.fill(shelves, with: .color(Color(hex: 0xFFFBF6).opacity(0.9)))
        l.fill(pines, with: .color(GH.pine))
        l.stroke(pines, with: .color(Color(hex: 0xFFF3E6).opacity(0.25)), lineWidth: 0.4)
        // the lit left edge
        var edge = Path()
        edge.move(to: left[0])
        left.dropFirst().prefix(4).forEach { edge.addLine(to: $0) }
        l.stroke(edge, with: .color(Color(hex: 0xFFEADB).opacity(0.75)), lineWidth: max(0.8, 1.4 * u))
        if light.night > 0 { l.fill(body, with: .color(Color(hex: 0x15123A).opacity(0.45 * light.night))) }
        if light.twilight > 0 { l.fill(body, with: .color(Color(hex: 0xF5A988).opacity(0.14 * light.twilight))) }
        // snow lip along the terrace edge, with drips
        var snow = Path()
        let x0 = left[0].x - halfTop * 0.06, x1 = right[0].x + halfTop * 0.06
        snow.move(to: CGPoint(x: x0, y: top - 1.8 * u))
        snow.addLine(to: CGPoint(x: x1, y: top - 1.8 * u))
        var sx = x1
        while sx > x0 {
            let step = halfTop * CGFloat(0.06 + rng.next() * 0.06)
            let dip = halfTop * CGFloat(0.03 + rng.next() * 0.08)
            snow.addQuadCurve(to: CGPoint(x: max(x0, sx - step), y: top + 1.2 * u), control: CGPoint(x: sx - step / 2, y: top + dip))
            sx -= step
        }
        snow.closeSubpath()
        ctx.fill(snow, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFFDF9), Color(hex: 0xDCD3EE)]),
                                             startPoint: CGPoint(x: cx, y: top - 2 * u), endPoint: CGPoint(x: cx, y: top + 6 * u)))
        if light.night > 0 { ctx.fill(snow, with: .color(Color(hex: 0x15123A).opacity(0.35 * light.night))) }
    }

    // MARK: Funicular

    static func funicular(_ ctx: GraphicsContext, cx: CGFloat, top: CGFloat, bottom: CGFloat, u: CGFloat, light: GHLight) {
        let gauge = 2.4 * u
        var bed = Path()
        bed.move(to: CGPoint(x: cx - gauge * 1.3, y: top))
        bed.addLine(to: CGPoint(x: cx + gauge * 1.3, y: top))
        bed.addLine(to: CGPoint(x: cx + gauge * 2.6, y: bottom))
        bed.addLine(to: CGPoint(x: cx - gauge * 2.6, y: bottom))
        bed.closeSubpath()
        ctx.fill(bed, with: .color(Color(hex: 0x7E4F7A).opacity(0.55)))
        var ties = Path()
        var y = top + 1
        while y < bottom {
            let t = (y - top) / max(1, bottom - top)
            let half = gauge * (1.2 + 1.3 * t)
            ties.addRect(CGRect(x: cx - half, y: y, width: half * 2, height: max(0.5, 0.5 * u * (1 + t))))
            y += max(1.6, 2.2 * u * (1 + t * 1.2))
        }
        ctx.fill(ties, with: .color(Color(hex: 0x4E2A4A).opacity(0.7)))
        var rails = Path()
        for sgn in [CGFloat(-1), 1] {
            rails.move(to: CGPoint(x: cx + sgn * gauge * 0.8, y: top))
            rails.addLine(to: CGPoint(x: cx + sgn * gauge * 1.7, y: bottom))
        }
        ctx.stroke(rails, with: .color(GH.goldLight), lineWidth: max(0.5, 0.5 * u))
        ctx.stroke(rails.offsetBy(dx: 0.4, dy: 0.4), with: .color(GH.goldDeep.opacity(0.7)), lineWidth: max(0.4, 0.3 * u))
        // the car, part way down, seen head on
        let t: CGFloat = 0.45
        let cy = top + (bottom - top) * t
        let cw = gauge * (3.4 + 1.6 * t), ch = cw * 0.8
        let car = CGRect(x: cx - cw / 2, y: cy - ch, width: cw, height: ch)
        var sh = ctx
        sh.addFilter(.blur(radius: 1.2 * u))
        sh.fill(Path(ellipseIn: CGRect(x: car.minX, y: car.maxY - ch * 0.1, width: cw * 1.1, height: ch * 0.35)), with: .color(GH.shadow.opacity(0.45)))
        ctx.fill(Path(roundedRect: car, cornerRadius: cw * 0.18),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xD0587D), GH.raspberryDeep]),
                                       startPoint: CGPoint(x: car.minX, y: car.minY), endPoint: CGPoint(x: car.maxX, y: car.maxY)))
        let lit = light.lamps > 0.3
        ctx.fill(Path(roundedRect: CGRect(x: car.minX + cw * 0.14, y: car.minY + ch * 0.2, width: cw * 0.72, height: ch * 0.32), cornerRadius: cw * 0.05),
                 with: .color(lit ? GH.lamplight : Color(hex: 0xE9E2F4)))
        ctx.fill(Path(CGRect(x: car.minX + cw * 0.47, y: car.minY + ch * 0.2, width: cw * 0.06, height: ch * 0.32)), with: .color(GH.raspberryDeep))
        ctx.fill(Path(CGRect(x: car.minX, y: car.minY + ch * 0.64, width: cw, height: ch * 0.08)), with: .color(GH.cream))
        ctx.fill(Path(roundedRect: CGRect(x: car.minX - cw * 0.06, y: car.minY - ch * 0.1, width: cw * 1.12, height: ch * 0.15), cornerRadius: ch * 0.05),
                 with: .linearGradient(Gradient(colors: [GH.goldLight, GH.gold]), startPoint: CGPoint(x: 0, y: car.minY - ch * 0.1), endPoint: CGPoint(x: 0, y: car.minY + ch * 0.05)))
        ctx.stroke(Path(CGRect(x: car.minX + 0.4, y: car.minY + 0.4, width: 0.01, height: ch * 0.6)), with: .color(Color.white.opacity(0.5)), lineWidth: 0.6)
    }

    // MARK: Cable cars

    static func cableCars(_ ctx: GraphicsContext, size: CGSize, y y0: CGFloat, u: CGFloat, light: GHLight) {
        let sag = size.height * 0.05
        var wire = Path()
        wire.move(to: CGPoint(x: -4, y: y0))
        wire.addQuadCurve(to: CGPoint(x: size.width + 4, y: y0), control: CGPoint(x: size.width / 2, y: y0 + sag * 2))
        ctx.stroke(wire, with: .color(GH.plum.opacity(0.55)), lineWidth: 0.7)
        ctx.stroke(wire.offsetBy(dx: 0, dy: 1.8), with: .color(GH.plum.opacity(0.3)), lineWidth: 0.5)
        for (fx, color) in [(CGFloat(0.27), GH.raspberry), (0.73, Color(hex: 0x7C9FD0))] {
            let x = size.width * fx
            let t = fx
            let wy = y0 + sag * 2 * 2 * t * (1 - t)
            let cw = max(7, 9 * u), ch = cw * 0.82
            var hanger = Path()
            hanger.move(to: CGPoint(x: x, y: wy))
            hanger.addLine(to: CGPoint(x: x, y: wy + ch * 0.75))
            ctx.stroke(hanger, with: .color(GH.plum.opacity(0.75)), lineWidth: 0.7)
            let cab = CGRect(x: x - cw / 2, y: wy + ch * 0.75, width: cw, height: ch)
            var sh = ctx
            sh.addFilter(.blur(radius: 1.5))
            sh.fill(Path(roundedRect: cab.offsetBy(dx: 1, dy: 1.6), cornerRadius: cw * 0.2), with: .color(GH.shadow.opacity(0.3)))
            ctx.fill(Path(roundedRect: cab, cornerRadius: cw * 0.2),
                     with: .linearGradient(Gradient(colors: [color.opacity(0.85), color]), startPoint: CGPoint(x: cab.minX, y: cab.minY), endPoint: CGPoint(x: cab.maxX, y: cab.maxY)))
            ctx.fill(Path(roundedRect: CGRect(x: cab.minX + cw * 0.15, y: cab.minY + ch * 0.18, width: cw * 0.7, height: ch * 0.36), cornerRadius: 0.6),
                     with: .color(light.lamps > 0.3 ? GH.lamplight : GH.cream))
            ctx.fill(Path(CGRect(x: cab.minX - 0.6, y: cab.minY - 0.8, width: cw + 1.2, height: 1.3)), with: .color(GH.goldLight))
            ctx.stroke(Path(roundedRect: cab, cornerRadius: cw * 0.2), with: .color(Color.white.opacity(0.3)), lineWidth: 0.5)
            if light.night > 0 {
                ctx.fill(Path(roundedRect: cab, cornerRadius: cw * 0.2), with: .color(Color(hex: 0x15123A).opacity(0.3 * light.night)))
            }
        }
    }

    // MARK: Hotel

    /// An original pink grand hotel, symmetric and head-on: a long main block under a raspberry mansard, two taller end
    /// pavilions standing forward with cupolas, and a central clock tower with a bell dome and pennant. Lit from the
    /// upper left: faces turned from the light are shaded, the left pavilion and the tower cast shadows to the right,
    /// the walls carry painted plaster dabs, trim is gilt, and the windows glow after dark.
    static func hotel(_ ctx: GraphicsContext, cx: CGFloat, base: CGFloat, u: CGFloat, light: GHLight, now: Date, simple: Bool = false) {
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
        let gilt = GraphicsContext.Shading.linearGradient(Gradient(colors: [GH.goldLight, GH.gold, GH.goldDeep]), startPoint: P(0, 90), endPoint: P(0, 0))
        let hair = max(0.35, 0.5 * u)

        // Soft shadow on the terrace, falling to the lower right, and the contact shadow.
        var sh = ctx
        sh.addFilter(.blur(radius: 3 * u))
        sh.fill(Path(ellipseIn: R(-48, -5, 70, 3)), with: .color(GH.shadow.opacity(0.32)))
        var contact = ctx
        contact.addFilter(.blur(radius: 1 * u))
        contact.fill(Path(R(-52, -1.2, 54, 1)), with: .color(GH.shadow.opacity(0.35)))

        var walls = Path(), roofs = Path()
        var glass = Path(), lamps = Path(), sills = Path(), lintels = Path()
        var litIndex = 0
        func window(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ wh: CGFloat, arch: Bool = false) {
            let rect = R(x - ww / 2, y, x + ww / 2, y + wh)
            let p = arch ? UnevenRoundedRectangle(cornerRadii: .init(topLeading: rect.width / 2, topTrailing: rect.width / 2)).path(in: rect) : Path(rect)
            litIndex += 1
            // By day a few rooms have their lamps on; at dusk more; at night nearly all.
            let hash = (litIndex * 37 + 11) % 100
            let threshold = 12 + Int(light.lamps * 80)
            if hash < threshold { lamps.addPath(p) } else { glass.addPath(p) }
            sills.addRect(R(x - ww / 2 - 0.5, y - 0.8, x + ww / 2 + 0.5, y))
            lintels.addRect(R(x - ww / 2, y + wh - 0.7, x + ww / 2, y + wh))
        }

        // Main block
        let main = Path(R(-35, 3, 35, 34))
        walls.addPath(main)
        ctx.fill(main, with: hgrad(GH.pinkLight, GH.pink, -35, 35))
        if simple {
            // three bays a side, three floors: the rhythm without the count
            for spec in [(6.0, 5.0, true), (14.0, 4.2, false), (20.6, 4.2, false)] {
                for x in [-30.0, -24.0, -18.0, 18.0, 24.0, 30.0] { window(x, spec.0, spec.2 ? 3.2 : 2.8, spec.1, arch: spec.2) }
            }
        } else {
            for (row, spec) in [(6.0, 5.0, true), (14.0, 4.2, false), (20.6, 4.2, false), (27.0, 3.6, false)].enumerated() {
                var x: CGFloat = -31.5
                while x <= 31.6 {
                    if abs(x) > 12 { window(x, spec.0, spec.2 ? 3.0 : 2.5, spec.1, arch: spec.2) }
                    x += 4.5
                }
                _ = row
            }
        }
        var courses = Path()
        for y in [12.0, 18.9, 25.4] { courses.addRect(R(-35, y, 35, y + 0.9)) }
        ctx.fill(courses, with: .color(GH.cream))
        ctx.fill(Path(R(-35, 32.4, 35, 34.2)), with: .color(GH.cream))
        ctx.fill(Path(R(-35, 31.8, 35, 32.4)), with: .color(GH.pinkDeep))

        // Main mansard with dormers and gilt cresting
        var roof = Path()
        roof.move(to: P(-35.5, 34)); roof.addLine(to: P(35.5, 34)); roof.addLine(to: P(32.5, 41)); roof.addLine(to: P(-32.5, 41)); roof.closeSubpath()
        roofs.addPath(roof)
        ctx.fill(roof, with: vgrad(GH.raspberry, GH.raspberryDeep, 41, 34))
        var slates = Path()
        var rx: CGFloat = -34
        while !simple && rx <= 34 { slates.move(to: P(rx, 34)); slates.addLine(to: P(rx * 0.93, 41)); rx += 2.2 }
        ctx.stroke(slates, with: .color(GH.claret.opacity(0.45)), lineWidth: hair * 0.7)
        var dormers = Path(), dormerGlass = Path()
        var dx: CGFloat = -29
        while !simple && dx <= 29.1 {
            if abs(dx) > 13 {
                let rect = R(dx - 1.6, 35.2, dx + 1.6, 39.4)
                dormers.addPath(UnevenRoundedRectangle(cornerRadii: .init(topLeading: rect.width / 2, topTrailing: rect.width / 2)).path(in: rect))
                let g = R(dx - 0.9, 35.7, dx + 0.9, 38.6)
                dormerGlass.addPath(UnevenRoundedRectangle(cornerRadii: .init(topLeading: g.width / 2, topTrailing: g.width / 2)).path(in: g))
            }
            dx += 5.8
        }
        ctx.fill(dormers, with: .color(GH.cream))
        ctx.fill(dormerGlass, with: .color(light.lamps > 0.5 ? GH.lamplight : GH.glass))
        ctx.fill(Path(R(-33, 40.6, 33, 41.7)), with: gilt)
        var cresting = Path()
        for k in stride(from: -32.0, through: 32.0, by: 2.0) where !simple { cresting.addEllipse(in: R(k - 0.35, 41.6, k + 0.35, 42.6)) }
        ctx.fill(cresting, with: gilt)

        // End pavilions, standing forward of the main block
        for sgn in [CGFloat(-1), 1] {
            let a: CGFloat = sgn < 0 ? -50 : 34, b: CGFloat = sgn < 0 ? -34 : 50
            let pav = Path(R(a, 3, b, 39))
            walls.addPath(pav)
            ctx.fill(pav, with: hgrad(sgn < 0 ? GH.pinkLight : GH.pink, sgn < 0 ? GH.pink : Color(hex: 0xEA92AC), a, b))
            var quoins = Path()
            for k in stride(from: 4.0, to: 37.0, by: 2.6) {
                let wq: CGFloat = Int(k) % 2 == 0 ? 2.2 : 1.4
                quoins.addRect(R(a, k, a + wq, k + 1.8))
                quoins.addRect(R(b - wq, k, b, k + 1.8))
            }
            ctx.fill(quoins, with: .color(GH.cream.opacity(0.85)))
            for wy in [6.0, 14.0, 21.0, 28.0] {
                for wxo in [-3.6, 3.6] { window((a + b) / 2 + wxo, wy, 2.6, wy == 6 ? 5 : 4.2, arch: wy == 6 || wy == 28) }
            }
            var pc = Path()
            for y in [12.0, 18.9, 25.4] { pc.addRect(R(a, y, b, y + 0.9)) }
            pc.addRect(R(a - 0.6, 37.6, b + 0.6, 39.4))
            ctx.fill(pc, with: .color(GH.cream))
            // pavilion mansard
            var pr = Path()
            pr.move(to: P(a - 0.8, 39.4)); pr.addLine(to: P(b + 0.8, 39.4)); pr.addLine(to: P(b - 2.2, 48)); pr.addLine(to: P(a + 2.2, 48)); pr.closeSubpath()
            roofs.addPath(pr)
            ctx.fill(pr, with: vgrad(GH.raspberry, GH.raspberryDeep, 48, 39.4))
            let m = (a + b) / 2
            ctx.fill(Path(ellipseIn: R(m - 1.8, 41.6, m + 1.8, 45.2)), with: .color(GH.cream))
            ctx.fill(Path(ellipseIn: R(m - 1.1, 42.3, m + 1.1, 44.5)), with: .color(light.lamps > 0.5 ? GH.lamplight : GH.glass))
            ctx.fill(Path(R(a + 2, 47.6, b - 2, 48.6)), with: gilt)
            // cupola
            ctx.fill(Path(R(m - 2.6, 48.6, m + 2.6, 52)), with: hgrad(GH.cream, Color(hex: 0xE8D5C6), m - 2.6, m + 2.6))
            ctx.fill(Path(R(m - 1.2, 49.2, m - 0.4, 51.4)), with: .color(light.lamps > 0.5 ? GH.lamplight : GH.glass))
            ctx.fill(Path(R(m + 0.4, 49.2, m + 1.2, 51.4)), with: .color(light.lamps > 0.5 ? GH.lamplight : GH.glass))
            var dome = Path()
            dome.move(to: P(m - 3, 52)); dome.addQuadCurve(to: P(m, 56.5), control: P(m - 3, 56)); dome.addQuadCurve(to: P(m + 3, 52), control: P(m + 3, 56)); dome.closeSubpath()
            roofs.addPath(dome)
            ctx.fill(dome, with: hgrad(Color(hex: 0xD0587D), GH.raspberryDeep, m - 3, m + 3))
            if !simple {
                var pole = Path(); pole.move(to: P(m, 56.5)); pole.addLine(to: P(m, 61.5))
                ctx.stroke(pole, with: .color(GH.goldDeep), lineWidth: hair)
                var flag = Path(); flag.move(to: P(m, 61.5)); flag.addLine(to: P(m + sgn * 4.2, 60.4)); flag.addLine(to: P(m, 59.3)); flag.closeSubpath()
                ctx.fill(flag, with: .color(sgn < 0 ? GH.raspberry : Color(hex: 0x86A9D8)))
            }
        }
        // The pavilions' inner returns: the left one's faces the shade, the right one's catches the light.
        ctx.fill(Path(R(-34, 3, -32.4, 39)), with: .color(Color(hex: 0xC56F8E)))
        ctx.fill(Path(R(32.4, 3, 34, 39)), with: .color(Color(hex: 0xFFD3DE)))
        // the left pavilion's shadow across the recessed main block
        ctx.fill(Path(R(-32.4, 3, -29.4, 31.8)), with: .color(GH.shadow.opacity(0.14)))

        // Central clock tower
        let tower = Path(R(-10.5, 3, 10.5, 50))
        walls.addPath(tower)
        ctx.fill(tower, with: hgrad(GH.pinkLight, GH.pink, -10.5, 10.5))
        var tq = Path()
        for k in stride(from: 4.0, to: 48.0, by: 2.6) {
            let wq: CGFloat = Int(k) % 2 == 0 ? 2.0 : 1.3
            tq.addRect(R(-10.5, k, -10.5 + wq, k + 1.8))
            tq.addRect(R(10.5 - wq, k, 10.5, k + 1.8))
        }
        ctx.fill(tq, with: .color(GH.cream.opacity(0.9)))
        for wx in [-4.6, 0.0, 4.6] {
            window(wx, 16, 2.6, 5.4, arch: true)
            window(wx, 25, 2.6, 5.0, arch: true)
        }
        if !simple {
            var bal = Path()
            bal.addRect(R(-8.5, 22.2, 8.5, 23))
            for bx in stride(from: -8.0, through: 8.0, by: 1.0) { bal.addRect(R(bx - 0.18, 23, bx + 0.18, 24.2)) }
            bal.addRect(R(-8.5, 24.1, 8.5, 24.6))
            ctx.fill(bal, with: .color(GH.cream))
        }
        // the tower's shadow on the main block and roof to its right
        ctx.fill(Path(R(10.5, 3, 13.6, 41)), with: .color(GH.shadow.opacity(0.15)))

        // Paint: plaster dabs over every wall, lighter on the roofs, then the light across the whole front.
        let bounds = R(-53, -1, 53, 87)
        var paint = ctx
        paint.clip(to: walls)
        paint.opacity = 0.95
        paint.draw(paint.resolve(GHTex.facade), in: R(-52, 2, 52, 52))
        var roofPaint = ctx
        roofPaint.clip(to: roofs)
        roofPaint.opacity = 0.6
        roofPaint.draw(roofPaint.resolve(GHTex.facade), in: R(-52, 30, 52, 60))
        var lit = ctx
        var both = walls
        both.addPath(roofs)
        lit.clip(to: both)
        lit.fill(Path(bounds), with: .linearGradient(Gradient(stops: [
            .init(color: Color(hex: 0xFFF2DC).opacity(0.22), location: 0),
            .init(color: .clear, location: 0.45),
            .init(color: GH.shadow.opacity(0.16), location: 1)
        ]), startPoint: P(-53, 60), endPoint: P(53, 0)))
        if light.twilight > 0 { lit.fill(Path(bounds), with: .color(Color(hex: 0xF7A47E).opacity(0.18 * light.twilight))) }
        if light.gray { lit.fill(Path(bounds), with: .color(Color(hex: 0x9C96B8).opacity(0.14))) }
        if light.night > 0 { lit.fill(Path(bounds), with: .color(Color(hex: 0x1A1640).opacity(0.5 * light.night))) }

        // entrance and striped scalloped awning
        let door = R(-3.8, 3, 3.8, 11.2)
        ctx.fill(UnevenRoundedRectangle(cornerRadii: .init(topLeading: door.width / 2, topTrailing: door.width / 2)).path(in: door),
                 with: .color(light.lamps > 0.3 ? Color(hex: 0xE8A85A) : GH.glass))
        ctx.fill(Path(R(-2.8, 3, 2.8, 8.6)), with: .color(GH.raspberryDeep))
        ctx.fill(Path(R(-0.12, 3, 0.12, 8.6)), with: .color(GH.goldLight))
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
        ctx.fill(awn, with: .color(GH.cream))
        var aw = ctx
        aw.clip(to: awn)
        aw.fill(stripes, with: .color(GH.raspberry))
        aw.fill(awn, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.25), GH.shadow.opacity(0.2)]), startPoint: P(-6, 13), endPoint: P(6, 9)))
        if light.night > 0 { aw.fill(awn, with: .color(Color(hex: 0x1A1640).opacity(0.4 * light.night))) }
        var awnShadow = ctx
        awnShadow.addFilter(.blur(radius: 0.6 * u))
        awnShadow.fill(Path(R(-6.4, 8.2, 7.2, 9.4)), with: .color(GH.shadow.opacity(0.25)))

        // clock, set to the hour
        let clock = R(-5.4, 37.4, 5.4, 48.2)
        ctx.fill(Path(ellipseIn: clock.insetBy(dx: -0.9 * u, dy: -0.9 * u)), with: gilt)
        ctx.fill(Path(ellipseIn: clock), with: .radialGradient(Gradient(colors: [light.night > 0 ? Color(hex: 0xFFE9B8) : GH.cream, Color(hex: 0xF1E0C8)]),
                                                                 center: CGPoint(x: clock.midX - clock.width * 0.15, y: clock.midY - clock.height * 0.15),
                                                                 startRadius: 0, endRadius: clock.width * 0.7))
        var ticks = Path()
        let cc = CGPoint(x: clock.midX, y: clock.midY)
        for k in 0..<12 {
            let a = Double(k) / 12 * 2 * .pi
            let r0 = clock.width * 0.36, r1 = clock.width * 0.45
            ticks.move(to: CGPoint(x: cc.x + CGFloat(sin(a)) * r0, y: cc.y - CGFloat(cos(a)) * r0))
            ticks.addLine(to: CGPoint(x: cc.x + CGFloat(sin(a)) * r1, y: cc.y - CGFloat(cos(a)) * r1))
        }
        ctx.stroke(ticks, with: .color(GH.plum), lineWidth: hair * 0.8)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minute = Double(comps.minute ?? 41), hour = Double((comps.hour ?? 9) % 12) + minute / 60
        var hands = Path()
        for (frac, len) in [(hour / 12, 0.24), (minute / 60, 0.36)] {
            let a = frac * 2 * .pi
            hands.move(to: cc)
            hands.addLine(to: CGPoint(x: cc.x + CGFloat(sin(a)) * clock.width * len, y: cc.y - CGFloat(cos(a)) * clock.width * len))
        }
        ctx.stroke(hands, with: .color(GH.plum), style: StrokeStyle(lineWidth: hair * 1.2, lineCap: .round))

        // cornice, belvedere, bell dome, lantern, pennant
        ctx.fill(Path(R(-11.6, 49.4, 11.6, 51.4)), with: .color(GH.cream))
        ctx.fill(Path(R(-11.6, 49, 11.6, 49.4)), with: gilt)
        ctx.fill(Path(R(-7.6, 51.4, 7.6, 57.4)), with: hgrad(GH.cream, Color(hex: 0xE2CDBE), -7.6, 7.6))
        var cols = Path()
        for k in stride(from: -6.0, through: 6.0, by: 3.0) { cols.addRect(R(k - 0.9, 52, k + 0.9, 56.8)) }
        ctx.fill(cols, with: .color(light.lamps > 0.5 ? GH.lamplight : GH.glass.opacity(0.9)))
        ctx.fill(Path(R(-8.4, 57.2, 8.4, 58.4)), with: gilt)
        var bell = Path()
        bell.move(to: P(-8, 58.4))
        bell.addCurve(to: P(0, 73), control1: P(-9.2, 64), control2: P(-2.2, 67.5))
        bell.addCurve(to: P(8, 58.4), control1: P(2.2, 67.5), control2: P(9.2, 64))
        bell.closeSubpath()
        ctx.fill(bell, with: hgrad(Color(hex: 0xD45E82), GH.raspberryDeep, -6, 8))
        var bp = ctx
        bp.clip(to: bell)
        bp.opacity = 0.6
        bp.draw(bp.resolve(GHTex.facade), in: R(-9, 58, 9, 74))
        if light.night > 0 { bp.opacity = 1; bp.fill(bell, with: .color(Color(hex: 0x1A1640).opacity(0.4 * light.night))) }
        var ribs = Path()
        for k in [-4.0, 0.0, 4.0] { ribs.move(to: P(k * 1.6, 58.4)); ribs.addQuadCurve(to: P(0, 73), control: P(k * 1.4, 66)) }
        ctx.stroke(ribs, with: .color(GH.goldLight.opacity(0.85)), lineWidth: hair * 0.8)
        var shine = Path()
        shine.move(to: P(-6.2, 60)); shine.addQuadCurve(to: P(-2.4, 68), control: P(-6.4, 65))
        ctx.stroke(shine, with: .color(Color.white.opacity(0.45)), style: StrokeStyle(lineWidth: hair * 1.4, lineCap: .round))
        ctx.fill(Path(R(-1.8, 72.4, 1.8, 76)), with: .color(GH.cream))
        ctx.fill(Path(ellipseIn: R(-2, 75.4, 2, 78)), with: gilt)
        var mast = Path(); mast.move(to: P(0, 78)); mast.addLine(to: P(0, 86))
        ctx.stroke(mast, with: .color(GH.goldDeep), lineWidth: hair)
        var pennant = Path(); pennant.move(to: P(0, 86)); pennant.addQuadCurve(to: P(8, 84.2), control: P(4, 84.4)); pennant.addQuadCurve(to: P(0, 82.4), control: P(4, 82.6)); pennant.closeSubpath()
        ctx.fill(pennant, with: .color(GH.raspberry))

        // windows, all at once: dark glass with a sky glint by day, lamplight after dark
        ctx.fill(glass, with: .linearGradient(Gradient(colors: [Color(hex: 0x3A2048), GH.glass]), startPoint: P(0, 40), endPoint: P(0, 3)))
        ctx.fill(glass.offsetBy(dx: -0.3 * u, dy: -0.3 * u), with: .color(Color(hex: 0xB7C9EA).opacity(0.18 * (1 - light.night))))
        if light.lamps > 0 {
            var glow = ctx
            glow.addFilter(.blur(radius: 2.2 * u))
            glow.fill(lamps, with: .color(GH.lamplight.opacity(0.5 + 0.4 * light.night)))
        }
        ctx.fill(lamps, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF1C2), GH.lamplight]), startPoint: P(0, 45), endPoint: P(0, 3)))
        ctx.fill(lintels, with: .color(GH.shadow.opacity(0.25)))
        ctx.fill(sills, with: .color(GH.cream))

        // terrace balustrade along the front
        var rail = Path()
        rail.addRect(R(-53, 0, 53, 0.8))
        rail.addRect(R(-53, 2.6, 53, 3.4))
        for bx in stride(from: -52.5, through: 52.5, by: 1.5) { rail.addRect(R(bx - 0.25, 0.8, bx + 0.25, 2.6)) }
        ctx.fill(rail, with: .color(light.night > 0 ? Color(hex: 0xB9AFCF) : GH.cream))
        ctx.fill(Path(R(-53, -0.6, 53, 0)), with: .color(GH.shadow.opacity(0.25)))

        // gilt sparkles either side of the pennant, the storybook's stars
        if u > 0.7 && !simple {
            for (x, y, s) in [(-20.0, 70.0, 5.0), (20.0, 70.0, 5.0)] {
                let rect = R(x - s / 2, y - s * 0.6, x + s / 2, y + s * 0.6)
                var g = ctx
                g.addFilter(.blur(radius: 2 * u))
                g.fill(Path(ellipseIn: rect.insetBy(dx: -s * 0.6 * u, dy: -s * 0.6 * u)), with: .color(Stone.goldBright.opacity(0.3)))
                ctx.fill(Sparkle().path(in: rect), with: .color(Stone.goldBright.opacity(0.95)))
            }
        }
    }
}

// MARK: - The proscenium

/// A raspberry velvet valance across the top of the frame: scalloped swags painted in velvet, pleat shading, a sheen in
/// each swag, a gilt rod with braid, gold-edged hems and tassels at the gathers. Casts a soft shadow on the set.
struct GHValance: View {
    var depth: CGFloat
    var scallops: Int
    /// Grand Hotel Calm hangs a plainer valance: no tassels, no crest, no braid.
    var tassels = true
    var crest = true
    var braid = true

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let band = depth * 0.46
            let r = w / CGFloat(scallops) / 2
            let drop = depth - band
            var shape = Path(CGRect(x: 0, y: 0, width: w, height: band))
            var hems = Path()
            var swags: [CGRect] = []
            for i in 0..<scallops {
                let cx = r * CGFloat(2 * i + 1)
                let e = CGRect(x: cx - r, y: band - drop, width: 2 * r, height: 2 * drop)
                swags.append(e)
                shape.addEllipse(in: e)
                var arc = Path()
                for k in 0...14 {
                    let a = Double.pi * (1 - Double(k) / 14)
                    let pt = CGPoint(x: e.midX + CGFloat(cos(a)) * e.width / 2, y: e.midY + CGFloat(sin(a)) * e.height / 2)
                    if k == 0 { arc.move(to: pt) } else { arc.addLine(to: pt) }
                }
                hems.addPath(arc)
            }
            // cast shadow: tight, then soft
            var sh = ctx
            sh.addFilter(.blur(radius: 3))
            sh.fill(shape.offsetBy(dx: 0, dy: 3), with: .color(GH.shadow.opacity(0.45)))
            var sh2 = ctx
            sh2.addFilter(.blur(radius: 0.8))
            sh2.fill(shape.offsetBy(dx: 0, dy: 1.2), with: .color(GH.shadow.opacity(0.5)))
            // velvet
            var v = ctx
            v.clip(to: shape)
            v.fill(shape, with: .color(GHMaterial.velvet.base))
            v.draw(v.resolve(GHTex.velvet), in: CGRect(x: 0, y: -depth * 0.6, width: w, height: max(depth * 2.4, w * 0.4)))
            for e in swags {
                // pleats: dark at the gathers, a soft sheen in the belly of each swag
                v.fill(Path(CGRect(x: e.minX, y: 0, width: e.width, height: depth)),
                       with: .linearGradient(Gradient(stops: [.init(color: GH.claret.opacity(0.7), location: 0),
                                                              .init(color: .clear, location: 0.3), .init(color: .clear, location: 0.7),
                                                              .init(color: GH.claret.opacity(0.7), location: 1)]),
                                             startPoint: CGPoint(x: e.minX, y: 0), endPoint: CGPoint(x: e.maxX, y: 0)))
                v.fill(Path(ellipseIn: e), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFC2D4).opacity(0.4), .clear]),
                                                                center: CGPoint(x: e.midX - e.width * 0.14, y: band + drop * 0.25),
                                                                startRadius: 0, endRadius: e.width * 0.5))
                var folds = Path()
                for k in [-0.22, 0.0, 0.22] {
                    folds.move(to: CGPoint(x: e.midX + e.width * k * 1.6, y: 0))
                    folds.addQuadCurve(to: CGPoint(x: e.midX + e.width * k, y: band + drop * 0.85), control: CGPoint(x: e.midX + e.width * k * 1.2, y: band))
                }
                v.stroke(folds, with: .color(GH.claret.opacity(0.4)), lineWidth: 0.9)
            }
            v.fill(shape, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.08), GH.shadow.opacity(0.2)]),
                                                startPoint: .zero, endPoint: CGPoint(x: 0, y: depth)))
            // gilt rod and braid
            let rodH = max(2.2, depth * 0.11)
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: rodH)),
                     with: .linearGradient(Gradient(colors: [GH.goldLight, GH.gold, GH.goldDeep]), startPoint: .zero, endPoint: CGPoint(x: 0, y: rodH)))
            ctx.fill(Path(CGRect(x: 0, y: rodH, width: w, height: 0.8)), with: .color(GH.shadow.opacity(0.4)))
            var braidPath = Path()
            var bx: CGFloat = 1
            while braid && bx < w { braidPath.addEllipse(in: CGRect(x: bx, y: band * 0.8, width: 1.7, height: 1.2)); bx += 2.8 }
            ctx.fill(braidPath.offsetBy(dx: 0, dy: 0.5), with: .color(GH.shadow.opacity(0.4)))
            ctx.fill(braidPath, with: .color(GH.goldLight))
            ctx.stroke(hems.offsetBy(dx: 0, dy: -0.9), with: .color(GH.goldLight), lineWidth: 1)
            ctx.stroke(hems, with: .color(GH.goldDeep), lineWidth: 0.6)
            // tassels at the gathers
            for i in 1..<scallops where tassels {
                let x = r * CGFloat(2 * i)
                var cord = Path()
                cord.move(to: CGPoint(x: x, y: band * 0.8))
                cord.addLine(to: CGPoint(x: x, y: band + drop * 0.35))
                ctx.stroke(cord, with: .color(GH.goldDeep), lineWidth: 0.7)
                let tw = max(2.8, depth * 0.14), th = max(4, depth * 0.26)
                let head = CGRect(x: x - tw * 0.32, y: band + drop * 0.3, width: tw * 0.64, height: tw * 0.6)
                var skirt = Path()
                skirt.move(to: CGPoint(x: x - tw * 0.25, y: head.maxY - 0.4))
                skirt.addLine(to: CGPoint(x: x + tw * 0.25, y: head.maxY - 0.4))
                skirt.addLine(to: CGPoint(x: x + tw * 0.5, y: head.maxY + th))
                skirt.addLine(to: CGPoint(x: x - tw * 0.5, y: head.maxY + th))
                skirt.closeSubpath()
                var ts = ctx
                ts.addFilter(.blur(radius: 0.8))
                ts.fill(skirt.offsetBy(dx: 0.8, dy: 1.2), with: .color(GH.shadow.opacity(0.45)))
                ctx.fill(skirt, with: .linearGradient(Gradient(colors: [GH.goldLight, GH.gold, GH.goldDeep]),
                                                      startPoint: CGPoint(x: x - tw * 0.5, y: 0), endPoint: CGPoint(x: x + tw * 0.5, y: 0)))
                ctx.fill(Path(ellipseIn: head), with: .radialGradient(Gradient(colors: [GH.goldLight, GH.goldDeep]),
                                                                      center: CGPoint(x: head.minX + head.width * 0.35, y: head.minY + head.height * 0.3),
                                                                      startRadius: 0, endRadius: head.width * 0.7))
            }
            // the crest at the centre: a gilt sparkle on the middle swag
            if crest {
                let mid = swags[scallops / 2]
                let s: CGFloat = max(7, depth * 0.42)
                let star = CGRect(x: mid.midX - s * 0.4, y: band + drop * 0.05, width: s * 0.8, height: s)
                var g = ctx
                g.addFilter(.blur(radius: 2))
                g.fill(Path(ellipseIn: star.insetBy(dx: -2, dy: -2)), with: .color(Stone.goldBright.opacity(0.35)))
                ctx.fill(Sparkle().path(in: star), with: .linearGradient(Gradient(colors: [Stone.goldBright, GH.gold]),
                                                                          startPoint: CGPoint(x: 0, y: star.minY), endPoint: CGPoint(x: 0, y: star.maxY)))
            }
        }
        .frame(height: depth + 8, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Velvet side curtains drawn open and tied back with gold cord: the proscenium's wings.
struct GHCurtains: View {
    var width: CGFloat   // of each curtain at the top
    var tie: CGFloat     // tie-back height, fraction of the height

    var body: some View {
        Canvas { ctx, size in
            for side in [CGFloat(-1), 1] {
                var c = ctx
                if side > 0 {
                    c.translateBy(x: size.width, y: 0)
                    c.scaleBy(x: -1, y: 1)
                }
                Self.drawOne(c, size: size, width: width, tie: tie)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func drawOne(_ ctx: GraphicsContext, size: CGSize, width cw: CGFloat, tie: CGFloat) {
        let h = size.height
        let ty = h * tie
        var shape = Path()
        shape.move(to: CGPoint(x: -2, y: 0))
        shape.addLine(to: CGPoint(x: cw, y: 0))
        shape.addCurve(to: CGPoint(x: cw * 0.34, y: ty), control1: CGPoint(x: cw * 0.95, y: ty * 0.45), control2: CGPoint(x: cw * 0.5, y: ty * 0.8))
        shape.addCurve(to: CGPoint(x: cw * 0.62, y: h), control1: CGPoint(x: cw * 0.5, y: ty + (h - ty) * 0.3), control2: CGPoint(x: cw * 0.66, y: h * 0.9))
        shape.addLine(to: CGPoint(x: -2, y: h))
        shape.closeSubpath()
        var sh = ctx
        sh.addFilter(.blur(radius: 4))
        sh.fill(shape.offsetBy(dx: 4, dy: 2), with: .color(GH.shadow.opacity(0.45)))
        var v = ctx
        v.clip(to: shape)
        v.fill(shape, with: .color(GHMaterial.velvet.base))
        v.draw(v.resolve(GHTex.velvet), in: CGRect(x: -20, y: 0, width: max(cw * 2.4, 140), height: h))
        // folds gathering into the tie-back
        var folds = Path()
        for k in 0..<5 {
            let x0 = cw * (0.12 + 0.2 * CGFloat(k))
            folds.move(to: CGPoint(x: x0, y: 0))
            folds.addQuadCurve(to: CGPoint(x: cw * (0.06 + 0.07 * CGFloat(k)), y: ty), control: CGPoint(x: x0 * 0.9, y: ty * 0.6))
            folds.addQuadCurve(to: CGPoint(x: cw * (0.08 + 0.13 * CGFloat(k)), y: h), control: CGPoint(x: cw * (0.1 + 0.08 * CGFloat(k)), y: ty + (h - ty) * 0.5))
        }
        v.stroke(folds, with: .color(GH.claret.opacity(0.55)), lineWidth: 2.4)
        v.stroke(folds.offsetBy(dx: 2, dy: 0), with: .color(Color(hex: 0xFFC2D4).opacity(0.22)), lineWidth: 1.2)
        v.fill(shape, with: .linearGradient(Gradient(colors: [GH.shadow.opacity(0.35), .clear, Color.white.opacity(0.08)]),
                                            startPoint: .zero, endPoint: CGPoint(x: cw, y: 0)))
        // lit inner edge
        var edge = Path()
        edge.move(to: CGPoint(x: cw, y: 0))
        edge.addCurve(to: CGPoint(x: cw * 0.34, y: ty), control1: CGPoint(x: cw * 0.95, y: ty * 0.45), control2: CGPoint(x: cw * 0.5, y: ty * 0.8))
        ctx.stroke(edge, with: .color(GH.goldLight.opacity(0.8)), lineWidth: 1)
        // cord and tassel
        var cord = Path()
        cord.move(to: CGPoint(x: -2, y: ty - 3))
        cord.addQuadCurve(to: CGPoint(x: cw * 0.42, y: ty + 1), control: CGPoint(x: cw * 0.2, y: ty + 4))
        ctx.stroke(cord.offsetBy(dx: 0.6, dy: 1), with: .color(GH.shadow.opacity(0.4)), lineWidth: 2.2)
        ctx.stroke(cord, with: .color(GH.gold), lineWidth: 2)
        ctx.stroke(cord, with: .color(GH.goldLight), style: StrokeStyle(lineWidth: 0.7, dash: [1.4, 1.4]))
        let tx = cw * 0.42, tY = ty + 1
        var tassel = Path()
        tassel.move(to: CGPoint(x: tx - 1.5, y: tY + 2))
        tassel.addLine(to: CGPoint(x: tx + 1.5, y: tY + 2))
        tassel.addLine(to: CGPoint(x: tx + 3.2, y: tY + 11))
        tassel.addLine(to: CGPoint(x: tx - 3.2, y: tY + 11))
        tassel.closeSubpath()
        var ts = ctx
        ts.addFilter(.blur(radius: 1))
        ts.fill(tassel.offsetBy(dx: 1, dy: 1.4), with: .color(GH.shadow.opacity(0.45)))
        ctx.fill(tassel, with: .linearGradient(Gradient(colors: [GH.goldLight, GH.gold, GH.goldDeep]),
                                               startPoint: CGPoint(x: tx - 3, y: 0), endPoint: CGPoint(x: tx + 3, y: 0)))
        ctx.fill(Path(ellipseIn: CGRect(x: tx - 2.4, y: tY - 1.6, width: 4.8, height: 4.2)),
                 with: .radialGradient(Gradient(colors: [GH.goldLight, GH.goldDeep]), center: CGPoint(x: tx - 0.8, y: tY - 0.4), startRadius: 0, endRadius: 3))
    }
}
