import SwiftUI

// MARK: - Quote widgets: the quote in the map's cartouche

struct TopoQuoteLarge: View {
    let quote: Quote

    var body: some View {
        ZStack(alignment: .topLeading) {
            MapSheet(sheet: TopoSheet.quoteLarge, grid: 58, gridOrigin: CGPoint(x: 55, y: 49), easting: 618, northing: 3502,
                     marginNote: "SCALE 1:24 000 \u{00B7} CONTOUR INTERVAL 40 FEET")
            SectionLine(from: CGPoint(x: 20, y: 27), to: CGPoint(x: 328, y: 33))
            Cartouche(title: "FIELD NOTE", author: quote.author, inset: EdgeInsets(top: 18, leading: 18, bottom: 16, trailing: 18)) {
                VStack(spacing: 6) {
                    FittedQuote(text: quote.text, sizes: [24, 22, 20.5, 19, 17.5, 16, 14.5, 13])
                        .frame(maxHeight: .infinity)
                    ProfileStrip(sheet: TopoSheet.quoteLarge).frame(height: 44)
                }
            }
            .frame(width: 296, height: 226)
            .offset(x: 26, y: 66)
            CompassRose(radius: 16).position(x: 52, y: 327)
            AdjoiningSheetButton().position(x: 317, y: 334)
        }
        .frame(width: 348, height: 365, alignment: .topLeading)
    }
}

struct TopoQuoteMedium: View {
    let quote: Quote

    var body: some View {
        ZStack(alignment: .topLeading) {
            MapSheet(sheet: TopoSheet.quoteMedium, grid: 58, gridOrigin: CGPoint(x: 43, y: 41), easting: 702, northing: 2280)
            Cartouche(title: "FIELD NOTE", author: quote.author, inset: EdgeInsets(top: 15, leading: 14, bottom: 16, trailing: 14)) {
                FittedQuote(text: quote.text, sizes: [19, 18, 17, 16, 15, 14, 13, 12])
            }
            .frame(width: 254, height: 126)
            .offset(x: 18, y: 20)
            AdjoiningSheetButton().position(x: 317, y: 133)
        }
        .frame(width: 348, height: 164, alignment: .topLeading)
    }
}

struct TopoQuoteSmall: View {
    let quote: Quote

    var body: some View {
        ZStack(alignment: .topLeading) {
            MapSheet(sheet: TopoSheet.quoteSmall, grid: 54, gridOrigin: CGPoint(x: 33, y: 29), easting: 115, northing: 870)
            Cartouche(title: "NOTE", author: quote.author, inset: EdgeInsets(top: 13, leading: 10, bottom: 14, trailing: 10)) {
                FittedQuote(text: quote.text, sizes: [19, 18, 17, 16, 15, 14, 13, 12])
            }
            .frame(width: 138, height: 94)
            .offset(x: 13, y: 40)
        }
        .frame(width: 164, height: 164, alignment: .topLeading)
    }
}

// MARK: - Fitted quote text

struct FittedQuote: View {
    let text: String
    let sizes: [CGFloat]

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes, id: \.self) { s in candidate(s) }
        }
    }

    private func candidate(_ s: CGFloat) -> some View {
        Text("\u{201C}\(text)\u{201D}")
            .font(TopoFont.quote(s))
            .foregroundColor(TopoInk.ink)
            .multilineTextAlignment(.center)
            .lineSpacing(s * 0.06)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Cartouche

/// The map's cartouche: a pasted paper panel with notched corners, a heavy and a hairline rule, corner pips,
/// a title set into the top rule and the author set into the bottom rule.
struct Cartouche<Content: View>: View {
    let title: String
    let author: String?
    let inset: EdgeInsets
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CartoucheFrame())
            .overlay(alignment: .top) { tab(Text(title).font(TopoFont.futuraBold(7.6)).tracking(2).foregroundColor(TopoInk.red)) }
            .overlay(alignment: .bottom) { footer }
    }

    @ViewBuilder private var footer: some View {
        if let a = author, !a.isEmpty {
            tab(Text("— " + a.uppercased()).font(TopoFont.futura(8.2)).tracking(0.9).foregroundColor(TopoInk.ink))
        } else {
            tab(Diamond().fill(TopoInk.ink).frame(width: 5, height: 5))
        }
    }

    private func tab<V: View>(_ v: V) -> some View {
        HStack(spacing: 5) {
            Diamond().fill(TopoInk.red).frame(width: 4, height: 4)
            v.lineLimit(1).minimumScaleFactor(0.8)
            Diamond().fill(TopoInk.red).frame(width: 4, height: 4)
        }
        .padding(.horizontal, 6)
        .frame(height: 12)
        .background(PaperFill())
        .alignmentGuide(.top) { d in d[VerticalAlignment.center] - 2.4 }
        .alignmentGuide(.bottom) { d in d[VerticalAlignment.center] + 2.4 }
    }
}

/// The plain survey paper, filling whatever frame it is given without spilling past it.
struct PaperFill: View {
    var body: some View {
        Color.clear
            .overlay(Mock.texture("topo/paper").resizable().interpolation(.high).scaledToFill())
            .clipped()
    }
}

struct CartoucheFrame: View {
    var notch: CGFloat = 9
    var body: some View {
        ZStack {
            PaperFill().clipShape(NotchedRect(notch: notch))
            LinearGradient(colors: [.white.opacity(0.16), .clear, TopoInk.shadow.opacity(0.07)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(NotchedRect(notch: notch))
            NotchedRect(notch: notch).stroke(TopoInk.shadow.opacity(0.10), lineWidth: 14).blur(radius: 6)
                .clipShape(NotchedRect(notch: notch))
            NotchedRect(notch: notch, inset: 0.8).stroke(TopoInk.ink, lineWidth: 1.6)
            NotchedRect(notch: notch, inset: 4).stroke(TopoInk.ink.opacity(0.7), lineWidth: 0.5)
            CornerPips(notch: notch).fill(TopoInk.red)
        }
        .compositingGroup()
        .shadow(color: TopoInk.shadow.opacity(0.2), radius: 0.7, x: 0.4, y: 0.7)
        .shadow(color: TopoInk.shadow.opacity(0.3), radius: 4, x: 1.6, y: 3)
    }
}

/// A rectangle whose corners are cut by concave quarter circles; insets stay concentric with the outer corners.
struct NotchedRect: Shape {
    var notch: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let n = notch + inset
        let a = asin(min(inset / n, 1)), b = acos(min(inset / n, 1))
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1), (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1), (CGPoint(x: rect.minX, y: rect.maxY), 1, -1)
        ]
        var p = Path()
        for (k, (c, sx, sy)) in corners.enumerated() {
            // top-left and bottom-right run from the edge-a end to the edge-b end; the others reverse
            let forward = k % 2 == 1
            let from = forward ? a : b, to = forward ? b : a
            for i in 0...10 {
                let t = from + (to - from) * CGFloat(i) / 10
                let pt = CGPoint(x: c.x + sx * n * cos(t), y: c.y + sy * n * sin(t))
                if k == 0 && i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
        p.closeSubpath()
        return p
    }
}

struct CornerPips: Shape {
    var notch: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        let d = notch * 0.42
        for c in [CGPoint(x: r.minX + d, y: r.minY + d), CGPoint(x: r.maxX - d, y: r.minY + d),
                  CGPoint(x: r.maxX - d, y: r.maxY - d), CGPoint(x: r.minX + d, y: r.maxY - d)] {
            p.addEllipse(in: CGRect(x: c.x - 1.5, y: c.y - 1.5, width: 3, height: 3))
        }
        return p
    }
}

struct Diamond: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Section line and elevation profile (the mountain motif inside the cartouche)

/// The line of section drawn across the sheet, red dash-dot with A and A′ at its ends.
struct SectionLine: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        Canvas { ctx, _ in
            var p = Path()
            p.move(to: from); p.addLine(to: to)
            ctx.stroke(p, with: .color(TopoInk.paperLight.opacity(0.7)), lineWidth: 2.4)
            ctx.stroke(p, with: .color(TopoInk.red), style: StrokeStyle(lineWidth: 0.9, dash: [5, 1.6, 1, 1.6]))
            for (pt, s) in [(from, "A"), (to, "A\u{2032}")] {
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 1.8, y: pt.y - 1.8, width: 3.6, height: 3.6)), with: .color(TopoInk.red))
                let t = ctx.resolve(Text(s).font(TopoFont.futuraBold(7)).foregroundColor(TopoInk.red))
                ctx.draw(t, at: CGPoint(x: pt.x, y: pt.y - 3), anchor: .bottom)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The section A–A′ drawn as an engraved elevation profile: hatched silhouette, guide lines, a vertical scale.
struct ProfileStrip: View {
    let sheet: TopoSheet

    var body: some View {
        Canvas { ctx, size in draw(&ctx, size) }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let v = sheet.profile
        guard v.count > 2 else { return }
        let left: CGFloat = 20, right: CGFloat = 10, top: CGFloat = 8, bottom: CGFloat = 5
        let w = size.width - left - right, h = size.height - top - bottom
        let pts = v.indices.map { CGPoint(x: left + w * CGFloat($0) / CGFloat(v.count - 1), y: top + h * (1 - v[$0])) }
        let base = top + h

        var guides = Path()
        for k in 0...2 {
            let y = top + h * CGFloat(k) / 2
            guides.move(to: CGPoint(x: left, y: y)); guides.addLine(to: CGPoint(x: left + w, y: y))
        }
        ctx.stroke(guides, with: .color(TopoInk.inkSoft.opacity(0.35)), style: StrokeStyle(lineWidth: 0.35, dash: [1.5, 1.5]))

        var sil = Path()
        sil.move(to: CGPoint(x: left, y: base))
        TopoSheet.addSmooth(&sil, pts, continuing: true)
        sil.addLine(to: CGPoint(x: left + w, y: base))
        sil.closeSubpath()
        ctx.fill(sil, with: .linearGradient(Gradient(colors: [TopoInk.contour.opacity(0.28), TopoInk.contour.opacity(0.08)]),
                                            startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: base)))
        var hatch = Path()
        for x in stride(from: left, through: left + w, by: 1.7) {
            hatch.move(to: CGPoint(x: x, y: top)); hatch.addLine(to: CGPoint(x: x, y: base))
        }
        var c = ctx
        c.clip(to: sil)
        c.stroke(hatch, with: .color(TopoInk.contourIndex.opacity(0.5)), lineWidth: 0.35)

        var ridge = Path()
        TopoSheet.addSmooth(&ridge, pts)
        ctx.stroke(ridge, with: .color(TopoInk.contourIndex), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        var axis = Path()
        axis.move(to: CGPoint(x: left, y: top)); axis.addLine(to: CGPoint(x: left, y: base)); axis.addLine(to: CGPoint(x: left + w, y: base))
        for k in 0...2 {
            let y = top + h * CGFloat(k) / 2
            axis.move(to: CGPoint(x: left - 2.5, y: y)); axis.addLine(to: CGPoint(x: left, y: y))
        }
        ctx.stroke(axis, with: .color(TopoInk.ink), lineWidth: 0.6)

        let lo = sheet.profileRange.low, hi = sheet.profileRange.high
        for (k, e) in [(0, hi), (1, (lo + hi) / 2), (2, lo)] {
            let t = ctx.resolve(Text(verbatim: "\(e)").font(TopoFont.menlo(4.8)).foregroundColor(TopoInk.inkSoft))
            ctx.draw(t, at: CGPoint(x: left - 3.5, y: top + h * CGFloat(k) / 2), anchor: .trailing)
        }
        if let peak = pts.min(by: { $0.y < $1.y }) {
            var tri = Path()
            tri.move(to: CGPoint(x: peak.x, y: peak.y - 4.6))
            tri.addLine(to: CGPoint(x: peak.x + 2.4, y: peak.y - 1))
            tri.addLine(to: CGPoint(x: peak.x - 2.4, y: peak.y - 1))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(TopoInk.red))
        }
        let a = ctx.resolve(Text("A").font(TopoFont.futuraBold(6.5)).foregroundColor(TopoInk.red))
        ctx.draw(a, at: CGPoint(x: left + 1.5, y: top - 1), anchor: .bottomLeading)
        let a2 = ctx.resolve(Text("A\u{2032}").font(TopoFont.futuraBold(6.5)).foregroundColor(TopoInk.red))
        ctx.draw(a2, at: CGPoint(x: left + w, y: top - 1), anchor: .bottomTrailing)
        let title = ctx.resolve(Text("PROFILE A\u{2013}A\u{2032}").font(TopoFont.futuraBold(5.6)).foregroundColor(TopoInk.inkSoft))
        ctx.draw(title, at: CGPoint(x: left + w / 2, y: top - 1), anchor: .bottom)
    }
}
