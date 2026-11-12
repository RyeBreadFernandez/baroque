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

    // MARK: Tasks worded alike, outside the brief

    private let inbox = "Tasks/Inbox.md"

    private func useInbox(_ md: String) -> [TaskItem] {
        let tasks = TaskParser.parse(markdown: md, sourcePath: inbox)
        store.daySnapshot = DaySnapshot(date: Date(), weather: nil, tasks: tasks, taskError: nil, weatherError: nil)
        return tasks
    }

    func testOneTapTicksOneOfTwoTasksWordedAlike() async {
        let md = "# Inbox\n- [ ] Call the dentist 📅 2026-11-11\n- [ ] Call the dentist 📅 2026-11-20\n"
        let tasks = useInbox(md)
        let tap = PendingToggle(tasks[0], tappedAt: nine)       // from the widget: no line, but its due date
        TaskSync.record(tap, store: store)
        XCTAssertEqual(snapshotTexts, ["Call the dentist"], "one task left on the widget")
        XCTAssertEqual(store.daySnapshot?.tasks.first?.due, TaskParser.parseDate("2026-11-20"))
        XCTAssertEqual(TaskSync.visible(TaskParser.parse(markdown: md, sourcePath: inbox), store: store).map(\.lineNumber), [3])

        StubGitHub.replies = [.file(md, sha: "s1"), .committed]
        await TaskSync.retryPending(store: store, client: StubGitHub.client())
        XCTAssertEqual(StubGitHub.seen.last?.writtenText,
                       "# Inbox\n- [x] Call the dentist 📅 2026-11-11 ✅ 2026-11-11\n- [ ] Call the dentist 📅 2026-11-20\n")
        XCTAssertEqual(store.daySnapshot?.tasks.map(\.lineNumber), [3], "the other one stays")
        XCTAssertTrue(store.doneTasks.isEmpty, "not remembered outside the brief")
        // Read again, the other one is still open.
        let after = TaskParser.parse(markdown: StubGitHub.seen.last?.writtenText ?? "", sourcePath: inbox)
        XCTAssertEqual(TaskSync.visible(after, store: store).map(\.lineNumber), [3])
    }

    func testTwoTapsOnTasksWordedAlikeAreTwoTicks() {
        let tasks = useInbox("- [ ] Water the ferns\n- [ ] Water the ferns\n")
        TaskSync.record(PendingToggle(tasks[0], tappedAt: nine), store: store)
        TaskSync.record(PendingToggle(tasks[1], tappedAt: nine), store: store)
        XCTAssertEqual(store.pendingToggles.map(\.lineNumber), [1, 2], "the second tap doesn't replace the first")
        XCTAssertTrue(snapshotTexts.isEmpty)
    }

    func testAfterALineAboveIsDeletedAWidgetTapTicksTheRightDate() async {
        let before = "- [ ] Feed the cat\n- [ ] Call the dentist 📅 2026-11-11\n- [ ] Call the dentist 📅 2026-11-20"
        let tap = PendingToggle(useInbox(before)[1], tappedAt: nine)    // the 11th, drawn at line 2
        // Line 1 was deleted in Obsidian since: line 2 is now the 20th.
        let now = "- [ ] Call the dentist 📅 2026-11-11\n- [ ] Call the dentist 📅 2026-11-20"
        StubGitHub.replies = [.file(now, sha: "s1"), .committed]
        let outcome = await TaskSync.toggle(tap, store: store, client: StubGitHub.client())
        XCTAssertEqual(outcome, .saved)
        XCTAssertEqual(StubGitHub.seen.last?.writtenText,
                       "- [x] Call the dentist 📅 2026-11-11 ✅ 2026-11-11\n- [ ] Call the dentist 📅 2026-11-20")
    }

    func testTasksThatCantBeToldApartAreNotGuessed() async {
        let tap = PendingToggle(path: inbox, text: "Call the dentist", lineNumber: 9, due: TaskParser.parseDate("2026-11-11"), done: true, tappedAt: nine)
        let md = "- [ ] Call the dentist 📅 2026-11-11\n- [ ] Call the dentist 📅 2026-11-11"
        StubGitHub.replies = [.file(md, sha: "s1")]
        let outcome = await TaskSync.toggle(tap, store: store, client: StubGitHub.client())
        XCTAssertEqual(outcome, .failed(TaskSync.changedMessage))
        XCTAssertEqual(StubGitHub.seen.map(\.method), ["GET"], "nothing written")
    }

    func testNextMonthsTaskOutsideTheBriefIsNotTickedAgain() async {
        let bills = "Tasks/Bills.md"
        let november = "- [ ] Pay rent 📅 2026-11-01"
        let task = TaskParser.parse(markdown: november, sourcePath: bills)[0]
        StubGitHub.replies = [.file(november, sha: "s1"), .committed]
        let outcome = await TaskSync.toggle(PendingToggle(task, tappedAt: nine), store: store, client: StubGitHub.client())
        XCTAssertEqual(outcome, .saved)
        XCTAssertTrue(store.doneTasks.isEmpty, "only the Daily Brief's ticks are remembered")

        // A month on, the file lists December's.
        let december = TaskParser.parse(markdown: "- [x] Pay rent 📅 2026-11-01 ✅ 2026-11-11\n- [ ] Pay rent 📅 2026-12-01", sourcePath: bills)
        XCTAssertEqual(TaskSync.visible(december, store: store).map(\.text), ["Pay rent"])
        // Even with a tick remembered there by an earlier version.
        store.doneTasks = [DoneTask(path: bills, key: "Pay rent", day: "2026-11-11")]
        XCTAssertEqual(TaskSync.visible(december, store: store).map(\.text), ["Pay rent"])
        XCTAssertTrue(store.pendingToggles.isEmpty, "nothing queued")
        let line = Brief.TaskLine(text: "Pay rent", done: false, lineNumber: 2, line: "- [ ] Pay rent 📅 2026-12-01")
        XCTAssertEqual(TaskSync.shown(line, path: bills, pending: [], done: store.doneTasks).done, false)
    }

    func testOnlyTheBriefsTicksAreRemembered() {
        TaskSync.record(tick(), store: store)
        TaskSync.record(PendingToggle(path: inbox, text: "Feed the cat", lineNumber: 1, done: true, tappedAt: nine), store: store)
        XCTAssertEqual(store.doneTasks, [DoneTask(path: path, key: "Water the ferns", day: "2026-11-11")])
    }

    func testARelistedBriefTaskWithADueDateIsQueuedWithIt() {
        store.doneTasks = [DoneTask(path: path, key: "Water the ferns", day: "2026-11-10")]
        let listed = TaskParser.parse(markdown: "## Needs attention\n- [ ] #todo Water the ferns 📅 2026-11-12", sourcePath: path)
        XCTAssertTrue(TaskSync.visible(listed, store: store).isEmpty)
        XCTAssertEqual(store.pendingToggles.first?.due, TaskParser.parseDate("2026-11-12"))
    }

    // MARK: Repeating tasks

    private let repeatingBrief = "# November 11\n\n## Needs attention\n- [ ] #todo Water the ferns 🔁 every day\n"

    func testATapOnARepeatingTaskIsRefusedAndTheTaskStays() async {
        let tasks = TaskParser.parse(markdown: repeatingBrief, sourcePath: path)
        XCTAssertEqual(tasks.map(\.repeats), [true])
        store.daySnapshot = DaySnapshot(date: Date(), weather: nil, tasks: tasks, taskError: nil, weatherError: nil)

        // From an older widget timeline that still had a button on it.
        let outcome = await TaskSync.toggle(PendingToggle(tasks[0], tappedAt: nine), store: store, client: StubGitHub.client())
        XCTAssertEqual(outcome, .failed(TaskSync.repeatsMessage))
        XCTAssertTrue(StubGitHub.seen.isEmpty, "nothing read or written")
        XCTAssertEqual(snapshotTexts, ["Water the ferns"], "still on the widget")
        XCTAssertTrue(store.pendingToggles.isEmpty)
        XCTAssertTrue(store.doneTasks.isEmpty)

        // A tap that carries the line (the Brief page's) is refused the same way.
        let fromPage = PendingToggle(path: path, line: "- [ ] #todo Water the ferns 🔁 every day", text: "Water the ferns", lineNumber: 4, done: true, tappedAt: nine)
        TaskSync.record(fromPage, store: store)
        XCTAssertTrue(store.pendingToggles.isEmpty)
        let written = await TaskSync.write(fromPage, store: store, client: StubGitHub.client())
        XCTAssertEqual(written, .failed(TaskSync.repeatsMessage))
        XCTAssertTrue(StubGitHub.seen.isEmpty)
    }

    func testARepeatingLineOnlyTheFileShowsIsNotTicked() async {
        // A snapshot cached before tasks knew they repeat: only the file can tell.
        let old = TaskItem(text: "Water the ferns", due: nil, priority: .none, sourcePath: path, lineNumber: 4)
        store.daySnapshot = DaySnapshot(date: Date(), weather: nil, tasks: [old], taskError: nil, weatherError: nil)
        StubGitHub.replies = [.file(repeatingBrief, sha: "s1")]
        let outcome = await TaskSync.toggle(PendingToggle(old, tappedAt: nine), store: store, client: StubGitHub.client())
        XCTAssertEqual(outcome, .failed(TaskSync.repeatsMessage))
        XCTAssertEqual(StubGitHub.seen.map(\.method), ["GET"], "never written")
        XCTAssertTrue(store.pendingToggles.isEmpty)
        XCTAssertTrue(store.doneTasks.isEmpty, "not remembered")
        XCTAssertEqual(snapshotTexts, ["Water the ferns"], "back on the widget")
        XCTAssertEqual(store.daySnapshot?.tasks.first?.repeats, true)
    }

    func testARepeatingTaskIsNeverHidden() {
        store.doneTasks = [DoneTask(path: path, key: "Water the ferns", day: "2026-11-10")]
        let listed = TaskParser.parse(markdown: repeatingBrief, sourcePath: path)
        XCTAssertEqual(TaskSync.visible(listed, store: store).count, 1)
        XCTAssertTrue(store.pendingToggles.isEmpty, "not queued to be ticked")
        // Nor by a tick left waiting by an earlier version.
        store.pendingToggles = [PendingToggle(path: path, text: "Water the ferns", lineNumber: 4, done: true, tappedAt: nine)]
        XCTAssertEqual(TaskSync.visible(listed, store: store).count, 1)
        // The Brief page shows it as the file has it.
        let line = Brief.TaskLine(text: "Water the ferns", done: false, lineNumber: 4, line: "- [ ] #todo Water the ferns 🔁 every day")
        XCTAssertTrue(line.repeats)
        let shown = TaskSync.shown(line, path: path, pending: store.pendingToggles, done: store.doneTasks)
        XCTAssertFalse(shown.done)
        XCTAssertNil(shown.pending)
    }

    func testASnapshotCachedBeforeRepeatsStillReads() {
        let json = """
        {"date":"2026-11-11T17:00:00Z","tasks":[{"text":"Water the ferns","priority":2,"sourcePath":"\(path)","lineNumber":7}]}
        """
        defaults.set(Data(json.utf8), forKey: "baroque.daySnapshot")
        XCTAssertEqual(store.daySnapshot?.tasks.map(\.text), ["Water the ferns"])
        XCTAssertEqual(store.daySnapshot?.tasks.first?.repeats, false)
    }

    // MARK: Stored ticks

    func testStoredTicksDecodeOneByOne() {
        // A tap saved before `retryHelps` existed, one that can't be read, and one that waits for a better token.
        let taps = """
        [{"path":"\(path)","text":"Water the ferns","lineNumber":7,"done":true,"tappedAt":"2026-11-11T17:00:00Z"},
         {"path":"\(path)","lineNumber":"seven"},
         {"path":"\(path)","text":"Call the bike shop","lineNumber":9,"done":true,"tappedAt":"2026-11-11T17:00:00Z",
          "error":"Your token can only read.","retryHelps":false}]
        """
        defaults.set(Data(taps.utf8), forKey: "baroque.pendingToggles")
        XCTAssertEqual(store.pendingToggles.map(\.text), ["Water the ferns", "Call the bike shop"])
        XCTAssertEqual(store.pendingToggles.map(\.retryHelps), [true, false])

        let done = """
        [{"path":"\(path)","key":"Water the ferns","day":"2026-11-10"},{"path":3},{"path":"\(path)","key":"Call the bike shop","day":"2026-11-11"}]
        """
        defaults.set(Data(done.utf8), forKey: "baroque.doneTasks")
        XCTAssertEqual(store.doneTasks.map(\.key), ["Water the ferns", "Call the bike shop"])
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
