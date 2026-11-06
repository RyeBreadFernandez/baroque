import SwiftUI

// The frame round every Storybook widget: a thin band of dark lacquer, the picture set into it through a window whose
// corners are cut in as quarter-circles (the storybook plate of the reference), a gold hairline round the window, and
// gold filigree in each corner: an echoing arc, a leaf pointing in along the diagonal with a bead either side, and a
// tendril running out along each edge that curls up into a scroll.

enum SBFrameMetrics {
    static let band: CGFloat = 10     // the lacquer band, from the widget's edge to the window
    static let notch: CGFloat = 16    // radius of the window's cut-in corners
    static let echo: CGFloat = 2.6    // the second, finer rule outside the window
}

/// The window the picture shows through: the widget inset by the band, its corners cut in as quarter circles.
struct SBWindow: Shape {
    var inset: CGFloat = SBFrameMetrics.band
    var notch: CGFloat = SBFrameMetrics.notch

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        let corners: [(CGPoint, Double)] = [   // the corner and the angle the cut starts from (degrees, y down)
            (CGPoint(x: r.maxX, y: r.minY), 180), (CGPoint(x: r.maxX, y: r.maxY), 270),
            (CGPoint(x: r.minX, y: r.maxY), 0), (CGPoint(x: r.minX, y: r.minY), 90)
        ]
        p.move(to: CGPoint(x: r.minX + notch, y: r.minY))
        for (c, start) in corners {
            for i in 0...12 {
                let a = (start - 90 * Double(i) / 12) * .pi / 180
                p.addLine(to: CGPoint(x: c.x + notch * CGFloat(cos(a)), y: c.y + notch * CGFloat(sin(a))))
            }
        }
        p.closeSubpath()
        return p
    }
}

/// One corner's filigree, drawn for the top-left corner and mirrored into the others.
struct SBCornerFiligree: Shape {
    var inset: CGFloat = SBFrameMetrics.band
    var notch: CGFloat = SBFrameMetrics.notch
    var reach: CGFloat = 22   // how far the tendrils run along the edges past the cut

    func path(in rect: CGRect) -> Path {
        var half = Path()
        let e = SBFrameMetrics.echo
        // The tendril along the top edge: up out of the outer rule where its corner cut ends, along the band, and a
        // scroll curling up toward the edge.
        let y = (inset - e) * 0.52
        let x0 = inset - e + notch - e
        let x1 = x0 + reach
        half.move(to: CGPoint(x: x0, y: inset - e))
        half.addQuadCurve(to: CGPoint(x: x0 + 5, y: y), control: CGPoint(x: x0 + 1, y: y))
        half.addLine(to: CGPoint(x: x1 - 2, y: y))
        spiral(&half, center: CGPoint(x: x1 - 2, y: y - 1.6), radius: 1.6, turns: 1.35)
        // A small leaf sprouting from the tendril's middle, toward the edge.
        leaf(&half, from: CGPoint(x: x0 + reach * 0.5, y: y), to: CGPoint(x: x0 + reach * 0.5 + 4.2, y: y - 2.6),
             width: 1.3)
        var whole = half
        whole.addPath(half.applying(CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)))
        // The leaf on the diagonal, pointing in toward the picture.
        let d = CGFloat(1 / 2.0.squareRoot())
        let c = CGPoint(x: inset - e, y: inset - e)
        leaf(&whole, from: CGPoint(x: c.x - 0.5 * d, y: c.y - 0.5 * d),
             to: CGPoint(x: c.x + (notch - e - 4.5) * d, y: c.y + (notch - e - 4.5) * d), width: 2.6)
        return whole
    }

    /// Beads either side of the diagonal leaf (filled).
    static func beads(inset: CGFloat = SBFrameMetrics.band, notch: CGFloat = SBFrameMetrics.notch) -> Path {
        var p = Path()
        let e = SBFrameMetrics.echo
        let c = CGPoint(x: inset - e, y: inset - e)
        for a in [16.0, 74.0] {
            let r = notch - e - 5.5
            let pt = CGPoint(x: c.x + r * CGFloat(cos(a * .pi / 180)), y: c.y + r * CGFloat(sin(a * .pi / 180)))
            p.addEllipse(in: CGRect(x: pt.x - 0.85, y: pt.y - 0.85, width: 1.7, height: 1.7))
        }
        return p
    }

    /// A scroll: from the bottom of a circle round `center`, turning up and over and in, `turns` times.
    private func spiral(_ p: inout Path, center: CGPoint, radius: CGFloat, turns: Double) {
        let steps = 40
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let a = (90 - 360 * turns * t) * .pi / 180
            let r = radius * CGFloat(1 - 0.72 * t)
            p.addLine(to: CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a))))
        }
    }

    /// A pointed leaf (a vesica) from one point to another.
    private func leaf(_ p: inout Path, from a: CGPoint, to b: CGPoint, width: CGFloat) {
        let mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(0.001, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / len * width, ny = dx / len * width
        p.move(to: a)
        p.addQuadCurve(to: b, control: CGPoint(x: mx + nx, y: my + ny))
        p.addQuadCurve(to: a, control: CGPoint(x: mx - nx, y: my - ny))
    }
}

/// The frame with the picture (or page) set in it.
struct SBFramed<Content: View>: View {
    var family: Family
    var ornament = false   // a small gold star where the top rule meets the picture (large widgets)
    @ViewBuilder var content: Content

    var body: some View {
        let size = Mock.size(family)
        let window = SBWindow()
        ZStack {
            // The lacquer: the forest-green gouache ground, darkened almost to black, lit a little from above.
            Mock.texture("weather-storybook/ground")
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .overlay(LinearGradient(colors: [SBInk.lacquer.opacity(0.62), SBInk.lacquer.opacity(0.84)],
                                        startPoint: .top, endPoint: .bottom))
            content
                .frame(width: size.width, height: size.height)
                .clipShape(window)
            // The picture sits a little behind the frame: a soft shadow inside the window's upper edge.
            window
                .stroke(Color.black.opacity(0.75), lineWidth: 5)
                .blur(radius: 2.6)
                .offset(y: 1.2)
                .clipShape(window)
            // The bevel of the band: a faint light on the outer lip.
            RoundedRectangle(cornerRadius: Mock.cornerRadius, style: .continuous)
                .inset(by: 0.6)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 1.1)
            gold(size)
        }
        .frame(width: size.width, height: size.height)
    }

    private func gold(_ size: CGSize) -> some View {
        let fil = SBCornerFiligree()
        let beads = SBCornerFiligree.beads()
        let corners = [CGAffineTransform.identity,
                       CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: size.width, ty: 0),
                       CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height),
                       CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: size.width, ty: size.height)]
        let rect = CGRect(origin: .zero, size: size)
        var lines = Path()
        var dots = Path()
        for t in corners {
            lines.addPath(fil.path(in: rect).applying(t))
            dots.addPath(beads.applying(t))
        }
        return ZStack {
            SBWindow().stroke(SBGilt.diagonal, lineWidth: 1.1)
            SBWindow(inset: SBFrameMetrics.band - SBFrameMetrics.echo, notch: SBFrameMetrics.notch - SBFrameMetrics.echo)
                .stroke(SBInk.gold.opacity(0.55), lineWidth: 0.55)
            lines.stroke(SBGilt.diagonal, style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
            dots.fill(SBInk.goldBright)
            if ornament {
                SBStar(points: 4, inner: 0.3)
                    .fill(SBGilt.fill)
                    .frame(width: 12, height: 12)
                    .position(x: size.width / 2, y: SBFrameMetrics.band)
                SBStar(points: 4, inner: 0.3)
                    .fill(SBGilt.fill)
                    .frame(width: 7, height: 7)
                    .rotationEffect(.degrees(45))
                    .position(x: size.width / 2, y: SBFrameMetrics.band)
            }
        }
        .sbRaised()
        .frame(width: size.width, height: size.height)
    }
}

/// A star of `points` rays; `inner` is the waist as a fraction of the radius.
struct SBStar: Shape {
    var points: Int = 4
    var inner: CGFloat = 0.32

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<(points * 2) {
            let a = Double(i) * .pi / Double(points) - .pi / 2
            let rr = i.isMultiple(of: 2) ? r : r * inner
            let pt = CGPoint(x: c.x + rr * CGFloat(cos(a)), y: c.y + rr * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// A short gold flourish under a heading: a hairline that thickens to a lozenge in the middle, with a curl at each end.
struct SBFlourish: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.midY, x0 = rect.minX, x1 = rect.maxX, mx = rect.midX
        p.move(to: CGPoint(x: x0 + 3, y: y))
        p.addLine(to: CGPoint(x: mx - 5, y: y))
        p.move(to: CGPoint(x: mx + 5, y: y))
        p.addLine(to: CGPoint(x: x1 - 3, y: y))
        // the lozenge
        p.move(to: CGPoint(x: mx - 4.5, y: y))
        p.addLine(to: CGPoint(x: mx, y: y - 2))
        p.addLine(to: CGPoint(x: mx + 4.5, y: y))
        p.addLine(to: CGPoint(x: mx, y: y + 2))
        p.closeSubpath()
        // curls
        for (x, s) in [(x0 + 3, CGFloat(-1)), (x1 - 3, CGFloat(1))] {
            p.move(to: CGPoint(x: x, y: y))
            p.addQuadCurve(to: CGPoint(x: x + s * 2.4, y: y - 2.2), control: CGPoint(x: x + s * 2.8, y: y))
            p.addQuadCurve(to: CGPoint(x: x + s * 0.6, y: y - 1.6), control: CGPoint(x: x + s * 1.6, y: y - 3.2))
        }
        return p
    }
}
