import SwiftUI
import AppKit

// The home screen built round Sun Arc (brief of 2026-11-04). Page one: the large Weather widget is the only widget,
// with a quote set under the temperature like the caption under a painting, and eight apps. Page two: a checkerboard of
// small widgets and blocks of four apps, as in the user's Pinterest reference: the to-do list, a painting, and a stack
// holding the days ahead and tonight's moon. Twenty apps on the pages (8 + 12) and four in the dock, each a custom
// icon: a raised taupe tile with its glyph carved in (the raised-slab construction of the earlier painted widgets),
// on a Baroque sepia cloudscape like the reference's.
//
//     SA_HOME=1 swift run --scratch-path .build-sa-home WSunArc             -> out/weather-sun-arc-home/matterhorn/
//     SA_HOME=1 SA_SCENE=<scene> swift run --scratch-path ... WSunArc        -> out/weather-sun-arc-home/<scene>/
//
// The forecast, the hour the rain starts, moonrise and the change in daylight are demo values: the app does not fetch
// them yet (Open-Meteo's daily and hourly forecast and a local moon calculation would supply them, free).

// MARK: - Page one's widget: Sun Arc with a quote

/// Sun Arc's large layout with the ground below the ridge shared: the gilt temperature and the weather notes on one
/// line, then a hairline and the quote, its gilt opening mark hanging in the margin, the author in spaced capitals
/// after the last word and the next-quote button at the end of the rule.
struct SAWeatherQuote: View {
    var snap: DaySnapshot
    var quote: Quote

    var body: some View {
        let r = SAReading(snap)
        let size = Mock.size(.large)
        let arc = SACanvas.large.arc
        let left = arc.point(0, in: size), right = arc.point(1, in: size)
        ZStack(alignment: .topLeading) {
            SAScene(canvas: .large, snap: snap)
            SADateline(month: r.month, day: SAWords.day(snap.date), size: 9)
                .saBaseline(x: 16, y: 25, in: size)
            if let feet = r.feet {
                SAFoot(rise: feet.left.rise, time: feet.left.time, light: r.light, markFirst: true, size: 13.5)
                    .saCenterY(leading: left.x - 7.3, y: 221, in: size)
                SAFoot(rise: feet.right.rise, time: feet.right.time, light: r.light, markFirst: false, size: 13.5)
                    .saCenterY(trailing: right.x + 7.3, y: 221, in: size)
            }
            SAGilt(text: SAWords.tempText(snap.weather, size: 76), light: r.light, depth: 0.85)
                .saBaseline(x: 16, y: 293, in: size)
            SAQuoteNotes(r: r)
                .frame(width: 180, alignment: .leading)
                .saBaseline(x: 152, y: 259, in: size)
            SAQuoteBand(quote: quote, light: r.light)
                .frame(width: 316, alignment: .topLeading)
                .offset(x: 16, y: 306)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The condition, high and low, and the next sun time, beside the temperature.
struct SAQuoteNotes: View {
    var r: SAReading

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let w = r.snap.weather {
                Text(SAWords.condition(w))
                    .font(SAType.italic(19))
                    .foregroundStyle(CoverInk.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(SAWords.highLow(w))
                    .coverLabel(9.5, CoverInk.creamSoft)
                    .padding(.top, 4)
                if let n = r.next {
                    Group {
                        if r.clock.isDay {
                            Text("sunset in \(SAWords.span(n.wait))")
                        } else {
                            Text("\(n.rise ? "sunrise" : "sunset") \(n.time)")
                        }
                    }
                    .font(SAType.italic(12.5))
                    .foregroundStyle(CoverInk.creamSoft)
                    .padding(.top, 4)
                }
            } else {
                Text("weather offline")
                    .font(SAType.italic(19))
                    .foregroundStyle(CoverInk.creamSoft)
                Text(r.snap.weatherError ?? "no weather yet")
                    .coverLabel(9.5, CoverInk.peach)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
        .coverOnPaint(0.6)
    }
}

/// The caption: a cream hairline with the next-quote button at its end, then the quote in italic.
struct SAQuoteBand: View {
    var quote: Quote
    var light: CoverLight

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SARule()
                .padding(.trailing, 26)
                .overlay(alignment: .trailing) {
                    CoverNextButton()
                        .scaleEffect(0.7)
                        .frame(width: 18, height: 18)
                }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                // A gilt opening mark hung in the margin, its tail level with the words' capitals.
                SAGilt(text: Text("\u{201C}").font(SAType.serif(30)), light: light, depth: 0.35)
                    .alignmentGuide(.firstTextBaseline) { $0[.firstTextBaseline] - 9 }
                words
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 9)
        }
        .coverOnPaint(0.6)
    }

    private var words: Text {
        let text = Text(quote.text).font(SAType.italic(13.5)).foregroundColor(CoverInk.cream)
        guard let author = quote.author, !author.isEmpty else { return text }
        return text + Text("   —  \(author.uppercased())").font(SAType.label(7.5)).tracking(1.3).foregroundColor(CoverInk.creamFaint)
    }
}

// MARK: - Page two's small widgets

/// A small canvas from Textures/weather-sun-arc/home, glazed for the time of day (fair-weather glazes) with the
/// varnish, craquelure and weave, and no frame.
struct SASmallGround: View {
    var name: String
    var light: CoverLight

    var body: some View {
        ZStack {
            SAPaint(lower: Mock.texture("weather-sun-arc/home/\(name)-lo"), upper: Mock.texture("weather-sun-arc/home/\(name)-hi"),
                    glow: nil, light: light, center: UnitPoint(x: 0.75, y: 0.05), reach: 260, seed: UInt64(name.count) &* 17)
            CanvasWeave(opacity: 0.8)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A weather mark in gilt, from SF Symbols (light weight, so it reads as engraved line work).
struct SAGlyph: View {
    var name: String
    var light: CoverLight
    var size: CGFloat

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .light))
            .foregroundStyle(LinearGradient(colors: [light.rim, light.gild[1], light.gild[2]], startPoint: .top, endPoint: .bottom))
            .shadow(color: CoverInk.shadow.opacity(0.7), radius: 1, x: 0, y: 0.8)
    }
}

struct SAForecastDay {
    var offset: Int
    var symbol: String
    var high: Int
    var low: Int
    var rain: Int
}

enum SAForecast {
    /// Demo: the four days after the snapshot's.
    static let days: [SAForecastDay] = [
        SAForecastDay(offset: 1, symbol: "cloud.rain", high: 61, low: 49, rain: 80),
        SAForecastDay(offset: 2, symbol: "cloud.sun", high: 63, low: 50, rain: 20),
        SAForecastDay(offset: 3, symbol: "sun.max", high: 69, low: 52, rain: 0),
        SAForecastDay(offset: 4, symbol: "sun.max", high: 71, low: 53, rain: 0),
    ]
    /// Demo: the hour tomorrow's rain begins.
    static let rainFrom = "2 pm"

    /// "tomorrow", then "the 6th", "the 7th": no weekday names.
    static func name(_ offset: Int, from date: Date) -> String {
        if offset == 1 { return "tomorrow" }
        let cal = Calendar.current
        let n = cal.component(.day, from: cal.date(byAdding: .day, value: offset, to: date) ?? date)
        let suffix: String
        switch (n % 10, n % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "the \(n)\(suffix)"
    }
}

/// The days ahead: the next rain as the headline over the painted sky, then four days on the dark ground (italic
/// name, gilt mark, high and low), ruled with the arc's dashes.
struct SAForecastSmall: View {
    var snap: DaySnapshot

    var body: some View {
        let light = CoverLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: .clear)
        let size = Mock.size(.small)
        let rain = SAForecast.days.first { $0.rain >= 50 }
        ZStack(alignment: .topLeading) {
            SASmallGround(name: "forecast-small", light: light)
            VStack(alignment: .leading, spacing: 2) {
                Text(rain.map { "rain \(SAForecast.name($0.offset, from: snap.date))" } ?? "dry days ahead")
                    .font(SAType.italic(16))
                    .foregroundStyle(CoverInk.cream)
                Text(rain.map { "\($0.rain)%  ·  from \(SAForecast.rainFrom)" } ?? "no rain in four days")
                    .coverLabel(8.5, rain == nil ? CoverInk.creamSoft : CoverInk.peach)
            }
            .fixedSize()
            .coverOnSky(0.9)
            .saBaseline(x: 16, y: 29, in: size)
            SAGlyph(name: rain == nil ? "sun.max" : "cloud.rain", light: light, size: 17)
                .position(x: 138, y: 26)
            VStack(spacing: 0) {
                ForEach(Array(SAForecast.days.enumerated()), id: \.offset) { i, d in
                    if i > 0 { SADashRule(light: light) }
                    HStack(spacing: 0) {
                        Text(SAForecast.name(d.offset, from: snap.date))
                            .font(SAType.italic(12.5))
                            .foregroundStyle(d.rain >= 50 ? CoverInk.peach : CoverInk.cream)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        SAGlyph(name: d.symbol, light: light, size: 10.5)
                            .frame(width: 20)
                        (Text("\(d.high)").foregroundColor(CoverInk.cream)
                            + Text("  \(d.low)").foregroundColor(CoverInk.creamFaint))
                            .font(SAType.serif(12.5))
                            .frame(width: 42, alignment: .trailing)
                    }
                    .frame(height: 20.5)
                }
            }
            .coverOnPaint(0.5)
            .frame(width: 132)
            .offset(x: 16, y: 64)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Tonight: the moon painted in its phase in the open sky, and on the dark ground its name, when it rises, how much
/// of it is lit, and today's daylight with the change from yesterday.
struct SAMoonSmall: View {
    var snap: DaySnapshot

    var body: some View {
        let clock = SkyClock(now: snap.date, weather: snap.weather)
        let light = CoverLight(clock: clock, condition: .clear)
        let phase = MoonPhase(date: snap.date)
        let size = Mock.size(.small)
        let lit = Int(((1 - cos(2 * .pi * phase.fraction)) / 2 * 100).rounded())
        ZStack(alignment: .topLeading) {
            SASmallGround(name: "moon-small", light: light)
            SAMoonDisc(phase: phase, light: light, radius: 19)
                .position(x: 116, y: 42)
            Text("TONIGHT").coverCaps(8, CoverInk.creamSoft, tracking: 2.2)
                .coverOnSky()
                .saBaseline(x: 16, y: 24, in: size)
            VStack(alignment: .leading, spacing: 0) {
                Text(SAWords.phase(phase))
                    .font(SAType.italic(16))
                    .foregroundStyle(CoverInk.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text([Self.moonrise(snap, phase).map { "rises \($0)" }, "\(lit)% lit"].compactMap { $0 }.joined(separator: "  ·  "))
                    .coverLabel(8.5, CoverInk.creamSoft)
                    .padding(.top, 3)
                SADashRule(light: light)
                    .padding(.vertical, 7)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(Self.daylight(snap).map { "daylight \($0)" } ?? "daylight unknown")
                        .coverLabel(8.5, CoverInk.creamSoft)
                    Text("− 2 m").coverLabel(8.5, CoverInk.peach)
                }
            }
            .frame(width: 132, alignment: .leading)
            .coverOnPaint(0.6)
            .saBaseline(x: 16, y: 107, in: size)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// Roughly: the moon rises with the sun when new and about 50 minutes later each day.
    static func moonrise(_ snap: DaySnapshot, _ phase: MoonPhase) -> String? {
        guard let rise = snap.weather?.sunrise else { return nil }
        let at = rise.addingTimeInterval(phase.fraction * 24.84 * 3600)
        return SAHome.clock(at, "h:mm a").lowercased()
    }

    static func daylight(_ snap: DaySnapshot) -> String? {
        guard let w = snap.weather, let rise = w.sunrise, let set = w.sunset else { return nil }
        return SAWords.span(SAWords.today(set, at: snap.date).timeIntervalSince(SAWords.today(rise, at: snap.date)))
    }
}

/// The painted moon in its phase, the unlit part in faint earthshine (fainter by day), in its own glow.
struct SAMoonDisc: View {
    var phase: MoonPhase
    var light: CoverLight
    var radius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [light.glow.opacity(light.isDay ? 0.22 : 0.38), light.glow.opacity(0.1), .clear],
                                     center: .center, startRadius: radius * 0.6, endRadius: radius * 3))
                .frame(width: radius * 6, height: radius * 6)
            ZStack {
                Circle().fill(Color(hex: 0x3A2C22).opacity(light.isDay ? 0.1 : 0.8))
                Image("PaintMoon")
                    .resizable()
                    .scaledToFill()
                    .colorMultiply(Color(hex: 0x7A6A58))
                    .opacity(light.isDay ? 0.06 : 0.35)
                    .clipShape(Circle())
                Image("PaintMoon")
                    .resizable()
                    .scaledToFill()
                    .colorMultiply(Color(hex: 0xF6EBD6))
                    .clipShape(MoonLitShape(phase: phase))
                    .shadow(color: light.glow.opacity(0.8), radius: radius * 0.3)
            }
            .frame(width: radius * 2, height: radius * 2)
        }
    }
}

// MARK: - The home screen

struct SAApp {
    var name: String
    var symbol: String
}

/// One home screen page of an iPhone 17 (402 x 874 pt): status bar, the 4 x 6 grid, the page dots and the dock.
struct SAHomeScreen: View {
    var page: Int
    var snap: DaySnapshot
    var quote: Quote

    static let screen = CGSize(width: 402, height: 874)
    /// Icon centres across, and the top of each grid row (a large widget spans four rows, a small one two).
    static let columns: [CGFloat] = [63, 155, 247, 339]
    static func rowTop(_ k: Int) -> CGFloat { 90 + 100.75 * CGFloat(k) }

    var body: some View {
        let night = !SkyClock(now: snap.date, weather: snap.weather).isDay
        ZStack(alignment: .topLeading) {
            SAHomeWallpaper(night: night)
            SAStatusBar(time: SAHome.clock(snap.date))
            if page == 1 { pageOne } else { pageTwo }
            SAPageDots(page: page, count: 2, night: night)
                .position(x: 201, y: 719)
            SADock(apps: SAHome.dock, night: night)
        }
        .frame(width: Self.screen.width, height: Self.screen.height)
        .clipped()
    }

    @ViewBuilder private var pageOne: some View {
        widget(.large, left: 27, row: 0) { SAWeatherQuote(snap: snap, quote: quote) }
        apps(SAHome.pageOne, at: [(0, 4), (1, 4), (2, 4), (3, 4), (0, 5), (1, 5), (2, 5), (3, 5)])
    }

    /// Widget, apps; apps, widget; widget, apps. The stack shows the days ahead by day and tonight's moon at night.
    @ViewBuilder private var pageTwo: some View {
        let night = !SkyClock(now: snap.date, weather: snap.weather).isDay
        widget(.small, left: 27, row: 0) { SATodoSmall(snap: snap, framed: false) }
        widget(.small, left: 211, row: 2) { SAPictureSmall(scene: SAPictureSmall.scene(besides: SALandscape.name), snap: snap) }
        widget(.small, left: 27, row: 4) {
            if night { SAMoonSmall(snap: snap) } else { SAForecastSmall(snap: snap) }
        }
        SAStackDots(index: night ? 1 : 0, count: 2)
            .position(x: 27 + 164 + 8, y: Self.rowTop(4) + 82)
        apps(SAHome.pageTwo, at: [(2, 0), (3, 0), (2, 1), (3, 1), (0, 2), (1, 2), (0, 3), (1, 3),
                                  (2, 4), (3, 4), (2, 5), (3, 5)])
    }

    private func widget<V: View>(_ family: Family, left: CGFloat, row: Int, @ViewBuilder _ content: () -> V) -> some View {
        let s = Mock.size(family)
        let top = Self.rowTop(row)
        return ZStack(alignment: .topLeading) {
            WidgetTile(family: family, content: content)
                .position(x: left + s.width / 2, y: top + s.height / 2)
            SAHomeLabel(text: "Baroque")
                .position(x: left + s.width / 2, y: top + s.height + 13)
        }
    }

    private func apps(_ list: [SAApp], at cells: [(Int, Int)]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(zip(list, cells).enumerated()), id: \.offset) { _, pair in
                let (app, cell) = pair
                SAAppCell(app: app)
                    .position(x: Self.columns[cell.0], y: Self.rowTop(cell.1) + 8 + 40.5)
            }
        }
    }
}

enum SAHome {
    static let dock = [SAApp(name: "Phone", symbol: "phone.fill"), SAApp(name: "Safari", symbol: "safari.fill"),
                       SAApp(name: "Messages", symbol: "message.fill"), SAApp(name: "Music", symbol: "music.note")]
    static let pageOne = [SAApp(name: "Photos", symbol: "photo.fill"), SAApp(name: "Camera", symbol: "camera.fill"),
                          SAApp(name: "Mail", symbol: "envelope.fill"), SAApp(name: "Maps", symbol: "map.fill"),
                          SAApp(name: "Clock", symbol: "clock.fill"), SAApp(name: "Notes", symbol: "note.text"),
                          SAApp(name: "Obsidian", symbol: "rhombus.fill"), SAApp(name: "Baroque", symbol: "mountain.2.fill")]
    static let pageTwo = [SAApp(name: "Calendar", symbol: "calendar"), SAApp(name: "Spotify", symbol: "headphones"),
                          SAApp(name: "Pinterest", symbol: "pin.fill"), SAApp(name: "YouTube", symbol: "play.rectangle.fill"),
                          SAApp(name: "Wallet", symbol: "wallet.pass.fill"), SAApp(name: "Health", symbol: "heart.fill"),
                          SAApp(name: "Files", symbol: "folder.fill"), SAApp(name: "Podcasts", symbol: "mic.fill"),
                          SAApp(name: "App Store", symbol: "arrow.down.app.fill"), SAApp(name: "Calculator", symbol: "plus.forwardslash.minus"),
                          SAApp(name: "Fitness", symbol: "figure.run"), SAApp(name: "Settings", symbol: "gearshape.fill")]

    /// A fixed 12-hour clock ("9:41"): POSIX, so a Mac set to 24-hour time doesn't turn h into HH.
    static func clock(_ date: Date, _ format: String = "h:mm") -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f.string(from: date)
    }

    /// The quote on page one (the medium-length demo quote).
    static let quote = DemoData.quotes[0]

    /// SA_HOME=1 writes both pages by day and by night, and page one's and page two's widgets on their own, to
    /// out/weather-sun-arc-home/<scene>/ (scene from SA_SCENE, else matterhorn).
    @MainActor static func renderIfRequested() -> Bool {
        guard let flag = ProcessInfo.processInfo.environment["SA_HOME"], !flag.isEmpty else { return false }
        let scene = SALandscape.name ?? "matterhorn"
        let dir = Mock.root.appendingPathComponent("out/weather-sun-arc-home/\(scene)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (snap, tag) in [(Mock.day, ""), (Mock.night, "-night")] {
            for page in [1, 2] {
                MockRunner.write(SAHomeScreen(page: page, snap: snap, quote: quote), scale: 3,
                                 to: dir.appendingPathComponent("home-\(page)\(tag).png"))
            }
            MockRunner.write(WidgetTile(family: .large) { SAWeatherQuote(snap: snap, quote: quote) }, scale: 3,
                             to: dir.appendingPathComponent("weather-quote-large\(tag).png"))
            MockRunner.write(WidgetTile(family: .small) { SATodoSmall(snap: snap, framed: false) }, scale: 3,
                             to: dir.appendingPathComponent("todo-small\(tag).png"))
            MockRunner.write(WidgetTile(family: .small) { SAForecastSmall(snap: snap) }, scale: 3,
                             to: dir.appendingPathComponent("forecast-small\(tag).png"))
            MockRunner.write(WidgetTile(family: .small) { SAMoonSmall(snap: snap) }, scale: 3,
                             to: dir.appendingPathComponent("moon-small\(tag).png"))
            MockRunner.write(WidgetTile(family: .small) { SAPictureSmall(scene: SAPictureSmall.scene(besides: SALandscape.name), snap: snap) },
                             scale: 3, to: dir.appendingPathComponent("picture-small\(tag).png"))
            MockRunner.write(SAIconSheet(), scale: 3, to: dir.appendingPathComponent("icons.png"))
        }
        print("Rendered the Sun Arc home screen (\(scene)) to \(dir.path)")
        return true
    }
}

/// The Baroque cloudscape wallpaper, dimmed a little at night as iOS's dark appearance does.
struct SAHomeWallpaper: View {
    var night: Bool

    var body: some View {
        Mock.texture("weather-sun-arc/home/wallpaper")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: SAHomeScreen.screen.width, height: SAHomeScreen.screen.height)
            .overlay(CanvasWeave(opacity: 0.45))
            .overlay(Color.black.opacity(night ? 0.25 : 0))
            .clipped()
    }
}

struct SAStatusBar: View {
    var time: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(time)
                .font(.system(size: 17, weight: .semibold))
                .position(x: 72, y: 33)
            HStack(spacing: 6) {
                Image(systemName: "cellularbars").font(.system(size: 15, weight: .semibold))
                Image(systemName: "wifi").font(.system(size: 15, weight: .semibold))
                Image(systemName: "battery.75percent").font(.system(size: 19, weight: .regular))
            }
            .position(x: 333, y: 33)
        }
        .foregroundStyle(.white)
        .frame(width: SAHomeScreen.screen.width, height: 60, alignment: .topLeading)
    }
}

/// A custom app icon in the raised-slab construction of the earlier painted widgets (Theme's StoneSlabModifier): a
/// taupe painted tile standing off the wallpaper on its darker cut side, with a contact shadow, a lit chamfer and the
/// light from the upper right as on the paintings; the glyph is carved into the face, dark umber with a lit lower lip.
/// The taupe and umber are the reference's icon pack. On iOS these would be set as Shortcuts home screen icons.
struct SAIcon: View {
    var app: SAApp
    static let side: CGFloat = 62

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14.5, style: .continuous)
        let depth: CGFloat = 2.6
        ZStack {
            // The cut side under the face, and the tile's shadow on the clouds.
            shape
                .fill(LinearGradient(colors: [Color(hex: 0x6B5444), Color(hex: 0x46362A)], startPoint: .top, endPoint: .bottom))
                .offset(y: depth)
                .shadow(color: Color(hex: 0x140B06).opacity(0.5), radius: 6, x: -1, y: depth + 3)
                .shadow(color: Color(hex: 0x140B06).opacity(0.45), radius: 1, x: 0, y: depth * 0.7)
            // The face: taupe paint with the brushwork of the painted panels, lit from the upper right.
            ZStack {
                LinearGradient(colors: [Color(hex: 0xC4AD94), Color(hex: 0xA68D77), Color(hex: 0x927965)],
                               startPoint: .top, endPoint: .bottom)
                Image("PaintPanel")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .grayscale(1)
                    .blendMode(.overlay)
                    .opacity(0.6)
                RadialGradient(colors: [Color(hex: 0xFFF1DC).opacity(0.38), .clear], center: UnitPoint(x: 0.88, y: 0),
                               startRadius: 0, endRadius: 58)
                LinearGradient(colors: [.clear, Color(hex: 0x2A1A10).opacity(0.2)], startPoint: .topTrailing, endPoint: .bottomLeading)
                CanvasWeave(opacity: 0.45)
            }
            .frame(width: Self.side, height: Self.side)  // the brushwork fills the tile, never widens it
            .clipShape(shape)
            // The chamfer: a lit top edge and a shaded foot.
            shape.strokeBorder(LinearGradient(stops: [.init(color: Color(hex: 0xFFF3E0).opacity(0.75), location: 0),
                                                      .init(color: .white.opacity(0), location: 0.32),
                                                      .init(color: .black.opacity(0), location: 0.7),
                                                      .init(color: Color(hex: 0x3A281C).opacity(0.55), location: 1)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 1.1)
            SACarvedGlyph(symbol: app.symbol, size: 25)
        }
        .frame(width: Self.side, height: Self.side)
    }
}

/// An SF Symbol cut into a painted face: the floor in dark umber, shadowed under its upper lip, and a cream lower lip
/// where the light catches the cut.
struct SACarvedGlyph: View {
    var symbol: String
    var size: CGFloat

    var body: some View {
        let glyph = Image(systemName: symbol).font(.system(size: size, weight: .semibold))
        ZStack {
            glyph.foregroundStyle(Color(hex: 0xF6E7D0).opacity(0.7)).offset(x: -0.3, y: 1)
            glyph.foregroundStyle(LinearGradient(colors: [Color(hex: 0x36261B), Color(hex: 0x5A4232)], startPoint: .top, endPoint: .bottom)
                .shadow(.inner(color: .black.opacity(0.7), radius: 1, x: 0.3, y: 1.4)))
        }
    }
}

/// All the icons on one sheet, for checking them up close.
struct SAIconSheet: View {
    var body: some View {
        let apps = SAHome.dock + SAHome.pageOne + SAHome.pageTwo
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 6), count: 6), spacing: 14) {
            ForEach(Array(apps.enumerated()), id: \.offset) { _, app in SAAppCell(app: app) }
        }
        .padding(24)
        .frame(width: 6 * 90 + 48)
        .background {
            Mock.texture("weather-sun-arc/home/wallpaper").resizable().interpolation(.high).scaledToFill()
        }
        .clipped()
    }
}

/// The page dots a Smart Stack shows beside itself.
struct SAStackDots: View {
    var index: Int
    var count: Int

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Circle().fill(.white.opacity(i == index ? 0.95 : 0.45)).frame(width: 4.5, height: 4.5)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 1.5)
    }
}

/// A painting on its own, as the reference's picture widgets: one of the Sun Arc landscapes without the arc or any
/// words but a small label, cropped square round its subject and glazed for the time of day. It would rotate through
/// the landscapes (or show a photo the user picks).
struct SAPictureSmall: View {
    var scene: String
    var snap: DaySnapshot

    /// A different landscape from page one's.
    static func scene(besides page: String?) -> String { page == "tuscany" ? "dolomites" : "tuscany" }

    /// The square to show, in points of the large canvas (348 x 365).
    static let crops: [String: CGRect] = [
        "tuscany": CGRect(x: 56, y: 62, width: 236, height: 236),
        "dolomites": CGRect(x: 36, y: 46, width: 260, height: 260),
    ]
    static let labels = ["tuscany": "Val d'Orcia", "dolomites": "Tre Cime"]

    var body: some View {
        let light = CoverLight(clock: SkyClock(now: snap.date, weather: snap.weather), condition: .clear)
        let size = Mock.size(.small)
        let crop = Self.crops[scene] ?? CGRect(x: 30, y: 40, width: 280, height: 280)
        let k = size.width / crop.width
        let folder = scene == "matterhorn" ? "weather-sun-arc" : "weather-sun-arc/scenes/\(scene)"
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: size.width, height: size.height)
                .overlay(alignment: .topLeading) {
                    SAPaint(lower: Mock.texture("\(folder)/large-lo"), upper: Mock.texture("\(folder)/large-hi"),
                            glow: Mock.texture("\(folder)/large-glow"), light: light, center: UnitPoint(x: 0.62, y: 0.14),
                            reach: 360, seed: 29)
                        .frame(width: 348, height: 365)
                        .scaleEffect(k, anchor: .topLeading)
                        .offset(x: -crop.minX * k, y: -crop.minY * k)
                }
                .clipped()
            CanvasWeave(opacity: 0.8)
            if let label = Self.labels[scene] {
                Text(label)
                    .font(SAType.italic(11))
                    .foregroundStyle(CoverInk.creamSoft)
                    .coverOnPaint(0.7)
                    .saBaseline(x: 14, y: 150, in: size)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

struct SAAppCell: View {
    var app: SAApp

    var body: some View {
        VStack(spacing: 5) {
            SAIcon(app: app)
            SAHomeLabel(text: app.name)
        }
        .frame(width: 84)
    }
}

struct SAHomeLabel: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(.white)
            .shadow(color: Color(hex: 0x140B06).opacity(0.75), radius: 2.5, x: 0, y: 0.5)
            .lineLimit(1)
            .fixedSize()
    }
}

/// The page dots in a small glass capsule, where the Search button sits when "Show on Home Screen" is off.
struct SAPageDots: View {
    var page: Int
    var count: Int
    var night: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...count, id: \.self) { i in
                Circle().fill(.white.opacity(i == page ? 0.95 : 0.4)).frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 26)
        .background {
            Capsule().fill(.white.opacity(night ? 0.1 : 0.14))
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.6))
        }
    }
}

/// The dock: a Liquid Glass slab (the wallpaper behind it blurred and lifted, a bright rim), four icons, no labels.
struct SADock: View {
    var apps: [SAApp]
    var night: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 40, style: .continuous)
        let frame = CGRect(x: 17.5, y: 744, width: 367, height: 101)
        ZStack(alignment: .topLeading) {
            SAHomeWallpaper(night: night)
                .blur(radius: 16)
                .brightness(0.07)
                .mask {
                    shape.frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY)
                }
            shape.fill(.white.opacity(0.07))
                .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.06), .white.opacity(0.18)],
                                                           startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
            ForEach(Array(apps.enumerated()), id: \.offset) { i, app in
                SAIcon(app: app).position(x: SAHomeScreen.columns[i], y: frame.midY)
            }
        }
        .frame(width: SAHomeScreen.screen.width, height: SAHomeScreen.screen.height, alignment: .topLeading)
    }
}
