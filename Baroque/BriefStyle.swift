import Foundation

// The vault's own look for the Daily Brief page (2026-11-12): the CSS snippets the note's front matter names
// (`cssclasses: [daily-brief]` → `.obsidian/snippets/daily-brief.css`) and the fonts in `.obsidian/appearance.json`.
// They're kept as files in the App Group's container, so the page looks the same offline, and fetched again when the
// page refreshes the note: at most about once a day, unless the refresh is forced or the note names a new class. A
// snippet that isn't in the vault (404) is skipped. Foundation only, so ParserTests compiles it.

enum BriefStyle {
    /// What the page styles the note with.
    struct Sheets: Equatable {
        /// The snippets' CSS, in the order the note names them.
        var css: [String] = []
        var appearance: BriefHTML.Appearance? = nil
    }

    /// "About once a day": a little under, so a morning refresh isn't skipped by a few minutes.
    static let maxAge: TimeInterval = 20 * 60 * 60
    /// The vault's settings folder, Obsidian's default.
    static let configFolder = ".obsidian"
    /// Larger than any snippet should be (the brief's, with two fonts embedded, is about 66 KB).
    static let maxSize = 4_000_000

    static var folder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup)?
            .appendingPathComponent("Library/Application Support/Brief style", isDirectory: true)
    }

    /// When the files were last fetched, and for which classes.
    private struct Record: Codable {
        var fetchedAt: Date
        var classes: [String]
    }

    static func snippetPath(_ name: String) -> String { "\(configFolder)/snippets/\(name).css" }
    static var appearancePath: String { "\(configFolder)/appearance.json" }

    /// What's on file for these classes (nothing for a class never fetched).
    static func cached(classes: [String], folder: URL?) -> Sheets {
        guard let folder else { return Sheets() }
        let css = classes.filter(isPlainName).compactMap { try? String(contentsOf: snippetFile($0, in: folder), encoding: .utf8) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let appearance = (try? Data(contentsOf: folder.appendingPathComponent("appearance.json"))).flatMap(BriefHTML.Appearance.init(json:))
        return Sheets(css: css, appearance: appearance)
    }

    /// Whether the files need fetching: never fetched, fetched more than `maxAge` ago (or in the future), or not for
    /// one of these classes.
    static func isStale(classes: [String], folder: URL, now: Date = Date()) -> Bool {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("fetched.json")),
              let record = try? decoder.decode(Record.self, from: data) else { return true }
        let age = now.timeIntervalSince(record.fetchedAt)
        return age < 0 || age > maxAge || !Set(classes).isSubset(of: Set(record.classes))
    }

    /// Fetches the snippets and the appearance when they're stale (or `force`), keeps them, and returns what's on
    /// file after. Never throws: a fetch that fails keeps the last copy, and is tried again next time; a file the vault
    /// doesn't have (404) is forgotten.
    @discardableResult
    static func refresh(classes: [String], client: GitHubClient, folder: URL?, force: Bool = false, now: Date = Date()) async -> Sheets {
        guard let folder else { return Sheets() }
        let classes = classes.filter(isPlainName)
        guard force || isStale(classes: classes, folder: folder, now: now) else { return cached(classes: classes, folder: folder) }
        let fm = FileManager.default
        let snippets = folder.appendingPathComponent("snippets", isDirectory: true)
        try? fm.createDirectory(at: snippets, withIntermediateDirectories: true)
        var complete = true
        for name in classes {
            let file = snippetFile(name, in: folder)
            switch await fetch(snippetPath(name), client: client) {
            case .found(let text): try? Data(text.utf8).write(to: file, options: .atomic)
            case .missing: try? fm.removeItem(at: file)
            case .failed: complete = false
            }
        }
        let appearanceFile = folder.appendingPathComponent("appearance.json")
        switch await fetch(appearancePath, client: client) {
        case .found(let text): try? Data(text.utf8).write(to: appearanceFile, options: .atomic)
        case .missing: try? fm.removeItem(at: appearanceFile)
        case .failed: complete = false
        }
        if complete {
            // Snippets for classes the note no longer names go.
            let named = Set(classes.map { "\($0).css" })
            for file in (try? fm.contentsOfDirectory(atPath: snippets.path)) ?? [] where !named.contains(file) {
                try? fm.removeItem(at: snippets.appendingPathComponent(file))
            }
            if let data = try? encoder.encode(Record(fetchedAt: now, classes: classes)) {
                try? data.write(to: folder.appendingPathComponent("fetched.json"), options: .atomic)
            }
        }
        return cached(classes: classes, folder: folder)
    }

    private enum Fetched {
        case found(String)
        case missing
        case failed
    }

    private static func fetch(_ path: String, client: GitHubClient) async -> Fetched {
        do {
            let text = try await client.fetchText(path: path)
            return text.utf8.count <= maxSize ? .found(text) : .missing
        } catch let error as GitHubError {
            if case .notFound = error { return .missing }
            return .failed
        } catch {
            return .failed
        }
    }

    /// A class name that can name a file: letters, digits, `-` and `_` (as `BriefHTML.cssClasses` keeps them).
    private static func isPlainName(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 64
            && name.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_") }
    }

    private static func snippetFile(_ name: String, in folder: URL) -> URL {
        folder.appendingPathComponent("snippets", isDirectory: true).appendingPathComponent("\(name).css")
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
