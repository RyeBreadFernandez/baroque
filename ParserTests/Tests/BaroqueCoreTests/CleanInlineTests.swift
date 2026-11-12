import Foundation
import XCTest
@testable import BaroqueCore

final class CleanInlineTests: XCTestCase {
    private func clean(_ s: String) -> String { TaskParser.cleanInline(s) }

    func testWikiLinks() {
        XCTAssertEqual(clean("Read [[Note]] today"), "Read Note today")
        XCTAssertEqual(clean("Email [[Mrs. Hudson|Mrs. H]]"), "Email Mrs. H")
        XCTAssertEqual(clean("See [[Note#Heading]]"), "See Note > Heading")
        XCTAssertEqual(clean("See [[Note#Heading|the part]]"), "See the part")
        XCTAssertEqual(clean("See [[#Heading]]"), "See Heading")
        XCTAssertEqual(clean("See [[Note#^abc123]]"), "See Note")
        XCTAssertEqual(clean("See [[Projects/Garden]] and [[Physics]]"), "See Projects/Garden and Physics")
    }

    func testEmbedsAreRemoved() {
        XCTAssertEqual(clean("Fix layout ![[diagram.png]] tonight"), "Fix layout tonight")
        XCTAssertEqual(clean("Fix layout ![[diagram.png|300]]"), "Fix layout")
        XCTAssertEqual(clean("Fix layout ![screen](https://example.com/a.png)"), "Fix layout")
        XCTAssertEqual(clean("![[Other note]] Review"), "Review")
    }

    func testMarkdownLinks() {
        XCTAssertEqual(clean("Read [the paper](https://arxiv.org/abs/1234.5678)"), "Read the paper")
        XCTAssertEqual(clean("Read [Foo](https://en.wikipedia.org/wiki/Foo_(bar)) now"), "Read Foo now")
        XCTAssertEqual(clean("Open [notes](obsidian://open?vault=v&file=x)"), "Open notes")
        XCTAssertEqual(clean("Open [notes](<My Note.md>)"), "Open notes")
    }

    func testBareURLsBecomeHosts() {
        XCTAssertEqual(clean("Watch https://www.youtube.com/watch?v=abc123 later"), "Watch youtube.com later")
        XCTAssertEqual(clean("Check http://example.com"), "Check example.com")
        XCTAssertEqual(clean("Check <https://example.com/a/b>"), "Check example.com")
        XCTAssertEqual(clean("PR https://github.com/o/r/pull/3#issuecomment-1"), "PR github.com")
    }

    func testEmphasisMarkers() {
        XCTAssertEqual(clean("**Bold** and __also bold__"), "Bold and also bold")
        XCTAssertEqual(clean("*Italic* and _also italic_"), "Italic and also italic")
        XCTAssertEqual(clean("***Both*** at once"), "Both at once")
        XCTAssertEqual(clean("~~struck~~ ==highlighted== `code`"), "struck highlighted code")
    }

    func testEmphasisLookalikesAreKept() {
        XCTAssertEqual(clean("Rename my_var_name"), "Rename my_var_name")
        XCTAssertEqual(clean("Compute 2 * 3 * 4"), "Compute 2 * 3 * 4")
        XCTAssertEqual(clean("Compute a*b*c"), "Compute a*b*c")
    }

    func testTags() {
        XCTAssertEqual(clean("#todo Buy milk"), "Buy milk")
        XCTAssertEqual(clean("Buy milk #errands/store #y2026 #café"), "Buy milk")
        XCTAssertEqual(clean("Fix issue #3 and #2026 report"), "Fix issue #3 and #2026 report")
        XCTAssertEqual(clean("Learn C# and F#"), "Learn C# and F#")
        XCTAssertEqual(clean("Plan foo#bar"), "Plan foo#bar")
        XCTAssertEqual(clean("Item # 5"), "Item # 5")
        XCTAssertEqual(clean("Say \\#notatag"), "Say #notatag")
    }

    func testCommentsAndBlockIDs() {
        XCTAssertEqual(clean("Visible %%hidden%% text"), "Visible text")
        XCTAssertEqual(clean("Review notes ^abc-123"), "Review notes")
        XCTAssertEqual(clean("Compute 2^10"), "Compute 2^10")
    }

    func testWhitespaceIsCollapsed() {
        XCTAssertEqual(clean("  a \t  b   c  "), "a b c")
    }
}
