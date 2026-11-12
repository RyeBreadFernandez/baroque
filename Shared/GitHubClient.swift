import Foundation

enum GitHubError: LocalizedError, Equatable {
    case badURL
    case http(Int, String)
    /// The file isn't there, or the token can't see the repository (GitHub answers 404 for both).
    case notFound(String, repository: String)
    /// The branch in the settings doesn't exist in the repository.
    case noBranch(String, repository: String)
    case noToken
    case noRepository
    /// A write was refused (403 or 404 on PUT): the token can read but not write.
    case readOnlyToken
    /// A write was refused because the file changed since it was fetched (409 or 422).
    case conflict(String)
    /// The Contents API answered with something that isn't the file.
    case badContent(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad GitHub URL"
        case .http(401, _): return "GitHub rejected the token (401)"
        case .http(403, _): return "GitHub denied access (403)"
        case .http(let code, let path): return "GitHub \(code) for \(path)"
        case .notFound(let path, let repository): return "Not found: \(path) in \(repository) (or the token can't read that repository)"
        case .noBranch(let branch, let repository): return "No branch \(branch) in \(repository)"
        case .noToken: return "No GitHub token. Add one in the Baroque app."
        case .noRepository: return "No vault repository. Add its owner and name in the Baroque app."
        case .readOnlyToken:
            return "Your token can only read. In GitHub, make a fine-grained token for the vault with Contents: Read and write, and paste it in Settings."
        case .conflict(let path): return "\(path) changed on GitHub while saving"
        case .badContent(let path): return "GitHub sent something unreadable for \(path)"
        }
    }

    /// A 404's body says which 404 it is: `{"message": "No commit found for the ref X"}` is a missing branch,
    /// anything else (usually "Not Found") a missing file or a token that can't see the repository.
    static func notFound(body: Data, path: String, branch: String, repository: String) -> GitHubError {
        let message = (try? JSONDecoder().decode(Message.self, from: body))?.message ?? ""
        let prefix = "No commit found for the ref "
        if message.hasPrefix(prefix) {
            let ref = message.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            return .noBranch(ref.isEmpty ? branch : ref, repository: repository)
        }
        return .notFound(path, repository: repository)
    }

    private struct Message: Decodable { var message: String? }
}

struct GitHubClient {
    var owner: String
    var repo: String
    var branch: String
    var token: String
    /// Tests pass a session with a stubbed URLProtocol.
    var session: URLSession

    init(settings: BaroqueSettings, token: String, session: URLSession = .shared) {
        owner = settings.githubOwner.trimmingCharacters(in: .whitespacesAndNewlines)
        repo = settings.githubRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        branch = settings.githubBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    var repository: String { "\(owner)/\(repo)" }
    private var ref: String { branch.isEmpty ? "main" : branch }

    // Fetches a file's raw text through the Contents API (works for private repos with a token).
    func fetchText(path: String) async throws -> String {
        let cleaned = try clean(path)
        let req = request(try url(cleaned, withRef: true), accept: "application/vnd.github.raw+json")
        let (data, http) = try await send(req)
        if http.statusCode == 200 { return String(decoding: data, as: UTF8.self) }
        throw readError(http.statusCode, data: data, path: cleaned)
    }

    /// A file's text and its blob `sha`, which a write must name (the JSON form of the Contents API).
    func fetchFile(path: String) async throws -> (text: String, sha: String) {
        let cleaned = try clean(path)
        let req = request(try url(cleaned, withRef: true), accept: "application/vnd.github+json")
        let (data, http) = try await send(req)
        guard http.statusCode == 200 else { throw readError(http.statusCode, data: data, path: cleaned) }
        guard let file = try? JSONDecoder().decode(ContentFile.self, from: data), let sha = file.sha, !sha.isEmpty
        else { throw GitHubError.badContent(cleaned) }
        // Files over 1 MB come without their content; the raw form still has it.
        if (file.content ?? "").isEmpty, (file.size ?? 0) > 0 {
            return (try await fetchText(path: cleaned), sha)
        }
        guard file.encoding == nil || file.encoding == "base64",
              let bytes = Data(base64Encoded: file.content ?? "", options: .ignoreUnknownCharacters)
        else { throw GitHubError.badContent(cleaned) }
        return (String(decoding: bytes, as: UTF8.self), sha)
    }

    /// Replaces a file with `text` as one commit on the branch. `sha` is the blob the change was made against; GitHub
    /// refuses the write with 409 (thrown as `.conflict`) when the file has changed since.
    func updateFile(path: String, text: String, sha: String, message: String) async throws {
        let cleaned = try clean(path)
        var req = request(try url(cleaned, withRef: false), accept: "application/vnd.github+json")
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(UpdateBody(message: message, content: Data(text.utf8).base64EncodedString(), sha: sha, branch: ref))
        let (data, http) = try await send(req)
        if let error = GitHubClient.writeError(http.statusCode, data: data, path: cleaned) { throw error }
    }

    /// What a write's status means. Nil for success.
    static func writeError(_ status: Int, data: Data, path: String) -> GitHubError? {
        switch status {
        case 200, 201: return nil
        case 409, 422: return .conflict(path)
        case 403:
            // A rate limit is also a 403, and passes; a token without write access never does.
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? ""
            return message.lowercased().contains("rate limit") ? .http(403, path) : .readOnlyToken
        case 404: return .readOnlyToken
        default: return .http(status, path)
        }
    }

    // MARK: Pieces

    private struct ContentFile: Decodable {
        var sha: String?
        var content: String?
        var encoding: String?
        var size: Int?
    }

    private struct UpdateBody: Encodable {
        var message: String
        var content: String
        var sha: String
        var branch: String
    }

    private func clean(_ path: String) throws -> String {
        let cleaned = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, !repo.isEmpty else { throw GitHubError.noRepository }
        guard !cleaned.isEmpty else { throw GitHubError.badURL }
        return cleaned
    }

    private func url(_ path: String, withRef: Bool) throws -> URL {
        let encodedPath = path
            .split(separator: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        var comps = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(encodedPath)")
        if withRef { comps?.queryItems = [URLQueryItem(name: "ref", value: ref)] }
        guard let url = comps?.url else { throw GitHubError.badURL }
        return url
    }

    private func request(_ url: URL, accept: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(accept, forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.setValue("Baroque-Widgets", forHTTPHeaderField: "User-Agent")
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 20
        // A write must be made against the file as it is now, never a cached copy.
        req.cachePolicy = .reloadIgnoringLocalCacheData
        return req
    }

    private func send(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GitHubError.badURL }
        return (data, http)
    }

    private func readError(_ status: Int, data: Data, path: String) -> GitHubError {
        switch status {
        case 404: return GitHubError.notFound(body: data, path: path, branch: ref, repository: repository)
        case 401 where token.isEmpty, 403 where token.isEmpty: return .noToken
        default: return .http(status, path)
        }
    }
}
