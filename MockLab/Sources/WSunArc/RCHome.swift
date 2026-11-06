import SwiftUI
import AppKit

// Baroque in the painted rococo of Hubert Robert's The Bathing Pool (1777-80, The Metropolitan Museum of Art, public
// domain), the user's wallpaper of 2026-11-04. It is the travertine set (TVHome.swift) drawn with TVStyle.rococo:
//   - the wallpaper is the painting, cropped to the screen with the rotunda left of centre;
//   - the stones are laid in with oil strokes in the painting's colours (Textures/rococo/make.py);
//   - the icons are the same Blender models on those stones, their objects brushed (ICON_SET=rococo build.py);
//   - the type is Didot;
//   - the two pictures, the large widget's and page three's, are the user's own outdoor photographs repainted in the
//     painting's colours and brushwork (Textures/rococo/photos.py);
//   - the Today widget's panel is a detail of the flower still life the user sent; Fragonard's The Swing and the still
//     life are also rendered as alternative wallpapers (out/rococo/swing/, out/rococo/flowers/).
//
//     SA_ROCOCO=1 swift run --scratch-path .build-sa-home WSunArc     -> out/rococo/

/// A painting in the rococo set, filling its frame: one of the user's photographs repainted by
/// Textures/rococo/photos.py, or a detail of The Bathing Pool. `spot` gives the part shown, its left, top and width as
/// fractions of the picture (its height follows the frame). Darkened and cooled at night.
struct RCDetail: View {
    var picture: String
    var spot: CGRect
    var night = false

    /// Page one: Kings Canyon from the Field Notes, its cliffs dark on the right for the date.
    static let hero = RCDetail(picture: "photos/kings-canyon", spot: CGRect(x: 0.03, y: 0, width: 0.953, height: 0))
    /// Page three: the dead tree under a stormy sky, the most like Robert of the user's photographs.
    static let wide = RCDetail(picture: "photos/dead-tree", spot: CGRect(x: 0, y: 0.38, width: 1, height: 0))
    /// The small picture (the showcase only): the river under the pines.
    static let square = RCDetail(picture: "photos/river", spot: CGRect(x: 0, y: 0, width: 1, height: 0))
    /// The Today widget's panel: the still life's roses and its dark ground at the lower right for the line.
    static let flowers = RCDetail(picture: "flowers", spot: CGRect(x: 0.42, y: 0.3, width: 0.58, height: 0))
    /// The Bathing Pool's own fountain, the women on the steps and the bathers.
    static let bathers = RCDetail(picture: "bathing-pool", spot: CGRect(x: 0.12, y: 0.74, width: 0.7, height: 0))

    func at(night: Bool) -> RCDetail { RCDetail(picture: picture, spot: spot, night: night) }

    var body: some View {
        GeometryReader { geo in
            if let img = NSImage(contentsOf: Mock.root.appendingPathComponent("Textures/rococo/\(picture).jpg")) {
                let w = geo.size.width / spot.width
                let h = w * img.size.height / img.size.width
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: w, height: h)
                    .offset(x: -spot.minX * w, y: -spot.minY * h)
            }
        }
        .saturation(night ? 0.7 : 1)
        .overlay(Color(hex: 0x141B26).opacity(night ? 0.6 : 0).blendMode(.multiply))
        .clipped()
    }

    /// The darkened corners of an old canvas, so cream type reads on the sky.
    static var corners: some View {
        RadialGradient(colors: [.clear, Color(hex: 0x1C1912).opacity(0.55)], center: UnitPoint(x: 0.45, y: 0.5),
                       startRadius: 110, endRadius: 320)
    }
}
