import SwiftUI

// The Quote widget as a frontispiece: tonight's moon in a window on the axis at the top, the quote centered
// between fleurons, the author between short gold rules, and a symmetric range at the foot.

// MARK: - Geometry

struct MDQuoteSpec {
    var canvas: CGSize
    var window: CGRect          // the moon's window, in points
    var arch: Bool              // an arch (large) or a round oculus
    var moon: CGFloat           // moon radius
    var moonY: CGFloat          // moon center, as a fraction of the window height
    var top: CGFloat            // the quote's band, in points
    var bottom: CGFloat
    var authorY: CGFloat
    var arrow: CGPoint?         // the next-quote pebble's center
    var textSizes: [CGFloat]    // largest first
    var fleuron: CGFloat        // fleuron width
    var sparkle: CGFloat
    var ridges: [MountainLayer]

    static func of(_ size: BaroqueSize) -> MDQuoteSpec {
        typealias R = MDRidges
        func range(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat) -> [MountainLayer] {
            // Side peaks framing a central saddle; the nearest ridge dips on the axis where the arrow rests.
            [
                MountainLayer(profile: R.mirrored([(0, a + 0.03), (0.08, a - 0.01), (0.16, a - 0.035), (0.24, a - 0.01),
                                                   (0.32, a - 0.03), (0.40, a + 0.0), (0.46, a + 0.02), (0.5, a + 0.03)], seed: 61),
                              top: Color(hex: 0x33423E), bottom: Color(hex: 0x26332F), rim: 0.32),
                MountainLayer(profile: R.mirrored([(0, b + 0.01), (0.1, b - 0.02), (0.2, b - 0.035), (0.3, b - 0.015),
                                                   (0.4, b + 0.0), (0.5, b + 0.02)], seed: 67),
                              top: Color(hex: 0x1F2B27), bottom: Color(hex: 0x18221E), rim: 0.22,
                              trees: Trees(height: 4...7, spacing: 4.5, coverage: 0.6)),
                MountainLayer(profile: R.mirrored([(0, c - 0.01), (0.12, c - 0.03), (0.24, c - 0.04), (0.36, c - 0.02),
                                                   (0.44, c + 0.005), (0.5, c + 0.015)], seed: 71),
                              top: Color(hex: 0x131B17), bottom: Color(hex: 0x0D1310), rim: 0.16,
                              trees: Trees(height: 6...11, spacing: 5, coverage: 0.8))
            ]
        }
        switch size {
        case .large:
            return MDQuoteSpec(canvas: CGSize(width: 348, height: 365),
                               window: CGRect(x: 147, y: 15, width: 54, height: 66), arch: true, moon: 13, moonY: 0.4,
                               top: 92, bottom: 286, authorY: 298, arrow: CGPoint(x: 174, y: 332),
                               textSizes: [28, 26, 24, 22, 20, 18, 16.5, 15], fleuron: 120, sparkle: 10,
                               ridges: range(0.71, 0.79, 0.865))
        case .medium:
            return MDQuoteSpec(canvas: CGSize(width: 348, height: 164),
                               window: CGRect(x: 160, y: 10, width: 28, height: 28), arch: false, moon: 8.5, moonY: 0.5,
                               top: 41, bottom: 122, authorY: 133, arrow: CGPoint(x: 317, y: 133),
                               textSizes: [20, 19, 17, 15.5, 14, 13, 12], fleuron: 96, sparkle: 8,
                               ridges: range(0.66, 0.76, 0.85))
        case .small:
            return MDQuoteSpec(canvas: CGSize(width: 164, height: 164),
                               window: CGRect(x: 69, y: 11, width: 26, height: 26), arch: false, moon: 8, moonY: 0.5,
                               top: 40, bottom: 126, authorY: 137, arrow: nil,
                               textSizes: [17, 15.5, 14, 13, 12, 11], fleuron: 70, sparkle: 7,
                               ridges: range(0.68, 0.77, 0.86))
        }
    }
}

// MARK: - Widget

struct MDQuote: View {
    var quote: Quote
    var size: BaroqueSize
    var date: Date
    var error: String? = nil

    var body: some View {
        let spec = MDQuoteSpec.of(size)
        let w = spec.canvas.width
        ZStack(alignment: .topLeading) {
            MDQuoteGround(spec: spec, date: date)
            ViewThatFits(in: .vertical) {
                ForEach(spec.textSizes, id: \.self) { s in
                    block(s, spec: spec)
                }
                // Too long for every size: fill the band and truncate the tail.
                block(spec.textSizes.last ?? 12, spec: spec)
            }
            .padding(.horizontal, 16)
            .frame(width: w, height: spec.bottom - spec.top)
            .offset(y: spec.top)
            authorBand(spec)
                .frame(width: authorWidth(spec))
                .position(x: w / 2, y: spec.authorY)
            if let arrow = spec.arrow {
                NextQuoteArrow().position(arrow)
            }
        }
        .frame(width: w, height: spec.canvas.height)
    }

    // The quote between two fleurons, all on the axis; short quotes sit in the middle of the band.
    private func block(_ pointSize: CGFloat, spec: MDQuoteSpec) -> some View {
        VStack(spacing: size == .large ? 10 : 5) {
            MDFleuron(width: spec.fleuron, sparkle: spec.sparkle)
            Text(quote.text)
                .font(Serif.font(pointSize, weight: .medium, italic: true))
                .foregroundStyle(Stone.parchment)
                .multilineTextAlignment(.center)
                .lineSpacing(pointSize > 18 ? 2 : 1)
                .legible()
            MDFleuron(width: spec.fleuron, sparkle: spec.sparkle)
        }
        .frame(maxWidth: .infinity)
    }

    /// Keeps the author clear of the arrow when the arrow sits at the side.
    private func authorWidth(_ spec: MDQuoteSpec) -> CGFloat {
        let w = spec.canvas.width
        guard let arrow = spec.arrow, abs(arrow.x - w / 2) > 1 else { return w - 32 }
        return 2 * (arrow.x - 15 - 8 - w / 2)
    }

    private func authorBand(_ spec: MDQuoteSpec) -> some View {
        VStack(spacing: 3) {
            if let a = quote.author, !a.isEmpty {
                HStack(spacing: 8) {
                    goldRule
                    Text(a)
                        .font(.system(size: size == .small ? 9 : 10, weight: .semibold))
                        .tracking(size == .small ? 0.8 : 1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Stone.gold)
                        .legible()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    goldRule
                }
            }
            if let error {
                MDErrorLine(message: error, color: Stone.parchment.opacity(0.9), fontSize: size == .small ? 9.5 : 10)
                    .legible()
            }
        }
    }

    private var goldRule: some View {
        Rectangle()
            .fill(Stone.gold.opacity(0.85))
            .frame(width: size == .small ? 12 : 18, height: 1)
            .shadow(color: Stone.shadow.opacity(0.8), radius: 0, x: 0, y: 0.8)
    }
}

// MARK: - Ground

/// The evening sky, mirrored stars, tonight's moon in its window on the axis, and the symmetric range.
struct MDQuoteGround: View {
    var spec: MDQuoteSpec
    var date: Date

    var body: some View {
        let horizon = spec.ridges.first.map { $0.profile.keys.map(\.y).min() ?? 0.7 } ?? 0.7
        let small = spec.canvas.width < 200
        let stars = CGRect(x: 0.05, y: 0.05, width: small ? 0.2 : 0.3, height: small || spec.canvas.height < 200 ? 0.14 : 0.2)
        PaintedSky(palette: .evening, horizon: horizon + 0.06)
            .overlay(RadialGradient(colors: [Color(hex: 0xB0703F).opacity(0.34), .clear],
                                    center: UnitPoint(x: 0.5, y: horizon + 0.07), startRadius: 0, endRadius: spec.canvas.width * 0.55))
            .overlay(Stars(region: stars, count: small ? 4 : 7, sparkles: 1, seed: 7))
            .overlay(Stars(region: CGRect(x: 1 - stars.maxX, y: stars.minY, width: stars.width, height: stars.height),
                           count: small ? 4 : 7, sparkles: 1, seed: 17))
            .overlay(alignment: .topLeading) { window }
            .overlay(MountainRange(layers: spec.ridges, night: true))
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.32), .clear], center: UnitPoint(x: 0.5, y: 1.08),
                                    startRadius: 0, endRadius: spec.canvas.width * 0.8))
            .overlay(GoldFrame(inset: 6, ornament: false))
            .overlay(SlabBevel())
    }

    private var window: some View {
        let f = spec.window
        let phase = MoonPhase(date: date)
        return ZStack(alignment: .topLeading) {
            // Moonlight spilling out of the window into the sky.
            Circle()
                .fill(RadialGradient(colors: [Stone.moonlight.opacity(0.13), .clear], center: .center, startRadius: 0, endRadius: f.width * 1.3))
                .frame(width: f.width * 2.6, height: f.width * 2.6)
                .position(x: f.midX, y: f.minY + f.width / 2)
            // Hairlines running out from the window along the top, like the frame's own ornament.
            HStack(spacing: f.width + 14) {
                HStack(spacing: 5) { MDHairline(fadesLeading: true, strength: 0.6); dot }
                HStack(spacing: 5) { dot; MDHairline(fadesLeading: false, strength: 0.6) }
            }
            .frame(width: f.width + 14 + (spec.arch ? 120 : 96))
            .position(x: f.midX, y: f.minY + f.width / 2)
            Group {
                if spec.arch {
                    MDMoonWindow(shape: MDArchShape(), phase: phase, moonRadius: spec.moon, moonCenter: UnitPoint(x: 0.5, y: spec.moonY),
                                 stars: [UnitPoint(x: 0.27, y: 0.72), UnitPoint(x: 0.74, y: 0.66), UnitPoint(x: 0.66, y: 0.84)])
                } else {
                    MDMoonWindow(shape: Circle(), phase: phase, moonRadius: spec.moon, moonCenter: UnitPoint(x: 0.5, y: spec.moonY))
                }
            }
            .frame(width: f.width, height: f.height)
            .position(x: f.midX, y: f.midY)
        }
        .frame(width: spec.canvas.width, height: spec.canvas.height)
    }

    private var dot: some View {
        Circle().fill(Stone.gold.opacity(0.8)).frame(width: 2.2, height: 2.2).raised()
    }
}
