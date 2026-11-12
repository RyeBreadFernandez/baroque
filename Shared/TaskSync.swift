import Foundation
#if os(iOS)
import WidgetKit
#endif

/// A tap on a task's ring, kept until it's written to the vault (`Store.pendingToggles`).
struct PendingToggle: Codable, Equatable {
    var path: String
    /// The task's line as it read when tapped, when that's known (the Brief page). The widget's ticks, and ticks made
    /// again for a task the morning brief lists anew, find their line by `text` instead.
    var line: String?
    /// The task's text as TaskParser shows it: what the task is known by (`TaskToggle.key`), and the commit message.
    var text: String
    var lineNumber: Int
    /// Ticked (true) or unticked.
    var done: Bool
    var tappedAt: Date
    /// Why the last try didn't write it, and whether trying again can help (false: a token that can only read, say).
    var error: String? = nil
    var retryHelps: Bool = true

    var key: String { TaskToggle.key(text) }

    init(path: String, line: String? = nil, text: String, lineNumber: Int, done: Bool, tappedAt: Date = Date()) {
        self.path = path
        self.line = line
        self.text = text
        self.lineNumber = lineNumber
        self.done = done
        // Whole seconds, as the store's ISO 8601 dates keep it, so a tap read back is still the same tap.
        self.tappedAt = Date(timeIntervalSince1970: tappedAt.timeIntervalSince1970.rounded(.down))
    }

    /// The same tap (not a later one on the same task).
    func isSameTap(as other: PendingToggle) -> Bool {
        path == other.path && key == other.key && done == other.done && tappedAt == other.tappedAt
    }
}

/// A task ticked in the app or on the widget (`Store.doneTasks`), so it stays ticked when the morning brief lists it
/// again unticked.
struct DoneTask: Codable, Equatable {
    var path: String
    var key: String
    /// The day it was ticked, yyyy-MM-dd: the ✅ date it's given again if it's listed anew.
    var day: String
}

/// Ticking tasks off and keeping them ticked. The app's Brief page, the Today widget's tick button and the widget's
/// loader all go through here.
///
/// A tap is kept at once (`record`): the tick is remembered, the Today widgets drop the task, and the tap waits in
/// `Store.pendingToggles` until it's written (`save`, `retryPending`): one fetch and one commit per file, made with
/// `TaskToggle` and retried once if the file changed meanwhile. A tap that can't be written stays pending.
enum TaskSync {
    /// How a tap went.
    enum Outcome: Equatable {
        case saved
        /// Not written yet; trying again later can help. The reason, for the log.
        case willRetry(String)
        /// Not written, and trying again won't help until something changes: the reason, to show.
        case failed(String)
    }

    static let changedMessage = "This task changed in the vault. Pull down to refresh."
    static let retryMessage = "Not saved yet: will retry"

    // MARK: Reading tasks

    /// The tasks that are still open: drops any task that was ticked in the app or on the widget, even when the
    /// morning brief has listed it again unticked (it queues that one to be ticked in the file again).
    static func visible(_ tasks: [TaskItem]) -> [TaskItem] { visible(tasks, store: .shared) }

    static func visible(_ tasks: [TaskItem], store: Store, now: Date = Date()) -> [TaskItem] {
        lock.withLock {
            let done = Set(store.doneTasks.map { id($0.path, $0.key) })
            var pending = store.pendingToggles
            guard !done.isEmpty || !pending.isEmpty else { return tasks }
            let waiting = Dictionary(pending.map { (id($0.path, $0.key), $0.done) }, uniquingKeysWith: { $1 })
            var queued = false
            let open = tasks.filter { task in
                let tid = id(task.sourcePath, TaskToggle.key(task.text))
                if let tick = waiting[tid] { return !tick }       // a tick waiting to be written hides it already
                guard done.contains(tid) else { return true }
                // Ticked before and listed again: still ticked here, and ticked in the file again.
                pending.append(PendingToggle(path: task.sourcePath, text: task.text, lineNumber: task.lineNumber, done: true, tappedAt: now))
                queued = true
                return false
            }
            if queued { store.pendingToggles = dedupe(pending) }
            return open
        }
    }

    /// How the Brief page shows a task: ticked if the file says so, if a tick is waiting, or if it was ticked before;
    /// and the tap still waiting for it, if any.
    static func shown(_ task: Brief.TaskLine, path: String, pending: [PendingToggle], done: [DoneTask]) -> (done: Bool, pending: PendingToggle?) {
        let key = task.key
        if let tap = pending.last(where: { $0.path == path && $0.key == key }) { return (tap.done, tap) }
        if !task.done, done.contains(where: { $0.path == path && $0.key == key }) { return (true, nil) }
        return (task.done, nil)
    }

    // MARK: Ticking

    /// A tap on a task's ring, from the Brief page or the widget: kept at once, then written with any other ticks
    /// waiting in that file. Never throws.
    @discardableResult
    static func toggle(_ tap: PendingToggle, store: Store = .shared, client: GitHubClient? = nil) async -> Outcome {
        record(tap, store: store)
        return await write(tap, store: store, client: client)
    }

    /// Writes a tap already kept by `record` (with anything else waiting in its file), and says how it went.
    static func write(_ tap: PendingToggle, store: Store = .shared, client: GitHubClient? = nil) async -> Outcome {
        let outcomes = await save(path: tap.path, store: store, client: client)
        if let outcome = outcomes[tap.key] { return outcome }
        // Another write (an earlier turn, or the other process) took it: saved, unless it's still waiting.
        guard let waiting = store.pendingToggles.first(where: { $0.isSameTap(as: tap) }) else { return .saved }
        return waiting.retryHelps ? .willRetry(waiting.error ?? retryMessage) : .failed(waiting.error ?? retryMessage)
    }

    /// Keeps a tap without writing it: it waits in `pendingToggles` (replacing an earlier tap on the same task, so a
    /// tick and then an untick leave nothing to write), a tick is remembered (an untick forgets it), and a ticked task
    /// leaves the cached snapshot, so the widgets drop it at their next redraw.
    static func record(_ tap: PendingToggle, store: Store = .shared) {
        defer { reloadWidgets() }
        lock.withLock {
            var fresh = tap
            fresh.error = nil
            fresh.retryHelps = true
            store.pendingToggles = store.pendingToggles.filter { !($0.path == tap.path && $0.key == tap.key) } + [fresh]
            var done = store.doneTasks.filter { !($0.path == tap.path && $0.key == tap.key) }
            if tap.done { done.append(DoneTask(path: tap.path, key: tap.key, day: dayString(tap.tappedAt))) }
            store.doneTasks = done
            if tap.done { dropFromSnapshot(path: tap.path, key: tap.key, store: store) }
        }
    }

    /// Tries every pending tick or untick once. It never throws; whatever fails stays pending for the next try.
    /// A tap that failed for a reason the user has to fix (a token that can only read, say) waits until the token or
    /// the settings are saved again (`Store` clears the flag) or it's tapped again.
    static func retryPending() async { await retryPending(store: .shared) }

    static func retryPending(store: Store, client: GitHubClient? = nil) async {
        var paths: [String] = []
        for tap in store.pendingToggles where tap.retryHelps && !paths.contains(tap.path) { paths.append(tap.path) }
        for path in paths { _ = await save(path: path, store: store, client: client) }
    }

    /// Writes the taps waiting in one file: one fetch and at most one commit (none when the file already reads that
    /// way). The outcome of each, by key. Writes in this process take turns.
    static func save(path: String, store: Store = .shared, client: GitHubClient? = nil) async -> [String: Outcome] {
        await turns.run {
            await saveNow(path: path, store: store, client: client ?? GitHubClient(settings: store.settings, token: store.githubToken))
        }
    }

    private static func saveNow(path: String, store: Store, client: GitHubClient) async -> [String: Outcome] {
        let taps = store.pendingToggles.filter { $0.path == path }
        guard !taps.isEmpty else { return [:] }
        guard !client.token.isEmpty else { return settle(taps, error: GitHubError.noToken, store: store) }
        for attempt in 1...2 {
            do {
                let file = try await client.fetchFile(path: path)
                let plan = applying(taps, to: file.text, store: store)
                if plan.text != file.text {
                    try await client.updateFile(path: path, text: plan.text, sha: file.sha, message: commitMessage(plan.changed))
                }
                return finish(path: path, plan: plan, store: store)
            } catch GitHubError.conflict where attempt == 1 {
                continue    // the file changed since it was fetched: fetch it again and tick again, once
            } catch {
                return settle(taps, error: error, store: store)
            }
        }
        return settle(taps, error: GitHubError.conflict(path), store: store)
    }

    // MARK: Pieces

    private struct Plan {
        var text: String
        /// Each tap that found its line, with the line as it reads now.
        var found: [(tap: PendingToggle, change: TaskToggle.Change)] = []
        /// The taps that changed the file (the others found it already that way).
        var changed: [PendingToggle] = []
        /// The taps whose task isn't in the file any more, or is there twice.
        var lost: [PendingToggle] = []
    }

    private static func applying(_ taps: [PendingToggle], to markdown: String, store: Store) -> Plan {
        var plan = Plan(text: markdown)
        let remembered = store.doneTasks
        for tap in taps {
            // A tick gets the day it was first made, even when it's made again on a later day.
            let day = tap.done ? (remembered.last(where: { $0.path == tap.path && $0.key == tap.key }).flatMap { TaskParser.parseDate($0.day) } ?? tap.tappedAt) : tap.tappedAt
            let change = tap.line.flatMap { TaskToggle.change(in: plan.text, line: $0, near: tap.lineNumber, done: tap.done, today: day) }
                ?? TaskToggle.change(in: plan.text, key: tap.key, near: tap.lineNumber, done: tap.done, today: day)
            guard let change else { plan.lost.append(tap); continue }
            if change.markdown != plan.text { plan.changed.append(tap) }
            plan.text = change.markdown
            plan.found.append((tap, change))
        }
        return plan
    }

    /// After a write (or none needed): the settled taps leave the queue unless tapped again meanwhile, the Brief's
    /// copy is the file as written, ticked tasks leave the snapshot and unticked ones come back, and the widgets redraw.
    private static func finish(path: String, plan: Plan, store: Store) -> [String: Outcome] {
        lock.withLock {
            let settled = plan.found.map(\.tap) + plan.lost
            store.pendingToggles = store.pendingToggles.filter { p in !settled.contains { $0.isSameTap(as: p) } }
            if path == Brief.path(settings: store.settings) {
                store.brief = BriefSnapshot(markdown: plan.text, fetchedAt: Date())
            }
            for (tap, change) in plan.found {
                if tap.done { dropFromSnapshot(path: path, key: tap.key, store: store) }
                else { addToSnapshot(path: path, change: change, store: store) }
            }
        }
        reloadWidgets()
        var outcomes: [String: Outcome] = [:]
        for (tap, _) in plan.found { outcomes[tap.key] = .saved }
        for tap in plan.lost { outcomes[tap.key] = .failed(changedMessage) }
        return outcomes
    }

    /// A try that failed: the taps stay pending with the reason.
    private static func settle(_ taps: [PendingToggle], error: Error, store: Store) -> [String: Outcome] {
        let helps = retryHelps(error)
        let reason = error.localizedDescription
        lock.withLock {
            store.pendingToggles = store.pendingToggles.map { p in
                guard taps.contains(where: { $0.isSameTap(as: p) }) else { return p }
                var failed = p
                failed.error = reason
                failed.retryHelps = helps
                return failed
            }
        }
        var outcomes: [String: Outcome] = [:]
        for tap in taps { outcomes[tap.key] = helps ? .willRetry(reason) : .failed(reason) }
        return outcomes
    }

    /// Whether trying the same write again later can work without the user changing anything.
    static func retryHelps(_ error: Error) -> Bool {
        switch error {
        case GitHubError.readOnlyToken, GitHubError.noToken, GitHubError.noRepository, GitHubError.badURL,
             GitHubError.notFound, GitHubError.noBranch, GitHubError.http(401, _):
            return false
        default:
            return true
        }
    }

    /// `Baroque: done "<the first 50 characters>"`, or `undone`; "and N more" when one commit carries several.
    static func commitMessage(_ taps: [PendingToggle]) -> String {
        guard let first = taps.first else { return "Baroque: tasks" }
        let one = "\(first.done ? "done" : "undone") \"\(first.text.prefix(50))\""
        return taps.count == 1 ? "Baroque: \(one)" : "Baroque: \(one) and \(taps.count - 1) more"
    }

    private static func dropFromSnapshot(path: String, key: String, store: Store) {
        guard var snap = store.daySnapshot else { return }
        let before = snap.tasks.count
        snap.tasks.removeAll { $0.sourcePath == path && TaskToggle.key($0.text) == key }
        if snap.tasks.count != before { store.daySnapshot = snap }
    }

    /// An unticked task comes back to the widgets: in the agenda's order, if the agenda shows it at all.
    private static func addToSnapshot(path: String, change: TaskToggle.Change, store: Store) {
        guard var snap = store.daySnapshot,
              var item = TaskParser.parse(markdown: change.line, sourcePath: path).first else { return }
        item.lineNumber = change.lineNumber
        let key = TaskToggle.key(item.text)
        guard !snap.tasks.contains(where: { $0.sourcePath == path && TaskToggle.key($0.text) == key }) else { return }
        snap.tasks = TaskParser.todaysAgenda(snap.tasks + [item], includeUndated: store.settings.includeUndatedTasks, limit: snap.tasks.count + 1)
        store.daySnapshot = snap
    }

    private static func dedupe(_ taps: [PendingToggle]) -> [PendingToggle] {
        var seen = Set<String>()
        return taps.reversed().filter { seen.insert(id($0.path, $0.key)).inserted }.reversed()
    }

    private static func id(_ path: String, _ key: String) -> String { path + "\n" + key }

    static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func reloadWidgets() {
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Guards the read-modify-write of the stored lists within a process.
    private static let lock = NSLock()
    private static let turns = Turns()

    /// Runs writes one after another (an actor alone would let them interleave at each network call).
    private actor Turns {
        private var last: Task<Void, Never>?

        func run<T>(_ work: @escaping () async -> T) async -> T {
            let previous = last
            let next = Task { () -> T in
                await previous?.value
                return await work()
            }
            last = Task { _ = await next.value }
            return await next.value
        }
    }
}
