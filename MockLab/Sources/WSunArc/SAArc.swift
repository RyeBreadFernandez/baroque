import SwiftUI

// The sun's path as a fine gilt arc inlaid in the painting's sky: solid gilt for the daylight (or night) gone, dashed
// for what is still to come, the sun or moon at the join. At the arc's feet, small engraved sun-up and sun-down marks
// and the times in serif.

/// A stretch of the arc between two fractions of its length (0 at the left foot, 1 at the right).
struct SAArcPath: Shape {
    var arc: SkyArc
    var from: Double
    var to: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard to > from else { return p }
        let steps = max(8, Int((to - from) * 120))
        for i in 0...steps {
            let t = from + (to - from) * Double(i) / Double(steps)
            let pt = arc.point(t, in: rect.size)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

/// The arc as gilt: an incised shadow under it, the travelled part solid and softly luminous, the rest dashed, and a
/// small tick at the crown (noon, or midnight's middle of the night).
struct SAArcLine: View {
    var arc: SkyArc
    var progress: Double
    var light: CoverLight
    /// False when there is no weather (no sunrise or sunset): the whole arc is dashed and quiet.
    var known: Bool = true
    var weight: CGFloat = 1

    var body: some View {
        let done = known ? min(1, max(0, progress)) : 0
        let gilt = LinearGradient(stops: [.init(color: light.rim, location: 0), .init(color: light.gild[0], location: 0.25),
                                          .init(color: light.gild[1], location: 0.6), .init(color: light.gild[2], location: 1)],
                                  startPoint: .top, endPoint: .bottom)
        let dash = StrokeStyle(lineWidth: 1.2 * weight, lineCap: .round, dash: [2.8 * weight, 3.6 * weight])
        ZStack {
            // Incised: a soft dark groove under the gilt.
            SAArcPath(arc: arc, from: 0, to: done)
                .stroke(CoverInk.shadow.opacity(0.6), style: StrokeStyle(lineWidth: 2.6 * weight, lineCap: .round))
                .blur(radius: 0.9)
                .offset(y: 0.7)
            SAArcPath(arc: arc, from: done, to: 1)
                .stroke(CoverInk.shadow.opacity(0.5), style: StrokeStyle(lineWidth: 2.4 * weight, lineCap: .round,
                                                                         dash: [2.8 * weight, 3.6 * weight]))
                .blur(radius: 0.7)
                .offset(y: 0.6)
            // The light the travelled gilt gives off.
            SAArcPath(arc: arc, from: 0, to: done)
                .stroke(light.glow.opacity(light.isDay ? 0.5 : 0.35), style: StrokeStyle(lineWidth: 4 * weight, lineCap: .round))
                .blur(radius: 3)
                .blendMode(.screen)
            SAArcPath(arc: arc, from: 0, to: done)
                .stroke(gilt, style: StrokeStyle(lineWidth: 1.35 * weight, lineCap: .round))
            SAArcPath(arc: arc, from: 0, to: done)
                .stroke(light.rim.opacity(0.75), style: StrokeStyle(lineWidth: 0.4 * weight, lineCap: .round))
                .offset(y: -0.35)
            SAArcPath(arc: arc, from: done, to: 1)
                .stroke(gilt, style: dash)
                .opacity(known ? 0.92 : 0.6)
            SANoonTick(arc: arc, light: light, weight: weight)
        }
    }
}

/// A short gilt tick across the arc's crown, like the noon mark on a sundial.
struct SANoonTick: View {
    var arc: SkyArc
    var light: CoverLight
    var weight: CGFloat

    var body: some View {
        GeometryReader { geo in
            let top = arc.point(0.5, in: geo.size)
            Path { p in
                p.move(to: CGPoint(x: top.x, y: top.y - 3.2 * weight))
                p.addLine(to: CGPoint(x: top.x, y: top.y + 3.2 * weight))
            }
            .stroke(LinearGradient(colors: [light.rim, light.gild[1]], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 0.9 * weight, lineCap: .round))
            .shadow(color: CoverInk.shadow.opacity(0.6), radius: 0.6, x: 0, y: 0.6)
        }
    }
}

// MARK: - The marks at the feet

/// A small engraved sun-up (or sun-down) mark: a half sun with five short rays on a horizon line, and a chevron under
/// the line pointing up for sunrise, down for sunset. Cut as a dark groove with gilt laid in it.
struct SASunMark: View {
    var rise: Bool
    var light: CoverLight
    var size: CGFloat = 14

    var body: some View {
        let gilt = LinearGradient(colors: [light.rim, light.gild[1], light.gild[2]], startPoint: .top, endPoint: .bottom)
        let line = StrokeStyle(lineWidth: max(0.8, size * 0.062), lineCap: .round, lineJoin: .round)
        ZStack {
            SASunMarkShape(rise: rise).stroke(CoverInk.shadow.opacity(0.85), style: StrokeStyle(lineWidth: line.lineWidth * 2.1, lineCap: .round, lineJoin: .round))
                .blur(radius: 0.5)
                .offset(y: 0.5)
            SASunMarkShape(rise: rise).stroke(gilt, style: line)
        }
        .frame(width: size, height: size * 0.86)
    }
}

struct SASunMarkShape: Shape {
    var rise: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let horizon = rect.minY + h * 0.6
        let c = CGPoint(x: rect.midX, y: horizon)
        let r = w * 0.2
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: horizon))
        p.addLine(to: CGPoint(x: rect.maxX, y: horizon))
        p.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.move(to: CGPoint(x: c.x - r, y: horizon))
        p.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        for k in 1...5 {
            let a = Double.pi + Double(k) * Double.pi / 6
            let r0 = r + w * 0.1, r1 = r + w * 0.2
            p.move(to: CGPoint(x: c.x + r0 * CGFloat(cos(a)), y: horizon + r0 * CGFloat(sin(a))))
            p.addLine(to: CGPoint(x: c.x + r1 * CGFloat(cos(a)), y: horizon + r1 * CGFloat(sin(a))))
        }
        // The chevron under the line.
        let cy = horizon + h * 0.27
        let dx = w * 0.13, dy = h * 0.12 * (rise ? -1 : 1)
        p.move(to: CGPoint(x: c.x - dx, y: cy - dy / 2))
        p.addLine(to: CGPoint(x: c.x, y: cy + dy / 2))
        p.addLine(to: CGPoint(x: c.x + dx, y: cy - dy / 2))
        return p
    }
}

/// A foot of the arc: the engraved mark and the time beside it, set on the dark ridge.
struct SAFoot: View {
    var rise: Bool
    var time: String
    var light: CoverLight
    /// The mark leads (left foot) or trails (right foot), so it always stands right under the arc's foot.
    var markFirst: Bool
    var size: CGFloat = 13
    var word: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if markFirst { SASunMark(rise: rise, light: light, size: size * 1.08) }
            VStack(alignment: markFirst ? .leading : .trailing, spacing: 0) {
                Text(time)
                    .font(SAType.serif(size))
                    .foregroundStyle(CoverInk.cream)
                if word {
                    Text(rise ? "sunrise" : "sunset")
                        .font(SAType.italic(size * 0.72))
                        .foregroundStyle(CoverInk.creamSoft)
                }
            }
            .fixedSize()
            if !markFirst { SASunMark(rise: rise, light: light, size: size * 1.08) }
        }
        .coverOnSky(0.8)
    }
}
