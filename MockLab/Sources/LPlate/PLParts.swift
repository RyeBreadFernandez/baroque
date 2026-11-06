import SwiftUI

// Storybook Plate: the widget's ground is a brushed espresso board, and the painting is an inset plate
// sunk into it (carved well, gilt fillet, the lip's shadow cast into the picture), like an illustration
// tipped into an old book. Everything here is pure SwiftUI built from the app's Theme and Landscape parts.

// MARK: - Board

/// The widget's ground: the shipped panel paint (brushwork, canvas weave, light from the upper left),
/// a lit chamfer round the widget's edge and a gold hairline inlaid just inside it.
struct PLBoard: View {
    var body: some View {
        StoneSurface(material: .panel)
            .overlay(StoneMaterial.panel.lighting)
            // A little more shade toward the foot, as on the shipped grounds.
            .overlay(RadialGradient(colors: [Stone.shadow.opacity(0.32), .clear], center: UnitPoint(x: 0.95, y: 1.0),
                                    startRadius: 0, endRadius: 300))
            .overlay(ChamferRim(shape: ContainerRelativeShape()))
            .overlay {
                // Inlaid hairline: a dark cut with the gold laid in above it.
                ZStack {
                    ContainerRelativeShape().inset(by: 6.7)
                        .stroke(Stone.shadow.opacity(0.55), lineWidth: 0.7)
                        .offset(y: 0.7)
                    ContainerRelativeShape().inset(by: 6)
                        .stroke(Stone.gold.opacity(0.34), lineWidth: 0.7)
                }
                .allowsHitTesting(false)
            }
            .overlay(SlabBevel())
    }
}

// MARK: - Plate shapes

/// A picture's outline: straight sides and a flat foot with small rounded corners, under an elliptical
/// arch `rise` points tall. `rise == width / 2` is a round-headed window; `rise == 0` a rounded rectangle.
/// Insetting keeps the arch's springing line, so a mat or rule drawn round it stays parallel.
struct PLArch: InsettableShape {
    var rise: CGFloat
    var corner: CGFloat = 6
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard r.width > 1, r.height > 1 else { return Path() }
        let c = max(0.5, min(corner - insetAmount, r.width / 2, r.height / 2))
        let ry = min(max(0, rise - insetAmount), r.height - c)
        var p = Path()
        if ry < c {
            return Path(roundedRect: r, cornerRadius: c, style: .continuous)
        }
        let rx = r.width / 2
        let spring = r.minY + ry
        let k: CGFloat = 0.5523 // quarter-ellipse Bezier
        p.move(to: CGPoint(x: r.minX, y: spring))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: spring - ry * k),
                   control2: CGPoint(x: r.midX - rx * k, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: spring),
                   control1: CGPoint(x: r.midX + rx * k, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: spring - ry * k))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> PLArch {
        var a = self
        a.insetAmount += amount
        return a
    }
}

// MARK: - The plate

/// A painting set into the board: the picture at the bottom of a carved well, a gilt fillet round its
/// edge, the board's upper lip casting a shadow into it, and an engraved gold rule on the board around
/// the well with a sparkle at its crown. The view's frame is the picture; the well and rule reach
/// `mat` and `mat + ruleGap` points beyond it.
struct PLPlate<S: InsettableShape, Content: View>: View {
    var shape: S
    var mat: CGFloat = 3.5
    var ruleGap: CGFloat? = 4
    var ornament: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        content
            .clipShape(shape)
            // The lip of the cut throws a soft shadow down across the top of the picture.
            .overlay {
                shape
                    .stroke(Stone.shadow.opacity(0.8), lineWidth: 8)
                    .blur(radius: 3.2)
                    .offset(x: 0.5, y: 2.4)
                    .clipShape(shape)
                    .allowsHitTesting(false)
            }
            // Gilt fillet: bright where the light catches it, deeper at the foot.
            .overlay {
                ZStack {
                    shape.strokeBorder(LinearGradient(colors: [Stone.goldBright.opacity(0.95), Stone.gold.opacity(0.85), Color(hex: 0x8C6538)],
                                                      startPoint: .top, endPoint: .bottom), lineWidth: 1.3)
                    shape.inset(by: 1.3).stroke(Stone.shadow.opacity(0.55), lineWidth: 0.6)
                }
                .allowsHitTesting(false)
            }
            .background { CarvedRecess(shape: shape.inset(by: -mat)) }
            .background {
                if let ruleGap {
                    GeometryReader { geo in
                        ZStack {
                            shape.inset(by: -(mat + ruleGap) - 0.7)
                                .stroke(Stone.shadow.opacity(0.55), lineWidth: 0.7)
                                .offset(y: 0.7)
                            shape.inset(by: -(mat + ruleGap))
                                .stroke(Stone.gold.opacity(0.4), lineWidth: 0.7)
                            if ornament {
                                PLSparkle(size: 9)
                                    .position(x: geo.size.width / 2, y: -(mat + ruleGap))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .accessibilityHidden(true)
    }
}

/// The gold sparkle the shipped frame sets into its top edge, with a dark halo so it sits over a rule.
struct PLSparkle: View {
    var size: CGFloat
    var dots: Bool = true

    var body: some View {
        ZStack {
            Circle().fill(Stone.espressoDark).frame(width: size * 1.7, height: size * 1.7).blur(radius: 2.5)
            Sparkle().fill(Stone.gold).frame(width: size, height: size * 1.22)
                .shadow(color: Stone.goldBright.opacity(0.6), radius: 2.5)
            if dots {
                HStack(spacing: size * 1.45) {
                    Circle().fill(Stone.gold.opacity(0.8)).frame(width: 2, height: 2)
                    Circle().fill(Stone.gold.opacity(0.8)).frame(width: 2, height: 2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Engraving on the board

/// A vertical hairline cut, lit on its right lip: the margin rule of the ledger.
struct PLVerticalRule: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.black.opacity(0.45)).frame(width: 0.7)
            Rectangle().fill(Stone.gold.opacity(0.16)).frame(width: 0.7)
        }
        .accessibilityHidden(true)
    }
}

/// An engraved rule that fades out toward one end: the flourish either side of a caption.
struct PLFadingRule: View {
    var toLeading: Bool

    var body: some View {
        let fade = LinearGradient(colors: [.clear, .black], startPoint: toLeading ? .leading : .trailing,
                                  endPoint: toLeading ? .trailing : .leading)
        EngravedRule()
            .mask(fade)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Ridges and sky sized for a plate

enum PLScenery {
    static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// `Trees` measures in points of a 348 pt widget; convert real point sizes for a plate `width` wide.
    static func trees(_ height: ClosedRange<CGFloat>, spacing: CGFloat, coverage: Double, width: CGFloat) -> Trees {
        let u = max(0.1, width / 348)
        return Trees(height: (height.lowerBound / u)...(height.upperBound / u), spacing: spacing / u, coverage: coverage)
    }
}

/// Clouds on the sky arc, as the shipped `SkyLayout` places them, at an explicit scale `u`
/// (the shipped version derives it from the widget width, which would shrink everything in a small plate).
enum PLSkyLayout {
    static func clouds(_ condition: SkyCondition, clock: SkyClock, arc: SkyArc, size: CGSize, u: CGFloat) -> [(center: CGPoint, width: CGFloat)] {
        func at(_ progress: Double, lift: CGFloat) -> CGPoint {
            let pt = arc.point(progress, in: size)
            return CGPoint(x: pt.x, y: pt.y - lift * u)
        }
        switch condition {
        case .clear:
            return []
        case .partly:
            let body = arc.point(clock.progress, in: size)
            return [(CGPoint(x: body.x + 12 * u, y: body.y + 7 * u), 32 * u),
                    (at(clock.progress < 0.5 ? 0.78 : 0.24, lift: 10), 22 * u)]
        case .fog:
            return [(at(0.62, lift: 10), 26 * u)]
        case .overcast, .rain, .snow, .storm:
            return [(at(0.24, lift: 8), 30 * u), (at(0.5, lift: 4), 38 * u), (at(0.77, lift: 12), 29 * u)]
        }
    }
}

/// The shipped `SkyBack` (glow, dotted arc, sun or moon, clouds) at an explicit scale for a plate.
struct PLSkyBack: View {
    var clock: SkyClock
    var condition: SkyCondition
    var arc: SkyArc
    var phase: MoonPhase
    var u: CGFloat

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let body = arc.point(clock.progress, in: size)
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(RadialGradient(colors: [(clock.isDay ? Stone.goldBright : Stone.moonlight).opacity(condition.gray ? 0.08 : 0.16), .clear],
                                         center: .center, startRadius: 0, endRadius: 75 * u))
                    .frame(width: 150 * u, height: 150 * u)
                    .position(body)
                ArcTrail(arc: arc)
                Group {
                    if clock.isDay {
                        SunDisc(radius: 8.5 * u).opacity(condition.gray ? 0.5 : 1)
                    } else {
                        MoonDisc(radius: 10 * u, phase: phase).opacity(condition.gray ? 0.6 : 1)
                    }
                }
                .position(body)
                ForEach(Array(PLSkyLayout.clouds(condition, clock: clock, arc: arc, size: size, u: u).enumerated()), id: \.offset) { i, c in
                    PaintedCloud(night: !clock.isDay, gray: condition.gray, seed: i)
                        .frame(width: c.width, height: c.width * 0.55)
                        .position(c.center)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The shipped `SkyFront` (rain, snow, lightning, fog banks) at an explicit scale for a plate.
struct PLSkyFront: View {
    var clock: SkyClock
    var condition: SkyCondition
    var arc: SkyArc
    var u: CGFloat

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let clouds = PLSkyLayout.clouds(condition, clock: clock, arc: arc, size: size, u: u)
            ZStack(alignment: .topLeading) {
                switch condition {
                case .rain, .storm:
                    Canvas { ctx, _ in
                        for c in clouds {
                            let count = Int(c.width / (5 * u))
                            for i in 0..<count {
                                let x = c.center.x - c.width * 0.36 + CGFloat(i) * 5 * u + (i % 2 == 0 ? 0 : 1.5 * u)
                                let y = c.center.y + c.width * 0.26 + (i % 2 == 0 ? 0 : 4 * u)
                                var p = Path()
                                p.move(to: CGPoint(x: x, y: y))
                                p.addLine(to: CGPoint(x: x - 2.5 * u, y: y + 9 * u))
                                ctx.stroke(p, with: .color(Color(hex: 0xA9BDB6).opacity(0.7)),
                                           style: StrokeStyle(lineWidth: 1.1 * u, lineCap: .round, dash: [3 * u, 2.5 * u]))
                            }
                        }
                    }
                    if condition == .storm, clouds.count > 1 {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12 * u, weight: .bold))
                            .foregroundStyle(Stone.goldBright)
                            .shadow(color: Stone.goldBright.opacity(0.8), radius: 4)
                            .position(x: clouds[1].center.x + 3 * u, y: clouds[1].center.y + clouds[1].width * 0.45)
                    }
                case .snow:
                    Canvas { ctx, _ in
                        var rng = SeededRandom(9)
                        for c in clouds {
                            for _ in 0..<8 {
                                let x = c.center.x + CGFloat(rng.signed()) * c.width * 0.4
                                let y = c.center.y + c.width * 0.3 + CGFloat(rng.next()) * 16 * u
                                let r = (1.0 + CGFloat(rng.next()) * 0.7) * u
                                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Stone.moonlight))
                            }
                        }
                    }
                case .fog:
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(Color(hex: 0xA7B6AE).opacity(0.45))
                            .frame(width: size.width * (0.5 + 0.12 * CGFloat(i)), height: 5 * u)
                            .blur(radius: 2.5 * u)
                            .position(x: size.width * (0.42 + 0.08 * CGFloat(i)), y: arc.horizon * size.height - CGFloat(6 + 9 * i) * u)
                    }
                default:
                    EmptyView()
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The shipped `Stars` with an explicit scale, so a small plate keeps full-size sparkles.
struct PLStars: View {
    var region: CGRect // unit coordinates of the plate
    var count: Int
    var sparkles: Int
    var seed: UInt64 = 3
    var u: CGFloat

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed)
            for i in 0..<count {
                let x = (region.minX + CGFloat(rng.next()) * region.width) * size.width
                let y = (region.minY + CGFloat(rng.next()) * region.height) * size.height
                if i < sparkles {
                    let s = (5 + CGFloat(rng.next()) * 4) * u
                    let rect = CGRect(x: x - s / 2, y: y - s * 0.6, width: s, height: s * 1.2)
                    glow(ctx, at: CGPoint(x: x, y: y), radius: s * 1.3, color: Stone.goldBright, opacity: 0.28)
                    ctx.fill(Sparkle().path(in: rect), with: .color(Stone.goldBright.opacity(0.95)))
                } else {
                    let r = (0.5 + CGFloat(rng.next()) * 0.8) * u
                    glow(ctx, at: CGPoint(x: x, y: y), radius: r * 3.5, color: Stone.moonlight, opacity: 0.25)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Stone.moonlight.opacity(0.9)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glow(_ ctx: GraphicsContext, at c: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        let rect = CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
                                                             center: c, startRadius: 0, endRadius: radius))
    }
}

// MARK: - Small type on the board

/// "+2 more", in goldMuted: the board's lightest strokes are a touch lighter than a slab's, so goldFaint
/// would dip under 4.5:1 here.
struct PLMoreLabel: View {
    var count: Int

    var body: some View {
        Text("+\(count) more")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Stone.goldMuted)
            .raised()
            .fixedSize()
    }
}

/// A big gilt numeral cut into the board.
struct PLGiltDay: View {
    var date: Date
    var size: CGFloat

    var body: some View {
        Text(date, format: .dateTime.day())
            .font(Serif.font(size, weight: .medium))
            .foregroundStyle(Gilt.style)
            .raised(1.3)
            .lineLimit(1)
            .fixedSize()
    }
}
