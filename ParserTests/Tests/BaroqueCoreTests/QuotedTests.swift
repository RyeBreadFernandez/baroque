import XCTest
@testable import BaroqueCore

/// The widgets set a quote's words inside quotation marks, the author outside them (RococoWords.quoted).
final class QuotedTests: XCTestCase {
    func testWordsGoInsideCurlyMarks() {
        XCTAssertEqual(RococoWords.quoted("Simplify, simplify."), "\u{201C}Simplify, simplify.\u{201D}")
    }

    func testMarksAlreadyRoundTheLineAreNotDoubled() {
        XCTAssertEqual(RococoWords.quoted("\u{201C}Brevity is the soul of wit.\u{201D}"), "\u{201C}Brevity is the soul of wit.\u{201D}")
        XCTAssertEqual(RococoWords.quoted("\"Brevity is the soul of wit.\""), "\u{201C}Brevity is the soul of wit.\u{201D}")
        XCTAssertEqual(RococoWords.quoted("  \u{201C}Hope\u{201D}  "), "\u{201C}Hope\u{201D}")
    }

    func testQuotesInsideBecomeSingle() {
        XCTAssertEqual(RococoWords.quoted("He said \u{201C}go\u{201D} and went."), "\u{201C}He said \u{2018}go\u{2019} and went.\u{201D}")
        XCTAssertEqual(RococoWords.quoted("\"Hi\" is what I said."), "\u{201C}\u{2018}Hi\u{2019} is what I said.\u{201D}")
    }

    func testInnerLeavesApostrophesAlone() {
        XCTAssertEqual(RococoWords.inner("Don't stop."), "Don't stop.")
    }
}
