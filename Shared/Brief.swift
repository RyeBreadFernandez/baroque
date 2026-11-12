import Foundation

// The Daily Brief page's note, read the way the widget reads tasks (2026-11-06: "If I click on the daily brief widget
// can you make it so it pulls up the rest of the brief"). The page itself is Baroque/BriefView.swift; this part is
// Foundation only, so ParserTests compiles it as it ships.

enum Brief {
    static let url = URL(string: "baroque://brief")!

    /// The note the page shows: the Daily Brief when it's one of the task paths, otherwise the first task path.
    static func path(settings: BaroqueSettings) -> String {
        let paths = DataLoader.resolvedTaskPaths(settings: settings)
        if paths.contains(BaroqueSettings.dailyBriefPath) { return BaroqueSettings.dailyBriefPath }
        return paths.first ?? BaroqueSettings.dailyBriefPath
    }

    /// "Open in Obsidian": the note in the vault with that name, as Obsidian's own links have it
    /// (`obsidian://open?vault=…&file=…`, the file without `.md`). Everything but letters, digits and `-._~` is
    /// escaped, so a space, `&`, `#`, `+` or `/` in either name reaches Obsidian as written.
    static func obsidianURL(vault: String, path: String) -> URL? {
        let name = vault.trimmingCharacters(in: .whitespacesAndNewlines)
        var file = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if file.lowercased().hasSuffix(".md") { file = String(file.dropLast(3)) }
        var comps = URLComponents()
        comps.scheme = "obsidian"
        comps.host = "open"
        var items: [URLQueryItem] = []
        if !name.isEmpty { items.append(URLQueryItem(name: "vault", value: escaped(name))) }
        items.append(URLQueryItem(name: "file", value: escaped(file)))
        comps.percentEncodedQueryItems = items
        return comps.url
    }

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    private static func escaped(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s }

    // MARK: The note

    /// A task as the page shows it: its text as the widget has it, and where it is in the file, for ticking it.
    struct TaskLine: Hashable {
        var text: String
        var done: Bool
        /// 1-based, as Obsidian and TaskParser count lines.
        var lineNumber: Int
        /// The line exactly as it is in the file.
        var line: String

        var key: String { TaskToggle.key(text) }
        /// Its due date (📅), which tells it apart from a task with the same words.
        var due: Date? { TaskToggle.due(ofLine: line) }
        /// A repeating task (🔁): the page shows its ring without the button, since it's ticked in Obsidian.
        var repeats: Bool { TaskToggle.repeats(line) }
    }

    enum Block: Hashable {
        case title(String)
        case section(String)
        case task(TaskLine)
        case bullet(String)
        case paragraph(String)
    }

    /// The note's blocks, and its "generated" line from the front matter. Lines are read as TaskParser reads them
    /// (`MarkdownText.visibleLines`: CRLF, a byte order mark, front matter, fenced code and %% comments), so every
    /// task the widget lists from this note is a task here, at the same line. Text is plain: `cleanInline`.
    static func parse(_ markdown: String) -> (blocks: [Block], generated: String?) {
        let raw = TaskToggle.Lines(markdown)
        let open = Dictionary(TaskParser.parse(markdown: markdown, sourcePath: "").map { ($0.lineNumber, $0) }, uniquingKeysWith: { a, _ in a })
        var blocks: [Block] = []
        for line in MarkdownText.visibleLines(of: markdown) {
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let original = raw.text(at: line.number - 1)
            if let task = open[line.number] {
                blocks.append(.task(TaskLine(text: task.text, done: false, lineNumber: line.number, line: original)))
                continue
            }
            if let box = TaskToggle.checkbox(line.text) {
                // Done tasks get a ticked ring; an open one with no text is skipped, as the widget skips it; other
                // states (cancelled `[-]` and the like) read as plain bullets.
                if let text = TaskToggle.text(ofLine: original), !box.isOpen {
                    blocks.append(box.isDone ? .task(TaskLine(text: text, done: true, lineNumber: line.number, line: original)) : .bullet(text))
                }
                continue
            }
            if case let (level, text)? = heading(trimmed) {
                let clean = TaskParser.cleanInline(text)
                if !clean.isEmpty { blocks.append(level == 1 ? .title(withoutWeekday(clean)) : .section(clean)) }
                continue
            }
            if isThematicBreak(trimmed) { continue }
            let body = bulletBody(trimmed) ?? trimmed
            let clean = TaskParser.cleanInline(body)
            if clean.isEmpty { continue }
            blocks.append(body == trimmed ? .paragraph(clean) : .bullet(clean))
        }
        return (blocks, frontMatterValue("generated", in: markdown))
    }

    private static let headingRegex = MarkdownText.regex(#"^(#{1,6})[ \t]+(.*?)[ \t#]*$"#)
    private static let bulletRegex = MarkdownText.regex(#"^(?:[-*+]|\d{1,9}[.)])[ \t]+(.*)$"#)
    private static let breakRegex = MarkdownText.regex(#"^(?:(?:-[ \t]*){3,}|(?:\*[ \t]*){3,}|(?:_[ \t]*){3,})$"#)

    private static func heading(_ s: String) -> (Int, String)? {
        let ns = s as NSString
        guard let m = headingRegex.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (m.range(at: 1).length, ns.substring(with: m.range(at: 2)))
    }

    private static func bulletBody(_ s: String) -> String? {
        let ns = s as NSString
        guard let m = bulletRegex.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    private static func isThematicBreak(_ s: String) -> Bool {
        breakRegex.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }

    /// A value from the note's YAML front matter (`generated: 2026-11-06 05:42 PT`), without quotes.
    static func frontMatterValue(_ key: String, in markdown: String) -> String? {
        let lines = TaskToggle.Lines(markdown).lines
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        for line in lines.dropFirst() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t == "---" || t == "..." { break }
            guard t.hasPrefix(key + ":") else { continue }
            var value = t.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
            if value.count >= 2, let q = value.first, q == "\"" || q == "'", value.last == q { value = String(value.dropFirst().dropLast()) }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    // No weekday names anywhere: "Friday, November 6" is set as "November 6".
    private static let weekdayRegex = MarkdownText.regex(
        #"^(?i:(?:mon|tues|wednes|thurs|fri|satur|sun)day,?[ \t]+|(?:mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\.?,[ \t]*)"#)

    static func withoutWeekday(_ title: String) -> String {
        let ns = title as NSString
        guard let m = weekdayRegex.firstMatch(in: title, range: NSRange(location: 0, length: ns.length)) else { return title }
        let rest = ns.substring(from: m.range.length).trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? title : rest
    }

    // MARK: Times (with their day, and no weekday)

    /// "today 7:02", "yesterday 7:02", "Nov 9, 7:02", and "Nov 9, 2025, 7:02" in another year.
    static func when(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "h:mm"
        let clock = f.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return "today \(clock)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "yesterday \(clock)"
        }
        f.dateFormat = calendar.component(.year, from: date) == calendar.component(.year, from: now) ? "MMM d" : "MMM d, yyyy"
        return "\(f.string(from: date)), \(clock)"
    }

    /// The front matter's "generated" time: "2026-11-06 05:42 PT" (PT, ET, CT, MT, or any zone abbreviation).
    static func writtenDate(_ generated: String) -> Date? {
        let s = generated.trimmingCharacters(in: .whitespaces)
        guard s.count >= 16 else { return nil }
        let stamp = String(s.prefix(16)).replacingOccurrences(of: "T", with: " ")
        let zoneName = s.dropFirst(16).trimmingCharacters(in: .whitespaces).uppercased()
        let named = ["PT": "America/Los_Angeles", "MT": "America/Denver", "CT": "America/Chicago", "ET": "America/New_York"]
        let zone = named[zoneName].flatMap(TimeZone.init(identifier:)) ?? (zoneName.isEmpty ? nil : TimeZone(abbreviation: zoneName))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = zone ?? .current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: stamp)
    }

    /// The line under the title: "WRITTEN TODAY 5:42  ·  FETCHED TODAY 7:02".
    static func stamp(generated: String?, fetchedAt: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let fetched = "FETCHED \(when(fetchedAt, now: now, calendar: calendar).uppercased())"
        guard let generated else { return fetched }
        let written = writtenDate(generated).map { when($0, now: now, calendar: calendar) } ?? generated
        return "WRITTEN \(written.uppercased())  ·  \(fetched)"
    }
}
