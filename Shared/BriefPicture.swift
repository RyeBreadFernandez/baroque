import Foundation

// The Daily Brief's picture of the day (2026-11-11: "On the page with the task list there is a photo of the flower on
// the top. I instead want to replace that with the Daily brief photo of the day"). The morning brief embeds one picture
// in `Today.md`, in a callout: a public-domain painting from a museum's IIIF server, as a Markdown image with an https
// URL. Each fetch of the brief looks for it (`find`); a new one is downloaded once, cut to the large Today's band
// (`BandImage`) and kept in the App Group's caches, and the band shows it for the day the brief named it, in place of
// the still life. Foundation only, so ParserTests compiles it as it ships.

enum BriefPicture {
    /// A picture the note shows: an https URL, or a picture in the vault as the note names it (`vaultPaths` finds it).
    struct Found: Equatable {
        var source: String
        var alt: String = ""

        /// The picture's https URL; nil for one in the vault.
        var webURL: URL? {
            guard source.lowercased().hasPrefix("https://") else { return nil }
            return URL(string: source)
        }
    }

    /// The picture on file (`Store.briefPicture`): where it came from, what it shows (for VoiceOver), and when a fetch of
    /// the brief last named it. Its day is the one the band shows it on.
    struct Kept: Codable, Equatable {
        var source: String
        var alt: String = ""
        var day: Date
    }

    /// A download that failed (`Store.briefPictureFailure`), so the same picture isn't fetched again at every refresh.
    struct Attempt: Codable, Equatable {
        var source: String
        var at: Date
    }

    /// The file in `folder` the picture is kept in.
    static let fileName = "picture.jpg"

    /// Where the picture is kept: the App Group's caches, which the app and the widgets share. If the system clears
    /// them, the next fetch of the brief downloads the picture again.
    static var folder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup)?
            .appendingPathComponent("Library/Caches/Brief picture", isDirectory: true)
    }

    /// The longest a picture's download may take, and how long a fetch of the day waits for it.
    static let timeout: TimeInterval = 15

    /// How long a picture that couldn't be fetched waits before it's tried again.
    static let retryAfter: TimeInterval = 60 * 60

    /// The largest download that's read: a painting at the size the brief asks for is a megabyte or two.
    static let maxBytes = 25 * 1024 * 1024

    /// Downloads with no cookies, no cache and no token, each over in `timeout`.
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    // MARK: Finding it

    /// The first picture in the note: a Markdown image `![alt](url "title")` with an https URL or a path in the vault, or
    /// an embed `![[picture.jpg|300]]`, in a blockquote or callout as anywhere else. Pictures in fenced code (also
    /// inside a callout), in `inline code`, in %% comments %% and in the front matter don't count, nor do embedded
    /// notes, http or other links, and SVGs (which can't be drawn).
    static func find(in markdown: String) -> Found? {
        for line in renderedLines(of: markdown) {
            if let found = firstPicture(in: line) { return found }
        }
        return nil
    }

    /// The note's lines as they render, with their blockquote and callout markers taken off. Front matter, fenced code
    /// and %% comments %% are left out. A fence opened in a callout ends with the callout if it isn't closed before,
    /// as in Obsidian; one that's never closed runs to the end of the note.
    static func renderedLines(of markdown: String) -> [String] {
        let text = markdown.first == "\u{FEFF}" ? String(markdown.dropFirst()) : markdown
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }).map(String.init)
        var start = 0
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let end = lines.dropFirst().firstIndex(where: { ["---", "..."].contains($0.trimmingCharacters(in: .whitespaces)) }) {
            start = end + 1
        }
        var out: [String] = []
        var fence: (char: Character, length: Int, depth: Int)?
        var inComment = false
        for raw in lines.dropFirst(start) {
            let (depth, body) = unquoted(raw)
            let stripped = body.drop(while: { $0 == " " || $0 == "\t" })
            if let open = fence {
                if depth >= open.depth {
                    let run = stripped.prefix(while: { $0 == open.char })
                    if run.count >= open.length, stripped.dropFirst(run.count).allSatisfy(\.isWhitespace) { fence = nil }
                    continue
                }
                fence = nil   // the callout the fence was in has ended, and the fence with it
            }
            var rest = body
            if inComment {
                guard let close = rest.range(of: "%%") else { continue }
                rest = String(rest[close.upperBound...])
                inComment = false
            } else if let c = stripped.first, c == "`" || c == "~" {
                let run = stripped.prefix(while: { $0 == c })
                if run.count >= 3, !(c == "`" && stripped.dropFirst(run.count).contains("`")) {
                    fence = (c, run.count, depth)
                    continue
                }
            }
            // %% comments %% on the line go; one left open hides the rest of the line and the lines after, to its close.
            let parts = rest.components(separatedBy: "%%")
            if parts.count % 2 == 0 { inComment = true }
            out.append(parts.enumerated().filter { $0.offset % 2 == 0 }.map(\.element).joined(separator: " "))
        }
        return out
    }

    /// How many blockquote (callout) markers open the line, and the line after them.
    private static func unquoted(_ line: String) -> (depth: Int, body: String) {
        var depth = 0
        var rest = Substring(line)
        while true {
            let after = rest.drop(while: { $0 == " " || $0 == "\t" })
            guard after.first == ">" else { break }
            depth += 1
            rest = after.dropFirst()
            if rest.first == " " { rest = rest.dropFirst() }
        }
        return (depth, String(rest))
    }

    // ![alt](destination "title"): the alt may hold [brackets]; the destination is <in angle brackets> or has no spaces
    // (balanced parentheses allowed); the title is in quotes or parentheses.
    private static let markdownImage = MarkdownText.regex(
        #"!\[((?:[^\[\]]|\[[^\[\]]*\])*)\]\(\s*(<[^<>]*>|(?:[^()\s]|\([^()\s]*\))+)(?:\s+(?:"[^"]*"|'[^']*'|\([^()]*\)))?\s*\)"#)
    // ![[picture.jpg]], ![[folder/picture.jpg|300]], ![[picture.jpg|alt text]]
    private static let wikiImage = MarkdownText.regex(#"!\[\[([^\[\]|#^]+)(?:[#^][^\[\]|]*)?(?:\|([^\[\]]*))?\]\]"#)
    private static let codeSpan = MarkdownText.regex(#"(`+)(?:.+?)\1"#)
    private static let htmlComment = MarkdownText.regex(#"<!--.*?-->"#)
    private static let scheme = MarkdownText.regex(#"^[A-Za-z][A-Za-z0-9+.-]*:"#)
    private static let size = MarkdownText.regex(#"^\s*\d+(?:\s*x\s*\d+)?\s*$"#)

    /// The picture formats ImageIO reads (an SVG isn't one).
    static let pictureExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "webp", "heic", "heif", "tif", "tiff", "avif"]

    /// The first picture on a line that can be shown.
    private static func firstPicture(in line: String) -> Found? {
        var s = MarkdownText.protectEscapes(line)   // \![not a picture](x)
        s = MarkdownText.apply([(codeSpan, " "), (htmlComment, " ")], to: s)
        let ns = s as NSString
        let all = NSRange(location: 0, length: ns.length)
        func group(_ m: NSTextCheckingResult, _ i: Int) -> String? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : MarkdownText.restoreEscapes(ns.substring(with: r))
        }
        let candidates = (markdownImage.matches(in: s, range: all).map { (m: $0, wiki: false) }
            + wikiImage.matches(in: s, range: all).map { (m: $0, wiki: true) })
            .sorted { $0.m.range.location < $1.m.range.location }
        for c in candidates {
            let found = c.wiki ? wikiPicture(target: group(c.m, 1) ?? "", options: group(c.m, 2))
                               : markdownPicture(alt: group(c.m, 1) ?? "", destination: group(c.m, 2) ?? "")
            if let found { return found }
        }
        return nil
    }

    private static func markdownPicture(alt: String, destination: String) -> Found? {
        var dest = destination.trimmingCharacters(in: .whitespaces)
        if dest.hasPrefix("<"), dest.hasSuffix(">") { dest = String(dest.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces) }
        guard !dest.isEmpty else { return nil }
        // Obsidian sizes a picture after a bar in its alt text: ![The harbour|300](…).
        var text = alt
        if let bar = text.range(of: "|", options: .backwards), matches(size, String(text[bar.upperBound...])) {
            text = String(text[..<bar.lowerBound])
        }
        let altText = TaskParser.cleanInline(text)
        if matches(scheme, dest) {
            guard dest.lowercased().hasPrefix("https://"),
                  let url = URL(string: dest.replacingOccurrences(of: " ", with: "%20")),
                  let host = url.host, !host.isEmpty, url.pathExtension.lowercased() != "svg" else { return nil }
            return Found(source: url.absoluteString, alt: altText)
        }
        let path = dest.removingPercentEncoding ?? dest
        guard isPicture(path) else { return nil }
        return Found(source: path, alt: altText)
    }

    private static func wikiPicture(target: String, options: String?) -> Found? {
        let path = target.trimmingCharacters(in: .whitespaces)
        guard isPicture(path) else { return nil }   // ![[A note]] embeds a note
        let words = (options ?? "").components(separatedBy: "|").filter { !matches(size, $0) }
        return Found(source: path, alt: TaskParser.cleanInline(words.joined(separator: " ")))
    }

    private static func isPicture(_ path: String) -> Bool {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        guard let dot = name.lastIndex(of: "."), !path.hasPrefix("#") else { return false }
        return pictureExtensions.contains(name[name.index(after: dot)...].lowercased())
    }

    private static func matches(_ r: NSRegularExpression, _ s: String) -> Bool {
        r.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }

    // MARK: A picture in the vault

    /// Where a picture named in the note at `notePath` may be in the vault, in the order to try: beside the note, then
    /// from the top of the vault. A path starting `./` or `../` counts from the note's folder only, one starting `/`
    /// from the top only; one that climbs out of the vault is none.
    static func vaultPaths(_ target: String, notePath: String) -> [String] {
        let t = target.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return [] }
        let folder = notePath.split(separator: "/").dropLast().map(String.init)
        let bases: [[String]]
        if t.hasPrefix("/") { bases = [[]] }
        else if t.hasPrefix("./") || t.hasPrefix("../") { bases = [folder] }
        else { bases = [folder, []] }
        var out: [String] = []
        for base in bases {
            guard let path = normalized(base + t.split(separator: "/", omittingEmptySubsequences: false).map(String.init)),
                  !path.isEmpty, !out.contains(path) else { continue }
            out.append(path)
        }
        return out
    }

    private static func normalized(_ parts: [String]) -> String? {
        var out: [String] = []
        for part in parts {
            switch part {
            case "", ".": continue
            case "..":
                guard !out.isEmpty else { return nil }
                out.removeLast()
            default: out.append(part)
            }
        }
        return out.joined(separator: "/")
    }

    // MARK: Keeping it

    /// What a fetch of the brief does with the picture.
    enum Step: Equatable {
        /// Nothing to download: keep this (nil: no picture, the flowers).
        case keep(Kept?)
        /// A new picture: download it, then `settle`.
        case download(Found)
    }

    /// The brief (fetched at `now`) names `found`, and `kept` is on file (`fileExists`):
    /// - no picture in the brief: back to the flowers;
    /// - the same picture, still on file: no download; it's now the picture for today;
    /// - a new one: download it, unless it failed within `retryAfter`, when what's kept stays as a failed download leaves it.
    static func step(found: Found?, kept: Kept?, fileExists: Bool, failed: Attempt?, now: Date) -> Step {
        guard let found else { return .keep(nil) }
        if let kept, kept.source == found.source, fileExists {
            return .keep(Kept(source: found.source, alt: found.alt, day: now))
        }
        if let failed, failed.source == found.source, failed.at <= now, now.timeIntervalSince(failed.at) < retryAfter {
            return .keep(settle(found, saved: false, kept: kept, now: now))
        }
        return .download(found)
    }

    /// What's kept once `found` was downloaded (`saved`) or not: the new picture, or after a failed download the last
    /// one if it's today's (the brief named it today), otherwise the flowers.
    static func settle(_ found: Found, saved: Bool, kept: Kept?, now: Date, calendar: Calendar = .current) -> Kept? {
        if saved { return Kept(source: found.source, alt: found.alt, day: now) }
        guard let kept, calendar.isDate(kept.day, inSameDayAs: now) else { return nil }
        return kept
    }

    /// The picture's file and what it shows, when the band should draw it on `date`: it's on file and the brief named
    /// it that day. Otherwise nil, and the band draws the still life.
    static func shown(_ kept: Kept?, in folder: URL?, on date: Date, calendar: Calendar = .current,
                      fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> (file: URL, alt: String)? {
        guard let kept, let folder, calendar.isDate(kept.day, inSameDayAs: date) else { return nil }
        let file = folder.appendingPathComponent(fileName)
        return fileExists(file) ? (file, kept.alt) : nil
    }

    // MARK: Fetching it

    /// After a fetch of the brief (`markdown`, the note at `notePath`): finds its picture, and keeps, downloads or clears
    /// what's on file in `folder` by `step` and `settle`. Never throws; a download that fails leaves the tasks as they
    /// are. A web picture comes through `web` with no token, one in the vault through `client`.
    static func update(brief markdown: String, notePath: String, store: Store, folder: URL?, client: GitHubClient,
                       web: URLSession = session, now: Date = Date()) async {
        guard let folder else { return }
        let fm = FileManager.default
        let file = folder.appendingPathComponent(fileName)
        let kept = store.briefPicture
        let next: Kept?
        switch step(found: find(in: markdown), kept: kept, fileExists: fm.fileExists(atPath: file.path),
                    failed: store.briefPictureFailure, now: now) {
        case .keep(let k):
            next = k
        case .download(let found):
            var saved = false
            if let jpeg = await fetch(found, notePath: notePath, client: client, web: web) {
                try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
                saved = (try? jpeg.write(to: file, options: .atomic)) != nil
            }
            store.briefPictureFailure = saved ? nil : Attempt(source: found.source, at: now)
            next = settle(found, saved: saved, kept: kept, now: now)
        }
        if next != kept { store.briefPicture = next }
        if next == nil { try? fm.removeItem(at: file) }
    }

    /// The picture downloaded and cut to the band, as JPEG data; nil when it couldn't be fetched or read.
    static func fetch(_ found: Found, notePath: String, client: GitHubClient, web: URLSession) async -> Data? {
        let file: URL
        do {
            if let url = found.webURL {
                file = try await download(url, session: web)
            } else {
                file = try await download(vaultPicture: found.source, notePath: notePath, client: client)
            }
        } catch {
            return nil
        }
        defer { try? FileManager.default.removeItem(at: file) }
        guard let bytes = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, bytes <= maxBytes else { return nil }
        return BandImage.jpeg(fromFile: file)
    }

    /// A web picture, saved to a temporary file: a plain request, never with the GitHub token.
    static func download(_ url: URL, session: URLSession) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (file, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: file)
            throw URLError(.badServerResponse)
        }
        return file
    }

    /// A picture in the vault, from the first of `vaultPaths` that's there.
    static func download(vaultPicture path: String, notePath: String, client: GitHubClient) async throws -> URL {
        var missing: Error = GitHubError.notFound(path, repository: client.repository)
        for candidate in vaultPaths(path, notePath: notePath) {
            do {
                return try await client.download(path: candidate)
            } catch let error as GitHubError {
                guard case .notFound = error else { throw error }
                missing = error
            }
        }
        throw missing
    }
}

extension BriefPicture.Kept {
    /// Decoded field by field: a field added later takes its default instead of losing the picture.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decode(String.self, forKey: .source)
        day = try c.decode(Date.self, forKey: .day)
        alt = (try? c.decodeIfPresent(String.self, forKey: .alt)) ?? ""
    }
}
