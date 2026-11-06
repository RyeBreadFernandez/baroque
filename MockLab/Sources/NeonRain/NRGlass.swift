import SwiftUI

// The pane in front of the street: breath-fog condensation, beads with specular highlights and refracted neon,
// and (only when it rains) run-down streaks that wipe clean trails through the fog.
// Then the film: halated grain, a vignette and a warm leak at the gate.
//
// Blend modes inside a Canvas only mix with that Canvas's own pixels, so every layer that has to mix with the
// street beneath it (the fog's screen, the grain's soft light, the leak) is its own view with `.blendMode`.

struct NRGlassSpec {
    var weather: NRWeather = .clear
    var seed: UInt64 = 7
    var lights: [NRLight] = []     // the colours the beads refract, by position
    var keepClear: [CGRect] = []   // text areas the bigger drops stay off (points)
    var wipes: [CGRect] = []       // patches wiped clear of condensation by a hand (points)
    var fog: Double = 1
}

enum NRGlass {
    struct Drop { var c: CGPoint; var r: CGFloat }

    /// Where the beads sit and where the run-downs ran: deterministic for a seed and size.
    static func layout(size: CGSize, spec: NRGlassSpec) -> (drops: [Drop], trails: [[CGPoint]]) {
        var rng = SeededRandom(seed: spec.seed)
        let R = CGRect(origin: .zero, size: size)
        let rain = spec.weather == .rain
        let snow = spec.weather == .snow
        let area = R.width * R.height
        let beads = rain ? Int(area / 380) : (snow ? Int(area / 2000) : Int(area / 1500))
        var drops: [Drop] = []
        var tries = 0
        while drops.count < beads && tries < beads * 6 {
            tries += 1
            let r = rain ? pow(rng.unit(), 2.2) * 3.0 + 0.6 : pow(rng.unit(), 2.6) * 2.0 + 0.55
            let c = CGPoint(x: rng.unit() * R.width, y: rng.unit() * R.height)
            if r > 1.1 && spec.keepClear.contains(where: { $0.insetBy(dx: -r, dy: -r).contains(c) }) { continue }
            drops.append(Drop(c: c, r: r))
        }
        var trails: [[CGPoint]] = []
        if rain {
            var made = 0
            var attempts = 0
            while made < Int(R.width / 46) + 2 && attempts < 60 {
                attempts += 1
                let x = rng.unit() * R.width
                let y1 = rng.range(0.35...1.05) * R.height
                let len = rng.range(30...110)
                if spec.keepClear.contains(where: { $0.insetBy(dx: -3, dy: 0).contains(CGPoint(x: x, y: y1 - len * 0.5)) }) { continue }
                var pts: [CGPoint] = []
                var px = x
                var y = max(-4, y1 - len)
                while y < y1 {
                    pts.append(CGPoint(x: px, y: y))
                    px += rng.range(-0.35...0.35)
                    y += 3
                }
                if pts.count > 2 {
                    trails.append(pts)
                    drops.append(Drop(c: CGPoint(x: px, y: y1 + 1), r: rng.range(2.2...3.3)))
                    made += 1
                }
            }
        }
        return (drops, trails)
    }

    /// Breath fog, tinted by the cool light, with the drops and trails wiped through it. Drawn on its own and screened.
    static func paintFog(_ ctx: GraphicsContext, size: CGSize, spec: NRGlassSpec) {
        let (drops, trails) = layout(size: size, spec: spec)
        let R = CGRect(origin: .zero, size: size)
        var img = ctx.resolve(Mock.texture("neon-rain/fog").renderingMode(.template))
        img.shading = .color(Color(hex: 0xA7CEC4))
        var l = ctx
        l.opacity = (spec.weather == .rain ? 0.42 : (spec.weather == .snow ? 0.7 : 0.5)) * spec.fog
        l.draw(img, in: CGRect(x: 0, y: 0, width: max(348, size.width), height: max(365, size.height)))
        if spec.weather == .snow {
            // Frost creeping in from the corners.
            l.fill(Path(R), with: .radialGradient(Gradient(colors: [.clear, .clear, Color(hex: 0xDDF2EE).opacity(0.55)]),
                                                 center: CGPoint(x: R.midX, y: R.midY), startRadius: 0, endRadius: max(R.width, R.height) * 0.75))
        }
        l.opacity = 1
        l.blendMode = .destinationOut
        // Hand-wiped patches: soft edges, and the arcs a palm leaves at the rim of the wipe.
        var wrng = SeededRandom(seed: spec.seed &+ 99)
        for w in spec.wipes {
            l.drawLayer { k in
                k.addFilter(.blur(radius: 7))
                k.fill(Path(roundedRect: w, cornerRadius: min(w.width, w.height) * 0.3), with: .color(.black))
            }
            l.drawLayer { k in
                k.addFilter(.blur(radius: 1.6))
                for i in 0..<3 {
                    let y = w.minY + CGFloat(i) * w.height * 0.4 + wrng.range(-3...3)
                    var arc = Path()
                    arc.move(to: CGPoint(x: w.minX - 4, y: y + 4))
                    arc.addQuadCurve(to: CGPoint(x: w.maxX + 4, y: y + wrng.range(-2...4)), control: CGPoint(x: w.midX, y: y - 9))
                    k.stroke(arc, with: .color(.black.opacity(0.5)), style: StrokeStyle(lineWidth: wrng.range(4...7), lineCap: .round))
                }
            }
        }
        for t in trails {
            l.stroke(NRNeon.path(t), with: .color(.black), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
        }
        for d in drops {
            l.fill(Path(ellipseIn: CGRect(x: d.c.x - d.r * 1.35, y: d.c.y - d.r * 1.35, width: d.r * 2.7, height: d.r * 2.7)), with: .color(.black.opacity(0.85)))
        }
    }

    static func paintDrops(_ ctx: GraphicsContext, size: CGSize, spec: NRGlassSpec) {
        let (drops, trails) = layout(size: size, spec: spec)
        // Trails: a cleared channel with a bright edge on one side and beads left behind.
        for t in trails {
            let p = NRNeon.path(t)
            let tc = tint(at: t.last!, size: size, spec: spec)
            ctx.stroke(p, with: .color(.black.opacity(0.12)), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 0.35))
                l.stroke(p.offsetBy(dx: -1.1, dy: 0), with: .color(.white.opacity(0.2)), style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
                l.stroke(p.offsetBy(dx: 1.1, dy: 0), with: .color(tc.opacity(0.3)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
            }
            for (i, q) in t.enumerated() where i % 5 == 3 {
                drop(ctx, Drop(c: CGPoint(x: q.x + 0.3, y: q.y), r: 0.55), color: tint(at: q, size: size, spec: spec))
            }
        }
        for d in drops { drop(ctx, d, color: tint(at: d.c, size: size, spec: spec)) }
    }

    /// The colour a bead refracts: the nearest light, else the street's sodium.
    static func tint(at p: CGPoint, size: CGSize, spec: NRGlassSpec) -> Color {
        var best = NR.sodium
        var bestD = CGFloat.greatestFiniteMagnitude
        for L in spec.lights {
            let d = abs(L.at.x * size.width - p.x) + abs(L.at.y * size.height - p.y) * 0.4
            if d < bestD { bestD = d; best = L.color }
        }
        return bestD < size.width * 0.3 ? best : NR.sodium
    }

    /// One bead: contact shadow, a dark lens body, the refracted light pooled at the bottom, rim, specular.
    static func drop(_ ctx: GraphicsContext, _ d: Drop, color: Color) {
        let r = d.r, c = d.c
        let body = CGRect(x: c.x - r, y: c.y - r * 0.98, width: r * 2, height: r * 2.08)
        // Contact shadow on the far side of the pane, then a lens that darkens toward its rim and stays clear in the middle.
        ctx.fill(Path(ellipseIn: body.offsetBy(dx: r * 0.15, dy: r * 0.28)), with: .color(.black.opacity(0.22)))
        ctx.fill(Path(ellipseIn: body), with: .radialGradient(Gradient(stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.45),
                                                                              .init(color: Color(hex: 0x020707).opacity(0.5), location: 1)]),
                                                              center: CGPoint(x: c.x, y: c.y - r * 0.15), startRadius: 0, endRadius: r * 1.05))
        // The lens shows the street upside down: light pools in the lower half.
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.74, y: c.y + r * 0.02, width: r * 1.48, height: r * 0.9)),
                 with: .radialGradient(Gradient(colors: [color.opacity(0.95), color.opacity(0.4), color.opacity(0)]),
                                       center: CGPoint(x: c.x + r * 0.08, y: c.y + r * 0.55), startRadius: 0, endRadius: r * 0.85))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.28, y: c.y + r * 0.5, width: r * 0.56, height: r * 0.24)), with: .color(.white.opacity(0.5)))
        ctx.stroke(Path(ellipseIn: body), with: .color(.black.opacity(0.32)), lineWidth: max(0.22, r * 0.1))
        let s = max(0.35, r * 0.26)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.45 - s / 2, y: c.y - r * 0.5 - s / 2, width: s, height: s * 0.85)), with: .color(.white.opacity(0.95)))
        if r > 1.6 {
            ctx.fill(Path(ellipseIn: CGRect(x: c.x + r * 0.2, y: c.y - r * 0.62, width: r * 0.3, height: r * 0.16)), with: .color(.white.opacity(0.35)))
        }
    }
}

struct NRGlassView: View {
    var spec: NRGlassSpec
    var body: some View {
        ZStack {
            Canvas { ctx, size in NRGlass.paintFog(ctx, size: size, spec: spec) }
                .blendMode(.screen)
            Canvas { ctx, size in NRGlass.paintDrops(ctx, size: size, spec: spec) }
        }
        .allowsHitTesting(false)
    }
}

/// Film finish over the whole frame: vignette, a warm leak at one edge of the gate, and grain.
struct NRFilm: View {
    var leak: UnitPoint = .topTrailing
    var grain: Double = 0.55

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let R = CGRect(origin: .zero, size: size)
                // Vignette, heavier at the bottom like an old wide lens.
                ctx.fill(Path(R), with: .radialGradient(Gradient(stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.58),
                                                                         .init(color: .black.opacity(0.5), location: 1)]),
                                                         center: CGPoint(x: R.midX, y: R.midY * 0.9), startRadius: 0,
                                                         endRadius: hypot(R.width, R.height) * 0.6))
            }
            Canvas { ctx, size in
                let R = CGRect(origin: .zero, size: size)
                let lp = CGPoint(x: leak.x * R.width, y: leak.y * R.height)
                ctx.fill(Path(R), with: .radialGradient(Gradient(colors: [NR.halation.opacity(0.3), Color(hex: 0xFF8A3A).opacity(0.08), .clear]),
                                                        center: lp, startRadius: 0, endRadius: max(R.width, R.height) * 0.55))
            }
            .blendMode(.screen)
            Canvas { ctx, size in
                ctx.opacity = grain
                ctx.draw(ctx.resolve(Mock.texture("neon-rain/grain")), in: CGRect(x: 0, y: 0, width: max(348, size.width), height: max(365, size.height)))
            }
            .blendMode(.softLight)
        }
        .allowsHitTesting(false)
    }
}
