import Foundation
import XCTest
@testable import BaroqueCore

/// Ticking through TaskSync, against a stubbed GitHub and a throwaway defaults suite (never the app's own).
final class TaskSyncTests: XCTestCase {
    private let suite = "BaroqueParserTests.TaskSync"
    private var defaults: UserDefaults!
    private var store: Store!
    private let path = BaroqueSettings.dailyBriefPath
    private let nine = day(2026, 11, 11, hour: 9)

    private let brief = """
    ---
    generated: 2026-11-11 05:40 PT
    ---
    # November 11

    ## Needs attention
    - [ ] #todo Water the ferns
    - [ ] #todo Return the library books (Library, email, Nov 4)
    - [ ] #todo Call the bike shop

    ## Notes
    - The seed order arrives next week.
    """

    override func setUp() {
        StubGitHub.reset()
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)!
        store = Store(defaults: defaults)
        store.settings = StubGitHub.settings
        store.daySnapshot = DaySnapshot(date: Date(), weather: nil, tasks: TaskParser.parse(markdown: brief, sourcePath: path),
                                        taskError: nil, weatherError: nil)
    }

    override func tearDown() {
        StubGitHub.reset()
        defaults.removePersistentDomain(forName: suite)
    }

    private func tick(_ text: String = "Water the ferns", line: String? = "- [ ] #todo Water the ferns", at lineNumber: Int = 7) -> PendingToggle {
        PendingToggle(path: path, line: line, text: text, lineNumber: lineNumber, done: true, tappedAt: nine)
    }

    private func ticked(_ md: String, _ line: String = "- [ ] #todo Water the ferns", on date: String = "2026-11-11") -> String {
        md.replacingOccurrences(of: line, with: line.replacingOccurrences(of: "- [ ]", with: "- [x]") + " ✅ " + date)
    }

    private var snapshotTexts: [String] { store.daySnapshot?.tasks.map(\.text) ?? [] }

    // MARK: Writing a tick

    func testATickIsWrittenAndTheTaskLeavesTheWidgets() async throws {
        StubGitHub.replies = [.file(brief, sha: "s1"), .committed]
        let outcome = await TaskSync.toggle(tick(), store: store, client: StubGitHub.client())
        XCTAssertEqual(outcome, .saved)
        XCTAssertEqual(StubGitHub.seen.map(\.method), ["GET", "PUT"])
        let put = StubGitHub.seen[1]
        XCTAssertEqual(put.json["sha"], "s1")
        XCTAssertEqual(put.json["message"], #"Baroque: done "Water the ferns""#)
        XCTAssertEqual(put.writtenText, ticked(brief))
        XCTAssertTrue(store.pendingToggles.isEmpty)
        XCTAssertEqual(store.doneTasks, [DoneTask(path: path, key: "Water the ferns", day: "2026-11-11")])
        XCTAssertEqual(snapshotTexts, ["Return the library books (Library, email, Nov 4)", "Call the bike shop"])
        XCTAssertEqual(store.brief?.markdown, ticked(brief))
    }

    func testAConflictFetchesAgainAndRetriesOnce() async {
        let moved = "- [ ] #todo Something new\n" + brief
        StubGitHub.replies = [.file(brief, sha: "s1"), .status(409, message: "is at s2 but expected s1"), .file(moved, sha: "s2"), .committed]
        let outcome = await TaskSync.toggle(tick(), store: store, client: StubGitHub.client())
        XCTAssertEqual(outcome, .saved)
        XCTAssertEqual(StubGitHub.seen.map(\.method), ["GET", "PUT", "GET", "PUT"])
        XCTAssertEqual(StubGitHub.seen[3].json["sha"], "s2")
        XCTAssertEqual(StubGitHub.seen[3].writtenText, ticked(moved))
    }

    func testASecondConflictWaitsForTheNextTry() async {
        StubGitHub.replies = [.file(brief, sha: "s1"), .status(409), .file(brief, sha: "s2"), .status(409)]
        let outcome = await TaskSync.toggle(tick(), store: store, client: StubGitHub.client())
        guard case .willRetry = outcome else { return XCTFail("\(outcome)") }
        XCTAssertEqual(StubGitHub.seen.count, 4)
        XCTAssertEqual(store.pendingToggles.count, 1)
        XCTAssertEqual(store.pendingToggles.first?.retryHelps, true)
    }

    func testAReadOnlyTokenSaysSoAndTheTickStays() async {
        StubGitHub.replies = [.file(brief, sha: "s1"), .status(403, message: "Resource not accessible by personal access token")]
        let outcome = await TaskSync.toggle(tick(), store: store, client: StubGitHub.client())
        XCTAssertEqual(outcome, .failed(GitHubError.readOnlyToken.localizedDescription))
        XCTAssertEqual(store.pendingToggles.count, 1)
        XCTAssertEqual(store.pendingToggles.first?.retryHelps, false)
        XCTAssertEqual(store.pendingToggles.first?.error, GitHubError.readOnlyToken.localizedDescription)
        XCTAssertFalse(snapshotTexts.contains("Water the ferns"), "still ticked on the widget")
        XCTAssertEqual(store.doneTasks.count, 1)
    }

    func testAReadOnlyTickIsNotRetriedUntilTheSettingsChange() async {
        StubGitHub.replies = [.file(brief, sha: "s1"), .status(403)]
        await TaskSync.toggle(tick(), store: store, client: StubGitHub.client())
        StubGitHub.reset()
        await TaskSync.retryPending(store: store, client: StubGitHub.client())
        XCTAssertTrue(StubGitHub.seen.isEmpty, "not retried")

        store.settings = StubGitHub.settings        // Save & Refresh, after making a token that can write
        StubGitHub.replies = [.file(brief, sha: "s1"), .committed]
        await TaskSync.retryPending(store: store, client: StubGitHub.client())
        XCTAssertEqual(StubGitHub.seen.map(\.method), ["GET", "PUT"])
        XCTAssertTrue(store.pendingToggles.isEmpty)
    }

    func testOfflineTheTickWaitsThenRetryWritesIt() async {
        StubGitHub.failure = URLError(.notConnectedToInternet)
        let outcome = await TaskSync.toggle(tick(), store: store, client: StubGitHub.client())
        guard case .willRetry = outcome else { return XCTFail("\(outcome)") }
        XCTAssertEqual(store.pendingToggles.count, 1)
        XCTAssertFalse(snapshotTexts.contains("Water the ferns"))

        StubGitHub.reset()
        StubGitHub.replies = [.file(brief, sha: "s1"), .committed]
        await TaskSync.retryPending(store: store, client: StubGitHub.client())
        XCTAssertEqual(StubGitHub.seen.map(\.method), ["GET", "PUT"])
        XCTAssertTrue(store.pendingToggles.isEmpty)
    }

    func testNoTokenWritesNothing() async {
        let outcome = await TaskSync.toggle(tick(), store: store, client: StubGitHub.client(token: ""))
        XCTAssertEqual(outcome, .failed(GitHubError.noToken.localizedDescription))
        XCTAssertTrue(StubGitHub.seen.isEmpty)
        XCTAssertEqual(store.pendingToggles.count, 1)
    }

    func testATaskThatChangedSaysSo() async {
        StubGitHub.replies = [.file("# November 11\n- [ ] #todo Something else\n", sha: "s1")]
        let outcome = await TaskSync.toggle(tick(), store: store, client: StubGitHub.client())
        XCTAssertEqual(outcome, .failed(TaskSync.changedMessage))
        XCTAssertEqual(StubGitHub.seen.map(\.method), ["GET"])
        XCTAssertTrue(store.pendingToggles.isEmpty)
    }

    func testAnUntickIsWrittenAndTheTaskComesBack() async {
        let done = ticked(brief, on: "2026-11-10")
        store.daySnapshot?.tasks.removeAll { $0.text == "Water the ferns" }
        StubGitHub.replies = [.file(done, sha: "s1"), .committed]
        let untick = PendingToggle(path: path, line: "- [x] #todo Water the ferns ✅ 2026-11-10", text: "Water the ferns", lineNumber: 7, done: false, tappedAt: nine)
        let outcome = await TaskSync.toggle(untick, store: store, client: StubGitHub.client())
        XCTAssertEqual(outcome, .saved)
        XCTAssertEqual(StubGitHub.seen.last?.writtenText, brief)
        XCTAssertEqual(StubGitHub.seen.last?.json["message"], #"Baroque: undone "Water the ferns""#)
        XCTAssertTrue(snapshotTexts.contains("Water the ferns"))
    }

    func testTickThenUntickWritesNothing() async {
        TaskSync.record(tick(), store: store)
        TaskSync.record(PendingToggle(path: path, line: "- [ ] #todo Water the ferns", text: "Water the ferns", lineNumber: 7, done: false, tappedAt: nine), store: store)
        XCTAssertEqual(store.pendingToggles.count, 1, "the untick replaced the tick")
        XCTAssertTrue(store.doneTasks.isEmpty)
        StubGitHub.replies = [.file(brief, sha: "s1")]
        await TaskSync.retryPending(store: store, client: StubGitHub.client())
        XCTAssertEqual(StubGitHub.seen.map(\.method), ["GET"], "no commit")
        XCTAssertTrue(store.pendingToggles.isEmpty)
        XCTAssertTrue(snapshotTexts.contains("Water the ferns"))
    }

    func testSeveralTicksInOneFileAreOneCommit() async {
        TaskSync.record(tick(), store: store)
        TaskSync.record(tick("Call the bike shop", line: "- [ ] #todo Call the bike shop", at: 9), store: store)
        StubGitHub.replies = [.file(brief, sha: "s1"), .committed]
        await TaskSync.retryPending(store: store, client: StubGitHub.client())
        XCTAssertEqual(StubGitHub.seen.map(\.method), ["GET", "PUT"])
        XCTAssertEqual(StubGitHub.seen[1].json["message"], #"Baroque: done "Water the ferns" and 1 more"#)
        XCTAssertEqual(StubGitHub.seen[1].writtenText, ticked(ticked(brief), "- [ ] #todo Call the bike shop"))
    }

    func testCommitMessageKeepsTheFirstFiftyCharacters() {
        let long = String(repeating: "abcdefghij", count: 7)
        let tap = PendingToggle(path: path, text: long, lineNumber: 1, done: true)
        XCTAssertEqual(TaskSync.commitMessage([tap]), "Baroque: done \"\(long.prefix(50))\"")
    }

    // MARK: Ticks stay ticked

    func testATaskListedAgainIsHiddenAndTickedAgain() async {
        store.doneTasks = [DoneTask(path: path, key: "Water the ferns", day: "2026-11-10")]
        let listed = TaskParser.parse(markdown: brief, sourcePath: path)
        XCTAssertEqual(TaskSync.visible(listed, store: store).map(\.text),
                       ["Return the library books (Library, email, Nov 4)", "Call the bike shop"])
        XCTAssertEqual(store.pendingToggles.count, 1)
        XCTAssertEqual(store.pendingToggles.first?.done, true)
        XCTAssertEqual(store.pendingToggles.first?.lineNumber, 7)
        XCTAssertNil(store.pendingToggles.first?.line)
        _ = TaskSync.visible(listed, store: store)
        XCTAssertEqual(store.pendingToggles.count, 1, "queued once")

        StubGitHub.replies = [.file(brief, sha: "s1"), .committed]
        await TaskSync.retryPending(store: store, client: StubGitHub.client())
        XCTAssertEqual(StubGitHub.seen.last?.writtenText, ticked(brief, on: "2026-11-10"), "ticked with the day it was first ticked")
        XCTAssertTrue(store.pendingToggles.isEmpty)
    }

    func testOnlyTheSameFileCounts() {
        store.doneTasks = [DoneTask(path: path, key: "Water the ferns", day: "2026-11-10")]
        let elsewhere = TaskItem(text: "Water the ferns", due: nil, priority: .none, sourcePath: "Tasks/Inbox.md", lineNumber: 3)
        XCTAssertEqual(TaskSync.visible([elsewhere], store: store), [elsewhere])
        XCTAssertTrue(store.pendingToggles.isEmpty)
    }

    func testTheKeyIgnoresDatesPriorityAndSpacing() {
        store.doneTasks = [DoneTask(path: path, key: TaskToggle.key(ofLine: "- [x] Pay  rent ⏫ 📅 2026-11-12 ✅ 2026-11-11")!, day: "2026-11-11")]
        let again = TaskParser.parse(markdown: "- [ ] #todo Pay rent 🔽 📅 2026-12-01", sourcePath: path)
        XCTAssertTrue(TaskSync.visible(again, store: store).isEmpty)
    }

    func testAnUntickForgetsTheTask() {
        TaskSync.record(tick(), store: store)
        TaskSync.record(PendingToggle(path: path, line: "- [x] #todo Water the ferns ✅ 2026-11-11", text: "Water the ferns", lineNumber: 7, done: false), store: store)
        XCTAssertTrue(store.doneTasks.isEmpty)
        let listed = TaskParser.parse(markdown: brief, sourcePath: path)
        XCTAssertEqual(TaskSync.visible(listed, store: store).count, 3)
    }

    func testTheNewest500AreKept() {
        store.doneTasks = (0..<499).map { DoneTask(path: path, key: "Task \($0)", day: "2026-11-01") }
        for i in 0..<3 { TaskSync.record(tick("New \(i)", line: nil, at: 1), store: store) }
        let kept = store.doneTasks
        XCTAssertEqual(kept.count, 500)
        XCTAssertEqual(kept.first?.key, "Task 2")
        XCTAssertEqual(kept.last?.key, "New 2")
    }

    func testTheBriefPageShowsWaitingAndRememberedTicks() {
        let line = Brief.TaskLine(text: "Water the ferns", done: false, lineNumber: 7, line: "- [ ] #todo Water the ferns")
        XCTAssertEqual(TaskSync.shown(line, path: path, pending: [], done: []).done, false)
        XCTAssertEqual(TaskSync.shown(line, path: path, pending: [tick()], done: []).done, true)
        XCTAssertEqual(TaskSync.shown(line, path: path, pending: [], done: [DoneTask(path: path, key: "Water the ferns", day: "2026-11-10")]).done, true)
        var doneLine = line
        doneLine.done = true
        let untick = PendingToggle(path: path, text: "Water the ferns", lineNumber: 7, done: false)
        XCTAssertEqual(TaskSync.shown(doneLine, path: path, pending: [untick], done: []).done, false)
    }
}
