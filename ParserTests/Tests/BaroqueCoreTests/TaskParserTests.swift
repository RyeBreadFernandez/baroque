import Foundation
import XCTest
@testable import BaroqueCore

final class TaskParserTests: XCTestCase {

    // MARK: Shape of a real vault line

    func testCanonicalVaultLine() throws {
        let t = try XCTUnwrap(one("- [ ] #todo Text ⏫ 📅 2026-06-05"))
        XCTAssertEqual(t.text, "Text")
        XCTAssertEqual(t.priority, .high)
        XCTAssertEqual(t.due, day(2026, 6, 5))
        XCTAssertEqual(t.sourcePath, "Tasks/Master Task List.md")
        XCTAssertEqual(t.lineNumber, 1)
        XCTAssertEqual(t.id, "Tasks/Master Task List.md#1")
    }

    func testEveryPriorityEmoji() {
        let cases: [(String, TaskPriority)] = [("🔺", .highest), ("⏫", .high), ("🔼", .medium), ("🔽", .low), ("⏬", .lowest)]
        for (emoji, expected) in cases {
            let before = one("- [ ] #todo Pay rent \(emoji) 📅 2026-06-05")
            XCTAssertEqual(before?.priority, expected, "priority before date: \(emoji)")
            XCTAssertEqual(before?.text, "Pay rent")
            XCTAssertEqual(before?.due, day(2026, 6, 5))

            let after = one("- [ ] #todo Pay rent 📅 2026-06-05 \(emoji)")
            XCTAssertEqual(after?.priority, expected, "priority after date: \(emoji)")
            XCTAssertEqual(after?.text, "Pay rent")
            XCTAssertEqual(after?.due, day(2026, 6, 5))

            let noDate = one("- [ ] \(emoji) Pay rent")
            XCTAssertEqual(noDate?.priority, expected, "leading priority: \(emoji)")
            XCTAssertEqual(noDate?.text, "Pay rent")
            XCTAssertNil(noDate?.due)
        }
        XCTAssertEqual(one("- [ ] #todo Plain 📅 2026-06-05")?.priority, TaskPriority.none)
    }

    func testMetadataInAnyOrder() {
        let lines = [
            "- [ ] #todo Pay rent ⏫ 📅 2026-06-01 🔁 every month",
            "- [ ] #todo Pay rent 📅 2026-06-01 ⏫ 🔁 every month",
            "- [ ] #todo Pay rent 🔁 every month 📅 2026-06-01 ⏫",
            "- [ ] #todo Pay rent 🔁 every month ⏫ 📅 2026-06-01",
            "- [ ] #todo Pay rent ➕ 2026-05-01 ⏳ 2026-05-30 📅 2026-06-01 🛫 2026-05-28 ⏫",
            "- [ ] Pay rent 📅 2026-06-01 ➕ 2026-05-01 #todo ⏫",
            "- [ ] Pay rent 🆔 rent1 ⛔ abc,def 📅 2026-06-01 🏁 delete ⏫",
        ]
        for line in lines {
            let t = one(line)
            XCTAssertEqual(t?.text, "Pay rent", line)
            XCTAssertEqual(t?.priority, .high, line)
            XCTAssertEqual(t?.due, day(2026, 6, 1), line)
        }
    }

    func testAllMetadataEmojiAreStripped() {
        let line = "- [ ] #todo Write report 🆔 abc123 ⛔ def456,ghi789 🏁 delete 🔁 every week on Monday ⏳ 2026-06-03 🛫 2026-06-01 ➕ 2026-05-20 ✅ 2026-06-04 ❌ 2026-06-04 📅 2026-06-05"
        let t = one(line)
        XCTAssertEqual(t?.text, "Write report")
        XCTAssertEqual(t?.due, day(2026, 6, 5))
        XCTAssertEqual(t?.priority, TaskPriority.none)

        // Each marker on its own, so a leftover payload is easy to spot.
        let singles = ["⏳ 2026-06-03", "⌛ 2026-06-03", "🛫 2026-06-01", "➕ 2026-05-20", "✅ 2026-06-04", "❌ 2026-06-04",
                       "🔁 every 2 weeks", "🔁 every weekday when done", "🆔 x7k2", "⛔ a1b2c3", "⛔ a1, b2", "🏁 keep"]
        for meta in singles {
            XCTAssertEqual(one("- [ ] Water plants \(meta)")?.text, "Water plants", meta)
            XCTAssertEqual(one("- [ ] Water plants \(meta) 📅 2026-06-05")?.due, day(2026, 6, 5), meta)
        }
    }

    func testRepeatingTasksAreMarked() {
        XCTAssertEqual(one("- [ ] Water plants 🔁 every week on Monday 📅 2026-06-05")?.repeats, true)
        XCTAssertEqual(one("- [ ] Water plants 🔁\u{FE0F} every day")?.repeats, true)
        XCTAssertEqual(one("- [ ] Water plants 📅 2026-06-05")?.repeats, false)
    }

    func testAlternateDueDateEmoji() {
        XCTAssertEqual(one("- [ ] Dentist 📆 2026-06-05")?.due, day(2026, 6, 5))
        XCTAssertEqual(one("- [ ] Dentist 🗓️ 2026-06-05")?.due, day(2026, 6, 5))
        XCTAssertEqual(one("- [ ] Dentist 🗓️ 2026-06-05")?.text, "Dentist")
    }

    func testVariationSelectorsOnEmoji() {
        let a = one("- [ ] #todo Stretch 🔼\u{FE0F} 📅 2026-06-05")
        XCTAssertEqual(a?.priority, .medium)
        XCTAssertEqual(a?.text, "Stretch")
        XCTAssertEqual(a?.due, day(2026, 6, 5))

        let b = one("- [ ] #todo Stretch 📅\u{FE0F} 2026-06-05 ⏫\u{FE0F}")
        XCTAssertEqual(b?.priority, .high)
        XCTAssertEqual(b?.due, day(2026, 6, 5))
        XCTAssertEqual(b?.text, "Stretch")

        let c = one("- [ ] Stretch ⛔\u{FE0F} abc ⏳\u{FE0F} 2026-06-01 🔺\u{FE0F}")
        XCTAssertEqual(c?.priority, .highest)
        XCTAssertEqual(c?.text, "Stretch")
        XCTAssertFalse(c?.text.contains("\u{FE0F}") ?? true)
    }

    func testInvalidDueDateIsIgnoredButStripped() {
        let t = one("- [ ] Taxes 📅 2026-02-30 ⏫")
        XCTAssertNil(t?.due)
        XCTAssertEqual(t?.priority, .high)
        XCTAssertEqual(t?.text, "Taxes")
    }

    func testFirstDueDateWins() {
        XCTAssertEqual(one("- [ ] Taxes 📅 2026-04-15 📅 2026-10-15")?.due, day(2026, 4, 15))
    }

    // MARK: Which lines count as open tasks

    func testDoneAndCancelledTasksAreIgnored() {
        let md = """
        - [x] #todo Done lower ⏫ 📅 2026-06-01 ✅ 2026-06-01
        - [X] #todo Done upper 📅 2026-06-01
        - [-] #todo Cancelled ❌ 2026-06-01
        - [ ] #todo Still open
        """
        let items = tasks(md)
        XCTAssertEqual(items.map(\.text), ["Still open"])
        XCTAssertEqual(items.first?.lineNumber, 4)
    }

    func testInProgressTaskIsOpen() {
        XCTAssertEqual(one("- [/] #todo Half done")?.text, "Half done")
    }

    func testIndentedSubtasks() {
        let md = "- [ ] Parent\n\t- [ ] Tab child 🔼\n    - [ ] Space child\n        - [x] Done grandchild\n  * [ ] Two space star"
        let items = tasks(md)
        XCTAssertEqual(items.map(\.text), ["Parent", "Tab child", "Space child", "Two space star"])
        XCTAssertEqual(items.map(\.lineNumber), [1, 2, 3, 5])
        XCTAssertEqual(items[1].priority, .medium)
    }

    func testBulletStyles() {
        let md = """
        - [ ] Dash
        * [ ] Star
        + [ ] Plus
        1. [ ] Numbered dot
        12) [ ] Numbered paren
        -   [ ] Extra spaces
        > - [ ] Inside a callout
        """
        XCTAssertEqual(tasks(md).map(\.text), ["Dash", "Star", "Plus", "Numbered dot", "Numbered paren", "Extra spaces", "Inside a callout"])
    }

    func testLinesThatAreNotTasks() {
        let md = """
        # Heading - [ ] not a task
        Plain prose with - [ ] in the middle
        - [] Missing space
        -[ ] Missing space after dash
        [ ] No bullet
        - Regular bullet
        - [link](https://example.com)
        - [ ]
        - [ ]   
        """
        XCTAssertEqual(tasks(md).map(\.text), [])
    }

    func testTaskWithOnlyMetadataIsSkipped() {
        XCTAssertTrue(tasks("- [ ] #todo 📅 2026-06-05 ⏫").isEmpty)
        XCTAssertTrue(tasks("- [ ] ⏫ 🔁 every day").isEmpty)
        XCTAssertTrue(tasks("- [ ] #todo").isEmpty)
        XCTAssertTrue(tasks("- [ ] ![[photo.png]]").isEmpty)
    }

    func testFencedCodeBlocksAreIgnored() {
        let md = """
        - [ ] Real one
        ```tasks
        not done
        due before tomorrow
        - [ ] Fake inside query block
        ```
        - [ ] Real two
        ~~~
        - [ ] Fake inside tilde fence
        ~~~
        ````markdown
        ```
        - [ ] Fake, a shorter fence does not close a longer one
        ```
        ````
          ```js
          - [ ] Fake inside an indented fence
          ```
        - [ ] Real three
        """
        let items = tasks(md)
        XCTAssertEqual(items.map(\.text), ["Real one", "Real two", "Real three"])
        XCTAssertEqual(items.map(\.lineNumber), [1, 7, 19])
    }

    func testUnclosedFenceRunsToEndOfFile() {
        XCTAssertEqual(tasks("- [ ] Before\n```\n- [ ] After").map(\.text), ["Before"])
    }

    func testObsidianCommentBlocksAreIgnored() {
        let md = "- [ ] Visible\n%%\n- [ ] Hidden in a comment\n%%\n- [ ] Also visible %%inline note%%"
        XCTAssertEqual(tasks(md).map(\.text), ["Visible", "Also visible"])
    }

    func testCRLFLineEndingsKeepLineNumbers() {
        let items = tasks("# Tasks\r\n- [ ] One\r\n\r\n- [ ] Two 📅 2026-06-05\r\n")
        XCTAssertEqual(items.map(\.text), ["One", "Two"])
        XCTAssertEqual(items.map(\.lineNumber), [2, 4])
        XCTAssertEqual(items.last?.due, day(2026, 6, 5))
    }

    func testByteOrderMarkDoesNotHideFirstLine() {
        XCTAssertEqual(tasks("\u{FEFF}- [ ] First\n- [ ] Second").map(\.text), ["First", "Second"])
        XCTAssertEqual(QuoteParser.parse(markdown: "\u{FEFF}> Quote.\n> — A"), [Quote(text: "Quote.", author: "A")])
    }

    func testDailyNoteShape() {
        let md = """
        # Tuesday, December 30

        ## Todo
        - [ ] #todo Finish [[Chapter 3]] exercises ⏫ 📅 2025-12-30
        - [x] #todo Gym ✅ 2025-12-30
        - [ ] #todo Email [[Mrs. Hudson|Mrs. H]] about **the lease**

        ## Notes
        Begin at once to live.
        """
        let items = tasks(md, path: "daily note/12.30.2025 - Tuesday.md")
        XCTAssertEqual(items.map(\.text), ["Finish Chapter 3 exercises", "Email Mrs. H about the lease"])
        XCTAssertEqual(items.map(\.lineNumber), [4, 6])
        XCTAssertEqual(items.first?.sourcePath, "daily note/12.30.2025 - Tuesday.md")
    }

    func testTagsAreStripped() {
        XCTAssertEqual(one("- [ ] #todo Call mom #family #errands/phone #high-priority #snake_case")?.text, "Call mom")
        XCTAssertEqual(one("- [ ] #todo Fix issue #3 in C# repo")?.text, "Fix issue #3 in C# repo")
    }

    func testOrdinaryEmojiInTextAreKept() {
        XCTAssertEqual(one("- [ ] 🎉 Plan party 🔥 📅 2026-06-05 ⏫")?.text, "🎉 Plan party 🔥")
    }

    func testOtherCustomStatusesAreSkipped() {
        XCTAssertTrue(tasks("- [>] Forwarded\n- [!] Important\n- [?] Question").isEmpty)
    }

    func testDueDateOnDayWhoseMidnightIsSkippedByDST() throws {
        // Chile springs forward at 00:00 on 2026-09-06, so that day has no midnight.
        // DateFormatter returns nil for "2026-09-06" there; the parser must not drop the date.
        let saved = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/Santiago")!
        defer { NSTimeZone.default = saved }
        let t = try XCTUnwrap(one("- [ ] Pay bills 📅 2026-09-06"))
        let due = try XCTUnwrap(t.due)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Santiago")!
        let comps = cal.dateComponents([.year, .month, .day], from: due)
        XCTAssertEqual([comps.year, comps.month, comps.day], [2026, 9, 6])
        let noon = cal.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12))!
        XCTAssertTrue(t.isDueToday(asOf: noon, calendar: cal))
        XCTAssertFalse(t.isOverdue(asOf: noon, calendar: cal))
    }

    func testBlockReferenceIsStripped() {
        let t = one("- [ ] Review notes ⏫ 📅 2026-06-05 ^task-42")
        XCTAssertEqual(t?.text, "Review notes")
        XCTAssertEqual(t?.priority, .high)
        XCTAssertEqual(t?.due, day(2026, 6, 5))
    }
}
