import SwiftUI
import AppKit
import UniformTypeIdentifiers

// Shared harness for the aesthetic mocks. Every target in Sources/ links this folder (Sources/<Target>/Kit -> ../../Kit),
// so each mock renders the same demo content at the same iPhone 17 widget sizes.
// Run one with: swift run --scratch-path <dir> <Target>   (PNGs land in MockLab/out/<slug>/)

enum Family: String, CaseIterable {
    case small, medium, large
}

/// One complete look for both widgets. Each view draws the whole widget, background included,
/// at exactly `Mock.size(family)`. Keep text 16 pt in from the edges (WidgetKit's default content margins);
/// decoration can run to the edge. Use only SwiftUI (no AppKit) so a chosen mock ports to the iOS widget as is.
protocol MockAesthetic {
    associatedtype DayBody: View
    associatedtype QuoteBody: View
    associatedtype WallpaperBody: View

    var name: String { get }
    var slug: String { get }
    var tagline: String { get }

    @MainActor @ViewBuilder func day(_ snapshot: DaySnapshot, family: Family) -> DayBody
    @MainActor @ViewBuilder func quote(_ quote: Quote, family: Family) -> QuoteBody
    /// Home-screen wallpaper that suits the look; shown behind the widgets on the comparison board.
    @MainActor @ViewBuilder func wallpaper() -> WallpaperBody
}

enum Mock {
    /// iPhone 17 / 17 Pro widget sizes in points (402 x 874 pt screen), the same as the app's `-renderWidgets`.
    static func size(_ family: Family) -> CGSize {
        switch family {
        case .small: return CGSize(width: 164, height: 164)
        case .medium: return CGSize(width: 348, height: 164)
        case .large: return CGSize(width: 348, height: 365)
        }
    }

    static let cornerRadius: CGFloat = 22
    static let margin: CGFloat = 16

    /// Today at 9:41 AM, so the demo tasks' overdue and due-today flags (computed against the real clock) agree with it.
    static let now: Date = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date()) ?? Date()

    /// Weather 64°, mostly clear, H 68 / L 52, sunrise 6:14, sunset 4:58; seven tasks in agenda order
    /// (one 1 day late, two due today, undated high priority, tomorrow, undated, a far one).
    /// Large shows up to 5 tasks, medium 3, small 1 (plus a count of the rest).
    static let day: DaySnapshot = DemoData.day(now: now)

    /// Fixed quotes per size: short for small, medium-length for medium, long for large.
    static func quote(for family: Family) -> Quote {
        switch family {
        case .small: return DemoData.quotes[3]   // "Good ideas take time." — unknown
        case .medium: return DemoData.quotes[0]  // Thoreau
        case .large: return DemoData.quotes[1]   // the long one (Seneca)
        }
    }

    /// The app's due labels: "1d late", "today", "tomorrow", otherwise "Nov 4". Nil when undated.
    static func dueLabel(_ task: TaskItem, now: Date = Mock.now) -> String? {
        guard let due = task.due else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: due)).day ?? 0
        if days < 0 { return "\(-days)d late" }
        if days == 0 { return "today" }
        if days == 1 { return "tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: due)
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "--" }
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    /// The MockLab folder (found from this file's path, so it works from any working directory).
    static let root: URL = {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) { return url }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }()

    /// A raster texture from MockLab/Textures/<path>.png (or .jpg), e.g. `Mock.texture("topo/paper")`.
    /// Keep textures near 1 px per point of the widget: WidgetKit refuses widgets with oversized images.
    static func texture(_ path: String) -> Image {
        for ext in ["png", "jpg"] {
            let url = root.appendingPathComponent("Textures/\(path).\(ext)")
            if let img = NSImage(contentsOf: url) { return Image(nsImage: img) }
        }
        FileHandle.standardError.write("MockKit: missing texture \(path)\n".data(using: .utf8)!)
        return Image(systemName: "questionmark.square.dashed")
    }
}

/// A widget as the home screen shows it: exact size, continuous rounded corners, and a container shape
/// so `ContainerRelativeShape` behaves as it does in WidgetKit.
struct WidgetTile<Content: View>: View {
    var family: Family
    @ViewBuilder var content: Content

    var body: some View {
        let s = Mock.size(family)
        let shape = RoundedRectangle(cornerRadius: Mock.cornerRadius, style: .continuous)
        content
            .frame(width: s.width, height: s.height)
            .clipShape(shape)
            .containerShape(shape)
    }
}

/// All six widgets on the look's wallpaper, laid out like two home screen columns, with the name card.
struct MockBoard<A: MockAesthetic>: View {
    var aesthetic: A
    static var gap: CGFloat { 28 }

    var body: some View {
        let g = Self.gap
        HStack(alignment: .top, spacing: g) {
            VStack(spacing: g) {
                WidgetTile(family: .large) { aesthetic.day(Mock.day, family: .large) }
                WidgetTile(family: .medium) { aesthetic.day(Mock.day, family: .medium) }
                HStack(spacing: 20) {
                    WidgetTile(family: .small) { aesthetic.day(Mock.day, family: .small) }
                    WidgetTile(family: .small) { aesthetic.quote(Mock.quote(for: .small), family: .small) }
                }
            }
            VStack(spacing: g) {
                WidgetTile(family: .large) { aesthetic.quote(Mock.quote(for: .large), family: .large) }
                WidgetTile(family: .medium) { aesthetic.quote(Mock.quote(for: .medium), family: .medium) }
                nameCard
            }
        }
        .padding(g)
        .background { aesthetic.wallpaper() }
        .clipped()
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(aesthetic.name)
                .font(.system(size: 26, weight: .bold))
            Text(aesthetic.tagline)
                .font(.system(size: 13, weight: .regular))
                .opacity(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(width: Mock.size(.medium).width, height: Mock.size(.medium).height, alignment: .bottomLeading)
        .background(.black.opacity(0.66), in: RoundedRectangle(cornerRadius: Mock.cornerRadius, style: .continuous))
    }
}

@MainActor
enum MockRunner {
    /// Renders the six widgets (scale 3) and the board (scale 2) to MockLab/out/<slug>/.
    static func run<A: MockAesthetic>(_ a: A) {
        let dir = Mock.root.appendingPathComponent("out/\(a.slug)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for f in Family.allCases {
            write(WidgetTile(family: f) { a.day(Mock.day, family: f) }, scale: 3, to: dir.appendingPathComponent("day-\(f.rawValue).png"))
            write(WidgetTile(family: f) { a.quote(Mock.quote(for: f), family: f) }, scale: 3, to: dir.appendingPathComponent("quote-\(f.rawValue).png"))
        }
        write(MockBoard(aesthetic: a), scale: 2, to: dir.appendingPathComponent("board.png"))
        // Name and tagline for compose.py, which builds the comparison sheets.
        let meta = ["name": a.name, "slug": a.slug, "tagline": a.tagline]
        if let data = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dir.appendingPathComponent("meta.json"))
        }
        print("Rendered \(a.name) to \(dir.path)")
    }

    static func write<V: View>(_ view: V, scale: CGFloat, to url: URL) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = scale
        guard let cg = renderer.cgImage,
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            FileHandle.standardError.write("MockKit: could not render \(url.lastPathComponent)\n".data(using: .utf8)!)
            return
        }
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)
    }
}
