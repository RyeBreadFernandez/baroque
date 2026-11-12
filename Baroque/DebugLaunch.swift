#if DEBUG
import Foundation
import Photos
import UIKit
import WebKit
import WidgetKit

// Launch arguments for simulator testing and screenshots:
//   -resetData     fresh-install state (default settings, no caches, no token)
//   -seedDemoData  demo tasks and quotes in the shared cache, as if the vault had been fetched earlier
//   -saveIcons     saves the 24 home screen icons to Photos in home screen order (Claude oldest, Venmo newest), for
//                  making them in Shortcuts (the app also keeps them in Files, which is what Choose File uses)
// The Brief page (BriefView), on the simulator with no token (a path not starting with / is in the app's Documents,
// which stays put when a reinstall moves the app's container):
//   -briefFile <path>        the brief read from a file
//   -briefCSS <path>         a CSS snippet read from a file instead of the vault's (give it more than once for more)
//   -briefAppearance <path>  the vault's appearance.json read from a file
//   -briefScroll <points>    once the page has loaded, scrolls it down that far
//   -briefTap <line>         once the page has loaded, taps the checkbox of the task on that line of the note
//   -briefSnapshot           once the page has loaded, renders the whole page to Documents/brief-full.png, at the
//                            window's width, or at -briefSnapshotWidth <points> (brief-full-<points>.png)
enum DebugLaunch {
    static func apply(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let store = Store.shared
        var changed = false
        if arguments.contains("-resetData") {
            store.resetAll()
            if let folder = BriefStyle.folder { try? FileManager.default.removeItem(at: folder) }
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
        if let file = values(after: "-briefFile", in: arguments).last, let text = try? String(contentsOf: debugFile(file), encoding: .utf8) {
            store.brief = BriefSnapshot(markdown: text, fetchedAt: Date())
        }
        if arguments.contains("-saveIcons") {
            Task { await saveIcons() }
        }
    }

    // MARK: The Brief page

    /// The value after `flag`, each time it's given.
    private static func values(after flag: String, in arguments: [String]) -> [String] {
        arguments.indices.filter { arguments[$0] == flag && $0 + 1 < arguments.count }.map { arguments[$0 + 1] }
    }

    private static func number(after flag: String, in arguments: [String]) -> Double? {
        values(after: flag, in: arguments).last.flatMap(Double.init)
    }

    /// An absolute path, or one in the app's Documents.
    private static func debugFile(_ path: String) -> URL {
        if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(path)
    }

    /// `-briefCSS` and `-briefAppearance`: the Brief page's style from files, instead of the vault's.
    static func briefStyle(arguments: [String] = ProcessInfo.processInfo.arguments) -> BriefStyle.Sheets? {
        let css = values(after: "-briefCSS", in: arguments)
        let appearance = values(after: "-briefAppearance", in: arguments)
        guard !css.isEmpty || !appearance.isEmpty else { return nil }
        return BriefStyle.Sheets(css: css.compactMap { try? String(contentsOf: debugFile($0), encoding: .utf8) },
                                 appearance: appearance.last.flatMap { try? Data(contentsOf: debugFile($0)) }.flatMap(BriefHTML.Appearance.init(json:)))
    }

    /// Once the Brief page has loaded: `-briefTap`, `-briefScroll` and `-briefSnapshot`.
    @MainActor
    static func briefLoaded(_ webView: WKWebView, document: String) {
        let arguments = ProcessInfo.processInfo.arguments
        if let line = number(after: "-briefTap", in: arguments) {
            webView.evaluateJavaScript("baroque.tap(\(Int(line)))") { result, error in
                print("Baroque -briefTap \(Int(line)): \(error.map { "\($0)" } ?? "\(result ?? "")")")
            }
        }
        if let y = number(after: "-briefScroll", in: arguments) {
            webView.evaluateJavaScript("baroque.scroll(\(y))")
        }
        if arguments.contains("-briefSnapshot") {
            let width = number(after: "-briefSnapshotWidth", in: arguments).map { CGFloat($0) }
            Task { await BriefShot.capture(document, width: width, in: webView.window) }
        }
    }

    /// The whole page as one picture: a web view as wide as asked and as tall as the page, behind the app's views.
    @MainActor
    private final class BriefShot: NSObject, WKNavigationDelegate {
        private var loaded: CheckedContinuation<Void, Never>?

        static func capture(_ document: String, width: CGFloat?, in window: UIWindow?) async {
            guard let window else { return print("Baroque -briefSnapshot: no window") }
            let shot = BriefShot()
            let wide = width ?? window.bounds.width
            let web = WKWebView(frame: CGRect(x: 0, y: 0, width: wide, height: window.bounds.height))
            web.navigationDelegate = shot
            web.overrideUserInterfaceStyle = .light
            window.insertSubview(web, at: 0)
            defer { web.removeFromSuperview() }
            await withCheckedContinuation { continuation in
                shot.loaded = continuation
                web.loadHTMLString(document, baseURL: nil)
            }
            // The pictures and the fonts, then the page's height.
            let wait = """
            await document.fonts.ready;
            await Promise.all(Array.from(document.images, (i) => i.complete ? null : new Promise((r) => { i.addEventListener("load", r); i.addEventListener("error", r); })));
            return Math.ceil(document.documentElement.scrollHeight);
            """
            let height = (try? await web.callAsyncJavaScript(wait, contentWorld: .defaultClient)) as? NSNumber
            web.frame.size.height = CGFloat(height?.doubleValue ?? 3000)
            try? await Task.sleep(for: .milliseconds(800))
            // A web view out of sight paints no tiles, so `takeSnapshot` would be blank: the page is drawn as a PDF
            // (the web content process draws it whole), then onto an image at the screen's scale.
            do {
                let pdf = try await web.pdf(configuration: WKPDFConfiguration())
                guard let document = CGDataProvider(data: pdf as CFData).flatMap(CGPDFDocument.init), let page = document.page(at: 1) else {
                    return print("Baroque -briefSnapshot: no PDF page")
                }
                let box = page.getBoxRect(.mediaBox)
                let format = UIGraphicsImageRendererFormat()
                format.scale = window.screen.scale
                let image = UIGraphicsImageRenderer(size: box.size, format: format).image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: box.size))
                    context.cgContext.translateBy(x: 0, y: box.height)
                    context.cgContext.scaleBy(x: 1, y: -1)
                    context.cgContext.drawPDFPage(page)
                }
                let name = width == nil ? "brief-full.png" : "brief-full-\(Int(wide)).png"
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
                try image.pngData()?.write(to: url)
                print("Baroque -briefSnapshot: \(url.path) \(Int(box.width)) x \(Int(box.height)) (\(document.numberOfPages) page)")
            } catch {
                print("Baroque -briefSnapshot failed: \(error)")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded?.resume()
            loaded = nil
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
