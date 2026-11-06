import Foundation
import SwiftUI

// The app's widget paint textures (Shared/PaintTextures.xcassets) and the retired looks' (Archive.xcassets) for the
// macOS layout mocks.
// Theme.swift and Landscape.swift load them with Image("PaintPanel") and friends, which on macOS reads the main
// bundle's compiled catalog; a SwiftPM executable's main bundle is its build folder, so the catalog is compiled
// there (xcrun actool) whenever it is missing or older than the source. Call PaintAssets.install() first in main.
enum PaintAssets {
    static func install() {
        // The app's catalog, and the retired looks' paintings that left it (Archive.xcassets: the Cover paintings).
        let catalogs = [Mock.root.deletingLastPathComponent().appendingPathComponent("Shared/PaintTextures.xcassets"),
                        Mock.root.appendingPathComponent("Archive.xcassets")]
        guard let binDir = Bundle.main.executableURL?.deletingLastPathComponent() else { return }
        let car = binDir.appendingPathComponent("Assets.car")
        if let built = modified(car), let source = catalogs.compactMap(newest).max(), built >= source { return }

        let actool = Process()
        actool.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        actool.arguments = ["actool"] + catalogs.map(\.path) + ["--compile", binDir.path, "--platform", "macosx",
                            "--minimum-deployment-target", "14.0", "--output-format", "human-readable-text"]
        actool.standardOutput = FileHandle.nullDevice
        do {
            try actool.run()
            actool.waitUntilExit()
        } catch {
            FileHandle.standardError.write("PaintAssets: could not run actool: \(error)\n".data(using: .utf8)!)
        }
        if !FileManager.default.fileExists(atPath: car.path) {
            FileHandle.standardError.write("PaintAssets: no Assets.car; slabs and sky will render without paint\n".data(using: .utf8)!)
        }
    }

    private static func modified(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private static func newest(in dir: URL) -> Date? {
        let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
        return (files?.allObjects as? [URL])?.compactMap(modified).max()
    }
}

/// A painted layout mock: the app's painted look, arranged differently.
/// `day` and `quote` return the whole widget, background included, at `Mock.size(family)`.
protocol PaintedLayout: MockAesthetic {}

extension BaroqueSize {
    init(_ family: Family) {
        switch family {
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        }
    }
}

/// The home-screen wallpaper behind every painted layout board: the app's night gradient with its painted
/// relief, so the boards compare layouts and nothing else.
struct PaintedWallpaper: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: 0x0D1519), Color(hex: 0x26363A)], startPoint: .top, endPoint: .bottom)
            .overlay(PaintRelief(name: "PaintSky", opacity: 0.55))
            .overlay(PaintRelief(name: "PaintRidge", opacity: 0.18, flip: true))
    }
}
