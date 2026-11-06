import Foundation
import XCTest
@testable import BaroqueCore

final class QuoteParserTests: XCTestCase {
    private func quotes(_ md: String) -> [Quote] { QuoteParser.parse(markdown: md) }
    private func q(_ text: String, _ author: String? = nil) -> Quote { Quote(text: text, author: author) }

    func testRealStarterQuotesFile() throws {
        let url = repoRoot.appendingPathComponent("examples/Quotes.md")
        let md = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(quotes(md), [
            q("Our life is frittered away by detail.", "Henry David Thoreau, Walden"),
            q("Make the quiet thing first, then the loud one."),
            q("Begin at once to live, and count each separate day as a separate life.", "Seneca"),
            q("Good ideas take time.", "unknown"),
        ])
    }

    /// A quote on a line of its own, in curly quotes, with "- Author" after it (the author's own Quotes.md style).
    func testStandaloneQuoteLines() {
        XCTAssertEqual(quotes("“The best way out is always through” - Robert Frost\n"),
                       [q("The best way out is always through", "Robert Frost")])
        XCTAssertEqual(quotes("\"Stay hungry.\"\n\n\"Stay foolish.\" — Stewart Brand"),
                       [q("Stay hungry."), q("Stay foolish.", "Stewart Brand")])
        XCTAssertEqual(quotes("“Be here now.” — O’Brien"), [q("Be here now.", "O’Brien")])
        // Prose that only starts with a quotation is not a quote.
        XCTAssertEqual(quotes("\"Hi\" is what I said to him."), [])
    }

    func testBlockquoteWithEmDashAuthor() {
        XCTAssertEqual(quotes("> Waste no more time arguing what a good man should be. Be one.\n> — Marcus Aurelius"),
                       [q("Waste no more time arguing what a good man should be. Be one.", "Marcus Aurelius")])
        XCTAssertEqual(quotes("> Be one.\n> —Marcus Aurelius"), [q("Be one.", "Marcus Aurelius")])
    }

    func testOtherDashAuthors() {
        XCTAssertEqual(quotes("> Luck is what happens when preparation meets opportunity.\n> – Seneca"),
                       [q("Luck is what happens when preparation meets opportunity.", "Seneca")])
        XCTAssertEqual(quotes("> No man is free who is not master of himself.\n> - Epictetus"),
                       [q("No man is free who is not master of himself.", "Epictetus")])
        XCTAssertEqual(quotes("> Text.\n> -- Someone"), [q("Text.", "Someone")])
        XCTAssertEqual(quotes("> Text.\n> ~ Someone"), [q("Text.", "Someone")])
        XCTAssertEqual(quotes("> Text.\n> ― Someone"), [q("Text.", "Someone")])
    }

    func testAuthorLineDirectlyBelowBlockquote() {
        XCTAssertEqual(quotes("> Simplicity is the ultimate sophistication.\n— Leonardo da Vinci"),
                       [q("Simplicity is the ultimate sophistication.", "Leonardo da Vinci")])
        XCTAssertEqual(quotes("> Simplicity.\n- Leonardo"), [q("Simplicity.", "Leonardo")])
    }

    func testInlineAuthorOnLastLine() {
        XCTAssertEqual(quotes(#"> "Stay hungry, stay foolish." — Steve Jobs"#), [q("Stay hungry, stay foolish.", "Steve Jobs")])
        XCTAssertEqual(quotes("> Stay hungry. — Steve Jobs"), [q("Stay hungry.", "Steve Jobs")])
        // An em dash inside a sentence is not an attribution.
        XCTAssertEqual(quotes("> I came — and I saw"), [q("I came — and I saw")])
    }

    func testBulletQuotes() {
        let md = """
        - "Good ideas take time." — unknown
        * “Curly bullet.” – Ana
        + "No author here."
        - Plain text - Bob
        - "A - B" — C
        - [ ] A task, not a quote
        """
        XCTAssertEqual(quotes(md), [
            q("Good ideas take time.", "unknown"),
            q("Curly bullet.", "Ana"),
            q("No author here."),
            q("Plain text", "Bob"),
            q("A - B", "C"),
        ])
    }

    func testQuoteCalloutWithoutTitle() {
        let md = "> [!quote]\n> You have power over your mind, not outside events.\n> — Marcus Aurelius"
        XCTAssertEqual(quotes(md), [q("You have power over your mind, not outside events.", "Marcus Aurelius")])
    }

    func testQuoteCalloutTitleIsAuthor() {
        let md = "> [!quote] Marcus Aurelius\n> You have power over your mind, not outside events."
        XCTAssertEqual(quotes(md), [q("You have power over your mind, not outside events.", "Marcus Aurelius")])
    }

    func testAuthorLineBeatsCalloutTitle() {
        let md = "> [!quote] Meditations\n> The impediment to action advances action.\n> — Marcus Aurelius"
        XCTAssertEqual(quotes(md), [q("The impediment to action advances action.", "Marcus Aurelius")])
    }

    func testFoldableAndAliasCallouts() {
        let md = """
        > [!quote]-
        > Folded closed.

        > [!quote]+ Seneca
        > Folded open.

        > [!QUOTE] Upper
        > Upper case type.

        > [!cite]
        > Cite is an alias.
        > — Someone

        > [!quote|wide]- Meta
        > With callout metadata.
        """
        XCTAssertEqual(quotes(md), [
            q("Folded closed."),
            q("Folded open.", "Seneca"),
            q("Upper case type.", "Upper"),
            q("Cite is an alias.", "Someone"),
            q("With callout metadata.", "Meta"),
        ])
    }

    func testNonQuoteCalloutsAreIgnored() {
        let md = "> [!note] How this file works\n> Put one quote per blockquote.\n\n> Real quote."
        XCTAssertEqual(quotes(md), [q("Real quote.")])
    }

    func testMultiLineQuote() {
        let md = "> The best time to plant a tree\n> was twenty years ago.\n> The second best time is now.\n> — Proverb"
        XCTAssertEqual(quotes(md), [q("The best time to plant a tree was twenty years ago. The second best time is now.", "Proverb")])
    }

    func testMultiParagraphQuoteStaysTogether() {
        let md = "> First paragraph.\n>\n> Second paragraph.\n> — Author\n\n> Next quote."
        XCTAssertEqual(quotes(md), [q("First paragraph.\nSecond paragraph.", "Author"), q("Next quote.")])
        XCTAssertEqual(quotes("> [!quote] A\n> One.\n> \n> Two."), [q("One.\nTwo.", "A")])
    }

    func testBlankLineSeparatesQuotes() {
        XCTAssertEqual(quotes("> One.\n\n> Two.\n— B\n\n\n> Three."), [q("One."), q("Two.", "B"), q("Three.")])
    }

    func testCurlyAndStraightQuotesAreStripped() {
        XCTAssertEqual(quotes("> “To be, or not to be.”\n> — Shakespeare"), [q("To be, or not to be.", "Shakespeare")])
        XCTAssertEqual(quotes("> \"Straight.\""), [q("Straight.")])
        XCTAssertEqual(quotes("> ‘Single curly.’"), [q("Single curly.")])
        XCTAssertEqual(quotes("> 'Don't panic.'"), [q("Don't panic.")])
        XCTAssertEqual(quotes(#"> "He said "hi" to me.""#), [q(#"He said "hi" to me."#)])
    }

    func testQuotesThatOnlyLookWrappedAreKept() {
        XCTAssertEqual(quotes(#"> "A" and "B" are letters."#), [q(#""A" and "B" are letters."#)])
        XCTAssertEqual(quotes("> “A” and “B”"), [q("“A” and “B”")])
    }

    func testHeadingsAndProseAreIgnored() {
        let md = """
        # Quotes
        Some prose explaining the file.

        ## Stoics
        > Quote one.
        > — Seneca

        More prose.
        ### Other
        """
        XCTAssertEqual(quotes(md), [q("Quote one.", "Seneca")])
    }

    func testFrontmatterAndCodeAreIgnored() {
        let md = """
        ---
        tags:
          - quotes
        aliases: [Q]
        ---
        ```
        > Example quote in a code block
        > — Nobody
        - "Example bullet" — Nobody
        ```
        > Real.
        """
        XCTAssertEqual(quotes(md), [q("Real.")])
    }

    func testMarkdownInsideQuotesIsCleaned() {
        let md = "> The **obstacle** is the [[Way]].\n> — [[Marcus Aurelius|Marcus]], *Meditations*"
        XCTAssertEqual(quotes(md), [q("The obstacle is the Way.", "Marcus, Meditations")])
    }

    func testCRLF() {
        XCTAssertEqual(quotes("> One\r\n> two\r\n> — A\r\n\r\n> Three\r\n"), [q("One two", "A"), q("Three")])
    }
}
