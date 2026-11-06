import SwiftUI

/// Home-screen wallpaper: a dim cathedral light of leaded mosaic glass, glowing at the top and fading to the stone.
struct GlassWallpaper: View {
    var body: some View {
        Canvas { ctx, size in GlassRenderer.render(Self.window(size), &ctx, size) }
    }

    static func window(_ size: CGSize) -> Window {
        var w = Window()
        var rng = SeededRandom(seed: 0x5A1)
        let cell: CGFloat = 46
        let cols = Int(size.width / cell) + 3, rows = Int(size.height / cell) + 3
        var seeds: [CGPoint] = []
        for r in 0..<rows {
            for c in 0..<cols {
                seeds.append(CGPoint(x: (CGFloat(c) - 1 + rng.range(0.1...0.9)) * cell,
                                     y: (CGFloat(r) - 1 + rng.range(0.1...0.9)) * cell))
            }
        }
        let cells = Geo.voronoi(seeds, reach: cell * 2.6)
        let sky: [Glass] = [.cobalt, .ultramarine, .sapphire, .violet, .cobalt, .amethyst]
        let warm: [Glass] = [.amber, .gold, .garnet, .ruby]
        let low: [Glass] = [.emerald, .jade, .violet, .ultramarine]
        let glow = CGPoint(x: size.width * 0.5, y: -size.height * 0.02)
        for (i, poly) in cells.enumerated() where poly.count >= 3 {
            let c = Geo.centroid(poly)
            let d = hypot(c.x - glow.x, c.y - glow.y) / max(size.width, 1)
            let g: Glass
            if d < 0.13 { g = warm[Int(rng.next() % UInt64(warm.count))] }
            else if c.y > size.height * 0.72 { g = low[Int(rng.next() % UInt64(low.count))] }
            else { g = sky[Int(rng.next() % UInt64(sky.count))] }
            var p = Pane(path: Geo.poly(poly), glass: g, light: Geo.lerp(c, glow, 0.12))
            p.reach = 0.9
            p.texture = i % 2 == 0 ? .streaky : .hammered
            p.texAngle = Double(rng.range(0...360))
            p.texShift = CGPoint(x: rng.range(-120...120), y: rng.range(-120...120))
            p.lead = 3.4
            p.bloom = d < 0.13 ? 0.18 : 0
            p.corners = poly
            w.add(p)
        }
        w.backlight = glow
        w.backlightRadius = max(size.width, size.height) * 0.95
        w.vignette = 0.72
        w.bloomRadius = 12
        return w
    }
}

extension Geo {
    /// Voronoi cells by half-plane clipping (only against seeds within `reach`).
    static func voronoi(_ seeds: [CGPoint], reach: CGFloat) -> [[CGPoint]] {
        var out: [[CGPoint]] = []
        for (i, s) in seeds.enumerated() {
            var poly = [CGPoint(x: s.x - reach, y: s.y - reach), CGPoint(x: s.x + reach, y: s.y - reach),
                        CGPoint(x: s.x + reach, y: s.y + reach), CGPoint(x: s.x - reach, y: s.y + reach)]
            for (j, t) in seeds.enumerated() where j != i && abs(t.x - s.x) < reach * 2 && abs(t.y - s.y) < reach * 2 {
                poly = clip(poly, keepNear: s, awayFrom: t)
                if poly.isEmpty { break }
            }
            out.append(poly)
        }
        return out
    }

    static func clip(_ poly: [CGPoint], keepNear s: CGPoint, awayFrom t: CGPoint) -> [CGPoint] {
        let m = CGPoint(x: (s.x + t.x) / 2, y: (s.y + t.y) / 2)
        let n = CGPoint(x: t.x - s.x, y: t.y - s.y)
        func side(_ p: CGPoint) -> CGFloat { (p.x - m.x) * n.x + (p.y - m.y) * n.y }
        var out: [CGPoint] = []
        for i in 0..<poly.count {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            let sa = side(a), sb = side(b)
            if sa <= 0 { out.append(a) }
            if (sa <= 0) != (sb <= 0) {
                let t = sa / (sa - sb)
                out.append(lerp(a, b, t))
            }
        }
        return out
    }
}
