import SwiftUI

// Baroque's widgets in the painted rococo of Hubert Robert's The Bathing Pool, the user's wallpaper (chosen 2026-11-04).
// Ported from MockLab's travertine set drawn in its rococo style (MockLab/Sources/WSunArc/TVHome.swift with
// TVStyle.rococo, and RCHome.swift):
//   - limestone laid in with oil strokes in the painting's colours, a gold sun on an arc carved into it;
//   - the user's own outdoor photographs repainted in the paintings' colours (MockLab/Textures/rococo/photos.py);
//   - Didot, with Avenir Next for small capitals and Savoye LET for short lines in script.
// The images are Rococo* in PaintTextures.xcassets, cut to their frames by scripts/export_rococo_textures.py.
//
// Every layout is fixed at its iPhone 17 size (164, 348 x 164, 348 x 365) and RococoFrame scales it to the widget.

/// The look's adjustable surface (2026-11-08 art redirect: "the effect needs to be a lot more subtle" so the words read,
/// and the widgets need "a little bit more that makes them stand out"). The widgets draw with `current`; MockLab
/// renders the others side by side to choose from.
struct RococoTheme {
    enum Edge { case soft, carved, crisp }

    var name: String
    /// The stone's flat colour, under the brushwork.
    var stone: Color
    /// How much of the painted brushwork shows over it: 1 is the original oil-painted limestone.
    var texture: Double
    var ink: Color
    var inkSoft: Color
    var terracotta: Color
    /// soft: the original lit lip; carved: a groove cut round the inside of every widget; crisp: a dark outline
    /// with a lit inner edge.
    var edge: Edge
    /// How strongly a photograph is darkened behind its words: 1 is the original.
    var scrim: Double

    static let original = RococoTheme(name: "Current", stone: Color(hex: 0xB5A483), texture: 1, ink: Color(hex: 0x3A2D23),
                                      inkSoft: Color(hex: 0x6B5B4C), terracotta: Color(hex: 0x9C5B3D), edge: .soft, scrim: 1)
    // Quiet's and Carved's inkSoft and terracotta were darkened on 2026-11-11 to reach 4.5:1 against the stone as it
    // renders (its 5th and 2nd percentiles, where the brushwork and shade fall), not only against the flat colour:
    // scripts/check_contrast.py measures them on MockLab's README renders.
    static let quiet = RococoTheme(name: "Quiet", stone: Color(hex: 0xDCD1BB), texture: 0.28, ink: Color(hex: 0x2B221B),
                                   inkSoft: Color(hex: 0x534437), terracotta: Color(hex: 0x713620), edge: .soft, scrim: 1.3)
    static let carved = RococoTheme(name: "Carved", stone: Color(hex: 0xDCD1BB), texture: 0.28, ink: Color(hex: 0x2B221B),
                                    inkSoft: Color(hex: 0x534437), terracotta: Color(hex: 0x713620), edge: .carved, scrim: 1.3)
    static let ivory = RococoTheme(name: "Ivory", stone: Color(hex: 0xEDE6D7), texture: 0.16, ink: Color(hex: 0x261E18),
                                   inkSoft: Color(hex: 0x53453A), terracotta: Color(hex: 0x86402A), edge: .crisp, scrim: 1.4)
    static let options = [original, quiet, carved, ivory]

    /// Quiet, chosen 2026-11-08: lighter stone, the brushwork at 28 percent, darker inks, photos darker behind words.
    static var current = quiet
}

enum RococoInk {
    static var ink: Color { RococoTheme.current.ink }
    static var inkSoft: Color { RococoTheme.current.inkSoft }
    static var inkFaint: Color { RococoTheme.current.inkSoft }
    static let cream = Color(hex: 0xF7F0E4)
    static var terracotta: Color { RococoTheme.current.terracotta }
    static let shadow = Color(hex: 0x2B1F15)
    /// The stone's flat colour: under the brushwork, and round the edges on other phone sizes.
    static var stone: Color { RococoTheme.current.stone }
    /// The dark of the paintings' corners.
    static let umber = Color(hex: 0x1C1912)
}

enum RococoType {
    static func serif(_ s: CGFloat) -> Font { .custom("Didot", size: s) }
    static func italic(_ s: CGFloat) -> Font { .custom("Didot-Italic", size: s) }
    static func sans(_ s: CGFloat) -> Font { .custom("AvenirNext-Regular", size: s) }
    static func sansMedium(_ s: CGFloat) -> Font { .custom("AvenirNext-Medium", size: s) }
    static func script(_ s: CGFloat) -> Font { .custom("SavoyeLetPlain", size: s) }
}

/// A rococo layout at its iPhone 17 design size, scaled to fill the widget (a point or two may be cropped at the
/// edges on other phones; every layout keeps 14 pt clear of them).
struct RococoFrame<Content: View>: View {
    var size: BaroqueSize
    @ViewBuilder var content: Content

    var body: some View {
        let design = size.designSize
        GeometryReader { geo in
            let scale = max(geo.size.width / design.width, geo.size.height / design.height)
            content
                .frame(width: design.width, height: design.height)
                .overlay(RococoEdge(theme: RococoTheme.current))
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
    }
}

/// The edge every widget gets from the theme, over stone and photograph alike (the soft lip is the slab's own).
struct RococoEdge: View {
    var theme: RococoTheme

    var body: some View {
        let outer = RoundedRectangle(cornerRadius: 22, style: .continuous)
        switch theme.edge {
        case .soft:
            EmptyView()
        case .carved:
            // A groove cut 7 points in, following the corners: dark at the top left, lit at the bottom right.
            let groove = RoundedRectangle(cornerRadius: 16, style: .continuous).inset(by: 7)
            ZStack {
                groove.stroke(Color.white.opacity(0.55), lineWidth: 1).offset(x: 0.5, y: 0.8)
                groove.stroke(RococoInk.shadow.opacity(0.42), lineWidth: 1.1)
                outer.strokeBorder(RococoInk.shadow.opacity(0.28), lineWidth: 1.2)
            }
            .allowsHitTesting(false)
        case .crisp:
            // A dark outline that holds the widget against the painting, with a lit edge just inside it.
            ZStack {
                outer.strokeBorder(RococoInk.shadow.opacity(0.6), lineWidth: 2.2)
                outer.inset(by: 2.2).strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Stone

/// The painted limestone: lit from the upper left, its edge softened (a lit lip at the upper left, a shaded one at the
/// lower right).
struct RococoSlab: View {
    var radius: CGFloat = 22

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            RococoInk.stone
            Image("RococoLimestone").resizable().interpolation(.high).rococoFullColor().scaledToFill()
                .opacity(RococoTheme.current.texture)
            LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0), .black.opacity(0.1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            shape.strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.35), location: 0),
                                                      .init(color: .white.opacity(0), location: 0.4),
                                                      .init(color: .black.opacity(0), location: 0.6),
                                                      .init(color: .black.opacity(0.22), location: 1)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            shape.inset(by: 2)
                .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear, .black.opacity(0.14)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 4)
                .blur(radius: 2.5)
        }
        .clipShape(shape)
    }
}

/// A line cut into the stone: a dark groove with a lit lower lip.
struct RococoCarve<S: Shape>: View {
    var shape: S
    var width: CGFloat = 1.1

    var body: some View {
        ZStack {
            shape.stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: width, lineCap: .round))
                .offset(x: 0.4, y: 0.8)
            shape.stroke(RococoInk.shadow.opacity(0.4), style: StrokeStyle(lineWidth: width * 1.15, lineCap: .round))
        }
    }
}

struct RococoLine: Shape {
    var vertical = false

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: vertical ? CGPoint(x: r.midX, y: r.minY) : CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: vertical ? CGPoint(x: r.midX, y: r.maxY) : CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

// MARK: - Reliefs

extension View {
    /// Raised off the stone: a tight contact shadow and a soft one, thrown to the lower right.
    func rococoRelief(_ h: CGFloat = 1) -> some View {
        shadow(color: RococoInk.shadow.opacity(0.4), radius: 0.9 * h, x: 0.9 * h, y: 1.2 * h)
            .shadow(color: RococoInk.shadow.opacity(0.2), radius: 3.5 * h, x: 2.2 * h, y: 3 * h)
    }

    /// Places a view with its first baseline at y and its leading (or trailing) edge at x, in a frame of `size`.
    func rococoBaseline(x: CGFloat, y: CGFloat, in size: CGSize, trailing: Bool = false) -> some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay(alignment: trailing ? .topTrailing : .topLeading) {
                self.alignmentGuide(.top) { $0[.firstTextBaseline] }
                    .offset(x: trailing ? x - size.width : x, y: y)
            }
    }
}

enum RococoMaterial {
    case gold, cream

    var gradient: LinearGradient {
        let c: [UInt32] = self == .gold ? [0xFAE5A4, 0xE2B259, 0xAC7930] : [0xFFFCF6, 0xEDE3D2, 0xCDBEA6]
        return LinearGradient(colors: c.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// An SF Symbol raised in gold or cream, lit on its upper left edges and standing off the stone.
struct RococoSymbol: View {
    var name: String
    var material: RococoMaterial
    var size: CGFloat

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * 1.22, weight: .bold))
            .foregroundStyle(material.gradient
                .shadow(.inner(color: .white.opacity(0.6), radius: 0.5, x: -0.6, y: -0.8))
                .shadow(.inner(color: .black.opacity(0.4), radius: 1, x: 0.8, y: 1)))
            .rococoRelief(1.1)
    }
}

/// The gold sun: a domed disc and eight rays.
struct RococoSun: View {
    var radius: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { k in
                Capsule()
                    .fill(RococoMaterial.gold.gradient)
                    .frame(width: radius * 0.62, height: radius * 0.22)
                    .offset(x: radius * 1.6)
                    .rotationEffect(.degrees(Double(k) * 45))
            }
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFCEBB4), Color(hex: 0xE6B85E), Color(hex: 0xB07E31)],
                                     center: UnitPoint(x: 0.36, y: 0.3), startRadius: 0, endRadius: radius * 1.15))
                .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .clear, .black.opacity(0.18)],
                                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7))
                .frame(width: radius * 2, height: radius * 2)
        }
        .frame(width: radius * 4.6, height: radius * 4.6)
        .rococoRelief(0.9)
    }
}

/// The moon in relief: the lit part raised in cream, the rest a faint carved disc.
struct RococoMoon: View {
    var phase: MoonPhase
    var radius: CGFloat

    var body: some View {
        ZStack {
            RococoCarve(shape: Circle(), width: 0.8)
            MoonLitShape(phase: phase)
                .fill(RococoMaterial.cream.gradient.shadow(.inner(color: .black.opacity(0.25), radius: 1, x: 0.6, y: 0.8)))
                .rococoRelief(0.7)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

/// A stretch of the sun's arc between two fractions of its length (0 at the left foot, 1 at the right).
struct RococoArcPath: Shape {
    var arc: SkyArc
    var from: Double
    var to: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard to > from else { return p }
        let steps = max(8, Int((to - from) * 120))
        for i in 0...steps {
            let pt = arc.point(from + (to - from) * Double(i) / Double(steps), in: rect.size)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

// MARK: - Pictures

// RococoPhotos, which photograph shows when, is in Words.swift.

/// One of the repainted photographs (or the still life), filling its frame; darkened and cooled at night.
struct RococoPicture: View {
    var name: String
    var night = false

    var body: some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .rococoFullColor()
            .scaledToFill()
            .saturation(night ? 0.7 : 1)
            .overlay(Color(hex: 0x141B26).opacity(night ? 0.45 : 0).blendMode(.multiply))
            .clipped()
    }
}

/// The darkened corners of an old canvas, so cream type reads on a bright sky.
struct RococoCorners: View {
    var body: some View {
        RadialGradient(colors: [.clear, RococoInk.umber.opacity(0.55)], center: UnitPoint(x: 0.45, y: 0.5),
                       startRadius: 110, endRadius: 320)
    }
}

extension Image {
    /// Keeps a painting in colour when the home screen is clear or tinted (iOS 18 and later turn images grey there).
    @ViewBuilder func rococoFullColor() -> some View {
        if #available(iOS 18.0, macOS 15.0, *) { widgetAccentedRenderingMode(.fullColor) } else { self }
    }
}

// The widgets' words (RococoWords) are in Words.swift, which is Foundation only so the tests can read it.
