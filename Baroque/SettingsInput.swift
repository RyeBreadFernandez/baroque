import Foundation

/// What the settings form's typed text means, checked before anything is saved: coordinates with either decimal mark,
/// and the vault repository however it was pasted. Foundation only, so ParserTests reads the same file.
enum SettingsInput {
    static let latitudes: ClosedRange<Double> = -90...90
    static let longitudes: ClosedRange<Double> = -180...180

    /// Why the form wasn't saved, in the words the status line shows.
    enum Problem: Error, Equatable {
        case latitude, longitude, repository

        var message: String {
            switch self {
            case .latitude: return "Not saved: latitude must be a number from -90 to 90, like 48.8566."
            case .longitude: return "Not saved: longitude must be a number from -180 to 180, like 2.3522."
            case .repository: return "Not saved: the repository should be an owner and a name, or a github.com link."
            }
        }
    }

    /// A latitude or longitude: "48.8566", "48,8566" (a comma for the decimal), "-118.2437". Nil when it isn't a
    /// number inside `range`.
    static func coordinate(_ text: String, range: ClosedRange<Double>) -> Double? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2212}", with: "-")   // a typographic minus
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "°", with: "")
        guard let value = Double(t), value.isFinite, range.contains(value) else { return nil }
        return value
    }

    /// The vault repository as typed: an owner and a name, `owner/name` in either field, or a github.com link (with
    /// or without `https://` and `www.`, an SSH address, a `.git` ending, or more path after the name). Empty fields
    /// stay empty. Nil when what's left isn't a GitHub owner and repository name.
    static func repository(owner: String, repo: String) -> (owner: String, repo: String)? {
        let o = pathParts(owner), r = pathParts(repo)
        var name: (owner: String, repo: String)
        if r.count >= 2 {
            name = (r[0], r[1])
        } else if o.count >= 2 {
            name = (o[0], r.first ?? o[1])
        } else {
            name = (o.first ?? "", r.first ?? "")
        }
        if name.repo.lowercased().hasSuffix(".git") { name.repo = String(name.repo.dropLast(4)) }
        guard isName(name.owner), isName(name.repo) else { return nil }
        return name
    }

    /// The form's settings with its typed coordinates applied and the repository cleaned up, or what's wrong with
    /// them. Valid coordinates set the location; both fields left empty mean no location (the widgets then ask for
    /// one instead of showing the weather somewhere else).
    static func apply(latitude: String, longitude: String, to settings: BaroqueSettings) -> Result<BaroqueSettings, Problem> {
        var s = settings
        let lat = latitude.trimmingCharacters(in: .whitespacesAndNewlines)
        let lon = longitude.trimmingCharacters(in: .whitespacesAndNewlines)
        if lat.isEmpty && lon.isEmpty {
            s.locationSet = false
        } else {
            guard let la = coordinate(lat, range: latitudes) else { return .failure(.latitude) }
            guard let lo = coordinate(lon, range: longitudes) else { return .failure(.longitude) }
            s.latitude = la
            s.longitude = lo
            s.locationSet = true
        }
        guard let name = repository(owner: s.githubOwner, repo: s.githubRepo) else { return .failure(.repository) }
        s.githubOwner = name.owner
        s.githubRepo = name.repo
        return .success(s)
    }

    /// A coordinate as the form shows it; empty until a location is set.
    static func text(_ value: Double, set: Bool) -> String {
        set ? String(format: "%.4f", value) : ""
    }

    /// The status line after a refresh. Only what was asked for counts: there is no weather request until a location
    /// is set. When nothing could be fetched it says so, rather than "Updated" over the saved data.
    static func refreshLine(day: DaySnapshot, quotes: QuoteSnapshot, weatherAsked: Bool) -> String {
        let failed = [day.taskError, weatherAsked ? day.weatherError : nil, quotes.error].compactMap { $0 }.count
        if failed == (weatherAsked ? 3 : 2) { return "Couldn't refresh; showing saved data." }
        var parts = ["\(day.tasks.count) task(s)"]
        if let w = day.weather { parts.append("\(Int(w.temperature.rounded()))° \(w.label)") }
        parts.append("\(quotes.quotes.count) quote(s)")
        return (failed > 0 ? "Updated, with errors: " : "Updated: ") + parts.joined(separator: ", ")
    }

    /// The path parts of a field, without a github.com prefix: "https://github.com/a/b/tree/main" gives a, b, tree, main.
    private static func pathParts(_ field: String) -> [String] {
        var t = field.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://", "http://", "ssh://", "git@", "www.", "github.com/", "github.com:"] {
            if t.lowercased().hasPrefix(prefix) { t = String(t.dropFirst(prefix.count)) }
        }
        return t.split(separator: "/").map(String.init)
    }

    /// Letters, digits, '-', '_' and '.', as GitHub allows in owner and repository names; empty is allowed too.
    private static func isName(_ s: String) -> Bool {
        guard s != ".", s != ".." else { return false }
        return s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) }
    }
}
