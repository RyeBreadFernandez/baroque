import Foundation
import XCTest
@testable import BaroqueCore

/// Gregorian date in the local time zone, the same way the parser builds due dates (local midnight).
func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    return cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
}

/// The Baroque repo root (ParserTests/Tests/BaroqueCoreTests/<this file> -> Baroque/).
let repoRoot: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // BaroqueCoreTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // ParserTests
    .deletingLastPathComponent()  // Baroque

func tasks(_ md: String, path: String = "Tasks/Master Task List.md") -> [TaskItem] {
    TaskParser.parse(markdown: md, sourcePath: path)
}

/// Parses a single line and asserts exactly one task came out.
func one(_ line: String, file: StaticString = #filePath, lineNo: UInt = #line) -> TaskItem? {
    let items = tasks(line)
    XCTAssertEqual(items.count, 1, "expected one task from \(line.debugDescription), got \(items.map(\.text))", file: file, line: lineNo)
    return items.first
}
