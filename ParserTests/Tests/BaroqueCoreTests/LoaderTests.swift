import Foundation
import XCTest
@testable import BaroqueCore

/// The loader's pure parts: when a cached snapshot serves, when a fetch may store, how a day is put together, and the
/// Day timeline's entry dates.
final class LoaderTests: XCTestCase {
    let noon = day(2026, 6, 5, hour: 12)

    // MARK: isFresh (F2)

    func testFreshWhenRecentTodayAndWithoutErrors() {
        XCTAssertTrue(DataLoader.isFresh(saved: noon.addingTimeInterval(-60), now: noon, maxAge: 900, hasError: false))
    }

    func testSnapshotFromTheFutureIsNotFresh() {
        // A clock set back makes the saved snapshot look newer than now; even maxAge 0 let it through before.
        XCTAssertFalse(DataLoader.isFresh(saved: noon.addingTimeInterval(60), now: noon, maxAge: 900, hasError: false))
        XCTAssertFalse(DataLoader.isFresh(saved: noon.addingTimeInterval(60), now: noon, maxAge: 0, hasError: false))
    }

    func testSnapshotWithAFailedFetchIsNotFresh() {
        XCTAssertFalse(DataLoader.isFresh(saved: noon.addingTimeInterval(-60), now: noon, maxAge: 900, hasError: true))
    }

    func testSnapshotExactlyMaxAgeOldIsNotFresh() {
        XCTAssertFalse(DataLoader.isFresh(saved: noon.addingTimeInterval(-900), now: noon, maxAge: 900, hasError: false))
        XCTAssertTrue(DataLoader.isFresh(saved: noon.addingTimeInterval(-899), now: noon, maxAge: 900, hasError: false))
    }

    func testYesterdaysSnapshotIsNotFresh() {
        // Ten minutes old, but from before midnight.
        let saved = day(2026, 6, 4, hour: 23, minute: 55)
        let now = day(2026, 6, 5, hour: 0, minute: 5)
        XCTAssertFalse(DataLoader.isFresh(saved: saved, now: now, maxAge: 900, hasError: false))
    }

    func testMaxAgeZeroAlwaysFetches() {
        XCTAssertFalse(DataLoader.isFresh(saved: noon, now: noon, maxAge: 0, hasError: false))
    }

    func testUnsetLocationIsNotAFailure() {
        var settings = BaroqueSettings.default
        settings.locationSet = false
        var snap = DaySnapshot(date: noon, weather: nil, tasks: [], taskError: nil, weatherError: DataLoader.noLocation)
        XCTAssertFalse(DataLoader.hasFailure(snap, settings: settings), "asking again wouldn't change it")
        settings.locationSet = true
        snap.weatherError = "The Internet connection appears to be offline."
        XCTAssertTrue(DataLoader.hasFailure(snap, settings: settings))
        snap.weatherError = nil
        snap.taskError = "GitHub denied access (403)"
        XCTAssertTrue(DataLoader.hasFailure(snap, settings: settings))
    }

    // MARK: shouldStore (F20)

    func testFetchStoresOverAnOlderSnapshot() {
        XCTAssertTrue(DataLoader.shouldStore(existing: nil, startedAt: noon))
        XCTAssertTrue(DataLoader.shouldStore(existing: noon.addingTimeInterval(-300), startedAt: noon))
    }

    func testLateWidgetFetchLeavesTheAppsNewerSnapshot() {
        // The widget began at noon; the app's Save & Refresh finished a minute later, before the widget's did.
        XCTAssertFalse(DataLoader.shouldStore(existing: noon.addingTimeInterval(60), startedAt: noon))
    }

    func testAppRefreshAlwaysStores() {
        // The other order: the widget's late fetch landed while the app's refresh ran; the app's still wins.
        XCTAssertTrue(DataLoader.shouldStore(existing: noon.addingTimeInterval(60), startedAt: noon, forced: true))
    }

    // MARK: Quotes (F18)

    let quotesPath = "main/Quotes/Quotes.md"
    let file = "> To be, or not to be, that is the question.\n> — William Shakespeare\n"
    lazy var cached = QuoteSnapshot(quotes: [Quote(text: "I think, therefore I am.", author: "René Descartes")],
                                    fetchedAt: noon.addingTimeInterval(-3600), error: nil)

    func testQuotesFetchedAreKept() {
        let out = DataLoader.quoteOutcome(.success(file), cached: cached, path: quotesPath, hasToken: true, now: noon)
        XCTAssertTrue(out.save)
        XCTAssertEqual(out.snapshot.quotes.map(\.author), ["William Shakespeare"])
        XCTAssertNil(out.snapshot.error)
        XCTAssertEqual(out.snapshot.fetchedAt, noon)
    }

    func testFileWithNoQuotesKeepsTheCachedOnesWithAnError() {
        let out = DataLoader.quoteOutcome(.success("# Quotes\n\nNothing here yet.\n"), cached: cached, path: quotesPath,
                                          hasToken: true, now: noon)
        XCTAssertFalse(out.save)
        XCTAssertEqual(out.snapshot.quotes, cached.quotes)
        XCTAssertEqual(out.snapshot.error, "No quotes found in main/Quotes/Quotes.md")
    }

    func testFileWithNoQuotesAndNoCache() {
        let out = DataLoader.quoteOutcome(.success(""), cached: nil, path: quotesPath, hasToken: true, now: noon)
        XCTAssertFalse(out.save)
        XCTAssertTrue(out.snapshot.quotes.isEmpty)
        XCTAssertEqual(out.snapshot.error, "No quotes found in main/Quotes/Quotes.md")
    }

    func testFailedQuotesFetchKeepsTheCache() {
        let out = DataLoader.quoteOutcome(.failure(GitHubError.http(500, quotesPath)), cached: cached, path: quotesPath,
                                          hasToken: true, now: noon)
        XCTAssertFalse(out.save)
        XCTAssertEqual(out.snapshot.quotes, cached.quotes)
        XCTAssertEqual(out.snapshot.error, GitHubError.http(500, quotesPath).localizedDescription)
    }

    func testNotFoundWithoutATokenSaysSo() {
        let out = DataLoader.quoteOutcome(.failure(GitHubError.notFound(quotesPath, repository: "owner/repo")), cached: nil, path: quotesPath,
                                          hasToken: false, now: noon)
        XCTAssertEqual(out.snapshot.error, GitHubError.noToken.localizedDescription)
    }

    // MARK: Putting the day together (F21, F23, N1)

    private func task(_ text: String, line: Int) -> TaskItem {
        TaskItem(text: text, due: nil, priority: .none, sourcePath: BaroqueSettings.dailyBriefPath, lineNumber: line)
    }

    private func weather(at date: Date) -> WeatherSnapshot {
        WeatherSnapshot(temperature: 70, apparent: 70, high: 75, low: 60, code: 0, fetchedAt: date)
    }

    func testNoLocationMeansNoWeatherAndAnErrorLine() {
        var settings = BaroqueSettings.default
        settings.locationSet = false
        let previous = DaySnapshot(date: noon.addingTimeInterval(-600), weather: weather(at: noon.addingTimeInterval(-600)),
                                   tasks: [], taskError: nil, weatherError: nil)
        let snap = DataLoader.daySnapshot(previous: previous, weather: nil, tasks: [], taskError: nil, settings: settings, now: noon)
        XCTAssertNil(snap.weather, "no weather for the default coordinates")
        XCTAssertEqual(snap.weatherError, "Set a location in the Baroque app")
    }

    func testFailedWeatherKeepsTodaysCachedWeather() {
        var settings = BaroqueSettings.default
        settings.locationSet = true
        let earlier = weather(at: noon.addingTimeInterval(-3600))
        let previous = DaySnapshot(date: noon.addingTimeInterval(-3600), weather: earlier, tasks: [], taskError: nil, weatherError: nil)
        let snap = DataLoader.daySnapshot(previous: previous, weather: .failure(WeatherError.http(500)), tasks: [],
                                          taskError: nil, settings: settings, now: noon)
        XCTAssertEqual(snap.weather, earlier)
        XCTAssertEqual(snap.weatherError, "Weather HTTP 500")

        let yesterday = DaySnapshot(date: day(2026, 6, 4, hour: 20), weather: weather(at: day(2026, 6, 4, hour: 20)),
                                    tasks: [], taskError: nil, weatherError: nil)
        let next = DataLoader.daySnapshot(previous: yesterday, weather: .failure(WeatherError.http(500)), tasks: [],
                                          taskError: nil, settings: settings, now: noon)
        XCTAssertNil(next.weather, "yesterday's weather isn't today's")
    }

    func testTickedTasksAreLeftOutFreshOrCached() {
        let a = task("Send the letter", line: 3), b = task("Water the roses", line: 4)
        let hide: ([TaskItem]) -> [TaskItem] = { $0.filter { $0.text != b.text } }
        let fresh = DataLoader.daySnapshot(previous: nil, weather: nil, tasks: [a, b], taskError: nil,
                                           settings: .default, now: noon, visible: hide)
        XCTAssertEqual(fresh.tasks.map(\.text), [a.text])

        // The brief couldn't be read: the cached tasks are used, still without the ticked one.
        let previous = DaySnapshot(date: noon.addingTimeInterval(-600), weather: nil, tasks: [a, b], taskError: nil, weatherError: nil)
        let cached = DataLoader.daySnapshot(previous: previous, weather: nil, tasks: nil, taskError: GitHubError.noToken,
                                            settings: .default, now: noon, visible: hide)
        XCTAssertEqual(cached.tasks.map(\.text), [a.text])
        XCTAssertEqual(cached.taskError, GitHubError.noToken.localizedDescription)
    }

    func testTheSnapshotKeepsTheWholeAgenda() {
        // The views draw what fits and count the rest for "+ N more", so 40 tasks stay 40 (the cap was 12).
        let many = (1...40).map { task("Task \($0)", line: $0) }
        let snap = DataLoader.daySnapshot(previous: nil, weather: nil, tasks: many, taskError: nil, settings: .default, now: noon)
        XCTAssertEqual(snap.tasks.count, 40)
    }

    // MARK: Day timeline (F8a, F16)

    /// The photographs' turns in the test: every three hours on the local clock.
    private func nextTurn(after date: Date) -> Date {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let startOfHour = cal.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
        return cal.date(byAdding: .hour, value: (hour / 3 + 1) * 3 - hour, to: startOfHour)!
    }

    private func turn(_ date: Date) -> Date {
        // The start of the turn `date` is in: the change before the next one.
        Calendar.current.date(byAdding: .hour, value: -3, to: nextTurn(after: date))!
    }

    private var hourly: BaroqueSettings {
        var s = BaroqueSettings.default
        s.quoteRotationMinutes = 60
        return s
    }

    func testDayEntriesCoverEveryPhotoChangeAndQuoteSlot() {
        let start = day(2026, 6, 5, hour: 10, minute: 20)
        let end = start.addingTimeInterval(24 * 3600)
        let dates = DataLoader.dayEntryDates(from: start, until: end, settings: hourly, photoChange: nextTurn)

        XCTAssertEqual(dates.first, start)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, dates.count, "no date twice")
        XCTAssertTrue(dates.allSatisfy { $0 >= start && $0 < end })

        var change = nextTurn(after: start)
        var changes = 0
        while change < end {
            XCTAssertTrue(dates.contains(change), "photo change at \(change)")
            change = nextTurn(after: change)
            changes += 1
        }
        XCTAssertEqual(changes, 8)

        let step = DataLoader.quoteStep(settings: hourly)
        var slot = DataLoader.quoteSlot(at: start, settings: hourly) + 1
        while Double(slot) * step < end.timeIntervalSince1970 {
            XCTAssertTrue(dates.contains(Date(timeIntervalSince1970: Double(slot) * step)), "quote slot \(slot)")
            slot += 1
        }
    }

    func testNoSlotOrTurnChangesBetweenEntries() {
        // Between two entries the widget shows the first one's photograph and quote, so neither may change in between.
        let start = day(2026, 6, 5, hour: 10, minute: 20)
        let dates = DataLoader.dayEntryDates(from: start, until: start.addingTimeInterval(24 * 3600), settings: hourly,
                                             photoChange: nextTurn)
        for (a, b) in zip(dates, dates.dropFirst()) {
            let justBefore = b.addingTimeInterval(-0.001)
            XCTAssertEqual(DataLoader.quoteSlot(at: justBefore, settings: hourly), DataLoader.quoteSlot(at: a, settings: hourly))
            XCTAssertEqual(turn(justBefore), turn(a))
        }
    }

    func testEveryEntryShowsTheQuoteAfterTheQuoteWidgets() {
        let start = day(2026, 6, 5, hour: 10, minute: 20)
        let count = 7, offset = 3
        let dates = DataLoader.dayEntryDates(from: start, until: start.addingTimeInterval(24 * 3600), settings: hourly,
                                             photoChange: nextTurn)
        for date in dates {
            let quoteWidget = DataLoader.quoteIndex(count: count, offset: offset, at: date, settings: hourly)
            let dayWidget = DataLoader.dayQuoteIndex(count: count, offset: offset, at: date, settings: hourly)
            XCTAssertEqual(dayWidget, (quoteWidget + 1) % count)
            XCTAssertNotEqual(dayWidget, quoteWidget)
        }
    }

    func testOtherSizesTakeOnlyThePhotoChanges() {
        let start = day(2026, 6, 5, hour: 10, minute: 20)
        let dates = DataLoader.dayEntryDates(from: start, until: start.addingTimeInterval(24 * 3600), settings: hourly,
                                             quotes: false, photoChange: nextTurn)
        XCTAssertEqual(dates.count, 1 + 8)
    }

    func testShortRotationsAreCapped() {
        var s = BaroqueSettings.default
        s.quoteRotationMinutes = 5
        let start = day(2026, 6, 5, hour: 10, minute: 20)
        let dates = DataLoader.dayEntryDates(from: start, until: start.addingTimeInterval(24 * 3600), settings: s,
                                             photoChange: nextTurn)
        XCTAssertLessThanOrEqual(dates.count, 1 + 8 + DataLoader.maxQuoteSlotEntries)
    }

    func testQuotePoolFallsBackWhenEmpty() {
        XCTAssertEqual(DataLoader.quotePool(nil), DataLoader.fallbackQuotes)
        XCTAssertEqual(DataLoader.quotePool(QuoteSnapshot(quotes: [], fetchedAt: noon, error: nil)), DataLoader.fallbackQuotes)
        XCTAssertEqual(DataLoader.quotePool(cached), cached.quotes)
    }

    // MARK: Sharing a fetch (F10) and the tick retry's time limit (N1)

    private actor Counter {
        var count = 0
        func bump() -> Int { count += 1; return count }
    }

    func testTwoCallsAtOnceMakeOneFetch() async {
        let shared = SharedFetch<Int>()
        let counter = Counter()
        let slowFetch: @Sendable () async -> Int = {
            let n = await counter.bump()
            try? await Task.sleep(nanoseconds: 300_000_000)
            return n
        }
        async let first = shared.value(slowFetch)
        async let second = shared.value(slowFetch)
        let (a, b) = await (first, second)
        let fetches = await counter.count
        XCTAssertEqual(fetches, 1)
        XCTAssertEqual(a, 1)
        XCTAssertEqual(b, 1)
    }

    func testStartNewFetchesEvenWhileOneRuns() async {
        let shared = SharedFetch<Int>()
        let counter = Counter()
        let slowFetch: @Sendable () async -> Int = {
            let n = await counter.bump()
            try? await Task.sleep(nanoseconds: 300_000_000)
            return n
        }
        async let first = shared.value(slowFetch)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let forced = await shared.value(startNew: true, slowFetch)
        _ = await first
        let fetches = await counter.count
        XCTAssertEqual(fetches, 2)
        XCTAssertEqual(forced, 2)
    }

    func testACallAfterTheFetchEndsFetchesAgain() async {
        let shared = SharedFetch<Int>()
        let counter = Counter()
        let fetch: @Sendable () async -> Int = { await counter.bump() }
        let a = await shared.value(fetch)
        let b = await shared.value(fetch)
        XCTAssertEqual([a, b], [1, 2])
    }

    func testWaitGivesUpAtItsDeadline() async {
        let long = Task { _ = try? await Task.sleep(nanoseconds: 3_000_000_000) }
        let start = Date()
        await DataLoader.wait(for: long, until: start.addingTimeInterval(0.1))
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.5)
        long.cancel()
    }

    func testWaitReturnsWhenTheTaskEnds() async {
        let quick = Task { _ = try? await Task.sleep(nanoseconds: 50_000_000) }
        let start = Date()
        await DataLoader.wait(for: quick, until: start.addingTimeInterval(5))
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
    }
}
