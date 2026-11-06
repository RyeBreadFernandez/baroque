import Foundation

enum GitHubError: LocalizedError {
    case badURL
    case http(Int, String)
    case notFound(String)
    case noToken
    case noRepository

    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad GitHub URL"
        case .http(401, _): return "GitHub rejected the token (401)"
        case .http(403, _): return "GitHub denied access (403)"
        case .http(let code, let path): return "GitHub \(code) for \(path)"
        case .notFound(let path): return "Not found: \(path)"
        case .noToken: return "No GitHub token. Add one in the Baroque app."
        case .noRepository: return "No vault repository. Add its owner and name in the Baroque app."
        }
    }
}

struct GitHubClient {
    var owner: String
    var repo: String
    var branch: String
    var token: String

    init(settings: BaroqueSettings, token: String) {
        owner = settings.githubOwner.trimmingCharacters(in: .whitespacesAndNewlines)
        repo = settings.githubRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        branch = settings.githubBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Fetches a file's raw text through the Contents API (works for private repos with a token).
    func fetchText(path: String) async throws -> String {
        let cleaned = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, !repo.isEmpty else { throw GitHubError.noRepository }
        guard !cleaned.isEmpty else { throw GitHubError.badURL }
        let encodedPath = cleaned
            .split(separator: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        var comps = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(encodedPath)")
        comps?.queryItems = [URLQueryItem(name: "ref", value: branch.isEmpty ? "main" : branch)]
        guard let url = comps?.url else { throw GitHubError.badURL }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.setValue("Baroque-Widgets", forHTTPHeaderField: "User-Agent")
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GitHubError.badURL }
        switch http.statusCode {
        case 200:
            return String(decoding: data, as: UTF8.self)
        case 404:
            throw GitHubError.notFound(cleaned)
        case 401 where token.isEmpty, 403 where token.isEmpty:
            throw GitHubError.noToken
        default:
            throw GitHubError.http(http.statusCode, cleaned)
        }
    }
}
