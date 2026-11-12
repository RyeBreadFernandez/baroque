import Foundation
@testable import BaroqueCore

/// Answers every request of a stubbed session from a list of replies, in order, and keeps what was asked, so the
/// GitHub calls are tested without the network (and never against a real repository).
final class StubGitHub: URLProtocol {
    struct Reply {
        var status: Int
        var body: Data

        /// The Contents API's JSON for a file: base64 with a newline every 60 characters, as GitHub sends it.
        static func file(_ text: String, sha: String) -> Reply {
            let b64 = Data(text.utf8).base64EncodedString()
            let wrapped = stride(from: 0, to: b64.count, by: 60).map { i -> String in
                let start = b64.index(b64.startIndex, offsetBy: i)
                return String(b64[start..<(b64.index(start, offsetBy: 60, limitedBy: b64.endIndex) ?? b64.endIndex)])
            }.joined(separator: "\n")
            let json: [String: Any] = ["type": "file", "encoding": "base64", "size": text.utf8.count, "sha": sha, "content": wrapped]
            return Reply(status: 200, body: try! JSONSerialization.data(withJSONObject: json))
        }

        static func status(_ code: Int, message: String = "") -> Reply {
            Reply(status: code, body: try! JSONSerialization.data(withJSONObject: ["message": message]))
        }

        static let committed = Reply(status: 200, body: Data(#"{"content":{},"commit":{}}"#.utf8))
    }

    struct Seen {
        var method: String
        var url: URL
        var headers: [String: String]
        var body: Data?

        /// A PUT's JSON body.
        var json: [String: String] { (body.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: String]) ?? [:] }
        /// The text a PUT writes.
        var writtenText: String? { json["content"].flatMap { Data(base64Encoded: $0) }.map { String(decoding: $0, as: UTF8.self) } }
    }

    static var replies: [Reply] = []
    static var seen: [Seen] = []
    /// When set, every request fails with it (no network).
    static var failure: Error?

    static func reset() {
        replies = []
        seen = []
        failure = nil
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubGitHub.self]
        return URLSession(configuration: config)
    }

    static func client(token: String = "test-token") -> GitHubClient {
        GitHubClient(settings: settings, token: token, session: session())
    }

    static var settings: BaroqueSettings {
        var s = BaroqueSettings.default
        s.githubOwner = "someone"
        s.githubRepo = "notes"
        return s
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.read)
        Self.seen.append(Seen(method: request.httpMethod ?? "GET", url: request.url!, headers: request.allHTTPHeaderFields ?? [:], body: body))
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let reply = Self.replies.isEmpty ? Reply.status(500, message: "no reply stubbed") : Self.replies.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}
