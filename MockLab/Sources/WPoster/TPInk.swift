import SwiftUI

// The poster's inks. One vintage-print set (vermilion, deep teal, cream, slate, alpine green) pulled three ways: by
// day, at dusk (an apricot and rose sky, alpenglow on the faces) and by night (a deep blue print with a cream moon);
// grey weather mutes the sky and the land toward slate.

struct TPRGB {
    var r: Double, g: Double, b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    func mix(_ o: TPRGB, _ t: Double) -> TPRGB {
        let t = min(1, max(0, t))
        return TPRGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }

    /// Toward a grey of the same lightness, tinted slate.
    func muted(_ t: Double, darker: Double = 0) -> TPRGB {
        let l = 0.3 * r + 0.59 * g + 0.11 * b
        let slate = TPRGB(r: l * 0.92, g: l * 1.0, b: l * 1.06)
        let m = mix(slate, t)
        return TPRGB(r: m.r * (1 - darker), g: m.g * (1 - darker), b: m.b * (1 - darker))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
}

struct TPInks {
    var sky: [TPRGB]       // five bands, top to horizon
    var disc: TPRGB        // the sun (or the moon at night)
    var discShade: TPRGB   // the halftone screen on the disc
    var east: TPRGB        // the lit east face
    var north: TPRGB       // the north face's snow
    var band: TPRGB        // the dark band and the Hornli ridge
    var shade: TPRGB       // the shadowed left face
    var rock: TPRGB        // streaks on the lit faces
    var ledge: TPRGB       // snow on the shadowed face
    var crest: TPRGB       // the lit rim of the summit ridge
    var ridge: TPRGB       // the lower ridges
    var ridgeShade: TPRGB
    var ridgeSnow: TPRGB
    var meadow: TPRGB      // the near hill
    var field: TPRGB       // the nearest hill, which carries the type
    var forest: TPRGB      // spruce
    var cloud: TPRGB
    var cloudShade: TPRGB
    var weather: TPRGB     // rain lines and snow dots
    var paper: TPRGB       // the unprinted stock (also the caption band)
    var title: TPRGB       // cream letterpress on the dark inks
    var register: TPRGB    // the second colour the title is printed in, a little out of register
    var caption: TPRGB     // the ink on the caption band
    var accent: TPRGB      // vermilion details
    var isNight: Bool

    static let paperStock = TPRGB(0xEEE3CA)

    static let day = TPInks(
        sky: [TPRGB(0x1B4555), TPRGB(0x225869), TPRGB(0x2F6C79), TPRGB(0x568C8C), TPRGB(0xA6C2B0)],
        disc: TPRGB(0xD9462A), discShade: TPRGB(0xA92E1E),
        east: TPRGB(0xF0E3C6), north: TPRGB(0xCFDAD2), band: TPRGB(0x5D7684), shade: TPRGB(0x2F4B59),
        rock: TPRGB(0x3E5866), ledge: TPRGB(0x7E9DA3), crest: TPRGB(0xF6EBD2),
        ridge: TPRGB(0x3C6470), ridgeShade: TPRGB(0x2B4C58), ridgeSnow: TPRGB(0xE1E4D6),
        meadow: TPRGB(0x5F8B52), field: TPRGB(0x2C5241), forest: TPRGB(0x1D3A33),
        cloud: TPRGB(0xF1E7CF), cloudShade: TPRGB(0xB9C9C0), weather: TPRGB(0xE9E2CD),
        paper: paperStock, title: TPRGB(0xF4E9CF), register: TPRGB(0xD9462A), caption: TPRGB(0x1D4152),
        accent: TPRGB(0xD9462A), isNight: false)

    static let dusk = TPInks(
        sky: [TPRGB(0x1D3B55), TPRGB(0x3A4C6A), TPRGB(0x85596A), TPRGB(0xD27E62), TPRGB(0xF1B585)],
        disc: TPRGB(0xC8361E), discShade: TPRGB(0x962415),
        east: TPRGB(0xF2BC9C), north: TPRGB(0xD7A596), band: TPRGB(0x765D6C), shade: TPRGB(0x37405A),
        rock: TPRGB(0x6C5464), ledge: TPRGB(0x7E7790), crest: TPRGB(0xF8D2B4),
        ridge: TPRGB(0x47506A), ridgeShade: TPRGB(0x353B55), ridgeSnow: TPRGB(0xE7B9A2),
        meadow: TPRGB(0x4C6150), field: TPRGB(0x263A35), forest: TPRGB(0x1A2A2D),
        cloud: TPRGB(0xF4C9A8), cloudShade: TPRGB(0xB98A8A), weather: TPRGB(0xF1D9C2),
        paper: paperStock, title: TPRGB(0xF6E8CE), register: TPRGB(0xC8361E), caption: TPRGB(0x2A2D46),
        accent: TPRGB(0xC8361E), isNight: false)

    static let night = TPInks(
        sky: [TPRGB(0x0C1730), TPRGB(0x111F3E), TPRGB(0x182B4E), TPRGB(0x223A60), TPRGB(0x324F74)],
        disc: TPRGB(0xF1E5C3), discShade: TPRGB(0xC9C0A6),
        east: TPRGB(0x8DA2BA), north: TPRGB(0x7189A6), band: TPRGB(0x34486A), shade: TPRGB(0x1B2945),
        rock: TPRGB(0x3A4E6E), ledge: TPRGB(0x4B6288), crest: TPRGB(0xC9D3DE),
        ridge: TPRGB(0x1E3150), ridgeShade: TPRGB(0x172640), ridgeSnow: TPRGB(0x7D90AA),
        meadow: TPRGB(0x182C3B), field: TPRGB(0x0F1C29), forest: TPRGB(0x0A141F),
        cloud: TPRGB(0x3E5274), cloudShade: TPRGB(0x2A3A58), weather: TPRGB(0xB9C3D2),
        paper: TPRGB(0xD9CFB5), title: TPRGB(0xF1E5C3), register: TPRGB(0xB8402A), caption: TPRGB(0x14233F),
        accent: TPRGB(0xC24A30), isNight: true)

    func mix(_ o: TPInks, _ t: Double) -> TPInks {
        TPInks(sky: zip(sky, o.sky).map { $0.mix($1, t) }, disc: disc.mix(o.disc, t), discShade: discShade.mix(o.discShade, t),
               east: east.mix(o.east, t), north: north.mix(o.north, t), band: band.mix(o.band, t), shade: shade.mix(o.shade, t),
               rock: rock.mix(o.rock, t), ledge: ledge.mix(o.ledge, t), crest: crest.mix(o.crest, t),
               ridge: ridge.mix(o.ridge, t), ridgeShade: ridgeShade.mix(o.ridgeShade, t), ridgeSnow: ridgeSnow.mix(o.ridgeSnow, t),
               meadow: meadow.mix(o.meadow, t), field: field.mix(o.field, t), forest: forest.mix(o.forest, t),
               cloud: cloud.mix(o.cloud, t), cloudShade: cloudShade.mix(o.cloudShade, t), weather: weather.mix(o.weather, t),
               paper: paper.mix(o.paper, t), title: title.mix(o.title, t), register: register.mix(o.register, t),
               caption: caption.mix(o.caption, t), accent: accent.mix(o.accent, t), isNight: t < 0.5 ? isNight : o.isNight)
    }

    /// The inks for a moment and its weather.
    init(clock: SkyClock, condition: SkyCondition) {
        var base: TPInks
        if clock.isDay {
            base = TPInks.day.mix(.dusk, clock.twilight)
        } else {
            base = TPInks.night.mix(.dusk, clock.twilight * 0.55)
            base.isNight = true
        }
        let grey: Double
        switch condition {
        case .clear: grey = 0
        case .partly: grey = 0.12
        case .overcast, .fog: grey = 0.55
        case .rain: grey = 0.62
        case .storm: grey = 0.7
        case .snow: grey = 0.5
        }
        if grey > 0 {
            let darker = condition == .storm ? 0.18 : (condition == .rain ? 0.06 : 0)
            base.sky = base.sky.map { $0.muted(grey, darker: darker) }
            if condition == .snow || condition == .fog {
                // A pale, high-key print: the sky lifts toward the paper.
                let lift = base.isNight ? 0.12 : 0.3
                base.sky = base.sky.enumerated().map { i, c in c.mix(TPInks.paperStock.muted(0.5), lift * (0.6 + 0.1 * Double(i))) }
            }
            for k in [\TPInks.east, \.north, \.band, \.shade, \.rock, \.ridge, \.ridgeShade, \.meadow, \.field, \.crest, \.ridgeSnow] as [WritableKeyPath<TPInks, TPRGB>] {
                base[keyPath: k] = base[keyPath: k].muted(grey * 0.55)
            }
            base.disc = base.disc.mix(base.sky[2], grey * 0.5)
            base.discShade = base.discShade.mix(base.sky[1], grey * 0.5)
        }
        if condition == .snow {
            base.meadow = base.meadow.mix(base.ridgeSnow, 0.55)
        }
        self = base
    }

    private init(sky: [TPRGB], disc: TPRGB, discShade: TPRGB, east: TPRGB, north: TPRGB, band: TPRGB, shade: TPRGB, rock: TPRGB,
                 ledge: TPRGB, crest: TPRGB, ridge: TPRGB, ridgeShade: TPRGB, ridgeSnow: TPRGB, meadow: TPRGB, field: TPRGB,
                 forest: TPRGB, cloud: TPRGB, cloudShade: TPRGB, weather: TPRGB, paper: TPRGB, title: TPRGB, register: TPRGB,
                 caption: TPRGB, accent: TPRGB, isNight: Bool) {
        self.sky = sky; self.disc = disc; self.discShade = discShade; self.east = east; self.north = north
        self.band = band; self.shade = shade; self.rock = rock; self.ledge = ledge; self.crest = crest
        self.ridge = ridge; self.ridgeShade = ridgeShade; self.ridgeSnow = ridgeSnow; self.meadow = meadow
        self.field = field; self.forest = forest; self.cloud = cloud; self.cloudShade = cloudShade
        self.weather = weather; self.paper = paper; self.title = title; self.register = register
        self.caption = caption; self.accent = accent; self.isNight = isNight
    }
}

/// Poster type: Futura, the Swiss travel-poster face (on every iPhone), in its condensed extra-bold for display.
enum TPType {
    static func display(_ size: CGFloat) -> Font { .custom("Futura-CondensedExtraBold", fixedSize: size) }
    static func label(_ size: CGFloat) -> Font { .custom("Futura-Medium", fixedSize: size) }
    static func bold(_ size: CGFloat) -> Font { .custom("Futura-Bold", fixedSize: size) }
    static func condensed(_ size: CGFloat) -> Font { .custom("Futura-CondensedMedium", fixedSize: size) }
}
