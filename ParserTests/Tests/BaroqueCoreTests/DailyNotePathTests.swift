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
        - [ ] #todo Join the all-staff "Info Sharing" Zoom at 8:00 AM. (Alex Rivera, email, Nov 4)
        - [ ] #todo Reply to Sam about the problem set, part B. (Sam, email reply Nov 5)
        - [x] #todo Something already done. (email)

        ## Today
        - 8:00 AM to 8:50 AM  Info Sharing meeting, Zoom
        - 12:00 PM to 1:50 PM  Discussion section, Room 3400

        ## Resolved
        - The reimbursement check was picked up.
        """
        let tasks = TaskParser.parse(markdown: brief, sourcePath: "Daily Brief/Today.md")
        XCTAssertEqual(tasks.map(\.text), [
            "Join the all-staff \"Info Sharing\" Zoom at 8:00 AM. (Alex Rivera, email, Nov 4)",
            "Reply to Sam about the problem set, part B. (Sam, email reply Nov 5)",
        ])
        XCTAssertTrue(tasks.allSatisfy { $0.due == nil })
        XCTAssertEqual(TaskParser.sourceNote(tasks[1].text).text, "Reply to Sam about the problem set, part B.")
        XCTAssertEqual(TaskParser.sourceNote(tasks[1].text).source, "Sam, email reply Nov 5")
        XCTAssertNil(TaskParser.sourceNote("Pump tires, get gas").source)
        XCTAssertNil(TaskParser.sourceNote("Call (maybe) the dentist").source)   // a parenthesis inside, not a note
        // Undated, so they show while undated tasks are included (the default), in the brief's order.
        XCTAssertEqual(TaskParser.todaysAgenda(tasks, includeUndated: true, limit: 5).count, 2)
    }
}
