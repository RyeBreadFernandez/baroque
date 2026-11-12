import Foundation
import XCTest
@testable import BaroqueCore

/// The vault's CSS snippets and fonts for the Brief page: fetched (from a stubbed GitHub), kept as files, fetched
/// again at most about once a day unless forced.
final class BriefStyleTests: XCTestCase {
    private var folder: URL!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let appearance = #"{"textFontFamily": "Times New Roman", "theme": "obsidian"}"#

    override func setUp() {
        StubGitHub.reset()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("BriefStyleTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        StubGitHub.reset()
        try? FileManager.default.removeItem(at: folder)
    }

    private func text(_ s: String) -> StubGitHub.Reply { .init(status: 200, body: Data(s.utf8)) }

    private func refresh(_ classes: [String], force: Bool = false, at date: Date? = nil) async -> BriefStyle.Sheets {
        await BriefStyle.refresh(classes: classes, client: StubGitHub.client(), folder: folder, force: force, now: date ?? now)
    }

    private var paths: [String] { StubGitHub.seen.map { $0.url.path.replacingOccurrences(of: "/repos/someone/notes/contents/", with: "") } }

    func testFetchesEachNamedSnippetAndTheAppearance() async {
        StubGitHub.replies = [text(".daily-brief { color: red }"), .status(404, message: "Not Found"), text(appearance)]
        let sheets = await refresh(["daily-brief", "wide-page"])
        XCTAssertEqual(paths, [".obsidian/snippets/daily-brief.css", ".obsidian/snippets/wide-page.css", ".obsidian/appearance.json"])
        XCTAssertEqual(StubGitHub.seen.first?.headers["Accept"], "application/vnd.github.raw+json")
        XCTAssertEqual(sheets.css, [".daily-brief { color: red }"])
        XCTAssertEqual(sheets.appearance?.textFontFamily, "Times New Roman")
        // Kept as files, for the page offline.
        XCTAssertEqual(BriefStyle.cached(classes: ["daily-brief", "wide-page"], folder: folder), sheets)
        XCTAssertEqual(BriefStyle.cached(classes: [], folder: folder).css, [])
    }

    func testNotFetchedAgainWithinADayUnlessForced() async {
        StubGitHub.replies = [text("a {}"), text(appearance)]
        _ = await refresh(["daily-brief"])
        XCTAssertEqual(StubGitHub.seen.count, 2)

        let later = await refresh(["daily-brief"], at: now.addingTimeInterval(3 * 3600))
        XCTAssertEqual(StubGitHub.seen.count, 2)
        XCTAssertEqual(later.css, ["a {}"])

        StubGitHub.replies = [text("b {}"), text(appearance)]
        let forced = await refresh(["daily-brief"], force: true, at: now.addingTimeInterval(3 * 3600))
        XCTAssertEqual(StubGitHub.seen.count, 4)
        XCTAssertEqual(forced.css, ["b {}"])

        StubGitHub.replies = [text("c {}"), text(appearance)]
        let tomorrow = await refresh(["daily-brief"], at: now.addingTimeInterval(24 * 3600))
        XCTAssertEqual(StubGitHub.seen.count, 6)
        XCTAssertEqual(tomorrow.css, ["c {}"])
    }

    func testANewClassIsFetchedAtOnce() async {
        StubGitHub.replies = [text("a {}"), text(appearance)]
        _ = await refresh(["daily-brief"])
        StubGitHub.replies = [text("a {}"), text("b {}"), text(appearance)]
        let sheets = await refresh(["daily-brief", "second"], at: now.addingTimeInterval(60))
        XCTAssertEqual(StubGitHub.seen.count, 5)
        XCTAssertEqual(sheets.css, ["a {}", "b {}"])
    }

    func testAFailedFetchKeepsTheLastCopyAndTriesAgain() async {
        StubGitHub.replies = [text("a {}"), text(appearance)]
        _ = await refresh(["daily-brief"])
        StubGitHub.replies = [.status(500), .status(500)]
        let offline = await refresh(["daily-brief"], force: true)
        XCTAssertEqual(offline.css, ["a {}"])
        XCTAssertEqual(offline.appearance?.textFontFamily, "Times New Roman")
    }

    func testAFirstFetchThatFailsIsTriedAgainNextTime() async {
        StubGitHub.replies = [.status(500), .status(500)]
        let offline = await refresh(["daily-brief"])
        XCTAssertEqual(offline, BriefStyle.Sheets())
        StubGitHub.replies = [text("b {}"), text(appearance)]
        let next = await refresh(["daily-brief"], at: now.addingTimeInterval(60))
        XCTAssertEqual(StubGitHub.seen.count, 4)
        XCTAssertEqual(next.css, ["b {}"])
    }

    func testASnippetGoneFromTheVaultIsForgotten() async {
        StubGitHub.replies = [text("a {}"), text(appearance)]
        _ = await refresh(["daily-brief"])
        StubGitHub.replies = [.status(404, message: "Not Found"), .status(404, message: "Not Found")]
        let sheets = await refresh(["daily-brief"], force: true)
        XCTAssertEqual(sheets, BriefStyle.Sheets())
    }

    func testOnlyPlainClassNamesNameFiles() async {
        let sheets = await refresh(["../../escape", "a/b", ""])
        XCTAssertEqual(paths, [".obsidian/appearance.json"])
        XCTAssertEqual(sheets.css, [])
    }

    func testNothingWithoutAToken() async {
        let sheets = await BriefStyle.refresh(classes: ["daily-brief"], client: StubGitHub.client(token: ""), folder: folder, now: now)
        XCTAssertEqual(sheets, BriefStyle.Sheets())
    }
}
