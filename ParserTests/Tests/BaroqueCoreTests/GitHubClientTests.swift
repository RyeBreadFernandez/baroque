import Foundation
import XCTest
@testable import BaroqueCore

final class GitHubClientTests: XCTestCase {
    override func setUp() { StubGitHub.reset() }
    override func tearDown() { StubGitHub.reset() }

    private let path = "Daily Brief/Today.md"

    func testFetchFileDecodesTheContentAndSha() async throws {
        let text = "# Today\r\n- [ ] Water the ferns ✅ and more text, long enough to wrap the base64 over several lines\r\n"
        StubGitHub.replies = [.file(text, sha: "abc123")]
        let file = try await StubGitHub.client().fetchFile(path: path)
        XCTAssertEqual(file.text, text)
        XCTAssertEqual(file.sha, "abc123")
        let get = try XCTUnwrap(StubGitHub.seen.first)
        XCTAssertEqual(get.method, "GET")
        XCTAssertEqual(get.url.absoluteString, "https://api.github.com/repos/someone/notes/contents/Daily%20Brief/Today.md?ref=main")
        XCTAssertEqual(get.headers["Accept"], "application/vnd.github+json")
        XCTAssertEqual(get.headers["Authorization"], "Bearer test-token")
    }

    func testUpdateFilePutsTheShaAndBase64Content() async throws {
        StubGitHub.replies = [.committed]
        let text = "- [x] Water the ferns ✅ 2026-11-11\n"
        try await StubGitHub.client().updateFile(path: path, text: text, sha: "abc123", message: #"Baroque: done "Water the ferns""#)
        let put = try XCTUnwrap(StubGitHub.seen.first)
        XCTAssertEqual(put.method, "PUT")
        XCTAssertEqual(put.url.absoluteString, "https://api.github.com/repos/someone/notes/contents/Daily%20Brief/Today.md")
        XCTAssertEqual(put.json["sha"], "abc123")
        XCTAssertEqual(put.json["branch"], "main")
        XCTAssertEqual(put.json["message"], #"Baroque: done "Water the ferns""#)
        XCTAssertEqual(put.writtenText, text)
    }

    func testAForbiddenWriteSaysTheTokenCanOnlyRead() async {
        for reply in [StubGitHub.Reply.status(403, message: "Resource not accessible by personal access token"), .status(404, message: "Not Found")] {
            StubGitHub.replies = [reply]
            do {
                try await StubGitHub.client().updateFile(path: path, text: "x", sha: "abc", message: "m")
                XCTFail("expected an error")
            } catch {
                XCTAssertEqual(error as? GitHubError, .readOnlyToken)
                XCTAssertEqual(error.localizedDescription,
                               "Your token can only read. In GitHub, make a fine-grained token for the vault with Contents: Read and write, and paste it in Settings.")
            }
        }
    }

    func testWriteStatuses() {
        XCTAssertNil(GitHubClient.writeError(200, data: Data(), path: path))
        XCTAssertNil(GitHubClient.writeError(201, data: Data(), path: path))
        XCTAssertEqual(GitHubClient.writeError(409, data: Data(), path: path), .conflict(path))
        XCTAssertEqual(GitHubClient.writeError(422, data: Data(), path: path), .conflict(path))
        let limited = Data(#"{"message":"API rate limit exceeded for user"}"#.utf8)
        XCTAssertEqual(GitHubClient.writeError(403, data: limited, path: path), .http(403, path))
    }

    // MARK: F34: which 404

    func testA404SaysWhichKind() {
        let noRef = Data(#"{"message":"No commit found for the ref nope","documentation_url":"https://docs.github.com","status":"404"}"#.utf8)
        let branch = GitHubError.notFound(body: noRef, path: path, branch: "nope", repository: "someone/notes")
        XCTAssertEqual(branch, .noBranch("nope", repository: "someone/notes"))
        XCTAssertEqual(branch.localizedDescription, "No branch nope in someone/notes")

        let missing = GitHubError.notFound(body: Data(#"{"message":"Not Found"}"#.utf8), path: path, branch: "main", repository: "someone/notes")
        XCTAssertEqual(missing.localizedDescription, "Not found: Daily Brief/Today.md in someone/notes (or the token can't read that repository)")
        XCTAssertEqual(GitHubError.notFound(body: Data(), path: path, branch: "main", repository: "someone/notes"), missing)
    }

    func testFetchTextMapsA404() async {
        StubGitHub.replies = [.status(404, message: "No commit found for the ref drafts")]
        do {
            _ = try await StubGitHub.client().fetchText(path: path)
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "No branch drafts in someone/notes")
        }
    }
}
