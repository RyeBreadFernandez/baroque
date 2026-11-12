import XCTest

// Steps through Baroque's page of the widget gallery and checks every preview's widget and size against
// SB.galleryOrder, the order addBaroqueWidget relies on. It places nothing on the home screen.
final class WidgetGalleryUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testGalleryShowsEveryWidgetInOrder() {
        // Launched once so the widget extension is registered with the system.
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Baroque"].waitForExistence(timeout: 20), "Baroque did not launch")
        XCUIDevice.shared.press(.home)
        SB.pause(1)
        SB.resetToHome()
        SB.goToPage(1)

        let shown = SB.readGallery()
        print("TERRA-GALLERY " + shown.joined(separator: " / "))
        SB.resetToHome()

        XCTAssertEqual(shown.count, SB.galleryOrder.count,
                       "The gallery has \(shown.count) Baroque previews; galleryOrder lists \(SB.galleryOrder.count)")
        for (i, want) in SB.galleryOrder.enumerated() {
            let got = i < shown.count ? shown[i] : "nothing"
            XCTAssertEqual(got, want, "Gallery page \(i + 1) shows \(got), not \(want)")
        }
    }
}
