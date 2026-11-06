import SwiftUI

// Painted night palette shared by the app and the widgets: forest and night-sky greens, espresso panels,
// copper pebbles and gold lettering, like a storybook painting. Text tokens are picked for WCAG AA on the
// lightest strokes of the espresso panel (about #4A3829) and on the sky behind the header text.
enum Stone {
    static let night        = Color(hex: 0x111A1C)
    static let forest       = Color(hex: 0x1C2824)
    static let espresso     = Color(hex: 0x33261C)
    static let espressoDark = Color(hex: 0x231A13)

    static let goldBright   = Color(hex: 0xF1D9A8) // highlights, the sun, sparkles
    static let gold         = Color(hex: 0xE2C38F) // headings and numerals, 7:1 on the panel
    static let parchment    = Color(hex: 0xEADCC2) // body text, 9:1
    static let goldMuted    = Color(hex: 0xC9B089) // secondary text, >= 5:1
    static let goldFaint    = Color(hex: 0xB8A07A) // tertiary labels, >= 4.5:1
    static let copperInk    = Color(hex: 0xE89A6C) // overdue and error text on dark, >= 5:1

    static let copperLight  = Color(hex: 0xC27C52)
    static let copper       = Color(hex: 0xA3603C)
    static let copperDark   = Color(hex: 0x7A4229)
    static let sage         = Color(hex: 0x8A9B80)
    static let moonlight    = Color(hex: 0xF3E3BC)

    static let shadow       = Color(hex: 0x080605) // cast shadows: warm near-black
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Materials

// Painted boards (scripts/make_textures.py): brushwork with bristle marks and lit paint ridges, plus a
// canvas weave drawn on top so the surface stays crisp at any scale. Widget textures live in
// Shared/PaintTextures.xcassets; AppPanel is app-only.
enum StoneMaterial {
    case panel      // task slabs and the app's rows: espresso
    case copper     // pebbles: today, the count, the next arrow, overdue chips
    case appPanel   // app only: the preview tray, painted with larger strokes

    var imageName: String {
        switch self {
        case .panel: return "PaintPanel"
        case .copper: return "PaintCopper"
        case .appPanel: return "AppPanel"
        }
    }

    // Average color, shown under the texture (and instead of it if the image fails to load).
    var base: Color {
        switch self {
        case .panel, .appPanel: return Color(hex: 0x35281E)
        case .copper: return Color(hex: 0xA3603C)
        }
    }

    // The cut side of a raised slab, seen below its face.
    var edge: [Color] {
        switch self {
        case .panel, .appPanel: return [Color(hex: 0x1E1610), Color(hex: 0x140F0B)]
        case .copper: return [Color(hex: 0x6A3923), Color(hex: 0x4E2A1A)]
        }
    }

    // Light falls from the upper left across every face.
    var lighting: LinearGradient {
        LinearGradient(stops: [
            .init(color: Stone.goldBright.opacity(0.10), location: 0),
            .init(color: .white.opacity(0), location: 0.45),
            .init(color: .black.opacity(0.22), location: 1)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// A painted board: texture, then canvas weave. Fills whatever space it is offered and never sizes its parent.
struct StoneSurface: View {
    var material: StoneMaterial
    var weave: Bool = true

    var body: some View {
        material.base
            .overlay {
                Image(material.imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            }
            .overlay {
                if weave { CanvasWeave(opacity: material == .copper ? 0.5 : 1) }
            }
            .clipped()
    }
}

// MARK: - Raised slabs

// A painted slab resting on the scene: brushed face, a lit chamfer, a gold hairline inlaid just inside
// the rim, a visible cut side underneath, and a soft shadow.
struct StoneSlabModifier: ViewModifier {
    var material: StoneMaterial
    var radius: CGFloat
    var depth: CGFloat
    var inlay: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content.background {
            ZStack {
                shape
                    .fill(LinearGradient(colors: material.edge, startPoint: .top, endPoint: .bottom))
                    .offset(y: depth)
                    .shadow(color: Stone.shadow.opacity(0.55), radius: 8, x: 0, y: depth + 3)
                    .shadow(color: Stone.shadow.opacity(0.5), radius: 1, x: 0, y: depth * 0.6)
                StoneSurface(material: material)
                    .overlay(material.lighting)
                    .clipShape(shape)
                    .overlay(ChamferRim(shape: shape))
                if inlay {
                    shape.inset(by: 4)
                        .stroke(Stone.gold.opacity(0.32), lineWidth: 0.6)
                }
            }
        }
    }
}

// Lit top edge, shaded bottom edge, and a faint glow just inside: reads as a softened edge.
struct ChamferRim<S: InsettableShape>: View {
    var shape: S

    var body: some View {
        ZStack {
            shape.strokeBorder(
                LinearGradient(stops: [
                    .init(color: Stone.goldBright.opacity(0.42), location: 0),
                    .init(color: Stone.goldBright.opacity(0.08), location: 0.3),
                    .init(color: .black.opacity(0), location: 0.65),
                    .init(color: .black.opacity(0.45), location: 1)
                ], startPoint: .top, endPoint: .bottom),
                lineWidth: 1.2)
            shape.inset(by: 1.6)
                .stroke(Stone.goldBright.opacity(0.07), lineWidth: 2.5)
                .blur(radius: 1.6)
                .clipShape(shape)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func stoneSlab(_ material: StoneMaterial, radius: CGFloat = 18, depth: CGFloat = 3, inlay: Bool = true) -> some View {
        modifier(StoneSlabModifier(material: material, radius: radius, depth: depth, inlay: inlay))
    }

    /// A channel cut into the scene (the week strip, sockets).
    func carved<S: InsettableShape>(_ shape: S) -> some View {
        background(CarvedRecess(shape: shape))
    }

    /// Letters standing proud of the paint: a tight dark shadow under each stroke.
    func raised(_ strength: Double = 1) -> some View {
        shadow(color: Stone.shadow.opacity(min(1, 0.7 * strength)), radius: 0.6, x: 0, y: 1)
    }

    /// Text over the painted scene: raised, in a soft dark halo so it reads over bright paint and ridges.
    func legible(_ strength: Double = 1) -> some View {
        raised(strength)
            .shadow(color: Stone.night.opacity(0.8), radius: 3.5, x: 0, y: 0)
    }
}

// Gold leaf: bright at the top of each letter, deeper toward the foot, with a soft inner shade.
// Used for the big date numerals.
enum Gilt {
    static var style: some ShapeStyle {
        LinearGradient(colors: [Stone.goldBright, Stone.gold, Color(hex: 0xB98C55)], startPoint: .top, endPoint: .bottom)
            .shadow(.inner(color: Color(hex: 0x5A3A1C).opacity(0.7), radius: 0.8, x: 0.4, y: -0.9))
    }
}

// The floor of a cut: darker, shadowed under its upper lip, with a lit lower lip.
struct CarvedRecess<S: InsettableShape>: View {
    var shape: S

    var body: some View {
        shape
            .fill(Color.black.opacity(0.30))
            .overlay {
                shape
                    .stroke(Stone.shadow.opacity(0.75), lineWidth: 5)
                    .blur(radius: 2.4)
                    .offset(y: 1.8)
                    .clipShape(shape)
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [Stone.shadow.opacity(0.6), .clear, Stone.goldBright.opacity(0.28)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.9)
            }
            .allowsHitTesting(false)
    }
}

// A polished copper pebble: painted, domed (highlight up-left, falloff to the rim), with a contact shadow.
struct Pebble<S: InsettableShape>: View {
    var shape: S

    var body: some View {
        StoneSurface(material: .copper)
            .overlay(EllipticalGradient(colors: [Stone.goldBright.opacity(0.45), .white.opacity(0)],
                                        center: UnitPoint(x: 0.34, y: 0.16), startRadiusFraction: 0, endRadiusFraction: 0.6))
            .overlay(EllipticalGradient(colors: [.clear, Stone.shadow.opacity(0.42)],
                                        center: UnitPoint(x: 0.45, y: 0.32), startRadiusFraction: 0.32, endRadiusFraction: 0.95))
            .clipShape(shape)
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [Stone.goldBright.opacity(0.6), .white.opacity(0), Stone.shadow.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                lineWidth: 0.8))
            .shadow(color: Stone.shadow.opacity(0.7), radius: 1.2, x: 0, y: 1.4)
            .shadow(color: Stone.shadow.opacity(0.35), radius: 4, x: 0, y: 3)
    }
}

// A hairline cut across the panel, with its lit lower edge.
struct EngravedRule: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black.opacity(0.45)).frame(height: 0.7)
            Rectangle().fill(Stone.gold.opacity(0.16)).frame(height: 0.7)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Ornament

// A four-pointed sparkle, the star used all over the painting.
struct Sparkle: Shape {
    var pinch: CGFloat = 0.16

    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let px = r.width / 2 * pinch, py = r.height / 2 * pinch
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: c.y), control: CGPoint(x: c.x + px, y: c.y - py))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.maxY), control: CGPoint(x: c.x + px, y: c.y + py))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: c.y), control: CGPoint(x: c.x - px, y: c.y + py))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.minY), control: CGPoint(x: c.x - px, y: c.y - py))
        p.closeSubpath()
        return p
    }
}

// A gold hairline border following the widget's corner shape, with a sparkle set into the top edge,
// like the frame round a storybook plate.
struct GoldFrame: View {
    var inset: CGFloat = 6
    var ornament: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ContainerRelativeShape().inset(by: inset + 0.7)
                    .stroke(Stone.shadow.opacity(0.6), lineWidth: 0.7)
                    .offset(y: 0.7)
                ContainerRelativeShape().inset(by: inset)
                    .stroke(Stone.gold.opacity(0.42), lineWidth: 0.7)
                if ornament {
                    ZStack {
                        Circle().fill(Stone.night).frame(width: 15, height: 15).blur(radius: 2.5)
                        Sparkle().fill(Stone.gold).frame(width: 9, height: 11)
                            .shadow(color: Stone.goldBright.opacity(0.6), radius: 2.5)
                        HStack(spacing: 13) {
                            Circle().fill(Stone.gold.opacity(0.8)).frame(width: 2, height: 2)
                            Circle().fill(Stone.gold.opacity(0.8)).frame(width: 2, height: 2)
                        }
                    }
                    .position(x: geo.size.width / 2, y: inset)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Widget grounds

// Rim light on the widget's top edge and shade along the bottom, following the widget's corner shape
// (ContainerRelativeShape: the real widget mask on the home screen, WidgetCanvas's shape in the app).
struct SlabBevel: View {
    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .strokeBorder(
                    LinearGradient(stops: [
                        .init(color: Stone.goldBright.opacity(0.30), location: 0),
                        .init(color: .white.opacity(0), location: 0.25),
                        .init(color: .black.opacity(0), location: 0.7),
                        .init(color: Stone.shadow.opacity(0.55), location: 1)
                    ], startPoint: .top, endPoint: .bottom),
                    lineWidth: 2)
            ContainerRelativeShape()
                .inset(by: 2)
                .stroke(Stone.shadow.opacity(0.35), lineWidth: 6)
                .blur(radius: 5)
                .offset(y: -2)
                .clipShape(ContainerRelativeShape())
        }
        .allowsHitTesting(false)
    }
}

// The canvas under the paint: a faint woven grid, deterministic and crisp at any scale.
struct CanvasWeave: View {
    var opacity: Double = 1

    var body: some View {
        Canvas { ctx, size in
            let pitch: CGFloat = 1.7
            var rows = Path(), cols = Path(), lit = Path()
            var y: CGFloat = 0, i = 0
            while y < size.height {
                let line = CGRect(x: 0, y: y, width: size.width, height: 0.5)
                if i % 2 == 0 { rows.addRect(line) } else { lit.addRect(line) }
                y += pitch; i += 1
            }
            var x: CGFloat = 0
            while x < size.width {
                cols.addRect(CGRect(x: x, y: 0, width: 0.5, height: size.height))
                x += pitch
            }
            ctx.fill(rows, with: .color(.black.opacity(0.04 * opacity)))
            ctx.fill(cols, with: .color(.black.opacity(0.03 * opacity)))
            ctx.fill(lit, with: .color(Stone.goldBright.opacity(0.015 * opacity)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum Serif {
    static func font(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        let base = Font.system(size: size, weight: weight, design: .serif)
        return italic ? base.italic() : base
    }
}
