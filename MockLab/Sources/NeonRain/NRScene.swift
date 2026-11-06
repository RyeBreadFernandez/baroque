import SwiftUI

// The night street at the foot of the mountains, painted back to front in one Canvas:
// sky with the city's sodium glow -> far ridge in mist -> cloud caught on the peaks -> mid ridge, wet, lit from
// below by neon, a road of lamps climbing it, hillside windows, a radio mast -> mist band -> the city's low blocks,
// lit windows and small neon signs (or, in shallow focus, bokeh) -> the wet street and its rippled reflections.
// The whole street is turned a few degrees, as a wide-angle lens held off level.

struct NRSign {
    enum Kind { case vbar, box, ring, arrow, zigzag, bars, cup }
    var at: CGPoint                 // unit coordinates of the scene rect (centre of the sign)
    var kind: Kind
    var color: Color
    var core: Color
    var scale: CGFloat = 1
    var dim: Bool = false
}

struct NRSceneSpec {
    var far: [CGPoint]
    var mid: [CGPoint]
    var near: [CGPoint]? = nil
    var city: ClosedRange<CGFloat>          // unit y range for the building tops
    var street: CGFloat                     // unit y where the street begins
    var mast: CGFloat? = nil                // unit x of the radio mast, standing on the mid ridge
    var lamps: [CGPoint] = []               // the switchback road of lamps on the mid ridge
    var houses: Int = 70                    // lit windows climbing the hillside
    var signs: [NRSign] = []
    var lights: [NRLight] = []              // extra lights for the street to reflect (the widget's own neon)
    var weather: NRWeather = .clear
    var soft: Bool = false                  // shallow focus: the city melts into bokeh
    var smear: Bool = true                  // step-printed car lights on the street
    var moon: CGPoint? = nil
    var seed: UInt64 = 1
    var tilt: Double = -2.4
    var peakCloud: CGFloat = 1              // how much cloud catches on the peaks
}

enum NRScene {
    // MARK: Geometry

    static func ridgeLine(_ keys: [CGPoint], in r: CGRect, seed: UInt64, rough: CGFloat) -> [CGPoint] {
        var rng = SeededRandom(seed: seed)
        var pts = keys.map { CGPoint(x: r.minX + $0.x * r.width, y: r.minY + $0.y * r.height) }
        for level in 0..<5 {
            var out: [CGPoint] = [pts[0]]
            let k = rough * pow(0.62, CGFloat(level))
            for i in 1..<pts.count {
                let a = pts[i - 1], b = pts[i]
                let len = hypot(b.x - a.x, b.y - a.y)
                let m = CGPoint(x: (a.x + b.x) / 2 + rng.range(-0.06...0.06) * len,
                                y: (a.y + b.y) / 2 + rng.range(-1...1) * len * k)
                out.append(m)
                out.append(b)
            }
            pts = out
        }
        return pts
    }

    static func ridgeY(_ line: [CGPoint], at x: CGFloat) -> CGFloat {
        guard let first = line.first, let last = line.last else { return 0 }
        if x <= first.x { return first.y }
        if x >= last.x { return last.y }
        for i in 1..<line.count where line[i].x >= x {
            let a = line[i - 1], b = line[i]
            let f = (x - a.x) / max(b.x - a.x, 0.0001)
            return a.y + (b.y - a.y) * f
        }
        return last.y
    }

    static func fillPath(_ line: [CGPoint], bottom: CGFloat, pad: CGFloat) -> Path {
        var p = Path()
        guard let first = line.first, let last = line.last else { return p }
        p.move(to: CGPoint(x: first.x - pad, y: bottom))
        p.addLine(to: CGPoint(x: first.x - pad, y: first.y))
        for q in line { p.addLine(to: q) }
        p.addLine(to: CGPoint(x: last.x + pad, y: last.y))
        p.addLine(to: CGPoint(x: last.x + pad, y: bottom))
        p.closeSubpath()
        return p
    }

    /// Local peaks (smallest y) of a ridge, highest first.
    static func peaks(_ line: [CGPoint], count: Int, minGap: CGFloat) -> [CGPoint] {
        var out: [CGPoint] = []
        for p in line.sorted(by: { $0.y < $1.y }) {
            if out.allSatisfy({ abs($0.x - p.x) > minGap }) { out.append(p) }
            if out.count == count { break }
        }
        return out
    }

    // MARK: Paint

    static func paint(_ base: GraphicsContext, size: CGSize, spec: NRSceneSpec) {
        var ctx = base
        let R = CGRect(origin: .zero, size: size)
        let X = R.insetBy(dx: -50, dy: -50)
        ctx.translateBy(x: R.midX, y: R.midY)
        ctx.rotate(by: .degrees(spec.tilt))
        ctx.translateBy(x: -R.midX, y: -R.midY)

        let streetY = R.minY + spec.street * R.height
        let far = ridgeLine(spec.far, in: R, seed: spec.seed &+ 1, rough: 0.16)
        let mid = ridgeLine(spec.mid, in: R, seed: spec.seed &+ 2, rough: 0.2)

        sky(ctx, R: R, X: X, spec: spec, streetY: streetY)
        farRidge(ctx, R: R, X: X, line: far, spec: spec, streetY: streetY)
        peakCloud(ctx, R: R, line: far, spec: spec, scale: 0.8, seed: 3)
        midRidge(ctx, R: R, X: X, line: mid, spec: spec, streetY: streetY)
        peakCloud(ctx, R: R, line: mid, spec: spec, scale: 1, seed: 4)
        if let near = spec.near {
            let line = ridgeLine(near, in: R, seed: spec.seed &+ 5, rough: 0.12)
            nearRidge(ctx, R: R, line: line, spec: spec, streetY: streetY)
        }
        mistBand(ctx, R: R, X: X, spec: spec, streetY: streetY)
        if spec.soft { bokehCity(ctx, R: R, spec: spec, streetY: streetY) } else { city(ctx, R: R, spec: spec, streetY: streetY) }
        street(ctx, R: R, X: X, spec: spec, streetY: streetY)
        weather(ctx, R: R, X: X, spec: spec, streetY: streetY)
    }

    // MARK: Sky

    static func sky(_ ctx: GraphicsContext, R: CGRect, X: CGRect, spec: NRSceneSpec, streetY: CGFloat) {
        let cityTop = R.minY + spec.city.lowerBound * R.height
        let horizonF = max(0.2, min(0.95, (cityTop - X.minY) / X.height))
        let haze: Color = spec.weather == .fog ? Color(hex: 0x4A655E) : Color(hex: 0x30483F)
        ctx.fill(Path(X), with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(hex: 0x020605), location: 0),
                .init(color: Color(hex: 0x081a18), location: horizonF * 0.3),
                .init(color: Color(hex: 0x173a35), location: horizonF * 0.62),
                .init(color: haze, location: horizonF * 0.9),
                .init(color: Color(hex: 0x4E4630), location: min(1, horizonF + 0.05)),
                .init(color: Color(hex: 0x0A1010), location: 1)
            ]),
            startPoint: CGPoint(x: X.midX, y: X.minY), endPoint: CGPoint(x: X.midX, y: X.maxY)))

        // City glow on the low cloud: sodium in the middle, magenta and a cold cyan off to the sides.
        var add = ctx
        add.blendMode = .screen
        let glowY = cityTop + R.height * 0.04
        for (x, c, o, k) in [(0.5, NR.sodium, 0.36, 0.75), (0.18, NR.magenta, 0.24, 0.45), (0.86, NR.cyan, 0.14, 0.4)] as [(CGFloat, Color, Double, CGFloat)] {
            let rx = R.width * k, ry = R.height * 0.32
            add.drawLayer { l in
                l.translateBy(x: R.minX + x * R.width, y: glowY)
                l.scaleBy(x: 1, y: ry / rx)
                l.fill(Path(ellipseIn: CGRect(x: -rx, y: -rx, width: rx * 2, height: rx * 2)),
                       with: .radialGradient(Gradient(colors: [c.opacity(o), c.opacity(o * 0.35), .clear]),
                                             center: .zero, startRadius: 0, endRadius: rx))
            }
        }

        var rng = SeededRandom(seed: spec.seed &+ 40)
        if spec.weather == .clear {
            // A few stars between the clouds, dulled by the city.
            for _ in 0..<Int(R.width * 0.12) {
                let p = CGPoint(x: R.minX + rng.unit() * R.width, y: R.minY + rng.unit() * (cityTop - R.minY) * 0.55)
                let r = rng.range(0.25...0.6)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(NR.tealPale.opacity(Double(rng.range(0.25...0.7)))))
            }
        }
        if let m = spec.moon, spec.weather == .clear || spec.weather == .cloudy {
            let c = CGPoint(x: R.minX + m.x * R.width, y: R.minY + m.y * R.height)
            let r: CGFloat = 6.5
            add.drawLayer { l in
                l.addFilter(.blur(radius: 10))
                l.fill(Path(ellipseIn: CGRect(x: c.x - r * 3.4, y: c.y - r * 3.4, width: r * 6.8, height: r * 6.8)), with: .color(Color(hex: 0xB9D7C8).opacity(0.45)))
                l.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.8, y: c.y - r * 1.8, width: r * 3.6, height: r * 3.6)), with: .color(Color(hex: 0xE8F0DA).opacity(0.4)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xF4F1DA), Color(hex: 0xCFD8C0)]), center: CGPoint(x: c.x - 1.5, y: c.y - 1.5), startRadius: 0, endRadius: r))
            // Thin cloud dragging across it.
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: r * 0.45))
                l.opacity = 0.6
                l.fill(Path(ellipseIn: CGRect(x: c.x - r * 3.2, y: c.y + r * 0.05, width: r * 5.6, height: r * 0.8)), with: .color(Color(hex: 0x1D3533)))
                l.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.6, y: c.y - r * 0.7, width: r * 3.4, height: r * 0.5)), with: .color(Color(hex: 0x24403C)))
            }
        }

        // Low cloud lit from beneath.
        var cloud = ctx.resolve(Mock.texture("neon-rain/mist").renderingMode(.template))
        cloud.shading = .color(Color(hex: 0x3F7E6C))
        var cl = ctx
        cl.blendMode = .screen
        cl.opacity = spec.weather == .cloudy || spec.weather == .rain ? 0.55 : 0.3
        cl.draw(cloud, in: CGRect(x: R.minX - 30, y: R.minY - R.height * 0.08, width: R.width + 60, height: max(60, (cityTop - R.minY) * 0.85)))
        cloud.shading = .color(Color(hex: 0xD08A44))
        cl.opacity = 0.24
        cl.draw(cloud, in: CGRect(x: R.minX - 30, y: R.minY + (cityTop - R.minY) * 0.15, width: R.width + 60, height: max(50, (cityTop - R.minY) * 0.75)))
    }

    // MARK: Ridges

    static func farRidge(_ ctx: GraphicsContext, R: CGRect, X: CGRect, line: [CGPoint], spec: NRSceneSpec, streetY: CGFloat) {
        let path = fillPath(line, bottom: streetY + 10, pad: 60)
        let top = line.map(\.y).min() ?? R.minY
        ctx.fill(path, with: .linearGradient(Gradient(colors: [Color(hex: 0x132C2C), Color(hex: 0x1E3B38), Color(hex: 0x3A5C53)]),
                                             startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: streetY)))
        var tex = ctx
        tex.clip(to: path)
        tex.blendMode = .softLight
        tex.opacity = 0.5
        tex.draw(ctx.resolve(Mock.texture("neon-rain/rock")), in: CGRect(x: R.minX - 10, y: top - 4, width: R.width + 20, height: max(80, streetY - top + 10)))
        // Cool rim where the moonlit wet rock turns.
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 0.8))
            l.stroke(NRNeon.path(line), with: .color(NR.tealPale.opacity(0.3)), lineWidth: 0.9)
        }
        if spec.weather == .snow { snowcap(ctx, line: line, path: path, depth: (streetY - top) * 0.35) }
    }

    static func midRidge(_ ctx: GraphicsContext, R: CGRect, X: CGRect, line: [CGPoint], spec: NRSceneSpec, streetY: CGFloat) {
        let path = fillPath(line, bottom: streetY + 10, pad: 60)
        let top = line.map(\.y).min() ?? R.minY
        ctx.fill(path, with: .linearGradient(Gradient(colors: [Color(hex: 0x040B0B), Color(hex: 0x071211), Color(hex: 0x0E1716)]),
                                             startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: streetY)))
        var tex = ctx
        tex.clip(to: path)
        tex.blendMode = .softLight
        tex.opacity = 0.7
        tex.draw(ctx.resolve(Mock.texture("neon-rain/rock")), in: CGRect(x: R.minX - 20, y: top - 6, width: R.width + 40, height: max(90, streetY - top + 16)))

        // Neon glows up onto the undersides: magenta to one side, sodium to the other.
        var glow = ctx
        glow.clip(to: path)
        glow.blendMode = .screen
        let h = streetY - top
        glow.fill(Path(R.insetBy(dx: -60, dy: -60)), with: .linearGradient(
            Gradient(stops: [.init(color: .clear, location: 0), .init(color: NR.magenta.opacity(0.0), location: 0.35),
                             .init(color: NR.magenta.opacity(0.42), location: 0.78), .init(color: NR.red.opacity(0.6), location: 1)]),
            startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: streetY)))
        glow.drawLayer { l in
            l.addFilter(.blur(radius: 18))
            l.fill(Path(ellipseIn: CGRect(x: R.minX + R.width * 0.45, y: streetY - h * 0.55, width: R.width * 0.6, height: h * 0.9)),
                   with: .color(NR.sodium.opacity(0.35)))
            l.fill(Path(ellipseIn: CGRect(x: R.minX - R.width * 0.1, y: streetY - h * 0.45, width: R.width * 0.45, height: h * 0.8)),
                   with: .color(NR.magenta.opacity(0.4)))
        }
        // Wet rim catching the city's light.
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 0.7))
            l.stroke(NRNeon.path(line), with: .color(Color(hex: 0x8FC2B6).opacity(0.38)), lineWidth: 0.9)
        }
        if spec.weather == .snow { snowcap(ctx, line: line, path: path, depth: h * 0.3) }

        hillsideLights(ctx, R: R, line: line, path: path, spec: spec, streetY: streetY)
        if let mx = spec.mast { mast(ctx, at: R.minX + mx * R.width, line: line, R: R) }
    }

    static func nearRidge(_ ctx: GraphicsContext, R: CGRect, line: [CGPoint], spec: NRSceneSpec, streetY: CGFloat) {
        let path = fillPath(line, bottom: streetY + 10, pad: 60)
        let top = line.map(\.y).min() ?? R.minY
        ctx.fill(path, with: .linearGradient(Gradient(colors: [Color(hex: 0x050D0C), Color(hex: 0x081211)]),
                                             startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: streetY)))
        var tex = ctx
        tex.clip(to: path)
        tex.blendMode = .softLight
        tex.opacity = 0.6
        tex.draw(ctx.resolve(Mock.texture("neon-rain/rock")), in: CGRect(x: R.minX - 30, y: top - 10, width: R.width + 60, height: max(60, streetY - top + 20)))
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 0.8))
            l.stroke(NRNeon.path(line), with: .color(NR.magenta.opacity(0.4)), lineWidth: 1)
        }
    }

    static func snowcap(_ ctx: GraphicsContext, line: [CGPoint], path: Path, depth: CGFloat) {
        var c = ctx
        c.clip(to: path)
        var cap = Path()
        cap.move(to: line[0])
        for q in line { cap.addLine(to: q) }
        let top = line.map(\.y).min() ?? 0
        for q in line.reversed() {
            // The snowline sits at a near-constant altitude, wavering slowly.
            let snowline = top + depth * (0.75 + 0.18 * sin(q.x * 0.045) + 0.07 * sin(q.x * 0.13))
            cap.addLine(to: CGPoint(x: q.x, y: max(q.y + 1, snowline)))
        }
        cap.closeSubpath()
        c.fill(cap, with: .linearGradient(Gradient(colors: [Color(hex: 0xDCEBE6).opacity(0.75), Color(hex: 0xA9C6BE).opacity(0.35), Color(hex: 0x9FBDB5).opacity(0.0)]),
                                          startPoint: CGPoint(x: 0, y: (line.map(\.y).min() ?? 0)),
                                          endPoint: CGPoint(x: 0, y: (line.map(\.y).min() ?? 0) + depth * 1.2)))
    }

    static func peakCloud(_ ctx: GraphicsContext, R: CGRect, line: [CGPoint], spec: NRSceneSpec, scale: CGFloat, seed: UInt64) {
        guard spec.peakCloud > 0 else { return }
        var img = ctx.resolve(Mock.texture("neon-rain/mist").renderingMode(.template))
        var c = ctx
        c.blendMode = .screen
        let extra: CGFloat = spec.weather == .cloudy || spec.weather == .fog ? 1.5 : 1
        for (i, p) in peaks(line, count: 2, minGap: R.width * 0.25).enumerated() {
            let w = max(70, R.width * 0.36) * scale, h = max(26, R.height * 0.13) * scale
            let rect = CGRect(x: p.x - w * (i == 0 ? 0.62 : 0.38), y: p.y - h * 0.18, width: w, height: h)
            img.shading = .color(Color(hex: 0xB4D2C8))
            c.opacity = Double(0.6 * spec.peakCloud * extra)
            c.draw(img, in: rect)
            // Lit from beneath by the city.
            img.shading = .color(NR.sodium)
            c.opacity = Double(0.18 * spec.peakCloud)
            c.draw(img, in: rect.offsetBy(dx: 0, dy: h * 0.25))
        }
    }

    /// Windows climbing the hillside in clusters, and the switchback road of sodium lamps.
    static func hillsideLights(_ ctx: GraphicsContext, R: CGRect, line: [CGPoint], path: Path, spec: NRSceneSpec, streetY: CGFloat) {
        var rng = SeededRandom(seed: spec.seed &+ 60)
        var warm = Path(), cold = Path(), pink = Path()
        let centres = (0..<5).map { _ in rng.unit() }
        for _ in 0..<(spec.soft ? spec.houses / 2 : spec.houses) {
            // Cluster around a few villages, denser toward the foot of the slope.
            let cx = centres[Int(rng.unit() * 4.99)]
            let x = R.minX + (cx + rng.range(-0.09...0.09)) * R.width
            let ry = ridgeY(line, at: x)
            let depth = streetY - ry
            guard depth > 8 else { continue }
            let y = ry + depth * (0.28 + 0.72 * pow(rng.unit(), 0.55))
            guard y < streetY - 2 else { continue }
            let rect = CGRect(x: x, y: y, width: rng.range(0.7...1.4), height: rng.range(0.55...0.9))
            let pick = rng.unit()
            if pick < 0.62 { warm.addRect(rect) } else if pick < 0.9 { cold.addRect(rect) } else { pink.addRect(rect) }
        }
        var road = Path()
        if spec.lamps.count > 1 {
            let pts = spec.lamps.map { CGPoint(x: R.minX + $0.x * R.width, y: R.minY + $0.y * R.height) }
            var total: CGFloat = 0
            for i in 1..<pts.count { total += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y) }
            let n = Int(total / 4.2)
            for i in 0...max(1, n) {
                let (p, _) = NRNeon.sample(pts, at: CGFloat(i) / CGFloat(max(1, n)))
                let r: CGFloat = 0.62
                road.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            }
        }
        var add = ctx
        add.blendMode = .plusLighter
        add.drawLayer { l in
            l.addFilter(.blur(radius: 2.2))
            l.fill(warm, with: .color(NR.sodium.opacity(0.8)))
            l.fill(road, with: .color(NR.sodium))
            l.fill(cold, with: .color(Color(hex: 0x9CFFE0).opacity(0.5)))
            l.fill(pink, with: .color(NR.magenta.opacity(0.7)))
        }
        add.drawLayer { l in
            l.addFilter(.blur(radius: 6))
            l.fill(road, with: .color(NR.halation.opacity(0.5)))
        }
        ctx.fill(warm, with: .color(Color(hex: 0xFFCF85)))
        ctx.fill(cold, with: .color(Color(hex: 0xD8FFF0).opacity(0.85)))
        ctx.fill(pink, with: .color(Color(hex: 0xFF9AD8)))
        ctx.fill(road, with: .color(NR.sodiumCore))
    }

    /// A lattice radio mast with a red aircraft light, on the mid ridge.
    static func mast(_ ctx: GraphicsContext, at x: CGFloat, line: [CGPoint], R: CGRect) {
        let baseY = ridgeY(line, at: x) + 1.5
        let h = min(30, R.height * 0.16)
        let topY = baseY - h
        var m = Path()
        m.move(to: CGPoint(x: x - 2.4, y: baseY)); m.addLine(to: CGPoint(x: x - 0.35, y: topY))
        m.move(to: CGPoint(x: x + 2.4, y: baseY)); m.addLine(to: CGPoint(x: x + 0.35, y: topY))
        var y = baseY
        var left = true
        while y > topY + 2 {
            let f0 = (baseY - y) / h, f1 = (baseY - (y - 3)) / h
            let w0 = 2.4 - 2.05 * f0, w1 = 2.4 - 2.05 * f1
            m.move(to: CGPoint(x: x + (left ? -w0 : w0), y: y))
            m.addLine(to: CGPoint(x: x + (left ? w1 : -w1), y: y - 3))
            y -= 3
            left.toggle()
        }
        m.move(to: CGPoint(x: x, y: topY)); m.addLine(to: CGPoint(x: x, y: topY - 5))
        ctx.stroke(m, with: .color(Color(hex: 0x02080A)), lineWidth: 0.55)
        ctx.stroke(m.offsetBy(dx: 0.3, dy: 0), with: .color(NR.magenta.opacity(0.18)), lineWidth: 0.3)
        let light = CGPoint(x: x, y: topY - 5)
        let mid = CGPoint(x: x, y: topY + h * 0.45)
        var add = ctx
        add.blendMode = .plusLighter
        add.drawLayer { l in
            l.addFilter(.blur(radius: 5))
            l.fill(Path(ellipseIn: CGRect(x: light.x - 5, y: light.y - 5, width: 10, height: 10)), with: .color(NR.red.opacity(0.9)))
            l.fill(Path(ellipseIn: CGRect(x: mid.x - 3, y: mid.y - 3, width: 6, height: 6)), with: .color(NR.red.opacity(0.5)))
        }
        add.drawLayer { l in
            l.addFilter(.blur(radius: 1.2))
            l.fill(Path(ellipseIn: CGRect(x: light.x - 1.6, y: light.y - 1.6, width: 3.2, height: 3.2)), with: .color(NR.red))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: light.x - 0.9, y: light.y - 0.9, width: 1.8, height: 1.8)), with: .color(NR.redCore))
        ctx.fill(Path(ellipseIn: CGRect(x: mid.x - 0.6, y: mid.y - 0.6, width: 1.2, height: 1.2)), with: .color(NR.redCore.opacity(0.8)))
    }

    // MARK: Mist and city

    static func mistBand(_ ctx: GraphicsContext, R: CGRect, X: CGRect, spec: NRSceneSpec, streetY: CGFloat) {
        let cityTop = R.minY + spec.city.lowerBound * R.height
        let bandTop = cityTop - R.height * (spec.weather == .fog ? 0.32 : 0.14)
        let thick: Double = spec.weather == .fog ? 0.75 : 0.5
        ctx.fill(Path(CGRect(x: X.minX, y: bandTop, width: X.width, height: streetY - bandTop)), with: .linearGradient(
            Gradient(stops: [.init(color: .clear, location: 0), .init(color: Color(hex: 0x4E6E66).opacity(thick), location: 0.6),
                             .init(color: Color(hex: 0x5C5A48).opacity(thick * 0.6), location: 1)]),
            startPoint: CGPoint(x: 0, y: bandTop), endPoint: CGPoint(x: 0, y: streetY)))
        var img = ctx.resolve(Mock.texture("neon-rain/mist").renderingMode(.template))
        img.shading = .color(Color(hex: 0x9DBDB3))
        var c = ctx
        c.blendMode = .screen
        c.opacity = spec.weather == .fog ? 0.8 : 0.45
        c.draw(img, in: CGRect(x: R.minX - 30, y: bandTop - R.height * 0.05, width: R.width + 60, height: (streetY - bandTop) * 0.9))
    }

    static func city(_ ctx: GraphicsContext, R: CGRect, spec: NRSceneSpec, streetY: CGFloat) {
        var rng = SeededRandom(seed: spec.seed &+ 80)
        var x = R.minX - 30
        var bodies = Path()
        var warm = Path(), cold = Path(), tv = Path()
        var roof = Path()
        while x < R.maxX + 30 {
            let w = rng.range(9...26)
            let top = R.minY + rng.range(spec.city) * R.height
            let rect = CGRect(x: x, y: top, width: w, height: streetY - top + 2)
            bodies.addRect(rect)
            // Rooftop clutter: water tanks, aerials, a stair hut.
            let pick = rng.unit()
            if pick < 0.3 {
                let tx = x + rng.range(1...max(1.5, w - 6))
                roof.addRect(CGRect(x: tx, y: top - 3.2, width: 4.5, height: 2.6))
                roof.addRect(CGRect(x: tx + 0.6, y: top - 0.8, width: 0.5, height: 0.9))
                roof.addRect(CGRect(x: tx + 3.4, y: top - 0.8, width: 0.5, height: 0.9))
            } else if pick < 0.55 {
                let ax = x + rng.range(1...max(1.5, w - 1))
                roof.addRect(CGRect(x: ax, y: top - rng.range(4...9), width: 0.45, height: 9))
                roof.addRect(CGRect(x: ax - 1.6, y: top - 6, width: 3.6, height: 0.4))
            } else if pick < 0.7 {
                roof.addRect(CGRect(x: x + 2, y: top - 2.5, width: min(6, w - 3), height: 2.6))
            }
            // Windows on a grid; most dark, some lit sodium, some fluorescent, a TV's blue flicker.
            var wy = top + 2.2
            while wy < streetY - 3 {
                var wx = x + 1.6
                while wx < x + w - 2 {
                    let r = rng.unit()
                    let wr = CGRect(x: wx, y: wy, width: 1.4, height: 1.1)
                    if r < 0.2 { warm.addRect(wr) } else if r < 0.3 { cold.addRect(wr) } else if r < 0.32 { tv.addRect(wr) }
                    wx += 3.0
                }
                wy += 3.3
            }
            x += w + rng.range(-1.5...0.8)
        }
        ctx.fill(bodies, with: .linearGradient(Gradient(colors: [Color(hex: 0x081211), Color(hex: 0x050B0B)]),
                                               startPoint: CGPoint(x: 0, y: R.minY + spec.city.lowerBound * R.height), endPoint: CGPoint(x: 0, y: streetY)))
        ctx.fill(roof, with: .color(Color(hex: 0x071010)))
        // Neon spill on the facades from below.
        var spill = ctx
        spill.clip(to: bodies)
        spill.blendMode = .screen
        spill.fill(Path(R.insetBy(dx: -40, dy: -40)), with: .linearGradient(
            Gradient(colors: [.clear, NR.magenta.opacity(0.10), NR.red.opacity(0.22)]),
            startPoint: CGPoint(x: 0, y: R.minY + spec.city.lowerBound * R.height), endPoint: CGPoint(x: 0, y: streetY)))
        var add = ctx
        add.blendMode = .plusLighter
        add.drawLayer { l in
            l.addFilter(.blur(radius: 1.6))
            l.fill(warm, with: .color(NR.sodium.opacity(0.7)))
            l.fill(cold, with: .color(Color(hex: 0x9CFFE0).opacity(0.45)))
            l.fill(tv, with: .color(NR.cyan.opacity(0.8)))
        }
        ctx.fill(warm, with: .color(Color(hex: 0xFFC77A).opacity(0.9)))
        ctx.fill(cold, with: .color(Color(hex: 0xCFFFEA).opacity(0.75)))
        ctx.fill(tv, with: .color(NR.cyanCore))

        for s in spec.signs { sign(ctx, s, R: R) }
    }

    static func signTubes(_ s: NRSign, R: CGRect) -> [[CGPoint]] {
        let c = CGPoint(x: R.minX + s.at.x * R.width, y: R.minY + s.at.y * R.height)
        let k = s.scale
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x * k, y: c.y + y * k) }
        switch s.kind {
        case .vbar:
            return [[P(-2.6, -9), P(2.6, -9), P(2.6, 9), P(-2.6, 9), P(-2.6, -9)], [P(0, -5.5), P(0, 5.5)]]
        case .box:
            return [[P(-8, -3.6), P(8, -3.6), P(8, 3.6), P(-8, 3.6), P(-8, -3.6)], [P(-5, 0), P(5, 0)]]
        case .ring:
            return [NRTubeFont.arc(c.x, c.y, 4 * k, 4 * k, 0, 360)]
        case .arrow:
            return [[P(-7, 0), P(6, 0)], [P(2, -3.5), P(6.5, 0), P(2, 3.5)]]
        case .zigzag:
            return [[P(-8, 2), P(-5, -2), P(-2, 2), P(1, -2), P(4, 2), P(7, -2)]]
        case .bars:
            return [[P(-5, -4), P(5, -4)], [P(-3.5, 0), P(3.5, 0)], [P(-6, 4), P(6, 4)]]
        case .cup:
            return [[P(-4, -3), P(-3, 4), P(3, 4), P(4, -3)], [P(4, -1.5), P(6.2, -0.5), P(3.6, 1.8)]]
        }
    }

    static func sign(_ ctx: GraphicsContext, _ s: NRSign, R: CGRect) {
        let tubes = signTubes(s, R: R).map { NRNeon.Tube(points: $0, dim: s.dim) }
        NRNeon.draw(ctx, tubes: tubes, color: s.color, core: s.core, width: 0.9 * s.scale, clips: false, glow: 0.8)
    }

    /// Shallow focus: the city is only light, discs with bright rims, and some of it step-printed sideways.
    static func bokehCity(_ ctx: GraphicsContext, R: CGRect, spec: NRSceneSpec, streetY: CGFloat) {
        var rng = SeededRandom(seed: spec.seed &+ 90)
        let cityTop = R.minY + spec.city.lowerBound * R.height
        // Dark block masses so the bokeh has something to sit in front of.
        var x = R.minX - 30
        var bodies = Path()
        while x < R.maxX + 30 {
            let w = rng.range(14...34)
            let top = R.minY + rng.range(spec.city) * R.height
            bodies.addRoundedRect(in: CGRect(x: x, y: top, width: w, height: streetY - top + 2), cornerSize: CGSize(width: 3, height: 3))
            x += w + rng.range(-2...1)
        }
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 2.5))
            l.fill(bodies, with: .color(Color(hex: 0x061010).opacity(0.92)))
        }
        let palette: [Color] = [NR.sodium, NR.sodium, NR.sodium, Color(hex: 0xFFD08A), Color(hex: 0xFFD08A), NR.red, NR.red, NR.magenta,
                                NR.cyan, Color(hex: 0x9CFFE0)]
        var add = ctx
        add.blendMode = .screen
        let count = Int(R.width * 0.15)
        for i in 0..<count {
            let big = i % 9 == 0
            let p = CGPoint(x: R.minX + rng.unit() * R.width, y: cityTop + rng.range(0.15...1.05) * (streetY - cityTop))
            let r = big ? rng.range(9...15) : 1.6 + pow(rng.unit(), 1.8) * 6.5
            let col = palette[min(palette.count - 1, Int(rng.unit() * CGFloat(palette.count)))]
            let o = big ? Double(rng.range(0.12...0.22)) : Double(rng.range(0.2...0.7))
            let ghosts = spec.smear && rng.unit() < 0.3 ? 3 : 0
            for g in 0...ghosts {
                let dx = CGFloat(g) * r * 0.9
                let fade = g == 0 ? 1.0 : 0.45 / Double(g)
                let disc = CGRect(x: p.x - r - dx, y: p.y - r, width: r * 2, height: r * 2)
                add.fill(Path(ellipseIn: disc), with: .radialGradient(
                    Gradient(stops: [.init(color: col.opacity(o * 0.5 * fade), location: 0), .init(color: col.opacity(o * 0.58 * fade), location: 0.78),
                                     .init(color: col.opacity(o * 0.85 * fade), location: 0.9), .init(color: col.opacity(0), location: 1)]),
                    center: CGPoint(x: disc.midX, y: disc.midY), startRadius: 0, endRadius: r))
            }
        }
        for s in spec.signs {
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 1.6 * s.scale))
                sign(l, s, R: R)
            }
        }
    }

    // MARK: Street

    static func street(_ ctx: GraphicsContext, R: CGRect, X: CGRect, spec: NRSceneSpec, streetY: CGFloat) {
        let rect = CGRect(x: X.minX, y: streetY, width: X.width, height: X.maxY - streetY)
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: 0x0E1716), Color(hex: 0x060B0B), Color(hex: 0x030606)]),
                                                   startPoint: CGPoint(x: 0, y: streetY), endPoint: CGPoint(x: 0, y: R.maxY)))
        var tex = ctx
        tex.clip(to: Path(rect))
        tex.blendMode = .softLight
        tex.opacity = 0.9
        tex.draw(ctx.resolve(Mock.texture("neon-rain/asphalt")), in: CGRect(x: R.minX - 10, y: streetY, width: R.width + 20, height: max(60, R.maxY - streetY + 30)))

        // The sky's glow lying on the wet road.
        var add = ctx
        add.blendMode = .screen
        add.fill(Path(CGRect(x: X.minX, y: streetY, width: X.width, height: min(26, R.maxY - streetY))), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x6F7A5E).opacity(0.45), .clear]), startPoint: CGPoint(x: 0, y: streetY), endPoint: CGPoint(x: 0, y: streetY + 26)))

        // Rippled reflections: every light pours a broken column down the wet asphalt.
        var rng = SeededRandom(seed: spec.seed &+ 120)
        var lights = spec.lights
        for s in spec.signs { lights.append(NRLight(at: s.at, color: s.color, size: 0.8 * s.scale)) }
        for _ in 0..<Int(R.width / 26) {
            lights.append(NRLight(at: CGPoint(x: rng.unit(), y: spec.street), color: rng.unit() < 0.6 ? NR.sodium : Color(hex: 0x9CFFE0), size: rng.range(0.35...0.7)))
        }
        let depth = R.maxY - streetY
        let plus = ctx
        var plusL = plus
        plusL.blendMode = .plusLighter
        plusL.drawLayer { l in
            l.addFilter(.blur(radius: 0.9))
            for L in lights {
                let x0 = R.minX + L.at.x * R.width
                let n = Int(depth / 2.1)
                for k in 0..<max(1, n) {
                    let f = CGFloat(k) / CGFloat(max(1, n))
                    let y = streetY + 1 + CGFloat(k) * 2.1
                    let w = (3.2 + rng.range(0...4)) * L.size * (1 + f * 0.8)
                    let jx = rng.range(-1.6...1.6) * (1 + f * 2)
                    let o = 0.9 * pow(Double(1 - f), 1.3) * Double(min(1, L.size)) * Double(rng.range(0.4...1))
                    l.fill(Path(CGRect(x: x0 - w / 2 + jx, y: y, width: w, height: rng.range(0.6...1.3))), with: .color(L.color.opacity(o)))
                }
            }
        }
        plusL.drawLayer { l in
            l.addFilter(.blur(radius: 7))
            for L in lights {
                let x0 = R.minX + L.at.x * R.width
                l.fill(Path(CGRect(x: x0 - 5 * L.size, y: streetY, width: 10 * L.size, height: depth * 0.8)), with: .color(L.color.opacity(0.22 * Double(min(1, L.size)))))
            }
        }
        // Kerb catching light.
        ctx.stroke(Path { p in p.move(to: CGPoint(x: X.minX, y: streetY + 0.5)); p.addLine(to: CGPoint(x: X.maxX, y: streetY + 0.5)) },
                   with: .color(Color(hex: 0xFFD7A0).opacity(0.28)), lineWidth: 0.6)

        if spec.smear { traffic(ctx, R: R, streetY: streetY, seed: spec.seed) }
    }

    /// Tail lights and a headlamp, step-printed: each light repeated in stuttering ghosts behind it.
    static func traffic(_ ctx: GraphicsContext, R: CGRect, streetY: CGFloat, seed: UInt64) {
        var rng = SeededRandom(seed: seed &+ 150)
        let depth = R.maxY - streetY
        var add = ctx
        add.blendMode = .plusLighter
        for car in 0..<2 {
            let y = streetY + depth * (car == 0 ? 0.16 : 0.34)
            guard y < R.maxY - 3 else { continue }
            let x = R.minX + R.width * (car == 0 ? rng.range(0.55...0.8) : rng.range(0.15...0.4))
            let col = car == 0 ? NR.red : Color(hex: 0xFFE9C4)
            let dir: CGFloat = car == 0 ? -1 : 1
            let gap: CGFloat = car == 0 ? 7 : 6
            add.drawLayer { l in
                l.addFilter(.blur(radius: 1.2))
                // The smear itself, a thin streak.
                l.fill(Path(roundedRect: CGRect(x: min(x, x + dir * 40), y: y - 0.5, width: 40, height: 1), cornerRadius: 0.5),
                       with: .color(col.opacity(0.3)))
                for g in 0..<6 {
                    let gx = x + dir * CGFloat(g) * gap + rng.range(-0.8...0.8)
                    let o = g == 0 ? 1.0 : 0.55 * pow(0.72, Double(g))
                    for side in [-1.0, 1.0] as [CGFloat] {
                        let p = CGPoint(x: gx + side * 3.2, y: y)
                        l.fill(Path(ellipseIn: CGRect(x: p.x - 1.1, y: p.y - 0.75, width: 2.2, height: 1.5)), with: .color(col.opacity(o)))
                    }
                }
            }
            add.drawLayer { l in
                l.addFilter(.blur(radius: 5))
                l.fill(Path(ellipseIn: CGRect(x: x - 9, y: y - 4, width: 18, height: 8)), with: .color(col.opacity(0.5)))
            }
        }
    }

    // MARK: Weather in the street

    static func weather(_ ctx: GraphicsContext, R: CGRect, X: CGRect, spec: NRSceneSpec, streetY: CGFloat) {
        var rng = SeededRandom(seed: spec.seed &+ 200)
        switch spec.weather {
        case .rain:
            var lines = Path(), bright = Path()
            for _ in 0..<Int(R.width * R.height / 140) {
                let p = CGPoint(x: X.minX + rng.unit() * X.width, y: X.minY + rng.unit() * X.height)
                let len = rng.range(5...13)
                var seg = Path()
                seg.move(to: p)
                seg.addLine(to: CGPoint(x: p.x + len * 0.16, y: p.y + len))
                if rng.unit() < 0.18 { bright.addPath(seg) } else { lines.addPath(seg) }
            }
            ctx.stroke(lines, with: .color(NR.tealPale.opacity(0.22)), lineWidth: 0.4)
            var add = ctx
            add.blendMode = .plusLighter
            add.stroke(bright, with: .color(Color(hex: 0xFFD8B0).opacity(0.3)), lineWidth: 0.5)
            // Splashes on the street.
            var splash = Path()
            for _ in 0..<Int(R.width / 5) {
                let p = CGPoint(x: R.minX + rng.unit() * R.width, y: streetY + rng.unit() * (R.maxY - streetY))
                let w = rng.range(1.5...3.5)
                splash.addEllipse(in: CGRect(x: p.x - w, y: p.y - w * 0.18, width: w * 2, height: w * 0.36))
            }
            ctx.stroke(splash, with: .color(NR.tealPale.opacity(0.28)), lineWidth: 0.35)
        case .snow:
            var flakes = Path(), big = Path()
            for _ in 0..<Int(R.width * R.height / 260) {
                let p = CGPoint(x: X.minX + rng.unit() * X.width, y: X.minY + rng.unit() * X.height)
                if rng.unit() < 0.08 {
                    let r = rng.range(2.5...4.5)
                    big.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                } else {
                    let r = rng.range(0.35...1.1)
                    flakes.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                }
            }
            ctx.fill(flakes, with: .color(Color(hex: 0xEAF6F2).opacity(0.85)))
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 1.6))
                l.fill(big, with: .color(Color(hex: 0xEAF6F2).opacity(0.35)))
            }
        case .fog:
            ctx.fill(Path(X), with: .linearGradient(Gradient(colors: [.clear, Color(hex: 0x5D7B73).opacity(0.35), Color(hex: 0x5D7B73).opacity(0.15)]),
                                                    startPoint: CGPoint(x: 0, y: R.minY), endPoint: CGPoint(x: 0, y: R.maxY)))
        case .clear, .cloudy:
            break
        }
    }
}

/// The scene as a view at the widget's size.
struct NRSceneView: View {
    var spec: NRSceneSpec

    var body: some View {
        Canvas { ctx, size in NRScene.paint(ctx, size: size, spec: spec) }
    }
}
