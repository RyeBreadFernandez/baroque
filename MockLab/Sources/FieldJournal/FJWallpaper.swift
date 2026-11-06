import SwiftUI

/// The home screen behind the widgets: a large ink-and-wash valley study painted across a whole sheet,
/// deepening toward the foreground so the cream pages stand off it.
struct FJWallpaper: View {
    var body: some View {
        Canvas { ctx, size in
            let full = CGRect(origin: .zero, size: size)
            ctx.draw(ctx.resolve(Mock.texture("field-journal/wall")), in: full)
            let tooth = FJTex.tooth(ctx)
            Landscape.paint(ctx, scene: Self.scene, in: full, tooth: tooth)
        }
    }

    static let scene: Scenery = {
        var far = Sceneries.far([CGPoint(x: -0.02, y: 0.34), CGPoint(x: 0.16, y: 0.22), CGPoint(x: 0.34, y: 0.30), CGPoint(x: 0.54, y: 0.12),
                                 CGPoint(x: 0.74, y: 0.26), CGPoint(x: 1.02, y: 0.18)], seed: 91, opacity: 1)
        far.glaze = 2
        far.fadeDepth = 0.4
        var mid = Sceneries.mid([CGPoint(x: -0.02, y: 0.52), CGPoint(x: 0.18, y: 0.34), CGPoint(x: 0.32, y: 0.44), CGPoint(x: 0.5, y: 0.22),
                                 CGPoint(x: 0.64, y: 0.42), CGPoint(x: 0.8, y: 0.30), CGPoint(x: 1.02, y: 0.48)], snowline: 0.36, seed: 92, ink: 2.4)
        mid.glaze = 2
        mid.fadeDepth = 0.5
        var nearA = Sceneries.near([CGPoint(x: -0.02, y: 0.62), CGPoint(x: 0.3, y: 0.54), CGPoint(x: 0.6, y: 0.64), CGPoint(x: 1.02, y: 0.56)],
                                   trees: 34, seed: 93, treeHeight: 30)
        nearA.glaze = 2
        nearA.fadeDepth = 0.6
        var nearB = Sceneries.near([CGPoint(x: -0.02, y: 0.78), CGPoint(x: 0.4, y: 0.72), CGPoint(x: 0.7, y: 0.8), CGPoint(x: 1.02, y: 0.74)],
                                   trees: 24, seed: 94, treeHeight: 52)
        nearB.pigment = Color(hex: 0x6E8A3A)
        nearB.glaze = 3
        nearB.fadeDepth = 0.9
        nearB.inkWidth = 1.6
        return Scenery(ridges: [far, mid, nearA, nearB], sky: CGRect(x: 0, y: 0, width: 1, height: 0.42), skyOpacity: 1, seed: 95, fullSky: true)
    }()
}
