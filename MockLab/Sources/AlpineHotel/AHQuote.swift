import SwiftUI

// Quote widgets: the quote as an intertitle. Large is the establishing shot of the hotel on its stage, with a chapter
// card set in front of the footlights; medium is a lobby notice between two arched windows onto the range; small is
// a postage stamp on an airmail envelope.

// MARK: - Shared pieces

/// A gold-leaf ornament: rules either side of a lozenge.
struct AHOrnament: View {
    var color: Color = AH.gold
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let d = size.height / 2
            var lozenge = Path()
            lozenge.move(to: CGPoint(x: c.x, y: c.y - d)); lozenge.addLine(to: CGPoint(x: c.x + d * 1.2, y: c.y))
            lozenge.addLine(to: CGPoint(x: c.x, y: c.y + d)); lozenge.addLine(to: CGPoint(x: c.x - d * 1.2, y: c.y)); lozenge.closeSubpath()
            ctx.fill(lozenge, with: .linearGradient(Gradient(colors: [AH.goldLight, color, AH.goldDeep]), startPoint: CGPoint(x: c.x, y: c.y - d), endPoint: CGPoint(x: c.x, y: c.y + d)))
            var rules = Path()
            for s in [CGFloat(-1), 1] {
                rules.move(to: CGPoint(x: c.x + s * d * 2.2, y: c.y)); rules.addLine(to: CGPoint(x: s < 0 ? 0 : size.width, y: c.y))
                rules.addEllipse(in: CGRect(x: c.x + s * d * 2.2 - (s < 0 ? 1.6 : 0), y: c.y - 0.8, width: 1.6, height: 1.6))
            }
            ctx.stroke(rules, with: .color(color), lineWidth: 0.7)
        }
    }
}

/// The quote set as an intertitle: a spaced-caps heading, an optional script flourish, the quote centred in Futura,
/// and the source in small spaced capitals (an ornament when there is no source).
struct AHIntertitle: View {
    var quote: Quote
    var heading: String
    var flourish: String?
    var size: CGFloat
    var lines: Int
    var sourceWidth: CGFloat
    /// Body size steps down for long quotes (and the script flourish gives way), rather than scaling to fit.
    var textSize: CGFloat { quote.text.count > 150 ? size * 0.86 : quote.text.count > 100 ? size * 0.93 : size }

    var body: some View {
        VStack(spacing: 0) {
            Text(heading).ahCaps(size * 0.6, AH.raspberry, tracking: size * 0.26)
                .lineLimit(1).allowsTightening(true).minimumScaleFactor(0.8)
                .frame(height: size * 0.85)
                .layoutPriority(2)
            if let flourish, quote.text.count <= 150 {
                Text(flourish)
                    .font(AH.snell(size * 1.05))
                    .foregroundStyle(AH.burgundy)
                    .lineLimit(1)
                    .padding(.top, size * 0.02)
            }
            AHOrnament().frame(width: size * 4.6, height: size * 0.42).padding(.top, size * 0.32)
            Spacer(minLength: size * 0.45)
            Text(quote.text)
                .font(AH.futuraMed(textSize))
                .foregroundStyle(AH.plum)
                .multilineTextAlignment(.center)
                .lineSpacing(textSize * 0.14)
                .lineLimit(lines)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: size * 0.45)
            if let author = quote.author, !author.isEmpty {
                HStack(spacing: size * 0.3) {
                    Text("—")
                    Text(author.uppercased()).lineLimit(1).truncationMode(.tail)
                    Text("—")
                }
                .ahCaps(size * 0.52, AH.burgundy, tracking: size * 0.12)
                .allowsTightening(true)
                .frame(maxWidth: sourceWidth)
                .frame(height: size * 0.8)
                .layoutPriority(2)
            } else {
                AHOrnament(color: AH.raspberry).frame(width: size * 3, height: size * 0.36)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The boards of the stage in one-point perspective, toward the centre of the set.
struct AHStageFloor: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            ctx.fill(Path(r), with: .linearGradient(Gradient(colors: [Color(hex: 0xE6B79A), Color(hex: 0xC98C86), Color(hex: 0x9C6577)]),
                                                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var boards = Path()
            let vp = CGPoint(x: size.width / 2, y: -size.height * 1.4)
            for i in -14...14 {
                let x = size.width / 2 + CGFloat(i) * size.width / 13
                let t = (0 - vp.y) / (size.height - vp.y)
                boards.move(to: CGPoint(x: vp.x + (x - vp.x) * t, y: 0))
                boards.addLine(to: CGPoint(x: x, y: size.height))
            }
            ctx.stroke(boards, with: .color(Color(hex: 0x7C4A5E, opacity: 0.45)), lineWidth: 0.7)
            AHTex.lay(ctx, AHTex.gouache, in: r, opacity: 1)
            // footlight glow along the lip
            ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 14)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xFFE6B0, opacity: 0.55), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: 14)))
            ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 2.2)), with: .linearGradient(Gradient(colors: [AH.goldLight, AH.goldDeep]),
                                                                                                    startPoint: .zero, endPoint: CGPoint(x: 0, y: 2.2)))
        }
    }
}

/// Candy-striped lobby wallpaper with a damask sprig in each stripe and a gilt dado.
struct AHWallpaper: View {
    var stripe: CGFloat = 12
    var dado: CGFloat? = nil

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            ctx.fill(Path(r), with: .color(AH.wall))
            var stripes = Path(), sprigs = Path()
            var x: CGFloat = -stripe / 2
            var i = 0
            while x < size.width {
                stripes.addRect(CGRect(x: x, y: 0, width: stripe * 0.5, height: size.height))
                var y: CGFloat = CGFloat(i % 2) * stripe * 1.1
                while y < size.height {
                    let c = CGPoint(x: x + stripe * 0.75, y: y)
                    let s = stripe * 0.16
                    sprigs.move(to: CGPoint(x: c.x, y: c.y - s * 1.6)); sprigs.addLine(to: CGPoint(x: c.x + s, y: c.y))
                    sprigs.addLine(to: CGPoint(x: c.x, y: c.y + s * 1.6)); sprigs.addLine(to: CGPoint(x: c.x - s, y: c.y)); sprigs.closeSubpath()
                    y += stripe * 2.2
                }
                x += stripe
                i += 1
            }
            ctx.fill(stripes, with: .color(Color(hex: 0xF7CFD9)))
            ctx.fill(sprigs, with: .color(AH.wallDeep.opacity(0.55)))
            AHTex.lay(ctx, AHTex.gouache, in: r, opacity: 1)
            if let dado {
                ctx.fill(Path(CGRect(x: 0, y: dado, width: size.width, height: size.height - dado)),
                         with: .linearGradient(Gradient(colors: [Color(hex: 0xC3E3D3), Color(hex: 0x95C9B2)]), startPoint: CGPoint(x: 0, y: dado), endPoint: CGPoint(x: 0, y: size.height)))
                ctx.fill(Path(CGRect(x: 0, y: dado - 1.5, width: size.width, height: 3)), with: .linearGradient(Gradient(colors: [AH.goldLight, AH.goldDeep]),
                                                                                                           startPoint: CGPoint(x: 0, y: dado - 1.5), endPoint: CGPoint(x: 0, y: dado + 1.5)))
            }
        }
    }
}

// MARK: - Large

struct AHQuoteLarge: View {
    var quote: Quote
    var date: Date = Mock.now

    var body: some View {
        let s = Mock.size(.large)
        let day = Calendar.current.component(.day, from: date)
        ZStack(alignment: .topLeading) {
            AHStageFloor().ahPlace(0, 214, s.width, s.height - 214)
            AHBackdrop(spec: AHSceneSpec(sky: .clear, apex: 0.15, shoulders: 0.34, far: 0.38, base: 0.74, hills: 0.6, ledge: 0.64, meadow: 0.9,
                                         hotel: 124, cableCars: true, seed: 41))
                .ahPlace(0, 0, s.width, 216)
            AHCurtains(width: 50, tie: 0.6).ahPlace(0, 0, s.width, 216)
            AHValance(depth: 22, scallops: 9).ahPlace(0, 0, s.width, 28)

            ZStack {
                AHCard(fill: AH.lilac, rule: AH.raspberry, corner: 7, inset: 4.5)
                AHIntertitle(quote: quote, heading: "PART \(AHDates.spelled(day))",
                             flourish: "a thought for \(AHDates.string(date, "EEEE"))", size: 15, lines: 6, sourceWidth: 220)
                    .padding(.horizontal, 22)
                    .padding(.top, 15)
                    .padding(.bottom, 14)
            }
            .ahPlace(20, 178, 308, 170)

            AHBellPush(size: 38).ahPlace(296, 320, 38, 31)
        }
        .frame(width: s.width, height: s.height)
        .modifier(AHFinish())
    }
}

// MARK: - Medium

struct AHQuoteMedium: View {
    var quote: Quote
    var date: Date = Mock.now

    var body: some View {
        let s = Mock.size(.medium)
        let windows = [CGRect(x: 14, y: 16, width: 66, height: 124), CGRect(x: 268, y: 16, width: 66, height: 124)]
        ZStack(alignment: .topLeading) {
            AHWallpaper(stripe: 12, dado: 146).ahPlace(0, 0, s.width, s.height)
            // one continuous view behind the wall, seen through both windows
            AHBackdrop(spec: AHSceneSpec(sky: .clear, apex: 0.1, shoulders: 0.3, far: 0.4, base: 0.72, hills: 0.62, ledge: 0.6, meadow: 0.9,
                                         hotel: 0, funicular: false, framingPines: 0, sun: false, shoulderX: 0.14, seed: 51))
                .ahPlace(0, 0, s.width, s.height)
                .mask {
                    Canvas { ctx, _ in for w in windows { ctx.fill(AHArchWindow.opening(w), with: .color(.black)) } }
                }
            AHArchWindow(rects: windows).ahPlace(0, 0, s.width, s.height)
            AHValance(depth: 12, scallops: 12).ahPlace(0, 0, s.width, 18)

            ZStack {
                AHCard(fill: AH.card, rule: AH.raspberry, corner: 6, inset: 4)
                AHIntertitle(quote: quote, heading: "\(AHDates.string(date, "EEEE").uppercased())'S THOUGHT", flourish: nil,
                             size: 12, lines: 4, sourceWidth: 142)
                    .padding(.horizontal, 13)
                    .padding(.top, 11)
                    .padding(.bottom, 10)
            }
            .ahPlace(90, 22, 168, 124)

            AHBellPush(size: 30).ahPlace(302, 117, 30, 25)
        }
        .frame(width: s.width, height: s.height)
        .modifier(AHFinish())
    }
}

/// Arched lobby windows: cream frames with a gold bead, mullions, sills and a little swag of curtain.
struct AHArchWindow: View {
    var rects: [CGRect]

    static func opening(_ r: CGRect) -> Path {
        UnevenRoundedRectangle(cornerRadii: .init(topLeading: r.width / 2, topTrailing: r.width / 2)).path(in: r)
    }

    var body: some View {
        Canvas { ctx, _ in
            for r in rects {
                let open = AHArchWindow.opening(r)
                // reveal: the wall's thickness, shaded inside the opening
                var inner = ctx
                inner.clip(to: open)
                inner.stroke(open, with: .color(AH.plum.opacity(0.35)), lineWidth: 7)
                inner.fill(Path(CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height)),
                           with: .linearGradient(Gradient(colors: [Color.white.opacity(0.15), .clear]), startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.minY)))
                // mullions and transom
                var bars = Path()
                bars.addRect(CGRect(x: r.midX - 1, y: r.minY, width: 2, height: r.height))
                bars.addRect(CGRect(x: r.minX, y: r.minY + r.width * 0.5, width: r.width, height: 2))
                bars.addRect(CGRect(x: r.minX, y: r.minY + r.height * 0.66, width: r.width, height: 1.6))
                inner.fill(bars.offsetBy(dx: 0.8, dy: 1), with: .color(AH.plum.opacity(0.25)))
                inner.fill(bars, with: .color(AH.cream))
                // glazing reflection
                var glint = Path()
                glint.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - 8))
                glint.addLine(to: CGPoint(x: r.minX + r.width * 0.4, y: r.minY + r.width * 0.62))
                inner.stroke(glint, with: .color(Color.white.opacity(0.14)), lineWidth: 4)
                // frame
                var sh = ctx
                sh.addFilter(.blur(radius: 1.6))
                sh.stroke(open.offsetBy(dx: 1, dy: 2), with: .color(AH.plum.opacity(0.4)), lineWidth: 5)
                ctx.stroke(open, with: .color(AH.cream), lineWidth: 5)
                ctx.stroke(open, with: .color(AH.gold), lineWidth: 0.8)
                ctx.stroke(AHArchWindow.opening(r.insetBy(dx: -2.4, dy: -2.4)).offsetBy(dx: 0, dy: 2.4), with: .color(AH.wallDeep.opacity(0.8)), lineWidth: 0.6)
                // keystone
                var key = Path()
                key.move(to: CGPoint(x: r.midX - 3, y: r.minY - 4)); key.addLine(to: CGPoint(x: r.midX + 3, y: r.minY - 4))
                key.addLine(to: CGPoint(x: r.midX + 2, y: r.minY + 3)); key.addLine(to: CGPoint(x: r.midX - 2, y: r.minY + 3)); key.closeSubpath()
                ctx.fill(key, with: .linearGradient(Gradient(colors: [AH.goldLight, AH.goldDeep]), startPoint: CGPoint(x: r.midX - 3, y: 0), endPoint: CGPoint(x: r.midX + 3, y: 0)))
                // sill
                let sill = CGRect(x: r.minX - 6, y: r.maxY, width: r.width + 12, height: 4.5)
                var ss = ctx
                ss.addFilter(.blur(radius: 1.5))
                ss.fill(Path(sill.offsetBy(dx: 0, dy: 3)), with: .color(AH.plum.opacity(0.45)))
                ctx.fill(Path(sill), with: .linearGradient(Gradient(colors: [AH.cream, Color(hex: 0xE8D3C0)]), startPoint: CGPoint(x: 0, y: sill.minY), endPoint: CGPoint(x: 0, y: sill.maxY)))
                ctx.fill(Path(CGRect(x: sill.minX, y: sill.minY, width: sill.width, height: 0.8)), with: .color(Color.white))
                // curtain swags tied at the sides
                for side in [CGFloat(-1), 1] {
                    let edgeX = side < 0 ? r.minX + 2 : r.maxX - 2
                    var drape = Path()
                    drape.move(to: CGPoint(x: edgeX, y: r.minY + r.width * 0.3))
                    drape.addQuadCurve(to: CGPoint(x: edgeX - side * 1, y: r.maxY), control: CGPoint(x: edgeX - side * 11, y: r.minY + r.height * 0.62))
                    drape.addLine(to: CGPoint(x: edgeX + side * 4, y: r.maxY))
                    drape.addLine(to: CGPoint(x: edgeX + side * 4, y: r.minY + r.width * 0.2))
                    drape.closeSubpath()
                    var d = ctx
                    d.addFilter(.shadow(color: AH.plum.opacity(0.4), radius: 1.5, x: 0, y: 1))
                    d.fill(drape, with: .linearGradient(Gradient(colors: [AH.raspberryDeep, AH.raspberry, Color(hex: 0xCF5A7E)]),
                                                        startPoint: CGPoint(x: edgeX + side * 4, y: 0), endPoint: CGPoint(x: edgeX - side * 8, y: 0)))
                    let tie = CGPoint(x: edgeX - side * 4.6, y: r.minY + r.height * 0.62)
                    ctx.fill(Path(ellipseIn: CGRect(x: tie.x - 1.8, y: tie.y - 1.8, width: 3.6, height: 3.6)), with: .color(AH.gold))
                }
            }
        }
    }
}

// MARK: - Small

struct AHQuoteSmall: View {
    var quote: Quote

    var body: some View {
        let s = Mock.size(.small)
        let stamp = CGRect(x: 13, y: 12, width: 138, height: 141)
        let long = quote.text.count > 34
        let window = CGRect(x: stamp.minX + 11, y: stamp.minY + 11, width: stamp.width - 22, height: long ? 52 : 64)
        ZStack(alignment: .topLeading) {
            AHAirmail().ahPlace(0, 0, s.width, s.height)
            AHStamp(fill: AH.card, engraving: false).ahPlace(stamp.minX, stamp.minY, stamp.width, stamp.height)
            AHBackdrop(spec: AHSceneSpec(sky: .clear, apex: 0.12, shoulders: 0.32, far: 0.36, base: 0.72, hills: 0.6, ledge: 0.66, meadow: 0.92,
                                         hotel: 50, sign: false, framingPines: 0.75, pineScale: 0.7, sunSize: 0.1, seed: 61))
                .ahPlace(window.minX, window.minY, window.width, window.height)
                .overlay {
                    Rectangle().strokeBorder(AH.raspberry, lineWidth: 0.9)
                        .ahPlace(window.minX, window.minY, window.width, window.height)
                }
            AHPostmark(top: "HOTEL TERRA", bottom: "PAR AVION", center: "★", waves: 3)
                .rotationEffect(.degrees(-10))
                .ahPlace(103, 16, 50, 30)
            VStack(spacing: 3) {
                Text(quote.text)
                    .font(AH.futura(long ? 11 : 11.5))
                    .foregroundStyle(AH.plum)
                    .multilineTextAlignment(.center)
                    .lineSpacing(0.5)
                    .lineLimit(long ? 4 : 3)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if let a = quote.author, !a.isEmpty {
                    Text(a.uppercased()).ahCaps(6.8, AH.burgundy, tracking: 0.9).lineLimit(1).truncationMode(.tail).allowsTightening(true)
                } else {
                    AHOrnament(color: AH.raspberry).frame(width: 34, height: 5)
                }
            }
            .padding(.horizontal, 2)
            .ahPlace(window.minX + 2, window.maxY + 6, window.width - 4, stamp.maxY - window.maxY - 6 - 11)
        }
        .frame(width: s.width, height: s.height)
        .modifier(AHFinish())
    }
}

/// An airmail envelope: cream laid paper with a border of raspberry and powder-blue chevrons.
struct AHAirmail: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            ctx.fill(Path(r), with: .color(Color(hex: 0xF6E9DC)))
            AHTex.lay(ctx, AHTex.paper, in: r, opacity: 1)
            let band: CGFloat = 7, step: CGFloat = 9
            var red = Path(), blue = Path()
            var i = 0
            var t: CGFloat = -step
            let per = (size.width + size.height) * 2
            while t < per {
                // chevrons around the edge: parallelograms along each side
                for (k, edge) in [(0, CGRect(x: 0, y: 0, width: size.width, height: band)), (1, CGRect(x: 0, y: size.height - band, width: size.width, height: band))] {
                    let x = t
                    if x > size.width + step { continue }
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: edge.minY)); p.addLine(to: CGPoint(x: x + step * 0.5, y: edge.minY))
                    p.addLine(to: CGPoint(x: x + step * 0.5 - band * (k == 0 ? 1 : -1), y: edge.maxY)); p.addLine(to: CGPoint(x: x - band * (k == 0 ? 1 : -1), y: edge.maxY)); p.closeSubpath()
                    if i % 2 == 0 { red.addPath(p) } else { blue.addPath(p) }
                }
                for (k, edge) in [(0, CGRect(x: 0, y: 0, width: band, height: size.height)), (1, CGRect(x: size.width - band, y: 0, width: band, height: size.height))] {
                    let y = t
                    if y > size.height + step { continue }
                    var p = Path()
                    p.move(to: CGPoint(x: edge.minX, y: y)); p.addLine(to: CGPoint(x: edge.minX, y: y + step * 0.5))
                    p.addLine(to: CGPoint(x: edge.maxX, y: y + step * 0.5 - band * (k == 0 ? 1 : -1))); p.addLine(to: CGPoint(x: edge.maxX, y: y - band * (k == 0 ? 1 : -1))); p.closeSubpath()
                    if i % 2 == 0 { red.addPath(p) } else { blue.addPath(p) }
                }
                t += step * 0.5
                i += 1
            }
            var c = ctx
            c.clip(to: Path(r).subtracting(Path(r.insetBy(dx: band, dy: band))))
            c.fill(red, with: .color(AH.raspberry))
            c.fill(blue, with: .color(Color(hex: 0x7FA6D6)))
            AHTex.lay(c, AHTex.paper, in: r, opacity: 1)
            ctx.stroke(Path(r.insetBy(dx: band + 0.5, dy: band + 0.5)), with: .color(AH.gold.opacity(0.7)), lineWidth: 0.6)
        }
    }
}
