import SwiftUI
import UIKit

// Setting up the home screen. iOS lets no app move icons, set the wallpaper or place widgets, so the app does what it
// can and shows the rest:
//   1. the icons: each is a Shortcuts "Open App" shortcut added to the Home Screen with one of Baroque's 24 icons, which
//      the app keeps as files (IconFiles) for Add to Home Screen > Image > Choose File. A web clip with the app's URL
//      scheme looks the same but opens Safari before the app, and the profile key that avoids that
//      (TargetApplicationBundleIdentifier) works only in profiles installed by MDM;
//   2. the wallpaper: The Bathing Pool saved to Photos, to set from there;
//   3. the widgets and the layout: HomePlan draws the dock and the pages.
// scripts/mirror_setup.py does steps 1 and 3 through iPhone Mirroring.

/// The 24 home screen icons as files ("Baroque Gmail.png" and so on) in the app's Documents, which the Files app shows
/// under On My iPhone > Baroque > Home screen icons.
enum IconFiles {
    static var folder: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Home screen icons", isDirectory: true)
    }

    static func export() {
        guard let folder else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for app in ContentView.homeIcons {
            let file = folder.appendingPathComponent("Baroque \(app).png")
            guard !FileManager.default.fileExists(atPath: file.path),
                  let data = UIImage(named: ContentView.iconAsset(app))?.pngData() else { continue }
            try? data.write(to: file)
        }
    }

    /// The folder in the Files app.
    static var filesURL: URL? { folder.flatMap { URL(string: "shareddocuments://" + $0.path) } }
}

/// Saves The Bathing Pool to Photos (the add-only permission is asked the first time).
final class WallpaperSaver: NSObject {
    static let shared = WallpaperSaver()
    private var done: ((Bool) -> Void)?

    func save(_ completion: @escaping (Bool) -> Void) {
        guard let image = UIImage(named: "Wallpaper") else { completion(false); return }
        done = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saved(_:error:context:)), nil)
    }

    @objc private func saved(_ image: UIImage, error: Error?, context: UnsafeRawPointer?) {
        let ok = error == nil
        DispatchQueue.main.async { [weak self] in self?.done?(ok); self?.done = nil }
    }
}

// MARK: - The plan

/// The author's home screen: the dock, then two pages of the 4 x 6 grid, each widget a labelled panel at its place and
/// size, each app its icon.
struct HomePlan: View {
    struct Item {
        var name: String
        var x: Int, y: Int
        var w = 1, h = 1
        var widget: Bool { w > 1 || h > 1 }
    }

    static let dock = ["Claude", "Messages", "Safari", "Obsidian"]
    static let pages: [[Item]] = [
        [Item(name: "Day · large", x: 0, y: 0, w: 4, h: 4)]
            + apps(["Gmail", "Photos", "Camera", "YouTube", "Settings", "Spotify", "Maps", "Calendar"], from: 16),
        [Item(name: "Day", x: 0, y: 0, w: 2, h: 2), Item(name: "Quote", x: 2, y: 2, w: 2, h: 2), Item(name: "Today", x: 0, y: 4, w: 2, h: 2),
         Item(name: "Weather", x: 2, y: 0), Item(name: "AllTrails", x: 3, y: 0), Item(name: "Uber Eats", x: 2, y: 1), Item(name: "Netflix", x: 3, y: 1),
         Item(name: "Equinox", x: 0, y: 2), Item(name: "Find My", x: 1, y: 2), Item(name: "Slack", x: 0, y: 3), Item(name: "Clock", x: 1, y: 3),
         Item(name: "Wallet", x: 2, y: 4), Item(name: "App Store", x: 3, y: 4), Item(name: "Files", x: 2, y: 5), Item(name: "Venmo", x: 3, y: 5)],
    ]

    /// Apps four to a row, starting at grid slot `from` (reading order).
    static func apps(_ names: [String], from: Int) -> [Item] {
        names.enumerated().map { i, name in Item(name: name, x: (from + i) % 4, y: (from + i) / 4) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(Self.pages.enumerated()), id: \.offset) { i, page in
                    PlanPage(number: i + 1, items: page)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    struct PlanPage: View {
        var number: Int
        var items: [Item]

        private let cell: CGFloat = 34, gap: CGFloat = 6

        /// The width (or height) of n grid cells and the gaps between them.
        private func span(_ n: Int) -> CGFloat { cell * CGFloat(n) + gap * CGFloat(n - 1) }

        var body: some View {
            VStack(spacing: 8) {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        Group {
                            if item.widget {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color(hex: 0xB5A483))
                                    .overlay(Text(item.name).font(.system(size: 10, weight: .semibold, design: .serif))
                                        .foregroundStyle(Color(hex: 0x3A2D23)))
                            } else {
                                PlanIcon(name: item.name, side: cell)
                            }
                        }
                        .frame(width: span(item.w), height: span(item.h))
                        .offset(x: CGFloat(item.x) * (cell + gap), y: CGFloat(item.y) * (cell + gap))
                    }
                }
                .frame(width: span(4), height: span(6), alignment: .topLeading)
                HStack(spacing: gap) {
                    ForEach(HomePlan.dock, id: \.self) { PlanIcon(name: $0, side: cell) }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.12)))
                Text("Page \(number)").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black.opacity(0.25)))
        }
    }

    struct PlanIcon: View {
        var name: String
        var side: CGFloat

        var body: some View {
            Image("Icon" + name.replacingOccurrences(of: " ", with: ""))
                .resizable()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.234, style: .continuous))
        }
    }
}
