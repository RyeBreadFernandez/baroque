#if DEBUG
import SwiftUI
import UIKit

// DEBUG-only render harness for fast design iteration.
// Launch the app with -renderWidgets and it writes exact-size PNGs (scale 3) of every widget family and data state
// at three phone sizes into Documents/renders, plus fit.txt. The rococo widgets are fixed layouts at the iPhone 17
// design sizes that RococoFrame scales to fill each widget, so fit.txt notes the scale and how much is cropped per
// size instead of measuring text. At the iPhone 17 size, "accented-*" imitates a tinted home screen (no stone or
// scrims, RococoFrame's accented mode, and the words in one light tint on a dark ground, as iOS draws them), and
// "ticks-today-*" shades the tap target round each task's ring. Pull them with:
//   xcrun simctl get_app_container <udid> com.ryanfernandez.terra data
enum WidgetRenders {
    struct Device {
        var name: String
        var small: CGSize
        var medium: CGSize
        var large: CGSize

        func size(_ family: BaroqueSize) -> CGSize {
            switch family {
            case .small: return small
            case .medium: return medium
            case .large: return large
            }
        }
    }

    // Widget point sizes. "402" is iPhone 17 / 17 Pro (402x874 pt screen), measured from simulator home-screen
    // screenshots; "430" (Pro Max) and "393" (6.1") come from Apple's HIG table and bracket it.
    static let devices: [Device] = [
        Device(name: "402", small: CGSize(width: 164, height: 164), medium: CGSize(width: 348, height: 164), large: CGSize(width: 348, height: 365)),
        Device(name: "430", small: CGSize(width: 170, height: 170), medium: CGSize(width: 364, height: 170), large: CGSize(width: 364, height: 382)),
        Device(name: "393", small: CGSize(width: 158, height: 158), medium: CGSize(width: 338, height: 158), large: CGSize(width: 338, height: 354))
    ]

    static let families: [(name: String, size: BaroqueSize)] = [("small", .small), ("medium", .medium), ("large", .large)]

    @MainActor
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-renderWidgets") else { return }
        run()
    }

    // -scrollTo <section id> scrolls the settings form for screenshots (github, tasks, quotes, location, about).
    @MainActor
    static func scrollIfRequested(_ proxy: ScrollViewProxy) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-scrollTo"), i + 1 < args.count else { return }
        let target = args[i + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            proxy.scrollTo(target, anchor: .top)
        }
    }

    @MainActor
    static func run() {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("renders", isDirectory: true)
        try? fm.removeItem(at: dir)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let days = dayStates, quotes = quoteStates, batteries = batteryStates, photoTimes = photographTimes
        var report = [
            "Rococo renders: \(devices.count) sizes x (Day S/M/L and Today S/M/L: \(days.count) states; Quote S/M/L: \(quotes.count);"
                + " Battery S: \(batteries.count); Still Life S/L; Photograph S: \(photoTimes.count) times) at 3x,"
                + " and the iPhone 17 size on a tinted home screen (accented-*).",
            "Day states: " + days.map(\.name).joined(separator: ", "),
            "Quote states: " + quotes.map(\.name).joined(separator: ", "),
            "Photograph times: " + photoTimes.map { "\($0.name) (\(RococoPhotos.small(at: $0.date)))" }.joined(separator: ", "),
            "Each widget is laid out at its iPhone 17 design size and scaled uniformly by RococoFrame to fill it:"
        ]
        for device in devices {
            for family in families {
                let size = device.size(family.size)
                report.append("  \(device.name) \(family.name): " + frameNote(design: family.size.designSize, widget: size))
                for state in days {
                    let quote = DemoData.quotes[1]   // one with an author, so the large Day shows who said it
                    write(RococoDayView(snapshot: state.snapshot, quote: quote, size: family.size), size: size,
                          name: "\(device.name)-day-\(family.name)-\(state.name)", dir: dir)
                    write(RococoTodayView(snapshot: state.snapshot, size: family.size), size: size,
                          name: "\(device.name)-today-\(family.name)-\(state.name)", dir: dir)
                }
                for state in quotes {
                    let view = RococoQuoteView(quote: state.quote, size: family.size, date: state.date, error: state.error)
                    write(view, size: size, name: "\(device.name)-quote-\(family.name)-\(state.name)", dir: dir)
                }
                // Still Life and Photograph draw their picture edge to edge and nothing else (BaroqueWidgets.swift).
                if family.size != .medium {
                    write(RococoPicture(name: family.size == .large ? "RococoStillLifeLarge" : "RococoStillLife"), size: size,
                          name: "\(device.name)-still-life-\(family.name)", dir: dir)
                }
                if family.size == .small {
                    for (name, reading) in batteries {
                        write(RococoBatteryView(reading: reading), size: size, name: "\(device.name)-battery-small-\(name)", dir: dir)
                    }
                    // The Days Ahead widget, in every Day state (its error line shows in the failed ones).
                    for state in days {
                        write(RococoDaysAheadView(snapshot: state.snapshot), size: size,
                              name: "\(device.name)-days-ahead-small-\(state.name)", dir: dir)
                    }
                    for time in photoTimes {
                        write(RococoPicture(name: RococoPhotos.small(at: time.date)), size: size,
                              name: "\(device.name)-photograph-small-\(time.name)", dir: dir)
                    }
                }
            }
        }
        writeAccented(dir: dir)
        writeTickAreas(dir: dir)
        report.append("The Daily Brief's picture of the day, stand-ins cut by BandImage (today-large-picture-*):")
        report += writeBriefPictures(dir: dir)
        try? report.joined(separator: "\n").write(to: dir.appendingPathComponent("fit.txt"), atomically: true, encoding: .utf8)
        try? "done".write(to: dir.appendingPathComponent("done.txt"), atomically: true, encoding: .utf8)
    }

    /// A tinted home screen, imitated: RococoFrame's accented mode (no stone, no scrims), every ink one light tint, on a
    /// dark ground. iOS draws all but the full-colour pictures in its tint there, so this shows whether the words
    /// survive (F46); the real look is checked in the simulator (Customize › Tinted and Clear).
    @MainActor
    private static func writeAccented(dir: URL) {
        let keep = RococoTheme.current
        defer { RococoTheme.current = keep }
        var tinted = keep
        let tint = Color(hex: 0xE4ECF4)
        tinted.ink = tint
        tinted.inkSoft = tint
        tinted.terracotta = tint
        RococoTheme.current = tinted
        let device = devices[0]
        let demo = DemoData.day(now: morning)
        let ground = Color(hex: 0x2A3440)
        for family in families {
            let size = device.size(family.size)
            var views: [(String, AnyView)] = [
                ("day", AnyView(RococoDayView(snapshot: demo, quote: DemoData.quotes[0], size: family.size))),
                ("today", AnyView(RococoTodayView(snapshot: demo, size: family.size))),
                ("quote", AnyView(RococoQuoteView(quote: DemoData.quotes[1], size: family.size, date: morning, error: nil)))
            ]
            if family.size == .small {
                views.append(("battery", AnyView(RococoBatteryView(reading: BatteryReading(level: 0.82, charging: false, at: morning)))))
            }
            if family.size == .large, let picture = briefPictureStandIns(dir: dir).first?.picture {
                views.append(("today-picture", AnyView(RococoTodayView(snapshot: demo, size: .large, picture: picture))))
            }
            for (kind, view) in views {
                write(view.environment(\.rococoAccented, true), size: size,
                      name: "\(device.name)-accented-\(kind)-\(family.name)", dir: dir, ground: ground)
            }
        }
    }

    /// The Today widget at the iPhone 17 size with each ring's tap target shaded ("ticks-*"): what the widget's tick
    /// button wraps, at least 28 points square, while the layout stays as it is.
    @MainActor
    private static func writeTickAreas(dir: URL) {
        let device = devices[0]
        let shade: (TaskItem, AnyView) -> AnyView = { _, ring in
            AnyView(ring.background(Color(hex: 0x3D7BD9).opacity(0.35)).border(Color(hex: 0x3D7BD9), width: 0.5))
        }
        for family in families {
            write(RococoTodayView(snapshot: DemoData.day(now: morning), size: family.size, tick: shade), size: device.size(family.size),
                  name: "\(device.name)-ticks-today-\(family.name)", dir: dir)
        }
    }

    /// The large Today with stand-ins for the Daily Brief's picture of the day, by day and by night, at every size
    /// ("today-large-picture-<picture>-<day|night>"). The stand-ins are made here and cut by BandImage as a downloaded
    /// picture is. At the iPhone 17 size each has a "-ground" twin without the band's words, which
    /// scripts/check_band_contrast.py reads to measure the words against what they sit on. Returns fit.txt's lines.
    @MainActor
    private static func writeBriefPictures(dir: URL) -> [String] {
        let brief = dayStates.first { $0.name == "brief" }?.snapshot ?? DemoData.day()
        let tonight = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
        var notes: [String] = []
        for standIn in briefPictureStandIns(dir: dir) {
            let size = (try? standIn.picture.file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let image = standIn.picture.image()
            notes.append("  \(standIn.name): \(image?.width ?? 0) x \(image?.height ?? 0) px, \(size) bytes")
            for (time, date) in [("day", morning), ("night", tonight)] {
                var snap = brief
                snap.date = date
                for device in devices {
                    write(RococoTodayView(snapshot: snap, size: .large, picture: standIn.picture), size: device.size(.large),
                          name: "\(device.name)-today-large-picture-\(standIn.name)-\(time)", dir: dir)
                }
                write(RococoTodayView(snapshot: snap, size: .large, picture: standIn.picture).environment(\.rococoBandWordsHidden, true),
                      size: devices[0].large, name: "\(devices[0].name)-today-large-picture-\(standIn.name)-\(time)-ground", dir: dir)
            }
        }
        return notes
    }

    /// The stand-ins, cut to the band into renders/brief-pictures: "light", a pale painting that's white where the words
    /// sit (the hardest case for them); "photo", one of the repainted photographs; "dark", a nocturne.
    @MainActor
    private static func briefPictureStandIns(dir: URL) -> [(name: String, picture: RococoBandPicture)] {
        let folder = dir.appendingPathComponent("brief-pictures", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sources: [(String, Data?)] = [
            ("light", painting(top: 0xF1EADB, foot: 0xFFFFFF, shapes: 0xE6DCC8)),
            ("photo", UIImage(named: "RococoPhoto-kings-canyon")?.jpegData(compressionQuality: 0.95)),
            ("dark", painting(top: 0x15141A, foot: 0x3A2D22, shapes: 0xD9CFB8))
        ]
        return sources.compactMap { name, data in
            let file = folder.appendingPathComponent(name + ".jpg")
            guard let data, let jpeg = BandImage.jpeg(from: data), (try? jpeg.write(to: file)) != nil else { return nil }
            return (name, RococoBandPicture(file: file, label: "A stand-in for the picture of the day (\(name))"))
        }
    }

    /// A made-up painting at the size the brief's come in (1800 x 1200): a sky from `top` to `foot`, a few soft shapes
    /// and a low horizon, as JPEG data.
    private static func painting(top: UInt32, foot: UInt32, shapes: UInt32) -> Data? {
        func ui(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
        }
        let size = CGSize(width: 1800, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let colours = [ui(top).cgColor, ui(foot).cgColor, ui(foot).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colours, locations: [0, 0.45, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            ui(shapes, 0.45).setFill()
            for (x, y, w, h) in [(180.0, 420.0, 520.0, 120.0), (900, 470, 620, 110), (1350, 380, 300, 200)] {
                cg.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
            }
            ui(shapes, 0.25).setFill()
            cg.fill(CGRect(x: 0, y: 640, width: size.width, height: 14))
        }
        return image.jpegData(compressionQuality: 0.92)
    }

    /// The widget at its exact size and rounded shape, as the home screen shows it.
    @MainActor
    private static func write<V: View>(_ view: V, size: CGSize, name: String, dir: URL, ground: Color = RococoInk.stone) {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let tile = view
            .frame(width: size.width, height: size.height)
            .background(ground)
            .clipShape(shape)
            .containerShape(shape)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: tile)
        renderer.scale = 3
        if let data = renderer.uiImage?.pngData() {
            try? data.write(to: dir.appendingPathComponent(name + ".png"))
        }
    }

    /// "364 x 170 pt, scale 1.046, 0.9 pt cropped at top and bottom".
    private static func frameNote(design: CGSize, widget: CGSize) -> String {
        let scale = max(widget.width / design.width, widget.height / design.height)
        let cropX = (design.width * scale - widget.width) / 2, cropY = (design.height * scale - widget.height) / 2
        var note = String(format: "%.0f x %.0f pt, scale %.3f", widget.width, widget.height, scale)
        if cropX >= 0.05 { note += String(format: ", %.1f pt cropped at left and right", cropX) }
        if cropY >= 0.05 { note += String(format: ", %.1f pt cropped at top and bottom", cropY) }
        if cropX < 0.05 && cropY < 0.05 { note += ", fills it exactly" }
        return note
    }

    // MARK: Data states

    struct DayState { var name: String; var snapshot: DaySnapshot }
    struct QuoteState { var name: String; var quote: Quote; var date: Date; var error: String? }

    static let noToken = "No GitHub token. Add one in the Baroque app."
    static let offline = "The Internet connection appears to be offline."

    /// Today at 9:41, the time MockLab renders the mocks at.
    static var morning: Date { Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date()) ?? Date() }

    static var dayStates: [DayState] {
        let demo = DemoData.day()

        var cached = demo
        cached.taskError = noToken

        let fresh = DaySnapshot(date: Date(), weather: nil, tasks: [], taskError: noToken, weatherError: nil)

        var empty = demo
        empty.tasks = []

        var noWeather = demo
        noWeather.weather = nil
        noWeather.weatherError = offline

        // Worst case: a two-digit date, long month, three-digit temperature, long condition, more tasks than fit,
        // long titles and a long error.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: today) ?? today }
        let stressTasks = [
            TaskItem(text: "Finish the chapter three exercises and check every answer twice", due: days(-3), priority: .highest, sourcePath: "a", lineNumber: 1),
            TaskItem(text: "Submit the physics lab report with the full error analysis appendix", due: today, priority: .highest, sourcePath: "a", lineNumber: 2),
            TaskItem(text: "Email the landlord about the leaking tap", due: today, priority: .high, sourcePath: "a", lineNumber: 3),
            TaskItem(text: "Pump tires, get gas", due: nil, priority: .high, sourcePath: "a", lineNumber: 4),
            TaskItem(text: "Renew parking permit before the lot fills up", due: nil, priority: .none, sourcePath: "a", lineNumber: 5),
            TaskItem(text: "Call the dentist", due: nil, priority: .none, sourcePath: "a", lineNumber: 6),
            TaskItem(text: "Plan spring break trip", due: nil, priority: .low, sourcePath: "a", lineNumber: 7),
            TaskItem(text: "Water the plants", due: nil, priority: .lowest, sourcePath: "a", lineNumber: 8)
        ]
        var wed = DateComponents()
        wed.year = 2026; wed.month = 9; wed.day = 30; wed.hour = 13
        let stress = DaySnapshot(
            date: cal.date(from: wed) ?? Date(),
            weather: WeatherSnapshot(temperature: 104, apparent: 108, high: 109, low: 88, code: 56, fetchedAt: Date()),
            tasks: stressTasks,
            taskError: offline,
            weatherError: nil)

        // Tasks shaped like the Daily Brief's, each ending with where it came from (the large Today sets that as a
        // caption), and one from another file whose brackets are part of the task. Made-up details.
        var brief = demo
        brief.tasks = [
            TaskItem(text: "Send the garden club the spring planting plan. (Sam, email, Nov 5)", due: days(-1), priority: .none,
                     sourcePath: BaroqueSettings.dailyBriefPath, lineNumber: 9),
            TaskItem(text: "Reply about the hike: carpool leaves at 7:00 AM. (Hiking club, message, Nov 5)", due: days(1), priority: .none,
                     sourcePath: BaroqueSettings.dailyBriefPath, lineNumber: 10),
            TaskItem(text: "Return the library hold.", due: days(5), priority: .none, sourcePath: BaroqueSettings.dailyBriefPath, lineNumber: 11),
            TaskItem(text: "Finish essay (draft 2)", due: days(12), priority: .none, sourcePath: "Tasks/Master Task List.md", lineNumber: 4)
        ]

        // The sky at different times and in different weather.
        func sky(_ name: String, code: Int, hour: Int, minute: Int = 0) -> DayState {
            var snap = demo
            snap.date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
            snap.weather = WeatherSnapshot(temperature: 48, apparent: 45, high: 55, low: 39, code: code, fetchedAt: snap.date,
                                           isDay: (7..<17).contains(hour),
                                           sunrise: cal.date(bySettingHour: 6, minute: 14, second: 0, of: today),
                                           sunset: cal.date(bySettingHour: 16, minute: 58, second: 0, of: today))
            return DayState(name: name, snapshot: snap)
        }

        return [
            DayState(name: "demo", snapshot: demo),
            DayState(name: "morning", snapshot: DemoData.day(now: morning)),
            DayState(name: "cached", snapshot: cached),
            DayState(name: "fresh", snapshot: fresh),
            DayState(name: "empty", snapshot: empty),
            DayState(name: "no-weather", snapshot: noWeather),
            DayState(name: "brief", snapshot: brief),
            DayState(name: "stress", snapshot: stress),
            sky("sky-partly", code: 2, hour: 11),
            sky("sky-rain", code: 63, hour: 13),
            sky("sky-snow", code: 73, hour: 14),
            sky("sky-fog", code: 45, hour: 8),
            sky("sky-storm-dusk", code: 95, hour: 16, minute: 50),
            sky("sky-clear-dusk", code: 0, hour: 16, minute: 45),
            sky("sky-clear-night", code: 0, hour: 22)
        ]
    }

    /// Two turns of the Photograph widget: this morning's photograph and tonight's.
    static var photographTimes: [(name: String, date: Date)] {
        [("morning", morning), ("night", Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date())]
    }

    static var batteryStates: [(String, BatteryReading)] {
        [("82", BatteryReading(level: 0.82, charging: false, at: morning)),
         ("low", BatteryReading(level: 0.14, charging: false, at: morning)),
         ("charging", BatteryReading(level: 0.64, charging: true, at: morning)),
         ("unknown", BatteryReading(level: nil, charging: false, at: morning))]
    }

    static var quoteStates: [QuoteState] {
        let night = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
        let long = Quote(
            text: "It is not the critic who counts; not the man who points out how the strong man stumbles, or where the doer of deeds could have done them better. The credit belongs to the man who is actually in the arena, whose face is marred by dust and sweat and blood; who strives valiantly; who errs, who comes short again and again.",
            author: "Theodore Roosevelt, Citizenship in a Republic")
        return [
            QuoteState(name: "demo", quote: DemoData.quotes[1], date: Date(), error: nil),
            QuoteState(name: "morning", quote: DemoData.quotes[1], date: morning, error: nil),
            QuoteState(name: "cached", quote: DemoData.quotes[1], date: morning, error: noToken),
            QuoteState(name: "short", quote: DemoData.quotes[3], date: morning, error: nil),
            QuoteState(name: "no-author", quote: DemoData.quotes[2], date: morning, error: nil),
            QuoteState(name: "fresh", quote: DataLoader.fallbackQuotes[0], date: morning, error: noToken),
            QuoteState(name: "long", quote: long, date: morning, error: noToken),
            QuoteState(name: "night", quote: DemoData.quotes[0], date: night, error: nil)
        ]
    }
}

#endif
