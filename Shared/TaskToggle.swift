import Foundation

/// Ticks and unticks a task's line in a markdown file the way Obsidian Tasks does: `- [ ]` becomes `- [x]` with
/// ` ✅ YYYY-MM-DD` added (before a trailing `^block-id`), and unticking takes both away again. Everything else on the
/// line, its indentation and every other line, line ending and byte order mark stay exactly as they were. A repeating
/// task (🔁) is never changed: it's ticked in Obsidian, where the Tasks plugin makes the next one.
///
/// Foundation only, so ParserTests compiles it as it ships.
enum TaskToggle {
    /// A checkbox line split round its status character: `prefix` + status + `rest` is the line again.
    struct Checkbox: Equatable {
        var prefix: String   // "  - [" : indent, list marker and the opening bracket
        var status: Character
        var rest: String     // "] Text ✅ 2026-11-11 ^abc"

        var isOpen: Bool { status == " " || status == "/" }   // todo and in progress, as TaskParser lists them
        var isDone: Bool { status == "x" || status == "X" }
        var line: String { prefix + String(status) + rest }
    }

    // TaskParser's checkbox rule (indent, `>` of a callout, a list marker `- * +` or `1.` / `1)`, then `[c]`).
    private static let checkboxRegex = MarkdownText.regex(#"^([\s>]*(?:[-*+]|\d{1,9}[.)])[ \t]+\[)(.)(\].*)$"#)

    static func checkbox(_ line: String) -> Checkbox? {
        let ns = line as NSString
        guard let m = checkboxRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
              let status = ns.substring(with: m.range(at: 2)).first else { return nil }
        return Checkbox(prefix: ns.substring(with: m.range(at: 1)), status: status, rest: ns.substring(with: m.range(at: 3)))
    }

    // MARK: Key

    /// What a task is called whatever its state: the text TaskParser shows for it (no checkbox, ✅ date, priority,
    /// due date or tags) with the spacing collapsed. Ticks are remembered by it, so a task the morning brief lists
    /// again reads as the same task.
    static func key(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// The task TaskParser would list for a checkbox line in any state (nil if it isn't a task or has no text).
    static func task(ofLine line: String) -> TaskItem? {
        guard var box = checkbox(line) else { return nil }
        box.status = " "
        return TaskParser.parse(markdown: box.line, sourcePath: "").first
    }

    /// The text TaskParser would show for a checkbox line in any state (nil if it isn't a task or has no text).
    static func text(ofLine line: String) -> String? { task(ofLine: line)?.text }

    static func key(ofLine line: String) -> String? { text(ofLine: line).map(key) }

    /// A checkbox line's due date (📅), in any state.
    static func due(ofLine line: String) -> Date? { task(ofLine: line)?.due }

    /// A repeating task's line (🔁), in any state. It's never changed here: ticked in Obsidian, the Tasks plugin
    /// adds the next one, and ticked here the recurrence would end.
    static func repeats(_ line: String) -> Bool { task(ofLine: line)?.repeats ?? false }

    /// The same due date, or both none. Days, not instants, so a date read again later still matches.
    static func sameDue(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (a?, b?): return Calendar.current.isDate(a, inSameDayAs: b)
        default: return false
        }
    }

    // MARK: One line

    /// The line ticked (`done`) or unticked. A line already in that state comes back unchanged; a line that isn't a
    /// task, has a status other than open or done (cancelled `[-]`, say), or repeats (`repeats`) is nil.
    static func toggled(_ line: String, done: Bool, today: Date) -> String? {
        guard var box = checkbox(line), box.isOpen || box.isDone, !repeats(line) else { return nil }
        if done == box.isDone { return line }
        if done {
            box.status = "x"
            box.rest = adding(doneDate(today), to: removingDoneDate(box.rest))
        } else {
            box.status = " "
            box.rest = removingDoneDate(box.rest)
        }
        return box.line
    }

    static func doneDate(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return "✅ " + f.string(from: day)
    }

    private static let doneDateRegex = MarkdownText.regex(#"[ \t]*✅\x{FE0F}?[ \t]*\d{4}-\d{2}-\d{2}"#)
    private static let trailingBlockID = MarkdownText.regex(#"[ \t]+\^[A-Za-z0-9-]+[ \t]*$"#)
    private static let trailingSpace = MarkdownText.regex(#"[ \t]*$"#)

    private static func removingDoneDate(_ s: String) -> String {
        doneDateRegex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "")
    }

    /// Puts the done date at the end of the text: before a block id, and before trailing spaces.
    private static func adding(_ date: String, to s: String) -> String {
        let ns = s as NSString
        let all = NSRange(location: 0, length: ns.length)
        let cut = trailingBlockID.firstMatch(in: s, range: all)?.range.location
            ?? trailingSpace.firstMatch(in: s, range: all)?.range.location
            ?? ns.length
        return ns.substring(to: cut) + " " + date + ns.substring(from: cut)
    }

    // MARK: In a file

    /// The markdown with one task ticked or unticked. The task is the line that reads exactly `original`: the one at
    /// `lineNumber` (1-based) if it's there, otherwise the only such line in the file. Nil when the line is missing,
    /// or appears more than once and not at `lineNumber`: the task changed in the vault. Nil too for a repeating task
    /// (`repeats`), which is never changed.
    static func apply(to markdown: String, line original: String, near lineNumber: Int, done: Bool, today: Date) -> String? {
        change(in: markdown, line: original, near: lineNumber, done: done, today: today).flatMap { $0.repeats ? nil : $0.markdown }
    }

    /// The same, finding the task by its key (`key(_:)`) rather than its exact line: for ticks made on the widget, and
    /// ticks made again when the morning brief lists a ticked task anew. When several lines have that key, only
    /// those due on `due` (or, for nil, with no due date) are the task; if that still leaves more than one and none is
    /// at `lineNumber`, it's nil rather than a guess. A line already in the wanted state counts as done (the markdown
    /// comes back unchanged) when no other line of the task needs changing.
    static func apply(to markdown: String, key wanted: String, near lineNumber: Int, done: Bool, today: Date, due: Date? = nil) -> String? {
        change(in: markdown, key: wanted, near: lineNumber, done: done, today: today, due: due).flatMap { $0.repeats ? nil : $0.markdown }
    }

    /// What `apply` did: the file after it, and the task's line (1-based) as it reads now.
    struct Change: Equatable {
        var markdown: String
        var lineNumber: Int
        var line: String
        /// The task repeats (🔁), so nothing was changed: `markdown` is the file as it was, `line` the task's line.
        var repeats = false
    }

    static func change(in markdown: String, line original: String, near lineNumber: Int, done: Bool, today: Date) -> Change? {
        let wanted = strippingReturn(original)
        return change(markdown, near: lineNumber, done: done, today: today) { _, line in line == wanted }
    }

    static func change(in markdown: String, key wanted: String, near lineNumber: Int, done: Bool, today: Date, due: Date? = nil) -> Change? {
        change(markdown, near: lineNumber, done: done, today: today, tellApart: { sameDue(TaskToggle.due(ofLine: $0), due) }) { box, line in
            (box.isOpen || box.isDone) && key(ofLine: line) == wanted
        }
    }

    /// Finds the line among the file's visible lines (not in front matter, code blocks or comments) and changes it.
    /// When several lines match, `tellApart` keeps the ones that are the task (none left: nil).
    private static func change(_ markdown: String, near lineNumber: Int, done: Bool, today: Date,
                               tellApart: ((String) -> Bool)? = nil, matches: (Checkbox, String) -> Bool) -> Change? {
        var file = Lines(markdown)
        let visible = Set(MarkdownText.visibleLines(of: markdown).map(\.number))
        var hits: [Int] = []           // 0-based indexes of the lines that match
        for i in file.lines.indices where visible.contains(i + 1) {
            let line = file.text(at: i)
            if let box = checkbox(line), matches(box, line) { hits.append(i) }
        }
        if hits.count > 1, let tellApart {
            hits = hits.filter { tellApart(file.text(at: $0)) }
            if hits.isEmpty { return nil }
        }
        // Lines already in the wanted state don't compete: the one at `lineNumber` that still needs the change, else
        // the only one that does. If every match is already ticked (or unticked), there's nothing to do.
        let needing = hits.filter { checkbox(file.text(at: $0)).map { done != $0.isDone } ?? false }
        let pick: Int
        if needing.contains(lineNumber - 1) { pick = lineNumber - 1 }
        else if needing.count == 1 { pick = needing[0] }
        else if needing.isEmpty, let already = hits.contains(lineNumber - 1) ? lineNumber - 1 : hits.first {
            return Change(markdown: markdown, lineNumber: already + 1, line: file.text(at: already))
        }
        else { return nil }
        let line = file.text(at: pick)
        if repeats(line) { return Change(markdown: markdown, lineNumber: pick + 1, line: line, repeats: true) }
        guard let changed = toggled(line, done: done, today: today) else { return nil }
        file.setText(changed, at: pick)
        return Change(markdown: file.joined, lineNumber: pick + 1, line: changed)
    }

    private static func strippingReturn(_ s: String) -> String {
        s.hasSuffix("\r") ? String(s.dropLast()) : s
    }

    /// A file split into lines the way `MarkdownText.visibleLines` counts them (any newline character, CRLF as one),
    /// keeping every separator and a byte order mark so `joined` gives the file back byte for byte.
    struct Lines {
        private(set) var lines: [String] = []
        private var separators: [String] = []   // separators[i] follows lines[i]; the last line may have none
        private var bom = ""

        init(_ markdown: String) {
            var text = Substring(markdown)
            if text.first == "\u{FEFF}" { bom = "\u{FEFF}"; text = text.dropFirst() }
            var current = ""
            for c in text {
                if c.isNewline {
                    lines.append(current); separators.append(String(c)); current = ""
                } else {
                    current.append(c)
                }
            }
            lines.append(current); separators.append("")
        }

        func text(at i: Int) -> String { lines[i] }
        mutating func setText(_ s: String, at i: Int) { lines[i] = s }

        var joined: String {
            var out = bom
            for i in lines.indices { out += lines[i] + separators[i] }
            return out
        }
    }
}
