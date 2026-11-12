import SwiftUI

// The painted scenery: a brushed sky that follows the time of day and the weather,
// the real sun or moon (today's sunrise to sunset arc, tonight's moon phase), clouds with lit rims,
// sparkling stars, and layered ridges with spruce along their crests.
// Everything is drawn in unit coordinates of the whole view, so the art lines up with the layout
// on every phone size. The settings app paints its backdrop with it (ContentView); the retired widgets'
// grounds that used the rest, DayBackground and QuoteBackground, are in MockLab/PaintKit/RetiredGrounds.swift.

// MARK: - Ridges

// Small deterministic generator, so a ridge looks the same on every render and every device.
struct SeededRandom {
    private var state: UInt64

    init(_ seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }

    mutating func signed() -> Double { next() * 2 - 1 }
}

// A ridge silhouette: hand-placed key points (x and y as fractions of the widget) roughened by seeded
// midpoint displacement into a natural, jagged crest.
struct RidgeProfile {
    var keys: [CGPoint]
    var seed: UInt64
    var roughness: CGFloat = 0.2 // displacement as a fraction of each segment's length
    var levels: Int = 4

    func crest(in rect: CGRect) -> [CGPoint] {
        var pts = keys.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        var rng = SeededRandom(seed)
        var amount = roughness
        for _ in 0..<levels {
            var next: [CGPoint] = [pts[0]]
            for i in 0..<(pts.count - 1) {
                let a = pts[i], b = pts[i + 1]
                let length = hypot(b.x - a.x, b.y - a.y)
                let mid = CGPoint(x: (a.x + b.x) / 2 + CGFloat(rng.signed()) * length * 0.08,
                                  y: (a.y + b.y) / 2 + CGFloat(rng.signed()) * length * amount)
                next.append(mid)
                next.append(b)
            }
            pts = next
            amount *= 0.62
        }
        return pts
    }

    // Height of the crest at x, by straight lines between its points.
    static func height(at x: CGFloat, on pts: [CGPoint]) -> CGFloat {
        guard let first = pts.first, let last = pts.last else { return 0 }
        if x <= first.x { return first.y }
        for i in 1..<pts.count where pts[i].x >= x {
            let a = pts[i - 1], b = pts[i]
            let t = b.x > a.x ? (x - a.x) / (b.x - a.x) : 0
            return a.y + (b.y - a.y) * t
        }
        return last.y
    }
}

struct RidgeShape: Shape {
    var profile: RidgeProfile
    var closed = true

    func path(in rect: CGRect) -> Path {
        let pts = profile.crest(in: rect)
        var p = Path()
        if closed {
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            for pt in pts { p.addLine(to: pt) }
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.closeSubpath()
        } else if let first = pts.first {
            p.move(to: first)
            for pt in pts.dropFirst() { p.addLine(to: pt) }
        }
        return p
    }
}

// Snow on everything above the snowline, ending in a ragged edge partway down each peak.
struct SnowShape: Shape {
    var profile: RidgeProfile
    var snowline: CGFloat // fraction of the widget height

    func path(in rect: CGRect) -> Path {
        let pts = profile.crest(in: rect)
        let line = rect.minY + snowline * rect.height
        var rng = SeededRandom(profile.seed &+ 77)
        var p = Path()
        var run: [CGPoint] = []
        func flush() {
            guard run.count > 2 else { run = []; return }
            p.move(to: run[0])
            for pt in run.dropFirst() { p.addLine(to: pt) }
            for pt in run.reversed() {
                let depth = (line - pt.y) * CGFloat(0.45 + rng.next() * 0.4)
                p.addLine(to: CGPoint(x: pt.x, y: min(line, pt.y + depth)))
            }
            p.closeSubpath()
            run = []
        }
        for pt in pts {
            if pt.y < line { run.append(pt) } else { flush() }
        }
        flush()
        return p
    }
}

// Spruce standing along a crest, with gaps, in sizes measured in points of a 348pt-wide widget.
struct Trees {
    var height: ClosedRange<CGFloat>
    var spacing: CGFloat
    var coverage: Double = 0.75
}

struct TreeLine: Shape {
    var profile: RidgeProfile
    var trees: Trees

    func path(in rect: CGRect) -> Path {
        let u = rect.width / 348
        let pts = profile.crest(in: rect)
        var rng = SeededRandom(profile.seed &+ 991)
        var p = Path()
        var x = rect.minX + CGFloat(rng.next()) * trees.spacing * u
        while x < rect.maxX {
            let h = (trees.height.lowerBound + (trees.height.upperBound - trees.height.lowerBound) * CGFloat(rng.next())) * u
            if rng.next() < trees.coverage {
                let base = RidgeProfile.height(at: x, on: pts) + 1.5 * u
                p.addPath(Self.spruce(x: x, base: base, height: h))
            }
            x += trees.spacing * u * CGFloat(0.55 + rng.next() * 0.9)
        }
        return p
    }

    // Three drooping tiers on a short trunk.
    static func spruce(x: CGFloat, base: CGFloat, height h: CGFloat) -> Path {
        let w = h * 0.46
        let top = base - h
        let tiers: [(y: CGFloat, half: CGFloat)] = (1...3).map { k in
            let f = CGFloat(k) / 3
            return (top + h * f * 0.9, w / 2 * (0.42 + 0.58 * f))
        }
        var p = Path()
        p.move(to: CGPoint(x: x, y: top))
        for (i, t) in tiers.enumerated() {
            p.addLine(to: CGPoint(x: x + t.half, y: t.y))
            if i < tiers.count - 1 { p.addLine(to: CGPoint(x: x + t.half * 0.35, y: t.y - h * 0.05)) }
        }
        p.addLine(to: CGPoint(x: x + w * 0.07, y: tiers[2].y))
        p.addLine(to: CGPoint(x: x + w * 0.07, y: base + h * 0.12))
        p.addLine(to: CGPoint(x: x - w * 0.07, y: base + h * 0.12))
        p.addLine(to: CGPoint(x: x - w * 0.07, y: tiers[2].y))
        for (i, t) in tiers.enumerated().reversed() {
            p.addLine(to: CGPoint(x: x - t.half, y: t.y))
            if i > 0 { p.addLine(to: CGPoint(x: x - tiers[i - 1].half * 0.35, y: tiers[i - 1].y - h * 0.05)) }
        }
        p.closeSubpath()
        return p
    }
}

struct MountainLayer {
    var profile: RidgeProfile
    var top: Color
    var bottom: Color
    var rim: Double = 0.4          // strength of the light along the crest
    var snowline: CGFloat? = nil
    var trees: Trees? = nil
}

// A relief overlay (light and dark brushwork with transparency) stretched over whatever it decorates.
// Never sizes its parent.
struct PaintRelief: View {
    var name: String
    var opacity: Double
    var flip = false

    var body: some View {
        Color.clear
            .overlay {
                Image(name)
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

// Ridges from far to near. Each is lifted off the one behind by a soft shadow, like cut paper.
struct MountainRange: View {
    var layers: [MountainLayer]
    var night: Bool = false
    var snowLower: CGFloat = 0 // heavier snow cover while it is snowing
    var fade: ClosedRange<CGFloat>? = nil // fraction of the height over which the ridges dissolve into the valley

    var body: some View {
        ZStack {
            ForEach(layers.indices, id: \.self) { i in
                layerView(layers[i], index: i)
            }
        }
        .mask {
            if let fade {
                LinearGradient(stops: [.init(color: .black, location: fade.lowerBound), .init(color: .clear, location: fade.upperBound)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                Color.black
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func layerView(_ layer: MountainLayer, index: Int) -> some View {
        let ridge = RidgeShape(profile: layer.profile)
        let rimColor = night ? Color(hex: 0xD8E0D2) : Stone.goldBright
        return ZStack {
            ridge.fill(LinearGradient(colors: [layer.top, layer.bottom], startPoint: .top, endPoint: .bottom))
            if let line = layer.snowline {
                SnowShape(profile: layer.profile, snowline: line + snowLower)
                    .fill(LinearGradient(colors: night ? [Color(hex: 0xC9CDBF), Color(hex: 0x7E8A84)] : [Color(hex: 0xF0E2C0), Color(hex: 0xA9AC98)],
                                         startPoint: .top, endPoint: .bottom))
            }
            PaintRelief(name: "PaintRidge", opacity: 0.9, flip: index % 2 == 1)
                .offset(y: CGFloat(index) * 23)
                .clipShape(ridge)
            if let trees = layer.trees {
                TreeLine(profile: layer.profile, trees: trees)
                    .fill(layer.top)
                    .overlay(TreeLine(profile: layer.profile, trees: trees).stroke(rimColor.opacity(layer.rim * 0.35), lineWidth: 0.5))
            }
            RidgeShape(profile: layer.profile, closed: false)
                .stroke(rimColor.opacity(layer.rim), style: StrokeStyle(lineWidth: 0.9, lineJoin: .round))
                .blur(radius: 0.3)
            if night {
                ridge.fill(Color(hex: 0x0A1220).opacity(0.32))
            }
        }
        .compositingGroup()
        .shadow(color: Stone.shadow.opacity(0.5), radius: 3, x: 0, y: -1.2)
    }
}

// MARK: - Sky


enum SkyCondition {
    case clear, partly, overcast, fog, rain, snow, storm

    init(code: Int?) {
        switch code ?? 0 {
        case 0, 1: self = .clear
        case 2: self = .partly
        case 3: self = .overcast
        case 45, 48: self = .fog
        case 71, 73, 75, 77, 85, 86: self = .snow
        case 95, 96, 99: self = .storm
        case 51...67, 80...82: self = .rain
        default: self = .partly
        }
    }

    var cloudy: Bool { self != .clear }
    var gray: Bool { self == .overcast || self == .rain || self == .storm || self == .snow || self == .fog }
}



// Colors of the painted sky for the time of day and the weather.
struct SkyPalette {
    var top: Color
    var mid: Color
    var horizon: Color
    var ground: Color

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

    init(clock: SkyClock, condition: SkyCondition) {
        // Day: deep teal overhead to a warm haze at the horizon. Night: blue-black to moonlit green.
        var top = clock.isDay ? RGB(0x1C3135) : RGB(0x0D1519)
        var mid = clock.isDay ? RGB(0x2D4645) : RGB(0x15222A)
        var horizon = clock.isDay ? RGB(0x6A6F55) : RGB(0x26363A)
        if condition.gray {
            top = top.mixed(RGB(0x1E2526), 0.6)
            mid = mid.mixed(RGB(0x2D3433), 0.6)
            horizon = horizon.mixed(RGB(0x474B45), 0.6)
        }
        // Copper light low in the sky around sunrise and sunset.
        horizon = horizon.mixed(RGB(0x9A5A38), 0.75 * clock.twilight)
        mid = mid.mixed(RGB(0x4A3A35), 0.45 * clock.twilight)
        self.top = top.color
        self.mid = mid.color
        self.horizon = horizon.color
        self.ground = (clock.isDay ? RGB(0x1A2521) : RGB(0x111917)).color
    }

    // The fixed evening sky behind the quote widget.
    static let evening = SkyPalette(top: Color(hex: 0x0F181B), mid: Color(hex: 0x182629), horizon: Color(hex: 0x3D3A2C), ground: Color(hex: 0x111816))

    private init(top: Color, mid: Color, horizon: Color, ground: Color) {
        self.top = top; self.mid = mid; self.horizon = horizon; self.ground = ground
    }
}

// The sky itself: a graded wash laid in with long brush strokes, on canvas.
struct PaintedSky: View {
    var palette: SkyPalette
    var horizon: CGFloat // fraction of the height where the sky meets the land
    var reliefName = "PaintSky"

    var body: some View {
        LinearGradient(stops: [
            .init(color: palette.top, location: 0),
            .init(color: palette.mid, location: horizon * 0.6),
            .init(color: palette.horizon, location: horizon),
            .init(color: palette.ground, location: min(1, horizon + 0.22))
        ], startPoint: .top, endPoint: .bottom)
        .overlay(PaintRelief(name: reliefName, opacity: 0.95))
        .overlay(CanvasWeave(opacity: 0.6))
    }
}


// Clouds sit high on the arc so the peaks never hide them; rain and snow fall from the same clouds.
enum SkyLayout {
    static func clouds(_ condition: SkyCondition, clock: SkyClock, arc: SkyArc, size: CGSize) -> [(center: CGPoint, width: CGFloat)] {
        let u = size.width / 348
        func at(_ progress: Double, lift: CGFloat) -> CGPoint {
            let pt = arc.point(progress, in: size)
            return CGPoint(x: pt.x, y: pt.y - lift * u)
        }
        switch condition {
        case .clear:
            return []
        case .partly:
            let body = arc.point(clock.progress, in: size)
            return [(CGPoint(x: body.x + 12 * u, y: body.y + 7 * u), 32 * u),
                    (at(clock.progress < 0.5 ? 0.78 : 0.24, lift: 10), 22 * u)]
        case .fog:
            return [(at(0.62, lift: 10), 26 * u)]
        case .overcast, .rain, .snow, .storm:
            return [(at(0.24, lift: 8), 30 * u), (at(0.5, lift: 4), 38 * u), (at(0.77, lift: 12), 29 * u)]
        }
    }
}

// Behind the ridges: the dotted arc, the sun or moon, and clouds. Stars are drawn by the scene.
struct SkyBack: View {
    var clock: SkyClock
    var condition: SkyCondition
    var arc: SkyArc
    var phase: MoonPhase

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let body = arc.point(clock.progress, in: size)
            let unit = size.width / 348
            ZStack(alignment: .topLeading) {
                // Light from the sun or moon spreading through the sky around it.
                Circle()
                    .fill(RadialGradient(colors: [(clock.isDay ? Stone.goldBright : Stone.moonlight).opacity(condition.gray ? 0.08 : 0.16), .clear],
                                         center: .center, startRadius: 0, endRadius: 75 * unit))
                    .frame(width: 150 * unit, height: 150 * unit)
                    .position(body)
                ArcTrail(arc: arc)
                Group {
                    if clock.isDay {
                        SunDisc(radius: 8.5 * unit).opacity(condition.gray ? 0.5 : 1)
                    } else {
                        MoonDisc(radius: 10 * unit, phase: phase).opacity(condition.gray ? 0.6 : 1)
                    }
                }
                .position(body)
                ForEach(Array(SkyLayout.clouds(condition, clock: clock, arc: arc, size: size).enumerated()), id: \.offset) { i, c in
                    PaintedCloud(night: !clock.isDay, gray: condition.gray, seed: i)
                        .frame(width: c.width, height: c.width * 0.55)
                        .position(c.center)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// In front of the ridges: rain, snow, lightning and fog banks.
struct SkyFront: View {
    var clock: SkyClock
    var condition: SkyCondition
    var arc: SkyArc

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let u = size.width / 348
            let clouds = SkyLayout.clouds(condition, clock: clock, arc: arc, size: size)
            ZStack(alignment: .topLeading) {
                switch condition {
                case .rain, .storm:
                    Canvas { ctx, _ in
                        for c in clouds {
                            let count = Int(c.width / (5 * u))
                            for i in 0..<count {
                                let x = c.center.x - c.width * 0.36 + CGFloat(i) * 5 * u + (i % 2 == 0 ? 0 : 1.5 * u)
                                let y = c.center.y + c.width * 0.26 + (i % 2 == 0 ? 0 : 4 * u)
                                var p = Path()
                                p.move(to: CGPoint(x: x, y: y))
                                p.addLine(to: CGPoint(x: x - 2.5 * u, y: y + 9 * u))
                                ctx.stroke(p, with: .color(Color(hex: 0xA9BDB6).opacity(0.7)),
                                           style: StrokeStyle(lineWidth: 1.1 * u, lineCap: .round, dash: [3 * u, 2.5 * u]))
                            }
                        }
                    }
                    if condition == .storm, clouds.count > 1 {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12 * u, weight: .bold))
                            .foregroundStyle(Stone.goldBright)
                            .shadow(color: Stone.goldBright.opacity(0.8), radius: 4)
                            .position(x: clouds[1].center.x + 3 * u, y: clouds[1].center.y + clouds[1].width * 0.45)
                    }
                case .snow:
                    Canvas { ctx, _ in
                        var rng = SeededRandom(9)
                        for c in clouds {
                            for _ in 0..<8 {
                                let x = c.center.x + CGFloat(rng.signed()) * c.width * 0.4
                                let y = c.center.y + c.width * 0.3 + CGFloat(rng.next()) * 16 * u
                                let r = (1.0 + CGFloat(rng.next()) * 0.7) * u
                                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Stone.moonlight))
                            }
                        }
                    }
                case .fog:
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(Color(hex: 0xA7B6AE).opacity(0.45))
                            .frame(width: size.width * (0.5 + 0.12 * CGFloat(i)), height: 5 * u)
                            .blur(radius: 2.5 * u)
                            .position(x: size.width * (0.42 + 0.08 * CGFloat(i)), y: arc.horizon * size.height - CGFloat(6 + 9 * i) * u)
                    }
                default:
                    EmptyView()
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ArcTrail: View {
    var arc: SkyArc

    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            for i in 0...48 {
                let pt = arc.point(Double(i) / 48, in: size)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            ctx.stroke(p, with: .color(Stone.gold.opacity(0.45)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [0.1, 4]))
        }
    }
}

// A painted sun: warm disc, brushed, in a wide soft halo.
struct SunDisc: View {
    var radius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Stone.goldBright.opacity(0.45), Stone.goldBright.opacity(0.12), .clear],
                                     center: .center, startRadius: radius * 0.8, endRadius: radius * 4))
                .frame(width: radius * 8, height: radius * 8)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF1CC), Color(hex: 0xF2C77E), Color(hex: 0xD6904E)],
                                     center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: radius * 1.15))
                .overlay(Image("PaintMoon").resizable().scaledToFill().opacity(0.22).clipShape(Circle()))
                .shadow(color: Color(hex: 0xF2C77E).opacity(0.7), radius: radius * 0.6)
                .frame(width: radius * 2, height: radius * 2)
        }
    }
}

// Tonight's moon in its real phase: painted lit part, the rest faintly visible, in a pale halo.
struct MoonDisc: View {
    var radius: CGFloat
    var phase: MoonPhase

    var body: some View {
        let lit = (1 - cos(2 * Double.pi * phase.fraction)) / 2
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Stone.moonlight.opacity(0.32 * (0.4 + lit)), Stone.moonlight.opacity(0.08), .clear],
                                     center: .center, startRadius: radius * 0.8, endRadius: radius * 4.2))
                .frame(width: radius * 8.4, height: radius * 8.4)
            ZStack {
                Circle().fill(Color(hex: 0x2A3638).opacity(0.28))
                Image("PaintMoon")
                    .resizable()
                    .scaledToFill()
                    .clipShape(MoonLitShape(phase: phase))
                    .shadow(color: Stone.moonlight.opacity(0.6), radius: radius * 0.35)
            }
            .frame(width: radius * 2, height: radius * 2)
        }
    }
}

// Stars across a region of the sky: a few four-pointed sparkles among small points.
struct Stars: View {
    var region: CGRect // unit coordinates of the widget
    var count: Int = 18
    var sparkles: Int = 4
    var seed: UInt64 = 3

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed)
            let u = size.width / 348
            for i in 0..<count {
                let x = (region.minX + CGFloat(rng.next()) * region.width) * size.width
                let y = (region.minY + CGFloat(rng.next()) * region.height) * size.height
                if i < sparkles {
                    let s = (5 + CGFloat(rng.next()) * 4) * u
                    let rect = CGRect(x: x - s / 2, y: y - s * 0.6, width: s, height: s * 1.2)
                    glow(ctx, at: CGPoint(x: x, y: y), radius: s * 1.3, color: Stone.goldBright, opacity: 0.28)
                    ctx.fill(Sparkle().path(in: rect), with: .color(Stone.goldBright.opacity(0.95)))
                } else {
                    let r = (0.5 + CGFloat(rng.next()) * 0.8) * u
                    glow(ctx, at: CGPoint(x: x, y: y), radius: r * 3.5, color: Stone.moonlight, opacity: 0.25)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Stone.moonlight.opacity(0.9)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glow(_ ctx: GraphicsContext, at c: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        let rect = CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
                                                             center: c, startRadius: 0, endRadius: radius))
    }
}

// A billowing cloud: shaded body laid in with brushwork, its upper rim lit by the sun or moon.
struct PaintedCloud: View {
    var night: Bool
    var gray: Bool
    var seed: Int = 0

    var body: some View {
        let colors: [Color] = night ? [Color(hex: 0x4A5552), Color(hex: 0x252E2F)]
            : (gray ? [Color(hex: 0x7A7D74), Color(hex: 0x494D48)] : [Color(hex: 0xB7AE94), Color(hex: 0x6D6D5E)])
        let rim = night ? Stone.moonlight : Stone.goldBright
        CloudShape()
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay(PaintRelief(name: "PaintSky", opacity: 0.9, flip: seed % 2 == 1).clipShape(CloudShape()))
            .overlay(
                CloudShape()
                    .stroke(LinearGradient(colors: [rim.opacity(gray ? 0.45 : 0.85), rim.opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)),
                            lineWidth: 2.2)
                    .blur(radius: 0.5)
                    .clipShape(CloudShape())
            )
            .shadow(color: Stone.shadow.opacity(0.45), radius: 2.5, x: 0, y: 1.5)
    }
}

struct CloudShape: Shape {
    func path(in r: CGRect) -> Path {
        let base = Path(roundedRect: CGRect(x: r.minX, y: r.minY + r.height * 0.52, width: r.width, height: r.height * 0.48),
                        cornerSize: CGSize(width: r.height * 0.24, height: r.height * 0.24))
        return base
            .union(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.30, width: r.width * 0.36, height: r.height * 0.62)))
            .union(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.30, y: r.minY, width: r.width * 0.44, height: r.height * 0.82)))
            .union(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.58, y: r.minY + r.height * 0.26, width: r.width * 0.32, height: r.height * 0.6)))
    }
}

// MARK: - Scenes

// The ridges' colours, far to near, and the settings app's range. The retired widgets' ridge layouts
// (Ridges.day and Ridges.quote) are in MockLab/PaintKit/RetiredGrounds.swift.
enum Ridges {
    static let far = (top: Color(hex: 0x5A6D67), bottom: Color(hex: 0x3D4F4A))
    static let mid = (top: Color(hex: 0x34463F), bottom: Color(hex: 0x263630))
    static let near = (top: Color(hex: 0x1E2A24), bottom: Color(hex: 0x141C18))

    // The settings app: a range across the top of the screen, low on the left under the large title.
    static let app: [MountainLayer] = [
        MountainLayer(profile: RidgeProfile(keys: [
            p(0, 0.175), p(0.12, 0.170), p(0.26, 0.172), p(0.38, 0.150), p(0.48, 0.118), p(0.56, 0.128), p(0.64, 0.092),
            p(0.72, 0.120), p(0.80, 0.108), p(0.90, 0.135), p(1, 0.128)], seed: 81),
                      top: far.top, bottom: far.bottom, rim: 0.6, snowline: 0.128),
        MountainLayer(profile: RidgeProfile(keys: [
            p(0, 0.192), p(0.15, 0.186), p(0.30, 0.190), p(0.42, 0.165), p(0.55, 0.172), p(0.68, 0.150), p(0.82, 0.170),
            p(1, 0.158)], seed: 83),
                      top: mid.top, bottom: mid.bottom, rim: 0.35, trees: Trees(height: 4...8, spacing: 5, coverage: 0.55)),
        MountainLayer(profile: RidgeProfile(keys: [
            p(0, 0.205), p(0.2, 0.200), p(0.38, 0.204), p(0.52, 0.186), p(0.7, 0.196), p(0.86, 0.182), p(1, 0.19)], seed: 87),
                      top: near.top, bottom: near.bottom, rim: 0.25, trees: Trees(height: 7...12, spacing: 5, coverage: 0.8))
    ]

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}
