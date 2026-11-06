import SwiftUI

// Old Master Folio: the widget is an antique book lying open on dark velvet, seen from above. The book's own design
// does the layout: a tipped-in oil-painting plate with its plate-mark and caption, a running head, a dropped initial,
// verse-numbered lines with marginal notes, a catchword, folios along the foot, a footnote for anything that went
// wrong. Old Master's palette carries over: the paper is warm and toned, the ink an umber brown-black, and the peach
// accent is deepened into the red-brown of rubrication so it reads on paper.

// MARK: - Ink and type

/// Ink on the aged paper (about #C9A77A where the light falls, #B39269 in the lower page). Contrast across the
/// text areas: ink 6.0-7.8:1, inkSoft 4.7-6.0:1, inkFaint 4.2-5.5:1, rubric 4.0-5.1:1 (initials are larger still).
enum OFInk {
    static let ink = Color(hex: 0x24160D)        // the text
    static let inkSoft = Color(hex: 0x3E2A1C)    // captions, the opening sentence, the attribution
    static let inkFaint = Color(hex: 0x46301F)   // verse numbers, folios, running heads
    static let rubric = Color(hex: 0x64260F)     // Old Master's peach, deepened into rubric: late, today
    static let initial = Color(hex: 0x7A3216)    // the dropped initials: the same red, a shade brighter at size
    static let paperLit = Color(hex: 0xEAD3AE)   // the lit lip of the plate-mark
    static let shadow = Color(hex: 0x1A0E07)
}

/// Baskerville for the text and Hoefler Text for figures (its numerals are old-style, as a book's are). Both ship
/// on iOS 17. Small capitals are set by hand (capitals, and the lowercase as capitals at three quarters' size),
/// since the fonts' own small caps aren't reachable from SwiftUI on every system.
enum OFType {
    static func serif(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", size: size) }
    /// Old-style figures: verse numbers, folios.
    static func figures(_ size: CGFloat) -> Font { .custom("Hoefler Text", size: size) }

    /// "Henry David Thoreau, Walden" in small capitals: G, O and the figures full size, the rest reduced.
    static func smallCaps(_ string: String, size: CGFloat) -> Text {
        var out = Text("")
        var run = ""
        var reduced = false
        func flush() {
            guard !run.isEmpty else { return }
            out = out + Text(run).font(.custom("Baskerville", size: reduced ? size * 0.76 : size))
            run = ""
        }
        for ch in string {
            let lower = ch.isLowercase
            if lower != reduced { flush(); reduced = lower }
            run += lower ? ch.uppercased() : String(ch)
        }
        flush()
        return out
    }
}

extension Text {
    /// Letterspaced small capitals: running heads, captions.
    static func ofCaps(_ string: String, _ size: CGFloat, _ color: Color = OFInk.inkSoft, tracking: CGFloat = 1.2) -> Text {
        OFType.smallCaps(string, size: size).tracking(tracking).foregroundColor(color)
    }
}

extension View {
    /// Places a view by its top-left corner in the widget, at a fixed size.
    func ofAt(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, alignment: Alignment = .topLeading) -> some View {
        frame(width: w, height: h, alignment: alignment).offset(x: x, y: y)
    }
}

// MARK: - The book

/// The bindings (textures painted in make.py at the widget's size): page edges, spine and margins in points.
enum OFBinding: String {
    case spreadLarge = "spread-large", spreadMedium = "spread-medium", pageMedium = "page-medium", pageSmall = "page-small"

    var texture: Image { Mock.texture("old-master-folio/\(rawValue)") }
}

/// The light in the room, falling across the pages: plain daylight from the upper left, a warm low light at dusk,
/// lamplight at night (the corners sink into shadow), and a cooler, dimmer grey under rain and snow.
struct OFRoomLight {
    var wash: Color
    var washAmount: Double
    var pool: UnitPoint
    var dim: Double
    var glow: Color
    var glowAmount: Double

    init(clock: SkyClock, condition: SkyCondition) {
        if clock.isDay {
            wash = Color(hex: 0xF0B57E)
            washAmount = 0.28 * clock.twilight
            pool = UnitPoint(x: 0.3 + 0.5 * clock.progress, y: 0.22)
            dim = 0.14 + 0.1 * clock.twilight
            glow = Color(hex: 0xFFE2B8)
            glowAmount = 0.05 + 0.05 * clock.twilight
        } else {
            wash = Color(hex: 0xD49A63)
            washAmount = 0.34
            pool = UnitPoint(x: 0.58, y: 0.42)
            dim = 0.5
            glow = Color(hex: 0xFFC983)
            glowAmount = 0.1
        }
        if condition.gray {
            wash = clock.isDay ? Color(hex: 0xC8C2BA) : Color(hex: 0xB89070)
            washAmount = clock.isDay ? 0.3 : 0.36
            dim += 0.06
            glowAmount *= 0.4
        }
    }
}

/// The open book: the binding, what is set on it, then the light of the room over everything.
struct OFBook<Content: View>: View {
    var binding: OFBinding
    var light: OFRoomLight
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            binding.texture
                .resizable()
                .interpolation(.high)
            content
            OFRoomLightOverlay(light: light)
        }
    }
}

struct OFRoomLightOverlay: View {
    var light: OFRoomLight

    var body: some View {
        ZStack {
            light.wash.opacity(light.washAmount).blendMode(.multiply)
            GeometryReader { geo in
                let span = max(geo.size.width, geo.size.height)
                RadialGradient(colors: [.white, .white, Color(hex: 0x6E5844)],
                               center: light.pool, startRadius: 0, endRadius: span * 1.05)
                    .opacity(light.dim * 2.2)
                    .blendMode(.multiply)
                RadialGradient(colors: [light.glow.opacity(light.glowAmount), .clear],
                               center: light.pool, startRadius: 0, endRadius: span * 0.6)
                    .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - The plate

/// A tipped-in plate: the painting with a fine edge, lifted a hair off the page, inside the plate-mark (the
/// rectangle the press pushed into the paper, shadowed on its top and left walls and lit on the others).
struct OFPlateFrame<Painting: View>: View {
    var mark: CGFloat = 4.5
    @ViewBuilder var painting: Painting

    var body: some View {
        painting
            .overlay(Rectangle().strokeBorder(OFInk.shadow.opacity(0.5), lineWidth: 0.6))
            .background {
                Rectangle()
                    .fill(OFInk.shadow)
                    .shadow(color: OFInk.shadow.opacity(0.45), radius: 1.6, x: 0.6, y: 1.1)
            }
            .background {
                GeometryReader { geo in
                    let r = CGRect(origin: .zero, size: geo.size).insetBy(dx: -mark, dy: -mark)
                    ZStack {
                        // The pressed paper inside the mark is a touch smoother and lighter.
                        Rectangle().fill(OFInk.paperLit.opacity(0.07))
                            .frame(width: r.width, height: r.height)
                            .position(x: r.midX, y: r.midY)
                        Path { p in
                            p.move(to: CGPoint(x: r.minX, y: r.maxY))
                            p.addLine(to: CGPoint(x: r.minX, y: r.minY))
                            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
                        }
                        .stroke(OFInk.shadow.opacity(0.32), lineWidth: 0.7)
                        Path { p in
                            p.move(to: CGPoint(x: r.minX + 0.7, y: r.maxY - 0.1))
                            p.addLine(to: CGPoint(x: r.maxX - 0.1, y: r.maxY - 0.1))
                            p.addLine(to: CGPoint(x: r.maxX - 0.1, y: r.minY + 0.7))
                        }
                        .stroke(OFInk.paperLit.opacity(0.55), lineWidth: 0.7)
                        Path { p in
                            p.move(to: CGPoint(x: r.minX + 0.75, y: r.maxY - 0.6))
                            p.addLine(to: CGPoint(x: r.minX + 0.75, y: r.minY + 0.75))
                            p.addLine(to: CGPoint(x: r.maxX - 0.6, y: r.minY + 0.75))
                        }
                        .stroke(OFInk.paperLit.opacity(0.3), lineWidth: 0.5)
                    }
                }
            }
    }
}

// MARK: - The turned corner (next quote)

/// The page's lower outer corner turned up: the back of the leaf folded over, and the next leaf showing beneath in
/// its shadow. A small arrow on the fold says what it does. Drawn in a square whose bottom-right is the page corner.
struct OFTurnedCorner: View {
    var leg: CGFloat = 26
    var radius: CGFloat = 6   // the page's own corner rounding

    var body: some View {
        let a = CGPoint(x: 0, y: leg), b = CGPoint(x: leg, y: 0), tip = CGPoint(x: 1.5, y: 1.5)
        ZStack(alignment: .topLeading) {
            // The next leaf, where the corner was, in the shadow of the fold.
            Path { p in
                p.move(to: a)
                p.addLine(to: CGPoint(x: leg - radius, y: leg))
                p.addQuadCurve(to: CGPoint(x: leg, y: leg - radius), control: CGPoint(x: leg, y: leg))
                p.addLine(to: b)
                p.closeSubpath()
            }
            .fill(ImagePaint(image: Mock.texture("old-master-folio/leaf"), scale: 1))
            .overlay {
                LinearGradient(colors: [OFInk.shadow.opacity(0.55), OFInk.shadow.opacity(0.18)],
                               startPoint: UnitPoint(x: 0.5, y: 0.5), endPoint: .bottomTrailing)
                    .clipShape(Path { p in
                        p.move(to: a); p.addLine(to: CGPoint(x: leg, y: leg)); p.addLine(to: b); p.closeSubpath()
                    })
            }
            // The flap: the back of the page, curling a little along its edges.
            let flap = Path { p in
                p.move(to: a)
                p.addQuadCurve(to: tip, control: CGPoint(x: -1.2, y: leg * 0.45))
                p.addQuadCurve(to: b, control: CGPoint(x: leg * 0.45, y: -1.2))
                p.closeSubpath()
            }
            flap
                .fill(ImagePaint(image: Mock.texture("old-master-folio/leaf"), scale: 1))
                .overlay {
                    LinearGradient(stops: [.init(color: Color.white.opacity(0.16), location: 0),
                                           .init(color: .clear, location: 0.55),
                                           .init(color: OFInk.shadow.opacity(0.22), location: 1)],
                                   startPoint: .topLeading, endPoint: UnitPoint(x: 0.5, y: 0.5))
                        .clipShape(flap)
                }
                .shadow(color: OFInk.shadow.opacity(0.45), radius: 1.4, x: 0.8, y: 1.0)
            flap.stroke(OFInk.shadow.opacity(0.28), lineWidth: 0.5)
            Image(systemName: "arrow.right")
                .font(.system(size: leg * 0.3, weight: .semibold))
                .foregroundStyle(OFInk.rubric.opacity(0.85))
                .position(x: leg * 0.37, y: leg * 0.4)
        }
        .frame(width: leg, height: leg, alignment: .topLeading)
        .contentShape(Rectangle())
        .accessibilityLabel("Next quote")
    }
}

// MARK: - Words

enum OFWords {
    /// "seven"
    static func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }

    /// 3 -> "III"
    static func roman(_ value: Int) -> String {
        var n = max(1, value)
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                      (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var out = ""
        for (v, s) in table { while n >= v { out += s; n -= v } }
        return out
    }

    /// The plate's title for the hour: "the peaks at morning", "by moonlight"...
    static func hour(_ clock: SkyClock, now: Date) -> String {
        if !clock.isDay { return clock.twilight > 0.3 ? "The peaks at nightfall" : "The peaks by moonlight" }
        if clock.twilight > 0.3 { return clock.progress < 0.5 ? "The peaks at sunrise" : "The peaks at evening" }
        let h = Calendar.current.component(.hour, from: now)
        if h < 11 { return "The peaks at morning" }
        if h < 14 { return "The peaks at noon" }
        return "The peaks in the afternoon"
    }

    static func temp(_ w: WeatherSnapshot?) -> String {
        guard let w else { return "—" }
        return "\(Int(w.temperature.rounded()))°"
    }
}
