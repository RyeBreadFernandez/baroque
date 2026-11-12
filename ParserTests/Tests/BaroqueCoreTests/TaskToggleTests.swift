import Foundation
import XCTest
@testable import BaroqueCore

final class TaskToggleTests: XCTestCase {
    private let today = day(2026, 11, 11, hour: 9)

    private func tick(_ line: String) -> String? { TaskToggle.toggled(line, done: true, today: today) }
    private func untick(_ line: String) -> String? { TaskToggle.toggled(line, done: false, today: today) }

    // MARK: One line

    func testTick() {
        XCTAssertEqual(tick("- [ ] Water the ferns"), "- [x] Water the ferns ✅ 2026-11-11")
        XCTAssertEqual(tick("- [/] Half done"), "- [x] Half done ✅ 2026-11-11")       // in progress counts as open
    }

    func testUntick() {
        XCTAssertEqual(untick("- [x] Water the ferns ✅ 2026-11-11"), "- [ ] Water the ferns")
        XCTAssertEqual(untick("- [X] Water the ferns ✅ 2026-11-10"), "- [ ] Water the ferns")
        XCTAssertEqual(untick("- [x] Water the ferns"), "- [ ] Water the ferns")
    }

    func testTickAndUntickGiveTheLineBack() {
        for line in ["- [ ] #todo Pay rent ⏫ 📅 2026-11-12", "  * [ ] Call the bike shop ^shop-1", "1. [ ] Numbered  ", "> - [ ] In a callout"] {
            XCTAssertEqual(tick(line).flatMap(untick), line, line)
        }
    }

    func testDoneDateGoesBeforeABlockID() {
        XCTAssertEqual(tick("- [ ] Water the ferns ^abc-1"), "- [x] Water the ferns ✅ 2026-11-11 ^abc-1")
        XCTAssertEqual(untick("- [x] Water the ferns ✅ 2026-11-11 ^abc-1"), "- [ ] Water the ferns ^abc-1")
    }

    func testMetadataAndTrailingSpaceStay() {
        XCTAssertEqual(tick("- [ ] #todo Pay rent ⏫ 📅 2026-11-12"), "- [x] #todo Pay rent ⏫ 📅 2026-11-12 ✅ 2026-11-11")
        XCTAssertEqual(tick("- [ ] Water the ferns  "), "- [x] Water the ferns ✅ 2026-11-11  ")
    }

    func testIndentationStays() {
        XCTAssertEqual(tick("\t  - [ ] Child task"), "\t  - [x] Child task ✅ 2026-11-11")
        XCTAssertEqual(tick("        - [ ] Deep"), "        - [x] Deep ✅ 2026-11-11")
    }

    func testAlreadyInThatStateIsUnchanged() {
        XCTAssertEqual(tick("- [x] Done ✅ 2026-11-01"), "- [x] Done ✅ 2026-11-01")
        XCTAssertEqual(untick("- [ ] Open"), "- [ ] Open")
    }

    func testNotATaskOrOtherStatusIsNil() {
        XCTAssertNil(tick("Just a paragraph"))
        XCTAssertNil(tick("- A bullet"))
        XCTAssertNil(tick("- [-] Cancelled"))
    }

    // MARK: Key

    func testKeyIgnoresDoneDatePriorityDueAndSpacing() {
        let keys = [
            "- [ ] Pay rent",
            "- [x] Pay rent ✅ 2026-11-11",
            "- [ ] Pay   rent ⏫ 📅 2026-11-12",
            "  * [X] #todo Pay rent 🔼 📅 2026-12-01 ✅ 2026-11-30",
        ].map { TaskToggle.key(ofLine: $0) }
        XCTAssertEqual(Set(keys), ["Pay rent"])
        XCTAssertEqual(TaskToggle.key(" Pay \t rent  "), "Pay rent")
        XCTAssertNotEqual(TaskToggle.key(ofLine: "- [ ] Pay rent today"), "Pay rent")
    }

    // MARK: In a file

    private let file = """
    # Today

    ## Needs attention
    - [ ] Water the ferns
    - [ ] Return the library books (Library, email, Nov 4)
    - [ ] Call the bike shop
    """

    func testApplyTicksTheLineAtItsNumber() {
        let out = TaskToggle.apply(to: file, line: "- [ ] Call the bike shop", near: 6, done: true, today: today)
        XCTAssertEqual(out, file.replacingOccurrences(of: "- [ ] Call the bike shop", with: "- [x] Call the bike shop ✅ 2026-11-11"))
    }

    func testApplyFindsALineThatMoved() {
        let moved = "- [ ] A new task at the top\n" + file
        let out = TaskToggle.change(in: moved, line: "- [ ] Water the ferns", near: 4, done: true, today: today)
        XCTAssertEqual(out?.lineNumber, 5)
        XCTAssertEqual(out?.line, "- [x] Water the ferns ✅ 2026-11-11")
    }

    func testMissingLineIsNil() {
        XCTAssertNil(TaskToggle.apply(to: file, line: "- [ ] Feed the cat", near: 4, done: true, today: today))
    }

    func testDuplicateLineIsNilUnlessAtItsNumber() {
        let twice = file + "\n- [ ] Water the ferns"
        XCTAssertNil(TaskToggle.apply(to: twice, line: "- [ ] Water the ferns", near: 2, done: true, today: today))
        let out = TaskToggle.change(in: twice, line: "- [ ] Water the ferns", near: 7, done: true, today: today)
        XCTAssertEqual(out?.lineNumber, 7)
        XCTAssertTrue(out?.markdown.contains("- [ ] Water the ferns\n") ?? false, "the other copy stays open")
    }

    func testCRLFFileKeepsItsLineEndings() {
        let crlf = "# Today\r\n- [ ] One\r\n- [ ] Two\r\n"
        XCTAssertEqual(TaskToggle.apply(to: crlf, line: "- [ ] Two", near: 3, done: true, today: today),
                       "# Today\r\n- [ ] One\r\n- [x] Two ✅ 2026-11-11\r\n")
        // A line handed over with its carriage return still matches.
        XCTAssertNotNil(TaskToggle.apply(to: crlf, line: "- [ ] One\r", near: 2, done: true, today: today))
    }

    func testByteOrderMarkAndFrontMatterStay() {
        let md = "\u{FEFF}---\ndate: 2026-11-11\n---\n- [ ] One\n"
        XCTAssertEqual(TaskToggle.apply(to: md, line: "- [ ] One", near: 4, done: true, today: today),
                       "\u{FEFF}---\ndate: 2026-11-11\n---\n- [x] One ✅ 2026-11-11\n")
    }

    func testLinesInCodeBlocksAreNotTasks() {
        let md = "```tasks\n- [ ] One\n```\n- [ ] One"
        let out = TaskToggle.change(in: md, line: "- [ ] One", near: 2, done: true, today: today)
        XCTAssertEqual(out?.lineNumber, 4)
        XCTAssertTrue(out?.markdown.hasPrefix("```tasks\n- [ ] One\n```") ?? false)
    }

    func testByKeyFindsTheTaskWhateverItsMetadata() {
        let md = "- [ ] Water the ferns 📅 2026-11-12\n- [ ] Call the bike shop"
        let out = TaskToggle.change(in: md, key: "Water the ferns", near: 9, done: true, today: today)
        XCTAssertEqual(out?.lineNumber, 1)
        XCTAssertEqual(out?.line, "- [x] Water the ferns 📅 2026-11-12 ✅ 2026-11-11")
    }

    func testByKeyAlreadyDoneIsUnchangedNotNil() {
        let md = "- [x] Water the ferns ✅ 2026-11-10\n- [ ] Call the bike shop"
        XCTAssertEqual(TaskToggle.apply(to: md, key: "Water the ferns", near: 1, done: true, today: today), md)
        XCTAssertNil(TaskToggle.apply(to: md, key: "Feed the cat", near: 1, done: true, today: today))
    }

    func testByKeyPrefersTheCopyThatStillNeedsIt() {
        // Ticked yesterday at line 1, listed again by the morning brief at line 3.
        let md = "- [x] Water the ferns ✅ 2026-11-10\n\n- [ ] Water the ferns"
        let out = TaskToggle.change(in: md, key: "Water the ferns", near: 1, done: true, today: today)
        XCTAssertEqual(out?.lineNumber, 3)
    }
}
