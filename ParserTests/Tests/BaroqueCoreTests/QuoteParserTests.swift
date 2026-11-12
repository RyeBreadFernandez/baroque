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
        XCTAssertEqual(quotes("\"Well done is better than well said.\"\n\n\"Lost time is never found again.\" — Benjamin Franklin"),
                       [q("Well done is better than well said."), q("Lost time is never found again.", "Benjamin Franklin")])
        XCTAssertEqual(quotes("“We are the music makers.” — Arthur O’Shaughnessy"), [q("We are the music makers.", "Arthur O’Shaughnessy")])
        // Prose that only starts with a quotation is not a quote.
        XCTAssertEqual(quotes("\"Hi\" is what I said to him."), [])
    }

    /// The author on the line below a quote in quotation marks (the author's own style), or as a sub-bullet.
    func testAuthorOnTheLineBelowAQuotedLine() {
        XCTAssertEqual(quotes("“Simplify, simplify.”\n- Henry David Thoreau"), [q("Simplify, simplify.", "Henry David Thoreau")])
        XCTAssertEqual(quotes("“Simplify, simplify.”\n— Henry David Thoreau"), [q("Simplify, simplify.", "Henry David Thoreau")])
        XCTAssertEqual(quotes("- “Hitch your wagon to a star.”\n  - Ralph Waldo Emerson"),
                       [q("Hitch your wagon to a star.", "Ralph Waldo Emerson")])
        XCTAssertEqual(quotes("* \"Brevity is the soul of wit.\"\n\t* William Shakespeare"),
                       [q("Brevity is the soul of wit.", "William Shakespeare")])
        // Several in a row, each with its author below.
        let md = """
        “Well done is better than well said.”
        - Benjamin Franklin
        “The best way out is always through.”
        - Robert Frost
        """
        XCTAssertEqual(quotes(md), [q("Well done is better than well said.", "Benjamin Franklin"),
                                    q("The best way out is always through.", "Robert Frost")])
    }

    /// An author line only joins the quote just above it, when that quote is in quotation marks and has no author.
    func testWhatIsNotAnAuthorBelow() {
        // A blank line between: two quotes.
        XCTAssertEqual(quotes("“Simplify, simplify.”\n\n- Henry David Thoreau"),
                       [q("Simplify, simplify."), q("Henry David Thoreau")])
        // The quote above already has an author: the bullet is a quote of its own.
        XCTAssertEqual(quotes("“Simplify, simplify.” - Henry David Thoreau\n- Lost time is never found again."),
                       [q("Simplify, simplify.", "Henry David Thoreau"), q("Lost time is never found again.")])
        // A list of plain bullet quotes stays a list.
        XCTAssertEqual(quotes("- Simplify, simplify.\n- Brevity is the soul of wit."),
                       [q("Simplify, simplify."), q("Brevity is the soul of wit.")])
        // Quoted bullets in a row are each a quote.
        XCTAssertEqual(quotes("- “Simplify, simplify.”\n- “Brevity is the soul of wit.”"),
                       [q("Simplify, simplify."), q("Brevity is the soul of wit.")])
        // A task is never an author.
        XCTAssertEqual(quotes("“Simplify, simplify.”\n- [ ] Buy a notebook"), [q("Simplify, simplify.")])
        XCTAssertEqual(quotes("> Simplify, simplify.\n- [ ] Buy a notebook"), [q("Simplify, simplify.")])
    }

    /// Under a bullet quote, a plain bullet is the next quote in the list: only a sub-bullet or a dash line is its author.
    func testAPlainBulletUnderAQuotedBulletIsTheNextQuote() {
        XCTAssertEqual(quotes("- \"Simplify, simplify.\"\n- Know thyself.\n- Less is more."),
                       [q("Simplify, simplify."), q("Know thyself."), q("Less is more.")])
        XCTAssertEqual(quotes("- “Simplify, simplify.”\n- Henry David Thoreau"),
                       [q("Simplify, simplify."), q("Henry David Thoreau")])
        XCTAssertEqual(quotes("- “Simplify, simplify.”\n— Henry David Thoreau"), [q("Simplify, simplify.", "Henry David Thoreau")])
        XCTAssertEqual(quotes("- “Simplify, simplify.”\n– Henry David Thoreau"), [q("Simplify, simplify.", "Henry David Thoreau")])
    }

    /// Under a quote on a line of its own, `- B` is its author only when B reads like a name, not a sentence.
    func testAPlainSentenceUnderAStandaloneQuoteIsNotItsAuthor() {
        XCTAssertEqual(quotes("“Simplify, simplify.”\n- Know thyself."), [q("Simplify, simplify."), q("Know thyself.")])
        XCTAssertEqual(quotes("“Simplify, simplify.”\n- Is this the way?"), [q("Simplify, simplify."), q("Is this the way?")])
        XCTAssertEqual(quotes("“Simplify, simplify.”\n- Henry David Thoreau, Walden"), [q("Simplify, simplify.", "Henry David Thoreau, Walden")])
        // A name may end in an abbreviation's full stop.
        XCTAssertEqual(quotes("“The life of the law has not been logic: it has been experience.”\n- Oliver Wendell Holmes Jr."),
                       [q("The life of the law has not been logic: it has been experience.", "Oliver Wendell Holmes Jr.")])
        let long = String(repeating: "a word ", count: 13)   // 91 characters: a sentence, not a name
        XCTAssertEqual(quotes("“Simplify, simplify.”\n- \(long)").count, 2)
    }

    /// `> “Text” - Author`: a hyphen right after a closing quotation mark is an attribution.
    func testHyphenAfterClosingQuoteInABlockquote() {
        XCTAssertEqual(quotes("> “Brevity is the soul of wit.” - William Shakespeare"),
                       [q("Brevity is the soul of wit.", "William Shakespeare")])
        XCTAssertEqual(quotes("> \"Lost time is never found again.\" -- Benjamin Franklin"),
                       [q("Lost time is never found again.", "Benjamin Franklin")])
        XCTAssertEqual(quotes("> “We are the music makers.” - Arthur O’Shaughnessy"),
                       [q("We are the music makers.", "Arthur O’Shaughnessy")])
        // Over two lines, the author after the closing mark on the last.
        XCTAssertEqual(quotes("> “The best way out\n> is always through.” - Robert Frost"),
                       [q("The best way out is always through.", "Robert Frost")])
        // A hyphen in a sentence is still not an attribution, nor one after a title the quote doesn't open with.
        XCTAssertEqual(quotes("> I came - and I saw"), [q("I came - and I saw")])
        XCTAssertEqual(quotes("> Read “Walden” - then walk."), [q("Read “Walden” - then walk.")])
    }

    func testBlockquoteWithEmDashAuthor() {
        XCTAssertEqual(quotes("> Our life is frittered away by detail. Simplify, simplify.\n> — Henry David Thoreau"),
                       [q("Our life is frittered away by detail. Simplify, simplify.", "Henry David Thoreau")])
        XCTAssertEqual(quotes("> Simplify, simplify.\n> —Henry David Thoreau"), [q("Simplify, simplify.", "Henry David Thoreau")])
    }

    func testOtherDashAuthors() {
        XCTAssertEqual(quotes("> Brevity is the soul of wit.\n> – William Shakespeare"),
                       [q("Brevity is the soul of wit.", "William Shakespeare")])
        XCTAssertEqual(quotes("> No man is free who is not master of himself.\n> - Epictetus"),
                       [q("No man is free who is not master of himself.", "Epictetus")])
        XCTAssertEqual(quotes("> Text.\n> -- Someone"), [q("Text.", "Someone")])
        XCTAssertEqual(quotes("> Text.\n> ~ Someone"), [q("Text.", "Someone")])
        XCTAssertEqual(quotes("> Text.\n> ― Someone"), [q("Text.", "Someone")])
    }

    func testAuthorLineDirectlyBelowBlockquote() {
        XCTAssertEqual(quotes("> Hitch your wagon to a star.\n— Ralph Waldo Emerson"),
                       [q("Hitch your wagon to a star.", "Ralph Waldo Emerson")])
        XCTAssertEqual(quotes("> Simplify, simplify.\n- Thoreau"), [q("Simplify, simplify.", "Thoreau")])
    }

    func testInlineAuthorOnLastLine() {
        XCTAssertEqual(quotes(#"> "Nothing will come of nothing." — William Shakespeare"#), [q("Nothing will come of nothing.", "William Shakespeare")])
        XCTAssertEqual(quotes("> Nothing will come of nothing. — William Shakespeare"), [q("Nothing will come of nothing.", "William Shakespeare")])
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
        let md = "> [!quote]\n> To be great is to be misunderstood.\n> — Ralph Waldo Emerson"
        XCTAssertEqual(quotes(md), [q("To be great is to be misunderstood.", "Ralph Waldo Emerson")])
    }

    func testQuoteCalloutTitleIsAuthor() {
        let md = "> [!quote] Ralph Waldo Emerson\n> To be great is to be misunderstood."
        XCTAssertEqual(quotes(md), [q("To be great is to be misunderstood.", "Ralph Waldo Emerson")])
    }

    func testAuthorLineBeatsCalloutTitle() {
        let md = "> [!quote] Self-Reliance\n> Trust thyself: every heart vibrates to that iron string.\n> — Ralph Waldo Emerson"
        XCTAssertEqual(quotes(md), [q("Trust thyself: every heart vibrates to that iron string.", "Ralph Waldo Emerson")])
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
        let md = "> **Brevity** is the soul of [[wit]].\n> — [[William Shakespeare|Shakespeare]], *Hamlet*"
        XCTAssertEqual(quotes(md), [q("Brevity is the soul of wit.", "Shakespeare, Hamlet")])
    }

    func testCRLF() {
        XCTAssertEqual(quotes("> One\r\n> two\r\n> — A\r\n\r\n> Three\r\n"), [q("One two", "A"), q("Three")])
    }
}
