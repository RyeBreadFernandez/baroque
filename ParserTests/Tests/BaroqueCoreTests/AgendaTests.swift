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

/// A task's due note on the Today widget (RococoWords.due, Shared/Words.swift): never a weekday name.
final class DueNoteTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func at(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
    }

    private func note(due: Date?, now: Date) -> String? {
        RococoWords.due(TaskItem(text: "x", due: due, priority: .none, sourcePath: "p", lineNumber: 1), now: now, calendar: cal)
    }

    func testEachCase() {
        let now = at(2026, 11, 11, hour: 9, minute: 41)
        XCTAssertNil(note(due: nil, now: now))
        XCTAssertEqual(note(due: at(2026, 11, 9), now: now), "2d late")
        XCTAssertEqual(note(due: at(2026, 10, 30), now: now), "12d late")
        XCTAssertEqual(note(due: at(2026, 11, 11), now: now), "today")
        XCTAssertEqual(note(due: at(2026, 11, 12), now: now), "tomorrow")
        XCTAssertEqual(note(due: at(2026, 11, 13), now: now), "the 13th")
        XCTAssertEqual(note(due: at(2026, 11, 17), now: now), "the 17th")    // six days on
        XCTAssertEqual(note(due: at(2026, 11, 18), now: now), "Nov 18")      // seven: a month and a day
        XCTAssertEqual(note(due: at(2026, 12, 5), now: now), "Dec 5")        // next month
        XCTAssertEqual(note(due: at(2027, 3, 1), now: now), "Mar 1")
    }

    func testNextMonthWithinTheWeekShowsTheMonth() {
        XCTAssertEqual(note(due: at(2026, 12, 2), now: at(2026, 11, 28, hour: 20)), "Dec 2")
        XCTAssertEqual(note(due: at(2027, 1, 2), now: at(2026, 12, 30, hour: 8)), "Jan 2")
        // Tomorrow is tomorrow, even in another month.
        XCTAssertEqual(note(due: at(2026, 12, 1), now: at(2026, 11, 30, hour: 23, minute: 59)), "tomorrow")
    }

    func testAcrossAClockChange() {
        // Clocks go back on 2026-11-01 in Los Angeles (a 25-hour day): still whole days.
        XCTAssertEqual(note(due: at(2026, 11, 3), now: at(2026, 11, 1, hour: 0, minute: 30)), "the 3rd")
        XCTAssertEqual(note(due: at(2026, 11, 2), now: at(2026, 11, 1, hour: 23, minute: 30)), "tomorrow")
        XCTAssertEqual(note(due: at(2026, 10, 30), now: at(2026, 11, 1, hour: 1, minute: 30)), "2d late")
        XCTAssertEqual(note(due: at(2026, 11, 2), now: at(2026, 10, 31, hour: 23)), "Nov 2")   // another month
        // Clocks go forward on 2027-03-14 (a 23-hour day).
        XCTAssertEqual(note(due: at(2027, 3, 16), now: at(2027, 3, 14, hour: 23, minute: 30)), "the 16th")
    }

    func testNeverAWeekday() {
        let weekdays: Set<String> = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
                                     "mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        let now = at(2026, 11, 11, hour: 12)
        for offset in -10...60 {
            let due = cal.date(byAdding: .day, value: offset, to: at(2026, 11, 11))!
            let words = (note(due: due, now: now) ?? "").lowercased().split(separator: " ").map(String.init)
            XCTAssertTrue(weekdays.isDisjoint(with: words), "offset \(offset): \(words)")
        }
    }

    func testOrdinals() {
        let cases = [1: "1st", 2: "2nd", 3: "3rd", 4: "4th", 11: "11th", 12: "12th", 13: "13th", 21: "21st", 22: "22nd", 23: "23rd", 31: "31st"]
        for (n, word) in cases { XCTAssertEqual(RococoWords.ordinal(n), word) }
    }
}

/// The photographs' three-hour turns (RococoPhotos, Shared/Words.swift) follow the local clock, on the days the clocks
/// change too.
final class PhotoTurnTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func at(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
    }

    /// Steps from just before midnight through the day with nextChange: every change is at 0:00, 3:00, 6:00 … local,
    /// at minute 0, and each one moves the turn on by exactly one.
    private func checkDay(_ y: Int, _ m: Int, _ d: Int, file: StaticString = #filePath, line: UInt = #line) {
        var t = cal.date(byAdding: .minute, value: -30, to: at(y, m, d))!
        var turn = RococoPhotos.turn(t, calendar: cal)
        var hours: [Int] = []
        for _ in 0..<9 {
            let next = RococoPhotos.nextChange(after: t, calendar: cal)
            let c = cal.dateComponents([.hour, .minute, .second], from: next)
            hours.append(c.hour!)
            XCTAssertEqual(c.minute, 0, file: file, line: line)
            XCTAssertEqual(c.second, 0, file: file, line: line)
            XCTAssertEqual(RococoPhotos.turn(next, calendar: cal), turn + 1, "at \(next)", file: file, line: line)
            // Still the old turn a second before.
            XCTAssertEqual(RococoPhotos.turn(next.addingTimeInterval(-1), calendar: cal), turn, "before \(next)", file: file, line: line)
            turn += 1
            t = next
        }
        XCTAssertEqual(hours, [0, 3, 6, 9, 12, 15, 18, 21, 0], file: file, line: line)
    }

    func testClocksGoBack() {
        checkDay(2026, 11, 1)
        // 1:30 comes twice; from either, the next change is at 3:00 standard time (the old code said 2:00).
        let firstOneThirty = at(2026, 11, 1, hour: 1, minute: 30)          // daylight time
        let secondOneThirty = firstOneThirty.addingTimeInterval(3600)        // standard time, the same on the clock
        let three = at(2026, 11, 1, hour: 3)
        XCTAssertEqual(RococoPhotos.nextChange(after: firstOneThirty, calendar: cal), three)
        XCTAssertEqual(RococoPhotos.nextChange(after: secondOneThirty, calendar: cal), three)
        XCTAssertEqual(RococoPhotos.turn(firstOneThirty, calendar: cal), RococoPhotos.turn(secondOneThirty, calendar: cal))
        XCTAssertEqual(three.timeIntervalSince(at(2026, 11, 1)), 4 * 3600)   // that turn lasts four hours
    }

    func testClocksGoForward() {
        checkDay(2027, 3, 14)
        // 2:00 to 3:00 doesn't happen; from 1:30 the next change is 3:00 daylight time (the old code said 4:00).
        let three = at(2027, 3, 14, hour: 3)
        XCTAssertEqual(RococoPhotos.nextChange(after: at(2027, 3, 14, hour: 1, minute: 30), calendar: cal), three)
        XCTAssertEqual(three.timeIntervalSince(at(2027, 3, 14)), 2 * 3600)   // that turn lasts two hours
    }

    func testOrdinaryDaysKeepTheirTurns() {
        // Away from a clock change the turn is the old count (local seconds since 1970 over three hours), so the
        // photographs keep their order.
        for date in [at(2026, 6, 5, hour: 9, minute: 41), at(2026, 11, 11, hour: 23, minute: 59), at(2027, 1, 1)] {
            let local = date.timeIntervalSince1970 + Double(cal.timeZone.secondsFromGMT(for: date))
            XCTAssertEqual(RococoPhotos.turn(date, calendar: cal), Int(floor(local / Double(RococoPhotos.hours * 3600))))
        }
        checkDay(2026, 6, 5)
    }

    func testPhotographNeverShowsTheLargeDaysPicture() {
        var t = at(2026, 10, 30)
        for _ in 0..<40 {
            XCTAssertNotEqual(RococoPhotos.small(at: t, calendar: cal), "RococoPhoto-" + RococoPhotos.largeName(at: t, calendar: cal) + "-small")
            XCTAssertTrue(RococoPhotos.underWords.contains(RococoPhotos.largeName(at: t, calendar: cal)))
            t = RococoPhotos.nextChange(after: t, calendar: cal)
        }
    }
}
