import SwiftUI

// Quote widgets: large is the stage itself (valance, tied-back curtains, the hotel on its ledge with cable cars) with
// the quote on a lilac chapter card; medium is a framed notice on the lobby wall between two arched windows that look
// out on the range; small is an airmail stamp. The quote widgets have no weather, so their sky follows the clock only.

enum GHQuoteScenes {
    private static func k(_ pts: [(CGFloat, CGFloat)]) -> [CGPoint] { pts.map { CGPoint(x: $0.0, y: $0.1) } }

    static func large(_ now: Date) -> GHSceneSpec {
        GHSceneSpec(
            now: now, horizon: 0.38,
            back: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.33), (0.07, 0.28), (0.14, 0.30), (0.22, 0.25), (0.3, 0.285), (0.38, 0.24), (0.5, 0.26),
                                                        (0.62, 0.24), (0.7, 0.285), (0.78, 0.25), (0.86, 0.30), (0.93, 0.28), (1, 0.33)]), seed: 61),
                        top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.55, snowline: 0.27),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.44), (0.14, 0.40), (0.26, 0.34), (0.34, 0.26), (0.41, 0.19), (0.46, 0.145), (0.5, 0.12),
                                                        (0.54, 0.145), (0.59, 0.19), (0.66, 0.26), (0.74, 0.34), (0.86, 0.40), (1, 0.44)]), seed: 63, roughness: 0.15),
                        top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.7, snowline: 0.225),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.41), (0.1, 0.385), (0.2, 0.40), (0.3, 0.43), (0.4, 0.45), (0.5, 0.46), (0.6, 0.45),
                                                        (0.7, 0.43), (0.8, 0.40), (0.9, 0.385), (1, 0.41)]), seed: 67),
                        top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.45,
                        trees: Trees(height: 5...9, spacing: 5, coverage: 0.7), treeColor: GH.pine)
            ],
            front: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.43), (0.08, 0.445), (0.16, 0.47), (0.26, 0.50), (0.36, 0.53), (0.5, 0.55), (0.64, 0.53),
                                                        (0.74, 0.50), (0.84, 0.47), (0.92, 0.445), (1, 0.43)]), seed: 69),
                        top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.4,
                        trees: Trees(height: 9...15, spacing: 6, coverage: 0.85), treeColor: GH.pineDark)
            ],
            hotel: GHHotelSpec(base: 0.37, width: 132, ledgeBottom: 0.56, cableCars: 0.235),
            arc: SkyArc(centerX: 0.5, horizon: 0.36, radiusX: 0.3, radiusY: 0.25),
            bodyRadius: 10,
            stars: CGRect(x: 0.2, y: 0.08, width: 0.6, height: 0.15), starCount: 14,
            mist: 0.44)
    }

    /// One continuous view behind the lobby wall, seen through both windows; the sun or moon stands in the east window
    /// before midday and the west one after.
    static func windows(_ now: Date) -> GHSceneSpec {
        let clock = SkyClock(now: now, weather: nil)
        return GHSceneSpec(
            now: now, horizon: 0.62,
            back: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.54), (0.05, 0.45), (0.09, 0.40), (0.15, 0.36), (0.2, 0.41), (0.25, 0.47), (0.3, 0.54),
                                                        (0.5, 0.56), (0.7, 0.54), (0.75, 0.47), (0.8, 0.41), (0.85, 0.36), (0.91, 0.40), (0.95, 0.45),
                                                        (1, 0.54)]), seed: 71),
                        top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.55, snowline: 0.44),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.62), (0.04, 0.53), (0.08, 0.45), (0.12, 0.51), (0.17, 0.43), (0.22, 0.53), (0.28, 0.62),
                                                        (0.5, 0.66), (0.72, 0.62), (0.78, 0.53), (0.83, 0.43), (0.88, 0.51), (0.92, 0.45), (0.96, 0.53),
                                                        (1, 0.62)]), seed: 73, roughness: 0.15),
                        top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.7, snowline: 0.5),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.70), (0.06, 0.66), (0.12, 0.70), (0.18, 0.66), (0.24, 0.70), (0.5, 0.75), (0.76, 0.70),
                                                        (0.82, 0.66), (0.88, 0.70), (0.94, 0.66), (1, 0.70)]), seed: 75),
                        top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.45,
                        trees: Trees(height: 6...10, spacing: 5, coverage: 0.75), treeColor: GH.pine)
            ],
            front: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.77), (0.08, 0.79), (0.16, 0.75), (0.24, 0.80), (0.5, 0.83), (0.76, 0.80), (0.84, 0.75),
                                                        (0.92, 0.79), (1, 0.77)]), seed: 77),
                        top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.4,
                        trees: Trees(height: 10...16, spacing: 6, coverage: 0.85), treeColor: GH.pineDark)
            ],
            arc: SkyArc(centerX: 0.5, horizon: 0.6, radiusX: 0.38, radiusY: 0.4),
            bodyRadius: 8, bodyAt: CGPoint(x: clock.progress < 0.5 ? 0.13 : 0.87, y: 0.255),
            stars: CGRect(x: 0.06, y: 0.16, width: 0.88, height: 0.18), starCount: 18,
            mist: 0.72, weatherRegion: .zero)
    }

    /// The vignette inside the airmail stamp.
    static func stamp(_ now: Date) -> GHSceneSpec {
        GHSceneSpec(
            now: now, horizon: 0.7,
            back: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.5), (0.12, 0.38), (0.25, 0.44), (0.38, 0.30), (0.5, 0.36), (0.62, 0.30), (0.75, 0.44),
                                                        (0.88, 0.38), (1, 0.5)]), seed: 81),
                        top: GHRidgeColors.far.top, bottom: GHRidgeColors.far.bottom, rim: 0.55, snowline: 0.42),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.8), (0.2, 0.62), (0.32, 0.46), (0.42, 0.30), (0.5, 0.22), (0.58, 0.30), (0.68, 0.46),
                                                        (0.8, 0.62), (1, 0.8)]), seed: 83, roughness: 0.15),
                        top: GHRidgeColors.peak.top, bottom: GHRidgeColors.peak.bottom, rim: 0.7, snowline: 0.42),
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.72), (0.2, 0.66), (0.4, 0.72), (0.5, 0.75), (0.6, 0.72), (0.8, 0.66), (1, 0.72)]), seed: 85),
                        top: GHRidgeColors.hill.top, bottom: GHRidgeColors.hill.bottom, rim: 0.45,
                        trees: Trees(height: 10...16, spacing: 9, coverage: 0.75), treeColor: GH.pine)
            ],
            front: [
                GHLayer(profile: RidgeProfile(keys: k([(0, 0.74), (0.15, 0.80), (0.3, 0.88), (0.5, 0.93), (0.7, 0.88), (0.85, 0.80), (1, 0.74)]), seed: 87),
                        top: GHRidgeColors.near.top, bottom: GHRidgeColors.near.bottom, rim: 0.4,
                        trees: Trees(height: 18...26, spacing: 12, coverage: 0.85), treeColor: GH.pineDark)
            ],
            hotel: GHHotelSpec(base: 0.75, width: 46, ledgeBottom: 1.05),
            arc: SkyArc(centerX: 0.5, horizon: 0.7, radiusX: 0.36, radiusY: 0.5),
            bodyRadius: 16,
            stars: CGRect(x: 0.15, y: 0.1, width: 0.7, height: 0.25), starCount: 8,
            mist: 0.8, weatherRegion: .zero)
    }
}

struct GHQuoteWidget: View {
    var quote: Quote
    var family: Family
    var now: Date = Mock.now

    var body: some View {
        switch family {
        case .small: GHQuoteSmall(quote: quote, now: now)
        case .medium: GHQuoteMedium(quote: quote, now: now)
        case .large: GHQuoteLarge(quote: quote, now: now)
        }
    }
}

/// The quote in serif, at the largest size that shows all of it; truncated with an ellipsis at the smallest.
struct GHQuoteText: View {
    var text: String
    var sizes: [CGFloat]
    var color: Color = GH.plum
    var alignment: TextAlignment = .center

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes, id: \.self) { s in line(s) }
            line(sizes.last ?? 11)
                .truncationMode(.tail)
                .frame(maxHeight: .infinity)
        }
    }

    private func line(_ size: CGFloat) -> some View {
        Text(text)
            .font(Serif.font(size, weight: .medium))
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineSpacing(size > 15 ? 2 : 1)
            .ghPressed()
    }
}

/// "— GEORGE ORWELL, 1984 —"
struct GHAuthor: View {
    var author: String?
    var size: CGFloat = 8.5

    var body: some View {
        if let a = author, !a.isEmpty {
            // Dashes and wide tracking when there is room; plain, then tighter, then truncated at the tail.
            ViewThatFits(in: .horizontal) {
                line("—  \(a.uppercased())  —", tracking: size * 0.18)
                line(a.uppercased(), tracking: size * 0.18)
                line(a.uppercased(), tracking: size * 0.06)
                line(a.uppercased(), tracking: size * 0.06).truncationMode(.tail)
            }
        }
    }

    private func line(_ s: String, tracking: CGFloat) -> some View {
        Text(s)
            .ghCaps(size, GH.burgundy, tracking: tracking)
            .ghPressed()
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Large

struct GHQuoteLarge: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let s = Mock.size(.large)
        let day = Calendar.current.component(.day, from: now)
        ZStack(alignment: .topLeading) {
            GHScene(spec: GHQuoteScenes.large(now))
                .frame(width: s.width, height: s.height)
            GHCurtains(width: 52, tie: 0.4).ghPlace(0, 0, s.width, s.height)
            GoldFrame(inset: 6, ornament: false)
            GHValance(depth: 22, scallops: 9).ghPlace(0, 0, s.width, 30)

            VStack(spacing: 0) {
                Text("PART \(GHDates.spelled(day))")
                    .ghCaps(9, GH.raspberry, tracking: 3)
                    .ghPressed()
                    .lineLimit(1)
                Text("with the compliments of the house")
                    .font(Serif.font(13.5, weight: .medium, italic: true))
                    .foregroundStyle(GH.burgundy)
                    .ghPressed()
                    .lineLimit(1)
                    .padding(.top, 2)
                GHFlourish(width: 120)
                    .padding(.top, 5)
                    .padding(.bottom, 4)
                GHQuoteText(text: quote.text, sizes: [18, 17, 16, 15, 14, 13, 12])
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)
                GHAuthor(author: quote.author)
                    .frame(maxWidth: 232)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 11)
            .ghSlab(.lilac, radius: 10, depth: 3)
            .ghPlace(20, 186, 308, 163)

            GHDeskBell(size: 34).ghPlace(298, 320, 34, 29)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

// MARK: - Medium

/// The lobby wall: painted striped paper above a mint wainscot with a gilt rail.
struct GHLobbyWall: View {
    var dado: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color(hex: 0xEFB2C3)
                    .overlay(GHTex.wall.resizable().interpolation(.high).scaledToFill())
                    .overlay(CanvasWeave(opacity: 0.8))
                    .overlay(LinearGradient(colors: [Color(hex: 0xFFF0DC).opacity(0.18), .clear, GH.shadow.opacity(0.18)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipped()
                GHSurface(material: .mint)
                    .overlay(GHMaterial.mint.lighting)
                    .overlay(alignment: .top) {
                        VStack(spacing: 0) {
                            Rectangle().fill(LinearGradient(colors: [GH.goldLight, GH.gold, GH.goldDeep], startPoint: .top, endPoint: .bottom)).frame(height: 3)
                            Rectangle().fill(GH.shadow.opacity(0.35)).frame(height: 1)
                        }
                    }
                    .frame(height: geo.size.height - dado)
                    .offset(y: dado)
                    .shadow(color: GH.shadow.opacity(0.3), radius: 2, x: 0, y: -1)
            }
        }
    }
}

/// Arched windows: a carved reveal, cream glazing bars, a gilt frame, a cream sill, and tied-back velvet curtains.
struct GHWindowFrames: View {
    var rects: [CGRect]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(rects.enumerated()), id: \.offset) { _, r in
                ZStack {
                    // reveal: the shadow inside the opening's upper lip
                    GHArch()
                        .stroke(GH.shadow.opacity(0.6), lineWidth: 6)
                        .blur(radius: 2.4)
                        .offset(y: 1.8)
                        .clipShape(GHArch())
                    Canvas { ctx, size in
                        let w = size.width, h = size.height
                        var bars = Path()
                        bars.addRect(CGRect(x: w / 2 - 1, y: 0, width: 2, height: h))
                        bars.addRect(CGRect(x: 0, y: h * 0.48, width: w, height: 2))
                        bars.addRect(CGRect(x: 0, y: h * 0.74, width: w, height: 1.6))
                        var c = ctx
                        c.clip(to: GHArch().path(in: CGRect(origin: .zero, size: size)))
                        c.fill(bars.offsetBy(dx: 0.8, dy: 1.2), with: .color(GH.shadow.opacity(0.35)))
                        c.fill(bars, with: .color(GH.cream))
                        c.stroke(GHArch().path(in: CGRect(x: w * 0.18, y: h * 0.06, width: w * 0.64, height: h * 0.42)), with: .color(GH.cream), lineWidth: 1.2)
                    }
                    // gilt frame with a lit chamfer
                    GHSurface(material: .brass, weave: 0.4)
                        .mask(GHArch().inset(by: -3).stroke(lineWidth: 4.5))
                        .overlay(GHArch().inset(by: -5.2).stroke(LinearGradient(colors: [Stone.goldBright.opacity(0.8), GH.shadow.opacity(0.5)],
                                                                                 startPoint: .top, endPoint: .bottom), lineWidth: 0.7))
                        .shadow(color: GH.shadow.opacity(0.45), radius: 2, x: 0, y: 2)
                }
                .ghPlace(r.minX, r.minY, r.width, r.height)
                // the sill
                Color.clear
                    .ghSlab(.cream, radius: 2, depth: 2, inlay: false)
                    .ghPlace(r.minX - 6, r.maxY - 1, r.width + 12, 6)
                GHCurtains(width: 15, tie: 0.62)
                    .ghPlace(r.minX - 6, r.minY - 4, r.width + 12, r.height + 2)
            }
        }
    }
}

/// A notice on cream card in a gilt frame: the quote, headed for the guests.
struct GHNotice: View {
    var quote: Quote

    var body: some View {
        VStack(spacing: 0) {
            Text("NOTICE TO GUESTS")
                .ghCaps(8.5, GH.raspberry, tracking: 1.9)
                .ghPressed()
                .lineLimit(1)
            GHFlourish(width: 76)
                .padding(.top, 4)
                .padding(.bottom, 4)
            GHQuoteText(text: quote.text, sizes: [14.5, 13.5, 12.5, 11.5, 11, 10.5])
                .frame(maxHeight: .infinity)
                .layoutPriority(1)
            GHAuthor(author: quote.author, size: 8)
                .padding(.top, 3)
        }
        .padding(.horizontal, 12)
        .padding(.top, 11)
        .padding(.bottom, 10)
        .ghSlab(.cream, radius: 3, depth: 3, inlay: false)
        .overlay {
            // the gilt moulding round the card
            ZStack {
                GHSurface(material: .brass, weave: 0.4)
                    .mask(RoundedRectangle(cornerRadius: 3).strokeBorder(lineWidth: 4.5))
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(LinearGradient(colors: [Stone.goldBright.opacity(0.85), .clear, GH.shadow.opacity(0.55)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
                RoundedRectangle(cornerRadius: 1.5)
                    .inset(by: 4.5)
                    .strokeBorder(LinearGradient(colors: [GH.shadow.opacity(0.55), .clear, Color.white.opacity(0.6)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
                RoundedRectangle(cornerRadius: 1)
                    .inset(by: 7)
                    .stroke(GH.gold.opacity(0.7), lineWidth: 0.5)
            }
            .allowsHitTesting(false)
        }
    }
}

struct GHQuoteMedium: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let s = Mock.size(.medium)
        let windows = [CGRect(x: 20, y: 26, width: 56, height: 104), CGRect(x: 272, y: 26, width: 56, height: 104)]
        ZStack(alignment: .topLeading) {
            GHLobbyWall(dado: 138).frame(width: s.width, height: s.height)
            GHScene(spec: GHQuoteScenes.windows(now))
                .frame(width: s.width, height: s.height)
                .mask {
                    Canvas { ctx, _ in
                        for w in windows { ctx.fill(GHArch().path(in: w), with: .color(.black)) }
                    }
                }
            GHWindowFrames(rects: windows)
            GoldFrame(inset: 6, ornament: false)
            GHValance(depth: 12, scallops: 12).ghPlace(0, 0, s.width, 20)
            GHNotice(quote: quote).ghPlace(94, 22, 160, 126)
            GHDeskBell(size: 30).ghPlace(302, 122, 30, 26)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}

// MARK: - Small

/// An airmail envelope: cream paper with a painted border of raspberry and powder-blue bars.
struct GHAirmail: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            ctx.fill(Path(r), with: .color(GHMaterial.cream.base))
            ctx.draw(ctx.resolve(GHTex.cream), in: r.insetBy(dx: -10, dy: -10))
            let band: CGFloat = 10
            var inner = Path(r)
            inner.addRect(r.insetBy(dx: band, dy: band))
            var c = ctx
            c.clip(to: inner, style: FillStyle(eoFill: true))
            var red = Path(), blue = Path()
            let pitch: CGFloat = 13
            var x: CGFloat = -size.height
            var i = 0
            while x < size.width + size.height {
                var bar = Path()
                bar.move(to: CGPoint(x: x, y: 0))
                bar.addLine(to: CGPoint(x: x + pitch * 0.5, y: 0))
                bar.addLine(to: CGPoint(x: x + pitch * 0.5 + size.height, y: size.height))
                bar.addLine(to: CGPoint(x: x + size.height, y: size.height))
                bar.closeSubpath()
                if i % 2 == 0 { red.addPath(bar) } else { blue.addPath(bar) }
                x += pitch
                i += 1
            }
            var rc = c
            rc.clip(to: red)
            rc.draw(rc.resolve(GHTex.raspberry), in: r)
            var bc = c
            bc.clip(to: blue)
            bc.fill(Path(r), with: .color(Color(hex: 0x86A9D8)))
            bc.opacity = 0.9
            bc.draw(bc.resolve(GHTex.skyRelief), in: r.insetBy(dx: -30, dy: -30))
            c.fill(Path(r), with: .linearGradient(Gradient(colors: [Color.white.opacity(0.15), GH.shadow.opacity(0.15)]),
                                                 startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
        }
        .overlay(CanvasWeave(opacity: 0.7))
    }
}

struct GHQuoteSmall: View {
    var quote: Quote
    var now: Date

    var body: some View {
        let s = Mock.size(.small)
        let hasAuthor = !(quote.author ?? "").isEmpty
        ZStack(alignment: .topLeading) {
            GHAirmail().frame(width: s.width, height: s.height)
            VStack(spacing: 0) {
                GHScene(spec: GHQuoteScenes.stamp(now))
                    .frame(height: 54)
                    .clipShape(Rectangle())
                    .overlay(Rectangle().strokeBorder(LinearGradient(colors: [GH.shadow.opacity(0.6), .clear, Color.white.opacity(0.7)],
                                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .overlay(Rectangle().inset(by: 2.5).stroke(GH.goldLight.opacity(0.8), lineWidth: 0.5))
                    .padding(.bottom, 6)
                GHQuoteText(text: quote.text, sizes: [14, 13, 12, 11, 10], color: GH.plum)
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)
                if hasAuthor {
                    GHAuthor(author: quote.author, size: 8)
                        .padding(.top, 3)
                }
            }
            .padding(6)
            .padding(.bottom, 1)
            .ghSlab(.cream, shape: GHPerforated(hole: 1.8), depth: 2, inlay: false)
            .ghPlace(14, 14, 136, 136)
            GHPostmark(year: nil, diameter: 22, waves: 2)
                .rotationEffect(.degrees(-8))
                .ghPlace(104, 12, 50, 22)
        }
        .frame(width: s.width, height: s.height)
        .overlay(SlabBevel())
    }
}
