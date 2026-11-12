import WidgetKit
import SwiftUI
import AppIntents
import UIKit

// The widgets are drawn in the rococo look (Shared/Rococo*.swift): Day, Today, Quote, Battery, Still Life and
// Photograph.

// MARK: - Bundle

@main
struct BaroqueWidgetBundle: WidgetBundle {
    var body: some Widget {
        DayWidget()
        TodayWidget()
        QuoteWidget()
        BatteryWidget()
        StillLifeWidget()
        PhotographWidget()
    }
}

// MARK: - Day widget

struct DayEntry: TimelineEntry {
    let date: Date
    /// The day's data, dated at the entry (not at the fetch), so the photograph and the night glaze follow the clock.
    let snapshot: DaySnapshot
    /// The large Day widget's line from the vault: the one after the Quote widget's, so the two differ.
    var quote: Quote? = nil
    /// The large Today's band: the Daily Brief's picture of the day when the brief named it on the entry's day (nil:
    /// the still life).
    var picture: RococoBandPicture? = nil
}

/// The Day and Today widgets' timelines: one fetch (shared by every widget that asks within `DataLoader.freshFor`),
/// then an entry at every photograph change in the next day and, on the large Day, at every quote slot.
struct DayProvider: TimelineProvider {
    /// True for the Day widget: its large size shows a line from the vault. Today shares the rest.
    var showsQuote = false

    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), snapshot: DayProvider.sample, quote: showsQuote ? DemoData.quotes[2] : nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(entry(at: Date(), snapshot: Store.shared.daySnapshot ?? DayProvider.sample, quotes: Store.shared.quoteSnapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        // Only the large Day shows a quote, so only it fetches quotes (with no Quote widget placed, nothing else would)
        // and takes a turn at each quote slot.
        let withQuote = showsQuote && context.family == .systemLarge
        Task {
            async let day = DataLoader.loadDay()
            async let quotes = DayProvider.quotes(fetch: withQuote)
            let (snap, quoteSnap) = await (day, quotes)
            let now = Date()
            let dates = DataLoader.dayEntryDates(from: now, until: now.addingTimeInterval(24 * 3600),
                                                 settings: Store.shared.settings, quotes: withQuote,
                                                 photoChange: { RococoPhotos.nextChange(after: $0) })
            // Refresh in about 30 minutes; the entries after that matter only when iOS reloads late.
            completion(Timeline(entries: dates.map { entry(at: $0, snapshot: snap, quotes: quoteSnap) },
                                policy: .after(now.addingTimeInterval(30 * 60))))
        }
    }

    /// An entry drawn at `date`: the snapshot carries the entry's own date (the stored one keeps the fetch's), the
    /// Day widget the quote for that slot, and the Today widget the brief's picture if it's that day's.
    private func entry(at date: Date, snapshot: DaySnapshot, quotes: QuoteSnapshot?) -> DayEntry {
        var snap = snapshot
        snap.date = date
        guard showsQuote else {
            let picture = BriefPicture.shown(Store.shared.briefPicture, in: BriefPicture.folder, on: date)
            return DayEntry(date: date, snapshot: snap, picture: picture.map { RococoBandPicture(file: $0.file, label: $0.alt) })
        }
        let pool = DataLoader.quotePool(quotes)
        let i = DataLoader.dayQuoteIndex(count: pool.count, offset: Store.shared.quoteOffset, at: date, settings: Store.shared.settings)
        return DayEntry(date: date, snapshot: snap, quote: pool[i])
    }

    /// The large Day's quotes: fetched when the cache is stale. The other sizes read the cache as it is.
    private static func quotes(fetch: Bool) async -> QuoteSnapshot? {
        fetch ? await DataLoader.loadQuotes() : Store.shared.quoteSnapshot
    }

    static var sample: DaySnapshot { DemoData.day() }
}

struct DayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DayEntry

    private var size: BaroqueSize {
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        default: return .large
        }
    }

    // The rococo layout is all foreground; the container background is the limestone's middle value.
    var body: some View {
        RococoDayView(snapshot: entry.snapshot, quote: entry.quote, size: size)
            .containerBackground(for: .widget) { RococoInk.stone }
    }
}

struct DayWidget: Widget {
    let kind = "BaroqueDay"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayProvider(showsQuote: true)) { entry in
            DayWidgetView(entry: entry)
        }
        .configurationDisplayName("Baroque Day")
        .description("The sun's path carved in painted stone, the days ahead, and on large one of your photographs, a new one every three hours, with the date, the temperature, a quote and the weather.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Today widget

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DayEntry

    var body: some View {
        // Each task's ring ticks it off (ToggleTaskIntent); the rest of the widget opens the Daily Brief. A repeating
        // task's ring is no button: it's ticked in Obsidian, so the Tasks plugin makes the next one.
        RococoTodayView(snapshot: entry.snapshot, size: family == .systemSmall ? .small : family == .systemMedium ? .medium : .large,
                        picture: entry.picture,
                        tick: { task, ring in
                            task.repeats ? ring : AnyView(Button(intent: ToggleTaskIntent(task)) { ring }.buttonStyle(.plain))
                        })
            .containerBackground(for: .widget) { RococoInk.stone }
            .widgetURL(URL(string: "baroque://brief"))   // opens the whole Daily Brief in the app (BriefView)
    }
}

struct TodayWidget: Widget {
    let kind = "BaroqueToday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Baroque Today")
        .description("Today's tasks from your Daily Brief on painted stone; medium adds the still life's roses, and large gives every task room to read under the brief's picture of the day. Tap for the whole brief.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Quote widget

struct NextQuoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Next quote"
    static var description = IntentDescription("Shows the next quote from your vault.")

    func perform() async throws -> some IntentResult {
        Store.shared.bumpQuoteOffset()
        // The large Day shows the quote after this one, so it moves on too.
        WidgetCenter.shared.reloadTimelines(ofKind: "BaroqueQuote")
        WidgetCenter.shared.reloadTimelines(ofKind: "BaroqueDay")
        return .result()
    }
}

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: Quote
    var error: String? = nil
}

struct QuoteProvider: TimelineProvider {
    /// How many rotations one timeline lays out.
    static let slots = 6

    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: Date(), quote: DataLoader.fallbackQuotes[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        let pool = DataLoader.quotePool(Store.shared.quoteSnapshot)
        let idx = DataLoader.quoteIndex(count: pool.count, offset: Store.shared.quoteOffset, at: Date(), settings: Store.shared.settings)
        completion(QuoteEntry(date: Date(), quote: pool[idx]))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        Task {
            let settings = Store.shared.settings
            let step = DataLoader.quoteStep(settings: settings)
            // The cache serves for as long as one timeline runs, so a tap on the quote (which reloads this timeline)
            // shows the next one at once instead of waiting on GitHub. Save & Refresh in the app still fetches.
            let snap = await DataLoader.loadQuotes(maxAge: Double(QuoteProvider.slots) * step)
            let pool = DataLoader.quotePool(snap)
            let offset = Store.shared.quoteOffset
            let first = DataLoader.quoteSlot(at: Date(), settings: settings)
            // Six rotations ahead, on wall-clock slots so the sequence keeps moving across reloads.
            // The next-quote button bumps the offset, which shifts the whole sequence forward.
            let entries = (0..<QuoteProvider.slots).map { i -> QuoteEntry in
                let date = Date(timeIntervalSince1970: Double(first + i) * step)
                let idx = DataLoader.quoteIndex(count: pool.count, offset: offset, at: date, settings: settings)
                return QuoteEntry(date: date, quote: pool[idx], error: snap.error)
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }
}

struct QuoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: QuoteEntry

    private var size: BaroqueSize {
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        default: return .large
        }
    }

    // The quote itself is the next-quote button.
    var body: some View {
        RococoQuoteView(quote: entry.quote, size: size, date: entry.date, error: entry.error) { words in
            AnyView(Button(intent: NextQuoteIntent()) { words }.buttonStyle(.plain))
        }
        .containerBackground(for: .widget) { RococoInk.umber }
    }
}

struct QuoteWidget: Widget {
    let kind = "BaroqueQuote"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteProvider()) { entry in
            QuoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Baroque Quote")
        .description("Rotating quotes from your vault over your own photographs, repainted in oils. Tap the quote for the next.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Battery widget

struct BatteryEntry: TimelineEntry {
    let date: Date
    let reading: BatteryReading
}

struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(date: Date(), reading: BatteryReading(level: 0.82, charging: false, at: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        Task { @MainActor in
            let reading = BatteryProvider.read()
            // The gallery shows a sample when iOS won't give a level (the simulator).
            completion(BatteryEntry(date: Date(), reading: reading.level == nil && context.isPreview
                                    ? BatteryReading(level: 0.82, charging: false, at: Date()) : reading))
        }
    }

    // iOS gives no battery events to a widget, so it reads the level whenever it refreshes and asks again in 15 minutes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        Task { @MainActor in
            let now = Date()
            let entry = BatteryEntry(date: now, reading: BatteryProvider.read())
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
        }
    }

    @MainActor
    static func read() -> BatteryReading {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        let charging = device.batteryState == .charging || device.batteryState == .full
        return BatteryReading(level: level < 0 ? nil : Double(level), charging: charging, at: Date())
    }
}

struct BatteryWidget: Widget {
    let kind = "BaroqueBattery"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BatteryProvider()) { entry in
            RococoBatteryView(reading: entry.reading)
                .containerBackground(for: .widget) { RococoInk.stone }
        }
        .configurationDisplayName("Baroque Battery")
        .description("Your iPhone's charge, inlaid in gold on painted stone. It updates when iOS refreshes the widget, about every 15 minutes.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - Still Life widget

/// Just the flower still life, edge to edge: no words, no stone (asked for on 2026-11-05: "just the picture of the
/// flower pot with nothing else on it"). Small and large; a medium would show only a slice of the upright painting.
struct StillLifeProvider: TimelineProvider {
    func placeholder(in context: Context) -> StillLifeEntry { StillLifeEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (StillLifeEntry) -> Void) { completion(StillLifeEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StillLifeEntry>) -> Void) {
        completion(Timeline(entries: [StillLifeEntry(date: Date())], policy: .never))
    }
}

struct StillLifeEntry: TimelineEntry {
    let date: Date
}

struct StillLifeWidget: Widget {
    let kind = "BaroqueStillLife"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StillLifeProvider()) { _ in
            StillLifeView()
        }
        .configurationDisplayName("Baroque Still Life")
        .description("The flower still life in its glass, and nothing else.")
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct StillLifeView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetPicture(name: family == .systemLarge ? "RococoStillLifeLarge" : "RococoStillLife")
    }
}

/// A painting filling the widget. It is the widget's content, not its container background, because iOS takes the
/// container background away on tinted and clear home screens; behind it is the umber the pictures' words sit on.
struct WidgetPicture: View {
    var name: String

    var body: some View {
        Color.clear
            .overlay { Image(name).resizable().interpolation(.high).rococoFullColor().scaledToFill() }
            .clipped()
            .containerBackground(for: .widget) { RococoInk.umber }
    }
}

// MARK: - Photograph widget

/// One of the user's repainted photographs and nothing else, a new one every three hours (2026-11-08: "a widget similar
/// to this that is for the small variant and has no text on it"); never the one the large Day widget is showing.
struct PhotographProvider: TimelineProvider {
    func placeholder(in context: Context) -> StillLifeEntry { StillLifeEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (StillLifeEntry) -> Void) { completion(StillLifeEntry(date: Date())) }

    /// A day of turns, laid out ahead; nothing to fetch.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StillLifeEntry>) -> Void) {
        var entries = [StillLifeEntry(date: Date())]
        var t = Date()
        for _ in 0..<(24 / RococoPhotos.hours) {
            t = RococoPhotos.nextChange(after: t)
            entries.append(StillLifeEntry(date: t))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct PhotographWidget: Widget {
    let kind = "BaroquePhotograph"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotographProvider()) { entry in
            WidgetPicture(name: RococoPhotos.small(at: entry.date))
        }
        .configurationDisplayName("Baroque Photograph")
        .description("Your own photographs, repainted in oils, and nothing else: a new one every three hours.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
