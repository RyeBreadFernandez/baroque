import XCTest

// Placeholder; the runtime tester fills this in with SpringBoard automation.
final class WidgetGalleryUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Baroque"].waitForExistence(timeout: 10))
    }
}
