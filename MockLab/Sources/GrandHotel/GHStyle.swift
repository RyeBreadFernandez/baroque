import SwiftUI

// Grand Hotel: the app's painted construction (Theme.swift) in a confectionery hotel palette. Every surface is a
// brushed texture painted by Textures/grand-hotel/make.py with the shipped brush method; slabs, pebbles and recesses
// are built exactly like StoneSlabModifier, Pebble and CarvedRecess, and reuse ChamferRim, CarvedRecess, CanvasWeave,
// Gilt, GoldFrame, SlabBevel and Sparkle as they are.

// MARK: - Palette

/// Text on pastel is burgundy, plum or espresso ink; text on velvet, plum lacquer or paint is cream or gold leaf.
enum GH {
    // Hotel
    static let pink = Color(hex: 0xF3A1B8)
    static let pinkLight = Color(hex: 0xFAC4D2)
    static let pinkDeep = Color(hex: 0xD9819C)
    static let raspberry = Color(hex: 0xB3375E)
    static let raspberryDeep = Color(hex: 0x841C40)
    static let claret = Color(hex: 0x5E1230)
    static let bellboy = Color(hex: 0x4A2350)
    static let cream = Color(hex: 0xFFF6E8)
    static let glass = Color(hex: 0x4A2A50)
    static let butter = Color(hex: 0xFBE6A6)
    static let lamplight = Color(hex: 0xFFD27F)
    // Scenery
    static let mint = Color(hex: 0xB2DEC9)
    static let mintDeep = Color(hex: 0x7FC0A6)
    static let pine = Color(hex: 0x2D6961)
    static let pineDark = Color(hex: 0x1E4846)
    static let lilac = Color(hex: 0xD6CCEA)
    static let lavender = Color(hex: 0xB3A8D8)
    static let rock = Color(hex: 0xEFC6AE)
    static let rockShade = Color(hex: 0xB98DA6)
    static let powder = Color(hex: 0xA9CAE8)
    // Ink
    static let burgundy = Color(hex: 0x6A1733)
    static let plum = Color(hex: 0x45203E)
    static let espresso = Color(hex: 0x3A2421)
    static let inkSoft = Color(hex: 0x6E4466)
    // Gold leaf and brass
    static let gold = Color(hex: 0xC99D46)
    static let goldLight = Color(hex: 0xF5E0A0)
    static let goldDeep = Color(hex: 0x87621F)
    /// Cast shadows: a deep plum instead of the night palette's warm black, so shadows on pastel stay in key.
    static let shadow = Color(hex: 0x2A0F24)
}

/// Fixed-size type (widgets ignore Dynamic Type). Futura caps are the hotel's labels; numerals, headings, tasks and
/// quotes use the app's serif (`Serif.font`). Both ship on iOS 17 and macOS.
enum GHFont {
    static func caps(_ size: CGFloat) -> Font { .custom("Futura-Bold", fixedSize: size) }
    static func capsMedium(_ size: CGFloat) -> Font { .custom("Futura-Medium", fixedSize: size) }
}

extension Text {
    /// Small spaced capitals in Futura, the hotel's voice for labels. Never under 8 pt.
    func ghCaps(_ size: CGFloat, _ color: Color, tracking: CGFloat? = nil, medium: Bool = false) -> some View {
        font(medium ? GHFont.capsMedium(max(8, size)) : GHFont.caps(max(8, size)))
            .tracking(tracking ?? size * 0.2)
            .foregroundStyle(color)
    }
}

// MARK: - Textures

/// The hotel's paints (MockLab/Textures/grand-hotel, about 1 px per point). Loaded once.
enum GHTex {
    static let velvet = Mock.texture("grand-hotel/velvet")
    static let cream = Mock.texture("grand-hotel/cream")
    static let lilac = Mock.texture("grand-hotel/lilac")
    static let mint = Mock.texture("grand-hotel/mint")
    static let plum = Mock.texture("grand-hotel/plum")
    static let brass = Mock.texture("grand-hotel/brass")
    static let raspberry = Mock.texture("grand-hotel/raspberry")
    static let wall = Mock.texture("grand-hotel/wall")
    /// The shipped PaintSky and PaintRidge strokes (same seeds) with the shadows in lavender and plum for pastel paint.
    static let skyRelief = Mock.texture("grand-hotel/sky-relief")
    static let ridgeRelief = Mock.texture("grand-hotel/ridge-relief")
    /// Small plaster dabs for the hotel's walls.
    static let facade = Mock.texture("grand-hotel/facade")
}

// MARK: - Materials

enum GHMaterial {
    case cream      // the register, stamps, notices
    case lilac      // chapter cards
    case velvet     // raspberry velvet: stamp panels, banners, plaques
    case mint       // mint enamel: the pigeonhole cabinet
    case plum       // bellboy-purple lacquer: the barometer face
    case brass      // keys, bells, bezels
    case raspberry  // wax seals, late chips, the count

    var image: Image {
        switch self {
        case .cream: return GHTex.cream
        case .lilac: return GHTex.lilac
        case .velvet: return GHTex.velvet
        case .mint: return GHTex.mint
        case .plum: return GHTex.plum
        case .brass: return GHTex.brass
        case .raspberry: return GHTex.raspberry
        }
    }

    /// Average colour, shown under the texture (and instead of it if the image fails to load).
    var base: Color {
        switch self {
        case .cream: return Color(hex: 0xF8ECDA)
        case .lilac: return Color(hex: 0xDCD0EF)
        case .velvet: return Color(hex: 0xA22F55)
        case .mint: return Color(hex: 0xB4DDCA)
        case .plum: return Color(hex: 0x472150)
        case .brass: return Color(hex: 0xC09443)
        case .raspberry: return Color(hex: 0xA8325A)
        }
    }

    /// The cut side of a raised slab, seen below its face.
    var edge: [Color] {
        switch self {
        case .cream: return [Color(hex: 0xD3B7A6), Color(hex: 0xA9867E)]
        case .lilac: return [Color(hex: 0xA592C4), Color(hex: 0x7C6AA0)]
        case .velvet: return [Color(hex: 0x6A1735), Color(hex: 0x4C0F26)]
        case .mint: return [Color(hex: 0x6FA58F), Color(hex: 0x4F8270)]
        case .plum: return [Color(hex: 0x2A1030), Color(hex: 0x1C0921)]
        case .brass: return [Color(hex: 0x7C5A22), Color(hex: 0x5C4116)]
        case .raspberry: return [Color(hex: 0x6E1A38), Color(hex: 0x521229)]
        }
    }

    /// The hairline inlaid just inside the rim: gold on everything, deeper gold on pale card so it still shows.
    var inlay: Color {
        switch self {
        case .cream, .lilac, .mint: return GH.gold.opacity(0.75)
        default: return Stone.gold.opacity(0.45)
        }
    }

    var pale: Bool { self == .cream || self == .lilac || self == .mint }

    /// Light falls from the upper left across every face (as StoneMaterial.lighting; plum shade on pale card).
    var lighting: LinearGradient {
        LinearGradient(stops: [
            .init(color: Stone.goldBright.opacity(pale ? 0.16 : 0.10), location: 0),
            .init(color: .white.opacity(0), location: 0.45),
            .init(color: (pale ? GH.shadow : Color.black).opacity(pale ? 0.12 : 0.22), location: 1)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// A painted board: texture, then canvas weave (as StoneSurface). Fills whatever space it is offered.
struct GHSurface: View {
    var material: GHMaterial
    var weave: Double = 1

    var body: some View {
        material.base
            .overlay {
                material.image
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            }
            .overlay {
                if weave > 0 { CanvasWeave(opacity: weave) }
            }
            .clipped()
    }
}

// MARK: - Raised slabs

/// A painted slab resting on the scene, built like StoneSlabModifier: brushed face lit from the upper left, ChamferRim,
/// a gold hairline inlaid inside the rim, the cut side visible underneath and a two-part cast shadow.
struct GHSlabModifier<S: InsettableShape>: ViewModifier {
    var material: GHMaterial
    var shape: S
    var depth: CGFloat
    var inlay: Bool

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                shape
                    .fill(LinearGradient(colors: material.edge, startPoint: .top, endPoint: .bottom))
                    .offset(y: depth)
                    .shadow(color: GH.shadow.opacity(0.5), radius: 7, x: 0, y: depth + 3)
                    .shadow(color: GH.shadow.opacity(0.5), radius: 1, x: 0, y: depth * 0.6)
                GHSurface(material: material)
                    .overlay(material.lighting)
                    .clipShape(shape)
                    .overlay(ChamferRim(shape: shape))
                if inlay {
                    shape.inset(by: 4)
                        .stroke(material.inlay, lineWidth: 0.6)
                }
            }
        }
    }
}

extension View {
    func ghSlab(_ material: GHMaterial, radius: CGFloat = 14, depth: CGFloat = 3, inlay: Bool = true) -> some View {
        modifier(GHSlabModifier(material: material, shape: RoundedRectangle(cornerRadius: radius, style: .continuous), depth: depth, inlay: inlay))
    }

    func ghSlab<S: InsettableShape>(_ material: GHMaterial, shape: S, depth: CGFloat = 3, inlay: Bool = true) -> some View {
        modifier(GHSlabModifier(material: material, shape: shape, depth: depth, inlay: inlay))
    }

    /// Ink on pale card: a hairline of light under each stroke, as if pressed into the paper.
    func ghPressed() -> some View {
        shadow(color: Color.white.opacity(0.65), radius: 0, x: 0, y: 0.7)
    }

    /// Places a view at an absolute frame inside a full-widget ZStack (the widget sizes are fixed points).
    func ghPlace(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View {
        frame(width: w, height: h).position(x: x + w / 2, y: y + h / 2)
    }
}

/// A polished pebble, built like Pebble: painted metal or enamel, domed (highlight up-left, falloff to the rim), with a
/// contact shadow.
struct GHPebble<S: InsettableShape>: View {
    var shape: S
    var material: GHMaterial = .brass

    var body: some View {
        GHSurface(material: material, weave: 0.5)
            .overlay(EllipticalGradient(colors: [Stone.goldBright.opacity(material == .brass ? 0.55 : 0.45), .white.opacity(0)],
                                        center: UnitPoint(x: 0.34, y: 0.16), startRadiusFraction: 0, endRadiusFraction: 0.6))
            .overlay(EllipticalGradient(colors: [.clear, GH.shadow.opacity(0.42)],
                                        center: UnitPoint(x: 0.45, y: 0.32), startRadiusFraction: 0.32, endRadiusFraction: 0.95))
            .clipShape(shape)
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [Stone.goldBright.opacity(0.65), .white.opacity(0), GH.shadow.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                lineWidth: 0.8))
            .shadow(color: GH.shadow.opacity(0.65), radius: 1.2, x: 0, y: 1.4)
            .shadow(color: GH.shadow.opacity(0.3), radius: 4, x: 0, y: 3)
    }
}

/// A hairline ruled into pale card, with its lit lower edge (EngravedRule in ink colours).
struct GHRule: View {
    var color: Color = GH.plum

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(color.opacity(0.28)).frame(height: 0.6)
            Rectangle().fill(Color.white.opacity(0.7)).frame(height: 0.6)
        }
        .accessibilityHidden(true)
    }
}

/// Gold leaf on a small sparkle: the gilt ornament between rules.
struct GHGiltSparkle: View {
    var size: CGFloat

    var body: some View {
        Sparkle()
            .fill(LinearGradient(colors: [Stone.goldBright, GH.gold, GH.goldDeep], startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.82, height: size)
            .shadow(color: GH.shadow.opacity(0.35), radius: 0.4, x: 0, y: 0.6)
    }
}

/// A rule with a gilt sparkle in the middle: rule, sparkle, rule.
struct GHFlourish: View {
    var width: CGFloat
    var color: Color = GH.raspberry

    var body: some View {
        HStack(spacing: 5) {
            rule
            GHGiltSparkle(size: 8)
            rule
        }
        .frame(width: width)
    }

    private var rule: some View {
        VStack(spacing: 1.2) {
            Rectangle().fill(color.opacity(0.8)).frame(height: 0.7)
            Rectangle().fill(GH.gold.opacity(0.8)).frame(height: 0.5)
        }
    }
}

// MARK: - Shapes

/// A rectangle with perforations bitten out of every edge: a postage stamp. Insettable for ChamferRim.
struct GHPerforated: InsettableShape {
    var hole: CGFloat = 2.2
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path(r)
        let pitch = hole * 3
        func row(_ a: CGPoint, _ b: CGPoint) {
            let len = hypot(b.x - a.x, b.y - a.y)
            let n = max(1, Int((len / pitch).rounded()))
            for i in 0...n {
                let t = CGFloat(i) / CGFloat(n)
                let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                p.addEllipse(in: CGRect(x: c.x - hole, y: c.y - hole, width: hole * 2, height: hole * 2))
            }
        }
        row(CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY))
        row(CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY))
        row(CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.minX, y: r.maxY))
        row(CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY))
        return p.normalized(eoFill: true)
    }

    func inset(by amount: CGFloat) -> GHPerforated {
        var s = self
        s.inset += amount
        return s
    }
}

/// A round-headed arch (windows, the notice's crown). Insettable for ChamferRim and CarvedRecess.
struct GHArch: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let rad = r.width / 2
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
        p.addArc(center: CGPoint(x: r.midX, y: r.minY + rad), radius: rad, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> GHArch {
        var s = self
        s.inset += amount
        return s
    }
}

// MARK: - Dates and text

enum GHDates {
    static func string(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = format
        return f.string(from: date)
    }

    /// Monday-first week containing `date`.
    static func week(of date: Date) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    /// "THREE", "TWENTY-THREE": the day of the month as a chapter number.
    static func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .spellOut
        return (f.string(from: NSNumber(value: n)) ?? "\(n)").uppercased()
    }

    /// "6:14": twelve-hour clock whatever the system setting.
    static func clock(_ date: Date) -> String { string(date, "h:mm") }
}

enum GHText {
    static func temp(_ v: Double) -> String { "\(Int(v.rounded()))°" }
    static func more(_ n: Int) -> String { "+ \(n) MORE" }
}
