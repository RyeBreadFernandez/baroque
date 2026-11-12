import Foundation

// The Daily Brief page, made the way Obsidian's reading view makes it (2026-11-12: "it does not look the same at all.
// i want it to have the same UI"). The brief's look is the vault's own CSS snippet, named in the note's front matter
// (`cssclasses: [daily-brief]`) and written against the DOM Obsidian builds from the note: callouts, task lists,
// `<small>` source lines. So this builds that DOM from the note, and the page (BriefView.swift) shows it in a web view
// with the vault's CSS (BriefStyle.swift) after a base sheet of Baroque's own, so the brief looks as it does in
// Obsidian.
//
// Nothing from the vault runs. A dataviewjs block that writes the hero's date and clock becomes two empty spans that
// Baroque's own script fills; any other dataview block is left out. Inline HTML passes through without scripts,
// frames, styles, `on…` attributes or `javascript:` links, and the Content-Security-Policy lets only Baroque's script
// (by its nonce) run. Foundation only: ParserTests compiles it through a symlink.

enum BriefHTML {
    // MARK: What the page passes in

    /// How a task's checkbox shows: ticked or not, whether a tap ticks it, and the line under it ("Saving…", or why
    /// it isn't saved, in terracotta when `problem`).
    struct TaskState: Equatable {
        var done: Bool
        var enabled: Bool = true
        var note: String? = nil
        var problem: Bool = false
    }

    /// The fonts from the vault's `.obsidian/appearance.json`, which Obsidian uses for the reading view.
    struct Appearance: Equatable {
        var textFontFamily: String?
        var interfaceFontFamily: String?
        var monospaceFontFamily: String?
        var baseFontSize: Double?

        init(textFontFamily: String? = nil, interfaceFontFamily: String? = nil, monospaceFontFamily: String? = nil,
             baseFontSize: Double? = nil) {
            self.textFontFamily = textFontFamily
            self.interfaceFontFamily = interfaceFontFamily
            self.monospaceFontFamily = monospaceFontFamily
            self.baseFontSize = baseFontSize
        }

        /// The file's JSON; nil when it isn't an object. Keys it doesn't use are ignored.
        init?(json: Data) {
            guard let object = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return nil }
            func text(_ key: String) -> String? {
                guard let value = (object[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
                return value
            }
            textFontFamily = text("textFontFamily")
            interfaceFontFamily = text("interfaceFontFamily")
            monospaceFontFamily = text("monospaceFontFamily")
            baseFontSize = (object["baseFontSize"] as? NSNumber)?.doubleValue
        }
    }

    struct Page {
        var markdown: String
        /// The vault's CSS snippets, in the order the note names them. Empty: Baroque's fallback sheet.
        var css: [String] = []
        var appearance: Appearance? = nil
        /// Each task's state by its 1-based line in the file (the page's `TaskSync.shown`).
        var tasks: [Int: TaskState] = [:]
        /// The muted line at the foot: when the brief was written and fetched.
        var footer: String? = nil
        /// The Content-Security-Policy's nonce for Baroque's script, new for each load.
        var nonce: String
    }

    /// The page in two parts: `head` (the page's classes and its style sheets), which needs a fresh load when it
    /// changes, and the sizer's children, which the page swaps one by one when only they change.
    struct Rendered: Equatable {
        var head: String
        var blocks: [String]
    }

    // MARK: The page

    static func render(_ page: Page) -> Rendered {
        let footer = page.footer.map { ["<div class=\"el-div baroque-stamp\">\(escape($0))</div>"] } ?? []
        return Rendered(head: pageClasses(page.markdown) + "\n" + styles(page), blocks: blocks(page.markdown, tasks: page.tasks) + footer)
    }

    static func document(_ page: Page, rendered: Rendered? = nil) -> String {
        let parts = rendered ?? render(page)
        let nonce = cleanNonce(page.nonce)
        return """
        <!doctype html>
        <html lang="en"><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light">
        <meta http-equiv="Content-Security-Policy" content="\(csp(nonce: nonce))">
        \(styles(page))
        </head>
        <body class="theme-light">
        <div class="\(pageClasses(page.markdown))"><div class="markdown-preview-sizer markdown-preview-section">
        \(parts.blocks.joined(separator: "\n"))
        </div></div>
        <script nonce="\(nonce)">\(script)</script>
        </body></html>
        """
    }

    /// Only Baroque's own script runs (by its nonce); pictures from the web, the vault CSS's embedded fonts.
    static func csp(nonce: String) -> String {
        "default-src 'none'; img-src https: data:; style-src 'unsafe-inline'; font-src data:; script-src 'nonce-\(cleanNonce(nonce))'"
    }

    static func makeNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 18)
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
    }

    private static func cleanNonce(_ nonce: String) -> String {
        String(nonce.filter { $0.isASCII && ($0.isLetter || $0.isNumber || "+/=".contains($0)) })
    }

    /// Obsidian's reading view classes, then the note's own `cssclasses`, which its CSS snippets select on.
    static func pageClasses(_ markdown: String) -> String {
        (["markdown-preview-view", "markdown-rendered", "is-readable-line-width"] + cssClasses(in: markdown)).joined(separator: " ")
    }

    /// Baroque's base sheet, the vault's fonts, then the vault's snippets (or the fallback), so the vault's CSS wins.
    static func styles(_ page: Page) -> String {
        let sheets = page.css.isEmpty ? [fallbackCSS] : page.css
        return ([baseCSS, fontVariables(page.appearance)] + sheets)
            .map { "<style>\n\($0.replacingOccurrences(of: "</style", with: "<\\/style", options: .caseInsensitive))\n</style>" }
            .joined(separator: "\n")
    }

    /// The vault's fonts as Obsidian's variables (`--font-text`, `--font-interface`, `--font-monospace`) and its text
    /// size, each followed by Baroque's defaults.
    static func fontVariables(_ appearance: Appearance?) -> String {
        var lines: [String] = []
        if let text = families(appearance?.textFontFamily) { lines.append("--font-text: \(text), var(--font-default);") }
        if let interface = families(appearance?.interfaceFontFamily) { lines.append("--font-interface: \(interface), var(--font-default);") }
        if let mono = families(appearance?.monospaceFontFamily) { lines.append("--font-monospace: \(mono), ui-monospace, Menlo, monospace;") }
        if let size = appearance?.baseFontSize, (10...32).contains(size) { lines.append("--font-text-size: \(Int(size))px;") }
        return ":root {\n" + lines.map { "  " + $0 }.joined(separator: "\n") + "\n}"
    }

    /// "Times New Roman" or "Inter, Georgia" as quoted CSS family names; anything that isn't a plain name is dropped.
    private static func families(_ value: String?) -> String? {
        guard let value else { return nil }
        let names = value.split(separator: ",").compactMap { part -> String? in
            let name = part.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'"))
            let plain = name.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || " -_.".unicodeScalars.contains($0) }
            return !name.isEmpty && plain && name.count <= 64 ? "\"\(name)\"" : nil
        }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    // MARK: The note's front matter

    /// The note's `cssclasses` (or the older `cssclass`): `[a, b]`, `a, b`, or a YAML list on the lines below. Only
    /// plain class names (letters, digits, `-` and `_`), each once.
    static func cssClasses(in markdown: String) -> [String] {
        let lines = TaskToggle.Lines(markdown).lines
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return [] }
        var found: [String] = []
        var inList = false
        for line in lines.dropFirst() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t == "---" || t == "..." { break }
            if inList {
                if t.hasPrefix("- ") || t == "-" { found.append(String(t.dropFirst())); continue }
                if t.isEmpty { continue }
                inList = false
            }
            guard let colon = t.firstIndex(of: ":"), ["cssclasses", "cssclass"].contains(t[..<colon].trimmingCharacters(in: .whitespaces).lowercased())
            else { continue }
            var value = t[t.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if value.isEmpty { inList = true; continue }
            if value.hasPrefix("["), value.hasSuffix("]") { value = String(value.dropFirst().dropLast()) }
            found += value.split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init)
        }
        var out: [String] = []
        for raw in found {
            let name = raw.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'"))
            guard !name.isEmpty, name.count <= 64, !out.contains(name),
                  name.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_") })
            else { continue }
            out.append(name)
        }
        return out
    }

    // MARK: The note's lines

    struct Line: Equatable {
        /// 1-based, as Obsidian, TaskParser and Brief count lines.
        let number: Int
        let text: String
    }

    /// The note's lines without its front matter and `%%` comments, each with its number in the file. Lines are split
    /// as MarkdownText splits them (CRLF, a byte order mark), so a task here has the line number Brief gives it.
    static func lines(of markdown: String) -> [Line] {
        let text = markdown.first == "\u{FEFF}" ? String(markdown.dropFirst()) : markdown
        let raw = text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }).map(String.init)
        var start = 0
        if raw.first?.trimmingCharacters(in: .whitespaces) == "---",
           let end = raw.dropFirst().firstIndex(where: { ["---", "..."].contains($0.trimmingCharacters(in: .whitespaces)) }) {
            start = end + 1
        }
        var out: [Line] = []
        var fence: (char: Character, length: Int)?
        var inComment = false
        for i in start..<max(start, raw.count) {
            // The placeholders the inline renderer uses can't come from the note.
            var line = raw[i].replacingOccurrences(of: "\u{E000}", with: "").replacingOccurrences(of: "\u{E001}", with: "")
            let stripped = String(line.drop(while: { $0 == " " || $0 == "\t" || $0 == ">" }))
            if let open = fence {
                out.append(Line(number: i + 1, text: line))
                let run = stripped.prefix(while: { $0 == open.char })
                if run.count >= open.length, stripped.dropFirst(run.count).allSatisfy(\.isWhitespace) { fence = nil }
                continue
            }
            if !inComment, let c = stripped.first, c == "`" || c == "~" {
                let run = stripped.prefix(while: { $0 == c })
                if run.count >= 3, !(c == "`" && stripped.dropFirst(run.count).contains("`")) {
                    fence = (c, run.count)
                    out.append(Line(number: i + 1, text: line))
                    continue
                }
            }
            // %% comments %%, on one line or over several.
            var kept = ""
            var rest = Substring(line)
            var cut = false
            while true {
                if inComment {
                    guard let close = rest.range(of: "%%") else { rest = ""; cut = true; break }
                    rest = rest[close.upperBound...]
                    inComment = false
                    cut = true
                } else {
                    guard let open = rest.range(of: "%%") else { kept += rest; break }
                    kept += rest[..<open.lowerBound]
                    rest = rest[open.upperBound...]
                    inComment = true
                    cut = true
                }
            }
            line = kept
            if cut, line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            out.append(Line(number: i + 1, text: line))
        }
        return out
    }

    // MARK: Blocks

    /// The sizer's children: each top-level block in its own `div.el-…`, as Obsidian wraps them.
    static func blocks(_ markdown: String, tasks: [Int: TaskState]) -> [String] {
        let renderer = Renderer(tasks: tasks)
        return renderer.blocks(lines(of: markdown)).map { "<div class=\"el-\($0.kind)\">\($0.html)</div>" }
    }

    private struct Block {
        var kind: String
        var html: String
    }

    private final class Renderer {
        let tasks: [Int: TaskState]
        init(tasks: [Int: TaskState]) { self.tasks = tasks }

        func blocks(_ lines: [Line]) -> [Block] {
            var out: [Block] = []
            var i = 0
            while i < lines.count {
                let text = lines[i].text
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { i += 1; continue }
                if BriefHTML.quoted(text) != nil {
                    var inner: [Line] = []
                    while i < lines.count, let rest = BriefHTML.quoted(lines[i].text) {
                        inner.append(Line(number: lines[i].number, text: rest))
                        i += 1
                    }
                    out.append(quote(inner))
                    continue
                }
                if let fence = BriefHTML.fenceOpen(trimmed) {
                    let indent = BriefHTML.indentWidth(text)
                    var code: [String] = []
                    i += 1
                    while i < lines.count {
                        let t = lines[i].text.trimmingCharacters(in: .whitespaces)
                        let run = t.prefix(while: { $0 == fence.char })
                        if run.count >= fence.length, t.dropFirst(run.count).allSatisfy(\.isWhitespace) { i += 1; break }
                        code.append(BriefHTML.dropIndent(lines[i].text, indent))
                        i += 1
                    }
                    if let block = codeBlock(language: fence.language, code: code.joined(separator: "\n")) { out.append(block) }
                    continue
                }
                if let heading = BriefHTML.heading(trimmed) {
                    let plain = BriefHTML.escape(heading.text)
                    out.append(Block(kind: "h\(heading.level)",
                                     html: "<h\(heading.level) data-heading=\"\(plain)\" dir=\"auto\">\(Inline().markdown(heading.text, breaks: false))</h\(heading.level)>"))
                    i += 1
                    continue
                }
                if BriefHTML.isThematicBreak(trimmed) {
                    out.append(Block(kind: "hr", html: "<hr>"))
                    i += 1
                    continue
                }
                if BriefHTML.listItem(text) != nil {
                    let list = self.list(lines, from: i)
                    out.append(list.block)
                    i = list.next
                    continue
                }
                if let tag = BriefHTML.htmlBlockTag(trimmed) {
                    var raw: [String] = []
                    let closer = BriefHTML.rawHTMLCloser(tag)
                    while i < lines.count {
                        let t = lines[i].text
                        if closer == nil, t.trimmingCharacters(in: .whitespaces).isEmpty { break }
                        raw.append(t)
                        i += 1
                        if let closer, t.range(of: closer, options: .caseInsensitive) != nil { break }
                    }
                    let html = Inline().html(raw.joined(separator: "\n"))
                    if !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        out.append(Block(kind: tag == "!--" ? "div" : tag, html: html))
                    }
                    continue
                }
                if i + 1 < lines.count, let table = table(lines, from: i) {
                    out.append(table.block)
                    i = table.next
                    continue
                }
                // A paragraph: its lines until a blank line or the start of another block, each break a <br>.
                var para: [String] = [trimmed]
                i += 1
                while i < lines.count {
                    let t = lines[i].text
                    let tt = t.trimmingCharacters(in: .whitespaces)
                    if tt.isEmpty || BriefHTML.quoted(t) != nil || BriefHTML.fenceOpen(tt) != nil || BriefHTML.heading(tt) != nil
                        || BriefHTML.isThematicBreak(tt) || BriefHTML.listItem(t) != nil || BriefHTML.htmlBlockTag(tt) != nil { break }
                    para.append(tt)
                    i += 1
                }
                out.append(Block(kind: "p", html: "<p dir=\"auto\">\(Inline().markdown(para.joined(separator: "\n")))</p>"))
            }
            return out
        }

        /// A blockquote, or a callout when its first line is `[!type] Title` (`[!type]-` folded, `[!type|meta]`).
        private func quote(_ inner: [Line]) -> Block {
            guard let first = inner.first, let header = BriefHTML.calloutHeader(first.text.trimmingCharacters(in: .whitespaces)) else {
                return Block(kind: "blockquote", html: "<blockquote dir=\"auto\">\(blocks(inner).map(\.html).joined())</blockquote>")
            }
            let titleText = header.title.isEmpty ? header.type.prefix(1).uppercased() + header.type.dropFirst() : header.title
            let title = Inline().markdown(titleText, breaks: false)
            let content = blocks(Array(inner.dropFirst())).map(\.html).joined()
            var classes = "callout"
            if !header.fold.isEmpty { classes += " is-collapsible" }
            if header.fold == "-" { classes += " is-collapsed" }
            let type = BriefHTML.escape(header.type)
            return Block(kind: "div", html: """
            <div data-callout-metadata="\(BriefHTML.escape(header.metadata))" data-callout-fold="\(header.fold)" data-callout="\(type)" class="\(classes)">\
            <div class="callout-title" dir="auto"><div class="callout-icon"></div><div class="callout-title-inner">\(title)</div></div>\
            <div class="callout-content">\(content)</div></div>
            """)
        }

        /// Fenced code: the hero's clock (Baroque fills it), nothing for other dataview blocks and Tasks queries, which
        /// Obsidian replaces with what they make, and the code itself for anything else.
        private func codeBlock(language: String, code: String) -> Block? {
            switch language {
            case "dataviewjs" where code.contains("brief-date") || code.contains("brief-time"):
                return Block(kind: "div", html: "<div class=\"block-language-dataviewjs\"><span class=\"brief-date\"></span><span class=\"brief-time brief-clock\"></span></div>")
            case "dataview", "dataviewjs", "tasks":
                return nil
            default:
                let lang = language.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
                let cls = lang.isEmpty ? "" : " class=\"language-\(lang)\""
                return Block(kind: "pre", html: "<pre><code\(cls)>\(BriefHTML.escape(code))</code></pre>")
            }
        }

        /// A list from `start`: items at its indentation, with what's indented under each (nested lists, more
        /// paragraphs) and lazy continuation lines. Tasks are Obsidian's task list items.
        private func list(_ lines: [Line], from start: Int) -> (block: Block, next: Int) {
            guard let first = BriefHTML.listItem(lines[start].text) else { return (Block(kind: "p", html: ""), start + 1) }
            struct Item { var line: Line; var body: String; var more: [String] = []; var children: [Line] = []; var column: Int }
            var items: [Item] = [Item(line: lines[start], body: first.body, column: first.column)]
            let base = first.indent
            var i = start + 1
            var blank = false
            while i < lines.count {
                let line = lines[i]
                let trimmed = line.text.trimmingCharacters(in: .whitespaces)
                let indent = BriefHTML.indentWidth(line.text)
                guard var current = items.last else { break }
                if trimmed.isEmpty {
                    // A blank line ends the list unless the list goes on below it.
                    guard let next = lines[(i + 1)...].first(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) else { break }
                    let nextIndent = BriefHTML.indentWidth(next.text)
                    let sibling = BriefHTML.listItem(next.text).map { $0.ordered == first.ordered && nextIndent >= base && nextIndent < current.column } ?? false
                    guard nextIndent >= current.column || sibling else { break }
                    current.children.append(Line(number: line.number, text: ""))
                    items[items.count - 1] = current
                    blank = true
                    i += 1
                    continue
                }
                if indent >= current.column {
                    current.children.append(Line(number: line.number, text: BriefHTML.dropIndent(line.text, current.column)))
                    items[items.count - 1] = current
                } else if let item = BriefHTML.listItem(line.text) {
                    guard item.ordered == first.ordered, indent >= base else { break }
                    items.append(Item(line: line, body: item.body, column: item.column))
                } else if !blank, current.children.isEmpty, BriefHTML.quoted(line.text) == nil, BriefHTML.fenceOpen(trimmed) == nil,
                          BriefHTML.heading(trimmed) == nil, !BriefHTML.isThematicBreak(trimmed), BriefHTML.htmlBlockTag(trimmed) == nil {
                    current.more.append(trimmed)
                    items[items.count - 1] = current
                } else {
                    break
                }
                blank = false
                i += 1
            }
            // Trailing blank lines belong to no item.
            var anyTask = false
            let html = items.map { item -> String in
                var children = item.children
                while children.last?.text.isEmpty == true { children.removeLast() }
                let li = listItem(number: item.line.number, body: item.body, more: item.more, children: children)
                anyTask = anyTask || li.isTask
                return li.html
            }.joined()
            let tag = first.ordered ? "ol" : "ul"
            let startAttr = first.ordered && first.number != 1 ? " start=\"\(first.number)\"" : ""
            let cls = anyTask ? " class=\"contains-task-list\"" : ""
            return (Block(kind: tag, html: "<\(tag)\(cls)\(startAttr)>\(html)</\(tag)>"), i)
        }

        private func listItem(number: Int, body: String, more: [String], children: [Line]) -> (html: String, isTask: Bool) {
            let kids = children.isEmpty ? "" : blocks(children).map(\.html).joined()
            guard let box = BriefHTML.taskBox(body) else {
                let text = Inline().markdown(([body] + more).joined(separator: "\n"))
                return ("<li data-line=\"\(number)\" dir=\"auto\">\(text)\(kids)</li>", false)
            }
            // A task: its state from the page (TaskSync), else as the file has it, with no tap.
            let state = tasks[number] ?? TaskState(done: box.mark != " " && box.mark != "/", enabled: false)
            let mark: String
            if state.done { mark = box.mark == " " || box.mark == "/" ? "x" : box.mark }
            else { mark = box.mark == "/" ? "/" : " " }
            let text = Inline().markdown(BriefHTML.withoutGlobalFilter(([box.rest] + more).joined(separator: "\n")))
            let note = state.note.map {
                "<span class=\"baroque-task-note\(state.problem ? " is-problem" : "")\">\(BriefHTML.escape($0))</span>"
            } ?? ""
            let li = """
            <li data-line="\(number)" data-task="\(BriefHTML.escape(mark))" class="task-list-item\(state.done ? " is-checked" : "")" dir="auto">\
            <input data-line="\(number)" type="checkbox" class="task-list-item-checkbox"\(state.done ? " checked" : "")\(state.enabled ? "" : " disabled")>\
            \(text)\(note)\(kids)</li>
            """
            return (li, true)
        }

        /// A GFM table: a header row, a separator row, then rows until a blank line.
        private func table(_ lines: [Line], from start: Int) -> (block: Block, next: Int)? {
            let header = lines[start].text.trimmingCharacters(in: .whitespaces)
            guard header.contains("|"), let aligns = BriefHTML.tableAlignments(lines[start + 1].text) else { return nil }
            let heads = BriefHTML.tableCells(header)
            guard heads.count == aligns.count else { return nil }
            func row(_ cells: [String], tag: String) -> String {
                "<tr>" + aligns.indices.map { c in
                    let align = aligns[c].map { " style=\"text-align: \($0)\"" } ?? ""
                    return "<\(tag)\(align) dir=\"auto\">\(Inline().markdown(c < cells.count ? cells[c] : "", breaks: false))</\(tag)>"
                }.joined() + "</tr>"
            }
            var body: [String] = []
            var i = start + 2
            while i < lines.count {
                let t = lines[i].text.trimmingCharacters(in: .whitespaces)
                if t.isEmpty || !t.contains("|") { break }
                body.append(row(BriefHTML.tableCells(t), tag: "td"))
                i += 1
            }
            let html = "<table><thead>\(row(heads, tag: "th"))</thead><tbody>\(body.joined())</tbody></table>"
            return (Block(kind: "table", html: html), i)
        }
    }

    // MARK: Block pieces

    /// A line's text inside a blockquote (`> text`), or nil when it isn't one.
    fileprivate static func quoted(_ s: String) -> String? {
        let lead = s.prefix(while: { $0 == " " || $0 == "\t" })
        guard indentWidth(String(lead)) <= 3 else { return nil }
        var rest = s.dropFirst(lead.count)
        guard rest.first == ">" else { return nil }
        rest = rest.dropFirst()
        if rest.first == " " || rest.first == "\t" { rest = rest.dropFirst() }
        return String(rest)
    }

    fileprivate static func indentWidth(_ s: String) -> Int {
        var w = 0
        for c in s {
            if c == " " { w += 1 } else if c == "\t" { w += 4 - w % 4 } else { break }
        }
        return w
    }

    /// The line without its first `columns` columns of indentation (a tab counts to the next multiple of four).
    fileprivate static func dropIndent(_ s: String, _ columns: Int) -> String {
        var w = 0
        var index = s.startIndex
        while index < s.endIndex, w < columns {
            let c = s[index]
            if c == " " { w += 1 } else if c == "\t" { w += 4 - w % 4 } else { break }
            index = s.index(after: index)
        }
        return String(s[index...])
    }

    private static let fenceRegex = regex(#"^(`{3,}|~{3,})[ \t]*(.*)$"#)

    fileprivate static func fenceOpen(_ trimmed: String) -> (char: Character, length: Int, language: String)? {
        guard let g = groups(fenceRegex, trimmed), let run = g[1], let char = run.first else { return nil }
        let info = g[2] ?? ""
        if char == "`", info.contains("`") { return nil }
        let language = info.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "{" }).first.map { $0.lowercased() } ?? ""
        return (char, run.count, language)
    }

    private static let headingRegex = regex(#"^(#{1,6})(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$"#)

    fileprivate static func heading(_ trimmed: String) -> (level: Int, text: String)? {
        guard let g = groups(headingRegex, trimmed), let hashes = g[1] else { return nil }
        return (hashes.count, (g[2] ?? "").trimmingCharacters(in: .whitespaces))
    }

    private static let breakRegex = regex(#"^(?:(?:-[ \t]*){3,}|(?:\*[ \t]*){3,}|(?:_[ \t]*){3,})$"#)

    fileprivate static func isThematicBreak(_ trimmed: String) -> Bool { groups(breakRegex, trimmed) != nil }

    private static let listItemRegex = regex(#"^([ \t]*)([-*+]|(\d{1,9})[.)])(?:([ \t]+)(.*))?$"#)

    /// A list item's marker: its indentation, the column its text starts at (where lines under it must reach to
    /// belong to it), whether it's numbered, and its text.
    fileprivate static func listItem(_ line: String) -> (indent: Int, column: Int, ordered: Bool, number: Int, body: String)? {
        guard !isThematicBreak(line.trimmingCharacters(in: .whitespaces)), let g = groups(listItemRegex, line),
              let lead = g[1], let marker = g[2] else { return nil }
        let indent = indentWidth(lead)
        var end = indent + marker.count
        for c in g[4] ?? "" { end += c == "\t" ? 4 - end % 4 : 1 }
        let gap = end - indent - marker.count
        let column = indent + marker.count + (gap >= 1 && gap <= 4 ? gap : 1)
        let number = g[3].flatMap { Int($0) } ?? 1
        return (indent, column, g[3] != nil, number, g[5] ?? "")
    }

    private static let taskRegex = regex(#"^\[(.)\](?:[ \t]+(.*))?$"#)

    fileprivate static func taskBox(_ body: String) -> (mark: String, rest: String)? {
        guard let g = groups(taskRegex, body), let mark = g[1] else { return nil }
        return (mark, g[2] ?? "")
    }

    private static let globalFilterRegex = regex(#"(?:^|(?<=[ \t]))#todo(?:[ \t]+|$)"#)

    /// The Tasks plugin's global filter, `#todo`, which Obsidian doesn't show on a task.
    fileprivate static func withoutGlobalFilter(_ text: String) -> String {
        globalFilterRegex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
    }

    private static let calloutRegex = regex(#"^\[!([^\]\s|]+)(?:\|([^\]]*))?\]([+-]?)(?:[ \t]+(.*))?$"#)

    fileprivate static func calloutHeader(_ trimmed: String) -> (type: String, metadata: String, fold: String, title: String)? {
        guard let g = groups(calloutRegex, trimmed), let type = g[1] else { return nil }
        return (type.lowercased(), g[2] ?? "", g[3] ?? "", (g[4] ?? "").trimmingCharacters(in: .whitespaces))
    }

    /// Block-level tags that start an HTML block (CommonMark's kinds 1 and 6, and the ones Baroque drops).
    private static let htmlBlockTags: Set<String> = [
        "address", "article", "aside", "base", "blockquote", "body", "caption", "center", "col", "colgroup", "dd", "details",
        "dialog", "div", "dl", "dt", "embed", "fieldset", "figcaption", "figure", "footer", "form", "frame", "frameset",
        "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hgroup", "hr", "html", "iframe", "legend", "li", "link", "main",
        "menu", "meta", "nav", "noscript", "object", "ol", "optgroup", "option", "p", "pre", "script", "search", "section",
        "style", "summary", "table", "tbody", "td", "template", "textarea", "tfoot", "th", "thead", "title", "tr", "ul",
    ]
    private static let htmlBlockRegex = regex(#"^<(?:/?([A-Za-z][A-Za-z0-9-]*)(?:[\s/>]|$)|(!--))"#)

    /// The tag name when a line starts an HTML block ("!--" for a comment).
    fileprivate static func htmlBlockTag(_ trimmed: String) -> String? {
        guard let g = groups(htmlBlockRegex, trimmed) else { return nil }
        if g[2] != nil { return "!--" }
        guard let name = g[1]?.lowercased(), htmlBlockTags.contains(name) else { return nil }
        return name
    }

    /// Script, style, pre, textarea and comments run to their closing tag, blank lines and all.
    fileprivate static func rawHTMLCloser(_ tag: String) -> String? {
        switch tag {
        case "!--": return "-->"
        case "script", "style", "pre", "textarea": return "</\(tag)"
        default: return nil
        }
    }

    fileprivate static func tableCells(_ row: String) -> [String] {
        var t = row.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|"), !t.hasSuffix("\\|") { t.removeLast() }
        var cells: [String] = []
        var cell = ""
        var escaped = false
        for c in t {
            if escaped { cell.append(c); escaped = false; continue }
            if c == "\\" { escaped = true; cell.append(c); continue }
            if c == "|" { cells.append(cell); cell = ""; continue }
            cell.append(c)
        }
        cells.append(cell)
        return cells.map { $0.replacingOccurrences(of: "\\|", with: "|").trimmingCharacters(in: .whitespaces) }
    }

    private static let alignRegex = regex(#"^:?-+:?$"#)

    fileprivate static func tableAlignments(_ row: String) -> [String?]? {
        guard row.contains("-") else { return nil }
        let cells = tableCells(row)
        var out: [String?] = []
        for cell in cells {
            guard groups(alignRegex, cell) != nil else { return nil }
            out.append(cell.hasPrefix(":") && cell.hasSuffix(":") ? "center" : cell.hasSuffix(":") ? "right" : cell.hasPrefix(":") ? "left" : nil)
        }
        return out.isEmpty ? nil : out
    }

    // MARK: Inline Markdown and HTML

    /// One run of inline text: Markdown (or raw HTML) to HTML. What mustn't be touched by later steps (code, links,
    /// tags) is kept aside behind a placeholder, and put back at the end; inline HTML elements left open are closed.
    private final class Inline {
        private var slots: [String] = []
        private var open: [String] = []

        /// Markdown as HTML; `breaks`: each newline is a <br>, as Obsidian shows a single line break.
        func markdown(_ s: String, breaks: Bool = true) -> String {
            restore(pass(s, breaks: breaks)) + closeAll()
        }

        /// An HTML block: the HTML sanitised, with no Markdown in it.
        func html(_ s: String) -> String {
            var t = BriefHTML.withoutDangerousElements(s)
            t = BriefHTML.replace(BriefHTML.htmlTagRegex, in: t) { self.keep(self.tag($0[0] ?? "")) }
            return restore(BriefHTML.escapeText(t)) + closeAll()
        }

        private func keep(_ html: String) -> String {
            slots.append(html)
            return "\u{E000}\(slots.count - 1)\u{E001}"
        }

        private func restore(_ s: String) -> String {
            var t = s
            var rounds = 0
            while t.contains("\u{E000}"), rounds < 8 {
                t = BriefHTML.replace(BriefHTML.slotRegex, in: t) { g in Int(g[1] ?? "").flatMap { $0 < self.slots.count ? self.slots[$0] : nil } ?? "" }
                rounds += 1
            }
            return t
        }

        private func closeAll() -> String {
            let closers = open.reversed().map { "</\($0)>" }.joined()
            open = []
            return closers
        }

        private func pass(_ input: String, breaks: Bool) -> String {
            var s = input
            s = BriefHTML.replace(BriefHTML.backslashRegex, in: s) { self.keep(BriefHTML.escape($0[1] ?? "")) }
            s = BriefHTML.replace(BriefHTML.codeRegex, in: s) { self.keep("<code>\(BriefHTML.escape(BriefHTML.codeText($0[2] ?? "")))</code>") }
            s = BriefHTML.withoutDangerousElements(s)
            s = BriefHTML.replace(BriefHTML.autolinkRegex, in: s) { self.keep(self.link(url: $0[1] ?? "", text: nil)) }
            s = BriefHTML.replace(BriefHTML.htmlTagRegex, in: s) { self.keep(self.tag($0[0] ?? "")) }
            s = BriefHTML.replace(BriefHTML.wikiRegex, in: s) { self.keep(self.wiki($0[2] ?? "")) }
            s = BriefHTML.replace(BriefHTML.imageRegex, in: s) { self.keep(self.image(alt: $0[1] ?? "", url: $0[2] ?? "")) }
            s = BriefHTML.replace(BriefHTML.linkRegex, in: s) { self.keep(self.link(url: $0[2] ?? "", text: $0[1] ?? "")) }
            s = BriefHTML.replace(BriefHTML.bareURLRegex, in: s) { g in
                let (url, trailing) = BriefHTML.trimmedURL(g[1] ?? "")
                return self.keep(self.link(url: url, text: nil)) + trailing
            }
            s = BriefHTML.replace(BriefHTML.tagRegex, in: s) { g in
                let tag = g[1] ?? ""
                return self.keep("<a href=\"#\(BriefHTML.escape(tag))\" class=\"tag\">#\(BriefHTML.escape(tag))</a>")
            }
            s = BriefHTML.escapeText(s)
            s = BriefHTML.emphasis(s)
            if breaks { s = s.replacingOccurrences(of: "\n", with: "<br>\n") }
            return s
        }

        /// `[text](url)`, `<https://…>` or a bare URL: a web link opens in Safari, a vault path in Obsidian, and
        /// anything else (`javascript:`, `data:`) is just its text.
        private func link(url raw: String, text: String?) -> String {
            var url = raw.trimmingCharacters(in: .whitespaces)
            if url.hasPrefix("<"), url.hasSuffix(">") { url = String(url.dropFirst().dropLast()) }
            let label = text.map { pass($0, breaks: false) } ?? BriefHTML.escape(url)
            switch BriefHTML.linkTarget(BriefHTML.decodeEntities(url)) {
            case .external(let href)?:
                return "<a class=\"external-link\" href=\"\(BriefHTML.escape(href))\" rel=\"noopener nofollow\">\(label)</a>"
            case .internal(let path)?:
                return "<a data-href=\"\(BriefHTML.escape(path))\" href=\"\(BriefHTML.escape(path))\" class=\"internal-link\">\(label)</a>"
            case nil:
                return label
            }
        }

        /// `![alt](https://…)`; `![alt|300](…)` sets its width as Obsidian does. A picture that isn't on the web
        /// shows its alt text.
        private func image(alt raw: String, url: String) -> String {
            var alt = raw
            var width = ""
            if let bar = raw.lastIndex(of: "|"), let w = Int(raw[raw.index(after: bar)...].split(separator: "x").first ?? "") {
                alt = String(raw[..<bar])
                width = " width=\"\(w)\""
            }
            var address = url.trimmingCharacters(in: .whitespaces)
            if address.hasPrefix("<"), address.hasSuffix(">") { address = String(address.dropFirst().dropLast()) }
            guard let src = BriefHTML.imageSource(BriefHTML.decodeEntities(address)) else { return BriefHTML.escape(alt) }
            return "<img alt=\"\(BriefHTML.escape(alt))\" src=\"\(BriefHTML.escape(src))\"\(width)>"
        }

        /// `[[path|alias]]`, `[[path#heading]]`, `![[embed]]`: a link to the note, opened in Obsidian; it reads as the
        /// alias, else the note's name.
        private func wiki(_ inner: String) -> String {
            let parts = inner.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            let target = parts[0]
            let alias = parts.count > 1 && !parts[1].isEmpty && Int(parts[1]) == nil ? parts[1] : nil
            let file = String(target.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
            var name = String(file.split(separator: "/").last ?? Substring(file))
            if name.lowercased().hasSuffix(".md") { name = String(name.dropLast(3)) }
            if let hash = target.firstIndex(of: "#") {
                let sub = target[target.index(after: hash)...].trimmingCharacters(in: CharacterSet(charactersIn: "#^ "))
                name = name.isEmpty ? sub : "\(name) > \(sub)"
            }
            let label = alias ?? (name.isEmpty ? target : name)
            return "<a data-href=\"\(BriefHTML.escape(target))\" href=\"\(BriefHTML.escape(target))\" class=\"internal-link\">\(BriefHTML.escape(label))</a>"
        }

        /// An inline HTML tag, sanitised: allowed tags keep only safe attributes, dropped ones go, unknown ones show as
        /// text, and a closing tag closes only what's open here.
        func tag(_ raw: String) -> String {
            guard let g = BriefHTML.groups(BriefHTML.tagPartsRegex, raw), let rawName = g[2] else { return BriefHTML.escape(raw) }
            let name = rawName.lowercased()
            if BriefHTML.droppedTags.contains(name) { return "" }
            guard BriefHTML.allowedTags.contains(name) else { return BriefHTML.escape(raw) }
            if g[1] == "/" {
                guard let at = open.lastIndex(of: name) else { return "" }
                let closers = open[at...].reversed().map { "</\($0)>" }.joined()
                open.removeSubrange(at...)
                return closers
            }
            guard let attributes = BriefHTML.attributes(g[3] ?? "", tag: name) else { return "" }
            if BriefHTML.voidTags.contains(name) { return "<\(name)\(attributes)>" }
            if raw.hasSuffix("/>") { return "<\(name)\(attributes)></\(name)>" }
            open.append(name)
            return "<\(name)\(attributes)>"
        }
    }

    // MARK: Sanitising

    /// Tags kept from the note's HTML.
    private static let allowedTags: Set<String> = [
        "a", "abbr", "address", "article", "aside", "b", "bdi", "bdo", "blockquote", "br", "caption", "center", "cite", "code",
        "col", "colgroup", "dd", "del", "details", "dfn", "div", "dl", "dt", "em", "figcaption", "figure", "font", "footer",
        "h1", "h2", "h3", "h4", "h5", "h6", "header", "hgroup", "hr", "i", "img", "ins", "kbd", "li", "main", "mark", "nav",
        "ol", "p", "pre", "q", "rp", "rt", "ruby", "s", "samp", "section", "small", "span", "strike", "strong", "sub",
        "summary", "sup", "table", "tbody", "td", "tfoot", "th", "thead", "time", "tr", "tt", "u", "ul", "var", "wbr",
    ]
    /// Tags dropped (their content too, for the first group: `withoutDangerousElements`).
    private static let contentDroppedTags = [
        "script", "style", "iframe", "object", "noscript", "template", "textarea", "title", "applet", "svg", "math", "select",
        "button", "frameset", "xmp", "noembed", "noframes", "plaintext",
    ]
    private static let droppedTags: Set<String> = Set(contentDroppedTags).union([
        "embed", "input", "link", "meta", "base", "frame", "param", "source", "track", "keygen", "form", "label", "html", "head",
        "body", "canvas", "audio", "video", "picture", "portal", "slot", "dialog", "option", "optgroup", "area", "map",
        "image", "fieldset", "legend", "output", "datalist", "progress", "meter",
    ])
    private static let voidTags: Set<String> = ["br", "hr", "img", "wbr", "col"]
    private static let allowedAttributes: Set<String> = [
        "class", "id", "title", "alt", "width", "height", "align", "valign", "colspan", "rowspan", "dir", "lang", "start",
        "reversed", "open", "datetime", "color", "face", "size", "role", "style",
    ]

    private static let dangerousRegex = NSRegularExpression.make(
        "<(\(contentDroppedTags.joined(separator: "|")))\\b[^>]*>.*?(?:</\\1\\s*>|$)", options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let commentRegex = NSRegularExpression.make(#"<!--.*?(?:-->|$)"#, options: [.dotMatchesLineSeparators])

    /// Scripts, styles, frames and the like, from their opening tag through their closing one (or the end); and
    /// HTML comments.
    fileprivate static func withoutDangerousElements(_ s: String) -> String {
        guard s.contains("<") else { return s }
        let ns = s as NSString
        let t = dangerousRegex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: ns.length), withTemplate: "")
        return commentRegex.stringByReplacingMatches(in: t, range: NSRange(location: 0, length: (t as NSString).length), withTemplate: "")
    }

    private static let attributeRegex = regex(#"([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?"#)

    /// A tag's attributes, kept only when they're safe: no `on…` handlers, links only to the web, mail or a vault
    /// path, pictures only from the web. Nil for a picture with no usable source.
    fileprivate static func attributes(_ text: String, tag: String) -> String? {
        var out: [(name: String, value: String?)] = []
        var classes: [String] = []
        var source = false
        let ns = text as NSString
        for m in attributeRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            func group(_ i: Int) -> String? { m.range(at: i).location == NSNotFound ? nil : ns.substring(with: m.range(at: i)) }
            let name = (group(1) ?? "").lowercased()
            let value = (group(2) ?? group(3) ?? group(4)).map(decodeEntities)
            if name.hasPrefix("on") { continue }
            switch name {
            case "href":
                guard tag == "a", let value else { continue }
                switch linkTarget(value) {
                case .external(let href)?:
                    out.append(("href", href))
                    classes.append("external-link")
                case .internal(let path)?:
                    out.append(("data-href", path))
                    out.append(("href", path))
                    classes.append("internal-link")
                case nil:
                    continue
                }
            case "src":
                guard tag == "img", let value, let src = imageSource(value) else { continue }
                out.append(("src", src))
                source = true
            case "class":
                if let value { classes.insert(contentsOf: value.split(separator: " ").map(String.init), at: 0) }
            case "style":
                guard let value else { continue }
                let lower = value.lowercased()
                if lower.contains("javascript") || lower.contains("expression") || lower.contains("url(") || lower.contains("@import") { continue }
                out.append((name, value))
            default:
                guard allowedAttributes.contains(name) || name.hasPrefix("data-") || name.hasPrefix("aria-"),
                      name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { continue }
                out.append((name, value))
            }
        }
        if tag == "img", !source { return nil }
        if !classes.isEmpty { out.insert(("class", classes.joined(separator: " ")), at: 0) }
        var seen = Set<String>()
        return out.filter { seen.insert($0.name).inserted }.map { " \($0.name)" + ($0.value.map { "=\"\(escape($0))\"" } ?? "") }.joined()
    }

    enum LinkTarget: Equatable {
        case external(String)
        case `internal`(String)
    }

    /// Where a link goes: the web, mail, a phone number or Obsidian; or a path in the vault. Nil for anything else
    /// (`javascript:`, `data:`, `file:`), read the way a browser reads it, ignoring spaces and control characters.
    static func linkTarget(_ raw: String) -> LinkTarget? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("#") else { return nil }
        if let scheme = scheme(of: value) {
            return ["http", "https", "mailto", "tel", "obsidian"].contains(scheme) ? .external(value) : nil
        }
        let compact = String(String.UnicodeScalarView(value.unicodeScalars.filter { $0.value > 0x20 && $0.value != 0x7F }))
        if compact.hasPrefix("//") || compact.hasPrefix("\\") { return nil }
        return .internal(value.removingPercentEncoding ?? value)
    }

    /// A picture's address: the web (https) or an embedded image.
    static func imageSource(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch scheme(of: value) {
        case "https"?: return value
        case "data"?:
            let lower = value.lowercased()
            return ["data:image/png", "data:image/jpeg", "data:image/gif", "data:image/webp"].contains(where: lower.hasPrefix) ? value : nil
        default: return nil
        }
    }

    /// The scheme, lowercased, as a browser finds it: whitespace and control characters don't count.
    static func scheme(of value: String) -> String? {
        let compact = String(String.UnicodeScalarView(value.unicodeScalars.filter { $0.value > 0x20 && $0.value != 0x7F }))
        guard let colon = compact.firstIndex(of: ":") else { return nil }
        let head = compact[..<colon]
        guard let first = head.first, first.isASCII, first.isLetter,
              head.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "+-.".contains($0)) }) else { return nil }
        return head.lowercased()
    }

    private static let entityRegex = NSRegularExpression.make(
        #"&(?:#([0-9]{1,7})|#[xX]([0-9A-Fa-f]{1,6})|(amp|lt|gt|quot|apos|nbsp|colon|tab|newline));?"#, options: [.caseInsensitive])

    /// HTML character references, as a browser decodes them in an attribute (numeric ones with or without the `;`).
    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        let named: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
                                       "colon": ":", "tab": "\t", "newline": "\n"]
        return replace(entityRegex, in: s) { g in
            if let dec = g[1].flatMap({ UInt32($0) }) { return Unicode.Scalar(dec).map { String($0) } ?? "\u{FFFD}" }
            if let hex = g[2].flatMap({ UInt32($0, radix: 16) }) { return Unicode.Scalar(hex).map { String($0) } ?? "\u{FFFD}" }
            return g[3].flatMap { named[$0.lowercased()] } ?? (g[0] ?? "")
        }
    }

    /// Text for HTML: `&`, `<`, `>` and `"` escaped.
    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let bareAmpersandRegex = regex(#"&(?!#[0-9]{1,7};|#[xX][0-9A-Fa-f]{1,6};|[A-Za-z][A-Za-z0-9]{1,31};)"#)

    /// The note's text for HTML: like `escape`, but an entity the note wrote (`&mdash;`) is kept.
    fileprivate static func escapeText(_ s: String) -> String {
        let amp = bareAmpersandRegex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "&amp;")
        return amp.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: Inline patterns

    private static let slotRegex = regex("\u{E000}([0-9]+)\u{E001}")
    private static let backslashRegex = regex(##"\\([!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~])"##)
    private static let codeRegex = NSRegularExpression.make(#"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)"#, options: [.dotMatchesLineSeparators])
    private static let autolinkRegex = regex(#"<((?:https?|mailto):[^\s<>]+)>"#)
    fileprivate static let htmlTagRegex = regex(#"</?[A-Za-z][A-Za-z0-9-]*(?:\s+[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*\s*/?>"#)
    private static let tagPartsRegex = NSRegularExpression.make(#"^<(/?)([A-Za-z][A-Za-z0-9-]*)(.*?)/?>$"#, options: [.dotMatchesLineSeparators])
    private static let wikiRegex = regex(#"(!?)\[\[([^\[\]\n]+?)\]\]"#)
    private static let imageRegex = regex(#"!\[([^\]\n]*)\]\(\s*(<[^>\n]*>|[^\s()]+)(?:\s+(?:"[^"]*"|'[^']*'))?\s*\)"#)
    private static let linkRegex = regex(#"\[((?:[^\[\]\n]|\[[^\[\]\n]*\])*)\]\(\s*(<[^>\n]*>|(?:[^()\s]|\([^()\s]*\))*)(?:\s+(?:"[^"]*"|'[^']*'))?\s*\)"#)
    private static let bareURLRegex = regex("(?<![\\w/@:=\"'])(https?://[^\\s<>\"\u{E000}\u{E001}]+)")
    private static let tagRegex = regex(#"(?<![^\s(])#([\p{L}\p{N}\p{M}_/\-]*[\p{L}\p{M}_/\-][\p{L}\p{N}\p{M}_/\-]*)"#)

    /// A bare URL without the punctuation after it (a full stop ending the sentence), which comes back as text.
    fileprivate static func trimmedURL(_ url: String) -> (url: String, trailing: String) {
        var u = url
        var trailing = ""
        while let last = u.last, ".,:;!?'\"*_~".contains(last) || (last == ")" && u.filter({ $0 == "(" }).count < u.filter({ $0 == ")" }).count) {
            trailing.insert(last, at: trailing.startIndex)
            u.removeLast()
        }
        return (u, trailing)
    }

    fileprivate static func codeText(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "\n", with: " ")
        if t.count >= 2, t.hasPrefix(" "), t.hasSuffix(" "), !t.allSatisfy({ $0 == " " }) { t = String(t.dropFirst().dropLast()) }
        return t
    }

    private static let emphasisRules: [(NSRegularExpression, String)] = [
        (regex(#"\*\*\*(?=\S)(.+?)(?<=\S)\*\*\*"#), "<em><strong>$1</strong></em>"),
        (regex(#"\*\*(?=\S)(.+?)(?<=\S)\*\*"#), "<strong>$1</strong>"),
        (regex(#"(?<![\p{L}\p{N}_])__(?=\S)(.+?)(?<=\S)__(?![\p{L}\p{N}_])"#), "<strong>$1</strong>"),
        (regex(#"(?<!\*)\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?!\*)"#), "<em>$1</em>"),
        (regex(#"(?<![\p{L}\p{N}_])_(?=[^\s_])(.+?)(?<=[^\s_])_(?![\p{L}\p{N}_])"#), "<em>$1</em>"),
        (regex(#"~~(?=\S)(.+?)(?<=\S)~~"#), "<del>$1</del>"),
        (regex(#"==(?=\S)(.+?)(?<=\S)=="#), "<mark>$1</mark>"),
    ]

    fileprivate static func emphasis(_ s: String) -> String {
        guard s.contains("*") || s.contains("_") || s.contains("~") || s.contains("=") else { return s }
        return MarkdownText.apply(emphasisRules, to: s)
    }

    // MARK: Regex helpers

    private static func regex(_ pattern: String) -> NSRegularExpression { NSRegularExpression.make(pattern, options: []) }

    fileprivate static func groups(_ r: NSRegularExpression, _ s: String) -> [String?]? {
        let ns = s as NSString
        guard let m = r.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { i in m.range(at: i).location == NSNotFound ? nil : ns.substring(with: m.range(at: i)) }
    }

    fileprivate static func replace(_ r: NSRegularExpression, in s: String, transform: ([String?]) -> String) -> String {
        MarkdownText.replace(r, in: s, transform: transform)
    }
}

private extension NSRegularExpression {
    /// Patterns are compile-time constants; a bad one is a programming error that the tests catch.
    static func make(_ pattern: String, options: NSRegularExpression.Options) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: options)
    }
}

// MARK: - Baroque's own sheets and script

extension BriefHTML {
    /// Baroque's stand-in for Obsidian's own reading-view styles. The vault's CSS comes after it and wins.
    static let baseCSS = #"""
    :root {
      --font-default: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Helvetica, sans-serif;
      --font-text: var(--font-default);
      --font-interface: var(--font-default);
      --font-monospace: ui-monospace, Menlo, monospace;
      --font-text-size: 16px;
      --line-height-normal: 1.5;
      --line-height-tight: 1.3;
      --file-line-width: 700px;
      --background-primary: #fbf7f0;
      --text-normal: #2e2820;
      --text-muted: #6e6455;
      --text-faint: #8c8170;
      --link-color: #6b5a3a;
      --link-external-color: #6b5a3a;
      --tag-color: #6e6455;
      --tag-background: rgba(120, 90, 40, 0.08);
      --hr-color: rgba(120, 90, 40, 0.22);
      --code-background: rgba(120, 90, 40, 0.07);
      --checkbox-border-color: rgba(90, 70, 40, 0.45);
      --baroque-tick: #a6e3a1;
      --baroque-problem: #713620;
      --p-spacing: 1rem;
    }
    html { background: var(--background-primary); -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }
    body { margin: 0; background: var(--background-primary); color: var(--text-normal); font-family: var(--font-interface); -webkit-font-smoothing: antialiased; }
    .markdown-preview-view {
      box-sizing: border-box; min-height: 100vh; padding: 18px 16px 28px;
      font-family: var(--font-text); font-size: var(--font-text-size); line-height: var(--line-height-normal);
      color: var(--text-normal); background-color: var(--background-primary);
      overflow-wrap: break-word; -webkit-tap-highlight-color: transparent;
    }
    @media (min-width: 701px) { .markdown-preview-view { padding: 36px 4.75rem 40px; } }
    .markdown-preview-sizer { max-width: var(--file-line-width); margin: 0 auto; }
    .markdown-rendered p { margin-block: var(--p-spacing); }
    .markdown-rendered h1, .markdown-rendered h2, .markdown-rendered h3,
    .markdown-rendered h4, .markdown-rendered h5, .markdown-rendered h6 { font-weight: 700; line-height: var(--line-height-tight); margin: 1.4em 0 0.5em; }
    .markdown-rendered h1 { font-size: 1.75em; } .markdown-rendered h2 { font-size: 1.45em; } .markdown-rendered h3 { font-size: 1.25em; }
    .markdown-rendered h4 { font-size: 1.1em; } .markdown-rendered h5 { font-size: 1em; } .markdown-rendered h6 { font-size: 0.9em; }
    .markdown-rendered ul, .markdown-rendered ol { margin-block: 0.5em; padding-inline-start: 1.6em; }
    .markdown-rendered li { margin-block: 0.15em; }
    .markdown-rendered li > ul, .markdown-rendered li > ol { margin-block: 0.1em; }
    .markdown-rendered ul.contains-task-list, .markdown-rendered li.task-list-item { list-style: none; }
    .markdown-rendered a { color: var(--link-color); text-decoration: underline; text-underline-offset: 0.12em; }
    .markdown-rendered a.external-link { color: var(--link-external-color); }
    .markdown-rendered a.tag { color: var(--tag-color); background: var(--tag-background); border-radius: 2em; padding: 0.1em 0.55em; font-size: 0.85em; text-decoration: none; white-space: nowrap; }
    .markdown-rendered small { font-size: 0.85em; }
    .markdown-rendered img { max-width: 100%; height: auto; border-radius: 4px; }
    .markdown-rendered hr { border: none; border-top: 1px solid var(--hr-color); margin: 2em 0; }
    .markdown-rendered code { font-family: var(--font-monospace); font-size: 0.875em; background: var(--code-background); border-radius: 4px; padding: 0.1em 0.3em; }
    .markdown-rendered pre { font-family: var(--font-monospace); font-size: 0.85em; background: var(--code-background); border-radius: 6px; padding: 0.8em 1em; overflow-x: auto; white-space: pre; }
    .markdown-rendered pre code { background: none; padding: 0; font-size: inherit; }
    .markdown-rendered blockquote { margin: 1em 0; padding-inline-start: 1em; border-inline-start: 2px solid var(--hr-color); color: var(--text-muted); }
    .markdown-rendered table { border-collapse: collapse; margin: 1em 0; }
    .markdown-rendered th, .markdown-rendered td { border: 1px solid var(--hr-color); padding: 0.3em 0.6em; }
    .markdown-rendered mark { background: rgba(245, 212, 0, 0.35); color: inherit; }

    /* Callouts */
    .callout { position: relative; margin: 1em 0; padding: 12px 16px; border-radius: 8px; background: rgba(120, 90, 40, 0.06); border: 1px solid rgba(120, 90, 40, 0.14); overflow: hidden; }
    .callout-title { display: flex; gap: 6px; align-items: flex-start; line-height: var(--line-height-tight); }
    .callout-icon:empty { display: none; }
    .callout-title-inner { font-weight: 600; }
    .callout-content { overflow-x: auto; }
    .callout.is-collapsible > .callout-title { cursor: pointer; }
    .callout.is-collapsed > .callout-content { display: none; }

    /* Task checkboxes as the vault's theme draws them: a rounded square about the size of the text (as in the brief
       in Obsidian), ticked soft green with a white check. A form control doesn't take the text's size unless told. */
    .markdown-rendered input.task-list-item-checkbox {
      -webkit-appearance: none; appearance: none; box-sizing: border-box; font-size: inherit;
      width: 1.05em; height: 1.05em; margin: 0 0.45em 0 -1.5em; padding: 0; vertical-align: -0.15em;
      border: 1.5px solid var(--checkbox-border-color); border-radius: 0.22em; background-color: transparent; cursor: pointer;
    }
    .markdown-rendered input.task-list-item-checkbox:checked {
      border-color: var(--baroque-tick); background-color: var(--baroque-tick);
      background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 14 14'%3E%3Cpath d='M3.2 7.3l2.5 2.5 5.1-5.3' fill='none' stroke='white' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
      background-repeat: no-repeat; background-position: center; background-size: 80%;
    }
    .markdown-rendered input.task-list-item-checkbox:disabled { cursor: default; opacity: 0.55; }
    .markdown-rendered li.task-list-item.is-checked { text-decoration: line-through; color: var(--text-faint); }

    /* Baroque's own: the line under a task while its tick is saved (inline-block, so a ticked task's line-through
       doesn't strike it), and the stamp at the foot. */
    .baroque-task-note { display: inline-block; width: 100%; margin-top: 0.2em; font-family: var(--font-monospace); font-size: 0.72rem; line-height: 1.5; color: var(--text-muted); text-decoration: none; }
    .baroque-task-note.is-problem { color: var(--baroque-problem); }
    .baroque-stamp { margin: 1.6rem 0 0.4rem; font-family: var(--font-monospace); font-size: 0.66rem; letter-spacing: 0.06em; line-height: 1.6; color: var(--text-muted); text-align: center; }
    """#

    /// The look when the vault's CSS can't be had (offline on the first run, or no snippet): a plain cream page and
    /// cards, Baroque's own.
    static let fallbackCSS = #"""
    .markdown-preview-view { background-color: #fbf6ec; }
    .markdown-preview-sizer { max-width: 760px; }
    .callout { background: #f6eedf; border: 1px solid rgba(110, 85, 45, 0.16); border-radius: 14px; padding: 14px 16px; margin: 0.9rem 0; }
    .callout-title-inner { font-family: Georgia, "Times New Roman", serif; font-style: italic; font-weight: 400; font-size: 1.35rem; }
    .callout-content { margin-top: 0.4rem; }
    .callout-content > :first-child { margin-top: 0; }
    .callout-content > :last-child { margin-bottom: 0; }
    .callout-content img { display: block; width: 100%; border-radius: 10px; }
    .callout ul { padding-inline-start: 1.3em; }
    .callout ul.contains-task-list { padding-inline-start: 1.7em; }
    .callout small { display: block; font-family: var(--font-monospace); font-size: 0.72rem; color: var(--text-muted); }
    .block-language-dataviewjs span { font-family: Georgia, serif; font-style: italic; margin-right: 0.8em; color: var(--text-muted); }
    """#

    /// Baroque's script, the only one the page runs: the hero's date and clock (as the brief's own dataviewjs block
    /// writes them: en-GB date, en-US 12-hour time, each character in its slot, every second), taps on checkboxes and
    /// links (handed to the app), folding callouts, and the page's hooks for the app (`baroque.update` and the rest).
    static let script = #"""
    (() => {
      "use strict";
      const post = (message) => { try { window.webkit.messageHandlers.brief.postMessage(message); } catch (_) {} };
      const slots = (el, s) => el.replaceChildren(...Array.from(s, (c) => Object.assign(document.createElement("span"), { className: /\d/.test(c) ? "d" : "s", textContent: c })));
      const tick = () => {
        const now = new Date();
        const date = now.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }).toUpperCase();
        const time = now.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: true });
        document.querySelectorAll(".brief-date").forEach((el) => slots(el, date));
        document.querySelectorAll(".brief-time").forEach((el) => slots(el, time));
      };
      tick();
      setInterval(tick, 1000);
      // The rubber band above and below the page in the page's own colour.
      const view = document.querySelector(".markdown-preview-view");
      if (view) {
        const ground = getComputedStyle(view).backgroundColor;
        if (ground && ground !== "rgba(0, 0, 0, 0)") { document.documentElement.style.backgroundColor = ground; document.body.style.backgroundColor = ground; }
      }
      document.addEventListener("click", (event) => {
        const target = event.target instanceof Element ? event.target : null;
        if (!target) return;
        const title = target.closest(".callout.is-collapsible > .callout-title");
        if (title) { title.parentElement.classList.toggle("is-collapsed"); return; }
        const link = target.closest("a");
        if (!link) return;
        event.preventDefault();
        if (link.classList.contains("internal-link")) post({ kind: "internal", path: link.getAttribute("data-href") || "" });
        else if (!link.classList.contains("tag")) post({ kind: "external", href: link.getAttribute("href") || "" });
      });
      document.addEventListener("change", (event) => {
        const box = event.target;
        if (!(box instanceof HTMLInputElement) || !box.classList.contains("task-list-item-checkbox")) return;
        const item = box.closest("li.task-list-item");
        const line = parseInt(box.getAttribute("data-line") || "", 10);
        if (!item || !Number.isFinite(line)) return;
        item.classList.toggle("is-checked", box.checked);
        item.setAttribute("data-task", box.checked ? "x" : " ");
        post({ kind: "tick", line: line, done: box.checked });
      });
      const sizer = () => document.querySelector(".markdown-preview-sizer");
      window.baroque = {
        // The app's new blocks: only the changed ones are swapped when the count is the same.
        update(blocks, changed) {
          const s = sizer();
          if (!s) return false;
          if (changed && s.children.length === blocks.length) {
            for (const i of changed) {
              const t = document.createElement("template");
              t.innerHTML = blocks[i];
              s.children[i].replaceWith(t.content);
            }
          } else {
            s.innerHTML = blocks.join("\n");
          }
          tick();
          return true;
        },
        scroll(y) { window.scrollTo(0, y); return window.scrollY; },
        height() { return Math.ceil(document.documentElement.scrollHeight); },
        tap(line) {
          const box = document.querySelector('input.task-list-item-checkbox[data-line="' + line + '"]');
          if (!box || box.disabled) return false;
          box.click();
          return true;
        }
      };
    })();
    """#
}
