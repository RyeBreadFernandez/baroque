import SwiftUI

// JRPG interface pieces: bevelled double-border windows, stepping-stone day tiles, weather glyphs,
// the quest row furniture and the round "next" button.

extension PixelBuffer {
    /// A window: ink outline with rounded corners, a cream bevel, a dark gap, a gold inner line,
    /// and a navy interior that steps down through a dithered ramp. Border is 4 px; interior starts at +4.
    mutating func window(_ x: Int, _ y: Int, _ ww: Int, _ hh: Int, shadow: Bool = true, studs: Bool = true) {
        if shadow {
            for yy in (y + 2)..<(y + hh + 2) {
                for xx in (x + 2)..<(x + ww + 2) where (xx >= x + ww || yy >= y + hh) && (xx + yy) & 1 == 0 {
                    set(xx, yy, .ink)
                }
            }
        }
        interior(x + 3, y + 3, ww - 6, hh - 6)
        // Outline (corners cut).
        hline(x + 1, y, ww - 2, .ink); hline(x + 1, y + hh - 1, ww - 2, .ink)
        vline(x, y + 1, hh - 2, .ink); vline(x + ww - 1, y + 1, hh - 2, .ink)
        // Bevel: lit top/left, shaded bottom/right.
        hline(x + 2, y + 1, ww - 4, .cream); vline(x + 1, y + 2, hh - 4, .cream)
        hline(x + 2, y + hh - 2, ww - 4, .creamD); vline(x + ww - 2, y + 2, hh - 4, .creamD)
        set(x + 1, y + 1, .ink); set(x + ww - 2, y + 1, .ink); set(x + 1, y + hh - 2, .ink); set(x + ww - 2, y + hh - 2, .ink)
        // Dark gap.
        hline(x + 2, y + 2, ww - 4, .navy0); hline(x + 2, y + hh - 3, ww - 4, .navy0)
        vline(x + 2, y + 2, hh - 4, .navy0); vline(x + ww - 3, y + 2, hh - 4, .navy0)
        // Gold inner line, bevelled.
        hline(x + 3, y + 3, ww - 6, .gold2); vline(x + 3, y + 3, hh - 6, .gold2)
        hline(x + 4, y + hh - 4, ww - 7, .gold0); vline(x + ww - 4, y + 4, hh - 7, .gold0)
        if studs {
            for (sx, sy) in [(x + 2, y + 2), (x + ww - 3, y + 2), (x + 2, y + hh - 3), (x + ww - 3, y + hh - 3)] {
                stud(sx, sy)
            }
        }
    }

    /// A four-point twinkle.
    mutating func sparkle(_ cx: Int, _ cy: Int) {
        set(cx, cy - 2, .gold2); set(cx, cy + 2, .gold2); set(cx - 2, cy, .gold2); set(cx + 2, cy, .gold2)
        set(cx, cy - 1, .gold3); set(cx, cy + 1, .gold3); set(cx - 1, cy, .gold3); set(cx + 1, cy, .gold3)
        set(cx, cy, .white)
    }

    /// A small gold rivet centred on (cx, cy).
    mutating func stud(_ cx: Int, _ cy: Int) {
        set(cx, cy - 1, .ink); set(cx - 1, cy, .ink); set(cx + 1, cy, .ink); set(cx, cy + 1, .ink)
        set(cx, cy, .gold3)
        set(cx - 1, cy - 1, .gold2); set(cx + 1, cy + 1, .gold0); set(cx + 1, cy - 1, .gold1); set(cx - 1, cy + 1, .gold1)
    }

    /// The navy interior: a dithered vertical ramp.
    mutating func interior(_ x: Int, _ y: Int, _ iw: Int, _ ih: Int, ramp: [C] = [.navy4, .navy3, .navy2, .navy1]) {
        guard iw > 0, ih > 0 else { return }
        let n = ramp.count - 1
        for yy in y..<(y + ih) {
            let t = Double(yy - y) / Double(max(1, ih - 1)) * Double(n)
            let i = min(n - 1, Int(t))
            let f = max(0, min(1, (t - Double(i) - 0.5) * 1.8 + 0.5))
            for xx in x..<(x + iw) {
                var c = Bayer.on(xx, yy, f) ? ramp[i + 1] : ramp[i]
                // A faint quilted lattice, one step lighter, so the cloth reads as woven.
                if yy & 3 == 0 && (xx - yy) & 7 == 0, let k = ramp.firstIndex(of: c), k > 0 { c = ramp[k - 1] }
                set(xx, yy, c)
            }
        }
    }

    /// A thin plate (3 px border) for name tabs and the compact status box.
    mutating func plate(_ x: Int, _ y: Int, _ ww: Int, _ hh: Int, shadow: Bool = true) {
        if shadow {
            for yy in (y + 1)..<(y + hh + 1) {
                for xx in (x + 1)..<(x + ww + 1) where (xx >= x + ww || yy >= y + hh) && (xx + yy) & 1 == 0 { set(xx, yy, .ink) }
            }
        }
        interior(x + 2, y + 2, ww - 4, hh - 4, ramp: [.navy3, .navy2, .navy1])
        hline(x + 1, y, ww - 2, .ink); hline(x + 1, y + hh - 1, ww - 2, .ink)
        vline(x, y + 1, hh - 2, .ink); vline(x + ww - 1, y + 1, hh - 2, .ink)
        hline(x + 1, y + 1, ww - 2, .cream); vline(x + 1, y + 1, hh - 2, .cream)
        hline(x + 2, y + hh - 2, ww - 3, .creamD); vline(x + ww - 2, y + 2, hh - 3, .creamD)
        set(x + 1, y + 1, .ink); set(x + ww - 2, y + 1, .ink); set(x + 1, y + hh - 2, .ink); set(x + ww - 2, y + hh - 2, .ink)
    }

    /// A stepping-stone tile for the week strip.
    enum TileKind { case past, today, future }

    mutating func tile(_ x: Int, _ y: Int, _ tw: Int, _ th: Int, kind: TileKind) {
        let face: (C, C, C)
        switch kind {
        case .past: face = (.stone2, .stone1, .stone0)
        case .today: face = (.gold3, .gold2, .gold0)
        case .future: face = (.cream, .creamD, .earth2)
        }
        // Contact shadow on the road.
        for xx in (x + 1)..<(x + tw + 1) where xx & 1 == 0 { set(xx, y + th, .earth0) }
        set(x + tw, y + th - 1, .earth0)
        for yy in (y + 1)..<(y + th - 1) {
            let f = Double(yy - y) / Double(th)
            for xx in (x + 1)..<(x + tw - 1) { set(xx, yy, Bayer.on(xx, yy, max(0, f - 0.5) * 1.4) ? face.1 : face.0) }
        }
        hline(x + 1, y, tw - 2, .ink); hline(x + 1, y + th - 1, tw - 2, .ink)
        vline(x, y + 1, th - 2, .ink); vline(x + tw - 1, y + 1, th - 2, .ink)
        hline(x + 1, y + 1, tw - 2, kind == .today ? .white : .white)
        vline(x + 1, y + 1, th - 3, face.0)
        hline(x + 1, y + th - 2, tw - 2, face.2); vline(x + tw - 2, y + 2, th - 3, face.2)
        if kind != .today {
            set(x + 1, y + 1, .ink); set(x + tw - 2, y + 1, .ink)
        }
    }

    /// A dirt road band with dithered verges.
    mutating func road(_ y: Int, _ rh: Int, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        for yy in y..<(y + rh) {
            let f = Double(yy - y) / Double(max(1, rh - 1))
            for x in 0..<w {
                var c: C = Bayer.on(x, yy, f * 0.8) ? .earth1 : .earth2
                if yy == y { c = .earth3 }
                if yy == y + 1 && (x + yy) & 1 == 0 { c = .earth3 }
                set(x, yy, c)
            }
        }
        // Pebbles and ruts.
        for _ in 0..<(w / 3) {
            let x = Int(rng.range(0...CGFloat(w - 2)))
            let yy = y + 2 + Int(rng.range(0...CGFloat(max(1, rh - 3))))
            if rng.unit() < 0.5 { set(x, yy, .earth3); set(x + 1, yy + 1, .earth0) } else { set(x, yy, .earth0) }
        }
        // Grass fringe hanging over the top edge.
        for x in 0..<w where (x * 7 + 3) % 5 < 2 { set(x, y, .grass2) }
        for x in 0..<w where (x * 5 + 1) % 7 == 0 { set(x, y + 1, .grass1) }
    }

    // MARK: Weather glyphs (13 x 13)

    mutating func weatherGlyph(_ symbol: String, _ x: Int, _ y: Int) {
        let hasSun = symbol.contains("sun")
        let hasMoon = symbol.contains("moon")
        let hasCloud = symbol.contains("cloud")
        if hasSun { glyphSun(x + (hasCloud ? 4 : 6), y + (hasCloud ? 4 : 6), r: hasCloud ? 3 : 4) }
        if hasMoon && !hasSun { glyphMoon(x + (hasCloud ? 5 : 6), y + (hasCloud ? 4 : 6)) }
        if hasCloud {
            let low = symbol.contains("rain") || symbol.contains("snow") || symbol.contains("drizzle") || symbol.contains("bolt")
            glyphCloud(x + 1, y + (low ? 7 : 11), w: 11)
            if symbol.contains("rain") || symbol.contains("drizzle") {
                for k in 0..<3 { set(x + 3 + k * 3, y + 9, .sky3); set(x + 2 + k * 3, y + 10, .sky3); set(x + 3 + k * 3, y + 12, .sky2) }
            }
            if symbol.contains("snow") {
                for k in 0..<3 { set(x + 3 + k * 3, y + 9, .white); set(x + 2 + k * 3, y + 11, .snowS); set(x + 4 + k * 3, y + 12, .white) }
            }
            if symbol.contains("bolt") {
                let bolt = [(6, 8), (5, 9), (6, 9), (7, 9), (6, 10), (5, 11), (5, 12)]
                for (bx, by) in bolt { set(x + bx, y + by, .gold2) }
            }
            if symbol.contains("fog") {
                for k in 0..<3 { hline(x + 1 + k, y + 8 + k * 2, 10 - k, .cloudS) }
            }
        }
    }

    mutating func glyphSun(_ cx: Int, _ cy: Int, r: Int) {
        let rr = Double(r)
        let d = r + 2
        for k in 0..<2 {
            let c: C = k == 0 ? .gold2 : .gold1
            set(cx, cy - d - k, c); set(cx, cy + d + k, c); set(cx - d - k, cy, c); set(cx + d + k, cy, c)
        }
        set(cx - r - 1, cy - r - 1, .gold1); set(cx + r + 1, cy - r - 1, .gold1)
        set(cx - r - 1, cy + r + 1, .gold1); set(cx + r + 1, cy + r + 1, .gold1)
        for y in (cy - r - 1)...(cy + r + 1) {
            for x in (cx - r - 1)...(cx + r + 1) {
                let dx = Double(x - cx), dy = Double(y - cy)
                let q = dx * dx + dy * dy
                if q <= rr * rr + rr * 0.6 {
                    var c: C = .gold2
                    if dx + dy < -rr * 0.7 { c = .gold3 } else if dx + dy > rr * 0.8 { c = .gold1 }
                    set(x, y, c)
                } else if q <= (rr + 1) * (rr + 1) + rr * 0.6 {
                    set(x, y, .ink)
                }
            }
        }
        set(cx - 1, cy - 1, .white)
    }

    mutating func glyphMoon(_ cx: Int, _ cy: Int) {
        moon(cx, cy, r: 4)
    }

    mutating func glyphCloud(_ x: Int, _ bottom: Int, w cw: Int) {
        // Outline pass then fill: three bumps over a flat base.
        let bumps: [(Double, Double, Double)] = [
            (Double(x) + Double(cw) * 0.28, Double(bottom) - 2.2, Double(cw) * 0.22),
            (Double(x) + Double(cw) * 0.56, Double(bottom) - 3.2, Double(cw) * 0.3),
            (Double(x) + Double(cw) * 0.8, Double(bottom) - 1.8, Double(cw) * 0.2)
        ]
        func inside(_ px: Int, _ py: Int, grow: Double) -> Bool {
            if py > bottom { return false }
            if py >= bottom - 1 && px >= x && px < x + cw { return true }
            for b in bumps {
                let dx = Double(px) - b.0, dy = Double(py) - b.1
                if dx * dx + dy * dy <= (b.2 + grow) * (b.2 + grow) { return true }
            }
            return false
        }
        for py in (bottom - cw)...(bottom + 1) {
            for px in (x - 2)...(x + cw + 2) {
                if inside(px, py, grow: 0) {
                    set(px, py, py >= bottom - 1 ? .cloudS : .cloudW)
                } else if inside(px, py, grow: 1) || inside(px, py - 1, grow: 0) || inside(px - 1, py, grow: 0) || inside(px + 1, py, grow: 0) {
                    set(px, py, .ink)
                }
            }
        }
    }
}

/// The round "next quote" button: an ink rim, a bevelled gold ring, a navy well and a cream down-pointer.
/// 15 x 15 art px (30 pt), drawn in its own canvas so it can become a Button(intent:) in the widget.
struct NextButton: View {
    var body: some View {
        Canvas { ctx, _ in
            var b = PixelBuffer(15, 15)
            let c = 7.0
            for y in 0..<15 {
                for x in 0..<15 {
                    let dx = Double(x) - c, dy = Double(y) - c
                    let d = (dx * dx + dy * dy).squareRoot()
                    guard d <= 7.45 else { continue }
                    var col: C
                    if d > 6.5 { col = .ink }
                    else if d > 5.0 {
                        let s = dx + dy
                        col = s < -4 ? .gold3 : (s < 1 ? .gold2 : (s < 5 ? .gold1 : .gold0))
                    } else if d > 4.3 { col = .ink }
                    else { col = Bayer.on(x, y, (dy + 4.5) / 9) ? .navy1 : .navy3 }
                    b.set(x, y, col)
                }
            }
            // Down pointer (7 wide) with a hard shadow.
            let tri: [(Int, Int, Int)] = [(5, 4, 7), (6, 5, 5), (7, 6, 3), (8, 7, 1)]
            for (y, x0, n) in tri { b.hline(x0 + 1, y + 1, n, .ink) }
            for (y, x0, n) in tri { b.hline(x0, y, n, y == 5 ? .white : .cream) }
            b.set(3, 3, .white)
            b.render(ctx)
        }
        .frame(width: 30, height: 30)
    }
}
