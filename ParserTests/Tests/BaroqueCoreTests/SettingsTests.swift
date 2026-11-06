import Foundation
import XCTest
@testable import BaroqueCore

final class SettingsTests: XCTestCase {
    /// Settings saved by an older version, missing fields added since, keep everything they do have.
    func testOlderSavedSettingsKeepTheirValues() throws {
        let saved = #"{"githubOwner":"someone","githubRepo":"vault","latitude":37.5,"longitude":-122.25,"taskPaths":"Notes/Tasks.md"}"#
        let s = try JSONDecoder().decode(BaroqueSettings.self, from: Data(saved.utf8))
        XCTAssertEqual(s.githubOwner, "someone")
        XCTAssertEqual(s.githubRepo, "vault")
        XCTAssertEqual(s.latitude, 37.5)
        XCTAssertEqual(s.taskPaths, "Notes/Tasks.md")
        XCTAssertEqual(s.quotesPath, BaroqueSettings.default.quotesPath)   // missing: the default
        XCTAssertEqual(s.quoteRotationMinutes, 60)
    }

    func testRoundTrip() throws {
        var s = BaroqueSettings.default
        s.githubOwner = "someone"
        s.useFahrenheit = false
        let back = try JSONDecoder().decode(BaroqueSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }
}
