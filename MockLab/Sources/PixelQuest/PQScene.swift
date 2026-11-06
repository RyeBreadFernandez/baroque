import SwiftUI

// The overworld: a banded, dithered sky; a pixel sun with rays; puffy clouds; two mountain ranges with
// snowcaps, crags and a light/shadow split; rolling hills crowned with pine forest; a tufted meadow.

struct Peak {
    var x: Int
    var y: Int
    var l: Double = 1.0
    var r: Double = 1.0
    var snow: Int = 0
}

struct RangeStyle {
    var rim: C, lit: C, mid: C, shade: C, cragLit: C, cragShade: C
    var snowLit: C = .snowL
    var snowShade: C = .snowS
    var haze: C?
    var hazeRows: Int = 0

    static let far = RangeStyle(rim: .snowL, lit: .farL, mid: .farM, shade: .farD, cragLit: .farM, cragShade: .slateM,
                                haze: .sky4, hazeRows: 8)
    static let near = RangeStyle(rim: .farL, lit: .slateL, mid: .slateM, shade: .slateD, cragLit: .slateM, cragShade: .slateB,
                                 haze: .farB, hazeRows: 6)
}

enum SkyMood {
    case day, night

    var bands: [C] {
        switch self {
        case .day: return [.sky0, .sky1, .sky2, .sky3, .sky4]
        case .night: return [.ink, .navy0, .navy1, .navy2, .navy3]
        }
    }
}

extension PixelBuffer {
    mutating func sky(_ mood: SkyMood, to bottom: Int, sharp: Double = 2.4) {
        let bands = mood.bands
        let n = bands.count - 1
        for y in 0..<min(h, bottom) {
            let t = Double(y) / Double(max(1, bottom - 1)) * Double(n)
            let i = min(n - 1, Int(t))
            let f = max(0, min(1, (t - Double(i) - 0.5) * sharp + 0.5))
            for x in 0..<w { px[y * w + x] = (Bayer.on(x, y, f) ? bands[i + 1] : bands[i]).rawValue }
        }
    }

    mutating func stars(count: Int, below: Int, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        for _ in 0..<count {
            let x = Int(rng.range(0...CGFloat(w - 1))), y = Int(rng.range(0...CGFloat(max(1, below))))
            set(x, y, rng.unit() < 0.3 ? .gold3 : .cream)
        }
    }

    private func lighter(_ c: C) -> C {
        switch c {
        case .sky0: return .sky1
        case .sky1: return .sky2
        case .sky2: return .sky3
        case .sky3: return .sky4
        case .sky4: return .cloudW
        default: return c
        }
    }

    mutating func sun(_ cx: Int, _ cy: Int, r: Int = 4) {
        let rr = Double(r)
        // Glow: lift the sky one band in a dithered halo.
        for y in (cy - r - 8)...(cy + r + 8) {
            for x in (cx - r - 8)...(cx + r + 8) {
                let d = hypot(Double(x - cx), Double(y - cy))
                guard d > rr + 1, d < rr + 8 else { continue }
                let f = 1 - (d - rr - 1) / 7
                if Bayer.on(x, y, f * 0.8) { set(x, y, lighter(get(x, y))) }
            }
        }
        // Rays: four long, four short.
        for k in 0..<3 {
            let d = r + 2 + k
            let c: C = k == 2 ? .gold1 : .gold2
            set(cx, cy - d, c); set(cx, cy + d, c); set(cx - d, cy, c); set(cx + d, cy, c)
        }
        for k in 0..<2 {
            let d = r - 1 + k
            let c: C = k == 1 ? .gold1 : .gold2
            set(cx - d, cy - d, c); set(cx + d, cy - d, c); set(cx - d, cy + d, c); set(cx + d, cy + d, c)
        }
        // Disc, lit from the upper left.
        for y in (cy - r)...(cy + r) {
            for x in (cx - r)...(cx + r) {
                let dx = Double(x - cx), dy = Double(y - cy)
                guard dx * dx + dy * dy <= rr * rr + rr * 0.6 else { continue }
                let s = dx + dy
                var c: C = .gold2
                if s < -rr * 0.8 { c = .gold3 } else if s > rr * 0.9 { c = .gold1 }
                if dx * dx + dy * dy > rr * rr - rr * 0.6 && s > 0 { c = .gold1 }
                set(x, y, c)
            }
        }
        set(cx - r / 2, cy - r / 2, .white)
    }

    mutating func moon(_ cx: Int, _ cy: Int, r: Int = 4) {
        let rr = Double(r)
        for y in (cy - r)...(cy + r) {
            for x in (cx - r)...(cx + r) {
                let dx = Double(x - cx), dy = Double(y - cy)
                guard dx * dx + dy * dy <= rr * rr + rr * 0.6 else { continue }
                let ex = dx - rr * 0.6, ey = dy + rr * 0.2
                if ex * ex + ey * ey < rr * rr * 0.75 { continue }
                set(x, y, dx + dy < 0 ? .cream : .creamD)
            }
        }
    }

    /// A puffy cloud with a flat, shaded base sitting on `bottom`.
    mutating func cloud(_ x: Int, _ bottom: Int, width: Int, seed: UInt64, tone: (C, C, C) = (.cloudW, .cloudS, .cloudD)) {
        var rng = SeededRandom(seed: seed)
        var puffs: [(Double, Double, Double)] = []
        var cx = Double(x) + 2.5
        while cx < Double(x + width - 2) {
            let mid = 1 - abs((cx - Double(x)) / Double(width) - 0.5) * 2
            let r = Double(rng.range(2.0...2.8)) + mid * Double(rng.range(1.6...3.4))
            puffs.append((cx, Double(bottom) - r * 0.9, r))
            cx += r * Double(rng.range(0.8...1.15))
        }
        let x0 = x - 4, x1 = x + width + 4, y0 = bottom - 16
        let cw = x1 - x0 + 1, ch = bottom - y0 + 1
        var mask = [Bool](repeating: false, count: cw * ch)
        func m(_ px: Int, _ py: Int) -> Bool {
            px >= x0 && px <= x1 && py >= y0 && py <= bottom && mask[(py - y0) * cw + (px - x0)]
        }
        for py in y0...bottom {
            for px in x0...x1 {
                for p in puffs {
                    let dx = Double(px) - p.0, dy = Double(py) - p.1
                    if dx * dx + dy * dy <= p.2 * p.2 { mask[(py - y0) * cw + (px - x0)] = true; break }
                }
            }
        }
        _ = ch
        for py in y0...bottom {
            for px in x0...x1 where m(px, py) {
                let fb = bottom - py
                var c = tone.0
                // Lit upper-left rims of each bump, shaded lower-right rims and a flat shaded base.
                if !m(px - 1, py - 1) || !m(px, py - 1) { c = tone.0 == .cloudW ? .white : tone.0 }
                if !m(px + 1, py + 1) || !m(px + 2, py + 1) { c = tone.1 }
                if fb <= 1 { c = tone.1 }
                if fb == 0 { c = tone.2 }
                if fb == 2 && Bayer.on(px, py, 0.5) { c = tone.1 }
                set(px, py, c)
            }
        }
    }

    /// A mountain range: cones around each peak with a jagged ridge, a lit/shaded split, crags, snowcaps and base haze.
    mutating func mountains(_ peaks: [Peak], bottom: Int, style s: RangeStyle, seed: UInt64) {
        guard !peaks.isEmpty else { return }
        var rng = SeededRandom(seed: seed)
        var jag = [Int](repeating: 0, count: w)
        var walk = 0.0
        for x in 0..<w {
            walk += Double(rng.range(-0.9...0.9))
            walk = max(-1.4, min(1.4, walk))
            jag[x] = Int(walk.rounded())
        }
        var snowJag = [Int](repeating: 0, count: w)
        for x in 0..<w {
            var v = Int(rng.range(0...2.99))
            if rng.unit() < 0.22 { v += Int(rng.range(2...4.99)) }
            snowJag[x] = v
        }
        var owner = [Int](repeating: 0, count: w)
        var top = [Int](repeating: Int.max, count: w)
        for x in 0..<w {
            for (i, p) in peaks.enumerated() {
                let dx = Double(x - p.x)
                let t = p.y + Int((abs(dx) * (dx < 0 ? p.l : p.r)).rounded())
                if t < top[x] { top[x] = t; owner[x] = i }
            }
            if abs(x - peaks[owner[x]].x) > 1 { top[x] += jag[x] }
        }
        var lit = [Bool](repeating: false, count: w * h)
        var mine = [Bool](repeating: false, count: w * h)
        for x in 0..<w {
            let p = peaks[owner[x]]
            let t0 = max(0, top[x])
            let b = min(bottom, h)
            guard t0 < b else { continue }
            for y in t0..<b {
                let down = Double(y - p.y)
                let wig = sin(Double(y) * 0.8 + Double(p.x) * 0.37) * 0.9
                let split = Double(p.x) + down * 0.25 + wig
                let dx = Double(x) - split
                let isLit = dx < -0.5
                var c: C = isLit ? s.lit : s.shade
                if abs(dx) < 1.6 && Bayer.on(x, y, 0.5) { c = s.mid }
                if y == top[x] && isLit { c = s.rim }
                let snowLine = p.y + p.snow + snowJag[x]
                let ridgeSnow = y - top[x] < 2 && y < p.y + p.snow + 4
                if p.snow > 0 && (y < snowLine || ridgeSnow || (y == snowLine && (x + y) & 1 == 0)) {
                    c = isLit ? s.snowLit : s.snowShade
                }
                if let hz = s.haze, s.hazeRows > 0 {
                    let f = Double(y - (bottom - s.hazeRows)) / Double(s.hazeRows)
                    if f > 0 && Bayer.on(x, y, f * 0.85) { c = hz }
                }
                set(x, y, c)
                lit[y * w + x] = isLit
                mine[y * w + x] = true
            }
        }
        // Crags: short strokes parallel to the ridges.
        for p in peaks {
            let height = bottom - p.y
            guard height > 8 else { continue }
            let n = 6 + height / 3
            for _ in 0..<n {
                let side: Int = rng.unit() < 0.5 ? -1 : 1
                let sy = p.y + max(p.snow, 2) + 1 + Int(rng.range(0...CGFloat(max(1, height - p.snow - 6))))
                let reach = Double(sy - p.y) / (side < 0 ? p.l : p.r)
                let sx = p.x + side * Int(Double(rng.range(0.1...0.85)) * reach)
                let len = Int(rng.range(2...4.99))
                let slope = side < 0 ? p.l : p.r
                for k in 0..<len {
                    let xx = sx + side * Int((Double(k) / slope).rounded())
                    let yy = sy + k
                    guard inside(xx, yy), mine[yy * w + xx] else { continue }
                    let cur = get(xx, yy)
                    if cur == s.snowLit || cur == s.snowShade || cur == s.haze { continue }
                    set(xx, yy, lit[yy * w + xx] ? s.cragLit : s.cragShade)
                }
            }
        }
    }

    /// Rolling hills; returns the top line so forests can stand on it.
    @discardableResult
    mutating func hills(base: Int, amp: Double, period: Double, phase: Double, bottom: Int,
                        rim: C, body: C, dark: C, fade: Double = 0.9) -> [Int] {
        var line = [Int](repeating: base, count: w)
        for x in 0..<w {
            let t = Double(x) / period * 2 * .pi
            let v = 0.6 * sin(t + phase) + 0.3 * sin(t * 2.1 + phase * 1.7) + 0.1 * sin(t * 4.3 + phase * 0.5)
            line[x] = base - Int((amp * v).rounded())
        }
        for x in 0..<w {
            let t0 = max(0, line[x]), b = min(h, bottom)
            guard t0 < b else { continue }
            for y in t0..<b {
                let f = Double(y - line[x]) / Double(max(1, bottom - line[x]))
                var c = Bayer.on(x, y, f * fade) ? dark : body
                if y == line[x] { c = rim }
                set(x, y, c)
            }
        }
        return line
    }

    mutating func forest(_ line: [Int], sprites: [Sprite], sink: Int, step: ClosedRange<Int>, seed: UInt64,
                         from: Int = -4, to: Int? = nil) {
        var rng = SeededRandom(seed: seed)
        var x = from + Int(rng.range(0...3))
        let end = to ?? (w + 4)
        while x < end {
            let s = sprites[Int(rng.next() % UInt64(sprites.count))]
            let lx = max(0, min(w - 1, x))
            draw(s, x - s.w / 2, line[lx] + sink - s.h + Int(rng.range(0...1.99)))
            x += Int(rng.range(CGFloat(step.lowerBound)...(CGFloat(step.upperBound) + 0.99)))
        }
    }

    /// A tufted meadow with a few flowers.
    mutating func meadow(top: Int, bottom: Int, seed: UInt64, flowers: Int = 6) {
        var rng = SeededRandom(seed: seed)
        let b = min(h, bottom)
        guard top < b else { return }
        for y in max(0, top)..<b {
            let f = Double(y - top) / Double(max(1, bottom - top))
            for x in 0..<w {
                var c: C = Bayer.on(x, y, f * 0.75) ? .grass1 : .grass2
                if y == top { c = .grass3 }
                set(x, y, c)
            }
        }
        let n = w * (bottom - top) / 12
        for _ in 0..<n {
            let x = Int(rng.range(0...CGFloat(w - 1)))
            let y = top + 2 + Int(rng.range(0...CGFloat(max(1, bottom - top - 3))))
            if rng.unit() < 0.55 {
                set(x, y, .grass3); set(x - 1, y - 1, .grass3); set(x + 1, y - 1, .grass3)
            } else {
                set(x, y, .grass0); set(x, y - 1, .grass1)
            }
        }
        for _ in 0..<flowers {
            let x = Int(rng.range(2...CGFloat(w - 3)))
            let y = top + 2 + Int(rng.range(0...CGFloat(max(1, bottom - top - 4))))
            let c: C = [.red2, .cream, .gold2][Int(rng.next() % 3)]
            set(x, y, c); set(x, y + 1, .grass0)
        }
        // Grass blades poking above the rim.
        for _ in 0..<(w / 5) {
            let x = Int(rng.range(0...CGFloat(w - 1)))
            set(x, top - 1, .grass3)
        }
    }

    /// A few distant birds.
    mutating func birds(_ list: [(Int, Int)]) {
        for (x, y) in list {
            set(x - 1, y - 1, .navy1); set(x, y, .navy1); set(x + 1, y - 1, .navy1)
            set(x - 2, y - 1, .navy2); set(x + 2, y - 1, .navy2)
        }
    }

    /// A small treasure chest with gold bands.
    mutating func chest(_ x: Int, _ y: Int) {
        draw(Sprite("""
        .oooooooooo.
        oe3333333eeo
        oeEEEgEEEe1o
        oooooGoooooo
        o2E2EgE2E21o
        o222EoE2221o
        o22222222210
        .oooooooooo.
        """, ["o": .ink, "e": .earth2, "3": .earth3, "E": .earth2, "2": .earth1, "1": .earth0, "0": .ink,
              "g": .gold2, "G": .gold3]), x, y)
        for xx in (x + 1)...(x + 12) where xx & 1 == 0 { set(xx, y + 8, .grass0) }
    }

    /// A mossy boulder for the owl to perch on.
    mutating func boulder(_ cx: Int, _ base: Int, w bw: Int = 14, h bh: Int = 7) {
        let rx = Double(bw) / 2, ry = Double(bh)
        for y in (base - bh)...base {
            for x in (cx - bw / 2 - 1)...(cx + bw / 2 + 1) {
                let dx = (Double(x) - Double(cx)) / rx, dy = (Double(y) - Double(base)) / ry
                let d = dx * dx + dy * dy
                guard d <= 1.0 else { continue }
                var c: C = .stone1
                if dx + dy * 0.6 < -0.75 { c = .stone2 } else if dx - dy * 0.3 > 0.35 { c = .stone0 }
                if d > 0.78 { c = .ink }
                if y == base { c = .ink }
                set(x, y, c)
            }
        }
        // Moss on the crown.
        for x in (cx - bw / 2 + 2)...(cx + 1) {
            let dx = (Double(x) - Double(cx)) / rx
            let yy = base - Int((ry * (1 - dx * dx).squareRoot()).rounded()) + 1
            set(x, yy, .grass2); if x % 3 == 0 { set(x, yy + 1, .grass1) }
        }
        // Dithered contact shadow.
        for x in (cx - bw / 2)...(cx + bw / 2 + 2) where x & 1 == 0 { set(x, base + 1, .grass0) }
    }
}
