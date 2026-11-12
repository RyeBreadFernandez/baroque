import Foundation
import XCTest
@testable import BaroqueCore

final class BriefTests: XCTestCase {
    private func tasks(in md: String) -> [Brief.TaskLine] {
        Brief.parse(md).blocks.compactMap { if case .task(let t) = $0 { return t } else { return nil } }
    }

    /// Every task the widget lists from a note is a task on the page, at the same line.
    private func assertWidgetTasksHaveRings(_ md: String, file: StaticString = #filePath, line: UInt = #line) {
        let widget = TaskParser.parse(markdown: md, sourcePath: BaroqueSettings.dailyBriefPath)
        let page = tasks(in: md).filter { !$0.done }
        XCTAssertEqual(page.map(\.lineNumber), widget.map(\.lineNumber), file: file, line: line)
        XCTAssertEqual(page.map(\.text), widget.map(\.text), file: file, line: line)
    }

    // MARK: F31: read as the widget reads

    func testTheExampleBrief() throws {
        let md = try String(contentsOf: repoRoot.appendingPathComponent("examples/Daily Brief/Today.md"), encoding: .utf8)
        let note = Brief.parse(md)
        XCTAssertEqual(note.generated, "2026-11-06 05:42 PT")
        XCTAssertEqual(tasks(in: md).count, 3)
        assertWidgetTasksHaveRings(md)
        XCTAssertEqual(tasks(in: md).first?.line, "- [ ] #todo Send the garden club the draft of the spring planting plan. (Sam, email, Nov 5)")
        XCTAssertEqual(tasks(in: md).first?.lineNumber, 12)
        XCTAssertEqual(note.blocks.first, .title("November 6"))
    }

    func testCRLF() {
        let md = "# Today\r\n\r\n## Needs attention\r\n- [ ] One\r\n- [x] Two ✅ 2026-11-10\r\n- A bullet\r\n"
        let t = tasks(in: md)
        XCTAssertEqual(t.map(\.lineNumber), [4, 5])
        XCTAssertEqual(t.map(\.done), [false, true])
        XCTAssertEqual(t.map(\.text), ["One", "Two"])
        XCTAssertEqual(t.first?.line, "- [ ] One")
        XCTAssertEqual(Brief.parse(md).blocks.last, .bullet("A bullet"))
        assertWidgetTasksHaveRings(md)
    }

    func testByteOrderMarkKeepsTheFrontMatter() {
        let md = "\u{FEFF}---\ngenerated: 2026-11-06 05:42 PT\n---\n# Today\n- [ ] One"
        let note = Brief.parse(md)
        XCTAssertEqual(note.generated, "2026-11-06 05:42 PT")
        XCTAssertEqual(note.blocks.first, .title("Today"))
        XCTAssertEqual(tasks(in: md).map(\.lineNumber), [5])
        assertWidgetTasksHaveRings(md)
    }

    func testFencedAndCommentedTasksAreNotTasks() {
        let md = "```tasks\n- [ ] not done\n```\n%% - [ ] hidden %%\n- [ ] Real one"
        XCTAssertEqual(tasks(in: md).map(\.text), ["Real one"])
        XCTAssertEqual(tasks(in: md).map(\.lineNumber), [5])
        assertWidgetTasksHaveRings(md)
    }

    func testOtherMarkersInProgressAndTabs() {
        let md = "* [ ] Star\n+ [ ] Plus\n1. [ ] Numbered\n- [/] Half done\n\t- [ ] Tabbed\n- [-] Cancelled"
        XCTAssertEqual(tasks(in: md).map(\.lineNumber), [1, 2, 3, 4, 5])
        XCTAssertEqual(tasks(in: md).map(\.text), ["Star", "Plus", "Numbered", "Half done", "Tabbed"])
        XCTAssertEqual(Brief.parse(md).blocks.last, .bullet("Cancelled"))
        assertWidgetTasksHaveRings(md)
    }

    func testIndentedTaskKeepsItsLine() {
        let md = "- [ ] Parent\n    - [ ] Child"
        let child = tasks(in: md).last
        XCTAssertEqual(child?.lineNumber, 2)
        XCTAssertEqual(child?.line, "    - [ ] Child")
        assertWidgetTasksHaveRings(md)
    }

    func testTextIsPlain() {
        let md = "## **Notes**\n- The book club picked *Walden* and [[Reading list|the list]]\nA **bold** line."
        let blocks = Brief.parse(md).blocks
        XCTAssertEqual(blocks, [.section("Notes"), .bullet("The book club picked Walden and the list"), .paragraph("A bold line.")])
    }

    func testTitleHasNoWeekday() {
        XCTAssertEqual(Brief.parse("# Friday, November 6").blocks, [.title("November 6")])
        XCTAssertEqual(Brief.withoutWeekday("Sat, Nov 7"), "Nov 7")
        XCTAssertEqual(Brief.withoutWeekday("Sunrise walk"), "Sunrise walk")
        XCTAssertEqual(Brief.withoutWeekday("Monday"), "Monday")   // nothing left after it: kept
    }

    // MARK: F32: the path and the Obsidian link

    func testPathIsTheBriefOrTheFirstTaskPath() {
        var s = BaroqueSettings.default
        XCTAssertEqual(Brief.path(settings: s), "Daily Brief/Today.md")
        s.taskPaths = "Tasks/Inbox.md\nDaily Brief/Today.md"
        XCTAssertEqual(Brief.path(settings: s), "Daily Brief/Today.md")
        s.taskPaths = "Notes/Morning.md\nTasks/Inbox.md"
        XCTAssertEqual(Brief.path(settings: s), "Notes/Morning.md")
    }

    func testObsidianLinkEscapesSpacesAmpersandsAndHashes() {
        let url = Brief.obsidianURL(vault: "Notes & Ideas #2", path: "Daily Brief/Today.md")
        XCTAssertEqual(url?.absoluteString, "obsidian://open?vault=Notes%20%26%20Ideas%20%232&file=Daily%20Brief%2FToday")
        XCTAssertEqual(Brief.obsidianURL(vault: "Obsidian Vault", path: "Plans+Lists/A.md")?.absoluteString,
                       "obsidian://open?vault=Obsidian%20Vault&file=Plans%2BLists%2FA")
        let back = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(back?.first(where: { $0.name == "vault" })?.value, "Notes & Ideas #2")
        XCTAssertEqual(back?.first(where: { $0.name == "file" })?.value, "Daily Brief/Today")
    }

    // MARK: F36: times with their day

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testWhenSaysTodayYesterdayOrTheDate() {
        let now = at(2026, 11, 11, 9, 30)
        XCTAssertEqual(Brief.when(at(2026, 11, 11, 7, 2), now: now, calendar: utc), "today 7:02")
        XCTAssertEqual(Brief.when(at(2026, 11, 10, 19, 2), now: now, calendar: utc), "yesterday 7:02")
        XCTAssertEqual(Brief.when(at(2026, 11, 9, 7, 2), now: now, calendar: utc), "Nov 9, 7:02")
        XCTAssertEqual(Brief.when(at(2025, 12, 30, 7, 2), now: now, calendar: utc), "Dec 30, 2025, 7:02")
    }

    func testStamp() {
        let now = at(2026, 11, 6, 15, 0)
        let fetched = at(2026, 11, 6, 15, 2)
        // 05:42 Pacific is 13:42 UTC in November.
        XCTAssertEqual(Brief.stamp(generated: "2026-11-06 05:42 PT", fetchedAt: fetched, now: now, calendar: utc),
                       "WRITTEN TODAY 1:42  ·  FETCHED TODAY 3:02")
        XCTAssertEqual(Brief.stamp(generated: nil, fetchedAt: fetched, now: now, calendar: utc), "FETCHED TODAY 3:02")
        XCTAssertEqual(Brief.stamp(generated: "soon", fetchedAt: fetched, now: now, calendar: utc), "WRITTEN SOON  ·  FETCHED TODAY 3:02")
    }
}
