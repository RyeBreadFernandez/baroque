#if DEBUG
import Foundation
import Photos
import UIKit
import WidgetKit

// Launch arguments for simulator testing and screenshots:
//   -resetData     fresh-install state (default settings, no caches, no token)
//   -seedDemoData  demo tasks and quotes in the shared cache, as if the vault had been fetched earlier
//   -saveIcons     saves the 24 home screen icons to Photos in home screen order (Claude oldest, Venmo newest), for
//                  making them in Shortcuts (the app also keeps them in Files, which is what Choose File uses)
enum DebugLaunch {
    static func apply(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let store = Store.shared
        var changed = false
        if arguments.contains("-resetData") {
            store.resetAll()
            changed = true
        }
        if arguments.contains("-seedDemoData") {
            var day = DemoData.day()
            day.weather = nil // let the real Open-Meteo fetch fill this in
            store.daySnapshot = day
            store.quoteSnapshot = QuoteSnapshot(quotes: DemoData.quotes, fetchedAt: Date(), error: nil)
            store.quoteOffset = 0
            changed = true
        }
        if changed { WidgetCenter.shared.reloadAllTimelines() }
        // -briefFile <path>: a Daily Brief read from a file, for the Brief page on the simulator (no token needed).
        if let i = arguments.firstIndex(of: "-briefFile"), i + 1 < arguments.count,
           let text = try? String(contentsOfFile: arguments[i + 1], encoding: .utf8) {
            store.brief = BriefSnapshot(markdown: text, fetchedAt: Date())
        }
        if arguments.contains("-saveIcons") {
            Task { await saveIcons() }
        }
    }

    /// One asset per icon, each a second newer than the last so Photos keeps them in order.
    private static func saveIcons() async {
        guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else {
            print("Baroque -saveIcons: no permission to add to Photos")
            return
        }
        let start = Date()
        var saved = 0
        for (i, app) in HomeIcons.apps.enumerated() {
            guard let image = UIImage(named: HomeIcons.asset(app)) else { continue }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image).creationDate = start.addingTimeInterval(Double(i))
                }
                saved += 1
            } catch {
                print("Baroque -saveIcons: \(app) failed: \(error.localizedDescription)")
            }
        }
        print("Baroque -saveIcons: saved \(saved) of \(HomeIcons.apps.count)")
    }
}
#endif
