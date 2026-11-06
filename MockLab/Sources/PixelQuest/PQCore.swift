import SwiftUI

// Pixel Quest core: a limited 16-bit palette, an indexed framebuffer that every widget paints into
// on an exact 2 pt grid, sprites authored as text, and ordered (Bayer) dithering.

/// The palette. The framebuffer stores these raw values; 0 is transparent.
enum C: UInt8, CaseIterable {
    case clear = 0
    case ink, navy0, navy1, navy2, navy3, navy4
    case sky0, sky1, sky2, sky3, sky4
    case cloudW, cloudS, cloudD
    case farL, farM, farD, farB
    case slateL, slateM, slateD, slateB
    case snowL, snowS
    case teal0, teal1, teal2, teal3
    case grass0, grass1, grass2, grass3
    case pine0, pine1, pine2, pine3
    case earth0, earth1, earth2, earth3
    case gold0, gold1, gold2, gold3
    case cream, creamD, stone0, stone1, stone2
    case red0, red1, red2
    case white

    var hex: UInt32 {
        switch self {
        case .clear: return 0x000000
        case .ink: return 0x0B0D22
        case .navy0: return 0x10183C
        case .navy1: return 0x17245A
        case .navy2: return 0x203476
        case .navy3: return 0x2B4594
        case .navy4: return 0x3D5DB6
        case .sky0: return 0x2848B2
        case .sky1: return 0x3866D0
        case .sky2: return 0x5288E4
        case .sky3: return 0x7CB0F0
        case .sky4: return 0xB4D8F8
        case .cloudW: return 0xFBFDFF
        case .cloudS: return 0xD2E2F6
        case .cloudD: return 0xA2BEE8
        case .farL: return 0xAEB8EC
        case .farM: return 0x8A98D6
        case .farD: return 0x6A78BC
        case .farB: return 0x96AEE2
        case .slateL: return 0x7090C2
        case .slateM: return 0x5676A8
        case .slateD: return 0x3E5C8C
        case .slateB: return 0x2E4672
        case .snowL: return 0xF8FAFF
        case .snowS: return 0xBCCEF0
        case .teal0: return 0x0E3440
        case .teal1: return 0x175560
        case .teal2: return 0x247C7A
        case .teal3: return 0x48AE9A
        case .grass0: return 0x1A4A26
        case .grass1: return 0x2A7034
        case .grass2: return 0x44A042
        case .grass3: return 0x8CD050
        case .pine0: return 0x0B2C26
        case .pine1: return 0x154C36
        case .pine2: return 0x237246
        case .pine3: return 0x3A9854
        case .earth0: return 0x3C2216
        case .earth1: return 0x6A3E24
        case .earth2: return 0x9A6434
        case .earth3: return 0xCA985A
        case .gold0: return 0xA65818
        case .gold1: return 0xE29A22
        case .gold2: return 0xF8CC44
        case .gold3: return 0xFFF0A2
        case .cream: return 0xFFF4D8
        case .creamD: return 0xCDBE98
        case .stone0: return 0x5C6078
        case .stone1: return 0x8C90A8
        case .stone2: return 0xB8BCCC
        case .red0: return 0x7C1424
        case .red1: return 0xD83038
        case .red2: return 0xFF7A66
        case .white: return 0xFFFFFF
        }
    }
}

enum PQ {
    static let colors: [Color] = C.allCases.map { Color(hex: $0.hex) }
    static func color(_ c: C) -> Color { colors[Int(c.rawValue)] }
    /// Snap to the @3x device grid so fine pixel text stays crisp.
    static func snap(_ v: CGFloat) -> CGFloat { (v * 3).rounded() / 3 }
    /// The art pixel (2 pt) and the fine pixel used only for small labels (4 device px at @3x).
    static let px: CGFloat = 2
    static let fine: CGFloat = 4.0 / 3.0
}

/// 4x4 ordered dithering.
enum Bayer {
    static let m: [Int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    static func on(_ x: Int, _ y: Int, _ f: Double) -> Bool {
        Double(m[(y & 3) * 4 + (x & 3)]) + 0.5 < f * 16
    }
}

/// A sprite authored as rows of characters; `key` maps characters to palette entries ('.' is transparent).
struct Sprite {
    let w: Int
    let h: Int
    let cells: [C]

    init(_ art: String, _ key: [Character: C]) {
        let rows = art.split(separator: "\n").map { Array($0) }
        let width = rows.map(\.count).max() ?? 0
        var cells = [C](repeating: .clear, count: width * rows.count)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() { cells[y * width + x] = key[ch] ?? .clear }
        }
        self.w = width
        self.h = rows.count
        self.cells = cells
    }
}

/// An indexed framebuffer: one byte per art pixel. Rendered as one non-antialiased path per palette entry,
/// with horizontal runs merged, so every art pixel lands on whole device pixels.
struct PixelBuffer {
    let w: Int
    let h: Int
    var px: [UInt8]

    init(_ w: Int, _ h: Int) {
        self.w = w
        self.h = h
        px = [UInt8](repeating: 0, count: w * h)
    }

    func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h }

    func get(_ x: Int, _ y: Int) -> C {
        guard inside(x, y) else { return .clear }
        return C(rawValue: px[y * w + x]) ?? .clear
    }

    mutating func set(_ x: Int, _ y: Int, _ c: C) {
        guard c != .clear, inside(x, y) else { return }
        px[y * w + x] = c.rawValue
    }

    mutating func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: C) {
        let x0 = max(0, x), x1 = min(w, x + rw), y0 = max(0, y), y1 = min(h, y + rh)
        guard x0 < x1, y0 < y1, c != .clear else { return }
        for yy in y0..<y1 { for xx in x0..<x1 { px[yy * w + xx] = c.rawValue } }
    }

    mutating func hline(_ x: Int, _ y: Int, _ len: Int, _ c: C) { rect(x, y, len, 1, c) }
    mutating func vline(_ x: Int, _ y: Int, _ len: Int, _ c: C) { rect(x, y, 1, len, c) }

    mutating func draw(_ s: Sprite, _ x: Int, _ y: Int, flip: Bool = false) {
        for sy in 0..<s.h {
            for sx in 0..<s.w {
                set(x + sx, y + sy, s.cells[sy * s.w + (flip ? s.w - 1 - sx : sx)])
            }
        }
    }

    /// Dithered checker shadow over whatever is already there.
    mutating func checker(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: C, parity: Int = 0) {
        guard rw > 0, rh > 0 else { return }
        for yy in y..<(y + rh) { for xx in x..<(x + rw) where (xx + yy) & 1 == parity { set(xx, yy, c) } }
    }

    func render(_ ctx: GraphicsContext, pixel p: CGFloat = PQ.px, origin o: CGPoint = .zero) {
        var paths = [Path](repeating: Path(), count: C.allCases.count)
        for y in 0..<h {
            let row = y * w
            var x = 0
            while x < w {
                let c = px[row + x]
                var e = x + 1
                while e < w && px[row + e] == c { e += 1 }
                if c != 0 {
                    paths[Int(c)].addRect(CGRect(x: o.x + CGFloat(x) * p, y: o.y + CGFloat(y) * p,
                                                 width: CGFloat(e - x) * p, height: p))
                }
                x = e
            }
        }
        for i in 1..<paths.count where !paths[i].isEmpty {
            ctx.fill(paths[i], with: .color(PQ.colors[i]), style: FillStyle(antialiased: false))
        }
    }
}

/// A Canvas that paints a framebuffer at 2 pt per pixel, then optional fine overlays (labels) on top.
struct PixelCanvas: View {
    let buffer: PixelBuffer
    var fine: (GraphicsContext) -> Void = { _ in }

    var body: some View {
        Canvas { ctx, _ in
            buffer.render(ctx)
            fine(ctx)
        }
    }
}
