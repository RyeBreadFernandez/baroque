import SwiftUI

@main
struct Main {
    @MainActor static func main() {
        // AH_STATES_DIR=/some/folder renders the states the demo board doesn't show, and leaves out/ alone.
        if AHStates.renderIfRequested() { return }
        MockRunner.run(AlpineHotel())
    }
}

/// Alpine Hotel: every widget is a miniature film set shot head-on. A gouache matte painting of a pastel alpine range
/// with a pink grand hotel on its ledge, a raspberry velvet proscenium, and brass and paper props in front.
struct AlpineHotel: MockAesthetic {
    let name = "Alpine Hotel"
    let slug = "alpine-hotel"
    let tagline = "A confectionery grand hotel on a pastel alpine ledge, staged head-on under a velvet valance: the date on a postage stamp, the weather on a brass barometer, tasks as numbered room keys in the register, and quotes as chapter cards."

    @ViewBuilder func day(_ snapshot: DaySnapshot, family: Family) -> some View {
        AHDayWidget(snapshot: snapshot, family: family)
    }

    @ViewBuilder func quote(_ quote: Quote, family: Family) -> some View {
        AHQuoteWidget(quote: quote, family: family)
    }

    func wallpaper() -> some View { AHBoardWallpaper() }
}

struct AHDayWidget: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        switch family {
        case .small: AHDaySmall(snap: snapshot)
        case .medium: AHDayMedium(snap: snapshot)
        case .large: AHDayLarge(snap: snapshot)
        }
    }
}

struct AHQuoteWidget: View {
    var quote: Quote
    var family: Family

    var body: some View {
        switch family {
        case .small: AHQuoteSmall(quote: quote)
        case .medium: AHQuoteMedium(quote: quote)
        case .large: AHQuoteLarge(quote: quote)
        }
    }
}

/// The home screen behind the board: the hotel corridor's raspberry velvet stripes under a soft vignette, dark
/// enough that the pastel widgets stand off it.
struct AHBoardWallpaper: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            ctx.fill(Path(r), with: .color(Color(hex: 0x7E2244)))
            var stripes = Path(), sprigs = Path()
            let stripe: CGFloat = 30
            var x: CGFloat = 0
            var i = 0
            while x < size.width {
                stripes.addRect(CGRect(x: x, y: 0, width: stripe * 0.5, height: size.height))
                var y: CGFloat = CGFloat(i % 2) * stripe
                while y < size.height {
                    let c = CGPoint(x: x + stripe * 0.75, y: y), d: CGFloat = 4
                    sprigs.move(to: CGPoint(x: c.x, y: c.y - d * 1.6)); sprigs.addLine(to: CGPoint(x: c.x + d, y: c.y))
                    sprigs.addLine(to: CGPoint(x: c.x, y: c.y + d * 1.6)); sprigs.addLine(to: CGPoint(x: c.x - d, y: c.y)); sprigs.closeSubpath()
                    y += stripe * 2
                }
                x += stripe
                i += 1
            }
            ctx.fill(stripes, with: .color(Color(hex: 0x922B52)))
            ctx.fill(sprigs, with: .color(AH.gold.opacity(0.55)))
            var g = ctx
            g.blendMode = .softLight
            g.draw(g.resolve(AHTex.gouache), in: r)
            ctx.fill(Path(r), with: .radialGradient(Gradient(colors: [.clear, Color(hex: 0x2A0A1A, opacity: 0.55)]),
                                                     center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: 220, endRadius: 760))
        }
    }
}

@MainActor
enum AHStates {
    /// Returns true when it rendered the states (and the normal run should be skipped).
    static func renderIfRequested() -> Bool {
        guard let path = ProcessInfo.processInfo.environment["AH_STATES_DIR"], !path.isEmpty else { return false }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let base = Mock.day
        let error = "GitHub returned 401. Check the token in Settings."
        func with(_ f: (inout DaySnapshot) -> Void) -> DaySnapshot { var s = base; f(&s); return s }

        let days: [(String, DaySnapshot)] = [
            ("empty", with { $0.tasks = [] }),
            ("error-cached", with { $0.taskError = error }),
            ("error-empty", with { $0.tasks = []; $0.taskError = error }),
            ("no-weather", with { $0.weather = nil; $0.weatherError = "Offline" }),
            ("rain", with { $0.weather?.code = 63; $0.weather?.temperature = 51; $0.weather?.high = 54; $0.weather?.low = 46 }),
            ("snow", with { $0.weather?.code = 73; $0.weather?.temperature = 28; $0.weather?.high = 31; $0.weather?.low = 19 }),
            ("fog", with { $0.weather?.code = 45 }),
            ("one-task", with { $0.tasks = Array(base.tasks.prefix(1)) }),
            ("late-date", with { $0.date = Calendar.current.date(byAdding: .day, value: 20, to: base.date) ?? base.date })
        ]
        for (name, snap) in days {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { AHDayWidget(snapshot: snap, family: f) }, scale: 3,
                                 to: dir.appendingPathComponent("day-\(name)-\(f.rawValue).png"))
            }
        }

        let long = Quote(text: "The mountains are not there to be conquered. Climb slowly, keep the hotel lights in view, and remember that every summit is only a very large stair you have agreed to take one step at a time, all afternoon.",
                         author: "A guest of the hotel, written in the register at the end of a very long season")
        let quotes: [(String, Quote)] = [
            ("long", long),
            ("no-author", DemoData.quotes[2]),
            ("long-no-author", Quote(text: long.text, author: nil)),
            ("orwell", DemoData.quotes[0])
        ]
        for (name, q) in quotes {
            for f in Family.allCases {
                MockRunner.write(WidgetTile(family: f) { AHQuoteWidget(quote: q, family: f) }, scale: 3,
                                 to: dir.appendingPathComponent("quote-\(name)-\(f.rawValue).png"))
            }
        }
        print("Rendered Alpine Hotel states to \(dir.path)")
        return true
    }
}
