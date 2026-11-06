import XCTest

// Places the Baroque widgets on the home screen through SpringBoard and captures screenshots in each data state.
// Tests run in name order; each one can also run alone (it places the widgets if they are missing).
//
//   test10_placeWidgets       removes any Baroque widgets, then builds four home pages:
//                               [Day large] / [Day medium + Quote medium] / [Today small + Battery small + Today medium]
//                               / [Day small + Quote small + Quote large]
//   test20_freshState         app launched with -resetData (no token, no cache)
//   test30_cachedState        app launched with -seedDemoData (demo tasks and quotes in the cache)
//   test35_quoteNextArrow     taps the quote on the medium quote widget (it is the next-quote button), before/after
//   test40_fakeTokenShows401  types "not-a-real-token", Save & Refresh, expects a 401 error; then -resetData again
//
// Screenshots go to <repo>/screenshots (override with TEST_RUNNER_TERRA_SCREENSHOT_DIR).
final class BaroqueScreenshotTests: XCTestCase {

    /// Seconds to let widgets fetch and re-render after the app reloads their timelines.
    private var widgetWait: Double {
        Double(ProcessInfo.processInfo.environment["TERRA_WIDGET_WAIT"] ?? "") ?? 15
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        // Baroque only asks for location when "Use current location" is tapped, but dismiss any system prompt.
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for label in ["Allow While Using App", "Allow Once", "Not Now", "Don’t Allow", "Don't Allow", "OK"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }
    }

    // MARK: - Layout signatures

    private static let dayLargePage: ([SB.Kind]) -> Bool = { $0 == [.large] }
    private static let mediumPage: ([SB.Kind]) -> Bool = { $0 == [.medium, .medium] }
    private static let todayPage: ([SB.Kind]) -> Bool = { $0 == [.small, .small, .medium] }
    private static let smallPage: ([SB.Kind]) -> Bool = { $0 == [.small, .small, .large] }

    // MARK: - Tests

    func test10_placeWidgets() {
        // Fresh data first so the gallery previews show the no-token state, not stale cache.
        let app = launchBaroque(["-resetData"])
        waitForRefresh(app)
        XCUIDevice.shared.press(.home)
        SB.pause(1)
        placeWidgets()

        let scan = SB.scanPages()
        print("TERRA-PAGES " + scan.map { "\($0.page): \($0.layout)" }.joined(separator: " | "))
        XCTAssertNotNil(SB.findPage(where: Self.dayLargePage, in: scan), "Baroque Day large page not found after placing")
        XCTAssertNotNil(SB.findPage(where: Self.mediumPage, in: scan), "Medium widgets page not found after placing")
        XCTAssertNotNil(SB.findPage(where: Self.todayPage, in: scan), "Today and Battery page not found after placing")
        XCTAssertNotNil(SB.findPage(where: Self.smallPage, in: scan), "Small widgets page not found after placing")
        XCTAssertEqual(scan.filter { !$0.layout.isEmpty }.count, 4, "Expected exactly four pages with Baroque widgets")
    }

    private func placeWidgets() {
        SB.removeAllBaroqueWidgets()
        SB.resetToHome()
        SB.goToPage(1)
        SB.enterEditMode()

        // Page A: Baroque Day large on its own (edit mode always offers a blank last page).
        SB.goToPage(99)
        SB.addBaroqueWidget("Baroque Day", size: "Large", beforeAdd: { Shots.save("30-widget-gallery-day-large", in: self) })

        // Page B: Baroque Day medium above Baroque Quote medium.
        SB.goToPage(99)
        SB.addBaroqueWidget("Baroque Quote", size: "Medium", beforeAdd: { Shots.save("31-widget-gallery-quote-medium", in: self) })
        SB.addBaroqueWidget("Baroque Day", size: "Medium")
        if SB.verbose { SB.dump("medium-page-editing") }

        // Page C: Today and Battery small side by side, Today medium under them (a new widget goes in at the top).
        SB.goToPage(99)
        SB.addBaroqueWidget("Baroque Today", size: "Medium")
        SB.addBaroqueWidget("Baroque Battery", size: "Small")
        SB.addBaroqueWidget("Baroque Today", size: "Small")

        // Page D: the two smalls side by side, Baroque Quote large under them.
        SB.goToPage(99)
        SB.addBaroqueWidget("Baroque Quote", size: "Large")
        SB.addBaroqueWidget("Baroque Quote", size: "Small")
        SB.addBaroqueWidget("Baroque Day", size: "Small")

        SB.exitEditMode()
        SB.resetToHome()
    }

    func test20_freshState() {
        let app = launchBaroque(["-resetData"])
        waitForRefresh(app)
        logAppTexts(app, tag: "fresh")
        Shots.save("01-app-preview-fresh", in: self)
        app.swipeUp()
        SB.pause(1)
        Shots.save("02-app-settings", in: self)
        app.swipeUp(); app.swipeUp()
        SB.pause(1)
        Shots.save("03-app-settings-location", in: self)

        XCUIDevice.shared.press(.home)
        shootHomePages(prefix: 10, state: "fresh")
    }

    func test30_cachedState() {
        let app = launchBaroque(["-seedDemoData"])
        waitForRefresh(app)
        logAppTexts(app, tag: "cached")
        Shots.save("05-app-preview-cached", in: self)

        XCUIDevice.shared.press(.home)
        shootHomePages(prefix: 20, state: "cached")
    }

    func test35_quoteNextArrow() {
        // Seeded quotes and offset 0 make the before/after quotes predictable.
        let app = launchBaroque(["-seedDemoData"])
        waitForRefresh(app)
        XCUIDevice.shared.press(.home)
        let scan = ensureWidgetsPlaced()

        guard let p = SB.findPage(where: Self.mediumPage, in: scan) else { XCTFail("Medium widgets page not found"); return }
        SB.goToPage(p)
        SB.pause(widgetWait)
        guard let quote = quoteWidget() else { XCTFail("Could not tell which medium widget is the quote"); return }
        let before = quote.screenshot().pngRepresentation
        Shots.save("25-quote-next-before", in: self)

        // The quote itself is the next-quote button: its words sit on the painting's right, under the top edge.
        let r = SB.widgetRect(quote)
        let arrow = CGPoint(x: r.minX + r.width * 0.76, y: r.minY + r.height * 0.32)
        SB.app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: arrow.x, dy: arrow.y)).tap()
        SB.pause(6)
        // A miss would open the app instead; note it and go back.
        let baroque = XCUIApplication()
        let openedApp = baroque.state == .runningForeground
        if openedApp { XCUIDevice.shared.press(.home); SB.pause(1); SB.goToPage(p) }
        XCTAssertFalse(openedApp, "Tapping the arrow opened the app; the tap missed the button")
        let after = quote.screenshot().pngRepresentation
        Shots.save("26-quote-next-after", in: self)
        XCTAssertNotEqual(before, after, "Quote widget did not change after tapping the next arrow")
        print("TERRA-ARROW tapped at \(arrow) in widget \(r); changed=\(before != after)")
    }

    func test40_fakeTokenShows401() {
        let app = launchBaroque(["-resetData"])
        waitForRefresh(app)

        // A fresh install has no vault repository (it would say so before asking GitHub): any owner and name will do,
        // since GitHub rejects a bad token before it looks for the repository.
        let field = app.secureTextFields["Personal access token"]
        for _ in 0..<6 where !(field.exists && field.isHittable) { app.swipeUp(); SB.pause(0.5) }
        XCTAssertTrue(field.isHittable, "Token field not reachable")
        for (label, value) in [("Owner", "example-user"), ("Repository", "example-vault")] {
            let text = app.textFields[label].firstMatch
            XCTAssertTrue(text.isHittable, "\(label) field not reachable")
            text.tap()
            text.typeText(value)
        }
        field.tap()
        field.typeText("not-a-real-token")
        app.buttons["Save & Refresh"].firstMatch.tap()

        // The error shows in the preview at the top; the form only builds the rows on screen, so scroll back first.
        for _ in 0..<6 { app.swipeDown() }
        let err401 = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '401'")).firstMatch
        XCTAssertTrue(err401.waitForExistence(timeout: 40), "No 401 error shown in the app after saving a fake token")
        SB.pause(1)
        logAppTexts(app, tag: "token-401")
        Shots.save("06-app-token-401", in: self)

        // The widget extension reads the token the app stored (Keychain / App Group) and gets the same 401.
        XCUIDevice.shared.press(.home)
        let scan = ensureWidgetsPlaced()
        if let p = SB.findPage(where: Self.dayLargePage, in: scan) {
            SB.goToPage(p); SB.pause(widgetWait)
            Shots.save("40-home-day-large-token-401", in: self)
        }
        if let p = SB.findPage(where: Self.mediumPage, in: scan) {
            SB.goToPage(p); SB.pause(4)
            Shots.save("41-home-medium-token-401", in: self)
        }

        // Clean up: back to the fresh, no-token state.
        let again = launchBaroque(["-resetData"])
        waitForRefresh(again)
        let tokenAfter = again.secureTextFields["Personal access token"]
        if tokenAfter.exists, let v = tokenAfter.value as? String { print("TERRA-TOKEN-FIELD after reset: '\(v)'") }
        XCUIDevice.shared.press(.home)
    }

    // MARK: - Helpers

    private func launchBaroque(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.navigationBars["Baroque"].waitForExistence(timeout: 20), "Baroque did not launch")
        return app
    }

    /// The app refreshes on launch and shows "Updated: …" when done.
    private func waitForRefresh(_ app: XCUIApplication) {
        let updated = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Updated'")).firstMatch
        if !updated.waitForExistence(timeout: 40) { print("TERRA-WARN no 'Updated' status after 40 s") }
        SB.pause(1.5)
    }

    private func logAppTexts(_ app: XCUIApplication, tag: String) {
        let labels = app.staticTexts.allElementsBoundByIndex.prefix(60).map { $0.label }
        print("TERRA-TEXTS [\(tag)] " + labels.joined(separator: " | "))
    }

    /// Scans the home pages, placing the widgets first if any layout is missing.
    @discardableResult
    private func ensureWidgetsPlaced() -> [(page: Int, layout: [SB.Kind])] {
        var scan = SB.scanPages()
        let complete = [Self.dayLargePage, Self.mediumPage, Self.todayPage, Self.smallPage].allSatisfy { SB.findPage(where: $0, in: scan) != nil }
        if !complete {
            placeWidgets()
            scan = SB.scanPages()
        }
        return scan
    }

    private func shootHomePages(prefix: Int, state: String) {
        let scan = ensureWidgetsPlaced()
        var first = true
        let pages: [(String, ([SB.Kind]) -> Bool)] = [
            ("home-day-large", Self.dayLargePage),
            ("home-day-medium-quote-medium", Self.mediumPage),
            ("home-today-battery", Self.todayPage),
            ("home-day-small-quote-small-quote-large", Self.smallPage)
        ]
        for (i, entry) in pages.enumerated() {
            guard let p = SB.findPage(where: entry.1, in: scan) else { XCTFail("Page for \(entry.0) not found"); continue }
            SB.goToPage(p)
            SB.pause(first ? widgetWait : 5)
            first = false
            Shots.save(String(format: "%02d-%@-%@", prefix + i, entry.0, state), in: self)
        }
    }

    /// Of the two medium widgets, the quote one is a painting darkened under its words in the lower right, where the
    /// Day widget is pale limestone.
    private func quoteWidget() -> XCUIElement? {
        let mediums = SB.visibleBaroqueWidgets().filter { SB.kind(of: $0) == .medium }
        let scored = mediums.map { ($0, Self.buttonCornerBrightness(of: $0)) }
        for (w, b) in scored { print("TERRA-BUTTON widget at \(w.frame) corner brightness \(b)") }
        return scored.min { $0.1 < $1.1 }?.0
    }

    private static func buttonCornerBrightness(of element: XCUIElement) -> Double {
        guard let cg = element.screenshot().image.cgImage else { return 0 }
        let frame = element.frame
        guard frame.width > 0 else { return 0 }
        // The disc's centre is 26 pt in from the right and bottom of the widget; sample a 16 pt square round it.
        let s = Double(cg.width) / Double(frame.width)
        let r = SB.widgetRect(element)
        let cx = (Double(r.maxX - frame.minX) - 26) * s, cy = (Double(r.maxY - frame.minY) - 26) * s
        guard let part = cg.cropping(to: CGRect(x: cx - 8 * s, y: cy - 8 * s, width: 16 * s, height: 16 * s)) else { return 0 }
        var px = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.interpolationQuality = .medium
        ctx.draw(part, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Double(px[0]) + Double(px[1]) + Double(px[2])) / (3 * 255)
    }
}
