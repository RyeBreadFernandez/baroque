import Foundation
import XCTest
@testable import BaroqueCore

final class DailyNotePathTests: XCTestCase {
    func testDefaultSettingsMatchVaultFilename() {
        let settings = BaroqueSettings.default
        XCTAssertEqual(settings.dailyNoteFolder, "daily note")
        XCTAssertEqual(settings.dailyNoteFormat, "MM.dd.yyyy - EEEE")
        for hour in [0, 9, 23] {
            XCTAssertEqual(DataLoader.dailyNotePath(settings: settings, date: day(2025, 12, 30, hour: hour)),
                           "daily note/12.30.2025 - Tuesday.md", "hour \(hour)")
        }
    }

    func testOtherDates() {
        let s = BaroqueSettings.default
        XCTAssertEqual(DataLoader.dailyNotePath(settings: s, date: day(2026, 1, 1)), "daily note/01.01.2026 - Thursday.md")
        XCTAssertEqual(DataLoader.dailyNotePath(settings: s, date: day(2026, 6, 5)), "daily note/06.05.2026 - Friday.md")
        // Year-boundary week: yyyy (calendar year) not YYYY (week-based year).
        XCTAssertEqual(DataLoader.dailyNotePath(settings: s, date: day(2024, 12, 30)), "daily note/12.30.2024 - Monday.md")
    }

    func testFolderVariants() {
        var s = BaroqueSettings.default
        s.dailyNoteFolder = "/daily note/"
        XCTAssertEqual(DataLoader.dailyNotePath(settings: s, date: day(2025, 12, 30)), "daily note/12.30.2025 - Tuesday.md")
        s.dailyNoteFolder = ""
        XCTAssertEqual(DataLoader.dailyNotePath(settings: s, date: day(2025, 12, 30)), "12.30.2025 - Tuesday.md")
        s.dailyNoteFolder = "Journal/Daily"
        s.dailyNoteFormat = "yyyy-MM-dd"
        XCTAssertEqual(DataLoader.dailyNotePath(settings: s, date: day(2025, 12, 30)), "Journal/Daily/2025-12-30.md")
    }

    func testDefaultTaskPathIsTheDailyBrief() {
        XCTAssertEqual(DataLoader.resolvedTaskPaths(settings: .default), ["Daily Brief/Today.md"])
    }

    func testResolvedTaskPathsExpandsDaily() {
        var s = BaroqueSettings.default
        s.taskPaths = BaroqueSettings.masterListTaskPaths
        XCTAssertEqual(DataLoader.resolvedTaskPaths(settings: s), ["Tasks/Master Task List.md", DataLoader.dailyNotePath(settings: s)])
    }

    /// The Daily Brief's shape (2026-11-06): the open tasks under "Needs attention" are read; the schedule, Canvas
    /// and Resolved bullets are not tasks.
    func testDailyBriefTasks() {
        let brief = """
        ---
        date: 2026-11-06
        tags: [daily-brief]
        ---

        # Friday, November 6

        A short summary of the day.

        ## Needs attention
        - [ ] #todo Join the "Garden Club" call at 8:00 AM. (Robin, email, Nov 4)
        - [ ] #todo Reply to Sam about the seed order, part B. (Sam, email reply Nov 5)
        - [x] #todo Something already done. (email)

        ## Today
        - 8:00 AM to 8:50 AM  Garden Club call
        - 12:00 PM to 1:30 PM  Pottery class, Studio 2

        ## Resolved
        - The library book was returned.
        """
        let tasks = TaskParser.parse(markdown: brief, sourcePath: "Daily Brief/Today.md")
        XCTAssertEqual(tasks.map(\.text), [
            "Join the \"Garden Club\" call at 8:00 AM. (Robin, email, Nov 4)",
            "Reply to Sam about the seed order, part B. (Sam, email reply Nov 5)",
        ])
        XCTAssertTrue(tasks.allSatisfy { $0.due == nil })
        let path = BaroqueSettings.dailyBriefPath
        XCTAssertEqual(TaskParser.sourceNote(tasks[1].text, sourcePath: tasks[1].sourcePath).text, "Reply to Sam about the seed order, part B.")
        XCTAssertEqual(TaskParser.sourceNote(tasks[1].text, sourcePath: tasks[1].sourcePath).source, "Sam, email reply Nov 5")
        XCTAssertNil(TaskParser.sourceNote("Pump tires, get gas", sourcePath: path).source)
        XCTAssertNil(TaskParser.sourceNote("Call (maybe) the dentist", sourcePath: path).source)   // a parenthesis inside, not a note
        // Undated, so they show while undated tasks are included (the default), in the brief's order.
        XCTAssertEqual(TaskParser.todaysAgenda(tasks, includeUndated: true, limit: 5).count, 2)
    }

    /// Only the Daily Brief's tasks end with a source note; brackets at the end of a task from any other file are
    /// part of the task.
    func testSourceNoteOnlyOnTheBrief() {
        let brief = BaroqueSettings.dailyBriefPath
        XCTAssertEqual(brief, "Daily Brief/Today.md")
        let split = TaskParser.sourceNote("Reply about the plan. (Sam, email, Nov 5)", sourcePath: brief)
        XCTAssertEqual(split.text, "Reply about the plan.")
        XCTAssertEqual(split.source, "Sam, email, Nov 5")

        for path in ["Tasks/Master Task List.md", "daily note/11.11.2026 - Wednesday.md", "Daily Brief/Archive.md"] {
            let whole = TaskParser.sourceNote("Finish essay (draft 2)", sourcePath: path)
            XCTAssertEqual(whole.text, "Finish essay (draft 2)", path)
            XCTAssertNil(whole.source, path)
        }
        // Parsed from another file, the task keeps its brackets.
        let task = tasks("- [ ] Finish essay (draft 2) 📅 2026-11-12", path: "Tasks/Master Task List.md")[0]
        XCTAssertEqual(TaskParser.sourceNote(task.text, sourcePath: task.sourcePath).text, "Finish essay (draft 2)")
        XCTAssertNil(TaskParser.sourceNote(task.text, sourcePath: task.sourcePath).source)
    }
}
