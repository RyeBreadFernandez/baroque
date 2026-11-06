import SwiftUI

// Props on the miniature set: embroidered patches with merrowed borders, satin-stitch lettering, typed text,
// rubber stamps, numbered callouts, card stock, a clipboard, a brass nameplate and an enamel button.
// Each prop's Canvas is padded out so its cast shadow is not clipped.

// MARK: - Embroidered patch

enum EXPatchShape {
    case circle
    case rounded(CGFloat)
}

struct EXPatch<Content: View>: View {
    var shape: EXPatchShape = .circle
    var fill: Color
    var border: Color
    var borderShade: Color
    var seed: UInt64 = 1
    @ViewBuilder var content: Content

    private let pad: CGFloat = 8

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let kit = EXKit(ctx)
                let rect = CGRect(x: pad, y: pad, width: size.width - pad * 2, height: size.height - pad * 2)
                let bw: CGFloat = 4.4
                let path: Path
                let band: Path
                let groove: Path
                var ring: [(CGPoint, CGPoint)] = []
                switch shape {
                case .circle:
                    path = Path(ellipseIn: rect)
                    band = Path(ellipseIn: rect.insetBy(dx: bw / 2, dy: bw / 2))
                    groove = Path(ellipseIn: rect.insetBy(dx: bw + 0.5, dy: bw + 0.5))
                    let r = rect.width / 2
                    let c = CGPoint(x: rect.midX, y: rect.midY)
                    let n = Int(2 * .pi * r / 0.8)
                    for i in 0..<n {
                        let a = CGFloat(i) / CGFloat(n) * 2 * .pi
                        let nv = CGPoint(x: cos(a), y: sin(a))
                        ring.append((c.exPlus(nv.exScaled(r)), nv))
                    }
                case .rounded(let rad):
                    path = Path(roundedRect: rect, cornerRadius: rad)
                    band = Path(roundedRect: rect.insetBy(dx: bw / 2, dy: bw / 2), cornerRadius: max(1, rad - bw / 2))
                    groove = Path(roundedRect: rect.insetBy(dx: bw + 0.5, dy: bw + 0.5), cornerRadius: max(1, rad - bw))
                    ring = EXGeo.roundedRectRing(rect, radius: rad, step: 0.8)
                }
                EXCraft.felt(ctx, path, edge: [], closed: true,
                             style: EXFeltStyle(color: fill, lift: 2.0, fuzz: 0, nap: 0.42, puff: 0.5, fibres: 0.3),
                             kit: kit, seed: seed)
                // Twill weave of the patch ground.
                var tw = ctx
                tw.clip(to: path)
                var hatch = Path()
                var x = -rect.height
                while x < size.width {
                    hatch.move(to: CGPoint(x: x, y: size.height))
                    hatch.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += 1.5
                }
                tw.stroke(hatch, with: .color(.white.opacity(0.07)), lineWidth: 0.5)
                tw.stroke(hatch.offsetBy(dx: 0.7, dy: 0), with: .color(.black.opacity(0.07)), lineWidth: 0.4)
                // Raised merrowed border: a band of thread, then the overlocking stitches across it.
                var gr = ctx
                gr.addFilter(.blur(radius: 0.7))
                gr.stroke(groove, with: .color(EX.shadow.opacity(0.45)), lineWidth: 1.2)
                ctx.stroke(band, with: .color(border), lineWidth: bw)
                var a = Path(), b = Path()
                for (i, (p, nv)) in ring.enumerated() {
                    let tng = CGPoint(x: -nv.y, y: nv.x)
                    let inner = p.exMinus(nv.exScaled(bw + 0.2)).exMinus(tng.exScaled(0.5))
                    let outer = p.exPlus(nv.exScaled(0.3)).exPlus(tng.exScaled(0.5))
                    if i % 2 == 0 { a.move(to: inner); a.addLine(to: outer) } else { b.move(to: inner); b.addLine(to: outer) }
                }
                ctx.stroke(a, with: .color(.white.opacity(0.22)), lineWidth: 0.45)
                ctx.stroke(b, with: .color(borderShade.opacity(0.85)), lineWidth: 0.5)
                ctx.stroke(band, with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.32), .clear, EX.shadow.opacity(0.35)]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)), lineWidth: bw)
            }
            .padding(-pad)
            content
        }
    }
}

// MARK: - Lettering

/// Satin-stitch lettering: the glyphs filled with fine slanted thread and raised off the ground.
struct EXStitchedText: View {
    var text: String
    var font: Font
    var color: Color
    var kerning: CGFloat = 0

    var body: some View {
        Text(text)
            .font(font)
            .kerning(kerning)
            .foregroundStyle(color)
            .overlay {
                EXSatin().mask { Text(text).font(font).kerning(kerning) }
            }
            .shadow(color: EX.shadow.opacity(0.6), radius: 0.3, x: 0.4, y: 0.8)
    }
}

struct EXSatin: View {
    var body: some View {
        Canvas { ctx, size in
            var light = Path(), dark = Path()
            var x = -size.height
            var i = 0
            while x < size.width + size.height {
                let p0 = CGPoint(x: x, y: size.height), p1 = CGPoint(x: x + size.height * 0.55, y: 0)
                if i % 2 == 0 { light.move(to: p0); light.addLine(to: p1) } else { dark.move(to: p0); dark.addLine(to: p1) }
                x += 0.85
                i += 1
            }
            ctx.stroke(light, with: .color(.white.opacity(0.24)), lineWidth: 0.4)
            ctx.stroke(dark, with: .color(.black.opacity(0.2)), lineWidth: 0.4)
        }
    }
}

extension View {
    /// Typewriter ink: a hair of bleed into the paper.
    func exInk(_ color: Color = EX.ink) -> some View {
        foregroundStyle(color).shadow(color: color.opacity(0.35), radius: 0.25)
    }
}

/// A rubber stamp: condensed caps in a ruled box, worn ink, pressed slightly crooked.
struct EXStamp: View {
    var text: String
    var color: Color
    var angle: Double = -3
    var size: CGFloat = 9
    var filled = false

    var body: some View {
        Text(text)
            .font(EX.head(size))
            .kerning(0.8)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(filled ? EX.creamLight : color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.2)
            .background {
                if filled { RoundedRectangle(cornerRadius: 1.8).fill(color) }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 1.8).strokeBorder(color, lineWidth: 1.1)
                    .padding(-1.6)
            }
            .padding(1.6)
            .mask { EX.tex("stampwear").resizable() }
            .rotationEffect(.degrees(angle))
    }
}

/// A numbered callout, the kind a cutaway diagram uses.
struct EXCallout: View {
    var n: Int
    var size: CGFloat = 14
    var fill: Color = EX.cream
    var ink: Color = EX.ink

    var body: some View {
        Text("\(n)")
            .font(EX.futura(size * 0.6))
            .foregroundStyle(ink)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(ink, lineWidth: 1))
            .shadow(color: EX.shadow.opacity(0.4), radius: 0.6, x: 0.4, y: 0.8)
    }
}

// MARK: - Card stock

/// Cream card stock with a cast shadow: index cards, catalog cards, typed labels.
struct EXCardStock: View {
    var seed: UInt64 = 1
    var lift: CGFloat = 2.2
    var corner: CGFloat = 2.5
    var rules: (start: CGFloat, step: CGFloat)? = nil
    var header: CGFloat? = nil
    var margin: CGFloat? = nil
    var hole = false
    var tint: Color? = nil

    private let pad: CGFloat = 10

    var body: some View {
        Canvas { ctx, size in
            let kit = EXKit(ctx)
            let r = CGRect(x: pad, y: pad, width: size.width - pad * 2, height: size.height - pad * 2)
            let shape = Path(roundedRect: r, cornerRadius: corner)
            var cast = ctx
            cast.addFilter(.blur(radius: lift * 1.3))
            cast.fill(shape.offsetBy(dx: lift * 0.6, dy: lift * 1.1), with: .color(EX.shadow.opacity(0.45)))
            var contact = ctx
            contact.addFilter(.blur(radius: 0.6))
            contact.fill(shape.offsetBy(dx: 0.3, dy: 0.6), with: .color(EX.shadow.opacity(0.35)))
            var c = ctx
            c.clip(to: shape)
            var rng = SeededRandom(seed: seed)
            let tw = max(320, r.width), th = max(280, r.height)
            c.draw(kit.card, in: CGRect(x: r.minX - rng.range(0...(tw - r.width)), y: r.minY - rng.range(0...(th - r.height)), width: tw, height: th))
            if let tint { c.fill(Path(r), with: .color(tint)) }
            if let rules {
                var lines = Path()
                var y = r.minY + rules.start
                while y < r.maxY - 4 {
                    lines.move(to: CGPoint(x: r.minX, y: y))
                    lines.addLine(to: CGPoint(x: r.maxX, y: y))
                    y += rules.step
                }
                c.stroke(lines, with: .color(Color(hex: 0x6E9AB0).opacity(0.38)), lineWidth: 0.5)
            }
            if let margin {
                var m = Path()
                m.move(to: CGPoint(x: r.minX + margin, y: r.minY))
                m.addLine(to: CGPoint(x: r.minX + margin, y: r.maxY))
                c.stroke(m, with: .color(EX.tomato.opacity(0.45)), lineWidth: 0.6)
            }
            if let header {
                var h = Path()
                h.move(to: CGPoint(x: r.minX, y: r.minY + header))
                h.addLine(to: CGPoint(x: r.maxX, y: r.minY + header))
                c.stroke(h, with: .color(EX.tomato.opacity(0.85)), lineWidth: 0.9)
                c.stroke(h.offsetBy(dx: 0, dy: 2.2), with: .color(EX.tomato.opacity(0.6)), lineWidth: 0.5)
            }
            // The card bows a little toward the key light.
            c.fill(Path(r), with: .linearGradient(
                Gradient(colors: [.white.opacity(0.16), .clear, EX.shadow.opacity(0.10)]),
                startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
            if hole {
                let hc = CGPoint(x: r.midX, y: r.maxY - 9)
                let hr = CGRect(x: hc.x - 4, y: hc.y - 4, width: 8, height: 8)
                c.fill(Path(ellipseIn: hr), with: .color(EX.shadow.opacity(0.75)))
                c.fill(Path(ellipseIn: hr.offsetBy(dx: 0.8, dy: 1.2)), with: .color(EX.shadow.opacity(0.5)))
                c.stroke(Path(ellipseIn: hr.insetBy(dx: -0.4, dy: -0.4)), with: .color(.white.opacity(0.45)), lineWidth: 0.6)
            }
            var rim = ctx
            rim.clip(to: shape)
            rim.stroke(shape, with: .color(.white.opacity(0.55)), lineWidth: 1.2)
            ctx.stroke(shape, with: .color(EX.shadow.opacity(0.25)), lineWidth: 0.4)
        }
        .padding(-pad)
    }
}

// MARK: - Wood and brass

/// A walnut clipboard with a brass lever clip at the top centre.
struct EXClipboard: View {
    var clipWidth: CGFloat = 46
    private let pad: CGFloat = 10

    var body: some View {
        Canvas { ctx, size in
            let kit = EXKit(ctx)
            let r = CGRect(x: pad, y: pad, width: size.width - pad * 2, height: size.height - pad * 2)
            let shape = Path(roundedRect: r, cornerRadius: 7)
            var cast = ctx
            cast.addFilter(.blur(radius: 3))
            cast.fill(shape.offsetBy(dx: 1.8, dy: 3.2), with: .color(EX.shadow.opacity(0.55)))
            var c = ctx
            c.clip(to: shape)
            c.draw(kit.walnut, in: CGRect(x: r.minX - 6, y: r.minY - 4, width: 360, height: 200))
            c.fill(Path(r), with: .linearGradient(Gradient(colors: [.white.opacity(0.12), .clear, EX.shadow.opacity(0.2)]),
                                                  startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
            // Rounded edge: bright lip at the top-left, dark at the bottom-right.
            var hi = c
            hi.addFilter(.blur(radius: 0.8))
            hi.stroke(shape.offsetBy(dx: 1, dy: 1.2), with: .color(.white.opacity(0.3)), lineWidth: 1.4)
            var lo = c
            lo.addFilter(.blur(radius: 1))
            lo.stroke(shape.offsetBy(dx: -1, dy: -1.2), with: .color(.black.opacity(0.45)), lineWidth: 1.8)
        }
        .padding(-pad)
    }
}

/// The lever clip, drawn separately so it sits on top of the sheet.
struct EXBoardClip: View {
    private let pad: CGFloat = 6
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(x: pad, y: pad, width: size.width - pad * 2, height: size.height - pad * 2)
            let plate = Path(roundedRect: CGRect(x: r.minX, y: r.minY + r.height * 0.28, width: r.width, height: r.height * 0.72), cornerRadius: 3)
            var sh = ctx
            sh.addFilter(.blur(radius: 1.6))
            sh.fill(plate.offsetBy(dx: 1.2, dy: 2.2), with: .color(EX.shadow.opacity(0.55)))
            let brass = Gradient(stops: [.init(color: EX.brassLight, location: 0), .init(color: EX.brass, location: 0.45),
                                         .init(color: EX.brassDeep, location: 1)])
            ctx.fill(plate, with: .linearGradient(brass, startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.minX, y: r.maxY)))
            ctx.stroke(plate, with: .color(EX.brassDeep), lineWidth: 0.6)
            // The lever: a rounded bar across the top.
            let lever = Path(roundedRect: CGRect(x: r.minX + r.width * 0.18, y: r.minY, width: r.width * 0.64, height: r.height * 0.4), cornerRadius: r.height * 0.2)
            ctx.fill(lever.offsetBy(dx: 0.6, dy: 1), with: .color(EX.shadow.opacity(0.4)))
            ctx.fill(lever, with: .linearGradient(brass, startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.minX, y: r.minY + r.height * 0.4)))
            ctx.stroke(lever, with: .color(EX.brassDeep), lineWidth: 0.5)
            // Rivets.
            for fx in [0.12, 0.88] as [CGFloat] {
                let p = CGPoint(x: r.minX + r.width * fx, y: r.minY + r.height * 0.66)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.6, y: p.y - 1.6, width: 3.2, height: 3.2)), with: .color(EX.brassDeep))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.1, y: p.y - 1.3, width: 1.6, height: 1.4)), with: .color(EX.brassLight))
            }
        }
        .padding(-pad)
    }
}

/// A brushed-brass nameplate with screws at both ends.
struct EXBrassPlate: View {
    private let pad: CGFloat = 6
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(x: pad, y: pad, width: size.width - pad * 2, height: size.height - pad * 2)
            let shape = Path(roundedRect: r, cornerRadius: 2.5)
            var sh = ctx
            sh.addFilter(.blur(radius: 1.2))
            sh.fill(shape.offsetBy(dx: 0.8, dy: 1.4), with: .color(.black.opacity(0.55)))
            ctx.fill(shape, with: .linearGradient(Gradient(stops: [
                .init(color: EX.brassLight, location: 0), .init(color: EX.brass, location: 0.35),
                .init(color: Color(hex: 0xA9822F), location: 0.7), .init(color: EX.brassLight.opacity(0.9), location: 1)]),
                startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
            var c = ctx
            c.clip(to: shape)
            var rng = SeededRandom(seed: 9)
            var brush = Path()
            var y = r.minY
            while y < r.maxY {
                brush.move(to: CGPoint(x: r.minX, y: y))
                brush.addLine(to: CGPoint(x: r.maxX, y: y))
                y += rng.range(0.5...1.1)
            }
            c.stroke(brush, with: .color(.white.opacity(0.12)), lineWidth: 0.3)
            c.stroke(brush.offsetBy(dx: 0, dy: 0.35), with: .color(EX.brassDeep.opacity(0.15)), lineWidth: 0.3)
            let inner = Path(roundedRect: r.insetBy(dx: 2.2, dy: 2.2), cornerRadius: 1.5)
            ctx.stroke(inner, with: .color(EX.brassDeep.opacity(0.7)), lineWidth: 0.5)
            ctx.stroke(inner.offsetBy(dx: 0.4, dy: 0.5), with: .color(.white.opacity(0.35)), lineWidth: 0.4)
            ctx.stroke(shape, with: .color(EX.brassDeep), lineWidth: 0.5)
            for fx in [r.minX + 6, r.maxX - 6] {
                let p = CGPoint(x: fx, y: r.midY)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(EX.brassDeep))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.6, y: p.y - 1.8, width: 3.2, height: 3.2)), with: .color(EX.brassLight))
                var slot = Path()
                slot.move(to: CGPoint(x: p.x - 1.4, y: p.y + 0.9))
                slot.addLine(to: CGPoint(x: p.x + 1.4, y: p.y - 0.9))
                ctx.stroke(slot, with: .color(EX.brassDeep), lineWidth: 0.6)
            }
        }
        .padding(-pad)
    }
}

/// A round enamel button with a brass rim and a cream arrow: the next-quote control.
struct EXEnamelButton: View {
    var diameter: CGFloat = 32
    private let pad: CGFloat = 6

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = diameter / 2
            func disc(_ rr: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)) }
            var sh = ctx
            sh.addFilter(.blur(radius: 2))
            sh.fill(disc(r).offsetBy(dx: 1.4, dy: 2.4), with: .color(EX.shadow.opacity(0.55)))
            ctx.fill(disc(r), with: .linearGradient(Gradient(stops: [
                .init(color: EX.brassLight, location: 0), .init(color: EX.brass, location: 0.45), .init(color: EX.brassDeep, location: 1)]),
                startPoint: CGPoint(x: c.x - r, y: c.y - r), endPoint: CGPoint(x: c.x + r, y: c.y + r)))
            ctx.stroke(disc(r - 0.4), with: .color(EX.brassDeep), lineWidth: 0.6)
            let er = r - 3
            ctx.fill(disc(er).offsetBy(dx: -0.5, dy: -0.6), with: .color(EX.brassDeep.opacity(0.9)))
            ctx.fill(disc(er), with: .radialGradient(Gradient(colors: [Color(hex: 0xE2574A), EX.tomato, EX.tomatoDeep]),
                                                     center: CGPoint(x: c.x - er * 0.35, y: c.y - er * 0.4), startRadius: 0, endRadius: er * 1.5))
            // Arrow, enamelled in cream and slightly proud of the surface.
            var arrow = Path()
            let s = er * 0.5
            arrow.move(to: CGPoint(x: c.x - s, y: c.y))
            arrow.addLine(to: CGPoint(x: c.x + s * 0.55, y: c.y))
            arrow.move(to: CGPoint(x: c.x + s * 0.05, y: c.y - s * 0.6))
            arrow.addLine(to: CGPoint(x: c.x + s * 0.7, y: c.y))
            arrow.addLine(to: CGPoint(x: c.x + s * 0.05, y: c.y + s * 0.6))
            let st = StrokeStyle(lineWidth: er * 0.2, lineCap: .round, lineJoin: .round)
            ctx.stroke(arrow.offsetBy(dx: 0.5, dy: 0.8), with: .color(EX.shadow.opacity(0.5)), style: st)
            ctx.stroke(arrow, with: .color(EX.creamLight), style: st)
            // Gloss.
            var g = ctx
            g.clip(to: disc(er))
            g.fill(Path(ellipseIn: CGRect(x: c.x - er * 0.85, y: c.y - er * 0.95, width: er * 1.3, height: er * 0.8)),
                   with: .linearGradient(Gradient(colors: [.white.opacity(0.42), .white.opacity(0)]),
                                         startPoint: CGPoint(x: c.x, y: c.y - er), endPoint: CGPoint(x: c.x, y: c.y - er * 0.1)))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - er * 0.55, y: c.y - er * 0.62, width: 2.4, height: 1.8)), with: .color(.white.opacity(0.85)))
        }
        .frame(width: diameter + pad * 2, height: diameter + pad * 2)
        .padding(-pad)
    }
}
