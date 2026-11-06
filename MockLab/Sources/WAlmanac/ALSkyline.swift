import SwiftUI

/// The Matterhorn's skyline from the Riffelsee (MockLab/Textures/old-master-cover/matterhorn.json, traced from
/// Wikimedia Commons File:Matterhorn_Riffelsee_2005-06-11.jpg by Dirk Beyer, CC BY-SA 3.0), decimated to 88
/// points from the foot of the left ridge to the end of the shoulder. Summit at (0, 0), x right and y down, in
/// pyramid heights.
enum ALSkyline {
    static let points: [(CGFloat, CGFloat)] = [
        (-0.947, 1.163), (-0.843, 1.123), (-0.740, 1.066), (-0.689, 1.037), (-0.654, 1.018), (-0.620, 1.019),
        (-0.585, 0.979), (-0.551, 0.879), (-0.516, 0.788), (-0.482, 0.725), (-0.448, 0.639), (-0.413, 0.586),
        (-0.379, 0.569), (-0.344, 0.526), (-0.310, 0.465), (-0.275, 0.417), (-0.241, 0.374), (-0.206, 0.340),
        (-0.172, 0.323), (-0.138, 0.272), (-0.120, 0.263), (-0.103, 0.229), (-0.086, 0.188), (-0.069, 0.086),
        (-0.052, 0.061), (-0.034, 0.045), (-0.017, 0.023), (0.000, 0.000), (0.017, 0.013), (0.034, 0.022),
        (0.052, 0.034), (0.069, 0.054), (0.086, 0.071), (0.103, 0.094), (0.120, 0.107), (0.138, 0.132),
        (0.155, 0.155), (0.172, 0.170), (0.189, 0.188), (0.206, 0.208), (0.224, 0.232), (0.241, 0.257),
        (0.258, 0.275), (0.275, 0.296), (0.293, 0.331), (0.310, 0.354), (0.327, 0.380), (0.344, 0.412),
        (0.361, 0.469), (0.379, 0.538), (0.396, 0.575), (0.413, 0.638), (0.430, 0.654), (0.448, 0.670),
        (0.465, 0.680), (0.482, 0.691), (0.499, 0.687), (0.516, 0.677), (0.551, 0.703), (0.585, 0.738),
        (0.620, 0.770), (0.654, 0.789), (0.689, 0.814), (0.723, 0.839), (0.757, 0.862), (0.792, 0.884),
        (0.826, 0.909), (0.861, 0.933), (0.895, 0.952), (0.929, 0.980), (0.964, 1.008), (0.998, 1.038),
        (1.033, 1.069), (1.067, 1.101), (1.101, 1.137), (1.136, 1.168), (1.170, 1.209), (1.205, 1.239),
        (1.239, 1.256), (1.274, 1.275), (1.308, 1.296), (1.343, 1.301), (1.377, 1.307), (1.411, 1.307),
        (1.515, 1.324), (1.618, 1.341), (1.721, 1.358), (1.738, 1.359)
    ]
    static let minX: CGFloat = -0.95
    static let maxX: CGFloat = 1.75
    static let depth: CGFloat = 1.36
}

/// A small engraved cut of the Matterhorn in gold line, set as a tailpiece: the true skyline, its shaded west face
/// hatched along the fall line, the Hörnli ridge running down from the notch, and a ground rule. Uniform scale only.
struct ALEngravedPeak: View {
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width / (ALSkyline.maxX - ALSkyline.minX), size.height / ALSkyline.depth)
            let ox = (size.width - (ALSkyline.maxX - ALSkyline.minX) * k) / 2 - ALSkyline.minX * k
            let oy = size.height - ALSkyline.depth * k
            func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: ox + u * k, y: oy + v * k) }
            let lw = max(0.55, k * 0.03)
            var sky = Path()
            for (i, pt) in ALSkyline.points.enumerated() {
                if i == 0 { sky.move(to: p(pt.0, pt.1)) } else { sky.addLine(to: p(pt.0, pt.1)) }
            }
            var land = sky
            land.addLine(to: p(ALSkyline.maxX, ALSkyline.depth))
            land.addLine(to: p(ALSkyline.minX, ALSkyline.depth))
            land.closeSubpath()
            // The west face in shadow: hatched down the fall line, left of the shadow's edge.
            var shade = Path()
            shade.move(to: p(0.03, -0.05))
            shade.addLine(to: p(0.03 - 0.33 * ALSkyline.depth, ALSkyline.depth))
            shade.addLine(to: p(ALSkyline.minX - 0.2, ALSkyline.depth))
            shade.addLine(to: p(ALSkyline.minX - 0.2, -0.05))
            shade.closeSubpath()
            ctx.drawLayer { layer in
                layer.clip(to: land)
                layer.clip(to: shade)
                var hatch = Path()
                var u = ALSkyline.minX - 0.6
                while u < 0.4 {
                    hatch.move(to: p(u, -0.05))
                    hatch.addLine(to: p(u - 0.42, ALSkyline.depth))
                    u += max(0.05, 1.5 / k)
                }
                layer.stroke(hatch, with: .color(color.opacity(0.85)), lineWidth: lw * 0.6)
            }
            // The Hornli ridge, from the notch down to the right.
            var ridge = Path()
            ridge.move(to: p(0.47, 0.69))
            ridge.addCurve(to: p(0.92, ALSkyline.depth), control1: p(0.6, 0.86), control2: p(0.8, 1.15))
            ctx.stroke(ridge, with: .color(color), lineWidth: lw * 0.8)
            // A few streaks of snow on the lit face.
            var streaks = Path()
            for (u0, v0, len) in [(0.1, 0.32, 0.22), (0.2, 0.5, 0.3), (0.0, 0.62, 0.26), (0.32, 0.78, 0.2)] as [(CGFloat, CGFloat, CGFloat)] {
                streaks.move(to: p(u0, v0))
                streaks.addLine(to: p(u0 - len * 0.35, v0 + len))
            }
            ctx.stroke(streaks, with: .color(color.opacity(0.7)), lineWidth: lw * 0.5)
            ctx.stroke(sky, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            var ground = Path()
            ground.move(to: p(ALSkyline.minX, ALSkyline.depth))
            ground.addLine(to: p(ALSkyline.maxX, ALSkyline.depth))
            ctx.stroke(ground, with: .color(color), lineWidth: lw * 0.8)
        }
        .accessibilityHidden(true)
    }
}
