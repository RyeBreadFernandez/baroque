import Foundation

// Parses Obsidian Tasks-plugin style checkboxes:
//   - [ ] #todo Buy coffee ⏫ 📅 2026-05-30
// Metadata may appear in any order (`📅 2026-05-30 ⏫` is as valid as `⏫ 📅 2026-05-30`),
// emoji may carry a U+FE0F variation selector, and lines inside fenced code blocks
// (for example a ```tasks query), %% comments %% and frontmatter are ignored.
enum TaskParser {
    /// Tasks due within this many days after today rank above undated tasks that are not 🔺 / ⏫,
    /// and tasks due later than that come last.
    static let soonWindowDays = 3

    static func parse(markdown: String, sourcePath: String) -> [TaskItem] {
        var items: [TaskItem] = []
        for line in MarkdownText.visibleLines(of: markdown) {
            guard let body = openTaskBody(line.text) else { continue }
            let meta = extractMetadata(body)
            let text = cleanInline(meta.text)
            guard !text.isEmpty else { continue }
            items.append(TaskItem(text: text, due: meta.due, priority: meta.priority, sourcePath: sourcePath, lineNumber: line.number,
                                  repeats: meta.repeats))
        }
        return items
    }

    // MARK: Checkbox line

    // Indent (spaces, tabs, callout `>`), a list marker (- * + or 1. / 1)), then `[c]`.
    private static let checkboxRegex = MarkdownText.regex(#"^[\s>]*(?:[-*+]|\d{1,9}[.)])[ \t]+\[(.)\][ \t]*(.*)$"#)

    // Status characters that mean "still to do": space (todo) and / (in progress).
    // x / X (done), - (cancelled) and other custom statuses are skipped.
    private static let openStatuses: Set<String> = [" ", "/"]

    /// The text after the checkbox if `line` is an open task, otherwise nil.
    private static func openTaskBody(_ line: String) -> String? {
        let ns = line as NSString
        guard let m = checkboxRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        guard openStatuses.contains(ns.substring(with: m.range(at: 1))) else { return nil }
        return ns.substring(with: m.range(at: 2))
    }

    // MARK: Tasks-plugin metadata

    private static let dueMarkers: Set<String> = ["📅", "📆", "🗓"]
    private static let priorityMarkers: [String: TaskPriority] = ["🔺": .highest, "⏫": .high, "🔼": .medium, "🔽": .low, "⏬": .lowest]

    // One pass over the whole body, so each marker's payload is bounded by the next marker
    // wherever it sits. Groups: 1 = date marker, 2 = its date, 3 = priority marker.
    private static let metadataRegex = MarkdownText.regex(
        "(📅|📆|🗓|⏳|⌛|🛫|➕|✅|❌)\\x{FE0F}?[ \\t]*(\\d{4}-\\d{2}-\\d{2})?"   // dates: due, scheduled, start, created, done, cancelled
        + "|(🔺|⏫|🔼|🔽|⏬)\\x{FE0F}?"                                      // priority
        + "|🔁\\x{FE0F}?[ \\t]*[a-zA-Z0-9, !]*"                               // recurrence: "every week on Monday"
        + "|🆔\\x{FE0F}?[ \\t]*[a-zA-Z0-9_-]*"                                 // id
        + "|⛔\\x{FE0F}?[ \\t]*(?:[a-zA-Z0-9_-]+(?:[ \\t]*,[ \\t]*[a-zA-Z0-9_-]+)*)?" // depends on
        + "|🏁\\x{FE0F}?[ \\t]*[a-zA-Z]*"                                      // on completion
    )

    private static func extractMetadata(_ body: String) -> (text: String, due: Date?, priority: TaskPriority, repeats: Bool) {
        var due: Date?
        var priority: TaskPriority?
        var repeats = false
        let ns = body as NSString
        var text = ""
        var cursor = 0
        for m in metadataRegex.matches(in: body, range: NSRange(location: 0, length: ns.length)) {
            text += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor)) + " "
            cursor = m.range.location + m.range.length
            // By scalar, since 🔁 with a variation selector is another Character.
            if ns.substring(with: m.range).unicodeScalars.first == "\u{1F501}" { repeats = true }
            if m.range(at: 1).location != NSNotFound,
               dueMarkers.contains(ns.substring(with: m.range(at: 1))),
               m.range(at: 2).location != NSNotFound,
               due == nil {
                due = parseDate(ns.substring(with: m.range(at: 2)))
            }
            if m.range(at: 3).location != NSNotFound, priority == nil {
                priority = priorityMarkers[ns.substring(with: m.range(at: 3))]
            }
        }
        text += ns.substring(from: cursor)
        return (text, due, priority ?? TaskPriority.none, repeats)
    }

    /// `yyyy-MM-dd` as the start of that day in the local time zone. Rejects impossible dates
    /// such as 2026-02-30, and still works on days whose midnight is skipped by DST.
    static func parseDate(_ s: String) -> Date? {
        let parts = s.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let comps = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = cal.date(from: comps) else { return nil }
        let back = cal.dateComponents([.year, .month, .day], from: date)
        guard back.year == parts[0], back.month == parts[1], back.day == parts[2] else { return nil }
        return cal.startOfDay(for: date)
    }

    // MARK: Inline markdown

    /// Turns a line of Obsidian markdown into plain display text: tags, embeds, comments and
    /// block IDs are removed; wiki links, markdown links and emphasis keep their visible text;
    /// bare URLs shrink to their host.
    static func cleanInline(_ s: String) -> String {
        var out = MarkdownText.protectEscapes(s)
        out = MarkdownText.apply(beforeWikiLinks, to: out)
        out = MarkdownText.replace(wikiLinkRegex, in: out) { groups in wikiLinkText(groups[1] ?? "") }
        out = MarkdownText.apply(afterWikiLinks, to: out)
        out = out.replacingOccurrences(of: "**", with: "")
        out = MarkdownText.apply([(trailingBlockID, "$1")], to: out)
        out = MarkdownText.restoreEscapes(out)
        out = MarkdownText.apply([(whitespaceRun, " ")], to: out)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let beforeWikiLinks = MarkdownText.rules([
        (#"%%.*?%%"#, " "),                                                                     // %% comments %%
        (#"!\[\[[^\]]*\]\]"#, " "),                                                            // ![[embed.png]]
        (#"!\[[^\]]*\]\((?:<[^>]*>|(?:[^()\s]|\([^()\s]*\))*)(?:\s+"[^"]*")?\)"#, " "),        // ![alt](image)
    ])
    // [[Note]], [[Note|Alias]], [[Note#Heading]], [[#Heading]], [[Note#^block]]
    private static let wikiLinkRegex = MarkdownText.regex(#"\[\[([^\]]+)\]\]"#)
    private static let afterWikiLinks = MarkdownText.rules([
        (#"\[([^\[\]]*)\]\((?:<[^>]*>|(?:[^()\s]|\([^()\s]*\))*)(?:\s+"[^"]*")?\)"#, "$1"),    // [text](url "title")
        (#"\[\^[^\]]+\]"#, ""),                                                                 // footnote refs [^1]
        (#"<(https?://[^>\s]+)>"#, "$1"),                                                       // <https://autolink>
        (#"https?://(?:www\.)?([^/\s?#)>]+)\S*"#, "$1"),                                        // bare URL -> host
        (#"</?[A-Za-z][A-Za-z0-9-]*(?:\s[^<>]*)?/?>"#, " "),                                    // <br>, <span ...>, </b>
        // #tags and #nested/tags. Obsidian tags need a non-digit, so "issue #3" stays; so does C#.
        (#"(^|\s)#(?!\d+(?![\w/-]))[\w/-]+"#, "$1"),
        (#"(`+)(.+?)\1"#, "$2"),                                                                // `code`
        (#"\*\*\*(?=\S)(.+?)(?<=\S)\*\*\*"#, "$1"),                                             // ***both***
        (#"(?<!\w)___(?=\S)(.+?)(?<=\S)___(?!\w)"#, "$1"),
        (#"\*\*(?=\S)(.+?)(?<=\S)\*\*"#, "$1"),                                                 // **bold**
        (#"(?<!\w)__(?=\S)(.+?)(?<=\S)__(?!\w)"#, "$1"),                                        // __bold__ (not my__var)
        (#"(?<![\w*])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![\w*])"#, "$1"),                          // *italic* (not 2*3*4)
        (#"(?<!\w)_(?=[^\s_])(.+?)(?<=[^\s_])_(?!\w)"#, "$1"),                                  // _italic_ (not snake_case)
        (#"~~(?=\S)(.+?)(?<=\S)~~"#, "$1"),                                                     // ~~strike~~
        (#"==(?=\S)(.+?)(?<=\S)=="#, "$1"),                                                     // ==highlight==
    ])
    private static let trailingBlockID = MarkdownText.regex(#"(^|\s)\^[A-Za-z0-9-]+\s*$"#)     // "text ^abc-123"
    private static let whitespaceRun = MarkdownText.regex(#"\s+"#)

    /// Display text of the inside of a [[wiki link]], the way Obsidian renders it.
    private static func wikiLinkText(_ inner: String) -> String {
        let parts = inner.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2 {
            let alias = parts[1].trimmingCharacters(in: .whitespaces)
            if !alias.isEmpty { return alias }
        }
        let target = parts[0].split(separator: "#", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        let note = target.first ?? ""
        let headings = target.dropFirst().filter { !$0.isEmpty && !$0.hasPrefix("^") }
        return ([note] + headings).filter { !$0.isEmpty }.joined(separator: " > ")
    }

    /// The Daily Brief ends a task with where it came from: "Reply to Sam. (Sam, email, Nov 5)" -> ("Reply to Sam.",
    /// "Sam, email, Nov 5"). The large Today widget sets the note as a caption. Only the brief's tasks
    /// (`BaroqueSettings.dailyBriefPath`) carry one, so a task from any other file, "Finish essay (draft 2)", and text
    /// without a note come back whole.
    static func sourceNote(_ text: String, sourcePath: String) -> (text: String, source: String?) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard sourcePath == BaroqueSettings.dailyBriefPath else { return (t, nil) }
        guard t.hasSuffix(")"), let open = t.range(of: " (", options: .backwards) else { return (t, nil) }
        let source = String(t[open.upperBound..<t.index(before: t.endIndex)]).trimmingCharacters(in: .whitespaces)
        let head = String(t[..<open.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard !head.isEmpty, !source.isEmpty, !source.contains("(") else { return (t, nil) }
        return (head, source)
    }

    // MARK: Agenda

    /// Orders tasks for "today" and keeps the first `limit` (at least one). Buckets, in order:
    ///   1. overdue
    ///   2. due today
    ///   3. undated 🔺 / ⏫
    ///   4. due within the next `soonWindowDays` days
    ///   5. other undated
    ///   6. due later than that
    /// Inside a bucket: higher priority first, then earlier due date, then input order
    /// (the order of the task paths, then line order). `includeUndated: false` drops buckets 3 and 5.
    static func todaysAgenda(_ all: [TaskItem], includeUndated: Bool, limit: Int, now: Date = Date()) -> [TaskItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let soonEnd = calendar.date(byAdding: .day, value: soonWindowDays + 1, to: today) ?? today.addingTimeInterval(Double(soonWindowDays + 1) * 86_400)

        func bucket(_ t: TaskItem) -> Int {
            guard let due = t.due else { return t.priority >= .high ? 2 : 4 }
            if t.isOverdue(asOf: now, calendar: calendar) { return 0 }
            if t.isDueToday(asOf: now, calendar: calendar) { return 1 }
            return due < soonEnd ? 3 : 5
        }

        let ranked = all.enumerated()
            .filter { includeUndated || $0.element.due != nil }
            .map { (index: $0.offset, task: $0.element, bucket: bucket($0.element)) }
            .sorted { a, b in
                if a.bucket != b.bucket { return a.bucket < b.bucket }
                if a.task.priority != b.task.priority { return a.task.priority > b.task.priority }
                if let x = a.task.due, let y = b.task.due, x != y { return x < y }
                return a.index < b.index
            }
        return ranked.prefix(max(1, limit)).map(\.task)
    }
}

// Parses a quotes markdown file. Supported shapes:
//   > Quote text, possibly over
//   > several lines
//   >
//   > and several paragraphs (a bare `>` line keeps them in one quote)
//   > — Author                      (em dash, en dash, ―, -, -- or ~; may also sit just below the block)
//
//   > "Short quote." — Author       (attribution at the end of the last line)
//
//   > [!quote] Author               (Obsidian callout; the title is the author unless an author line exists;
//   > Quote text                     [!quote]- / [!quote]+ and [!cite] work too; other callout types are skipped)
//
//   - "Quote text" — Author
//   - Quote text - Author
// A blank line separates quotes. Headings, prose, frontmatter and code blocks are ignored.
enum QuoteParser {
    private static let quoteCalloutTypes: Set<String> = ["quote", "cite"]

    static func parse(markdown: String) -> [Quote] {
        var quotes: [Quote] = []
        var paragraphs: [[String]] = []       // current blockquote, split on bare `>` lines
        var calloutTitle: String?
        var skippingCallout = false           // inside a non-quote callout such as [!note]
        var inBlock: Bool { !paragraphs.isEmpty }
        // The quote on the line just above, in quotation marks and with no author, and whether it was a bullet.
        var lastAuthorless: (index: Int, bullet: Bool)?

        func flush(authorBelow: String? = nil) {
            defer { paragraphs = []; calloutTitle = nil }
            var paras = paragraphs.filter { !$0.isEmpty }
            guard !paras.isEmpty else { return }
            var author = authorBelow
            let lineCount = paras.reduce(0) { $0 + $1.count }
            if author == nil, lineCount > 1, let last = paras.last?.last, let a = authorFromLine(last) {
                author = a
                paras[paras.count - 1].removeLast()
                if paras[paras.count - 1].isEmpty { paras.removeLast() }
            }
            let quoted = paras.first?.first?.first.map { openingQuoteChars.contains($0) } ?? false
            if author == nil, let last = paras.last?.last, let split = inlineAttribution(last, quoted: quoted) {
                paras[paras.count - 1][paras[paras.count - 1].count - 1] = split.text
                author = split.author
            }
            if author == nil { author = calloutTitle }
            let text = paras
                .map { TaskParser.cleanInline($0.joined(separator: " ")) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            append(text: text, author: author)
        }

        func append(text: String, author: String?) {
            let t = stripQuotes(text)
            guard !t.isEmpty else { return }
            let a = author.map { TaskParser.cleanInline($0) }
            quotes.append(Quote(text: t, author: (a?.isEmpty ?? true) ? nil : a))
        }

        for line in MarkdownText.visibleLines(of: markdown) {
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            let authorless = lastAuthorless
            lastAuthorless = nil

            if trimmed.hasPrefix(">") {
                var content = Substring(trimmed)
                while content.first == ">" {
                    content = content.dropFirst().drop(while: { $0 == " " || $0 == "\t" })
                }
                let body = String(content).trimmingCharacters(in: .whitespaces)
                if let callout = calloutHeader(body) {
                    flush()
                    skippingCallout = !quoteCalloutTypes.contains(callout.type)
                    calloutTitle = skippingCallout ? nil : callout.title
                    if !skippingCallout { paragraphs = [[]] }
                    continue
                }
                if skippingCallout { continue }
                if body.isEmpty {
                    // A bare `>` line is a paragraph break inside the same quote.
                    if let last = paragraphs.last, !last.isEmpty { paragraphs.append([]) }
                    continue
                }
                if paragraphs.isEmpty { paragraphs = [[]] }
                paragraphs[paragraphs.count - 1].append(body)
                continue
            }

            skippingCallout = false
            if trimmed.isEmpty { flush(); continue }

            // An attribution line directly below a blockquote belongs to it.
            if inBlock, let a = authorFromLine(trimmed), !isBulletQuote(trimmed), !isTask(trimmed) {
                flush(authorBelow: a)
                continue
            }
            flush()

            // So does one directly below a quote in quotation marks that has no author yet (`authorBelow`).
            if let above = authorless, !isBulletQuote(trimmed), !isTask(trimmed),
               let a = authorBelow(line.text, underBullet: above.bullet) {
                let cleaned = TaskParser.cleanInline(a)
                if !cleaned.isEmpty { quotes[above.index].author = cleaned }
                continue
            }

            if isThematicBreak(trimmed) { continue }
            if let item = bulletBody(trimmed) {
                let (text, author) = splitAuthor(item)
                let before = quotes.count
                append(text: TaskParser.cleanInline(text), author: author)
                if author == nil, quotes.count > before, let first = item.first, openingQuoteChars.contains(first) {
                    lastAuthorless = (before, true)
                }
                continue
            }
            if let line = standaloneQuote(trimmed) {
                let before = quotes.count
                append(text: TaskParser.cleanInline(line.text), author: line.author)
                if line.author == nil, quotes.count > before { lastAuthorless = (before, false) }
                continue
            }
            // Headings and prose are ignored.
        }
        flush()
        return quotes
    }

    // MARK: Pieces

    private static let calloutRegex = MarkdownText.regex(#"^\[!([A-Za-z0-9_-]+)(?:\|[^\]]*)?\][+-]?\s*(.*)$"#)

    private static func calloutHeader(_ body: String) -> (type: String, title: String?)? {
        let ns = body as NSString
        guard let m = calloutRegex.firstMatch(in: body, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let type = ns.substring(with: m.range(at: 1)).lowercased()
        let title = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
        return (type, title.isEmpty ? nil : title)
    }

    private static let authorRegex = MarkdownText.regex(#"^(?:—|–|―|~|-{1,3})\s*([^\s—–―~-].*)$"#)

    /// "— Author", "– Author", "- Author", "-- Author", "~ Author" -> "Author".
    private static func authorFromLine(_ line: String) -> String? {
        let t = line.trimmingCharacters(in: .whitespaces)
        let ns = t as NSString
        guard let m = authorRegex.firstMatch(in: t, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let a = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
        return a.isEmpty ? nil : a
    }

    /// The author on the line under a quote in quotation marks that has none (`raw` is the line as written, with its
    /// indent). Under a bullet quote that's a line opening with an em or en dash (`— Author`) or an indented
    /// sub-bullet (`  - Author`); a plain bullet there is the next quote in the list. Under a quote on a line of its
    /// own (`“Text”`, the user's style) a plain `- Author` counts too, when it reads like a name rather than a
    /// sentence (`looksLikeName`).
    private static func authorBelow(_ raw: String, underBullet: Bool) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let author: String?
        if let first = trimmed.first, "—–―".contains(first) {
            author = authorFromLine(trimmed)
        } else if raw.first?.isWhitespace == true, let sub = bulletBody(trimmed) {
            author = underBullet || looksLikeName(sub) ? sub : nil
        } else if !underBullet, let a = authorFromLine(trimmed), looksLikeName(a) {
            author = a
        } else {
            author = nil
        }
        guard let author, author.count <= 80 else { return nil }
        return author
    }

    /// Short, and not a sentence: at most 80 characters, not ending in a full stop, question or exclamation mark.
    private static func looksLikeName(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard let last = t.last, t.count <= 80, last != "!", last != "?" else { return false }
        guard last == "." else { return true }
        // A full stop ends a sentence, unless it ends a short capitalised abbreviation or initial: "Jr.", "St.", "J."
        let word = t.split(separator: " ").last ?? ""
        return word.count <= 3 && word.first?.isUppercase == true
    }

    private static let bulletRegex = MarkdownText.regex(#"^(?:[-*+]|\d{1,9}[.)])\s+(.*)$"#)
    private static let taskBoxRegex = MarkdownText.regex(#"^\[.\](?:\s|$)"#)

    /// The text of a list item, or nil if the line is not one (task checkboxes are not quotes).
    private static func bulletBody(_ line: String) -> String? {
        let ns = line as NSString
        guard let m = bulletRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let body = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
        let bns = body as NSString
        if taskBoxRegex.firstMatch(in: body, range: NSRange(location: 0, length: bns.length)) != nil { return nil }
        return body.isEmpty ? nil : body
    }

    /// `- [ ] Text`: a task, never an author line.
    private static func isTask(_ line: String) -> Bool {
        let ns = line as NSString
        guard let m = bulletRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return false }
        let body = ns.substring(with: m.range(at: 1))
        return taskBoxRegex.firstMatch(in: body, range: NSRange(location: 0, length: (body as NSString).length)) != nil
    }

    /// `- "Text" — Author` style bullets are quotes of their own, not an author line.
    private static func isBulletQuote(_ line: String) -> Bool {
        guard let body = bulletBody(line) else { return false }
        if let first = body.first, openingQuoteChars.contains(first) { return true }
        return splitAuthor(body).1 != nil
    }

    private static func isThematicBreak(_ line: String) -> Bool {
        let chars = line.filter { !$0.isWhitespace }
        guard chars.count >= 3, let c = chars.first, "-*_".contains(c) else { return false }
        return chars.allSatisfy { $0 == c }
    }

    private static let openingQuoteChars: Set<Character> = ["\"", "“", "‘", "'", "«", "„"]
    private static let closingQuoteChars: Set<Character> = ["\"", "”", "’", "'", "»", "“"]
    private static let doubleClosingQuotes: Set<Character> = ["\"", "”", "»", "“"]
    private static let dashSeparators = [" — ", " – ", " ― "]
    private static let allSeparators = dashSeparators + [" - ", " ~ "]

    /// Splits `"Text" — Author` or `Text - Author` into text and author.
    private static func splitAuthor(_ s: String, separators: [String] = allSeparators) -> (String, String?) {
        let s = s.trimmingCharacters(in: .whitespaces)
        // Quoted text first, so a dash inside the quotes is never taken as the separator.
        if let first = s.first, openingQuoteChars.contains(first),
           let close = s.lastIndex(where: { closingQuoteChars.contains($0) }), close > s.startIndex {
            let text = String(s[...close])
            let rest = s[s.index(after: close)...].trimmingCharacters(in: .whitespaces)
            if rest.isEmpty { return (text, nil) }
            if let a = authorFromLine(rest), separators.contains(where: { $0.trimmingCharacters(in: .whitespaces) == String(rest.prefix(1)) }) {
                return (text, a)
            }
        }
        for sep in separators {
            if let r = s.range(of: sep, options: .backwards) {
                let text = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                let author = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                if text.isEmpty { continue }
                return (text, author.isEmpty ? nil : author)
            }
        }
        return (s, nil)
    }

    /// `"Well done is better than well said." — Benjamin Franklin` / `Well done. — Benjamin Franklin` on a blockquote's last line.
    /// Only em/en dashes count, and only after closing punctuation, so "I came — and I saw" stays whole. When the quote
    /// is in quotation marks (`quoted`), a hyphen right after the closing mark counts too (`“Text” - Author`, the
    /// author's own style), but not after a title inside a sentence (`Read “Walden” - then walk.`).
    private static func inlineAttribution(_ line: String, quoted: Bool) -> (text: String, author: String)? {
        if quoted, let split = attributionAfterQuote(line) { return split }
        let (text, author) = splitAuthor(line, separators: dashSeparators + ["—", "–", "―"])
        guard let author, author.count <= 80, let end = text.last, ".!?…\"”’»)".contains(end) else { return nil }
        return (text, author)
    }

    /// `… lost.” - Author`: a closing double quotation mark, then an author line (any dash, a hyphen included). Single
    /// marks don't count, since in prose they're mostly apostrophes. Tries each closing mark from the end.
    private static func attributionAfterQuote(_ line: String) -> (text: String, author: String)? {
        var end = line.endIndex
        while let close = line[..<end].lastIndex(where: { doubleClosingQuotes.contains($0) }) {
            let rest = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
            if rest.isEmpty { return nil }
            if close > line.startIndex, let author = authorFromLine(rest), author.count <= 80 {
                return (String(line[...close]), author)
            }
            end = close
        }
        return nil
    }

    private static let quotePairs: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("‘", "’"), ("'", "'"), ("«", "»"), ("„", "“")]

    /// A quote on a line of its own, no bullet: `“Text” - Author`, `"Text" — Author` or just `"Text"`. The line must
    /// open with a quotation mark and end at its closing mark or at an attribution, so prose that merely starts with a
    /// quotation (`"Hi" is what I said.`) stays prose.
    private static func standaloneQuote(_ line: String) -> (text: String, author: String?)? {
        guard let first = line.first, let close = quotePairs.first(where: { $0.0 == first })?.1, line.count > 2 else { return nil }
        let start = line.index(after: line.startIndex)
        var end = line.endIndex
        while let c = line[start..<end].lastIndex(of: close) {
            let rest = line[line.index(after: c)...].trimmingCharacters(in: .whitespaces)
            if rest.isEmpty { return (String(line[...c]), nil) }
            if let author = authorFromLine(rest) { return (String(line[...c]), author) }
            end = c
        }
        return nil
    }

    /// Removes one pair of quotation marks wrapping the whole text, but not from `"A" and "B"`.
    private static func stripQuotes(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        for (open, close) in quotePairs where t.count > 2 && t.first == open && t.last == close {
            let inner = String(t.dropFirst().dropLast())
            if isBalanced(inner, open: open, close: close) {
                return inner.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return t
    }

    /// True if the quote marks inside `inner` never close the outer pair early.
    private static func isBalanced(_ inner: String, open: Character, close: Character) -> Bool {
        let chars = Array(inner)
        var depth = 0
        for (i, c) in chars.enumerated() where c == open || c == close {
            let prev: Character? = i > 0 ? chars[i - 1] : nil
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            // Apostrophes inside words (don't, it’s) are not quote marks.
            if c == "'" || c == "’", prev?.isLetter == true, next?.isLetter == true { continue }
            if open == close {
                let opening = prev == nil || prev!.isWhitespace || "([{—–-".contains(prev!)
                depth += opening ? 1 : -1
            } else {
                depth += c == open ? 1 : -1
            }
            if depth < 0 { return false }
        }
        return true
    }
}

// Line and regex helpers shared by both parsers.
enum MarkdownText {
    struct Line {
        let number: Int     // 1-based, as Obsidian shows it
        let text: String
    }

    /// Lines that render as markdown text: skips YAML frontmatter, fenced code blocks
    /// (``` and ~~~, any info string, e.g. a ```tasks query) and multi-line %% comments %%.
    static func visibleLines(of markdown: String) -> [Line] {
        // Character.isNewline covers \n, \r and \r\n (one grapheme), so CRLF files keep their line numbers.
        // A UTF-8 byte order mark (files saved by some Windows editors) would hide the first line.
        let text = markdown.first == "\u{FEFF}" ? String(markdown.dropFirst()) : markdown
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }).map(String.init)
        var out: [Line] = []
        var start = 0

        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let end = lines.dropFirst().firstIndex(where: { ["---", "..."].contains($0.trimmingCharacters(in: .whitespaces)) }) {
            start = end + 1
        }

        var fence: (char: Character, length: Int)?
        var inComment = false
        for i in start..<lines.count {
            let raw = lines[i]
            let stripped = String(raw.drop(while: { $0 == " " || $0 == "\t" || $0 == ">" }))

            if let open = fence {
                let run = stripped.prefix(while: { $0 == open.char })
                if run.count >= open.length, stripped.dropFirst(run.count).allSatisfy(\.isWhitespace) { fence = nil }
                continue
            }
            if inComment {
                if raw.contains("%%") { inComment = false }
                continue
            }
            if let c = stripped.first, c == "`" || c == "~" {
                let run = stripped.prefix(while: { $0 == c })
                if run.count >= 3, !(c == "`" && stripped.dropFirst(run.count).contains("`")) {
                    fence = (c, run.count)
                    continue
                }
            }
            let markers = raw.components(separatedBy: "%%").count - 1
            if markers % 2 == 1 {
                // A comment opens here and closes on a later line; keep the text before it.
                inComment = true
                let before = raw.components(separatedBy: "%%").dropLast().joined(separator: "%%")
                out.append(Line(number: i + 1, text: before))
                continue
            }
            out.append(Line(number: i + 1, text: raw))
        }
        return out
    }

    // MARK: Regex

    /// Patterns are compile-time constants; a bad one is a programming error that the tests catch.
    static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [])
    }

    static func rules(_ list: [(String, String)]) -> [(NSRegularExpression, String)] {
        list.map { (regex($0.0), $0.1) }
    }

    static func apply(_ rules: [(NSRegularExpression, String)], to s: String) -> String {
        rules.reduce(s) { text, rule in
            rule.0.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: rule.1)
        }
    }

    /// Replaces each match with `transform(groups)`, where groups[0] is the whole match.
    static func replace(_ r: NSRegularExpression, in s: String, transform: ([String?]) -> String) -> String {
        let ns = s as NSString
        var out = ""
        var cursor = 0
        for m in r.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            let groups: [String?] = (0..<m.numberOfRanges).map { i in
                let g = m.range(at: i)
                return g.location == NSNotFound ? nil : ns.substring(with: g)
            }
            out += transform(groups)
            cursor = m.range.location + m.range.length
        }
        return out + ns.substring(from: cursor)
    }

    // MARK: Backslash escapes

    // `\#`, `\*` etc. are swapped for private-use characters while the other rules run,
    // then restored without the backslash.
    private static let escapable = Array(#"\`*_{}[]()#+-.!|~=<>%^""#)

    static func protectEscapes(_ s: String) -> String {
        var out = ""
        var it = s.makeIterator()
        while let c = it.next() {
            guard c == "\\" else { out.append(c); continue }
            guard let n = it.next() else { out.append(c); break }
            if let i = escapable.firstIndex(of: n), let scalar = Unicode.Scalar(0xF000 + i) {
                out.unicodeScalars.append(scalar)
            } else {
                out.append(c); out.append(n)
            }
        }
        return out
    }

    static func restoreEscapes(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in s.unicodeScalars {
            let v = Int(scalar.value)
            if v >= 0xF000, v < 0xF000 + escapable.count {
                out.append(contentsOf: String(escapable[v - 0xF000]).unicodeScalars)
            } else {
                out.append(scalar)
            }
        }
        return String(out)
    }
}
