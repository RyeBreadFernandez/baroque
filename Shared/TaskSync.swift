import Foundation
#if os(iOS)
import WidgetKit
#endif

/// A tap on a task's ring, kept until it's written to the vault (`Store.pendingToggles`).
struct PendingToggle: Codable, Equatable {
    var path: String
    /// The task's line as it read when tapped, when that's known (the Brief page). The widget's ticks, and ticks made
    /// again for a task the morning brief lists anew, find their line by `text` and `due` instead.
    var line: String?
    /// The task's text as TaskParser shows it: what the task is known by (`TaskToggle.key`), and the commit message.
    var text: String
    var lineNumber: Int
    /// The task's due date (📅), nil when it has none: it tells apart lines with the same words when `line` isn't
    /// known (two "Call the dentist" on different days, say).
    var due: Date?
    /// Ticked (true) or unticked.
    var done: Bool
    var tappedAt: Date
    /// Why the last try didn't write it, and whether trying again can help (false: a token that can only read, say).
    var error: String? = nil
    var retryHelps: Bool = true

    var key: String { TaskToggle.key(text) }

    init(path: String, line: String? = nil, text: String, lineNumber: Int, due: Date? = nil, done: Bool, tappedAt: Date = Date()) {
        self.path = path
        self.line = line
        self.text = text
        self.lineNumber = lineNumber
        self.due = due
        self.done = done
        // Whole seconds, as the store's ISO 8601 dates keep it, so a tap read back is still the same tap.
        self.tappedAt = Date(timeIntervalSince1970: tappedAt.timeIntervalSince1970.rounded(.down))
    }

    /// A tap on a task as the widgets list it.
    init(_ task: TaskItem, done: Bool = true, tappedAt: Date = Date()) {
        self.init(path: task.sourcePath, text: task.text, lineNumber: task.lineNumber, due: task.due, done: done, tappedAt: tappedAt)
    }

    /// The same tap (not a later one on the same task).
    func isSameTap(as other: PendingToggle) -> Bool {
        path == other.path && key == other.key && lineNumber == other.lineNumber && done == other.done && tappedAt == other.tappedAt
    }

    /// A tap on the same task, which a later tap replaces: the same file, words, line and due date. Two tasks worded
    /// alike are two tasks.
    func isSameTask(as other: PendingToggle) -> Bool {
        path == other.path && key == other.key && lineNumber == other.lineNumber && TaskToggle.sameDue(due, other.due)
    }
}

extension PendingToggle {
    /// Saved taps decode field by field, so a field added in a later version takes its default (`due` nil,
    /// `retryHelps` true) instead of making the tap unreadable.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        path = try c.decode(String.self, forKey: .path)
        line = try c.decodeIfPresent(String.self, forKey: .line)
        text = try c.decode(String.self, forKey: .text)
        lineNumber = try c.decode(Int.self, forKey: .lineNumber)
        due = try? c.decodeIfPresent(Date.self, forKey: .due)
        done = try c.decode(Bool.self, forKey: .done)
        tappedAt = try c.decode(Date.self, forKey: .tappedAt)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        retryHelps = try c.decodeIfPresent(Bool.self, forKey: .retryHelps) ?? true
    }
}

/// A task ticked in the Daily Brief (`Store.doneTasks`), so it stays ticked when the morning brief lists it again
/// unticked.
struct DoneTask: Codable, Equatable {
    var path: String
    var key: String
    /// The day it was ticked, yyyy-MM-dd: the ✅ date it's given again if it's listed anew.
    var day: String
}

/// Ticking tasks off and keeping them ticked. The app's Brief page, the Today widget's tick button and the widget's
/// loader all go through here.
///
/// A tap is kept at once (`record`): the Today widgets drop the task, and the tap waits in `Store.pendingToggles`
/// until it's written (`save`, `retryPending`): one fetch and one commit per file, made with `TaskToggle` and retried
/// once if the file changed meanwhile. A tap that can't be written stays pending. A tick in the Daily Brief is also
/// remembered (`remembers`), so it stays ticked when the morning brief lists the task again.
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
    /// A repeating task (🔁) is never ticked here: ticked here, its recurrence would end.
    static let repeatsMessage = "This task repeats: tick it in Obsidian, so the next one is made."

    /// Whether ticks in this file are remembered, so a task listed again unticked stays ticked: only the Daily Brief,
    /// which the morning brief rewrites each day. A tick anywhere else is written to its file and stays ticked there on
    /// its own; remembering it by its words would tick next month's "Pay rent" too.
    static func remembers(_ path: String) -> Bool { path == BaroqueSettings.dailyBriefPath }

    // MARK: Reading tasks

    /// The tasks that are still open: drops a task whose tick is waiting to be written, and, in the Daily Brief, one
    /// that was ticked before and is listed again unticked (it queues that one to be ticked in the file again). A
    /// repeating task is never dropped: it's ticked in Obsidian.
    static func visible(_ tasks: [TaskItem]) -> [TaskItem] { visible(tasks, store: .shared) }

    static func visible(_ tasks: [TaskItem], store: Store, now: Date = Date()) -> [TaskItem] {
        lock.withLock {
            let remembered = Set(store.doneTasks.filter { remembers($0.path) }.map { id($0.path, $0.key) })
            var pending = store.pendingToggles
            guard !remembered.isEmpty || !pending.isEmpty else { return tasks }
            var hidden = Set<Int>()
            var claimed = Set<Int>()
            // Each tap waiting to be written stands for the one task it was made on: a tick hides it already, an
            // untick keeps it.
            for tap in pending {
                guard let i = target(of: tap, among: tasks, excluding: claimed) else { continue }
                claimed.insert(i)
                if tap.done && !tasks[i].repeats { hidden.insert(i) }
            }
            // Ticked before in the Daily Brief and listed again: still ticked here, and ticked in the file again.
            var queued = false
            for (i, task) in tasks.enumerated() where !claimed.contains(i) && !task.repeats && remembers(task.sourcePath) {
                let tid = id(task.sourcePath, TaskToggle.key(task.text))
                guard remembered.contains(tid) else { continue }
                hidden.insert(i)
                guard !pending.contains(where: { id($0.path, $0.key) == tid }) else { continue }   // queued once
                pending.append(PendingToggle(task, done: true, tappedAt: now))
                queued = true
            }
            if queued { store.pendingToggles = pending }
            return tasks.indices.filter { !hidden.contains($0) }.map { tasks[$0] }
        }
    }

    /// How the Brief page shows its tasks, by line number: ticked if the file says so, if the tap waiting for that
    /// task is a tick, or (in the Daily Brief) if it was ticked before; and the tap still waiting for it, if any. A
    /// repeating task shows as the file has it.
    static func shown(_ tasks: [Brief.TaskLine], path: String, pending: [PendingToggle], done: [DoneTask])
        -> [Int: (done: Bool, pending: PendingToggle?)] {
        let items = tasks.map { TaskItem(text: $0.text, due: $0.due, priority: .none, sourcePath: path, lineNumber: $0.lineNumber) }
        var taps: [Int: PendingToggle] = [:]
        for tap in pending where tap.path == path {
            if let i = target(of: tap, among: items, excluding: Set(taps.keys)) { taps[i] = tap }
        }
        let remembered = remembers(path) ? Set(done.filter { $0.path == path }.map(\.key)) : []
        var out: [Int: (done: Bool, pending: PendingToggle?)] = [:]
        for (i, task) in tasks.enumerated() {
            if task.repeats { out[task.lineNumber] = (task.done, nil) }
            else if let tap = taps[i] { out[task.lineNumber] = (tap.done, tap) }
            else if !task.done, remembered.contains(task.key) { out[task.lineNumber] = (true, nil) }
            else { out[task.lineNumber] = (task.done, nil) }
        }
        return out
    }

    /// The same for one task on its own.
    static func shown(_ task: Brief.TaskLine, path: String, pending: [PendingToggle], done: [DoneTask]) -> (done: Bool, pending: PendingToggle?) {
        shown([task], path: path, pending: pending, done: done)[task.lineNumber] ?? (task.done, nil)
    }

    /// The task a tap was made on, among listed tasks with its words in its file: the one at its line with its due
    /// date, else the first with its due date, else the one at its line (a tap saved before due dates were kept),
    /// else the first. `excluding`: tasks another tap already stands for.
    static func target(of tap: PendingToggle, among tasks: [TaskItem], excluding: Set<Int> = []) -> Int? {
        let key = tap.key
        let same = tasks.indices.filter { !excluding.contains($0) && tasks[$0].sourcePath == tap.path && TaskToggle.key(tasks[$0].text) == key }
        let dated = same.filter { TaskToggle.sameDue(tasks[$0].due, tap.due) }
        return dated.first { tasks[$0].lineNumber == tap.lineNumber } ?? dated.first
            ?? same.first { tasks[$0].lineNumber == tap.lineNumber } ?? same.first
    }

    // MARK: Ticking

    /// A tap on a task's ring, from the Brief page or the widget: kept at once, then written with any other ticks
    /// waiting in that file. Never throws. A tap on a repeating task is refused at once, without hiding the task (an
    /// older widget timeline may still have a button on one).
    @discardableResult
    static func toggle(_ tap: PendingToggle, store: Store = .shared, client: GitHubClient? = nil) async -> Outcome {
        if isRepeating(tap, store: store) { return .failed(repeatsMessage) }
        record(tap, store: store)
        return await write(tap, store: store, client: client)
    }

    /// Whether a tap is on a repeating task, as far as can be told without the file: by its line, or else by the task
    /// the widgets list for it. The write checks the file's line again (`finish`).
    static func isRepeating(_ tap: PendingToggle, store: Store) -> Bool {
        if let line = tap.line { return TaskToggle.repeats(line) }
        guard let tasks = store.daySnapshot?.tasks, let i = target(of: tap, among: tasks) else { return false }
        return tasks[i].repeats
    }

    /// Writes a tap already kept by `record` (with anything else waiting in its file), and says how it went.
    static func write(_ tap: PendingToggle, store: Store = .shared, client: GitHubClient? = nil) async -> Outcome {
        // `record` keeps no tap on a repeating line (the snapshot's task is gone by now, so only the line can tell).
        if let line = tap.line, TaskToggle.repeats(line) { return .failed(repeatsMessage) }
        let outcomes = await save(path: tap.path, store: store, client: client)
        if let outcome = outcomes.first(where: { $0.tap.isSameTap(as: tap) })?.outcome { return outcome }
        // Another write (an earlier turn, or the other process) took it: saved, unless it's still waiting.
        guard let waiting = store.pendingToggles.first(where: { $0.isSameTap(as: tap) }) else { return .saved }
        return waiting.retryHelps ? .willRetry(waiting.error ?? retryMessage) : .failed(waiting.error ?? retryMessage)
    }

    /// Keeps a tap without writing it: it waits in `pendingToggles` (replacing an earlier tap on the same task, so a
    /// tick and then an untick leave nothing to write), a tick in the Daily Brief is remembered (an untick forgets
    /// it), and a ticked task leaves the cached snapshot, so the widgets drop it at their next redraw. A tap on a
    /// repeating task isn't kept.
    static func record(_ tap: PendingToggle, store: Store = .shared) {
        defer { reloadWidgets() }
        lock.withLock {
            guard !isRepeating(tap, store: store) else { return }
            var fresh = tap
            fresh.error = nil
            fresh.retryHelps = true
            store.pendingToggles = store.pendingToggles.filter { !$0.isSameTask(as: tap) } + [fresh]
            let before = store.doneTasks
            var done = before.filter { !($0.path == tap.path && $0.key == tap.key) }
            if tap.done && remembers(tap.path) { done.append(DoneTask(path: tap.path, key: tap.key, day: dayString(tap.tappedAt))) }
            if done != before { store.doneTasks = done }
            if tap.done { dropFromSnapshot(tap, store: store) }
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
    /// way). The outcome of each. Writes in this process take turns.
    static func save(path: String, store: Store = .shared, client: GitHubClient? = nil) async -> [(tap: PendingToggle, outcome: Outcome)] {
        await turns.run {
            await saveNow(path: path, store: store, client: client ?? GitHubClient(settings: store.settings, token: store.githubToken))
        }
    }

    private static func saveNow(path: String, store: Store, client: GitHubClient) async -> [(tap: PendingToggle, outcome: Outcome)] {
        let taps = store.pendingToggles.filter { $0.path == path }
        guard !taps.isEmpty else { return [] }
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
        /// The taps whose task isn't in the file any more, or can't be told apart from another.
        var lost: [PendingToggle] = []
        /// The taps whose task repeats in the file (nothing changed), with its line.
        var repeating: [(tap: PendingToggle, change: TaskToggle.Change)] = []
    }

    private static func applying(_ taps: [PendingToggle], to markdown: String, store: Store) -> Plan {
        var plan = Plan(text: markdown)
        let remembered = store.doneTasks
        for tap in taps {
            // A tick in the Daily Brief gets the day it was first made, even when it's made again on a later day.
            let first = tap.done && remembers(tap.path)
                ? remembered.last(where: { $0.path == tap.path && $0.key == tap.key }).flatMap { TaskParser.parseDate($0.day) } : nil
            let day = first ?? tap.tappedAt
            let change = tap.line.flatMap { TaskToggle.change(in: plan.text, line: $0, near: tap.lineNumber, done: tap.done, today: day) }
                ?? TaskToggle.change(in: plan.text, key: tap.key, near: tap.lineNumber, done: tap.done, today: day, due: tap.due)
            guard let change else { plan.lost.append(tap); continue }
            if change.repeats { plan.repeating.append((tap, change)); continue }
            if change.markdown != plan.text { plan.changed.append(tap) }
            plan.text = change.markdown
            plan.found.append((tap, change))
        }
        return plan
    }

    /// After a write (or none needed): the settled taps leave the queue unless tapped again meanwhile, the Brief's
    /// copy is the file as written, ticked tasks leave the snapshot and unticked ones come back, and the widgets redraw.
    /// A task the file shows repeating was never ticked: it isn't remembered, and comes back to the widgets.
    private static func finish(path: String, plan: Plan, store: Store) -> [(tap: PendingToggle, outcome: Outcome)] {
        lock.withLock {
            let settled = plan.found.map(\.tap) + plan.lost + plan.repeating.map(\.tap)
            store.pendingToggles = store.pendingToggles.filter { p in !settled.contains { $0.isSameTap(as: p) } }
            for (tap, change) in plan.repeating {
                store.doneTasks = store.doneTasks.filter { !($0.path == path && $0.key == tap.key) }
                addToSnapshot(path: path, change: change, store: store)
            }
            if path == Brief.path(settings: store.settings) {
                store.brief = BriefSnapshot(markdown: plan.text, fetchedAt: Date())
            }
            for (tap, change) in plan.found {
                // `record` took it out already; this is for a snapshot stored since, and takes only that task.
                if tap.done { dropFromSnapshot(tap, store: store, at: [tap.lineNumber, change.lineNumber]) }
                else { addToSnapshot(path: path, change: change, store: store) }
            }
        }
        reloadWidgets()
        return plan.found.map { ($0.tap, Outcome.saved) } + plan.lost.map { ($0, Outcome.failed(changedMessage)) }
            + plan.repeating.map { ($0.tap, Outcome.failed(repeatsMessage)) }
    }

    /// A try that failed: the taps stay pending with the reason.
    private static func settle(_ taps: [PendingToggle], error: Error, store: Store) -> [(tap: PendingToggle, outcome: Outcome)] {
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
        return taps.map { ($0, helps ? .willRetry(reason) : .failed(reason)) }
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

    /// Takes the tapped task out of the cached snapshot (`target`), and no other worded the same. With `lines`, only
    /// a task at one of those lines with the tap's due date: after a write, when `record` has taken it out already.
    private static func dropFromSnapshot(_ tap: PendingToggle, store: Store, at lines: [Int]? = nil) {
        guard var snap = store.daySnapshot else { return }
        let index: Int?
        if let lines {
            index = snap.tasks.firstIndex {
                $0.sourcePath == tap.path && lines.contains($0.lineNumber) && TaskToggle.key($0.text) == tap.key
                    && TaskToggle.sameDue($0.due, tap.due)
            }
        } else {
            index = target(of: tap, among: snap.tasks)
        }
        guard let index else { return }
        snap.tasks.remove(at: index)
        store.daySnapshot = snap
    }

    /// An unticked task comes back to the widgets: in the agenda's order, if the agenda shows it at all.
    private static func addToSnapshot(path: String, change: TaskToggle.Change, store: Store) {
        guard var snap = store.daySnapshot,
              var item = TaskParser.parse(markdown: change.line, sourcePath: path).first else { return }
        item.lineNumber = change.lineNumber
        let key = TaskToggle.key(item.text)
        guard !snap.tasks.contains(where: { $0.sourcePath == path && $0.lineNumber == item.lineNumber && TaskToggle.key($0.text) == key }) else { return }
        snap.tasks = TaskParser.todaysAgenda(snap.tasks + [item], includeUndated: store.settings.includeUndatedTasks, limit: snap.tasks.count + 1)
        store.daySnapshot = snap
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
