import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        // CE_STATES_DIR=/some/folder renders the states the board doesn't show, and leaves out/ alone.
        if CEStates.renderIfRequested() { return }
        WeatherRunner.run(WCelestial())
    }
}

struct WCelestial: WeatherMock {
    let name = "Celestial"
    let slug = "weather-celestial"
    let tagline = "An engraved astrolabe in navy lacquer and gold: the sun rides the day ring from the east point to the west over an engraved Matterhorn, the month runs round the brass limb, and the tasks are a star chart."

    func weather(_ snapshot: DaySnapshot, family: Family) -> some View { CEWeather(snapshot: snapshot, family: family) }
    func todo(_ snapshot: DaySnapshot, family: Family) -> some View { CETodo(snapshot: snapshot, family: family) }
    func wallpaper() -> some View { CEWallpaper() }
}

/// The home screen behind the board: a darker painted night than the widgets, with the faint engraved circles of a
/// celestial chart and a few constellations.
struct CEWallpaper: View {
    var body: some View {
        Color(hex: 0x060B1A)
            .overlay {
                Mock.texture("weather-celestial/wallpaper")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            }
            .overlay {
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    var rings = Path()
                    for r in [0.36, 0.52, 0.53, 0.78] { rings.addPath(CEEngrave.circle(c, size.width * r)) }
                    var ecl = Path(ellipseIn: CGRect(x: -size.width * 0.3, y: -size.width * 0.2, width: size.width * 1.6, height: size.width * 0.4))
                    ecl = ecl.applying(CGAffineTransform(translationX: -c.x, y: -c.y).concatenating(CGAffineTransform(rotationAngle: -0.42))
                        .concatenating(CGAffineTransform(translationX: c.x, y: c.y + size.height * 0.06)))
                    rings.addPath(ecl)
                    for a in stride(from: 0.0, to: 360, by: 30) {
                        rings.move(to: CEEngrave.point(c, size.width * 0.53, a))
                        rings.addLine(to: CEEngrave.point(c, size.width * 0.78, a))
                    }
                    ctx.stroke(rings, with: .color(CE.gold.opacity(0.13)), lineWidth: 0.7)
                    // A few constellations, dotted.
                    let figures: [[CGPoint]] = [
                        [CGPoint(x: 0.08, y: 0.06), CGPoint(x: 0.15, y: 0.1), CGPoint(x: 0.21, y: 0.08), CGPoint(x: 0.27, y: 0.13), CGPoint(x: 0.33, y: 0.11)],
                        [CGPoint(x: 0.88, y: 0.82), CGPoint(x: 0.93, y: 0.88), CGPoint(x: 0.86, y: 0.93), CGPoint(x: 0.8, y: 0.9)]
                    ]
                    for f in figures {
                        var p = Path()
                        p.addLines(f.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                        ctx.stroke(p, with: .color(CE.gold.opacity(0.3)), style: StrokeStyle(lineWidth: 0.6, dash: [2, 3]))
                        for s in f {
                            let q = CGPoint(x: s.x * size.width, y: s.y * size.height)
                            CEEngrave.glow(ctx, q, 6, CE.goldBright, 0.35)
                            ctx.fill(CEEngrave.star(q, 2.6), with: .color(CE.goldBright.opacity(0.85)))
                        }
                    }
                }
            }
            .clipped()
    }
}
