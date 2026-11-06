import SwiftUI

// The view through the window: an evening sky (stars and a crescent when it's clear, cloud banks lit from below
// by the town when it isn't), three ridges stepping back into mist with snow on the far peaks, and a stair road
// of lamps climbing the middle slope between a few lit windows. Then the glass (the lamp reflected in it, beads,
// rain streaks), the lacquered frame, and a velvet curtain.

enum CHColor {
    static func rgb(_ hex: UInt32) -> (Double, Double, Double) {
        (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }
    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double, opacity: Double = 1) -> Color {
        let x = rgb(a), y = rgb(b)
        return Color(.sRGB, red: x.0 + (y.0 - x.0) * t, green: x.1 + (y.1 - x.1) * t, blue: x.2 + (y.2 - x.2) * t, opacity: opacity)
    }
}

/// A ridge crest from hand-placed unit key points, roughened by seeded midpoint displacement.
struct CHRidge {
    var keys: [CGPoint]
    var seed: UInt64
    var roughness: CGFloat = 0.22
    var levels: Int = 4

    func crest(in r: CGRect) -> [CGPoint] {
        var pts = keys.map { CHGeo.unit(r, $0.x, $0.y) }
        var rng = CHRandom(seed)
        var amount = roughness
        for _ in 0..<levels {
            var next: [CGPoint] = [pts[0]]
            for i in 0..<(pts.count - 1) {
                let a = pts[i], b = pts[i + 1]
                let len = hypot(b.x - a.x, b.y - a.y)
                next.append(CGPoint(x: (a.x + b.x) / 2 + rng.range(-0.1...0.1) * (b.x - a.x),
                                    y: (a.y + b.y) / 2 + rng.range(-1...1) * len * amount))
                next.append(b)
            }
            pts = next
            amount *= 0.62
        }
        return pts
    }

    static func fill(_ crest: [CGPoint], bottom: CGFloat) -> Path {
        var p = Path()
        guard let first = crest.first, let last = crest.last else { return p }
        p.move(to: CGPoint(x: first.x, y: bottom))
        for c in crest { p.addLine(to: c) }
        p.addLine(to: CGPoint(x: last.x, y: bottom))
        p.closeSubpath()
        return p
    }

    static func y(at x: CGFloat, on line: [CGPoint]) -> CGFloat {
        guard let first = line.first, let last = line.last else { return 0 }
        if x <= first.x { return first.y }
        if x >= last.x { return last.y }
        for i in 1..<line.count where line[i].x >= x {
            let a = line[i - 1], b = line[i]
            return a.y + (b.y - a.y) * (x - a.x) / max(b.x - a.x, 0.001)
        }
        return last.y
    }
}

/// Where things sit in a particular window, as fractions of the glass.
struct CHVista {
    var far: [CGPoint]
    var mid: [CGPoint]
    var near: [CGPoint]
    var road: CGFloat = 0.55          // unit x where the stair road starts at the foot of the middle ridge
    var roadWidth: CGFloat = 0.22     // unit width of the switchbacks
    var moon = CGPoint(x: 0.78, y: 0.16)
    var lamp = CGPoint(x: 0.2, y: 0.3)  // where the room's lamp reflects in the glass
    var seed: UInt64 = 1
    var horizon: CGFloat = 0.6          // unit y where the afterglow is brightest
    var roadFoot: CGFloat = 0.84        // unit y where the stair road starts
    var bolt: CGFloat = 0.3             // unit x of the lightning in a storm (kept clear of any lettering)

    /// The far room's window in the quote doorways (the curtain covers its right-hand side).
    static let square = CHVista(
        far: [CGPoint(x: -0.03, y: 0.46), CGPoint(x: 0.2, y: 0.24), CGPoint(x: 0.4, y: 0.38), CGPoint(x: 0.6, y: 0.12),
              CGPoint(x: 0.8, y: 0.32), CGPoint(x: 1.03, y: 0.26)],
        mid: [CGPoint(x: -0.03, y: 0.62), CGPoint(x: 0.14, y: 0.5), CGPoint(x: 0.3, y: 0.40), CGPoint(x: 0.5, y: 0.5),
              CGPoint(x: 0.8, y: 0.58), CGPoint(x: 1.03, y: 0.6)],
        near: [CGPoint(x: -0.03, y: 0.86), CGPoint(x: 0.45, y: 0.82), CGPoint(x: 1.03, y: 0.87)],
        road: 0.28, roadWidth: 0.34, moon: CGPoint(x: 0.64, y: 0.08), lamp: CGPoint(x: 0.72, y: 0.72), seed: 37,
        horizon: 0.5, roadFoot: 0.82)
}

enum CHExterior {
    /// Paints the evening outside into `r` (the glass rect). Everything is in fractions of `r`.
    static func draw(_ ctx: GraphicsContext, in r: CGRect, sky: CHSky, vista: CHVista, scale k: CGFloat = 1) {
        var c = ctx
        c.clip(to: Path(r))
        let seed = vista.seed
        let overcast = Double(min(1, sky.clouds * 0.9 + sky.rain * 0.3 + sky.snow * 0.2))
        let fog = Double(sky.fog)

        // Sky: deep blue at the top, a slate band, and the last of the afterglow behind the far peaks.
        let hz = vista.horizon
        c.fill(Path(r), with: .linearGradient(Gradient(stops: [
            .init(color: CHColor.mix(0x08111C, 0x1A222C, overcast), location: 0),
            .init(color: CHColor.mix(0x182C40, 0x2E3A46, overcast), location: hz * 0.5),
            .init(color: CHColor.mix(0x46586C, 0x56606A, overcast), location: hz * 0.8),
            .init(color: CHColor.mix(0xC08060, 0x6E6460, overcast * 0.8), location: hz),
            .init(color: CHColor.mix(0x3A4656, 0x3A4048, overcast), location: min(1, hz + 0.25))]),
            startPoint: CGPoint(x: r.midX, y: r.minY), endPoint: CGPoint(x: r.midX, y: r.maxY)))

        if sky.stars { stars(c, in: r, seed: seed &+ 1, k: k, dim: overcast) }
        if sky.moon { moon(c, at: CHGeo.unit(r, vista.moon.x, vista.moon.y), radius: max(3.2, min(8, r.width * 0.045)) * (0.8 + 0.2 * k)) }
        if sky.clouds > 0.05 { clouds(c, in: r, amount: sky.clouds, seed: seed &+ 2, k: k) }

        // Far range: pale with distance, snow on the summits, catching the afterglow.
        let far = CHRidge(keys: vista.far, seed: seed &+ 3, roughness: 0.26).crest(in: r)
        let farPath = CHRidge.fill(far, bottom: r.maxY)
        c.fill(farPath, with: .linearGradient(Gradient(colors: [CHColor.mix(0x8496A8, 0x7A828C, overcast), CHColor.mix(0x52667A, 0x5A626C, overcast)]),
                                              startPoint: CGPoint(x: r.midX, y: r.minY + r.height * 0.15), endPoint: CGPoint(x: r.midX, y: r.minY + r.height * hz)))
        let farShade = ctxClip(c, farPath)
        farShade.fill(farPath.offsetBy(dx: 3.2 * k, dy: 1.2 * k), with: .color(CHColor.mix(0x3A4C60, 0x4A525C, overcast, opacity: 0.85)))
        snowcaps(c, crest: far, ridge: farPath, in: r, seed: seed &+ 4, snowy: sky.snow > 0, k: k)
        // Light falling on the left faces: a faint rose rim along the crest.
        var rim = c
        rim.clip(to: farPath)
        rim.stroke(CHGeo.smooth(far).offsetBy(dx: 0, dy: 0.6), with: .color(CH.afterglow.opacity(0.45 * (1 - overcast * 0.7))), lineWidth: 0.9 * k)

        let farLow = far.map(\.y).max() ?? r.midY
        mist(c, at: farLow - r.height * 0.02, in: r, height: r.height * 0.12, opacity: 0.32 + fog * 0.4, seed: seed &+ 5, warm: false)

        // Middle ridge with the town on its flank.
        let mid = CHRidge(keys: vista.mid, seed: seed &+ 6, roughness: 0.18).crest(in: r)
        let midPath = CHRidge.fill(mid, bottom: r.maxY)
        let midTop = mid.map(\.y).min() ?? r.midY
        c.fill(midPath, with: .linearGradient(Gradient(colors: [CHColor.mix(0x2C4054, 0x3A444E, overcast), CHColor.mix(0x16222E, 0x262E36, overcast)]),
                                              startPoint: CGPoint(x: r.midX, y: midTop), endPoint: CGPoint(x: r.midX, y: r.maxY)))
        let midShade = ctxClip(c, midPath)
        midShade.fill(midPath.offsetBy(dx: 2.6 * k, dy: 1.4 * k), with: .color(CHColor.mix(0x1A2836, 0x2A323A, overcast, opacity: 0.8)))
        midShade.stroke(CHGeo.smooth(mid).offsetBy(dx: 0, dy: 0.5), with: .color(CH.afterglow.opacity(0.28 * (1 - overcast * 0.7))), lineWidth: 0.7 * k)
        town(c, crest: mid, in: r, vista: vista, k: k)

        mist(c, at: r.minY + r.height * (vista.roadFoot - 0.02), in: r, height: r.height * 0.1, opacity: 0.30 + fog * 0.4, seed: seed &+ 7, warm: true)

        // Near ridge: a dark shoulder with spruce tips and a roof or two.
        let near = CHRidge(keys: vista.near, seed: seed &+ 8, roughness: 0.12, levels: 3).crest(in: r)
        let nearPath = CHRidge.fill(near, bottom: r.maxY + 2)
        c.fill(nearPath, with: .color(CHColor.mix(0x111A24, 0x1A2026, overcast)))
        spruce(c, crest: near, in: r, seed: seed &+ 9, k: k)

        if sky.snow > 0 { snowfall(c, in: r, amount: sky.snow, seed: seed &+ 10, k: k) }
        if fog > 0.01 {
            c.fill(Path(r), with: .linearGradient(Gradient(colors: [Color(hex: 0x8D9AA6, opacity: fog * 0.18), Color(hex: 0x9AA6B0, opacity: fog * 0.42)]),
                                                  startPoint: CGPoint(x: r.midX, y: r.minY), endPoint: CGPoint(x: r.midX, y: r.maxY)))
        }
        if sky.storm { lightning(c, in: r, x: vista.bolt, seed: seed &+ 11, k: k) }
    }

    static func stars(_ c: GraphicsContext, in r: CGRect, seed: UInt64, k: CGFloat, dim: Double) {
        var rng = CHRandom(seed)
        let n = Int(r.width * r.height / 380) + 6
        for _ in 0..<n {
            let p = CGPoint(x: rng.range(r.minX...r.maxX), y: r.minY + rng.range(0...0.42) * r.height)
            let s = rng.range(0.25...0.75) * k
            let o = Double(rng.range(0.35...0.95)) * (1 - dim * 0.8)
            c.fill(Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s, width: s * 2, height: s * 2)), with: .color(Color(hex: 0xF4ECD8, opacity: o)))
            if rng.unit() < 0.18 {
                let g = s * 4
                c.fill(Path(ellipseIn: CGRect(x: p.x - g, y: p.y - g, width: g * 2, height: g * 2)),
                       with: .radialGradient(Gradient(colors: [Color(hex: 0xF4ECD8, opacity: o * 0.35), .clear]), center: p, startRadius: 0, endRadius: g))
            }
        }
    }

    static func moon(_ c: GraphicsContext, at p: CGPoint, radius m: CGFloat) {
        let halo = m * 6
        c.fill(Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: halo * 2, height: halo * 2)),
               with: .radialGradient(Gradient(colors: [Color(hex: 0xEADFC4, opacity: 0.28), Color(hex: 0xEADFC4, opacity: 0.06), .clear]),
                                     center: p, startRadius: m * 0.8, endRadius: halo))
        let disc = Path(ellipseIn: CGRect(x: p.x - m, y: p.y - m, width: m * 2, height: m * 2))
        let bite = Path(ellipseIn: CGRect(x: p.x - m * 0.45, y: p.y - m * 1.12, width: m * 2.1, height: m * 2.1))
        // Earthshine on the dark part, then the lit crescent.
        c.fill(disc, with: .color(Color(hex: 0x30404E, opacity: 0.55)))
        c.fill(disc.subtracting(bite), with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF3D6), Color(hex: 0xE8D5A8)]),
                                                             startPoint: CGPoint(x: p.x - m, y: p.y - m), endPoint: CGPoint(x: p.x + m, y: p.y + m)))
    }

    static func clouds(_ c: GraphicsContext, in r: CGRect, amount: CGFloat, seed: UInt64, k: CGFloat) {
        var rng = CHRandom(seed)
        let banks = 2 + Int(amount * 5)
        var body = c
        body.addFilter(.blur(radius: 2.4 * k))
        for i in 0..<banks {
            let y = r.minY + r.height * (0.08 + 0.42 * CGFloat(i) / CGFloat(max(1, banks - 1))) + rng.range(-4...4)
            let x = r.minX + r.width * rng.range(-0.1...0.8)
            let w = r.width * rng.range(0.35...0.8)
            let h = max(4, r.height * rng.range(0.05...0.09))
            var bank = Path()
            for j in 0..<5 {
                let t = CGFloat(j) / 4
                let bw = w * rng.range(0.28...0.45)
                let bh = h * rng.range(0.8...1.5)
                bank.addEllipse(in: CGRect(x: x + w * t * 0.75, y: y - bh * 0.5 + rng.range(-1...1), width: bw, height: bh))
            }
            let lit = Double(0.5 + amount * 0.3)
            body.fill(bank, with: .color(Color(hex: 0x1E2834, opacity: lit)))
            // The underside catches the town's glow.
            var under = body
            under.clip(to: Path(CGRect(x: r.minX, y: y + h * 0.15, width: r.width, height: h)))
            under.fill(bank.offsetBy(dx: 0, dy: 0.8), with: .color(Color(hex: 0x8E6A58, opacity: 0.30 * lit)))
        }
    }

    static func snowcaps(_ c: GraphicsContext, crest: [CGPoint], ridge: Path, in r: CGRect, seed: UInt64, snowy: Bool, k: CGFloat) {
        // Snow above a wavy line a little below the highest points of the crest.
        let top = crest.map(\.y).min() ?? r.minY
        let line = r.minY + (top - r.minY) + r.height * (snowy ? 0.14 : 0.08)
        var region = Path()
        region.move(to: CGPoint(x: r.minX - 2, y: r.minY))
        let steps = 24
        for i in 0...steps {
            let x = r.minX - 2 + (r.width + 4) * CGFloat(i) / CGFloat(steps)
            region.addLine(to: CGPoint(x: x, y: line + CHGeo.wobble(x, seed: seed, base: 0.25) * r.height * 0.035))
        }
        region.addLine(to: CGPoint(x: r.maxX + 2, y: r.minY))
        region.closeSubpath()
        var s = ctxClip(c, ridge)
        s.clip(to: region)
        s.fill(Path(r), with: .linearGradient(Gradient(colors: [CH.snowcap.opacity(0.95), CH.snowcap.opacity(0.5)]),
                                              startPoint: CGPoint(x: r.midX, y: top), endPoint: CGPoint(x: r.midX, y: line + r.height * 0.04)))
        // Shadowed right-hand faces: darken the snow to the right of each local summit.
        for i in 1..<(crest.count - 1) where crest[i].y < crest[i - 1].y && crest[i].y < crest[i + 1].y {
            var face = Path()
            face.move(to: crest[i])
            face.addLine(to: CGPoint(x: crest[i].x + r.width * 0.18, y: crest[i].y + r.height * 0.3))
            face.addLine(to: CGPoint(x: crest[i].x + r.width * 0.03, y: crest[i].y + r.height * 0.3))
            face.closeSubpath()
            s.fill(face, with: .color(Color(hex: 0x4A5A6C, opacity: 0.45)))
        }
        // Afterglow on the snow's lit faces.
        s.fill(Path(r), with: .linearGradient(Gradient(colors: [CH.afterglow.opacity(0.35), .clear]),
                                              startPoint: CGPoint(x: r.minX, y: top), endPoint: CGPoint(x: r.minX + r.width * 0.6, y: line)))
    }

    private static func ctxClip(_ c: GraphicsContext, _ p: Path) -> GraphicsContext {
        var x = c
        x.clip(to: p)
        return x
    }

    static func mist(_ c: GraphicsContext, at y: CGFloat, in r: CGRect, height h: CGFloat, opacity: Double, seed: UInt64, warm: Bool) {
        var m = c
        m.addFilter(.blur(radius: max(2, h * 0.35)))
        var rng = CHRandom(seed)
        let tone: UInt32 = warm ? 0x9C8C84 : 0x8C9CAA
        for i in 0..<4 {
            let w = r.width * rng.range(0.5...0.9)
            let x = r.minX + r.width * (CGFloat(i) / 3) - w / 2 + rng.range(-8...8)
            let bh = h * rng.range(0.5...1.0)
            m.fill(Path(ellipseIn: CGRect(x: x, y: y - bh / 2 + rng.range(-2...2), width: w, height: bh)),
                   with: .color(Color(hex: tone, opacity: opacity * Double(rng.range(0.5...0.85)))))
        }
    }

    /// The stair road: switchbacks of steps up the middle ridge, a lamp at every few steps, and a handful of
    /// houses set back from it with their windows lit.
    static func town(_ c: GraphicsContext, crest: [CGPoint], in r: CGRect, vista: CHVista, k: CGFloat) {
        var rng = CHRandom(vista.seed &+ 40)
        let startX = r.minX + r.width * vista.road
        let footY = r.minY + r.height * vista.roadFoot
        let crestY = CHRidge.y(at: startX, on: crest)
        let topY = crestY + max(4, (footY - crestY) * 0.14)
        guard footY - topY > 6 else { return }
        let turns = max(3, min(6, Int((footY - topY) / (9 * k))))
        // Uneven switchbacks: each bend lands a different distance out, the road wanders as it climbs.
        var pts: [CGPoint] = []
        var wander: CGFloat = 0
        for i in 0...turns {
            let t = CGFloat(i) / CGFloat(turns)
            let y = footY + (topY - footY) * t + rng.range(-0.15...0.15) * (footY - topY) / CGFloat(turns)
            let half = r.width * vista.roadWidth * 0.5 * (1 - t * 0.5) * rng.range(0.55...1.0)
            wander += rng.range(-0.06...0.06) * r.width * vista.roadWidth
            pts.append(CGPoint(x: startX + wander + (i % 2 == 0 ? -half : half), y: y))
        }
        // Houses beside the bends (never on the road), each with a lit window or two.
        var houses = Path()
        var lit: [CGRect] = []
        for i in 1..<pts.count {
            for side: CGFloat in [-1, 1] where rng.unit() < 0.7 {
                let bend = pts[i]
                let outward: CGFloat = bend.x > startX ? 1 : -1
                let hx = bend.x + outward * side.magnitude * rng.range(3...6) * k * (side > 0 ? 1 : -0.2)
                let hw = rng.range(3.0...4.6) * k, hh = rng.range(2.2...3.2) * k
                let hy = bend.y - hh - rng.range(1.5...4) * k
                guard hy > CHRidge.y(at: hx, on: crest) + 3 * k else { continue }
                houses.addRect(CGRect(x: hx - hw / 2, y: hy, width: hw, height: hh))
                houses.move(to: CGPoint(x: hx - hw / 2 - 0.6 * k, y: hy))
                houses.addLine(to: CGPoint(x: hx, y: hy - hh * 0.55))
                houses.addLine(to: CGPoint(x: hx + hw / 2 + 0.6 * k, y: hy))
                houses.closeSubpath()
                let ww = max(0.7, 0.9 * k), wh = max(0.9, 1.2 * k)
                lit.append(CGRect(x: hx - hw * 0.25 - ww / 2, y: hy + hh * 0.3, width: ww, height: wh))
                if rng.unit() < 0.5 { lit.append(CGRect(x: hx + hw * 0.22 - ww / 2, y: hy + hh * 0.3, width: ww, height: wh)) }
            }
        }
        c.fill(houses, with: .color(Color(hex: 0x111A24)))
        var wg = c
        wg.blendMode = .screen
        for w in lit {
            let g = 2.2 * k
            wg.fill(Path(ellipseIn: w.insetBy(dx: -g, dy: -g)), with: .radialGradient(Gradient(colors: [CH.amber.opacity(0.35), .clear]),
                                                                                     center: CGPoint(x: w.midX, y: w.midY), startRadius: 0, endRadius: g + w.width))
            c.fill(Path(w), with: .color(CH.tungsten.opacity(0.95)))
        }
        // The steps: a pale band of stone with the light of the lamps on it.
        let road = CHGeo.smooth(pts)
        c.stroke(road, with: .color(Color(hex: 0x0E1620, opacity: 0.6)), style: StrokeStyle(lineWidth: 1.8 * k, lineCap: .round, lineJoin: .round))
        c.stroke(road, with: .color(Color(hex: 0xC89A68, opacity: 0.45)), style: StrokeStyle(lineWidth: 0.8 * k, lineCap: .round, lineJoin: .round))
        // Lamps at even steps along the whole road.
        let spacing = max(4.2, 6 * k)
        var glow = c
        glow.blendMode = .screen
        var carry: CGFloat = 0
        for i in 0..<(pts.count - 1) {
            let a = pts[i], b = pts[i + 1]
            let len = hypot(b.x - a.x, b.y - a.y)
            var d = carry
            while d < len {
                let p = CHGeo.lerp(a, b, d / len)
                // Farther up the slope the lamps are smaller and dimmer; a few are out.
                let height = (footY - p.y) / max(1, footY - topY)
                if rng.unit() > 0.12 {
                    let g = max(2.0, 3.4 * k) * (1 - height * 0.35)
                    let o = Double(0.62 - height * 0.25) * Double(rng.range(0.7...1))
                    glow.fill(Path(ellipseIn: CGRect(x: p.x - g, y: p.y - g, width: g * 2, height: g * 2)),
                              with: .radialGradient(Gradient(colors: [CH.amber.opacity(o), CH.amber.opacity(0)]), center: p, startRadius: 0, endRadius: g))
                    let s = max(0.45, 0.62 * k) * (1 - height * 0.25)
                    c.fill(Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s, width: s * 2, height: s * 2)), with: .color(CH.tungstenHot.opacity(0.95 - Double(height) * 0.25)))
                }
                d += spacing * rng.range(0.85...1.2)
            }
            carry = d - len
        }
        // A few lone windows further along the slope.
        var lone = Path()
        for _ in 0..<Int(6 * k + 3) {
            let x = r.minX + r.width * rng.range(0.05...0.95)
            guard abs(x - startX) > r.width * vista.roadWidth * 0.7 else { continue }
            let cy = CHRidge.y(at: x, on: crest)
            let y = cy + rng.range(0.25...0.7) * (footY - cy)
            guard y > cy + 3 * k else { continue }
            let s = max(0.6, 0.8 * k)
            lone.addRect(CGRect(x: x, y: y, width: s, height: s * 1.3))
        }
        c.fill(lone, with: .color(CH.tungsten.opacity(0.75)))
    }

    static func spruce(_ c: GraphicsContext, crest: [CGPoint], in r: CGRect, seed: UInt64, k: CGFloat) {
        var rng = CHRandom(seed)
        var trees = Path()
        var x = r.minX + rng.range(0...6)
        while x < r.maxX {
            let base = CHRidge.y(at: x, on: crest) + 1.2
            let h = rng.range(3.5...7.5) * k
            let w = h * rng.range(0.32...0.42)
            trees.move(to: CGPoint(x: x - w / 2, y: base))
            trees.addLine(to: CGPoint(x: x, y: base - h))
            trees.addLine(to: CGPoint(x: x + w / 2, y: base))
            trees.closeSubpath()
            x += rng.range(2.2...9) * k
        }
        c.fill(trees, with: .color(Color(hex: 0x0E151D)))
    }

    static func snowfall(_ c: GraphicsContext, in r: CGRect, amount: CGFloat, seed: UInt64, k: CGFloat) {
        var rng = CHRandom(seed)
        let n = Int(r.width * r.height / 70 * amount)
        var soft = c
        soft.addFilter(.blur(radius: 0.6 * k))
        for i in 0..<n {
            let p = CGPoint(x: rng.range(r.minX...r.maxX), y: rng.range(r.minY...r.maxY))
            let s = rng.range(0.35...1.3) * k
            let o = Double(rng.range(0.45...0.95))
            let path = Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s, width: s * 2, height: s * 2))
            if i % 3 == 0 { soft.fill(path, with: .color(.white.opacity(o))) } else { c.fill(path, with: .color(Color(hex: 0xEEF2F4, opacity: o))) }
        }
    }

    static func lightning(_ c: GraphicsContext, in r: CGRect, x: CGFloat, seed: UInt64, k: CGFloat) {
        var rng = CHRandom(seed)
        var p = CGPoint(x: r.minX + r.width * x, y: r.minY)
        var bolt = Path()
        bolt.move(to: p)
        while p.y < r.minY + r.height * 0.5 {
            p = CGPoint(x: p.x + rng.range(-4...4) * k, y: p.y + rng.range(3...6) * k)
            bolt.addLine(to: p)
        }
        var g = c
        g.addFilter(.blur(radius: 2 * k))
        g.stroke(bolt, with: .color(Color(hex: 0xDDE6FF, opacity: 0.6)), lineWidth: 2 * k)
        c.stroke(bolt, with: .color(.white.opacity(0.9)), lineWidth: 0.6 * k)
    }
}

/// The pane itself, drawn over the view: the lamp and the room reflected in it, a sheen, condensation,
/// beads and rain streaks.
enum CHGlass {
    static func draw(_ ctx: GraphicsContext, in r: CGRect, sky: CHSky, vista: CHVista, seed: UInt64, k: CGFloat = 1) {
        var c = ctx
        c.clip(to: Path(r))
        // Rain blurs the far view a little and greys it.
        if sky.rain > 0 {
            c.fill(Path(r), with: .color(Color(hex: 0x3E4A56, opacity: 0.18 * Double(sky.rain))))
        }
        // The room's crimson reflected faintly in the lower glass.
        c.fill(Path(r), with: .linearGradient(Gradient(colors: [.clear, CH.crimson.opacity(0.10), CH.crimson.opacity(0.20)]),
                                              startPoint: CGPoint(x: r.midX, y: r.minY + r.height * 0.4), endPoint: CGPoint(x: r.midX, y: r.maxY)))
        // The lamp, reflected: a warm bloom with a ghost of its shade.
        let lp = CHGeo.unit(r, vista.lamp.x, vista.lamp.y)
        let lr = max(r.width, r.height) * 0.32
        var glow = c
        glow.blendMode = .screen
        glow.fill(Path(ellipseIn: CGRect(x: lp.x - lr, y: lp.y - lr, width: lr * 2, height: lr * 2)),
                  with: .radialGradient(Gradient(colors: [CH.tungsten.opacity(0.30), CH.amber.opacity(0.10), .clear]), center: lp, startRadius: 0, endRadius: lr))
        var shade = Path()
        let sw = min(r.width, r.height) * 0.11
        shade.move(to: CGPoint(x: lp.x - sw * 0.55, y: lp.y - sw * 0.5))
        shade.addLine(to: CGPoint(x: lp.x + sw * 0.55, y: lp.y - sw * 0.5))
        shade.addLine(to: CGPoint(x: lp.x + sw, y: lp.y + sw * 0.35))
        shade.addLine(to: CGPoint(x: lp.x - sw, y: lp.y + sw * 0.35))
        shade.closeSubpath()
        var ghost = glow
        ghost.addFilter(.blur(radius: 1.6 * k))
        ghost.fill(shade, with: .color(CH.tungsten.opacity(0.22)))
        // A diagonal sheen across the pane.
        var sheen = Path()
        sheen.move(to: CGPoint(x: r.minX + r.width * 0.55, y: r.minY))
        sheen.addLine(to: CGPoint(x: r.minX + r.width * 0.72, y: r.minY))
        sheen.addLine(to: CGPoint(x: r.minX + r.width * 0.30, y: r.maxY))
        sheen.addLine(to: CGPoint(x: r.minX + r.width * 0.18, y: r.maxY))
        sheen.closeSubpath()
        var sh = glow
        sh.addFilter(.blur(radius: 3 * k))
        sh.fill(sheen, with: .color(.white.opacity(0.045)))
        // Condensation along the bottom of the pane.
        c.fill(Path(CGRect(x: r.minX, y: r.maxY - r.height * 0.22, width: r.width, height: r.height * 0.22)),
               with: .linearGradient(Gradient(colors: [.clear, Color(hex: 0xB8C2C8, opacity: 0.16)]),
                                     startPoint: CGPoint(x: r.midX, y: r.maxY - r.height * 0.22), endPoint: CGPoint(x: r.midX, y: r.maxY)))
        var rng = CHRandom(seed)
        let area = r.width * r.height
        if sky.rain > 0 {
            let streaks = Int(area / 260 * sky.rain) + 4
            for _ in 0..<streaks {
                let x = rng.range(r.minX...r.maxX)
                let y0 = rng.range((r.minY - 10)...(r.maxY - 6))
                let len = rng.range(8...34) * k
                var pts: [CGPoint] = []
                for s in 0...6 {
                    let t = CGFloat(s) / 6
                    pts.append(CGPoint(x: x + CHGeo.wobble(t * 12 + x, seed: seed, base: 0.6) * 1.2 * k, y: y0 + len * t))
                }
                let path = CHGeo.smooth(pts)
                c.stroke(path, with: .color(Color(hex: 0x0E141A, opacity: 0.35)), lineWidth: 1.1 * k)
                c.stroke(path.offsetBy(dx: -0.3, dy: 0), with: .color(Color(hex: 0xD6E0E6, opacity: 0.33)), lineWidth: 0.55 * k)
                bead(c, at: pts[6], radius: rng.range(0.8...1.5) * k)
            }
            for _ in 0..<Int(area / 120 * sky.rain) {
                bead(c, at: CGPoint(x: rng.range(r.minX...r.maxX), y: rng.range(r.minY...r.maxY)), radius: rng.range(0.35...1.0) * k)
            }
        } else if sky.beads > 0 {
            for _ in 0..<Int(area / 420 * sky.beads) + 3 {
                bead(c, at: CGPoint(x: rng.range(r.minX...r.maxX), y: rng.range(r.minY...r.maxY)), radius: rng.range(0.4...1.2) * k)
            }
        }
        if sky.snow > 0 {
            // Snow caught in the bottom corners of the pane.
            var drift = Path()
            drift.move(to: CGPoint(x: r.minX, y: r.maxY))
            drift.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.3, y: r.maxY), control: CGPoint(x: r.minX + 2, y: r.maxY - r.height * 0.08))
            drift.closeSubpath()
            drift.move(to: CGPoint(x: r.maxX, y: r.maxY))
            drift.addQuadCurve(to: CGPoint(x: r.maxX - r.width * 0.22, y: r.maxY), control: CGPoint(x: r.maxX - 2, y: r.maxY - r.height * 0.06))
            drift.closeSubpath()
            c.fill(drift, with: .color(Color(hex: 0xE8EEF2, opacity: 0.85)))
        }
        // The rebate's shadow on the glass edge.
        var edge = c
        edge.addFilter(.blur(radius: 1.6 * k))
        edge.stroke(Path(r), with: .color(.black.opacity(0.7)), lineWidth: 3.5 * k)
    }

    static func bead(_ c: GraphicsContext, at p: CGPoint, radius s: CGFloat) {
        let rect = CGRect(x: p.x - s, y: p.y - s * 1.1, width: s * 2, height: s * 2.2)
        c.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0x0D1218, opacity: 0.35)))
        c.fill(Path(ellipseIn: rect.insetBy(dx: s * 0.25, dy: s * 0.25)), with: .color(Color(hex: 0x6E7C88, opacity: 0.35)))
        c.fill(Path(ellipseIn: CGRect(x: p.x - s * 0.55, y: p.y - s * 0.75, width: s * 0.6, height: s * 0.5)), with: .color(.white.opacity(0.6)))
        c.fill(Path(ellipseIn: CGRect(x: p.x - s * 0.2, y: p.y + s * 0.45, width: s * 0.8, height: s * 0.4)), with: .color(CH.tungsten.opacity(0.35)))
    }
}

/// The lacquered window frame: stiles, a centre mullion, a sill, and the lamp catching the near edges.
enum CHFrame {
    /// `outer` is the whole frame; returns the glass rects (one per pane).
    @discardableResult
    static func draw(_ ctx: GraphicsContext, outer: CGRect, thickness t: CGFloat, mullions: [CGFloat] = [], transom: CGFloat? = nil,
                     sill: Bool = true, lampFromLeft: Bool = true, k: CGFloat = 1) -> [CGRect] {
        let glass = outer.insetBy(dx: t, dy: t)
        // Cast shadow on the wall, away from the lamp.
        var shadow = ctx
        shadow.addFilter(.blur(radius: 3.5 * k))
        let dx: CGFloat = lampFromLeft ? 2.5 : -2.5
        var ring = Path(outer.offsetBy(dx: dx, dy: 3))
        ring.addPath(Path(glass.offsetBy(dx: dx, dy: 3)))
        shadow.fill(ring, with: .color(.black.opacity(0.65)), style: FillStyle(eoFill: true))

        var frame = Path(outer)
        frame.addPath(Path(glass))
        var bars: [CGRect] = []
        for m in mullions {
            let x = glass.minX + glass.width * m
            bars.append(CGRect(x: x - t * 0.32, y: glass.minY, width: t * 0.64, height: glass.height))
        }
        if let tr = transom {
            let y = glass.minY + glass.height * tr
            bars.append(CGRect(x: glass.minX, y: y - t * 0.3, width: glass.width, height: t * 0.6))
        }
        let wood = Gradient(colors: [Color(hex: 0x4A2416), Color(hex: 0x24100A), Color(hex: 0x120705)])
        let start = lampFromLeft ? CGPoint(x: outer.minX, y: outer.minY) : CGPoint(x: outer.maxX, y: outer.minY)
        let end = lampFromLeft ? CGPoint(x: outer.maxX, y: outer.maxY) : CGPoint(x: outer.minX, y: outer.maxY)
        ctx.fill(frame, with: .linearGradient(wood, startPoint: start, endPoint: end), style: FillStyle(eoFill: true))
        for b in bars {
            var bc = ctx
            bc.addFilter(.shadow(color: .black.opacity(0.6), radius: 1.5 * k, x: lampFromLeft ? 1 : -1, y: 1))
            bc.fill(Path(b), with: .linearGradient(wood, startPoint: start, endPoint: end))
            ctx.stroke(Path(CGRect(x: lampFromLeft ? b.minX + 0.4 : b.maxX - 0.4, y: b.minY, width: 0, height: b.height)),
                       with: .color(CH.tungsten.opacity(0.35)), lineWidth: 0.6 * k)
        }
        // Lacquer: grain lines and the lamp's highlight on the near edges.
        var grain = ctx
        grain.clip(to: frame, style: FillStyle(eoFill: true))
        var rng = CHRandom(UInt64(outer.width * 13 + outer.height))
        for _ in 0..<Int(outer.width + outer.height) / 6 {
            let vertical = rng.unit() < 0.5
            let p = CGPoint(x: rng.range(outer.minX...outer.maxX), y: rng.range(outer.minY...outer.maxY))
            let l = rng.range(6...22)
            var g = Path()
            g.move(to: p)
            g.addLine(to: vertical ? CGPoint(x: p.x + rng.range(-0.4...0.4), y: p.y + l) : CGPoint(x: p.x + l, y: p.y + rng.range(-0.4...0.4)))
            grain.stroke(g, with: .color(Color(hex: rng.unit() < 0.5 ? 0x000000 : 0x8A4A2A, opacity: 0.18)), lineWidth: 0.4)
        }
        // Outer highlight on the lamp side, inner highlight on the opposite inner edge (it faces the lamp).
        var hi = Path()
        if lampFromLeft {
            hi.move(to: CGPoint(x: outer.minX + 0.4, y: outer.maxY)); hi.addLine(to: CGPoint(x: outer.minX + 0.4, y: outer.minY + 0.4))
            hi.addLine(to: CGPoint(x: outer.maxX, y: outer.minY + 0.4))
            hi.move(to: CGPoint(x: glass.maxX + 0.4, y: glass.minY)); hi.addLine(to: CGPoint(x: glass.maxX + 0.4, y: glass.maxY))
        } else {
            hi.move(to: CGPoint(x: outer.maxX - 0.4, y: outer.maxY)); hi.addLine(to: CGPoint(x: outer.maxX - 0.4, y: outer.minY + 0.4))
            hi.addLine(to: CGPoint(x: outer.minX, y: outer.minY + 0.4))
            hi.move(to: CGPoint(x: glass.minX - 0.4, y: glass.minY)); hi.addLine(to: CGPoint(x: glass.minX - 0.4, y: glass.maxY))
        }
        hi.move(to: CGPoint(x: glass.minX, y: glass.maxY + 0.4)); hi.addLine(to: CGPoint(x: glass.maxX, y: glass.maxY + 0.4))
        ctx.stroke(hi, with: .color(CH.tungsten.opacity(0.45)), lineWidth: 0.7 * k)
        ctx.stroke(Path(glass.insetBy(dx: -0.3, dy: -0.3)), with: .color(.black.opacity(0.8)), lineWidth: 0.6)

        if sill {
            let s = CGRect(x: outer.minX - 4 * k, y: outer.maxY - 1, width: outer.width + 8 * k, height: 5.5 * k)
            var ss = ctx
            ss.addFilter(.blur(radius: 2.5 * k))
            ss.fill(Path(s.offsetBy(dx: 0, dy: 3.5 * k)), with: .color(.black.opacity(0.7)))
            ctx.fill(Path(s), with: .linearGradient(Gradient(colors: [Color(hex: 0x6A3620), Color(hex: 0x2A120A), Color(hex: 0x140806)]),
                                                    startPoint: CGPoint(x: s.minX, y: s.minY), endPoint: CGPoint(x: s.minX, y: s.maxY)))
            ctx.stroke(Path(CGRect(x: s.minX, y: s.minY + 0.4, width: s.width, height: 0)), with: .color(CH.tungsten.opacity(0.55)), lineWidth: 0.7 * k)
        }
        // The panes: split by the vertical mullions.
        var edges: [CGFloat] = [glass.minX]
        for m in mullions { edges.append(glass.minX + glass.width * m) }
        edges.append(glass.maxX)
        return (0..<(edges.count - 1)).map { CGRect(x: edges[$0], y: glass.minY, width: edges[$0 + 1] - edges[$0], height: glass.height) }
    }
}

/// A velvet curtain hanging in folds, its leading edge lit by the lamp.
enum CHCurtain {
    static func draw(_ ctx: GraphicsContext, in r: CGRect, seed: UInt64, leadingRight: Bool = false, base: UInt32 = 0x7A1419, k: CGFloat = 1) {
        // Fold profile across the width.
        var rng = CHRandom(seed)
        var stops: [Gradient.Stop] = []
        var x: CGFloat = 0
        var widths: [CGFloat] = []
        while x < r.width {
            let w = rng.range(5...10) * k
            widths.append(w)
            x += w
        }
        var pos: CGFloat = 0
        var peaks: [CGFloat] = []
        for w in widths {
            for s in 0..<6 {
                let t = CGFloat(s) / 6
                let shade = 0.5 + 0.5 * cos(t * 2 * .pi)
                let loc = min(1, (pos + w * t) / r.width)
                stops.append(.init(color: CHColor.mix(0x2A0508, base, Double(0.25 + shade * 0.75)), location: loc))
            }
            peaks.append(pos)
            pos += w
        }
        stops.append(.init(color: CHColor.mix(0x2A0508, base, 1), location: 1))
        // Hem: scalloped along the folds.
        var shape = Path()
        shape.move(to: CGPoint(x: r.minX, y: r.minY))
        shape.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        shape.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 1))
        var hx = r.maxX
        for w in widths.reversed() {
            let nx = max(r.minX, hx - w)
            shape.addQuadCurve(to: CGPoint(x: nx, y: r.maxY - 1), control: CGPoint(x: (hx + nx) / 2, y: r.maxY + 2.2 * k))
            hx = nx
        }
        shape.closeSubpath()
        // Shadow cast beside the leading edge.
        var sh = ctx
        sh.addFilter(.blur(radius: 4 * k))
        sh.fill(shape.offsetBy(dx: leadingRight ? 3 : -3, dy: 2), with: .color(.black.opacity(0.75)))
        ctx.fill(shape, with: .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: r.minX, y: r.midY), endPoint: CGPoint(x: r.maxX, y: r.midY)))
        var c = ctx
        c.clip(to: shape)
        // Velvet sheen along the fold crests, strongest at the lamp-lit leading edge.
        var sheen = c
        sheen.addFilter(.blur(radius: 1.2 * k))
        sheen.blendMode = .screen
        for (i, p) in peaks.enumerated() {
            let edgeT = leadingRight ? CGFloat(i) / CGFloat(max(1, peaks.count - 1)) : 1 - CGFloat(i) / CGFloat(max(1, peaks.count - 1))
            sheen.fill(Path(CGRect(x: r.minX + p - 0.6, y: r.minY, width: 1.2 * k, height: r.height)),
                       with: .color(CH.crimsonLit.opacity(0.25 + 0.45 * Double(edgeT))))
        }
        // Top gathered in shadow, a warm pool lower down.
        c.fill(Path(r), with: .linearGradient(Gradient(stops: [
            .init(color: .black.opacity(0.65), location: 0), .init(color: .black.opacity(0.1), location: 0.25),
            .init(color: .clear, location: 0.55), .init(color: .black.opacity(0.35), location: 1)]),
            startPoint: CGPoint(x: r.midX, y: r.minY), endPoint: CGPoint(x: r.midX, y: r.maxY)))
        let lead = leadingRight ? r.maxX : r.minX
        c.fill(Path(CGRect(x: leadingRight ? r.maxX - 2.2 * k : r.minX, y: r.minY, width: 2.2 * k, height: r.height)),
               with: .linearGradient(Gradient(colors: [CH.tungsten.opacity(0.0), CH.tungsten.opacity(0.35), CH.tungsten.opacity(0.1)]),
                                     startPoint: CGPoint(x: lead, y: r.minY), endPoint: CGPoint(x: lead, y: r.maxY)))
    }

    /// A brass rod across the top with a couple of rings.
    static func rod(_ ctx: GraphicsContext, from a: CGFloat, to b: CGFloat, y: CGFloat, rings: [CGFloat], k: CGFloat = 1) {
        var sh = ctx
        sh.addFilter(.blur(radius: 1.5 * k))
        sh.fill(Path(CGRect(x: a, y: y + 1.5, width: b - a, height: 2.4 * k)), with: .color(.black.opacity(0.6)))
        let rod = CGRect(x: a, y: y - 1.2 * k, width: b - a, height: 2.4 * k)
        ctx.fill(Path(roundedRect: rod, cornerRadius: 1.2 * k), with: .linearGradient(
            Gradient(colors: [Color(hex: 0xF0C878), Color(hex: 0x9A6A2A), Color(hex: 0x3E2610)]),
            startPoint: CGPoint(x: a, y: rod.minY), endPoint: CGPoint(x: a, y: rod.maxY)))
        for x in rings {
            let ring = CGRect(x: x - 1.6 * k, y: y - 2.6 * k, width: 3.2 * k, height: 5.2 * k)
            ctx.stroke(Path(ellipseIn: ring), with: .color(Color(hex: 0xB8873E)), lineWidth: 0.8 * k)
        }
    }
}
