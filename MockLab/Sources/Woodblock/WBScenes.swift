import SwiftUI

// One composition per widget. Coordinates are points in that widget; ridges are placed around the text blocks.
enum WBScenes {
    static func p(_ pts: [(CGFloat, CGFloat)]) -> [CGPoint] { pts.map { CGPoint(x: $0.0, y: $0.1) } }

    // MARK: skies

    static func daySky(_ w: WBSky) -> [Gradient.Stop] {
        switch w {
        case .night:
            return [.init(color: WB.indigoDeep, location: 0), .init(color: WB.indigo, location: 0.45),
                    .init(color: WB.prussian, location: 0.8), .init(color: WB.prussianMid, location: 1)]
        case .cloudy, .fog, .rain, .storm, .snow:
            return [.init(color: Color(hex: 0x2B3446), location: 0), .init(color: Color(hex: 0x4D5B6E), location: 0.3),
                    .init(color: Color(hex: 0x8C9AA3), location: 0.62), .init(color: WB.washiDeep, location: 1)]
        default:
            return [.init(color: WB.indigoDeep, location: 0), .init(color: WB.indigo, location: 0.16),
                    .init(color: WB.prussian, location: 0.40), .init(color: WB.prussianMid, location: 0.60),
                    .init(color: WB.prussianPale, location: 0.80), .init(color: WB.washi, location: 1)]
        }
    }

    /// Quotes: a thin indigo band, then a pale dusk sky (for sumi text) warming toward the horizon.
    static let duskSky: [Gradient.Stop] = [
        .init(color: WB.indigoDeep, location: 0), .init(color: WB.prussian, location: 0.07),
        .init(color: WB.prussianPale, location: 0.15), .init(color: WB.celadon, location: 0.24),
        .init(color: WB.washi, location: 0.40), .init(color: WB.washi, location: 0.68),
        .init(color: WB.blush, location: 0.9), .init(color: WB.ochrePale, location: 1)
    ]

    static func clouds(_ w: WBSky, _ main: CloudSpec, extra: [CloudSpec] = []) -> [CloudSpec] {
        switch w {
        case .clear, .night: return []
        case .fewClouds: return [main]
        default: return [main] + extra
        }
    }

    // MARK: day

    static func dayLarge(_ w: WBSky) -> SceneSpec {
        SceneSpec(
            sky: daySky(w), skyTo: 205,
            ridges: [
                RidgeSpec(keys: p([(-10, 150), (24, 130), (58, 140), (92, 118), (124, 132), (150, 124), (204, 138),
                                   (246, 120), (278, 130), (318, 112), (360, 128)]),
                          top: WB.celadon, bottom: WB.washi, gradFrom: 112, gradTo: 172, rough: 0.06, seed: 11,
                          snow: 122, keyline: 0.6, grain: 1, misreg: CGSize(width: -0.5, height: 0.4)),
                RidgeSpec(keys: p([(-10, 176), (44, 154), (92, 140), (126, 120), (146, 100), (160, 88), (170, 94), (184, 76),
                                   (196, 92), (208, 100), (224, 118), (246, 132), (276, 116), (300, 106), (322, 122), (360, 142)]),
                          top: WB.prussian, bottom: WB.prussianPale, gradFrom: 82, gradTo: 172, rough: 0.07, seed: 21,
                          snow: 116, keyline: 0.95, grain: 0, gullies: 6),
                RidgeSpec(keys: p([(-10, 170), (30, 158), (74, 168), (120, 152), (166, 164), (214, 152), (258, 166),
                                   (300, 152), (360, 162)]),
                          top: WB.indigo, bottom: WB.pine, gradFrom: 150, gradTo: 200, rough: 0.08, seed: 31,
                          trees: [TreeSpec(from: -4, to: 352, spacing: 3.6...6.5, height: 6...11)],
                          keyline: 0.8, grain: 1, misreg: CGSize(width: 0.7, height: 0.3)),
                RidgeSpec(keys: p([(-10, 214), (60, 206), (140, 216), (220, 204), (300, 214), (360, 206)]),
                          top: WB.indigoDeep, bottom: WB.indigo, rough: 0.06, seed: 41, keyline: 0.8, grain: 0)
            ],
            mists: [
                MistSpec(edge: .left, y: 122, length: 228, height: 13, tiers: [1, 0.66, 0.84], after: 1),
                MistSpec(edge: .right, y: 134, length: 156, height: 11, tiers: [1, 0.62], after: 1),
                MistSpec(edge: .right, y: 166, length: 132, height: 13, tiers: [1], after: 2),
                MistSpec(edge: .left, y: 175, length: 262, height: 37, tiers: [1], solid: 0.8, after: 2),
                MistSpec(edge: .right, y: 179, length: 214, height: 34, tiers: [1], solid: 0.8, after: 2),
                MistSpec(edge: .left, y: 198, length: 236, height: 14, tiers: [1], after: 2)
            ],
            sun: CGPoint(x: 182, y: 40), sunR: 15,
            clouds: clouds(w, CloudSpec(center: CGPoint(x: 196, y: 56), width: 64, height: 12, seed: 5),
                           extra: [CloudSpec(center: CGPoint(x: 96, y: 126), width: 60, height: 10, seed: 6)]),
            pines: [PineSpec(base: CGPoint(x: 316, y: 160), height: 26, lean: -1, seed: 4)],
            pinesAfter: 2,
            weather: w,
            precip: CGRect(x: 0, y: 0, width: 348, height: 172)
        )
    }

    static func dayMedium(_ w: WBSky) -> SceneSpec {
        SceneSpec(
            sky: daySky(w), skyTo: 128,
            ridges: [
                RidgeSpec(keys: p([(-10, 116), (28, 104), (60, 110), (96, 98), (130, 108), (170, 100), (240, 110), (300, 100), (360, 110)]),
                          top: WB.celadon, bottom: WB.washi, gradFrom: 96, gradTo: 134, rough: 0.06, seed: 12,
                          keyline: 0.6, grain: 1, misreg: CGSize(width: -0.5, height: 0.4)),
                RidgeSpec(keys: p([(-10, 140), (22, 124), (46, 106), (64, 94), (82, 108), (100, 118), (140, 112), (220, 124), (290, 116), (360, 128)]),
                          top: WB.prussian, bottom: WB.prussianPale, gradFrom: 94, gradTo: 150, rough: 0.07, seed: 22,
                          snow: 110, keyline: 0.9, gullies: 4),
                RidgeSpec(keys: p([(-10, 150), (30, 142), (70, 152), (110, 140), (150, 148), (220, 142), (290, 150), (360, 144)]),
                          top: WB.indigo, bottom: WB.pine, gradFrom: 140, gradTo: 166, rough: 0.08, seed: 32,
                          trees: [TreeSpec(from: -4, to: 352, spacing: 3.4...6, height: 5...9)],
                          keyline: 0.8, grain: 1)
            ],
            mists: [MistSpec(edge: .left, y: 118, length: 104, height: 9, tiers: [1, 0.66, 0.86], after: 1)],
            sun: CGPoint(x: 92, y: 92), sunR: 9,
            clouds: clouds(w, CloudSpec(center: CGPoint(x: 84, y: 100), width: 30, height: 7, seed: 8)),
            weather: w,
            precip: CGRect(x: 0, y: 0, width: 120, height: 164)
        )
    }

    static func daySmall(_ w: WBSky) -> SceneSpec {
        SceneSpec(
            sky: daySky(w), skyTo: 104,
            ridges: [
                RidgeSpec(keys: p([(-10, 86), (24, 74), (56, 80), (92, 70), (128, 78), (174, 72)]),
                          top: WB.celadon, bottom: WB.washi, gradFrom: 68, gradTo: 100, rough: 0.06, seed: 13,
                          keyline: 0.55, grain: 1, misreg: CGSize(width: -0.5, height: 0.4)),
                RidgeSpec(keys: p([(-10, 104), (18, 88), (40, 70), (54, 62), (70, 76), (92, 88), (120, 82),
                                   (140, 72), (174, 90)]),
                          top: WB.prussian, bottom: WB.prussianPale, gradFrom: 62, gradTo: 110, rough: 0.07, seed: 23,
                          snow: 80, keyline: 0.85, gullies: 4),
                RidgeSpec(keys: p([(-10, 100), (40, 92), (90, 100), (130, 90), (174, 98)]),
                          top: WB.indigo, bottom: WB.pine, gradFrom: 90, gradTo: 120, rough: 0.08, seed: 33,
                          trees: [TreeSpec(from: -4, to: 168, spacing: 3.4...6, height: 5...9)],
                          keyline: 0.75, grain: 1)
            ],
            mists: [MistSpec(edge: .right, y: 80, length: 104, height: 7, tiers: [1, 0.62, 0.8], after: 1),
                    MistSpec(edge: .left, y: 76, length: 48, height: 6, tiers: [1, 0.7], after: 1)],
            sun: CGPoint(x: 104, y: 64), sunR: 8,
            clouds: clouds(w, CloudSpec(center: CGPoint(x: 112, y: 72), width: 28, height: 6, seed: 9)),
            weather: w,
            precip: CGRect(x: 0, y: 0, width: 164, height: 100)
        )
    }

    // MARK: quotes

    static let quoteLarge = SceneSpec(
        sky: duskSky, skyTo: 262,
        ridges: [
            RidgeSpec(keys: p([(-10, 236), (40, 218), (90, 228), (150, 212), (196, 224), (240, 214), (300, 226), (360, 216)]),
                      top: WB.prussianPale, bottom: WB.washi, gradFrom: 212, gradTo: 256, rough: 0.06, seed: 14,
                      keyline: 0.55, grain: 1, misreg: CGSize(width: -0.5, height: 0.4)),
            RidgeSpec(keys: p([(-10, 282), (30, 258), (62, 240), (88, 222), (104, 210), (116, 218), (130, 202), (146, 220),
                               (170, 236), (200, 250), (238, 258), (270, 240), (300, 228), (330, 242), (360, 254)]),
                      top: WB.prussian, bottom: WB.prussianPale, gradFrom: 202, gradTo: 292, rough: 0.07, seed: 24,
                      snow: 236, keyline: 0.95, gullies: 6),
            RidgeSpec(keys: p([(-10, 304), (40, 290), (96, 300), (150, 286), (206, 298), (260, 286), (310, 298), (360, 288)]),
                      top: WB.indigo, bottom: WB.pine, gradFrom: 284, gradTo: 330, rough: 0.08, seed: 34,
                      trees: [TreeSpec(from: 80, to: 352, spacing: 3.6...6.5, height: 7...12)],
                      keyline: 0.8, grain: 1),
            RidgeSpec(keys: p([(-10, 318), (22, 306), (50, 312), (76, 326), (104, 344), (126, 369), (140, 369)]),
                      top: WB.indigoDeep, bottom: WB.indigo, gradFrom: 306, gradTo: 365, rough: 0.07, seed: 44,
                      trees: [TreeSpec(from: 64, to: 112, spacing: 4...7, height: 8...13)],
                      keyline: 0.9, grain: 0)
        ],
        mists: [
            MistSpec(edge: .left, y: 252, length: 236, height: 14, tiers: [1, 0.7, 0.88], after: 1),
            MistSpec(edge: .right, y: 266, length: 176, height: 12, tiers: [1, 0.64], after: 1),
            MistSpec(edge: .right, y: 308, length: 220, height: 11, tiers: [1, 0.72], after: 2, tint: WB.celadon),
        ],
        moon: CGPoint(x: 254, y: 214), moonR: 22,
        birds: p([(286, 160), (296, 154), (306, 150), (298, 165), (314, 158)]),
        pines: [PineSpec(base: CGPoint(x: 34, y: 312), height: 42, lean: 1, seed: 3)],
        pinesAfter: 3,
        weather: .clear,
        water: 314, waterAfter: 2
    )

    static let quoteMedium = SceneSpec(
        sky: duskSky, skyTo: 150,
        ridges: [
            RidgeSpec(keys: p([(-10, 132), (50, 120), (110, 128), (170, 114), (230, 122), (290, 108), (360, 118)]),
                      top: WB.prussianPale, bottom: WB.washi, gradFrom: 108, gradTo: 146, rough: 0.06, seed: 15,
                      keyline: 0.55, grain: 1, misreg: CGSize(width: -0.5, height: 0.4)),
            RidgeSpec(keys: p([(-10, 152), (40, 138), (96, 146), (150, 128), (178, 116), (196, 108), (210, 114),
                               (226, 104), (248, 122), (276, 132), (300, 118), (330, 112), (360, 126)]),
                      top: WB.prussian, bottom: WB.prussianPale, gradFrom: 104, gradTo: 160, rough: 0.07, seed: 25,
                      snow: 124, keyline: 0.9, gullies: 4),
            RidgeSpec(keys: p([(-10, 150), (50, 142), (110, 152), (170, 140), (230, 150), (290, 142), (360, 150)]),
                      top: WB.indigo, bottom: WB.pine, gradFrom: 140, gradTo: 166, rough: 0.08, seed: 35,
                      trees: [TreeSpec(from: -4, to: 352, spacing: 3.6...6, height: 5...9)],
                      keyline: 0.8, grain: 1)
        ],
        mists: [MistSpec(edge: .left, y: 128, length: 196, height: 9, tiers: [1, 0.7, 0.86], after: 1),
                MistSpec(edge: .right, y: 133, length: 128, height: 8, tiers: [1, 0.62], after: 1)],
        moon: CGPoint(x: 268, y: 112), moonR: 12,
        birds: p([(120, 112), (130, 107), (139, 110)]),
        weather: .clear
    )

    static let quoteSmall = SceneSpec(
        sky: duskSky, skyTo: 160,
        ridges: [
            RidgeSpec(keys: p([(-10, 124), (40, 114), (90, 120), (130, 108), (174, 116)]),
                      top: WB.prussianPale, bottom: WB.washi, gradFrom: 108, gradTo: 140, rough: 0.06, seed: 16,
                      keyline: 0.55, grain: 1, misreg: CGSize(width: -0.5, height: 0.4)),
            RidgeSpec(keys: p([(-10, 146), (30, 130), (62, 118), (82, 108), (102, 120), (136, 132), (174, 124)]),
                      top: WB.prussian, bottom: WB.prussianPale, gradFrom: 108, gradTo: 156, rough: 0.07, seed: 26,
                      snow: 120, keyline: 0.85, gullies: 4),
            RidgeSpec(keys: p([(-10, 150), (50, 142), (110, 152), (174, 144)]),
                      top: WB.indigo, bottom: WB.pine, gradFrom: 142, gradTo: 170, rough: 0.08, seed: 36,
                      trees: [TreeSpec(from: -4, to: 168, spacing: 3.4...6, height: 5...8)],
                      keyline: 0.75, grain: 1)
        ],
        mists: [MistSpec(edge: .right, y: 122, length: 104, height: 8, tiers: [1, 0.64, 0.82], after: 1),
                MistSpec(edge: .left, y: 136, length: 54, height: 6, tiers: [1], after: 1)],
        moon: CGPoint(x: 130, y: 108), moonR: 10,
        birds: p([(96, 98), (105, 94), (113, 97)]),
        weather: .clear
    )
}
