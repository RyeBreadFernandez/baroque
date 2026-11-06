import SwiftUI

// Quote widgets: the quote is a burned-in subtitle over a rain-streaked pane, the city behind it gone soft into
// bokeh at the foot of the mountains, tail lights step-printed along the wet street. The source is a small mono
// line; a voice-over timestamp opens the scene; a cyan neon arrow on a glass plaque asks for the next one.

/// A big neon fixture close to the glass, cropped by the frame, with step-printed ghosts trailing it.
struct NRFixture: View {
    var color: Color = NR.red
    var core: Color = NR.redCore
    var scale: CGFloat = 1
    var ghosts = 3

    var body: some View {
        Canvas { ctx, size in
            let k = scale
            let x0 = size.width - 26 * k, y0: CGFloat = 8 * k
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x0 + x * k, y: y0 + y * k) }
            let frame = [P(0, 0), P(18, 0), P(18, 74), P(0, 74), P(0, 0)]
            let bars = [[P(5, 14), P(13, 14)], [P(5, 30), P(13, 30)], [P(5, 46), P(13, 46)]]
            let ring = NRTubeFont.arc(x0 + 9 * k, y0 + 61 * k, 4.2 * k, 4.2 * k, -90, 270)
            let tubes = ([frame] + bars + [ring]).enumerated().map { NRNeon.Tube(points: $0.element, dim: $0.offset == 2) }
            // Step-printed ghosts: the sign repeated in stutters, as the shutter dragged.
            for g in stride(from: ghosts, through: 1, by: -1) {
                ctx.drawLayer { l in
                    l.opacity = 0.5 / Double(g)
                    l.translateBy(x: -CGFloat(g) * 10 * k, y: CGFloat(g) * 1.2 * k)
                    l.addFilter(.blur(radius: 0.7 * CGFloat(g)))
                    NRNeon.draw(l, tubes: tubes, color: color, core: core, width: 1.7 * k, clips: false, glow: 0.7)
                }
            }
            NRNeon.draw(ctx, tubes: tubes, color: color, core: core, width: 1.7 * k)
        }
        .allowsHitTesting(false)
    }
}

enum NRQuoteScene {
    static let lights: [NRLight] = [NRLight(at: CGPoint(x: 0.95, y: 0.12), color: NR.red, size: 1.4),
                                    NRLight(at: CGPoint(x: 0.25, y: 0.55), color: NR.magenta, size: 1),
                                    NRLight(at: CGPoint(x: 0.6, y: 0.55), color: NR.cyan, size: 0.9)]
}

// MARK: - Large

struct NRQuoteLarge: View {
    var quote: Quote

    var body: some View {
        let size = Mock.size(.large)
        let spec = NRSceneSpec(
            far: [CGPoint(x: -0.05, y: 0.2), CGPoint(x: 0.16, y: 0.11), CGPoint(x: 0.36, y: 0.16), CGPoint(x: 0.55, y: 0.05),
                  CGPoint(x: 0.76, y: 0.14), CGPoint(x: 1.05, y: 0.09)],
            mid: [CGPoint(x: -0.05, y: 0.34), CGPoint(x: 0.12, y: 0.24), CGPoint(x: 0.3, y: 0.31), CGPoint(x: 0.46, y: 0.17),
                  CGPoint(x: 0.6, y: 0.27), CGPoint(x: 0.8, y: 0.22), CGPoint(x: 1.05, y: 0.33)],
            near: [CGPoint(x: -0.05, y: 0.42), CGPoint(x: 0.2, y: 0.38), CGPoint(x: 0.4, y: 0.43), CGPoint(x: 0.7, y: 0.39), CGPoint(x: 1.05, y: 0.44)],
            city: 0.42...0.52, street: 0.58, mast: 0.46,
            lamps: [CGPoint(x: 0.3, y: 0.4), CGPoint(x: 0.4, y: 0.33), CGPoint(x: 0.35, y: 0.28), CGPoint(x: 0.44, y: 0.22)],
            houses: 80,
            signs: [NRSign(at: CGPoint(x: 0.22, y: 0.47), kind: .vbar, color: NR.magenta, core: NR.magentaCore, scale: 1.3),
                    NRSign(at: CGPoint(x: 0.62, y: 0.5), kind: .box, color: NR.cyan, core: NR.cyanCore, scale: 1.2)],
            lights: NRQuoteScene.lights, weather: .rain, soft: true, seed: 31, tilt: -3)

        ZStack(alignment: .topLeading) {
            NRSceneView(spec: spec)
            NRFixture(scale: 1.15)
            NRGlassView(spec: NRGlassSpec(weather: .rain, seed: 41, lights: NRQuoteScene.lights))

            NRCaption(text: NRDates.stamp(Mock.now), size: 9.5)
                .padding(.leading, 16).padding(.top, 18)

            VStack(spacing: 9) {
                NRSubtitle(text: quote.text, size: 18.5, lines: 6, minScale: 0.75)
                if let a = quote.author, !a.isEmpty { NRSource(text: a, size: 9) }
            }
            .padding(.horizontal, 22)
            .frame(width: size.width, height: size.height - 58, alignment: .bottom)

            NRNeonArrow(size: 30)
                .offset(x: size.width - 16 - 30, y: size.height - 16 - 30)

            NRFilm(leak: .topTrailing, grain: 0.55)
        }
        .frame(width: size.width, height: size.height)
        .background(NR.ink)
    }
}

// MARK: - Medium

struct NRQuoteMedium: View {
    var quote: Quote

    var body: some View {
        let size = Mock.size(.medium)
        let spec = NRSceneSpec(
            far: [CGPoint(x: -0.05, y: 0.3), CGPoint(x: 0.14, y: 0.16), CGPoint(x: 0.34, y: 0.26), CGPoint(x: 0.6, y: 0.06),
                  CGPoint(x: 0.82, y: 0.2), CGPoint(x: 1.05, y: 0.12)],
            mid: [CGPoint(x: -0.05, y: 0.42), CGPoint(x: 0.2, y: 0.3), CGPoint(x: 0.4, y: 0.4), CGPoint(x: 0.56, y: 0.22),
                  CGPoint(x: 0.72, y: 0.36), CGPoint(x: 1.05, y: 0.3)],
            city: 0.46...0.6, street: 0.66, mast: 0.56,
            lamps: [CGPoint(x: 0.44, y: 0.56), CGPoint(x: 0.52, y: 0.46), CGPoint(x: 0.49, y: 0.38), CGPoint(x: 0.55, y: 0.3)],
            houses: 60,
            signs: [NRSign(at: CGPoint(x: 0.12, y: 0.55), kind: .vbar, color: NR.magenta, core: NR.magentaCore, scale: 1.1),
                    NRSign(at: CGPoint(x: 0.78, y: 0.57), kind: .arrow, color: NR.acid, core: .white, scale: 1)],
            lights: NRQuoteScene.lights, weather: .rain, soft: true, seed: 32, tilt: -2.6)

        ZStack(alignment: .topLeading) {
            NRSceneView(spec: spec)
            NRFixture(scale: 0.62, ghosts: 3)
            NRGlassView(spec: NRGlassSpec(weather: .rain, seed: 42, lights: NRQuoteScene.lights))

            NRCaption(text: NRDates.stamp(Mock.now), size: 8.5)
                .padding(.leading, 16).padding(.top, 15)

            VStack(spacing: 6) {
                NRSubtitle(text: quote.text, size: 15, lines: 3, minScale: 0.78)
                if let a = quote.author, !a.isEmpty { NRSource(text: a, size: 8.5) }
            }
            .padding(.leading, 36).padding(.trailing, 44)
            .frame(width: size.width, height: size.height - 17, alignment: .bottom)

            NRNeonArrow(size: 26)
                .offset(x: size.width - 16 - 26, y: size.height - 14 - 26)

            NRFilm(leak: .bottomTrailing, grain: 0.55)
        }
        .frame(width: size.width, height: size.height)
        .background(NR.ink)
    }
}

// MARK: - Small

struct NRQuoteSmall: View {
    var quote: Quote

    var body: some View {
        let size = Mock.size(.small)
        let spec = NRSceneSpec(
            far: [CGPoint(x: -0.05, y: 0.3), CGPoint(x: 0.3, y: 0.12), CGPoint(x: 0.55, y: 0.24), CGPoint(x: 0.8, y: 0.1), CGPoint(x: 1.05, y: 0.2)],
            mid: [CGPoint(x: -0.05, y: 0.4), CGPoint(x: 0.25, y: 0.3), CGPoint(x: 0.5, y: 0.4), CGPoint(x: 0.72, y: 0.24), CGPoint(x: 1.05, y: 0.36)],
            city: 0.42...0.52, street: 0.56, mast: 0.72,
            lamps: [CGPoint(x: 0.6, y: 0.5), CGPoint(x: 0.68, y: 0.42), CGPoint(x: 0.64, y: 0.36), CGPoint(x: 0.71, y: 0.3)],
            houses: 36,
            signs: [NRSign(at: CGPoint(x: 0.22, y: 0.5), kind: .vbar, color: NR.magenta, core: NR.magentaCore, scale: 0.9)],
            lights: NRQuoteScene.lights, weather: .rain, soft: true, seed: 33, tilt: -3.2, peakCloud: 0.8)

        ZStack(alignment: .topLeading) {
            NRSceneView(spec: spec)
            NRGlassView(spec: NRGlassSpec(weather: .rain, seed: 43, lights: NRQuoteScene.lights))

            NRCaption(text: NRDates.stamp(Mock.now), size: 8)
                .padding(.leading, 16).padding(.top, 15)

            VStack(spacing: 5) {
                NRSubtitle(text: quote.text, size: 14.5, lines: 4, minScale: 0.75)
                if let a = quote.author, !a.isEmpty { NRSource(text: a, size: 7.5) }
            }
            .padding(.horizontal, 16)
            .frame(width: size.width, height: size.height - 16, alignment: .bottom)

            NRFilm(leak: .topTrailing, grain: 0.55)
        }
        .frame(width: size.width, height: size.height)
        .background(NR.ink)
    }
}
