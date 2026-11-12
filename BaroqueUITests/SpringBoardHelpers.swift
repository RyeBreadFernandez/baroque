import XCTest

// SpringBoard automation for the iOS 26 home screen. Every label below was read from
// springboard.debugDescription on an iOS 26.4 iPhone 17 simulator, not guessed.
//
// Add-widget flow: long-press empty space (edit mode: Button "Edit" top left, "Done" top right)
// -> "Edit" -> menu Button "Add Widget" -> SearchField "Search Widgets" -> type "Baroque" -> Cell "Baroque"
// -> detail sheet with one page per widget and size, 13 of them in galleryOrder (PageIndicator value "page 3 of 13";
// preview Button label "Baroque, Baroque Day", value "Widget, Large") -> Button " Add Widget" (leading space).
// Placed widgets are Icon elements with identifier "Baroque" and value "Widget" (the app icon has an empty value).
// Remove: in edit mode Button identifier "DeleteButton" at the widget's top-left corner
// -> Alert "Remove “Baroque” Widget?" -> Button "Remove".
// Home pages: PageIndicator identifier "Page control", value "Page 2 of 3". Edit mode adds one blank page at the end.
enum SB {
    static let app = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    static var pageControl: XCUIElement { app.pageIndicators["Page control"].firstMatch }
    static var editButton: XCUIElement { app.buttons["Edit"].firstMatch }
    static var doneButton: XCUIElement { app.buttons["Done"].firstMatch }
    static var searchField: XCUIElement { app.searchFields["Search Widgets"].firstMatch }
    static var sheetGrabber: XCUIElement { app.buttons["Sheet Grabber"].firstMatch }
    static var isEditing: Bool { doneButton.exists && editButton.exists }

    static func pause(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    static var verbose: Bool { ProcessInfo.processInfo.environment["TERRA_DUMP"] == "1" }

    static func dump(_ tag: String) {
        print("=====DUMP-BEGIN \(tag)=====")
        print(app.debugDescription)
        print("=====DUMP-END \(tag)=====")
    }

    // MARK: Pages

    /// (current, total) from the page indicator value "Page 2 of 3", or nil when not on a home page.
    static func page() -> (Int, Int)? {
        guard pageControl.exists, let v = pageControl.value as? String else { return nil }
        let nums = v.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard nums.count >= 2 else { return nil }
        return (nums[0], nums[1])
    }

    /// A slow one-page swipe through a band near the bottom of the grid.
    static func swipePage(left: Bool) {
        let y = 0.76
        let a = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: y))
        let b = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.25 : 0.75, dy: y))
        a.press(forDuration: 0.05, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.05)
        pause(1.0)
    }

    /// Dismisses alerts and sheets, leaves edit mode and returns to a home screen page.
    static func resetToHome() {
        for _ in 0..<6 {
            let alert = app.alerts.firstMatch
            if alert.exists {
                let cancel = alert.buttons["Cancel"]
                if cancel.exists { cancel.tap() } else { alert.buttons.firstMatch.tap() }
                pause(0.8)
                continue
            }
            let sheetOpen = sheetGrabber.exists || searchField.exists
            if !sheetOpen && !isEditing && page() != nil { return }
            XCUIDevice.shared.press(.home)
            pause(1.2)
        }
    }

    /// Moves to page `n` (clamped to the last page). Works in and out of edit mode.
    static func goToPage(_ n: Int) {
        for _ in 0..<14 {
            guard let (cur, total) = page() else {
                XCUIDevice.shared.press(.home); pause(1.2); continue
            }
            let target = max(1, min(n, total))
            if cur == target { return }
            swipePage(left: cur < target)
        }
    }

    // MARK: Edit mode

    /// Frames of every icon and widget visible on the current page.
    static func visibleIconFrames() -> [CGRect] {
        let screen = app.frame
        return app.icons.allElementsBoundByIndex.map { $0.frame }
            .filter { $0.width > 10 && $0.minX >= -1 && $0.maxX <= screen.maxX + 1 }
    }

    /// Long-presses empty space to enter edit mode. Long-pressing a widget or icon would open its context menu
    /// instead (and stall XCTest about 60 s waiting for SpringBoard to idle), so pick a point that is free.
    static func enterEditMode(file: StaticString = #filePath, line: UInt = #line) {
        if isEditing { return }
        let screen = app.frame
        let taken = visibleIconFrames().map { $0.insetBy(dx: -6, dy: -6) }
        let candidates: [CGVector] = [
            CGVector(dx: 0.5, dy: 0.76), CGVector(dx: 0.5, dy: 0.70), CGVector(dx: 0.15, dy: 0.76),
            CGVector(dx: 0.85, dy: 0.76), CGVector(dx: 0.5, dy: 0.62), CGVector(dx: 0.5, dy: 0.08)
        ]
        let free = candidates.filter { v in
            let pt = CGPoint(x: screen.width * v.dx, y: screen.height * v.dy)
            return !taken.contains { $0.contains(pt) }
        }
        for v in (free.isEmpty ? [candidates[0]] : free).prefix(3) {
            app.coordinate(withNormalizedOffset: v).press(forDuration: 1.6)
            if doneButton.waitForExistence(timeout: 3) { return }
            // A long-press that landed on an icon opens a context menu; it has "Edit Home Screen".
            let editHome = app.buttons["Edit Home Screen"].firstMatch
            if editHome.exists { editHome.tap(); if doneButton.waitForExistence(timeout: 5) { return } }
        }
        XCTFail("Could not enter home screen edit mode", file: file, line: line)
    }

    static func exitEditMode() {
        if doneButton.exists { doneButton.tap() }
        pause(1.5)
    }

    // MARK: Baroque widgets on screen

    enum Kind { case small, medium, large }

    /// Baroque widgets visible on the current page, top to bottom then left to right.
    static func visibleBaroqueWidgets() -> [XCUIElement] {
        let screen = app.frame
        return app.icons.matching(identifier: "Baroque").allElementsBoundByIndex
            .filter { (($0.value as? String) ?? "").contains("Widget") }
            .filter { $0.frame.width > 100 && $0.frame.minX >= -1 && $0.frame.maxX <= screen.maxX + 1 }
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
    }

    static func kind(of widget: XCUIElement) -> Kind {
        let f = widget.frame
        if f.width < 250 { return .small }
        return f.height > 300 ? .large : .medium
    }

    /// The widget's own rectangle (the Icon frame also includes the "Baroque" label under it).
    static func widgetRect(_ widget: XCUIElement) -> CGRect {
        let f = widget.frame
        return CGRect(x: f.minX + 2, y: f.minY + 2, width: f.width - 4, height: f.height - 26.7)
    }

    /// Kinds on the current page, e.g. [.medium, .medium].
    static func currentLayout() -> [Kind] { visibleBaroqueWidgets().map(kind(of:)) }

    /// Visits every home page once (out of edit mode) and returns the Baroque widget layout of each.
    static func scanPages() -> [(page: Int, layout: [Kind])] {
        resetToHome()
        goToPage(1)
        guard let (_, total) = page() else { return [] }
        var result: [(page: Int, layout: [Kind])] = []
        for p in 1...total {
            goToPage(p)
            pause(0.6)
            result.append((p, currentLayout()))
        }
        return result
    }

    /// First home page whose Baroque widgets match `matches`.
    @discardableResult
    static func findPage(where matches: ([Kind]) -> Bool, in scan: [(page: Int, layout: [Kind])]? = nil) -> Int? {
        (scan ?? scanPages()).first { matches($0.layout) }?.page
    }

    // MARK: Remove

    /// Removes every Baroque widget on every page (so placement is idempotent).
    static func removeAllBaroqueWidgets() {
        // Find pages that hold Baroque widgets first (no edit mode), then delete from the last one back.
        let pages = scanPages().filter { !$0.layout.isEmpty }.map { $0.page }
        guard !pages.isEmpty else { return }
        goToPage(1)   // page 1 has free space under its icon grid for the long-press
        enterEditMode()
        for p in pages.reversed() {
            goToPage(p)
            for _ in 0..<6 {
                guard let w = visibleBaroqueWidgets().first else { break }
                let corner = CGPoint(x: w.frame.minX, y: w.frame.minY)
                let dels = app.buttons.matching(identifier: "DeleteButton").allElementsBoundByIndex
                let del = dels.min { hypot($0.frame.midX - corner.x, $0.frame.midY - corner.y) < hypot($1.frame.midX - corner.x, $1.frame.midY - corner.y) }
                guard let d = del, hypot(d.frame.midX - corner.x, d.frame.midY - corner.y) < 40 else { break }
                d.tap()
                let remove = app.alerts.buttons["Remove"].firstMatch
                if remove.waitForExistence(timeout: 3) { remove.tap() }
                pause(1.2)
            }
        }
        exitEditMode()
        resetToHome()
    }

    // MARK: Add

    /// The gallery's previews, in the widget bundle's order (BaroqueWidgets.swift).
    static let galleryOrder = ["Baroque Day|Small", "Baroque Day|Medium", "Baroque Day|Large",
                               "Baroque Today|Small", "Baroque Today|Medium", "Baroque Today|Large",
                               "Baroque Quote|Small", "Baroque Quote|Medium", "Baroque Quote|Large", "Baroque Battery|Small",
                               "Baroque Still Life|Small", "Baroque Still Life|Large", "Baroque Photograph|Small"]

    static var galleryIndicator: XCUIElement {
        app.pageIndicators.matching(NSPredicate(format: "value BEGINSWITH 'page '")).firstMatch
    }

    /// Current gallery page (1-based) and the page count, from "page 3 of 13".
    static func galleryPages() -> (current: Int, total: Int)? {
        guard galleryIndicator.exists, let v = galleryIndicator.value as? String else { return nil }
        let nums = v.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard nums.count >= 2 else { return nil }
        return (nums[0], nums[1])
    }

    /// Current gallery page (1-based) from "page 3 of 13".
    static func galleryPage() -> Int? { galleryPages()?.current }

    /// The preview button closest to the horizontal centre of the screen.
    static func currentPreview() -> (label: String, value: String)? {
        let all = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Baroque, Baroque '")).allElementsBoundByIndex
        let mid = app.frame.midX
        let best = all.filter { $0.frame.width > 10 }.min { abs($0.frame.midX - mid) < abs($1.frame.midX - mid) }
        guard let b = best else { return nil }
        return (b.label, (b.value as? String) ?? "")
    }

    /// A preview as `galleryOrder` writes it: label "Baroque, Baroque Day" (the app, then the widget's name) and value
    /// "Widget, Large" -> "Baroque Day|Large".
    static func entry(label: String, value: String) -> String {
        let parts = label.components(separatedBy: ", ")
        let name = parts.count > 1 ? parts[1] : label
        let size = ["Small", "Medium", "Large"].first { value.contains($0) } ?? "?"
        return "\(name)|\(size)"
    }

    /// The centred preview as `galleryOrder` writes it, read again for a moment while the page settles; nil if unreadable.
    static func currentEntry() -> String? {
        for _ in 0..<4 {
            if let p = currentPreview() { return entry(label: p.label, value: p.value) }
            pause(0.5)
        }
        return nil
    }

    /// Opens the widget gallery on Baroque's widgets from the current home page (entering edit mode if needed).
    @discardableResult
    static func openBaroqueGallery(file: StaticString = #filePath, line: UInt = #line) -> Bool {
        enterEditMode(file: file, line: line)
        guard editButton.waitForExistence(timeout: 3) else { XCTFail("No Edit button", file: file, line: line); return false }
        editButton.tap()
        let addMenu = app.buttons["Add Widget"].firstMatch
        guard addMenu.waitForExistence(timeout: 5) else { XCTFail("No Add Widget menu item", file: file, line: line); return false }
        addMenu.tap()
        guard searchField.waitForExistence(timeout: 8) else { XCTFail("Widget gallery did not open", file: file, line: line); return false }
        searchField.tap()
        searchField.typeText("Baroque")
        let cell = app.cells["Baroque"].firstMatch
        guard cell.waitForExistence(timeout: 8) else { XCTFail("Baroque not found in widget gallery", file: file, line: line); return false }
        cell.tap()
        guard galleryIndicator.waitForExistence(timeout: 8) else { XCTFail("Widget gallery pages not shown", file: file, line: line); return false }
        return true
    }

    /// Opens Baroque's gallery and reads every page from the first, one swipe at a time: the previews in page order,
    /// as `galleryOrder` writes them ("?" where a page's preview couldn't be read). Places nothing.
    static func readGallery(file: StaticString = #filePath, line: UInt = #line) -> [String] {
        guard openBaroqueGallery(file: file, line: line) else { return [] }
        for _ in 0..<20 {
            guard let cur = galleryPage(), cur > 1 else { break }
            app.swipeRight()
            pause(0.8)
        }
        guard let (first, total) = galleryPages(), first == 1 else {
            XCTFail("Could not get to the gallery's first page", file: file, line: line)
            return []
        }
        var entries: [String] = []
        for page in 1...total {
            guard galleryPage() == page else {
                XCTFail("The gallery is on page \(galleryPage() ?? 0), not \(page)", file: file, line: line)
                break
            }
            entries.append(currentEntry() ?? "?")
            if verbose { print("TERRA gallery page \(page) of \(total): \(entries.last ?? "-")") }
            if page < total { app.swipeLeft(); pause(0.8) }
        }
        return entries
    }

    /// Adds a Baroque widget on the current page (must already be in edit mode or it enters it).
    /// `widget` is a name in `galleryOrder` ("Baroque Day", "Baroque Today", …); `size` is "Small", "Medium" or "Large".
    /// `beforeAdd` runs while the gallery shows the chosen widget (used for gallery screenshots).
    @discardableResult
    static func addBaroqueWidget(_ widget: String, size: String, beforeAdd: (() -> Void)? = nil,
                               file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard let index = galleryOrder.firstIndex(of: "\(widget)|\(size)") else {
            XCTFail("\(widget) \(size) isn't in galleryOrder", file: file, line: line)
            return false
        }
        guard openBaroqueGallery(file: file, line: line) else { return false }
        let wantedIndex = index + 1
        var found = false
        for _ in 0..<20 {
            let cur = galleryPage() ?? 1
            if cur == wantedIndex {
                // The page must show the wanted widget at the wanted size; a preview that can't be read doesn't count.
                let shown = currentEntry()
                if verbose { print("TERRA gallery page \(cur): \(shown ?? "-"), want \(widget)|\(size)") }
                found = shown == "\(widget)|\(size)"
                break
            }
            if cur < wantedIndex { app.swipeLeft() } else { app.swipeRight() }
            pause(0.8)
        }
        guard found else { XCTFail("Could not select \(widget) \(size) in the gallery", file: file, line: line); return false }
        pause(1.0)
        beforeAdd?()
        let add = app.buttons[" Add Widget"].firstMatch
        let addButton = add.exists ? add : app.buttons.matching(NSPredicate(format: "label ENDSWITH 'Add Widget'")).element(boundBy: 0)
        guard addButton.waitForExistence(timeout: 5) else { XCTFail("No ' Add Widget' button", file: file, line: line); return false }
        addButton.tap()
        pause(2.5)
        return true
    }
}
