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

enum RococoInk {
    static let ink = Color(hex: 0x3A2D23)
    static let inkSoft = Color(hex: 0x6B5B4C)
    static let inkFaint = Color(hex: 0x6E604E)
    static let cream = Color(hex: 0xF7F0E4)
    static let terracotta = Color(hex: 0x9C5B3D)
    static let shadow = Color(hex: 0x2B1F15)
    /// The limestone's middle value: behind the stone while it loads, and round the edges on other phone sizes.
    static let stone = Color(hex: 0xB5A483)
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
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
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

/// The user's repainted photographs taking turns (2026-11-08): a new one every three hours on the clock (midnight,
/// 3, 6 …), on the large Day widget and, never the same one at once, on the Photograph widget. The images are
/// RococoPhoto-<name> (696 x 730) and RococoPhoto-<name>-small (328 x 328), cut by scripts/export_rococo_textures.py.
enum RococoPhotos {
    static let hours = 3
    /// All of them, for the Photograph widget, which has no words on it.
    static let all = ["kings-canyon", "valley", "river", "dead-tree", "falls", "bryce", "arch", "zion", "sunset", "zion-canyon"]
    /// The large Day widget's: landscapes with no one where the quote sits (checked by eye, by day and by night, with
    /// MockLab's HEROES=1). The photographs of people (falls, zion, sunset, dead-tree) show only on the Photograph
    /// widget, with nothing over them.
    static let underWords = ["kings-canyon", "valley", "river", "bryce", "arch", "zion-canyon"]

    /// Which three-hour turn of the local day `date` falls in, counted from 1970 so it keeps moving across days.
    static func turn(_ date: Date) -> Int {
        let local = date.timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT(for: date))
        return Int(floor(local / Double(hours * 3600)))
    }

    /// When the next turn begins.
    static func nextChange(after date: Date) -> Date {
        let offset = Double(TimeZone.current.secondsFromGMT(for: date))
        return Date(timeIntervalSince1970: Double(turn(date) + 1) * Double(hours * 3600) - offset)
    }

    static func largeName(at date: Date) -> String { underWords[turn(date) % underWords.count] }

    static func large(at date: Date) -> String { "RococoPhoto-" + largeName(at: date) }

    /// Half the list on from the large one, and never the same photograph.
    static func small(at date: Date) -> String {
        var name = all[(turn(date) + all.count / 2) % all.count]
        if name == largeName(at: date) { name = all[(all.firstIndex(of: name)! + 1) % all.count] }
        return "RococoPhoto-" + name + "-small"
    }
}

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

// MARK: - Words

enum RococoWords {
    static func month(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }

    static func day(_ date: Date) -> String { String(Calendar.current.component(.day, from: date)) }

    /// "4:58": a twelve-hour clock whatever the system setting.
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    static func temp(_ w: WeatherSnapshot?) -> String {
        guard let w else { return "—" }
        return "\(Int(w.temperature.rounded()))°"
    }

    static func more(_ n: Int) -> String { "+ \(n) more" }

    /// A task's due note against the snapshot's day: "2d late", "today", "tomorrow", otherwise "the 9th" (no weekday
    /// names). Nil when undated.
    static func due(_ task: TaskItem, now: Date) -> String? {
        guard let due = task.due else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: due)).day ?? 0
        switch days {
        case ..<0: return "\(-days)d late"
        case 0: return "today"
        default: return dayName(due, from: now)
        }
    }

    /// Today's sunrise or sunset moved onto the snapshot's day.
    static func today(_ d: Date, at now: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: cal.component(.hour, from: d), minute: cal.component(.minute, from: d), second: 0, of: now) ?? d
    }

    /// "10 h 44 m": sunrise to sunset.
    static func daylight(_ snap: DaySnapshot) -> String? {
        guard let w = snap.weather, let rise = w.sunrise, let set = w.sunset else { return nil }
        let m = max(0, Int((today(set, at: snap.date).timeIntervalSince(today(rise, at: snap.date)) / 60).rounded()))
        return m >= 60 ? "\(m / 60) h \(m % 60) m" : "\(m) m"
    }

    /// "tomorrow", then "the 6th", "the 7th": no weekday names.
    static func dayName(_ date: Date, from now: Date) -> String {
        let cal = Calendar.current
        let offset = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        if offset == 1 { return "tomorrow" }
        let n = cal.component(.day, from: date)
        let suffix: String
        switch (n % 10, n % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "the \(n)\(suffix)"
    }

    /// Whether a line is short enough to set in script (Savoye only reads at a large size).
    static func fitsScript(_ text: String) -> Bool {
        text.count <= 26 && text.split(separator: " ").count <= 5
    }
}
