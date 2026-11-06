import SwiftUI

// Gilt Frame: the palette, type, geometry and materials (wall, gilt frame, brass plate, studs). Pure SwiftUI; the
// paint lives in MockLab/Textures/weather-gilt-frame (make.py), loaded with Mock.texture here and from the asset
// catalog in the app.

/// Oxblood, gold leaf, brass and the painting's sepia. Engraved type is black wax on brass (about 7:1 on the
/// brushed brass), and card type is iron-gall ink on ivory (about 12:1).
enum GFInk {
    static let wall = Color(hex: 0x3C0E14)        // the damask wall's shadow, behind everything
    static let wallDeep = Color(hex: 0x1E0609)
    static let engraved = Color(hex: 0x23160A)    // black wax filling the engraving
    static let engravedSoft = Color(hex: 0x4A3418)
    static let lip = Color(hex: 0xFFF1C9)         // the lit lower lip of each cut
    static let ink = Color(hex: 0x2A1E14)         // ink on the card
    static let inkSoft = Color(hex: 0x6A5640)
    static let oxblood = Color(hex: 0x7A1C22)     // late, on the card
    static let shadow = Color(hex: 0x0A0304)
    static let lamp = Color(hex: 0xFFD8A0)        // the picture light
}

/// Copperplate is the engraver's own capital; Didot for the numeral; Baskerville for words.
enum GFType {
    static func caps(_ size: CGFloat) -> Font { .custom("Copperplate", size: size) }
    static func capsLight(_ size: CGFloat) -> Font { .custom("Copperplate-Light", size: size) }
    static func numeral(_ size: CGFloat) -> Font { .custom("Didot", size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", size: size) }
    static func serif(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
}

/// Where everything hangs, in points (mirrors FRAMES and PAINTINGS in make.py). The sight is the frame's opening.
enum GFGeometry {
    struct Frame {
        var texture: String
        var rect: CGRect
        var moulding: CGFloat
        var sight: CGRect { rect.insetBy(dx: moulding, dy: moulding) }
    }

    static func frame(_ family: Family) -> Frame {
        switch family {
        case .large: return Frame(texture: "frame-large", rect: CGRect(x: 44, y: 14, width: 260, height: 250), moulding: 30)
        case .medium: return Frame(texture: "frame-medium", rect: CGRect(x: 14, y: 12, width: 176, height: 140), moulding: 22)
        case .small: return Frame(texture: "frame-small", rect: CGRect(x: 14, y: 10, width: 136, height: 132), moulding: 17)
        }
    }

    static func card(_ family: Family) -> Frame {
        switch family {
        case .small: return Frame(texture: "card-small", rect: CGRect(x: 10, y: 10, width: 144, height: 144), moulding: 13)
        default: return Frame(texture: "card-medium", rect: CGRect(x: 10, y: 10, width: 328, height: 144), moulding: 13)
        }
    }

    /// The painting's lake edge (fraction of its height) and the arc its sun and moon travel (fractions of the
    /// painting): rising from behind the left ridges, over the summit at noon, setting behind the shoulder.
    static func water(_ family: Family) -> CGFloat {
        switch family {
        case .large: return 0.64
        case .medium: return 0.68
        case .small: return 0.67
        }
    }

    static func arc(_ family: Family) -> SkyArc {
        switch family {
        case .large: return SkyArc(centerX: 0.47, horizon: 0.6, radiusX: 0.4, radiusY: 0.53)
        case .medium: return SkyArc(centerX: 0.48, horizon: 0.64, radiusX: 0.4, radiusY: 0.56)
        case .small: return SkyArc(centerX: 0.48, horizon: 0.63, radiusX: 0.38, radiusY: 0.55)
        }
    }
}

// MARK: - The wall

/// Oxblood silk damask under a picture light: a warm pool where the light falls (over the frame), falling off to
/// the shadowed corners; dimmer after dark.
struct GFWall: View {
    var size: CGSize
    var focus: UnitPoint
    var night: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            GFInk.wall
            Mock.texture("weather-gilt-frame/wall")
                .resizable()
                .interpolation(.high)
                .frame(width: 348, height: 365)
            RadialGradient(colors: [GFInk.lamp.opacity(night ? 0.16 : 0.2), GFInk.lamp.opacity(0.05), .clear],
                           center: focus, startRadius: 0, endRadius: max(size.width, size.height) * 0.8)
                .blendMode(.screen)
                .frame(width: size.width, height: size.height)
            RadialGradient(colors: [.clear, GFInk.shadow.opacity(night ? 0.6 : 0.5)], center: focus,
                           startRadius: min(size.width, size.height) * 0.35, endRadius: max(size.width, size.height) * 0.95)
                .frame(width: size.width, height: size.height)
            if night {
                GFInk.shadow.opacity(0.22).frame(width: size.width, height: size.height)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
    }
}

// MARK: - The frame

/// A frame texture's shadows on the wall: a soft cast shadow down and to the right (the picture light is above and to
/// the left) and a tight contact shadow where the frame stands off the wall.
struct GFFrameShadow: View {
    var texture: String

    var body: some View {
        let img = Mock.texture("weather-gilt-frame/\(texture)")
        ZStack {
            img.resizable().renderingMode(.template).foregroundStyle(GFInk.shadow)
                .blur(radius: 7).offset(x: 3, y: 9).opacity(0.7)
            img.resizable().renderingMode(.template).foregroundStyle(GFInk.shadow)
                .blur(radius: 1.6).offset(x: 0.8, y: 2.2).opacity(0.55)
        }
    }
}

/// The gilt itself, and the shade its rails throw into the sight (the painting sits a little behind the slip).
struct GFFrameGilt: View {
    var frame: GFGeometry.Frame
    var dim: Double = 1

    var body: some View {
        let img = Mock.texture("weather-gilt-frame/\(frame.texture)")
        ZStack(alignment: .topLeading) {
            // The rebate's shade on the painting: deepest under the top rail, a little on the left.
            img.resizable().renderingMode(.template).foregroundStyle(GFInk.shadow)
                .blur(radius: 2.4).offset(x: 1.2, y: 3).opacity(0.55)
                .mask {
                    Rectangle().frame(width: frame.sight.width, height: frame.sight.height)
                        .offset(x: frame.sight.minX, y: frame.sight.minY)
                }
            img.resizable().interpolation(.high)
            if dim < 1 {
                img.resizable().renderingMode(.template).foregroundStyle(GFInk.shadow.opacity(1 - dim))
            }
        }
    }
}

// MARK: - The brass plate

/// An engraved brass museum plate: brushed brass with a bevelled edge lit from above, two screws, standing a little off
/// the wall. The content is set in engraved type (`.gfEngraved()`).
struct GFPlaque<Content: View>: View {
    var size: CGSize
    var screws = true
    var dim: Double = 1
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 2.5, style: .continuous)
        ZStack {
            Mock.texture("weather-gilt-frame/brass")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
            // Sheen: the picture light along the top, a duller lower half.
            LinearGradient(stops: [.init(color: Color(hex: 0xFFF4D0).opacity(0.32), location: 0),
                                   .init(color: .clear, location: 0.42),
                                   .init(color: GFInk.shadow.opacity(0.16), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [Color(hex: 0xFFF4D0).opacity(0.12), .clear, Color(hex: 0xFFF4D0).opacity(0.08), .clear],
                           startPoint: UnitPoint(x: 0, y: 0.2), endPoint: UnitPoint(x: 1, y: 0.8))
            if screws {
                HStack {
                    GFScrew(angle: 30)
                    Spacer()
                    GFScrew(angle: -55)
                }
                .padding(.horizontal, 5.5)
            }
            content
            if dim < 1 { GFInk.shadow.opacity(1 - dim) }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay {
            // The bevel: lit along the top and left, shaded along the bottom and right, with a dark cut edge.
            ZStack {
                shape.strokeBorder(LinearGradient(colors: [Color(hex: 0xFFF3CF).opacity(0.95), Color(hex: 0xC9A35A).opacity(0.2),
                                                           Color(hex: 0x4A3214).opacity(0.85)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.6)
                shape.inset(by: 1.6).strokeBorder(GFInk.shadow.opacity(0.28), lineWidth: 0.5)
                shape.strokeBorder(GFInk.shadow.opacity(0.65), lineWidth: 0.4)
            }
        }
        .background {
            shape.fill(GFInk.shadow).blur(radius: 2.5).offset(x: 1, y: 3).opacity(0.65)
        }
    }
}

/// A slotted brass screw head, domed, its slot turned at random.
struct GFScrew: View {
    var angle: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFBEBC0), Color(hex: 0xC59D52), Color(hex: 0x5C4018)],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 3.4))
            Capsule()
                .fill(GFInk.engraved.opacity(0.85))
                .frame(width: 4.2, height: 0.7)
                .rotationEffect(.degrees(angle))
            Circle().strokeBorder(GFInk.shadow.opacity(0.5), lineWidth: 0.35)
        }
        .frame(width: 4.6, height: 4.6)
        .shadow(color: Color(hex: 0xFFF1C9).opacity(0.5), radius: 0, x: 0, y: 0.5)
    }
}

/// A domed brass stud (the to-do card's checkbox), or an oxblood enamel one when the task is late.
struct GFStud: View {
    var late: Bool = false
    var diameter: CGFloat = 8

    var body: some View {
        let colors: [Color] = late
            ? [Color(hex: 0xF0B3A0), Color(hex: 0x9C2A2C), Color(hex: 0x3A0A0E)]
            : [Color(hex: 0xFFF2CA), Color(hex: 0xCFA757), Color(hex: 0x5E4119)]
        ZStack {
            Circle()
                .fill(RadialGradient(colors: colors, center: UnitPoint(x: 0.36, y: 0.3), startRadius: 0,
                                     endRadius: diameter * 0.72))
            if late {
                // The enamel sits in a brass bezel.
                Circle().strokeBorder(LinearGradient(colors: [Color(hex: 0xF4DC98), Color(hex: 0x7A5822)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1.1)
            }
            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: diameter * 0.24, height: diameter * 0.18)
                .offset(x: -diameter * 0.17, y: -diameter * 0.2)
                .blur(radius: 0.3)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: GFInk.shadow.opacity(0.55), radius: 0.8, x: 0.4, y: 1)
    }
}

// MARK: - Engraving

extension View {
    /// Letters cut into brass and filled with black wax: the wax, and the lit lower lip of each cut.
    func gfEngraved(_ color: Color = GFInk.engraved) -> some View {
        self.foregroundStyle(color)
            .shadow(color: GFInk.lip.opacity(0.6), radius: 0, x: 0, y: 0.6)
    }

    /// Type printed on the ivory card: ink, very slightly spread into the paper.
    func gfInked(_ color: Color = GFInk.ink) -> some View {
        self.foregroundStyle(color)
            .shadow(color: color.opacity(0.18), radius: 0.3, x: 0, y: 0)
    }
}

/// A rule cut into the brass (or printed on the card): a dark line with its lit lip below.
struct GFRule: View {
    var vertical = false
    var color: Color = GFInk.engraved
    var lip: Color = GFInk.lip

    var body: some View {
        if vertical {
            HStack(spacing: 0) {
                color.opacity(0.8).frame(width: 0.6)
                lip.opacity(0.55).frame(width: 0.5)
            }
        } else {
            VStack(spacing: 0) {
                color.opacity(0.8).frame(height: 0.6)
                lip.opacity(0.55).frame(height: 0.5)
            }
        }
    }
}

// MARK: - Words

enum GFWords {
    static func month(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM"
        return f.string(from: date).uppercased()
    }

    static func shortMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f.string(from: date).uppercased()
    }

    static func day(_ date: Date) -> String { String(Calendar.current.component(.day, from: date)) }

    static func clock(_ date: Date?) -> String {
        guard let date else { return "--" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    static func temp(_ w: WeatherSnapshot?) -> String {
        guard let w else { return "--°" }
        return "\(Int(w.temperature.rounded()))°"
    }

    static func degrees(_ v: Double) -> String { "\(Int(v.rounded()))" }

    /// True while the sun is up: the next event is the sunset, otherwise the sunrise.
    static func sunUp(_ w: WeatherSnapshot?, now: Date) -> Bool {
        SkyClock(now: now, weather: w).isDay
    }
}
