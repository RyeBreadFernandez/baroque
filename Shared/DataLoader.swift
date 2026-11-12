import Foundation

enum DataLoader {
    static func dailyNotePath(settings: BaroqueSettings, date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = settings.dailyNoteFormat
        let name = f.string(from: date)
        let folder = settings.dailyNoteFolder.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return folder.isEmpty ? "\(name).md" : "\(folder)/\(name).md"
    }

    static func resolvedTaskPaths(settings: BaroqueSettings) -> [String] {
        settings.taskPaths
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { $0 == "{daily}" ? dailyNotePath(settings: settings) : $0 }
            .reduce(into: [String]()) { paths, p in if !paths.contains(p) { paths.append(p) } } // same file twice would duplicate task ids
    }

    // Fetches every task path. Returns nil tasks when nothing could be read, so callers keep their cache.
    // A missing daily note is normal and not an error; any other failure is reported even if other paths worked.
    // `brief` is the Daily Brief's text when it's one of the paths and was read, for its picture of the day.
    static func fetchTasks(client: GitHubClient, settings: BaroqueSettings) async -> (tasks: [TaskItem]?, error: Error?, brief: String?) {
        let dailyPath = dailyNotePath(settings: settings)
        var all: [TaskItem] = []
        var firstError: Error?
        var anySuccess = false
        var brief: String?
        for path in resolvedTaskPaths(settings: settings) {
            do {
                let text = try await client.fetchText(path: path)
                all.append(contentsOf: TaskParser.parse(markdown: text, sourcePath: path))
                anySuccess = true
                if path == BaroqueSettings.dailyBriefPath { brief = text }
            } catch GitHubError.notFound where path == dailyPath {
                continue
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        // A private repo answers 404 without a token, which reads like "file missing". Say what's really wrong.
        if !anySuccess && client.token.isEmpty { return (nil, GitHubError.noToken, nil) }
        if !anySuccess && firstError != nil { return (nil, firstError, nil) }
        return (all, firstError, brief)
    }

    /// How long a fetch serves every widget that asks. Day and Today share a provider, and iOS asks for each widget
    /// kind and size on its own schedule, so without this one refresh of the home screen fetched the same weather and
    /// brief once per widget.
    static let freshFor: TimeInterval = 15 * 60

    /// How many of the day's tasks the snapshot keeps. The views draw only what fits, and count the rest for "+ N more".
    static let agendaLimit = 100

    /// The weather line until a location is saved in the app, instead of quietly showing the default city's weather.
    static let noLocation = "Set a location in the Baroque app"

    /// How long a fetch waits for pending ticks to reach the vault, counted from its start. The ticks are written
    /// before the tasks are read, so the fetch reads the file as they left it; whatever hasn't finished by then
    /// carries on, or stays pending for the next try.
    static let tickRetryAllowance: TimeInterval = 3

    /// A saved snapshot serves another caller only while it is from today, between 0 and `maxAge` seconds old (a
    /// clock set back makes a snapshot look newer than now), and holds no failed fetch: the next caller tries again.
    static func isFresh(saved: Date, now: Date, maxAge: TimeInterval, hasError: Bool, calendar: Calendar = .current) -> Bool {
        let age = now.timeIntervalSince(saved)
        return age >= 0 && age < maxAge && !hasError && calendar.isDate(saved, inSameDayAs: now)
    }

    /// Whether a fetch that began at `startedAt` may replace the stored snapshot made at `existing`. A widget's fetch
    /// that began before the app's refresh finished carries the older settings (no token yet, say), so it leaves the
    /// app's newer result in place. The app's own refresh (`forced`) always stores: it began after the user's change.
    /// The stored date keeps whole seconds only (ISO 8601), so one from the second the fetch began may be the newer:
    /// it's left in place too.
    static func shouldStore(existing: Date?, startedAt: Date, forced: Bool = false) -> Bool {
        guard !forced, let existing else { return true }
        let startSecond = Date(timeIntervalSince1970: startedAt.timeIntervalSince1970.rounded(.down))
        return existing < startSecond
    }

    /// A failed fetch in the snapshot. A location that was never set isn't one: that wouldn't change by asking again.
    static func hasFailure(_ snap: DaySnapshot, settings: BaroqueSettings) -> Bool {
        snap.taskError != nil || (settings.locationSet && snap.weatherError != nil)
    }

    // Loads weather + tasks. Never throws; errors are recorded in the snapshot and cached data is reused.
    // A fresh snapshot (`isFresh`) is returned as it is, less any task ticked since; the app passes 0 to always fetch.
    // Widgets that ask while a fetch is running share it.
    static func loadDay(maxAge: TimeInterval = freshFor) async -> DaySnapshot {
        let store = Store.shared
        if var previous = store.daySnapshot,
           isFresh(saved: previous.date, now: Date(), maxAge: maxAge, hasError: hasFailure(previous, settings: store.settings)) {
            previous.tasks = TaskSync.visible(previous.tasks)
            return previous
        }
        let forced = maxAge <= 0
        return await dayFetch.value(startNew: forced) { await fetchDay(forced: forced) }
    }

    private static let dayFetch = SharedFetch<DaySnapshot>()

    private static func fetchDay(forced: Bool) async -> DaySnapshot {
        let store = Store.shared
        let startedAt = Date()
        let settings = store.settings
        let client = GitHubClient(settings: settings, token: store.githubToken)

        // Ticks that couldn't be saved earlier go to the vault first, best effort and for a few seconds at most, so the
        // tasks are read as they left the file (a list read alongside could put back what an untick's write just
        // changed). They never fail the widget, and the ticked tasks are left out below either way. The weather
        // doesn't wait.
        async let weatherResult = fetchWeather(settings: settings)
        let t = await afterPendingTicks(store.pendingToggles.contains(where: \.retryHelps), retry: { await TaskSync.retryPending() },
                                        until: startedAt.addingTimeInterval(tickRetryAllowance)) {
            await fetchTasks(client: client, settings: settings)
        }
        let w = await weatherResult

        let stored = store.daySnapshot
        let snap = daySnapshot(previous: stored, weather: w, tasks: t.tasks, taskError: t.error, settings: settings,
                               now: Date(), visible: { TaskSync.visible($0) })
        if let stored, !shouldStore(existing: stored.date, startedAt: startedAt, forced: forced) {
            var newer = stored
            newer.tasks = TaskSync.visible(newer.tasks)
            return newer
        }
        store.daySnapshot = snap
        // With the tasks saved, the brief's picture of the day: downloaded only when it's a new one, and waited for
        // `BriefPicture.timeout` at most, so the timeline that follows draws it.
        if let brief = t.brief {
            let pictureClient = GitHubClient(settings: settings, token: client.token, session: BriefPicture.session)
            let update = Task {
                await BriefPicture.update(brief: brief, notePath: BaroqueSettings.dailyBriefPath, store: store,
                                          folder: BriefPicture.folder, client: pictureClient)
            }
            await wait(for: update, until: Date().addingTimeInterval(BriefPicture.timeout))
        }
        return snap
    }

    /// Nil until a location is set: no request is made for the default coordinates.
    private static func fetchWeather(settings: BaroqueSettings) async -> Result<WeatherSnapshot, Error>? {
        guard settings.locationSet else { return nil }
        do { return .success(try await WeatherClient.fetch(latitude: settings.latitude, longitude: settings.longitude, fahrenheit: settings.useFahrenheit)) }
        catch { return .failure(error) }
    }

    /// The day's snapshot from what was fetched: fresh weather and tasks where they came, today's cached ones where
    /// they didn't. `weather` is nil when no location is set (no request was made); `tasks` is nil when no task file
    /// could be read. `visible` leaves out tasks ticked in the app or on the widget (TaskSync).
    static func daySnapshot(previous: DaySnapshot?, weather: Result<WeatherSnapshot, Error>?, tasks: [TaskItem]?,
                            taskError: Error?, settings: BaroqueSettings, now: Date, calendar: Calendar = .current,
                            visible: ([TaskItem]) -> [TaskItem] = { $0 }) -> DaySnapshot {
        func agenda(_ items: [TaskItem]) -> [TaskItem] {
            TaskParser.todaysAgenda(visible(items), includeUndated: settings.includeUndatedTasks, limit: agendaLimit, now: now)
        }
        // Cached weather is only worth showing on the day it was fetched, and only for a location that is set.
        let cachedWeather = settings.locationSet
            ? previous?.weather.flatMap { calendar.isDate($0.fetchedAt, inSameDayAs: now) ? $0 : nil } : nil
        var snap = DaySnapshot(date: now, weather: cachedWeather, tasks: agenda(tasks ?? previous?.tasks ?? []),
                               taskError: taskError?.localizedDescription, weatherError: nil)
        switch weather {
        case nil: snap.weatherError = noLocation
        case .success(let ws)?: snap.weather = ws
        case .failure(let e)?: snap.weatherError = e.localizedDescription
        }
        return snap
    }

    static func loadQuotes(maxAge: TimeInterval = freshFor) async -> QuoteSnapshot {
        let store = Store.shared
        if let cached = store.quoteSnapshot,
           isFresh(saved: cached.fetchedAt, now: Date(), maxAge: maxAge, hasError: cached.error != nil) {
            return cached
        }
        let forced = maxAge <= 0
        return await quoteFetch.value(startNew: forced) { await fetchQuotes(forced: forced) }
    }

    private static let quoteFetch = SharedFetch<QuoteSnapshot>()

    private static func fetchQuotes(forced: Bool) async -> QuoteSnapshot {
        let store = Store.shared
        let startedAt = Date()
        let settings = store.settings
        let client = GitHubClient(settings: settings, token: store.githubToken)
        let fetched: Result<String, Error>
        do { fetched = .success(try await client.fetchText(path: settings.quotesPath)) }
        catch { fetched = .failure(error) }
        let stored = store.quoteSnapshot
        let outcome = quoteOutcome(fetched, cached: stored, path: settings.quotesPath, hasToken: !client.token.isEmpty, now: Date())
        guard outcome.save else { return outcome.snapshot }
        if let stored, !shouldStore(existing: stored.fetchedAt, startedAt: startedAt, forced: forced) { return stored }
        store.quoteSnapshot = outcome.snapshot
        return outcome.snapshot
    }

    /// What a quotes fetch comes to, and whether to keep it. A file with no quotes in it counts as a failed fetch: the
    /// cached quotes stay (so the Quote widget, the large Day and the app agree) with a line saying why.
    static func quoteOutcome(_ fetched: Result<String, Error>, cached: QuoteSnapshot?, path: String, hasToken: Bool,
                             now: Date) -> (snapshot: QuoteSnapshot, save: Bool) {
        var kept = cached ?? QuoteSnapshot(quotes: [], fetchedAt: now, error: nil)
        switch fetched {
        case .success(let text):
            let quotes = QuoteParser.parse(markdown: text)
            if !quotes.isEmpty { return (QuoteSnapshot(quotes: quotes, fetchedAt: now, error: nil), true) }
            kept.error = "No quotes found in \(path)"
        case .failure(let error):
            kept.error = error.localizedDescription
            // A private repo answers 404 without a token.
            if case GitHubError.notFound = error, !hasToken { kept.error = GitHubError.noToken.localizedDescription }
        }
        return (kept, false)
    }

    // Which quote is showing: the next-quote offset plus a wall-clock rotation slot, so the widget's
    // timeline and the app preview agree, and the sequence keeps moving across timeline reloads.
    static func quoteStep(settings: BaroqueSettings) -> TimeInterval {
        TimeInterval(max(5, settings.quoteRotationMinutes) * 60)
    }

    static func quoteSlot(at date: Date, settings: BaroqueSettings) -> Int {
        Int(date.timeIntervalSince1970 / quoteStep(settings: settings))
    }

    static func quoteIndex(count: Int, offset: Int, at date: Date, settings: BaroqueSettings) -> Int {
        guard count > 0 else { return 0 }
        return (offset + quoteSlot(at: date, settings: settings)) % count
    }

    /// The large Day widget's line: the one after the Quote widget's, so the two never show the same quote at once.
    static func dayQuoteIndex(count: Int, offset: Int, at date: Date, settings: BaroqueSettings) -> Int {
        guard count > 0 else { return 0 }
        return (quoteIndex(count: count, offset: offset, at: date, settings: settings) + 1) % count
    }

    /// The quotes the widgets take turns with: the vault's, or the fallback lines while there are none.
    static func quotePool(_ snapshot: QuoteSnapshot?) -> [Quote] {
        let quotes = snapshot?.quotes ?? []
        return quotes.isEmpty ? fallbackQuotes : quotes
    }

    /// The most quote-slot entries a Day timeline lays out: a day of 5-minute turns would be nearly 300 entries.
    static let maxQuoteSlotEntries = 96

    /// When the Day timeline needs an entry: `start`, then every photograph change (`photoChange` gives the next one
    /// after a date) and, when the widget shows a quote, every quote slot start, up to `end`. Each entry is drawn with
    /// its own date, so a late reload never leaves the large Day on the last turn's photograph or quote.
    static func dayEntryDates(from start: Date, until end: Date, settings: BaroqueSettings, quotes: Bool = true,
                              photoChange: (Date) -> Date) -> [Date] {
        var dates: Set<Date> = [start]
        var t = start
        while true {
            let next = photoChange(t)
            guard next > t, next < end else { break }
            dates.insert(next)
            t = next
        }
        if quotes {
            let step = quoteStep(settings: settings)
            var slot = quoteSlot(at: start, settings: settings) + 1
            for _ in 0..<maxQuoteSlotEntries {
                let date = Date(timeIntervalSince1970: Double(slot) * step)
                guard date < end else { break }
                dates.insert(date)
                slot += 1
            }
        }
        return dates.sorted()
    }

    /// Runs `fetch` once the ticks waiting to be written (`retry`) are done, or at `deadline`, whichever comes first;
    /// the retry runs on past it. With nothing waiting (`pending` false) the fetch starts at once.
    static func afterPendingTicks<T>(_ pending: Bool, retry: @escaping @Sendable () async -> Void, until deadline: Date,
                                     then fetch: () async -> T) async -> T {
        if pending {
            await wait(for: Task { await retry() }, until: deadline)
        }
        return await fetch()
    }

    /// Waits for `task` until `deadline` at the latest, then returns and lets it run on.
    static func wait(for task: Task<Void, Never>, until deadline: Date) async {
        let seconds = deadline.timeIntervalSinceNow
        guard seconds > 0 else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = ResumeOnce(continuation)
            Task { await task.value; once.resume() }
            Task { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)); once.resume() }
        }
    }

    static let fallbackQuotes: [Quote] = [
        Quote(text: "Make the quiet thing first, then the loud one.", author: nil),
        Quote(text: "Good ideas take time.", author: nil),
        Quote(text: "Add quotes to main/Quotes/Quotes.md in your vault to see them here.", author: "Baroque")
    ]
}

/// One fetch at a time for everyone who asks while it runs: when several widgets refresh at the same moment, they
/// share one request instead of each making its own. `startNew` (the app's Save & Refresh) always starts a fresh one,
/// which later callers then share.
actor SharedFetch<Value: Sendable> {
    private var running: Task<Value, Never>?

    func value(startNew: Bool = false, _ fetch: @escaping @Sendable () async -> Value) async -> Value {
        if !startNew, let running { return await running.value }
        let task = Task { await fetch() }
        running = task
        let value = await task.value
        if running == task { running = nil }
        return value
    }
}

/// Resumes a continuation once, whichever of two racing tasks gets there first.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }

    func resume() {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume()
    }
}
