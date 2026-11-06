import SwiftUI

// The wallpaper: a top-down JRPG world map at 3 pt per pixel. Seeded value noise lays out ocean,
// shallows, foam, beaches, meadows, pine forests and snowcapped ranges; a castle and a road sit on land.

struct ValueNoise {
    let seed: UInt64

    func hash(_ x: Int, _ y: Int) -> Double {
        var h = UInt64(bitPattern: Int64(x &* 374_761_393 &+ y &* 668_265_263)) ^ seed
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        h = h &* 0x9E37_79B9_7F4A_7C15
        h ^= h >> 29
        return Double(h & 0xFFFF) / 65535
    }

    func at(_ x: Double, _ y: Double) -> Double {
        let xi = Int(floor(x)), yi = Int(floor(y))
        let fx = x - floor(x), fy = y - floor(y)
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        let a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1)
        return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy
    }

    func fbm(_ x: Double, _ y: Double) -> Double {
        0.55 * at(x / 26, y / 26) + 0.3 * at(x / 11 + 17, y / 11 + 5) + 0.15 * at(x / 5 + 41, y / 5 + 9)
    }
}

enum Terrain: UInt8 { case deep, shallow, foam, sand, grass, forest, hill, peak }

struct WorldMap {
    let w: Int
    let h: Int
    var t: [Terrain]

    init(w: Int, h: Int, seed: UInt64) {
        self.w = w
        self.h = h
        let n = ValueNoise(seed: seed), f = ValueNoise(seed: seed &+ 99)
        var t = [Terrain](repeating: .deep, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let v = n.fbm(Double(x), Double(y))
                let woods = f.fbm(Double(x) * 1.3, Double(y) * 1.3)
                var k: Terrain
                switch v {
                case ..<0.46: k = .deep
                case ..<0.50: k = .shallow
                case ..<0.512: k = .foam
                case ..<0.535: k = .sand
                case ..<0.65: k = woods > 0.55 ? .forest : .grass
                case ..<0.69: k = .hill
                default: k = .peak
                }
                t[y * w + x] = k
            }
        }
        self.t = t
    }

    func at(_ x: Int, _ y: Int) -> Terrain {
        t[max(0, min(h - 1, y)) * w + max(0, min(w - 1, x))]
    }

    func paint(_ b: inout PixelBuffer, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        // Ground colours.
        for y in 0..<h {
            for x in 0..<w {
                let c: C
                switch at(x, y) {
                case .deep: c = Bayer.on(x, y, 0.2 + 0.2 * sin(Double(x + y * 2) * 0.15)) ? .navy2 : .navy1
                case .shallow: c = Bayer.on(x, y, 0.4) ? .sky1 : .sky2
                case .foam: c = (x + y) & 1 == 0 ? .cloudW : .sky3
                case .sand: c = Bayer.on(x, y, 0.3) ? .earth2 : .earth3
                case .grass: c = Bayer.on(x, y, 0.22) ? .grass1 : .grass2
                case .forest: c = Bayer.on(x, y, 0.5) ? .pine1 : .grass1
                case .hill: c = Bayer.on(x, y, 0.4) ? .earth1 : .grass1
                case .peak: c = Bayer.on(x, y, 0.5) ? .stone0 : .earth1
                }
                b.set(x, y, c)
            }
        }
        // Wave glints on deep water.
        for _ in 0..<(w * h / 90) {
            let x = Int(rng.range(0...CGFloat(w - 3))), y = Int(rng.range(1...CGFloat(h - 1)))
            if at(x, y) == .deep && at(x + 2, y) == .deep {
                b.set(x, y, .sky3); b.set(x + 1, y - 1, .sky3); b.set(x + 2, y, .sky3)
            }
        }
        // Grass tufts.
        for _ in 0..<(w * h / 30) {
            let x = Int(rng.range(0...CGFloat(w - 1))), y = Int(rng.range(1...CGFloat(h - 1)))
            if at(x, y) == .grass { b.set(x, y, .grass3); b.set(x - 1, y - 1, .grass3); b.set(x + 1, y - 1, .grass3) }
        }
        // Forests: pines on a jittered lattice, back to front.
        for gy in stride(from: 0, to: h + 6, by: 4) {
            for gx in stride(from: (gy / 4) % 2 * 3, to: w + 6, by: 6) {
                let x = gx + Int(rng.range(-1...1.99)), y = gy + Int(rng.range(-1...1.99))
                if at(x, y) == .forest { b.draw(Sprites.smallPines[Int(rng.next() % 3)], x - 3, y - 6) }
            }
        }
        // Mountains: outlined triangles, snowcapped on the high ground.
        for gy in stride(from: 0, to: h + 10, by: 7) {
            for gx in stride(from: (gy / 7) % 2 * 6, to: w + 12, by: 12) {
                let x = gx + Int(rng.range(-2...2.99)), y = gy + Int(rng.range(-1...1.99))
                let k = at(x, y)
                guard k == .peak || (k == .hill && rng.unit() < 0.35) else { continue }
                b.mapMountain(x, y, size: k == .peak ? 7 : 5, snow: k == .peak)
            }
        }
    }
}

extension PixelBuffer {
    /// A world-map mountain: a triangle with lit and shaded faces, an ink outline and an optional snowcap.
    mutating func mapMountain(_ cx: Int, _ base: Int, size: Int, snow: Bool) {
        let top = base - size
        for y in top...base {
            let r = y - top
            for x in (cx - r)...(cx + r) {
                var c: C = x < cx ? .stone2 : (x == cx ? .stone1 : .stone0)
                if snow && r <= size / 2 { c = x <= cx ? .snowL : .snowS }
                if x == cx - r || x == cx + r || y == base { c = .ink }
                set(x, y, c)
            }
        }
        set(cx, top - 1, .ink)
        // Contact shadow.
        for x in (cx - size + 1)...(cx + size + 1) where x & 1 == 0 { set(x, base + 1, .ink) }
    }

    /// An original little castle: two towers, a keep with a red roof, a gate.
    mutating func castle(_ x: Int, _ y: Int) {
        let art = Sprite("""
        ..r.......r..
        .rrr.....rrr.
        orRro.r.orRro
        oSsSo.r.oSsSo
        oSSSorrroSSSo
        oSsSoRrRoSsSo
        oSSSSSSSSSSSo
        oSsSSoooSSsSo
        oSSSSodoSSSSo
        ooooooooooooo
        """, ["o": .ink, "r": .red1, "R": .red0, "S": .stone2, "s": .stone1, "d": .earth0])
        draw(art, x, y)
    }
}

struct Wallpaper: View {
    var body: some View {
        Canvas { ctx, size in
            let p: CGFloat = 3
            let w = Int((size.width / p).rounded(.up)), h = Int((size.height / p).rounded(.up))
            var b = PixelBuffer(w, h)
            let map = WorldMap(w: w, h: h, seed: 2026)
            map.paint(&b, seed: 7)
            // Castle on the first meadow found from the lower right.
            search: for y in stride(from: h - 20, to: 20, by: -3) {
                for x in stride(from: w - 30, to: w / 2, by: -3) where map.at(x, y) == .grass && map.at(x + 12, y + 9) == .grass {
                    b.castle(x, y)
                    break search
                }
            }
            b.render(ctx, pixel: p)
        }
    }
}
