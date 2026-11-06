import SwiftUI

// The poster's picture, pulled as a screen print in one Canvas: a printed sky (flat bands with halftone screens
// between them), the live sun or moon disc on its arc behind the peak, weather printed as cloud shapes, diagonal rain
// lines or snow dots, the Matterhorn in five inks with its snow, and the alpine foreground. Each ink is a flat shape;
// the paper shows through slivers where a colour is a little out of register.

/// Where everything sits on one widget size (points).
struct TPStage {
    var size: CGSize
    var summit: CGPoint
    var height: CGFloat          // the pyramid, summit to the foot of the left face
    var skyBottom: CGFloat       // the sky's bands are spread down to here
    var arcCentreX: CGFloat      // the sun's arc: from the left horizon, up over the peak, down to the right
    var arcRadius: CGSize
    var horizon: CGFloat
    var disc: CGFloat            // the disc's radius
    var pitch: CGFloat           // the halftone screen
    var meadow: [CGPoint]        // the near hill's crest, left to right
    var field: [CGPoint]         // the nearest hill's crest (it carries the type)
    var spruce: [(x0: CGFloat, x1: CGFloat, count: Int, h0: CGFloat, h1: CGFloat)]
    var clouds: [CGRect]         // partly cloudy: where the two cloud shapes sit
    var ceiling: CGFloat         // overcast: the cloud ceiling's lowest scallop
    var mist: CGFloat            // fog: the mist bank's centre line
    var seed: UInt64

    func sunCentre(_ progress: Double) -> CGPoint {
        let a = Double.pi * min(1, max(0, progress))
        return CGPoint(x: arcCentreX - arcRadius.width * CGFloat(cos(a)), y: horizon - arcRadius.height * CGFloat(sin(a)))
    }
}

struct TPPrint: View {
    var stage: TPStage
    var inks: TPInks
    var clock: SkyClock
    var condition: SkyCondition
    var date: Date
    var showsArc: Bool = true
    var showsDisc: Bool = true

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let mountain = TPMountain(summit: stage.summit, height: stage.height, size: size, seed: stage.seed)
            drawSky(&ctx, size)
            if inks.isNight { drawStars(&ctx, size) }
            if showsArc { drawArc(&ctx) }
            if showsDisc { drawDisc(&ctx) }
            if condition.gray && condition != .fog { drawCeiling(&ctx, size) }
            if condition == .partly { drawClouds(&ctx) }
            drawMountain(&ctx, mountain)
            if condition == .fog { drawMist(&ctx, size) }
            drawForeground(&ctx, size)
            if condition == .storm { drawBolt(&ctx) }
            if condition == .rain || condition == .storm || condition == .snow {
                // Full strength over the sky and the mountain, faint over the field that carries the type.
                let field = crest(stage.field, down: size.height + 4, width: size.width)
                let open = Path(CGRect(x: -4, y: -4, width: size.width + 8, height: size.height + 8)).subtracting(field)
                ctx.drawLayer { l in
                    l.clip(to: open)
                    condition == .snow ? drawSnow(&l, size) : drawRain(&l, size)
                }
                ctx.drawLayer { l in
                    l.clip(to: field)
                    l.opacity = 0.3
                    condition == .snow ? drawSnow(&l, size) : drawRain(&l, size)
                }
            }
        }
        .overlay {
            // Starved ink: the paper colour laid back through a dry litho grain over every ink field.
            Mock.texture("weather-poster/litho")
                .renderingMode(.template)
                .resizable(resizingMode: .tile)
                .foregroundStyle(inks.paper.color)
                .opacity(inks.isNight ? 0.45 : 0.75)
        }
    }

    // MARK: Sky

    private func bandEdges() -> [CGFloat] { [0, 0.36, 0.58, 0.75, 0.88].map { $0 * stage.skyBottom } }

    private func drawSky(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let edges = bandEdges()
        for i in edges.indices {
            let top = edges[i], bottom = i + 1 < edges.count ? edges[i + 1] : size.height
            ctx.fill(Path(CGRect(x: 0, y: top, width: size.width, height: bottom - top + 0.5)), with: .color(inks.sky[i].color))
        }
        // The halftone screens between bands: dots of the band above, shrinking to nothing.
        for i in 1..<edges.count {
            let y0 = edges[i]
            let next = i + 1 < edges.count ? edges[i + 1] : stage.skyBottom + 30
            let depth = min(stage.pitch * 5.5, (next - y0) * 0.8)
            let rMax = stage.pitch * 0.62
            let dots = tpHalftone(in: CGRect(x: 0, y: y0 - stage.pitch, width: size.width, height: depth + stage.pitch), pitch: stage.pitch) { c in
                let t = max(0, min(1, (c.y - y0) / depth))
                return rMax * pow(1 - t, 0.9)
            }
            ctx.fill(dots, with: .color(inks.sky[i - 1].color))
        }
    }

    private func drawStars(_ ctx: inout GraphicsContext, _ size: CGSize) {
        var rng = TPRandom(stage.seed &+ 77)
        var dots = Path(), sparkles = Path()
        let count = Int(size.width * stage.skyBottom / 900)
        for i in 0..<count {
            let x = rng.range(4, size.width - 4)
            let y = rng.range(4, stage.skyBottom * 0.8) * rng.range(0.55, 1)
            if i % 9 == 0 {
                let r = rng.range(2.2, 3.4)
                var s = Path()
                s.move(to: CGPoint(x: x, y: y - r))
                s.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x + r * 0.16, y: y - r * 0.16))
                s.addQuadCurve(to: CGPoint(x: x, y: y + r), control: CGPoint(x: x + r * 0.16, y: y + r * 0.16))
                s.addQuadCurve(to: CGPoint(x: x - r, y: y), control: CGPoint(x: x - r * 0.16, y: y + r * 0.16))
                s.addQuadCurve(to: CGPoint(x: x, y: y - r), control: CGPoint(x: x - r * 0.16, y: y - r * 0.16))
                sparkles.addPath(s)
            } else {
                let r = rng.range(0.45, 0.95)
                dots.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
            }
        }
        ctx.fill(dots, with: .color(inks.disc.color.opacity(0.85)))
        ctx.fill(sparkles, with: .color(inks.disc.color))
    }

    // MARK: The sun or moon on its arc

    private func drawArc(_ ctx: inout GraphicsContext) {
        var arc = Path()
        let steps = 60
        for i in 0...steps {
            let pt = stage.sunCentre(Double(i) / Double(steps))
            if i == 0 { arc.move(to: pt) } else { arc.addLine(to: pt) }
        }
        let ink = inks.isNight ? inks.disc : inks.title
        ctx.stroke(arc, with: .color(ink.color.opacity(inks.isNight ? 0.34 : 0.42)),
                   style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [0.1, 3.6]))
    }

    private func drawDisc(_ ctx: inout GraphicsContext) {
        let c = stage.sunCentre(clock.progress)
        let r = stage.disc
        let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
        let disc = Path(ellipseIn: rect)
        // Out of register: the paper shows in a sliver on the upper left.
        let slip = max(0.7, r * 0.035)
        ctx.fill(Path(ellipseIn: rect.offsetBy(dx: -slip, dy: -slip * 0.8)), with: .color(inks.paper.color))
        if inks.isNight {
            // The moon: the whole disc in a pale earthshine ink, the lit part in cream on top.
            let phase = MoonPhase(date: date)
            ctx.fill(disc, with: .color(inks.disc.mix(inks.sky[4], 0.66).mix(TPRGB(0x5C78A0), 0.25).color))
            let lit = MoonLitShape(phase: phase).path(in: rect)
            ctx.fill(lit, with: .color(inks.disc.color))
            ctx.drawLayer { l in
                l.clip(to: lit)
                var rng = TPRandom(stage.seed &+ 11)
                var maria = Path()
                for _ in 0..<5 {
                    let a = rng.range(0, 2 * .pi), d = rng.range(0, 0.55) * r, s = rng.range(0.12, 0.26) * r
                    maria.addEllipse(in: CGRect(x: c.x + cos(a) * d - s, y: c.y + sin(a) * d - s, width: 2 * s, height: 2 * s * 0.85))
                }
                l.fill(maria, with: .color(inks.discShade.color.opacity(0.7)))
            }
        } else {
            ctx.fill(disc, with: .color(inks.disc.color))
            // A halftone screen of a deeper red across the lower right: the disc is printed, not a flat circle.
            ctx.drawLayer { l in
                l.clip(to: disc)
                let pitch = max(2.4, stage.pitch * 0.9)
                let dots = tpHalftone(in: rect.insetBy(dx: -pitch, dy: -pitch), pitch: pitch) { q in
                    let t = ((q.x - c.x) * 0.6 + (q.y - c.y) * 0.8) / r
                    return pitch * 0.58 * max(0, min(1, (t + 0.1) / 1.0))
                }
                l.fill(dots, with: .color(inks.discShade.color))
            }
        }
    }

    // MARK: Weather

    private func cloudShape(in rect: CGRect) -> Path {
        // A poster cloud: a flat base and three or four round tops.
        var p = Path()
        let h = rect.height, w = rect.width
        p.addRoundedRect(in: CGRect(x: rect.minX, y: rect.maxY - h * 0.42, width: w, height: h * 0.42), cornerSize: CGSize(width: h * 0.21, height: h * 0.21))
        let bumps: [(CGFloat, CGFloat)] = [(0.24, 0.36), (0.47, 0.5), (0.72, 0.38)]
        for (fx, fr) in bumps {
            let rr = h * fr * 1.25
            p.addEllipse(in: CGRect(x: rect.minX + w * fx - rr, y: rect.maxY - h * 0.3 - rr * 1.55, width: 2 * rr, height: 2 * rr))
        }
        return p
    }

    private func drawClouds(_ ctx: inout GraphicsContext) {
        for rect in stage.clouds {
            let shape = cloudShape(in: rect)
            ctx.fill(cloudShape(in: rect.offsetBy(dx: 0.8, dy: 0.7)), with: .color(inks.paper.color))
            ctx.fill(shape, with: .color(inks.cloud.color))
            ctx.drawLayer { l in
                l.clip(to: shape)
                l.fill(Path(CGRect(x: rect.minX - 2, y: rect.maxY - rect.height * 0.26, width: rect.width + 4, height: rect.height)),
                       with: .color(inks.cloudShade.color))
            }
        }
    }

    /// Grey weather: a cloud ceiling with a scalloped underside, in two inks.
    private func drawCeiling(_ ctx: inout GraphicsContext, _ size: CGSize) {
        func ceiling(_ base: CGFloat, scallop: CGFloat, phase: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: -4, y: -4))
            p.addLine(to: CGPoint(x: -4, y: base))
            var x: CGFloat = -4 - phase
            var i = 0
            while x < size.width + 4 {
                let w = scallop * (i % 3 == 1 ? 1.3 : 0.9)
                let lift = scallop * (i % 2 == 0 ? 0.55 : 0.75)
                p.addQuadCurve(to: CGPoint(x: x + w, y: base - (i % 3 == 2 ? scallop * 0.2 : 0)),
                               control: CGPoint(x: x + w / 2, y: base + lift))
                x += w
                i += 1
            }
            p.addLine(to: CGPoint(x: size.width + 4, y: -4))
            p.closeSubpath()
            return p
        }
        let deep = condition == .storm || condition == .rain
        let upper = inks.sky[0].mix(inks.paper.muted(0.6), inks.isNight ? 0.05 : (deep ? 0.08 : 0.2))
        let lower = inks.sky[1].mix(inks.paper.muted(0.4), inks.isNight ? 0.1 : (deep ? 0.22 : 0.38))
        let s = stage.size.width / 9
        ctx.fill(ceiling(stage.ceiling + 1, scallop: s, phase: s * 0.3), with: .color(inks.paper.color))
        ctx.fill(ceiling(stage.ceiling, scallop: s, phase: s * 0.3), with: .color(lower.color))
        ctx.fill(ceiling(stage.ceiling * 0.62, scallop: s * 0.8, phase: s * 0.75), with: .color(upper.color))
    }

    /// Fog: a pale bank pulled across the mountain's foot, its top edge broken into a halftone.
    private func drawMist(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let ink = inks.paper.mix(inks.sky[4], 0.45)
        let top = stage.mist, fade = stage.height * 0.22
        ctx.fill(Path(CGRect(x: -4, y: top, width: size.width + 8, height: size.height)), with: .color(ink.color.opacity(0.86)))
        let dots = tpHalftone(in: CGRect(x: 0, y: top - fade, width: size.width, height: fade + 2), pitch: stage.pitch) { q in
            stage.pitch * 0.62 * pow(max(0, min(1, (q.y - (top - fade)) / fade)), 1.2)
        }
        ctx.fill(dots, with: .color(ink.color.opacity(0.86)))
    }

    private func drawRain(_ ctx: inout GraphicsContext, _ size: CGSize) {
        var rng = TPRandom(stage.seed &+ 21)
        var lines = Path()
        let gap: CGFloat = 5.2
        let slope: CGFloat = 0.36  // falls to the left as it goes down
        var x0: CGFloat = -size.height * slope
        while x0 < size.width + 10 {
            var y = rng.range(-20, 0)
            while y < size.height {
                let len = rng.range(7, 16)
                let start = CGPoint(x: x0 + (size.height - y) * slope, y: y)
                lines.move(to: start)
                lines.addLine(to: CGPoint(x: start.x - len * slope, y: y + len))
                y += len + rng.range(4, 12)
            }
            x0 += gap + rng.range(-0.8, 0.8)
        }
        ctx.stroke(lines, with: .color(inks.weather.color.opacity(0.5)), style: StrokeStyle(lineWidth: 0.85, lineCap: .round))
    }

    private func drawBolt(_ ctx: inout GraphicsContext) {
        let x = stage.summit.x + stage.height * 0.62, y = stage.ceiling - 2
        let u = stage.height * 0.06
        var b = Path()
        b.move(to: CGPoint(x: x, y: y))
        b.addLine(to: CGPoint(x: x - u * 1.4, y: y + u * 3))
        b.addLine(to: CGPoint(x: x - u * 0.2, y: y + u * 2.8))
        b.addLine(to: CGPoint(x: x - u * 1.5, y: y + u * 6))
        b.addLine(to: CGPoint(x: x + u * 0.9, y: y + u * 2.2))
        b.addLine(to: CGPoint(x: x - u * 0.3, y: y + u * 2.4))
        b.addLine(to: CGPoint(x: x + u * 0.8, y: y))
        b.closeSubpath()
        ctx.fill(b, with: .color(TPRGB(0xF2C14E).color))
    }

    private func drawSnow(_ ctx: inout GraphicsContext, _ size: CGSize) {
        var rng = TPRandom(stage.seed &+ 33)
        var flakes = Path()
        let k = min(1, stage.pitch / 3.4)   // flakes shrink with the print
        let pitch: CGFloat = 8.5 * (0.6 + 0.4 * k)
        var y: CGFloat = 2
        var row = 0
        while y < size.height {
            var x: CGFloat = row % 2 == 0 ? 2 : pitch / 2 + 2
            while x < size.width {
                let r = rng.range(0.7, 1.55) * k
                let j = CGPoint(x: x + rng.range(-2.2, 2.2), y: y + rng.range(-2.2, 2.2))
                flakes.addEllipse(in: CGRect(x: j.x - r, y: j.y - r, width: 2 * r, height: 2 * r))
                x += pitch
            }
            y += pitch * 0.8
            row += 1
        }
        ctx.fill(flakes, with: .color(inks.weather.color.opacity(0.88)))
    }

    // MARK: The Matterhorn

    private func drawMountain(_ ctx: inout GraphicsContext, _ m: TPMountain) {
        // Out of register: the sky's knockout sits a little right of the mountain, so paper shows along its right
        // hand slopes.
        ctx.drawLayer { l in
            l.translateBy(x: 0.9, y: 0.5)
            l.fill(m.land, with: .color(inks.paper.color))
        }
        ctx.fill(m.land, with: .color(inks.ridge.color))
        ctx.fill(m.ridgeShade, with: .color(inks.ridgeShade.color))
        ctx.fill(m.ridgeSnow, with: .color(inks.ridgeSnow.color))
        ctx.fill(m.pyramid, with: .color(inks.east.color))
        ctx.fill(m.northFace, with: .color(inks.north.color))
        ctx.fill(m.shadowFace, with: .color(inks.shade.color))
        ctx.fill(m.band, with: .color(inks.band.color))
        // A halftone across the foot of the shadowed face, darkening into the valley.
        ctx.drawLayer { l in
            l.clip(to: m.shadowFace)
            let top = stage.summit.y + stage.height * 0.35, bottom = stage.summit.y + stage.height * 1.15
            let dots = tpHalftone(in: CGRect(x: 0, y: top, width: stage.size.width, height: bottom - top), pitch: stage.pitch) { q in
                stage.pitch * 0.55 * max(0, min(1, (q.y - top) / (bottom - top)))
            }
            l.fill(dots, with: .color(inks.ridgeShade.mix(inks.forest, 0.3).color))
        }
        // Volume on the lit face: a screen of the band's ink gathering toward the shadow's edge.
        ctx.drawLayer { l in
            l.clip(to: m.eastFace)
            let H = stage.height, s = stage.summit
            let dots = tpHalftone(in: CGRect(x: s.x - H * 0.6, y: s.y, width: H * 1.4, height: H * 1.4), pitch: stage.pitch) { q in
                let u = (q.x - s.x) / H, v = (q.y - s.y) / H
                let d = (u - TPPeak.shadowLine(v)) / 0.3
                let fall = max(0, 1 - d) * (0.55 + 0.45 * min(1, v / 0.6))
                return stage.pitch * 0.56 * fall * fall
            }
            l.fill(dots, with: .color(inks.east.mix(inks.band, 0.42).color))
        }
        ctx.fill(m.rock, with: .color(inks.rock.color))
        ctx.fill(m.ledges, with: .color(inks.ledge.color))
        ctx.fill(m.crest, with: .color(inks.crest.color))
    }

    // MARK: Foreground

    private func crest(_ pts: [CGPoint], down to: CGFloat, width: CGFloat) -> Path {
        var p = Path()
        guard pts.count > 1 else { return p }
        p.move(to: CGPoint(x: -4, y: to))
        p.addLine(to: CGPoint(x: -4, y: pts[0].y))
        p.addLine(to: pts[0])
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: c1, control2: c2)
        }
        p.addLine(to: CGPoint(x: width + 4, y: pts[pts.count - 1].y))
        p.addLine(to: CGPoint(x: width + 4, y: to))
        p.closeSubpath()
        return p
    }

    private func crestY(_ pts: [CGPoint], at x: CGFloat) -> CGFloat {
        tpInterp(x, pts.map(\.x), pts.map(\.y))
    }

    private func drawForeground(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let meadow = crest(stage.meadow, down: size.height + 4, width: size.width)
        ctx.drawLayer { l in
            l.translateBy(x: -0.8, y: -0.6)
            l.fill(meadow, with: .color(inks.paper.color))
        }
        // Spruce on the meadow's crest, in the forest ink, a stand of tiered spires.
        var rng = TPRandom(stage.seed &+ 3)
        var trees = Path()
        for stand in stage.spruce {
            for k in 0..<stand.count {
                let x = stand.x0 + (stand.x1 - stand.x0) * (CGFloat(k) + rng.range(0.1, 0.9)) / CGFloat(stand.count)
                let h = rng.range(stand.h0, stand.h1)
                let base = crestY(stage.meadow, at: x) + h * 0.12
                TPPrint.spruce(&trees, x: x, base: base, height: h, rng: &rng)
            }
        }
        ctx.fill(trees, with: .color(inks.forest.color))
        ctx.fill(meadow, with: .color(inks.meadow.color))
        // The meadow darkens into the field below through a halftone.
        let field = crest(stage.field, down: size.height + 4, width: size.width)
        ctx.drawLayer { l in
            l.clip(to: meadow)
            let top = (stage.meadow.map(\.y).min() ?? 0)
            let bottom = (stage.field.map(\.y).max() ?? size.height)
            let dots = tpHalftone(in: CGRect(x: 0, y: top, width: size.width, height: bottom - top), pitch: stage.pitch) { q in
                let c = crestY(stage.field, at: q.x), t = crestY(stage.meadow, at: q.x)
                let f = max(0, min(1, (q.y - t) / max(1, c - t)))
                return stage.pitch * 0.6 * f * f
            }
            l.fill(dots, with: .color(inks.field.color))
        }
        ctx.fill(field, with: .color(inks.field.color))
    }

    static func spruce(_ path: inout Path, x: CGFloat, base: CGFloat, height h: CGFloat, rng: inout TPRandom) {
        let w = h * rng.range(0.3, 0.38)
        let tiers = 4
        var p = Path()
        p.move(to: CGPoint(x: x, y: base - h))
        for t in 1...tiers {
            let f = CGFloat(t) / CGFloat(tiers)
            let y = base - h + h * f * 0.9
            let half = w / 2 * (0.35 + 0.65 * f)
            p.addLine(to: CGPoint(x: x + half, y: y))
            if t < tiers { p.addLine(to: CGPoint(x: x + half * 0.42, y: y - h * 0.035)) }
        }
        p.addLine(to: CGPoint(x: x + w * 0.06, y: base))
        p.addLine(to: CGPoint(x: x - w * 0.06, y: base))
        for t in stride(from: tiers, through: 1, by: -1) {
            let f = CGFloat(t) / CGFloat(tiers)
            let y = base - h + h * f * 0.9
            let half = w / 2 * (0.35 + 0.65 * f)
            if t < tiers { p.addLine(to: CGPoint(x: x - half * 0.42, y: y - h * 0.035)) }
            p.addLine(to: CGPoint(x: x - half, y: y))
        }
        p.closeSubpath()
        path.addPath(p)
    }
}

/// The paper the poster is printed on, multiplied over everything (type included), and its aged edges.
struct TPPaper: View {
    var body: some View {
        Mock.texture("weather-poster/paper")
            .resizable(resizingMode: .tile)
            .overlay {
                EllipticalGradient(colors: [.white, Color(red: 0.93, green: 0.89, blue: 0.82)], center: .center,
                                   startRadiusFraction: 0.5, endRadiusFraction: 0.78)
                    .blendMode(.multiply)
            }
            .compositingGroup()
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}
