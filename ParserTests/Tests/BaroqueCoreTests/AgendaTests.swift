import Foundation
import XCTest
@testable import BaroqueCore

final class AgendaTests: XCTestCase {
    /// Friday 2026-06-05, mid-afternoon local time.
    let now = day(2026, 6, 5, hour: 15, minute: 30)

    private func t(_ text: String, _ due: Date?, _ p: TaskPriority = .none, path: String = "Tasks/Master Task List.md", line: Int = 1) -> TaskItem {
        TaskItem(text: text, due: due, priority: p, sourcePath: path, lineNumber: line)
    }

    private func agenda(_ all: [TaskItem], includeUndated: Bool = true, limit: Int = 100) -> [String] {
        TaskParser.todaysAgenda(all, includeUndated: includeUndated, limit: limit, now: now).map(\.text)
    }

    private lazy var mixed: [TaskItem] = [
        t("far none", day(2027, 1, 1), line: 1),
        t("undated low", nil, .low, line: 2),
        t("soon tomorrow", day(2026, 6, 6), line: 3),
        t("overdue low", day(2026, 6, 1), .low, line: 4),
        t("undated high", nil, .high, line: 5),
        t("today none", day(2026, 6, 5), line: 6),
        t("far highest", day(2026, 6, 30), .highest, line: 7),
        t("overdue high recent", day(2026, 6, 3), .high, line: 8),
        t("undated none", nil, line: 9),
        t("soon +3 highest", day(2026, 6, 8), .highest, line: 10),
        t("today highest", day(2026, 6, 5), .highest, line: 11),
        t("undated medium", nil, .medium, line: 12),
        t("overdue high older", day(2026, 6, 2), .high, line: 13),
        t("undated highest", nil, .highest, line: 14),
        t("far +4", day(2026, 6, 9), line: 15),
    ]

    func testBucketOrder() {
        XCTAssertEqual(agenda(mixed), [
            // 1. overdue
            "overdue high older", "overdue high recent", "overdue low",
            // 2. due today
            "today highest", "today none",
            // 3. undated 🔺 / ⏫
            "undated highest", "undated high",
            // 4. due in the next 3 days
            "soon +3 highest", "soon tomorrow",
            // 5. other undated
            "undated medium", "undated none", "undated low",
            // 6. far future
            "far highest", "far +4", "far none",
        ])
    }

    func testFarFutureIsKeptWhenOtherTasksExist() {
        XCTAssertEqual(agenda([t("far", day(2026, 9, 1)), t("today", day(2026, 6, 5))]), ["today", "far"])
        XCTAssertEqual(agenda([t("far", day(2026, 9, 1))]), ["far"])
    }

    func testOrderingInsideBucketPriorityThenDateThenSource() {
        let overdue = [
            t("b", day(2026, 6, 2), .medium, line: 1),
            t("a", day(2026, 6, 1), .medium, line: 2),
            t("c", day(2026, 6, 1), .medium, line: 3),
            t("top", day(2026, 6, 4), .highest, line: 4),
        ]
        XCTAssertEqual(agenda(overdue), ["top", "a", "c", "b"])

        let today = [
            t("x", day(2026, 6, 5), line: 3),
            t("y", day(2026, 6, 5, hour: 0), .low, line: 1),
            t("z", day(2026, 6, 5), .medium, line: 2),
        ]
        XCTAssertEqual(agenda(today), ["z", "x", "y"])

        let farFuture = [
            t("later", day(2026, 8, 1), .high, line: 1),
            t("sooner", day(2026, 7, 1), .high, line: 2),
            t("urgent", day(2026, 12, 1), .highest, line: 3),
        ]
        XCTAssertEqual(agenda(farFuture), ["urgent", "sooner", "later"])
    }

    func testSourceOrderIsInputOrderAcrossFiles() {
        // Line numbers from different files are not comparable; input order (master list, then daily note) is.
        let all = [
            t("master line 40", nil, .high, path: "Tasks/Master Task List.md", line: 40),
            t("master line 41", nil, .high, path: "Tasks/Master Task List.md", line: 41),
            t("daily line 3", nil, .high, path: "daily note/06.05.2026 - Friday.md", line: 3),
        ]
        XCTAssertEqual(agenda(all), ["master line 40", "master line 41", "daily line 3"])
        XCTAssertEqual(agenda(all.reversed()), ["daily line 3", "master line 41", "master line 40"])
    }

    func testSourceOrderIsStableForManyEqualTasks() {
        let all = (1...50).map { t("task \($0)", nil, line: $0) }
        XCTAssertEqual(agenda(all), all.map(\.text))
    }

    func testIncludeUndatedFalse() {
        XCTAssertEqual(agenda(mixed, includeUndated: false), [
            "overdue high older", "overdue high recent", "overdue low",
            "today highest", "today none",
            "soon +3 highest", "soon tomorrow",
            "far highest", "far +4", "far none",
        ])
        XCTAssertEqual(agenda([t("undated", nil, .highest)], includeUndated: false), [])
    }

    func testLimit() {
        XCTAssertEqual(agenda(mixed, limit: 4), ["overdue high older", "overdue high recent", "overdue low", "today highest"])
        XCTAssertEqual(agenda(mixed, limit: 1), ["overdue high older"])
        XCTAssertEqual(agenda(mixed, limit: 100).count, mixed.count)
        // Existing behaviour: a non-positive limit still shows one task.
        XCTAssertEqual(agenda(mixed, limit: 0), ["overdue high older"])
        XCTAssertEqual(agenda([], limit: 5), [])
    }

    func testParsedDatesLandInTheRightBuckets() {
        let md = """
        - [ ] #todo Later 📅 2026-07-01
        - [ ] #todo Overdue 📅 2026-06-04 🔽
        - [ ] #todo Someday
        - [ ] #todo Today 📅 2026-06-05
        - [ ] #todo Important ⏫
        - [ ] #todo Monday 📅 2026-06-08 ⏫
        """
        let all = TaskParser.parse(markdown: md, sourcePath: "Tasks/Master Task List.md")
        XCTAssertEqual(agenda(all), ["Overdue", "Today", "Important", "Monday", "Someday", "Later"])
    }

    func testMidnightBoundaries() {
        let justAfterMidnight = day(2026, 6, 5, hour: 0, minute: 1)
        let justBeforeMidnight = day(2026, 6, 5, hour: 23, minute: 59)
        let all = [t("yesterday", day(2026, 6, 4)), t("today", day(2026, 6, 5)), t("tomorrow", day(2026, 6, 6))]
        for n in [justAfterMidnight, justBeforeMidnight] {
            XCTAssertEqual(TaskParser.todaysAgenda(all, includeUndated: true, limit: 10, now: n).map(\.text), ["yesterday", "today", "tomorrow"])
        }
    }

    func testExistingSignatureStillCompiles() {
        let result: [TaskItem] = TaskParser.todaysAgenda([t("x", nil)], includeUndated: true, limit: 12)
        XCTAssertEqual(result.map(\.text), ["x"])
    }
}

final class TaskItemDateTests: XCTestCase {
    func testAsOfHelpers() {
        let now = day(2026, 6, 5, hour: 9)
        let overdue = TaskItem(text: "a", due: day(2026, 6, 4), priority: .none, sourcePath: "p", lineNumber: 1)
        let today = TaskItem(text: "b", due: day(2026, 6, 5), priority: .none, sourcePath: "p", lineNumber: 2)
        let future = TaskItem(text: "c", due: day(2026, 6, 6), priority: .none, sourcePath: "p", lineNumber: 3)
        let undated = TaskItem(text: "d", due: nil, priority: .none, sourcePath: "p", lineNumber: 4)

        XCTAssertTrue(overdue.isOverdue(asOf: now))
        XCTAssertFalse(overdue.isDueToday(asOf: now))
        XCTAssertFalse(today.isOverdue(asOf: now))
        XCTAssertTrue(today.isDueToday(asOf: now))
        XCTAssertFalse(future.isOverdue(asOf: now))
        XCTAssertFalse(future.isDueToday(asOf: now))
        XCTAssertFalse(undated.isOverdue(asOf: now))
        XCTAssertFalse(undated.isDueToday(asOf: now))
    }

    func testPropertiesMatchHelpersForRealNow() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        for offset in [-2, -1, 0, 1, 2] {
            let due = cal.date(byAdding: .day, value: offset, to: start)!
            let item = TaskItem(text: "x", due: due, priority: .none, sourcePath: "p", lineNumber: 1)
            XCTAssertEqual(item.isOverdue, item.isOverdue(asOf: Date()), "offset \(offset)")
            XCTAssertEqual(item.isDueToday, item.isDueToday(asOf: Date()), "offset \(offset)")
            XCTAssertEqual(item.isOverdue, offset < 0)
            XCTAssertEqual(item.isDueToday, offset == 0)
        }
    }
}
