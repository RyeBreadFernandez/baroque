import SwiftUI

// Small painted emblems, in the manner of the gold-edged icons of a storybook theme: a sun of wavy rays, a crescent
// moon, a cloud with a lit crown, drops, flakes, mist and a bolt, each filled with paint and edged in gold; and the
// ribbon the sunrise and sunset times are lettered on.

/// The sun: a gold disc in a ring of alternating straight and wavy rays.
struct SBSunGlyph: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            SBStar(points: 8, inner: 0.56)
                .fill(SBGilt.fill)
                .rotationEffect(.degrees(22.5))
            SBStar(points: 8, inner: 0.6)
                .fill(LinearGradient(colors: [SBInk.goldBright, Color(hex: 0xE9A84A)], startPoint: .top, endPoint: .bottom))
                .scaleEffect(0.86)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF1C4), Color(hex: 0xF2C463), Color(hex: 0xC98F38)],
                                     center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.32))
                .overlay(Circle().stroke(SBInk.goldDeep, lineWidth: max(0.5, size * 0.045)))
                .scaleEffect(0.54)
        }
        .frame(width: size, height: size)
    }
}

/// A crescent moon, lit on its left limb, with a gold edge.
struct SBMoonGlyph: View {
    var size: CGFloat

    var body: some View {
        let crescent = MoonLitShape(phase: MoonPhase(fraction: 0.83))
        ZStack {
            crescent
                .fill(LinearGradient(colors: [Color(hex: 0xFFF3CF), Color(hex: 0xE8C985)], startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
            crescent
                .stroke(SBInk.goldDeep, lineWidth: max(0.5, size * 0.05))
        }
        .frame(width: size * 0.9, height: size * 0.9)
        .rotationEffect(.degrees(-18))
        .offset(x: size * 0.18)   // the lit limb is on the left: centre the crescent, not its disc
        .frame(width: size, height: size)
    }
}

/// A cloud: three billows on a flat base, cream with a lit crown and a gold edge.
struct SBCloudShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.addEllipse(in: CGRect(x: r.minX + 0.02 * w, y: r.minY + 0.42 * h, width: 0.42 * w, height: 0.5 * h))
        p.addEllipse(in: CGRect(x: r.minX + 0.22 * w, y: r.minY + 0.08 * h, width: 0.48 * w, height: 0.72 * h))
        p.addEllipse(in: CGRect(x: r.minX + 0.52 * w, y: r.minY + 0.3 * h, width: 0.44 * w, height: 0.6 * h))
        p.addRoundedRect(in: CGRect(x: r.minX + 0.12 * w, y: r.minY + 0.62 * h, width: 0.76 * w, height: 0.3 * h),
                         cornerSize: CGSize(width: 0.15 * h, height: 0.15 * h))
        return p
    }
}

struct SBCloudGlyph: View {
    var width: CGFloat
    var dark = false

    var body: some View {
        let h = width * 0.62
        ZStack {
            SBCloudShape().stroke(SBInk.goldDeep, lineWidth: max(1, width * 0.09))
            SBCloudShape().fill(LinearGradient(colors: dark ? [Color(hex: 0xB8BFC0), Color(hex: 0x6E7C84)]
                                                            : [Color(hex: 0xFFF8E6), Color(hex: 0xD3C6A8)],
                                               startPoint: .top, endPoint: .bottom))
        }
        .frame(width: width, height: h)
    }
}

/// The weather as an emblem: the sun or moon, alone or behind a cloud, or a cloud with rain, snow, mist or a bolt.
struct SBConditionEmblem: View {
    var condition: SkyCondition
    var isDay: Bool
    var size: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch condition {
            case .clear:
                luminary(size).frame(width: size, height: size)
            case .partly:
                luminary(size * 0.74).offset(x: size * 0.02, y: 0)
                SBCloudGlyph(width: size * 0.78).offset(x: size * 0.24, y: size * 0.44)
            case .overcast:
                SBCloudGlyph(width: size * 0.7, dark: true).offset(x: size * 0.3, y: size * 0.1)
                SBCloudGlyph(width: size * 0.86).offset(x: 0, y: size * 0.36)
            case .fog:
                SBCloudGlyph(width: size * 0.86).offset(x: size * 0.07, y: 0)
                mist.offset(x: size * 0.04, y: size * 0.58)
            case .rain, .storm:
                SBCloudGlyph(width: size * 0.9, dark: condition == .storm).offset(x: size * 0.05, y: 0)
                if condition == .storm { bolt.offset(x: size * 0.36, y: size * 0.5) } else { drops.offset(x: size * 0.16, y: size * 0.6) }
            case .snow:
                SBCloudGlyph(width: size * 0.9).offset(x: size * 0.05, y: 0)
                flakes.offset(x: size * 0.14, y: size * 0.62)
            }
        }
        .frame(width: size, height: size, alignment: .topLeading)
    }

    @ViewBuilder private func luminary(_ s: CGFloat) -> some View {
        if isDay { SBSunGlyph(size: s) } else { SBMoonGlyph(size: s) }
    }

    private var drops: some View {
        HStack(spacing: size * 0.12) {
            ForEach(0..<3, id: \.self) { i in
                SBDrop()
                    .fill(LinearGradient(colors: [Color(hex: 0xCFE4EE), SBInk.rain], startPoint: .top, endPoint: .bottom))
                    .overlay(SBDrop().stroke(SBInk.goldDeep, lineWidth: 0.5))
                    .frame(width: size * 0.14, height: size * 0.24)
                    .offset(y: i == 1 ? size * 0.08 : 0)
            }
        }
    }

    private var flakes: some View {
        HStack(spacing: size * 0.1) {
            ForEach(0..<3, id: \.self) { i in
                SBStar(points: 6, inner: 0.25)
                    .fill(SBInk.cream)
                    .frame(width: size * 0.2, height: size * 0.2)
                    .offset(y: i == 1 ? size * 0.1 : 0)
            }
        }
    }

    private var mist: some View {
        VStack(alignment: .leading, spacing: size * 0.08) {
            Capsule().fill(SBInk.creamDim).frame(width: size * 0.8, height: max(1, size * 0.07))
            Capsule().fill(SBInk.creamDim.opacity(0.8)).frame(width: size * 0.62, height: max(1, size * 0.07))
                .offset(x: size * 0.12)
        }
    }

    private var bolt: some View {
        SBBolt().fill(SBGilt.fill).frame(width: size * 0.3, height: size * 0.46)
    }
}

struct SBDrop: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY - r.width / 2), control: CGPoint(x: r.maxX, y: r.midY - r.height * 0.1))
        p.addArc(center: CGPoint(x: r.midX, y: r.maxY - r.width / 2), radius: r.width / 2, startAngle: .degrees(0),
                 endAngle: .degrees(180), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.midY - r.height * 0.1))
        return p
    }
}

struct SBBolt: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let pts: [(CGFloat, CGFloat)] = [(0.55, 0), (0.05, 0.55), (0.45, 0.55), (0.3, 1), (0.95, 0.38), (0.55, 0.38), (0.8, 0)]
        for (i, (x, y)) in pts.enumerated() {
            let pt = CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - The ribbon

/// A banner: a band with a gentle sag, its ends folded back behind it into swallow-tailed tails.
struct SBRibbonBand: Shape {
    var sag: CGFloat = 1.6

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.minY + 2 * sag))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY), control: CGPoint(x: r.midX, y: r.maxY + 2 * sag))
        p.closeSubpath()
        return p
    }
}

/// One tail, for the left end (mirrored for the right): it runs out from behind the band, lower, to a swallow-tail cut.
struct SBRibbonTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.32, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// The fold where the band turns back into the tail: a small dark triangle.
struct SBRibbonFold: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A green silk ribbon with gold edges, lettered with `content`.
struct SBRibbon<Content: View>: View {
    var height: CGFloat = 20
    var tail: CGFloat = 11
    @ViewBuilder var content: Content

    var body: some View {
        let drop = height * 0.32
        content
            .padding(.horizontal, 10)
            .frame(height: height)
            .background {
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .topLeading) {
                        // tails, behind and lower
                        ForEach([false, true], id: \.self) { right in
                            let tailRect = CGRect(x: right ? w - 4 : -tail, y: drop, width: tail + 4, height: height)
                            SBRibbonTail()
                                .fill(LinearGradient(colors: [SBInk.ribbonDeep, SBInk.ribbonBack], startPoint: .top, endPoint: .bottom))
                                .overlay(SBRibbonTail().stroke(SBInk.goldDeep.opacity(0.8), lineWidth: 0.6))
                                .scaleEffect(x: right ? -1 : 1, y: 1)
                                .frame(width: tailRect.width, height: tailRect.height)
                                .offset(x: tailRect.minX, y: tailRect.minY)
                            SBRibbonFold()
                                .fill(Color.black.opacity(0.85))
                                .scaleEffect(x: right ? -1 : 1, y: 1)
                                .frame(width: 4, height: drop)
                                .offset(x: right ? w - 4 : 0, y: height)
                        }
                        SBRibbonBand()
                            .fill(LinearGradient(colors: [Color(hex: 0x33573F), SBInk.ribbon, SBInk.ribbonDeep],
                                                 startPoint: .top, endPoint: .bottom))
                            .overlay(SBRibbonBand().stroke(SBGilt.fill, lineWidth: 0.8))
                            .overlay(SBRibbonBand().inset(1.8).stroke(SBInk.gold.opacity(0.35), lineWidth: 0.4))
                            .frame(width: w, height: height)
                    }
                    .shadow(color: Color.black.opacity(0.6), radius: 2.5, x: 0, y: 1.5)
                }
            }
    }
}

extension SBRibbonBand {
    func inset(_ d: CGFloat) -> some Shape {
        SBInsetBand(sag: sag, d: d)
    }
}

private struct SBInsetBand: Shape {
    var sag: CGFloat
    var d: CGFloat
    func path(in r: CGRect) -> Path { SBRibbonBand(sag: sag).path(in: r.insetBy(dx: d, dy: d)) }
}
