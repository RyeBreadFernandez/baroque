import SwiftUI

// The home screen behind the widgets: a deep stack of hand-cut cardstock hills running from butter
// through peach and coral to sage, each lifted off the one behind, so every gap between widgets
// shows layered paper edges.

struct PaperWallpaper: View {
    private static let stocks: [UInt32] = [
        0xFCE6C8, 0xFBD9B4, 0xF9CBA6, 0xF7BC9A, 0xF3AC90, 0xEE9E8A,
        0xD8C8DC, 0xBFD9C2, 0xA9D0AF, 0x95C6A0, 0x82BA94, 0x70AD88
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0xFFF4E0), Color(hex: 0xFDE9CF)], startPoint: .top, endPoint: .bottom)
            Fiber(seed: 2).blendMode(.overlay)
            ForEach(Self.stocks.indices, id: \.self) { i in
                let y = 0.035 + CGFloat(i) * 0.08
                let seed = UInt64(i + 1)
                Sheet(shape: RidgeCut(top: wave(y: y, seed: seed), smooth: true, seed: seed, wobble: 1.1),
                      color: Color(hex: Self.stocks[i]), seed: seed &+ 20, lightTop: y - 0.04, lightBottom: y + 0.12, edge: 1.6)
                    .lifted(3.2)
            }
        }
    }

    private func wave(y: CGFloat, seed: UInt64) -> [CGPoint] {
        var rng = SeededRandom(seed: seed &* 13)
        return (0...8).map { i in
            CGPoint(x: -0.05 + CGFloat(i) * 0.1375, y: y + rng.range(-0.022...0.022))
        }
    }
}
