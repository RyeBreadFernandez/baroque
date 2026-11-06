import SwiftUI

// A proportional 5x7 bitmap font drawn by hand: uppercase, lowercase (with two descender rows),
// digits and the symbols the widgets need. Row 0 is the cap top; the baseline sits under row 6.

enum PixelFont {
    struct Glyph {
        let w: Int
        let on: [(Int, Int)]
    }

    static let capHeight = 7
    /// Cap height + descenders + 2 rows of leading.
    static let lineAdvance = 11
    static let spaceWidth = 3

    static let glyphs: [Character: Glyph] = parse(source)

    static func normalize(_ s: String) -> String {
        var t = s.folding(options: .diacriticInsensitive, locale: nil)
        let swaps: [(String, String)] = [("\u{2019}", "'"), ("\u{2018}", "'"), ("\u{201C}", "\""), ("\u{201D}", "\""),
                                         ("\u{2013}", "-"), ("\u{2015}", "\u{2014}"), ("\t", " ")]
        for (a, b) in swaps { t = t.replacingOccurrences(of: a, with: b) }
        return t
    }

    static func glyph(_ ch: Character) -> Glyph? {
        if let g = glyphs[ch] { return g }
        if let g = glyphs[Character(String(ch).uppercased())] { return g }
        return glyphs["?"]
    }

    /// Lit pixels of a run of text (in font pixels, origin at the cap top-left) and its width.
    static func run(_ s: String) -> (on: [(Int, Int)], width: Int) {
        var x = 0
        var pts: [(Int, Int)] = []
        for ch in normalize(s) {
            if ch == " " { x += spaceWidth + 1; continue }
            guard let g = glyph(ch) else { continue }
            for (gx, gy) in g.on { pts.append((x + gx, gy)) }
            x += g.w + 1
        }
        return (pts, max(0, x - 1))
    }

    static func width(_ s: String) -> Int { run(s).width }

    /// Greedy word wrap; `limit(i)` is the width available to line i in font pixels.
    static func wrap(_ text: String, limit: (Int) -> Int) -> [String] {
        let words = normalize(text).split(separator: " ").map(String.init)
        var lines: [String] = []
        var cur = ""
        for word in words {
            let candidate = cur.isEmpty ? word : cur + " " + word
            if width(candidate) <= limit(lines.count) {
                cur = candidate
                continue
            }
            if !cur.isEmpty { lines.append(cur) }
            cur = word
            // Hard-break a single word that is wider than the line.
            while width(cur) > limit(lines.count) && cur.count > 1 {
                var head = ""
                for ch in cur {
                    if width(head + String(ch)) > limit(lines.count) { break }
                    head.append(ch)
                }
                if head.isEmpty { break }
                lines.append(head)
                cur = String(cur.dropFirst(head.count))
            }
        }
        if !cur.isEmpty { lines.append(cur) }
        return lines
    }

    /// Draw text in a GraphicsContext at any pixel size (snapped to the @3x grid), with a hard drop shadow.
    static func draw(_ ctx: GraphicsContext, _ s: String, x: CGFloat, y: CGFloat, px: CGFloat,
                     color: C, shadow: C? = .ink) {
        let r = run(s)
        let ox = PQ.snap(x), oy = PQ.snap(y)
        func path(_ dx: CGFloat, _ dy: CGFloat) -> Path {
            var p = Path()
            for (gx, gy) in r.on {
                p.addRect(CGRect(x: ox + (CGFloat(gx) + dx) * px, y: oy + (CGFloat(gy) + dy) * px, width: px, height: px))
            }
            return p
        }
        if let shadow {
            ctx.fill(path(1, 1), with: .color(PQ.color(shadow)), style: FillStyle(antialiased: false))
        }
        ctx.fill(path(0, 0), with: .color(PQ.color(color)), style: FillStyle(antialiased: false))
    }

    static func draw(_ ctx: GraphicsContext, runs: [(String, C)], x: CGFloat, y: CGFloat, px: CGFloat, shadow: C? = .ink) {
        var cx = x
        for (s, c) in runs {
            draw(ctx, s, x: cx, y: y, px: px, color: c, shadow: shadow)
            cx += CGFloat(width(s) + 1) * px
        }
    }

    static func width(runs: [(String, C)]) -> Int {
        runs.reduce(0) { $0 + width($1.0) + 1 } - 1
    }

    private static func parse(_ src: String) -> [Character: Glyph] {
        var out: [Character: Glyph] = [:]
        var current: Character?
        var rows: [String] = []
        func flush() {
            guard let ch = current else { return }
            let w = rows.map(\.count).max() ?? 0
            var on: [(Int, Int)] = []
            for (y, row) in rows.enumerated() {
                for (x, c) in row.enumerated() where c == "#" { on.append((x, y)) }
            }
            out[ch] = Glyph(w: w, on: on)
        }
        for line in src.split(separator: "\n") {
            if line.hasPrefix(">") && line.count == 2 {
                flush()
                current = line.last
                rows = []
            } else {
                rows.append(String(line))
            }
        }
        flush()
        return out
    }

    // Glyph source: ">X" starts a glyph, then its rows ('#' on, '.' off).
    private static let source = """
    >A
    .###.
    #...#
    #...#
    #####
    #...#
    #...#
    #...#
    >B
    ####.
    #...#
    #...#
    ####.
    #...#
    #...#
    ####.
    >C
    .###.
    #...#
    #....
    #....
    #....
    #...#
    .###.
    >D
    ####.
    #...#
    #...#
    #...#
    #...#
    #...#
    ####.
    >E
    #####
    #....
    #....
    ####.
    #....
    #....
    #####
    >F
    #####
    #....
    #....
    ####.
    #....
    #....
    #....
    >G
    .###.
    #...#
    #....
    #.###
    #...#
    #...#
    .####
    >H
    #...#
    #...#
    #...#
    #####
    #...#
    #...#
    #...#
    >I
    ###
    .#.
    .#.
    .#.
    .#.
    .#.
    ###
    >J
    ..###
    ...#.
    ...#.
    ...#.
    #..#.
    #..#.
    .##..
    >K
    #...#
    #..#.
    #.#..
    ##...
    #.#..
    #..#.
    #...#
    >L
    #....
    #....
    #....
    #....
    #....
    #....
    #####
    >M
    #...#
    ##.##
    #.#.#
    #.#.#
    #...#
    #...#
    #...#
    >N
    #...#
    #...#
    ##..#
    #.#.#
    #..##
    #...#
    #...#
    >O
    .###.
    #...#
    #...#
    #...#
    #...#
    #...#
    .###.
    >P
    ####.
    #...#
    #...#
    ####.
    #....
    #....
    #....
    >Q
    .###.
    #...#
    #...#
    #...#
    #.#.#
    #..#.
    .##.#
    >R
    ####.
    #...#
    #...#
    ####.
    #.#..
    #..#.
    #...#
    >S
    .####
    #....
    #....
    .###.
    ....#
    ....#
    ####.
    >T
    #####
    ..#..
    ..#..
    ..#..
    ..#..
    ..#..
    ..#..
    >U
    #...#
    #...#
    #...#
    #...#
    #...#
    #...#
    .###.
    >V
    #...#
    #...#
    #...#
    #...#
    #...#
    .#.#.
    ..#..
    >W
    #...#
    #...#
    #...#
    #.#.#
    #.#.#
    #.#.#
    .#.#.
    >X
    #...#
    #...#
    .#.#.
    ..#..
    .#.#.
    #...#
    #...#
    >Y
    #...#
    #...#
    .#.#.
    ..#..
    ..#..
    ..#..
    ..#..
    >Z
    #####
    ....#
    ...#.
    ..#..
    .#...
    #....
    #####
    >a
    .....
    .....
    .###.
    ....#
    .####
    #...#
    .####
    >b
    #....
    #....
    ####.
    #...#
    #...#
    #...#
    ####.
    >c
    ....
    ....
    .###
    #...
    #...
    #...
    .###
    >d
    ....#
    ....#
    .####
    #...#
    #...#
    #...#
    .####
    >e
    .....
    .....
    .###.
    #...#
    #####
    #....
    .###.
    >f
    ..##
    .#..
    ####
    .#..
    .#..
    .#..
    .#..
    >g
    .....
    .....
    .####
    #...#
    #...#
    #...#
    .####
    ....#
    .###.
    >h
    #....
    #....
    ####.
    #...#
    #...#
    #...#
    #...#
    >i
    #
    .
    #
    #
    #
    #
    #
    >j
    ..#
    ...
    ..#
    ..#
    ..#
    ..#
    ..#
    ..#
    ##.
    >k
    #...
    #...
    #..#
    #.#.
    ##..
    #.#.
    #..#
    >l
    #.
    #.
    #.
    #.
    #.
    #.
    .#
    >m
    .....
    .....
    ##.#.
    #.#.#
    #.#.#
    #.#.#
    #.#.#
    >n
    .....
    .....
    ####.
    #...#
    #...#
    #...#
    #...#
    >o
    .....
    .....
    .###.
    #...#
    #...#
    #...#
    .###.
    >p
    .....
    .....
    ####.
    #...#
    #...#
    #...#
    ####.
    #....
    #....
    >q
    .....
    .....
    .####
    #...#
    #...#
    #...#
    .####
    ....#
    ....#
    >r
    ....
    ....
    #.##
    ##..
    #...
    #...
    #...
    >s
    .....
    .....
    .####
    #....
    .###.
    ....#
    ####.
    >t
    .#..
    .#..
    ####
    .#..
    .#..
    .#..
    ..##
    >u
    .....
    .....
    #...#
    #...#
    #...#
    #...#
    .####
    >v
    .....
    .....
    #...#
    #...#
    #...#
    .#.#.
    ..#..
    >w
    .....
    .....
    #...#
    #...#
    #.#.#
    #.#.#
    .#.#.
    >x
    .....
    .....
    #...#
    .#.#.
    ..#..
    .#.#.
    #...#
    >y
    .....
    .....
    #...#
    #...#
    #...#
    #...#
    .####
    ....#
    .###.
    >z
    .....
    .....
    #####
    ...#.
    ..#..
    .#...
    #####
    >0
    .###.
    #...#
    #..##
    #.#.#
    ##..#
    #...#
    .###.
    >1
    ..#..
    .##..
    ..#..
    ..#..
    ..#..
    ..#..
    .###.
    >2
    .###.
    #...#
    ....#
    ...#.
    ..#..
    .#...
    #####
    >3
    #####
    ...#.
    ..#..
    ...#.
    ....#
    #...#
    .###.
    >4
    ...#.
    ..##.
    .#.#.
    #..#.
    #####
    ...#.
    ...#.
    >5
    #####
    #....
    ####.
    ....#
    ....#
    #...#
    .###.
    >6
    ..##.
    .#...
    #....
    ####.
    #...#
    #...#
    .###.
    >7
    #####
    ....#
    ...#.
    ..#..
    .#...
    .#...
    .#...
    >8
    .###.
    #...#
    #...#
    .###.
    #...#
    #...#
    .###.
    >9
    .###.
    #...#
    #...#
    .####
    ....#
    ...#.
    .##..
    >.
    .
    .
    .
    .
    .
    .
    #
    >,
    ..
    ..
    ..
    ..
    ..
    .#
    .#
    #.
    >:
    .
    .
    #
    .
    .
    #
    .
    >;
    ..
    ..
    .#
    ..
    ..
    .#
    .#
    #.
    >!
    #
    #
    #
    #
    #
    .
    #
    >?
    .###.
    #...#
    ....#
    ...#.
    ..#..
    .....
    ..#..
    >'
    #
    #
    .
    >"
    #.#
    #.#
    ...
    >-
    ....
    ....
    ....
    ####
    >—
    .......
    .......
    .......
    #######
    >+
    .....
    ..#..
    ..#..
    #####
    ..#..
    ..#..
    >/
    ....#
    ...#.
    ...#.
    ..#..
    .#...
    .#...
    #....
    >(
    ..#
    .#.
    #..
    #..
    #..
    .#.
    ..#
    >)
    #..
    .#.
    ..#
    ..#
    ..#
    .#.
    #..
    >[
    ##
    #.
    #.
    #.
    #.
    #.
    ##
    >]
    ##
    .#
    .#
    .#
    .#
    .#
    ##
    >°
    .##.
    #..#
    #..#
    .##.
    >▲
    .......
    .......
    ...#...
    ..###..
    .#####.
    #######
    >▼
    .......
    .......
    #######
    .#####.
    ..###..
    ...#...
    >↑
    ..#..
    .###.
    #.#.#
    ..#..
    .....
    .###.
    #####
    >↓
    ..#..
    #.#.#
    .###.
    ..#..
    .....
    .###.
    #####
    >★
    ...#...
    ...#...
    #######
    .#####.
    ..###..
    .##.##.
    .#...#.
    >…
    .....
    .....
    .....
    .....
    .....
    .....
    #.#.#
    >&
    .##..
    #..#.
    #.#..
    .#...
    #.#.#
    #..#.
    .##.#
    >#
    .#.#.
    .#.#.
    #####
    .#.#.
    #####
    .#.#.
    .#.#.
    >%
    ##...
    ##..#
    ...#.
    ..#..
    .#...
    #..##
    ...##
    >=
    ....
    ....
    ####
    ....
    ####
    >*
    .....
    #.#.#
    .###.
    #####
    .###.
    #.#.#
    >_
    ....
    ....
    ....
    ....
    ....
    ....
    ####
    >@
    .###.
    #...#
    #.###
    #.#.#
    #.###
    #....
    .###.
    """
}

extension PixelBuffer {
    /// Text on the art grid at an integer scale. `outline` rings each pixel in 8 directions (for text over the scene);
    /// `ramp` shades the glyphs top to bottom (gold numerals).
    mutating func text(_ s: String, _ x: Int, _ y: Int, _ c: C, scale k: Int = 1,
                       shadow: C? = .ink, outline: C? = nil, ramp: [C]? = nil) {
        let r = PixelFont.run(s)
        if let o = outline {
            for (gx, gy) in r.on {
                for oy in -1...1 { for ox in -1...1 { rect(x + gx * k + ox, y + gy * k + oy, k, k, o) } }
            }
        }
        if let sh = shadow {
            for (gx, gy) in r.on { rect(x + gx * k + 1, y + gy * k + 1, k, k, sh) }
        }
        let rows = PixelFont.capHeight * k
        for (gx, gy) in r.on {
            for yy in 0..<k {
                for xx in 0..<k {
                    let ry = gy * k + yy
                    var col = c
                    if let ramp, !ramp.isEmpty {
                        col = ramp[min(ramp.count - 1, max(0, ry * ramp.count / max(1, rows)))]
                    }
                    set(x + gx * k + xx, y + ry, col)
                }
            }
        }
    }
}

/// Bold display digits (2 px strokes, 7 x 10) for the date and the temperature, embossed in gold.
enum BigDigits {
    static let height = 10
    static let glyphs: [Character: PixelFont.Glyph] = parse(source)

    static func width(_ s: String) -> Int {
        var x = 0
        for ch in s { if let g = glyphs[ch] { x += g.w + 1 } }
        return max(0, x - 1)
    }

    static func run(_ s: String) -> [(Int, Int)] {
        var x = 0
        var pts: [(Int, Int)] = []
        for ch in s {
            guard let g = glyphs[ch] else { continue }
            for (gx, gy) in g.on { pts.append((x + gx, gy)) }
            x += g.w + 1
        }
        return pts
    }

    private static func parse(_ src: String) -> [Character: PixelFont.Glyph] {
        var out: [Character: PixelFont.Glyph] = [:]
        var current: Character?
        var rows: [String] = []
        func flush() {
            guard let ch = current else { return }
            var on: [(Int, Int)] = []
            for (y, row) in rows.enumerated() { for (x, c) in row.enumerated() where c == "#" { on.append((x, y)) } }
            out[ch] = PixelFont.Glyph(w: rows.map(\.count).max() ?? 0, on: on)
        }
        for line in src.split(separator: "\n") {
            if line.hasPrefix(">") && line.count == 2 { flush(); current = line.last; rows = [] } else { rows.append(String(line)) }
        }
        flush()
        return out
    }

    private static let source = """
    >0
    .#####.
    #######
    ##...##
    ##...##
    ##...##
    ##...##
    ##...##
    ##...##
    #######
    .#####.
    >1
    ...##..
    ..###..
    .####..
    ...##..
    ...##..
    ...##..
    ...##..
    ...##..
    .######
    .######
    >2
    .#####.
    #######
    ##...##
    .....##
    ..#####
    .#####.
    ##.....
    ##.....
    #######
    #######
    >3
    ######.
    #######
    .....##
    .....##
    ..####.
    ..#####
    .....##
    .....##
    #######
    ######.
    >4
    ##...##
    ##...##
    ##...##
    ##...##
    #######
    #######
    .....##
    .....##
    .....##
    .....##
    >5
    #######
    #######
    ##.....
    ##.....
    ######.
    #######
    .....##
    .....##
    #######
    ######.
    >6
    .######
    #######
    ##.....
    ##.....
    ######.
    #######
    ##...##
    ##...##
    #######
    .#####.
    >7
    #######
    #######
    .....##
    .....##
    ....##.
    ...##..
    ..##...
    ..##...
    ..##...
    ..##...
    >8
    .#####.
    #######
    ##...##
    ##...##
    .#####.
    #######
    ##...##
    ##...##
    #######
    .#####.
    >9
    .#####.
    #######
    ##...##
    ##...##
    #######
    .######
    .....##
    .....##
    ######.
    #####..
    >°
    .##.
    #..#
    #..#
    .##.
    >-
    .....
    .....
    .....
    .....
    #####
    #####
    """
}

extension PixelBuffer {
    /// Embossed gold numerals: an ink outline with a deeper drop to the lower right, a vertical gold ramp,
    /// bright top/left edges and dark bottom/right edges.
    mutating func bigNumber(_ s: String, _ x: Int, _ y: Int, scale k: Int = 2,
                            ramp: [C] = [.gold3, .gold2, .gold2, .gold2, .gold1, .gold1],
                            hi: C = .white, lo: C = .gold0, outline: C = .ink) {
        let pts = BigDigits.run(s)
        let gw = BigDigits.width(s) * k, gh = BigDigits.height * k
        var mask = [Bool](repeating: false, count: (gw + 4) * (gh + 4))
        func idx(_ ax: Int, _ ay: Int) -> Int { (ay + 2) * (gw + 4) + (ax + 2) }
        func m(_ ax: Int, _ ay: Int) -> Bool { ax >= -2 && ay >= -2 && ax < gw + 2 && ay < gh + 2 && mask[idx(ax, ay)] }
        for (gx, gy) in pts { for yy in 0..<k { for xx in 0..<k { mask[idx(gx * k + xx, gy * k + yy)] = true } } }
        // Outline and extruded drop.
        for ay in -2..<(gh + 2) {
            for ax in -2..<(gw + 2) where !m(ax, ay) {
                var near = false
                for oy in -1...1 { for ox in -1...1 where m(ax + ox, ay + oy) { near = true } }
                if near || m(ax - 1, ay - 1) || m(ax - 2, ay - 2) || m(ax - 1, ay - 2) || m(ax - 2, ay - 1) { set(x + ax, y + ay, outline) }
            }
        }
        for ay in 0..<gh {
            for ax in 0..<gw where m(ax, ay) {
                var c = ramp[min(ramp.count - 1, ay * ramp.count / gh)]
                if !m(ax, ay - 1) || !m(ax - 1, ay) { c = hi }
                if !m(ax, ay + 1) || !m(ax + 1, ay) { c = lo }
                if !m(ax, ay - 1) && !m(ax + 1, ay) { c = ramp[0] }
                set(x + ax, y + ay, c)
            }
        }
    }
}
