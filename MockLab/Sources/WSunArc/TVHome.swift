import SwiftUI
import AppKit

// Baroque in travertine (2026-11-04), after the user's Pinterest pin 215046950953591573: a home screen in travertine,
// olive and terracotta stone, raised reliefs (a gold sun, an olive branch, a flower) and a sunlit Mediterranean scene,
// shown as a phone beside the set of widgets on a plaster wall with leaf shadows.
//
// What carries over from the earlier rounds:
//   - Baroque's own data: the weather, sunrise and sunset, the vault's tasks and quotes.
//   - Sun Arc, here as a gold sun on an arc carved into the stone.
//   - The painted landscapes, glazed for a sunlit day, in place of photographs.
//   - The quote on page one; no weekday names; no gold frames.
//   - Page two as a checkerboard of widgets and apps, with a picture widget.
//   - Custom raised icons.
//
// The layout is the user's own (2026-11-04): Claude, Messages, Safari and Obsidian in the dock; page one the large
// widget over eight apps; page two a medium widget, eight apps, a medium widget; page three a medium widget over four.
//
//     SA_TRAV=1 swift run --scratch-path .build-sa-home WSunArc     -> out/travertine/
//
// Stones and plaster: Textures/travertine/make.py. Light falls from the upper left, as in the pin.

/// Which look the set draws in: the pin's travertine, or the same set painted to sit on Hubert Robert's The Bathing
/// Pool (SA_ROCOCO=1, RCHome.swift). Set once before rendering.
enum TVStyle {
    static var rococo = false
    /// The folder under Textures/ holding the stones, the wallpaper, the wall and the icons.
    static var folder: String { rococo ? "rococo" : "travertine" }
    /// The wallpaper's name in that folder (rococo also has wallpaper-swing and wallpaper-flowers).
    static var wallpaper = "wallpaper"
}

enum TVInk {
    static let ink = Color(hex: 0x3A2D23)
    static let inkSoft = Color(hex: 0x6B5B4C)
    // Deeper on the rococo set's painted limestone, which is darker than travertine.
    static var inkFaint: Color { TVStyle.rococo ? Color(hex: 0x6E604E) : Color(hex: 0x9A8A78) }
    static let cream = Color(hex: 0xF7F0E4)
    static let terracotta = Color(hex: 0x9C5B3D)
    static let shadow = Color(hex: 0x2B1F15)
}

enum TVType {
    // Rococo sets its words in Didot, the type of Robert's France.
    static func serif(_ s: CGFloat) -> Font { .custom(TVStyle.rococo ? "Didot" : "Baskerville", size: s) }
    static func italic(_ s: CGFloat) -> Font { .custom(TVStyle.rococo ? "Didot-Italic" : "Baskerville-Italic", size: s) }
    static func sans(_ s: CGFloat) -> Font { .custom("AvenirNext-Regular", size: s) }
    static func sansMedium(_ s: CGFloat) -> Font { .custom("AvenirNext-Medium", size: s) }
    static func script(_ s: CGFloat) -> Font { .custom("SavoyeLetPlain", size: s) }
}

// MARK: - Stone

enum TVStone: String {
    case travertine, olive, verde, terracotta, umber, tan

    var image: Image { Mock.texture("\(TVStyle.folder)/\(rawValue)") }

    /// The slab's underside, seen below its face when it is lifted off the wall.
    var edge: Color {
        switch self {
        case .travertine: return Color(hex: 0xB7A68D)
        case .olive: return Color(hex: 0x3D432D)
        case .verde: return Color(hex: 0x353A29)
        case .terracotta: return Color(hex: 0x5E3828)
        case .umber: return Color(hex: 0x2E261F)
        case .tan: return Color(hex: 0x7C5A41)
        }
    }

    var isDark: Bool { self != .travertine }
}

/// A slab of stone: the texture, light from the upper left, a softened edge (a lit lip at the upper left, a shaded
/// one at the lower right); with `lift`, the darker underside and the shadow it throws to the lower right.
struct TVSlab: View {
    var stone: TVStone
    var radius: CGFloat
    var lift: CGFloat = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            if lift > 0 {
                shape.fill(stone.edge)
                    .offset(x: lift * 0.4, y: lift)
                    .shadow(color: TVInk.shadow.opacity(0.3), radius: lift * 4.5, x: lift * 2.4, y: lift * 3.2)
                    .shadow(color: TVInk.shadow.opacity(0.28), radius: lift * 0.8, x: lift * 0.5, y: lift * 0.9)
            }
            Color.clear
                .overlay { stone.image.resizable().interpolation(.high).scaledToFill() }
                .clipShape(shape)
            shape.fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0), .black.opacity(0.1)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(stone.isDark ? 0.35 : 0.7), location: 0),
                                                      .init(color: .white.opacity(0), location: 0.4),
                                                      .init(color: .black.opacity(0), location: 0.6),
                                                      .init(color: .black.opacity(0.22), location: 1)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            shape.inset(by: 2)
                .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear, .black.opacity(0.14)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 4)
                .blur(radius: 2.5)
                .clipShape(shape)
        }
    }
}

/// A line cut into the stone: a dark groove with a lit lower lip.
struct TVCarve<S: Shape>: View {
    var shape: S
    var width: CGFloat = 1.1
    var dash: [CGFloat] = []
    var dark = false

    var body: some View {
        ZStack {
            shape.stroke(Color.white.opacity(dark ? 0.22 : 0.75), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
                .offset(x: 0.4, y: 0.8)
            shape.stroke(TVInk.shadow.opacity(dark ? 0.6 : 0.4), style: StrokeStyle(lineWidth: width * 1.15, lineCap: .round, dash: dash))
        }
    }
}

struct TVLine: Shape {
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
    func tvRelief(_ h: CGFloat = 1) -> some View {
        shadow(color: TVInk.shadow.opacity(0.4), radius: 0.9 * h, x: 0.9 * h, y: 1.2 * h)
            .shadow(color: TVInk.shadow.opacity(0.2), radius: 3.5 * h, x: 2.2 * h, y: 3 * h)
    }
}

enum TVMaterial {
    case gold, cream, terracotta, umber, olive

    var gradient: LinearGradient {
        let c: [UInt32]
        switch self {
        case .gold: c = [0xFAE5A4, 0xE2B259, 0xAC7930]
        case .cream: c = [0xFFFCF6, 0xEDE3D2, 0xCDBEA6]
        case .terracotta: c = [0xCB8463, 0x9E5C3E, 0x6E3B26]
        case .umber: c = [0x7C6856, 0x4E4034, 0x2E251E]
        case .olive: c = [0x919E70, 0x606D47, 0x3F4A2E]
        }
        return LinearGradient(colors: c.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// An SF Symbol raised in a material: lit on its upper left edges, shaded on the lower right, standing off the stone.
struct TVSymbolRelief: View {
    var name: String
    var material: TVMaterial
    var size: CGFloat

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * 1.22, weight: .bold))
            .foregroundStyle(material.gradient
                .shadow(.inner(color: .white.opacity(0.6), radius: 0.5, x: -0.6, y: -0.8))
                .shadow(.inner(color: .black.opacity(0.4), radius: 1, x: 0.8, y: 1)))
            .tvRelief(1.1)
    }
}

/// The gold sun: a domed disc and eight rays.
struct TVSun: View {
    var radius: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { k in
                Capsule()
                    .fill(TVMaterial.gold.gradient)
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
        .tvRelief(0.9)
    }
}

struct TVLeafShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.midY), control1: CGPoint(x: r.minX + r.width * 0.25, y: r.minY - r.height * 0.15),
                   control2: CGPoint(x: r.minX + r.width * 0.72, y: r.minY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.midY), control1: CGPoint(x: r.minX + r.width * 0.72, y: r.maxY),
                   control2: CGPoint(x: r.minX + r.width * 0.25, y: r.maxY + r.height * 0.15))
        p.closeSubpath()
        return p
    }
}

/// A raised olive leaf, its base at the leading edge: graded green, a pale midrib.
struct TVLeaf: View {
    var length: CGFloat
    var width: CGFloat
    var gold = false

    var body: some View {
        ZStack {
            if gold {
                TVLeafShape().fill(TVMaterial.gold.gradient)
            } else {
                TVLeafShape().fill(LinearGradient(colors: [Color(hex: 0x8E9C71), Color(hex: 0x5E6D47), Color(hex: 0x435032)],
                                                  startPoint: .top, endPoint: .bottom))
            }
            TVLeafShape().fill(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing))
            Path { p in
                p.move(to: CGPoint(x: 1, y: width / 2))
                p.addQuadCurve(to: CGPoint(x: length * 0.9, y: width / 2), control: CGPoint(x: length * 0.5, y: width * 0.44))
            }
            .stroke(Color(hex: gold ? 0xFFF1C4 : 0xC2CAA2).opacity(0.6), lineWidth: max(0.4, width * 0.07))
        }
        .frame(width: length, height: width)
    }
}

/// An olive: dark, glossy.
struct TVOlive: View {
    var w: CGFloat
    var h: CGFloat

    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color(hex: 0x8B7658), Color(hex: 0x4A3A28), Color(hex: 0x261D15)],
                                 center: UnitPoint(x: 0.34, y: 0.3), startRadius: 0, endRadius: w * 0.75))
            .overlay(Ellipse().fill(.white.opacity(0.38)).frame(width: w * 0.32, height: h * 0.2)
                .offset(x: -w * 0.16, y: -h * 0.22).blur(radius: 0.6))
            .frame(width: w, height: h)
    }
}

/// Places a view with its leading-centre at p, turned by `angle` degrees round that point.
private func tvPlace<V: View>(_ v: V, at p: CGPoint, length: CGFloat, angle: Double) -> some View {
    v.rotationEffect(.degrees(angle), anchor: .leading)
        .position(x: p.x + length / 2, y: p.y)
}

/// A sprig of olive in relief: a curved stem with leaves along it and olives hanging from it. Drawn in a 110 x 140
/// box from its base at the lower right to its tip at the upper left; scale it with `scale`.
struct TVOliveBranch: View {
    var scale: CGFloat = 1
    var olives = true
    var gold = false

    static let base = CGPoint(x: 96, y: 136), tip = CGPoint(x: 16, y: 6), bend = CGPoint(x: 86, y: 52)

    static func point(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * base.x + 2 * u * t * bend.x + t * t * tip.x, y: u * u * base.y + 2 * u * t * bend.y + t * t * tip.y)
    }

    static func angle(_ t: CGFloat) -> Double {
        let dx = 2 * (1 - t) * (bend.x - base.x) + 2 * t * (tip.x - bend.x)
        let dy = 2 * (1 - t) * (bend.y - base.y) + 2 * t * (tip.y - bend.y)
        return atan2(Double(dy), Double(dx)) * 180 / .pi
    }

    var body: some View {
        let leaves: [(CGFloat, Double, CGFloat)] = [(0.14, 38, 40), (0.26, -40, 44), (0.4, 36, 46), (0.52, -38, 44),
                                                    (0.64, 34, 42), (0.76, -36, 40), (0.88, 30, 34), (1.0, 4, 30)]
        let fruit: [(CGFloat, CGFloat, CGFloat)] = [(0.3, 14, 1), (0.47, 12, -1), (0.68, 14, 1)]
        ZStack {
            Path { p in
                p.move(to: Self.base)
                p.addQuadCurve(to: Self.tip, control: Self.bend)
            }
            .stroke(LinearGradient(colors: gold ? [Color(hex: 0xE2B259), Color(hex: 0xAC7930)] : [Color(hex: 0x7A6A4C), Color(hex: 0x4E4330)],
                                   startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            if olives {
                ForEach(Array(fruit.enumerated()), id: \.offset) { _, f in
                    let p = Self.point(f.0)
                    let a = Self.angle(f.0) + 90 * Double(f.2)
                    let d = CGPoint(x: CGFloat(cos(a * .pi / 180)) * 10, y: CGFloat(sin(a * .pi / 180)) * 10)
                    Path { s in
                        s.move(to: p)
                        s.addLine(to: CGPoint(x: p.x + d.x * 0.6, y: p.y + d.y * 0.6))
                    }
                    .stroke(Color(hex: 0x5A4C36), lineWidth: 1)
                    TVOlive(w: f.1 * 1.35, h: f.1)
                        .rotationEffect(.degrees(a))
                        .position(x: p.x + d.x * 1.25, y: p.y + d.y * 1.25)
                }
            }
            ForEach(Array(leaves.enumerated()), id: \.offset) { _, l in
                tvPlace(TVLeaf(length: l.2, width: l.2 * 0.27, gold: gold), at: Self.point(l.0), length: l.2,
                        angle: Self.angle(l.0) + l.1)
            }
        }
        .frame(width: 110, height: 140)
        .tvRelief(0.8)
        .scaleEffect(scale)
        .frame(width: 110 * scale, height: 140 * scale)
    }
}

struct TVPetalShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.midY), control1: CGPoint(x: r.minX + r.width * 0.3, y: r.minY - r.height * 0.1),
                   control2: CGPoint(x: r.maxX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.midY), control1: CGPoint(x: r.maxX, y: r.maxY),
                   control2: CGPoint(x: r.minX + r.width * 0.3, y: r.maxY + r.height * 0.1))
        p.closeSubpath()
        return p
    }
}

/// A cream flower in relief with gold-edged petals and a gold heart.
struct TVFlower: View {
    var radius: CGFloat
    var petals = 6

    var body: some View {
        ZStack {
            ForEach(0..<petals, id: \.self) { k in
                TVPetalShape()
                    .fill(LinearGradient(colors: [Color(hex: 0xD9CCB6), Color(hex: 0xF4EDE1), Color(hex: 0xFFFDF8)],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(TVPetalShape().stroke(TVMaterial.gold.gradient, lineWidth: max(0.5, radius * 0.035)))
                    .frame(width: radius, height: radius * 0.66)
                    .shadow(color: TVInk.shadow.opacity(0.18), radius: 1, x: 0.5, y: 0.8)
                    .offset(x: radius * 0.5)
                    .rotationEffect(.degrees(Double(k) * 360 / Double(petals) - 90))
            }
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFCE6A6), Color(hex: 0xD9A64C), Color(hex: 0x9C6C28)],
                                     center: UnitPoint(x: 0.36, y: 0.3), startRadius: 0, endRadius: radius * 0.3))
                .frame(width: radius * 0.46, height: radius * 0.46)
                .shadow(color: TVInk.shadow.opacity(0.3), radius: 1, x: 0.6, y: 0.9)
        }
        .frame(width: radius * 2.2, height: radius * 2.2)
        .tvRelief(0.7)
    }
}

/// The flower on its stem with two leaves, for the to-do widget's panel.
struct TVFlowerStem: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 40, y: 44))
                p.addQuadCurve(to: CGPoint(x: 36, y: 130), control: CGPoint(x: 46, y: 90))
            }
            .stroke(LinearGradient(colors: [Color(hex: 0x6F7C52), Color(hex: 0x46512F)], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
            tvPlace(TVLeaf(length: 30, width: 9), at: CGPoint(x: 42, y: 92), length: 30, angle: -38)
            tvPlace(TVLeaf(length: 28, width: 8.5), at: CGPoint(x: 40, y: 104), length: 28, angle: -150)
            TVFlower(radius: 24).position(x: 40, y: 40)
        }
        .frame(width: 84, height: 132)
        .tvRelief(0.6)
    }
}

// MARK: - Paintings in sunlight

enum TVLight {
    /// The Cover's light for the hour, with a sunlit Mediterranean glaze by day: warm plaster lights, a greige sky,
    /// olive-brown land. At night, the Cover's own glaze.
    static func sunlit(_ snap: DaySnapshot) -> CoverLight {
        var l = CoverLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: .clear)
        guard l.isDay else { return l }
        l.shadow = [Color(hex: 0x8A7560), Color(hex: 0x4C4233)]
        l.mid = [Color(hex: 0xE2D3BC), Color(hex: 0x9C9468)]
        l.light = [Color(hex: 0xFFF8EC), Color(hex: 0xEFE6C8)]
        l.glow = Color(hex: 0xFFEBC6)
        l.air = l.air * 1.3
        return l
    }
}

/// One of the Sun Arc landscapes on its own (no arc), enlarged by `scale` from the top left and shifted by `offset`.
struct TVPainting: View {
    var scene: String
    var light: CoverLight
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    var body: some View {
        let folder = scene == "matterhorn" ? "weather-sun-arc" : "weather-sun-arc/scenes/\(scene)"
        Color.clear
            .overlay(alignment: .topLeading) {
                SAPaint(lower: Mock.texture("\(folder)/large-lo"), upper: Mock.texture("\(folder)/large-hi"),
                        glow: Mock.texture("\(folder)/large-glow"), light: light, center: UnitPoint(x: 0.66, y: 0.12),
                        reach: 380, seed: 31, aged: false)
                    .frame(width: 348, height: 365)
                    .scaleEffect(scale, anchor: .topLeading)
                    .offset(offset)
            }
            // Sunlight: the darks lifted and warmed, as in a bright photograph.
            .overlay(Color(hex: 0xFFE4BC).blendMode(.softLight).opacity(light.isDay ? 0.55 : 0))
            .contrast(light.isDay ? 1.12 : 1)
            .saturation(light.isDay ? 1.15 : 1)
            .clipped()
    }
}

// MARK: - Widgets

/// Page one's widget, after the pin's photo hero: Val d'Orcia in sunlight, the date and temperature at the top right,
/// the quote large in italic down the shaded left, a short rule, and the weather in spaced capitals.
struct TVHero: View {
    var snap: DaySnapshot
    var quote: Quote

    var body: some View {
        let size = Mock.size(.large)
        let w = snap.weather
        ZStack(alignment: .topLeading) {
            if TVStyle.rococo {
                RCDetail.hero.at(night: !TVLight.sunlit(snap).isDay)
                RCDetail.corners
            } else {
                TVPainting(scene: "tuscany", light: TVLight.sunlit(snap), scale: 1.4, offset: CGSize(width: -6, height: -52))
            }
            LinearGradient(colors: [Color(hex: 0x3A2C1F).opacity(0.55), Color(hex: 0x3A2C1F).opacity(0.22), .clear],
                           startPoint: .leading, endPoint: UnitPoint(x: 0.7, y: 0.5))
            LinearGradient(colors: [Color(hex: 0x3A2C1F).opacity(0.3), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3))
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(SAWords.month(snap.date).capitalized) \(SAWords.day(snap.date))")
                    .font(TVType.serif(17))
                Text(SAWords.temp(w))
                    .font(TVType.serif(56))
                    .padding(.top, -4)
            }
            .foregroundStyle(TVInk.cream)
            .shadow(color: TVInk.shadow.opacity(0.5), radius: 4, x: 0, y: 1)
            .fixedSize()
            .saBaseline(x: 330, y: 36, in: size, trailing: true)
            VStack(alignment: .leading, spacing: 0) {
                Text(quote.text)
                    .font(TVType.italic(27))
                    .lineSpacing(-1)
                    .foregroundStyle(TVInk.cream)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(TVInk.cream.opacity(0.75)).frame(width: 20, height: 0.8)
                    .padding(.top, 16)
                VStack(alignment: .leading, spacing: 6) {
                    if let w {
                        Text(SAWords.condition(w).uppercased())
                        Text("HIGH \(Int(w.high.rounded()))  ·  LOW \(Int(w.low.rounded()))")
                        if let set = w.sunset { Text("SUNSET \(SAWords.clock(set))") }
                    } else {
                        Text(snap.weatherError?.uppercased() ?? "WEATHER OFFLINE")
                    }
                }
                .font(TVType.sansMedium(8.5))
                .tracking(2.2)
                .foregroundStyle(TVInk.cream.opacity(0.92))
                .padding(.top, 13)
            }
            .shadow(color: TVInk.shadow.opacity(0.5), radius: 5, x: 0, y: 1)
            .frame(width: 186, alignment: .leading)
            .offset(x: 22, y: 112)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Sun Arc in stone: the sun's path carved as an arc above a carved horizon, the day gone inlaid in gold, the gold
/// sun raised where it is now; sunrise and sunset under the feet, the length of the day, a sprig of olive.
struct TVSunArc: View {
    var snap: DaySnapshot
    var lift: CGFloat = 0
    /// False when it sits on a wider slab (TVSunArcMedium).
    var slab = true

    var body: some View {
        let size = Mock.size(.small)
        let clock = SkyClock(now: snap.date, weather: snap.weather)
        let arc = SkyArc(centerX: 0.5, horizon: 0.56, radiusX: 0.37, radiusY: 0.4)
        let done = snap.weather == nil ? 0 : min(1, max(0, clock.progress))
        let sun = arc.point(done, in: size)
        let w = snap.weather
        ZStack(alignment: .topLeading) {
            if slab { TVSlab(stone: .travertine, radius: Mock.cornerRadius, lift: lift) }
            TVCarve(shape: TVLine(), width: 1)
                .frame(width: 140, height: 2)
                .position(x: 82, y: arc.point(0, in: size).y + 1)
            TVCarve(shape: SAArcPath(arc: arc, from: 0, to: 1), width: 1.8)
            SAArcPath(arc: arc, from: 0, to: done)
                .stroke(TVMaterial.gold.gradient, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .shadow(color: TVInk.shadow.opacity(0.3), radius: 0.4, x: 0.3, y: 0.5)
            if clock.isDay {
                TVSun(radius: 8.5).position(sun)
            } else {
                TVMoonRelief(phase: MoonPhase(date: snap.date), radius: 8).position(sun)
            }
            if let w, let rise = w.sunrise, let set = w.sunset {
                TVSunTime(time: SAWords.clock(rise), word: "SUNRISE", leading: true)
                    .saBaseline(x: 16, y: 113, in: size)
                TVSunTime(time: SAWords.clock(set), word: "SUNSET", leading: false)
                    .saBaseline(x: 148, y: 113, in: size, trailing: true)
                Text(SAMoonSmall.daylight(snap).map { "\($0) of light" } ?? "")
                    .font(TVType.italic(11.5))
                    .foregroundStyle(TVInk.inkSoft)
                    .saBaseline(x: 16, y: 148, in: size)
            } else {
                Text(snap.weatherError ?? "no sun times yet")
                    .font(TVType.sans(9.5))
                    .foregroundStyle(TVInk.terracotta)
                    .lineLimit(2)
                    .frame(width: 130, alignment: .leading)
                    .saBaseline(x: 16, y: 118, in: size)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

struct TVSunTime: View {
    var time: String
    var word: String
    var leading: Bool

    var body: some View {
        VStack(alignment: leading ? .leading : .trailing, spacing: 2) {
            Text(time).font(TVType.serif(17)).foregroundStyle(TVInk.ink)
            Text(word).font(TVType.sansMedium(6.5)).tracking(1.6).foregroundStyle(TVInk.inkSoft)
        }
        .fixedSize()
    }
}

/// The moon in relief: the lit part raised in cream, the rest a faint carved disc.
struct TVMoonRelief: View {
    var phase: MoonPhase
    var radius: CGFloat

    var body: some View {
        ZStack {
            TVCarve(shape: Circle(), width: 0.8)
            MoonLitShape(phase: phase)
                .fill(TVMaterial.cream.gradient.shadow(.inner(color: .black.opacity(0.25), radius: 1, x: 0.6, y: 0.8)))
                .tvRelief(0.7)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

/// A quote cut into green stone.
struct TVQuoteTile: View {
    var quote: Quote
    var lift: CGFloat = 0

    var body: some View {
        let size = Mock.size(.small)
        ZStack(alignment: .topLeading) {
            TVSlab(stone: .verde, radius: Mock.cornerRadius, lift: lift)
            VStack(alignment: .leading, spacing: 0) {
                Text(quote.text)
                    .font(TVType.serif(15))
                    .lineSpacing(0)
                    .foregroundStyle(TVInk.cream)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Rectangle().fill(TVInk.cream.opacity(0.75)).frame(width: 16, height: 0.8)
                if let author = quote.author {
                    Text(author.uppercased())
                        .font(TVType.sansMedium(6.5))
                        .tracking(1.5)
                        .foregroundStyle(TVInk.cream.opacity(0.7))
                        .lineLimit(1)
                        .padding(.top, 6)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 0.5, x: 0, y: 0.6)
            .frame(width: 132, height: 132, alignment: .topLeading)
            .offset(x: 16, y: 16)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The days ahead on travertine: a title and a sprig, then four days ruled with carved lines.
struct TVForecastTile: View {
    var snap: DaySnapshot
    var lift: CGFloat = 0
    var slab = true

    var body: some View {
        let size = Mock.size(.small)
        ZStack(alignment: .topLeading) {
            if slab { TVSlab(stone: .travertine, radius: Mock.cornerRadius, lift: lift) }
            Text("The days ahead").font(TVType.serif(15.5)).foregroundStyle(TVInk.ink)
                .saBaseline(x: 16, y: 29, in: size)
            VStack(spacing: 0) {
                ForEach(Array(SAForecast.days.enumerated()), id: \.offset) { i, d in
                    if i > 0 { TVCarve(shape: TVLine(), width: 0.6).frame(height: 1) }
                    HStack(spacing: 0) {
                        Text(SAForecast.name(d.offset, from: snap.date))
                            .font(TVType.sans(10.5))
                            .foregroundStyle(d.rain >= 50 ? TVInk.terracotta : TVInk.ink)
                        Spacer(minLength: 2)
                        TVSymbolRelief(name: d.symbol + (d.symbol == "sun.max" ? ".fill" : ".fill"),
                                       material: d.symbol == "sun.max" ? .gold : .cream, size: 11)
                            .frame(width: 22)
                        (Text("\(d.high)°").foregroundColor(TVInk.ink) + Text("  \(d.low)°").foregroundColor(TVInk.inkFaint))
                            .font(TVType.serif(12))
                            .frame(width: 46, alignment: .trailing)
                    }
                    .frame(height: 24)
                }
            }
            .frame(width: 132)
            .offset(x: 16, y: 42)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Tonight on travertine: the moon in relief, its phase and rise, and the day's light.
struct TVTonightTile: View {
    var snap: DaySnapshot
    var lift: CGFloat = 0

    var body: some View {
        let size = Mock.size(.small)
        let phase = MoonPhase(date: snap.date)
        let lit = Int(((1 - cos(2 * .pi * phase.fraction)) / 2 * 100).rounded())
        ZStack(alignment: .topLeading) {
            TVSlab(stone: .travertine, radius: Mock.cornerRadius, lift: lift)
            Text("Tonight").font(TVType.serif(15.5)).foregroundStyle(TVInk.ink)
                .saBaseline(x: 16, y: 29, in: size)
            TVMoonRelief(phase: phase, radius: 13).position(x: 128, y: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(SAWords.phase(phase).capitalized(with: nil).replacingOccurrences(of: " M", with: " m")
                    .replacingOccurrences(of: " C", with: " c").replacingOccurrences(of: " G", with: " g"))
                    .font(TVType.sans(11)).foregroundStyle(TVInk.ink)
                Text([SAMoonSmall.moonrise(snap, phase).map { "rises \($0)" }, "\(lit)% lit"].compactMap { $0 }.joined(separator: "  ·  "))
                    .font(TVType.sans(9.5)).foregroundStyle(TVInk.inkSoft)
                    .padding(.top, 3)
                TVCarve(shape: TVLine(), width: 0.6).frame(height: 1).padding(.vertical, 10)
                Text("Daylight").font(TVType.sans(11)).foregroundStyle(TVInk.ink)
                Text("\(SAMoonSmall.daylight(snap) ?? "unknown")  ·  − 2 m")
                    .font(TVType.sans(9.5)).foregroundStyle(TVInk.inkSoft)
                    .padding(.top, 3)
            }
            .frame(width: 132, alignment: .leading)
            .saBaseline(x: 16, y: 66, in: size)
            TVOliveBranch(scale: 0.3, olives: false)
                .rotationEffect(.degrees(-30))
                .position(x: 142, y: 138)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// A painting with a quote written across it in script, as the pin's picture widget.
struct TVPictureTile: View {
    var snap: DaySnapshot
    var quote: Quote
    var lift: CGFloat = 0

    var body: some View {
        let size = Mock.size(.small)
        let shape = RoundedRectangle(cornerRadius: Mock.cornerRadius, style: .continuous)
        ZStack(alignment: .topLeading) {
            if lift > 0 { TVSlab(stone: .umber, radius: Mock.cornerRadius, lift: lift) }
            ZStack(alignment: .topLeading) {
                if TVStyle.rococo {
                    RCDetail.square.at(night: !TVLight.sunlit(snap).isDay)
                } else {
                    TVPainting(scene: "matterhorn", light: TVLight.sunlit(snap), scale: 0.78, offset: CGSize(width: -58, height: -14))
                }
                LinearGradient(colors: [.clear, Color(hex: 0x2E2318).opacity(0.5)], startPoint: UnitPoint(x: 0.35, y: 0.5),
                               endPoint: .trailing)
                VStack(alignment: .leading, spacing: -6) {
                    ForEach(quote.text.replacingOccurrences(of: ".", with: "").split(separator: " ").map(String.init), id: \.self) { word in
                        Text(word.capitalized).font(TVType.script(27))
                    }
                    Rectangle().frame(width: 14, height: 0.8).padding(.top, 14)
                }
                .foregroundStyle(TVInk.cream)
                .shadow(color: TVInk.shadow.opacity(0.5), radius: 2, x: 0, y: 1)
                .fixedSize()
                .offset(x: 92, y: 18)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.3), .clear, .black.opacity(0.2)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Page two's wide weather: Sun Arc on the left, the days ahead on the right, a carved line between.
struct TVSunArcMedium: View {
    var snap: DaySnapshot
    var lift: CGFloat = 0

    var body: some View {
        let size = Mock.size(.medium)
        ZStack(alignment: .topLeading) {
            TVSlab(stone: .travertine, radius: Mock.cornerRadius, lift: lift)
            TVSunArc(snap: snap, slab: false)
            TVCarve(shape: TVLine(vertical: true), width: 0.7)
                .frame(width: 2, height: 124)
                .position(x: 174, y: size.height / 2)
            TVForecastTile(snap: snap, slab: false)
                .offset(x: 176)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Page three's picture: a painting across the whole widget, a line from the vault written over it in script.
struct TVPictureMedium: View {
    var snap: DaySnapshot
    var quote: Quote
    var lift: CGFloat = 0

    var body: some View {
        let size = Mock.size(.medium)
        let shape = RoundedRectangle(cornerRadius: Mock.cornerRadius, style: .continuous)
        let words = quote.text.replacingOccurrences(of: ".", with: "").split(separator: " ").map(String.init)
        let half = (words.count + 1) / 2
        ZStack(alignment: .topLeading) {
            if lift > 0 { TVSlab(stone: .umber, radius: Mock.cornerRadius, lift: lift) }
            ZStack(alignment: .topLeading) {
                if TVStyle.rococo {
                    RCDetail.wide.at(night: !TVLight.sunlit(snap).isDay)
                } else {
                    TVPainting(scene: TVPictureMedium.scene, light: TVLight.sunlit(snap), scale: TVPictureMedium.scale,
                               offset: TVPictureMedium.offset)
                }
                LinearGradient(colors: [.clear, Color(hex: 0x2E2318).opacity(0.72)], startPoint: UnitPoint(x: 0.4, y: 0.5),
                               endPoint: .trailing)
                VStack(alignment: .leading, spacing: -8) {
                    Text(words.prefix(half).joined(separator: " ").capitalized).font(TVType.script(31))
                    Text(words.dropFirst(half).joined(separator: " ").capitalized).font(TVType.script(31))
                        .padding(.leading, 18)
                    Rectangle().frame(width: 14, height: 0.8).padding(.top, 16).padding(.leading, 18)
                }
                .foregroundStyle(TVInk.cream)
                .shadow(color: TVInk.shadow.opacity(0.55), radius: 2, x: 0, y: 1)
                .fixedSize()
                .offset(x: TVPictureMedium.text.x, y: TVPictureMedium.text.y)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.3), .clear, .black.opacity(0.2)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    static let scene = "dolomites"
    static let scale: CGFloat = 1.0
    static let offset = CGSize(width: -10, height: -42)
    static let text = CGPoint(x: 190, y: 30)
}

/// A carved ring to tick; terracotta when the task is late.
struct TVRing: View {
    var late: Bool

    var body: some View {
        ZStack {
            TVCarve(shape: Circle(), width: 1)
            if late { Circle().strokeBorder(TVInk.terracotta.opacity(0.8), lineWidth: 1.1) }
        }
        .frame(width: 13, height: 13)
    }
}

/// Today's tasks on travertine.
struct TVTodayList: View {
    var snap: DaySnapshot
    var rows: Int
    var width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today").font(TVType.serif(18)).foregroundStyle(TVInk.ink)
                Spacer()
                Text("•••").font(TVType.sans(9)).tracking(1).foregroundStyle(TVInk.inkSoft)
            }
            .padding(.bottom, 8)
            if snap.tasks.isEmpty {
                Text(snap.taskError ?? "Nothing due today.")
                    .font(TVType.sans(10.5))
                    .foregroundStyle(snap.taskError == nil ? TVInk.inkSoft : TVInk.terracotta)
                    .lineLimit(2)
            }
            ForEach(Array(snap.tasks.prefix(rows).enumerated()), id: \.offset) { _, t in
                let late = t.isOverdue(asOf: snap.date)
                HStack(spacing: 9) {
                    TVRing(late: late)
                    Text(t.text)
                        .font(TVType.sans(11))
                        .foregroundStyle(late ? TVInk.terracotta : TVInk.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(height: 24, alignment: .leading)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

struct TVTodaySmall: View {
    var snap: DaySnapshot
    var lift: CGFloat = 0

    var body: some View {
        let size = Mock.size(.small)
        ZStack(alignment: .topLeading) {
            TVSlab(stone: .travertine, radius: Mock.cornerRadius, lift: lift)
            TVTodayList(snap: snap, rows: 4, width: 132)
                .offset(x: 16, y: 13)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The wide to-do: the list on the left; on the right a raised inner panel with the flower and a line in script.
struct TVTodayMedium: View {
    var snap: DaySnapshot
    var lift: CGFloat = 0

    var body: some View {
        let size = Mock.size(.medium)
        let panel = RoundedRectangle(cornerRadius: 18, style: .continuous)
        ZStack(alignment: .topLeading) {
            TVSlab(stone: .travertine, radius: Mock.cornerRadius, lift: lift)
            TVTodayList(snap: snap, rows: 4, width: 160)
                .offset(x: 18, y: 13)
            ZStack(alignment: .topLeading) {
                if TVStyle.rococo {
                    // The still life's roses, the line set on its dark ground.
                    RCDetail.flowers.at(night: !TVLight.sunlit(snap).isDay)
                    LinearGradient(colors: [.clear, Color(hex: 0x1C1912).opacity(0.45)], startPoint: .center, endPoint: .bottomTrailing)
                } else {
                    TVSlab(stone: .travertine, radius: 18)
                        .shadow(color: TVInk.shadow.opacity(0.18), radius: 3, x: -1, y: 1)
                    TVFlowerStem().scaleEffect(0.9).position(x: 44, y: 76)
                    TVOliveBranch(scale: 0.2, olives: false, gold: true)
                        .rotationEffect(.degrees(40))
                        .position(x: 128, y: 24)
                }
                VStack(alignment: .leading, spacing: -4) {
                    Text("Small").font(TVType.italic(17))
                    Text("steps,").font(TVType.italic(17))
                    Text("every day").font(TVType.italic(17))
                    Rectangle().frame(width: 14, height: 0.8).padding(.top, 10)
                }
                .foregroundStyle(TVStyle.rococo ? TVInk.cream : TVInk.ink)
                .shadow(color: TVInk.shadow.opacity(TVStyle.rococo ? 0.6 : 0), radius: 2, x: 0, y: 1)
                .fixedSize()
                .offset(x: 80, y: 74)
            }
            .frame(width: 152, height: 148)
            .clipShape(panel)
            .offset(x: 188, y: 8)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

// MARK: - Icons

enum TVGlyph {
    case symbol(String, TVMaterial, CGFloat)
    case flower
    case calendar
}

struct TVApp {
    var name: String
    var stone: TVStone
    var glyph: TVGlyph
}

/// A custom icon: a small slab of stone with its object raised on it.
struct TVIcon: View {
    var app: TVApp
    var snap: DaySnapshot
    var side: CGFloat = 62
    var lift: CGFloat = 0

    /// The icon modelled and rendered in Blender (Textures/travertine/icons/build.py, which writes the rococo set to
    /// Textures/rococo/icons/), when there is one.
    static func render(_ app: TVApp) -> NSImage? {
        let slug = app.name.lowercased().replacingOccurrences(of: " ", with: "")
        return NSImage(contentsOf: Mock.root.appendingPathComponent("Textures/\(TVStyle.folder)/icons/\(slug).png"))
    }

    var body: some View {
        if let image = Self.render(app) {
            // The render is the whole tile; a lifted tile (the showcase only) also throws its shadow to the lower right.
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: side, height: side)
                .shadow(color: TVInk.shadow.opacity(lift > 0 ? 0.3 : 0), radius: lift * 4.5, x: lift * 2.4, y: lift * 3.2)
                .shadow(color: TVInk.shadow.opacity(lift > 0 ? 0.25 : 0), radius: lift * 0.8, x: lift * 0.5, y: lift * 0.9)
        } else {
            drawn
        }
    }

    /// The SwiftUI version, for an app with no render.
    private var drawn: some View {
        ZStack {
            TVSlab(stone: app.stone, radius: side * 0.234, lift: lift)
            switch app.glyph {
            case .symbol(let name, let material, let size):
                TVSymbolRelief(name: name, material: material, size: size)
            case .flower:
                TVFlower(radius: 18)
            case .calendar:
                VStack(spacing: -4) {
                    Text(SAWords.month(snap.date).prefix(3).uppercased())
                        .font(TVType.sansMedium(10)).tracking(1.2)
                    Text(SAWords.day(snap.date)).font(TVType.serif(34))
                }
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xA8603F), Color(hex: 0x7A4128)], startPoint: .top, endPoint: .bottom)
                    .shadow(.inner(color: .white.opacity(0.5), radius: 0.4, x: -0.5, y: -0.6)))
                .tvRelief(0.8)
            }
        }
        .frame(width: side, height: side)
    }
}

struct TVAppCell: View {
    var app: TVApp
    var snap: DaySnapshot

    var body: some View {
        VStack(spacing: 5) {
            TVIcon(app: app, snap: snap)
            SAHomeLabel(text: app.name)
        }
        .frame(width: 84)
    }
}

enum TVApps {
    // The user's apps. Each has a Blender render (Textures/travertine/icons/<slug>.png); the glyph is the SwiftUI stand-in.
    static let dock = [
        TVApp(name: "Claude", stone: .terracotta, glyph: .symbol("sparkle", .cream, 28)),
        TVApp(name: "Messages", stone: .olive, glyph: .symbol("message.fill", .cream, 26)),
        TVApp(name: "Safari", stone: .travertine, glyph: .symbol("safari", .gold, 30)),
        TVApp(name: "Obsidian", stone: .umber, glyph: .symbol("rhombus.fill", .gold, 24)),
    ]
    static let pageOne = [
        TVApp(name: "Gmail", stone: .travertine, glyph: .symbol("envelope.fill", .terracotta, 24)),
        TVApp(name: "Photos", stone: .olive, glyph: .flower),
        TVApp(name: "Camera", stone: .travertine, glyph: .symbol("camera.fill", .umber, 25)),
        TVApp(name: "YouTube", stone: .umber, glyph: .symbol("play.rectangle.fill", .terracotta, 25)),
        TVApp(name: "Settings", stone: .olive, glyph: .symbol("gearshape.fill", .gold, 29)),
        TVApp(name: "Spotify", stone: .umber, glyph: .symbol("headphones", .gold, 26)),
        TVApp(name: "Maps", stone: .olive, glyph: .symbol("mappin", .cream, 26)),
        TVApp(name: "Calendar", stone: .travertine, glyph: .calendar),
    ]
    static let pageTwo = [
        TVApp(name: "Weather", stone: .travertine, glyph: .symbol("cloud.sun.fill", .gold, 26)),
        TVApp(name: "AllTrails", stone: .olive, glyph: .symbol("mountain.2.fill", .cream, 24)),
        TVApp(name: "Uber Eats", stone: .travertine, glyph: .symbol("bag.fill", .umber, 24)),
        TVApp(name: "Netflix", stone: .umber, glyph: .symbol("n.square.fill", .terracotta, 26)),
        TVApp(name: "Equinox", stone: .umber, glyph: .symbol("figure.strengthtraining.traditional", .cream, 26)),
        TVApp(name: "Find My", stone: .travertine, glyph: .symbol("location.circle.fill", .gold, 27)),
        TVApp(name: "Slack", stone: .umber, glyph: .symbol("number", .cream, 26)),
        TVApp(name: "Clock", stone: .travertine, glyph: .symbol("clock.fill", .umber, 26)),
    ]
    static let pageThree = [
        TVApp(name: "Wallet", stone: .umber, glyph: .symbol("wallet.pass.fill", .cream, 24)),
        TVApp(name: "App Store", stone: .olive, glyph: .symbol("arrow.down.app.fill", .cream, 25)),
        TVApp(name: "Files", stone: .tan, glyph: .symbol("folder.fill", .cream, 24)),
        TVApp(name: "Venmo", stone: .verde, glyph: .symbol("v.circle.fill", .cream, 26)),
    ]
    static let all = dock + pageOne + pageTwo + pageThree
}

// MARK: - The home screen and the showcase

struct TVHomeScreen: View {
    var page: Int
    var snap: DaySnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            TVWallpaper()
            SAStatusBar(time: SAHome.clock(snap.date))
            switch page {
            case 1:
                widget(.large, left: 27, row: 0) { TVHero(snap: snap, quote: TVQuotes.hero) }
                apps(TVApps.pageOne, rows: [4, 5])
            case 2:
                widget(.medium, left: 27, row: 0) { TVSunArcMedium(snap: snap) }
                apps(TVApps.pageTwo, rows: [2, 3])
                widget(.medium, left: 27, row: 4) { TVTodayMedium(snap: snap) }
            default:
                widget(.medium, left: 27, row: 0) { TVPictureMedium(snap: snap, quote: TVQuotes.picture) }
                apps(TVApps.pageThree, rows: [2])
            }
            SAPageDots(page: page, count: 3, night: false)
                .position(x: 201, y: 719)
            TVDock(snap: snap)
        }
        .frame(width: SAHomeScreen.screen.width, height: SAHomeScreen.screen.height)
        .clipped()
    }

    private func widget<V: View>(_ family: Family, left: CGFloat, row: Int, @ViewBuilder _ content: () -> V) -> some View {
        let s = Mock.size(family)
        let top = SAHomeScreen.rowTop(row)
        return ZStack(alignment: .topLeading) {
            // No shadow on the wallpaper: iOS clips a widget to its shape. The depth is all inside the stone.
            WidgetTile(family: family, content: content)
                .position(x: left + s.width / 2, y: top + s.height / 2)
            SAHomeLabel(text: "Baroque")
                .position(x: left + s.width / 2, y: top + s.height + 13)
        }
    }

    /// The apps in order, four to a row.
    private func apps(_ list: [TVApp], rows: [Int]) -> some View {
        let cells = rows.flatMap { r in (0..<4).map { ($0, r) } }
        return ZStack(alignment: .topLeading) {
            ForEach(Array(zip(list, cells).enumerated()), id: \.offset) { _, pair in
                TVAppCell(app: pair.0, snap: snap)
                    .position(x: SAHomeScreen.columns[pair.1.0], y: SAHomeScreen.rowTop(pair.1.1) + 8 + 40.5)
            }
        }
    }
}

enum TVQuotes {
    static let hero = DemoData.quotes[2]      // "Make the quiet thing first, then the loud one."
    static let tile = DemoData.quotes[0]      // Thoreau
    static let picture = DemoData.quotes[3]   // "Good ideas take time."
}

struct TVWallpaper: View {
    var body: some View {
        Mock.texture("\(TVStyle.folder)/\(TVStyle.wallpaper)")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: SAHomeScreen.screen.width, height: SAHomeScreen.screen.height)
            .clipped()
    }
}

/// The dock as frosted glass over the plaster.
struct TVDock: View {
    var snap: DaySnapshot

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 40, style: .continuous)
        let frame = CGRect(x: 17.5, y: 744, width: 367, height: 101)
        ZStack(alignment: .topLeading) {
            TVWallpaper()
                .blur(radius: 14)
                .brightness(0.08)
                .mask { shape.frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY) }
            shape.fill(Color(hex: 0xF4ECDF).opacity(0.42))
                .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.1), .white.opacity(0.25)],
                                                           startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
            ForEach(Array(TVApps.dock.enumerated()), id: \.offset) { i, app in
                TVIcon(app: app, snap: snap)
                    .position(x: SAHomeScreen.columns[i], y: frame.midY)
            }
        }
        .frame(width: SAHomeScreen.screen.width, height: SAHomeScreen.screen.height, alignment: .topLeading)
    }
}

/// An iPhone in champagne titanium round a home screen, at `screenWidth` points wide.
struct TVPhone<Screen: View>: View {
    var screenWidth: CGFloat
    @ViewBuilder var screen: Screen

    var body: some View {
        let s = screenWidth / SAHomeScreen.screen.width
        let sw = screenWidth, sh = SAHomeScreen.screen.height * s
        let bezel: CGFloat = 13
        ZStack {
            RoundedRectangle(cornerRadius: 62 * s + bezel, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xE6D6BD), Color(hex: 0xA48A6B), Color(hex: 0xD9C6A8), Color(hex: 0x8C7356)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: sw + 2 * bezel, height: sh + 2 * bezel)
                .shadow(color: TVInk.shadow.opacity(0.35), radius: 22, x: 14, y: 18)
            RoundedRectangle(cornerRadius: 62 * s + bezel - 4, style: .continuous)
                .fill(Color(hex: 0x0E0B09))
                .frame(width: sw + 2 * bezel - 8, height: sh + 2 * bezel - 8)
            screen
                .frame(width: SAHomeScreen.screen.width, height: SAHomeScreen.screen.height)
                .scaleEffect(s)
                .frame(width: sw, height: sh)
                .clipShape(RoundedRectangle(cornerRadius: 62 * s, style: .continuous))
            Capsule().fill(Color.black)
                .frame(width: 124 * s, height: 36 * s)
                .offset(y: -sh / 2 + 11 * s + 18 * s)
            // Side buttons.
            ForEach(Array([(-1.0, 0.2, 0.05), (-1.0, 0.29, 0.07), (-1.0, 0.38, 0.07), (1.0, 0.3, 0.1)].enumerated()), id: \.offset) { _, b in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [Color(hex: 0xD9C6A8), Color(hex: 0x8C7356)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 4, height: sh * b.2)
                    .offset(x: CGFloat(b.0) * (sw / 2 + bezel + 1.5), y: -sh / 2 + sh * b.1)
            }
        }
    }
}

/// The pin's layout: the phone on page one on the left; on the right the set of widgets and the dock's icons, at 1.6x,
/// lifted off a plaster wall with olive-leaf shadows.
struct TVShowcase: View {
    var snap: DaySnapshot
    static let size = CGSize(width: 1240, height: 1300)

    var body: some View {
        let k: CGFloat = 1.6
        let cell = 164 * k, gap = 20 * k
        let x0 = Self.size.width - 40 - (2 * cell + gap)
        let y0 = (Self.size.height - (4 * cell + 3 * gap)) / 2
        let lift: CGFloat = 2.2
        ZStack(alignment: .topLeading) {
            Mock.texture("\(TVStyle.folder)/wall").resizable().interpolation(.high).scaledToFill()
                .frame(width: Self.size.width, height: Self.size.height).clipped()
            TVPhone(screenWidth: 520) { TVHomeScreen(page: 1, snap: snap) }
                .position(x: 40 + 13 + 260, y: Self.size.height / 2)
            Group {
                kit(TVSunArc(snap: snap, lift: lift), k: k, x: x0, y: y0)
                kit(TVQuoteTile(quote: TVQuotes.tile, lift: lift), k: k, x: x0 + cell + gap, y: y0)
                kit(TVForecastTile(snap: snap, lift: lift), k: k, x: x0, y: y0 + cell + gap)
                kit(TVTonightTile(snap: snap, lift: lift), k: k, x: x0 + cell + gap, y: y0 + cell + gap)
                kit(TVPictureTile(snap: snap, quote: TVQuotes.picture, lift: lift), k: k, x: x0, y: y0 + 2 * (cell + gap))
                kit(TVTodayMedium(snap: snap, lift: lift), k: k, x: x0, y: y0 + 3 * (cell + gap))
            }
            let icon: CGFloat = 62 * 1.75, igap: CGFloat = 26
            let ix = x0 + cell + gap + (cell - (2 * icon + igap)) / 2, iy = y0 + 2 * (cell + gap) + (cell - (2 * icon + igap)) / 2
            ForEach(Array(TVApps.dock.enumerated()), id: \.offset) { i, app in
                TVIcon(app: app, snap: snap, lift: 1.6)
                    .scaleEffect(1.75, anchor: .topLeading)
                    .frame(width: icon, height: icon, alignment: .topLeading)
                    .offset(x: ix + CGFloat(i % 2) * (icon + igap), y: iy + CGFloat(i / 2) * (icon + igap))
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .clipped()
    }

    private func kit<V: View>(_ v: V, k: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        v.scaleEffect(k, anchor: .topLeading)
            .offset(x: x, y: y)
    }
}

/// The user's 24 icons in home screen order, lifted, on the plaster wall.
struct TVIconSheet: View {
    var snap: DaySnapshot

    var body: some View {
        let apps = TVApps.all
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 10), count: 6), spacing: 16) {
            ForEach(Array(apps.enumerated()), id: \.offset) { _, app in
                VStack(spacing: 6) {
                    TVIcon(app: app, snap: snap, lift: 1.4)
                    Text(app.name).font(TVType.sans(11)).foregroundStyle(TVInk.inkSoft)
                }
            }
        }
        .padding(28)
        .frame(width: 6 * 94 + 56)
        .background {
            Mock.texture("\(TVStyle.folder)/wall").resizable().interpolation(.high).scaledToFill()
        }
        .clipped()
    }
}

enum TVRender {
    /// SA_TRAV=1 writes the showcase (scale 2), the three home screen pages and every widget (scale 3) to out/travertine/;
    /// SA_ROCOCO=1 writes the same in the rococo look to out/rococo/.
    @MainActor static func renderIfRequested() -> Bool {
        let env = ProcessInfo.processInfo.environment
        TVStyle.rococo = !(env["SA_ROCOCO"] ?? "").isEmpty
        guard TVStyle.rococo || !(env["SA_TRAV"] ?? "").isEmpty else { return false }
        let dir = Mock.root.appendingPathComponent("out/\(TVStyle.folder)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let snap = Mock.day
        MockRunner.write(TVShowcase(snap: snap), scale: 2, to: dir.appendingPathComponent("showcase.png"))
        for page in [1, 2, 3] {
            MockRunner.write(TVHomeScreen(page: page, snap: snap), scale: 3, to: dir.appendingPathComponent("home-\(page).png"))
        }
        MockRunner.write(TVHomeScreen(page: 1, snap: Mock.night), scale: 3, to: dir.appendingPathComponent("home-1-night.png"))
        let widgets: [(String, Family, AnyView)] = [
            ("hero-large", .large, AnyView(TVHero(snap: snap, quote: TVQuotes.hero))),
            ("sun-arc-small", .small, AnyView(TVSunArc(snap: snap))),
            ("quote-small", .small, AnyView(TVQuoteTile(quote: TVQuotes.tile))),
            ("forecast-small", .small, AnyView(TVForecastTile(snap: snap))),
            ("tonight-small", .small, AnyView(TVTonightTile(snap: snap))),
            ("picture-small", .small, AnyView(TVPictureTile(snap: snap, quote: TVQuotes.picture))),
            ("today-small", .small, AnyView(TVTodaySmall(snap: snap))),
            ("today-medium", .medium, AnyView(TVTodayMedium(snap: snap))),
            ("sun-arc-medium", .medium, AnyView(TVSunArcMedium(snap: snap))),
            ("picture-medium", .medium, AnyView(TVPictureMedium(snap: snap, quote: TVQuotes.picture))),
        ]
        MockRunner.write(TVIconSheet(snap: snap), scale: 3, to: dir.appendingPathComponent("icons.png"))
        for (name, family, view) in widgets {
            MockRunner.write(WidgetTile(family: family) { view }, scale: 3, to: dir.appendingPathComponent("\(name).png"))
        }
        // Rococo: the three pages again on the other two paintings the user sent, to compare with The Bathing Pool.
        if TVStyle.rococo {
            for (wallpaper, sub) in [("wallpaper-swing", "swing"), ("wallpaper-flowers", "flowers")] {
                TVStyle.wallpaper = wallpaper
                let d = dir.appendingPathComponent(sub, isDirectory: true)
                try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
                for page in [1, 2, 3] {
                    MockRunner.write(TVHomeScreen(page: page, snap: snap), scale: 3, to: d.appendingPathComponent("home-\(page).png"))
                }
            }
            TVStyle.wallpaper = "wallpaper"
        }
        print("Rendered Baroque in \(TVStyle.folder) to \(dir.path)")
        return true
    }
}
