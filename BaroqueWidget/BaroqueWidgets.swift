import WidgetKit
import SwiftUI
import AppIntents
import UIKit

// The widgets are drawn in the rococo look (Shared/Rococo*.swift): Day, Today, Quote and Battery.

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
    let snapshot: DaySnapshot
    let settings: BaroqueSettings
    /// The large Day widget's line from the vault: the one after the Quote widget's, so the two differ.
    var quote: Quote? = nil
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), snapshot: DayProvider.sample, settings: Store.shared.settings, quote: DemoData.quotes[2])
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        let cached = Store.shared.daySnapshot ?? DayProvider.sample
        completion(DayEntry(date: Date(), snapshot: cached, settings: Store.shared.settings, quote: DayProvider.quote(at: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        Task {
            let snap = await DataLoader.loadDay()
            let settings = Store.shared.settings
            let now = Date()
            // Refresh in ~30 minutes. In between, re-draw when the photograph's turn changes (every three hours; the
            // last turn of the day ends at midnight, when the date flips too).
            let next = now.addingTimeInterval(30 * 60)
            var entries = [DayEntry(date: now, snapshot: snap, settings: settings, quote: DayProvider.quote(at: now))]
            let change = RococoPhotos.nextChange(after: now)
            if change < next {
                var later = snap
                later.date = change
                entries.append(DayEntry(date: change, snapshot: later, settings: settings, quote: DayProvider.quote(at: change)))
            }
            completion(Timeline(entries: entries, policy: .after(next)))
        }
    }

    static var sample: DaySnapshot { DemoData.day() }

    /// The cached quotes (the Quote widget fetches them), one step past the Quote widget's.
    static func quote(at date: Date) -> Quote {
        let cached = Store.shared.quoteSnapshot?.quotes ?? []
        let list = cached.isEmpty ? DataLoader.fallbackQuotes : cached
        let i = DataLoader.quoteIndex(count: list.count, offset: Store.shared.quoteOffset, at: date, settings: Store.shared.settings)
        return list[(i + 1) % list.count]
    }
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
        StaticConfiguration(kind: kind, provider: DayProvider()) { entry in
            DayWidgetView(entry: entry)
        }
        .configurationDisplayName("Baroque Day")
        .description("The sun's path carved in painted stone, the days ahead, and on large your Kings Canyon with the date, temperature and a line from your vault.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Today widget

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DayEntry

    var body: some View {
        RococoTodayView(snapshot: entry.snapshot, size: family == .systemSmall ? .small : family == .systemMedium ? .medium : .large)
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
        .description("Today's tasks from your Daily Brief on painted stone; medium adds the still life's roses, and large gives every task room to read. Tap for the whole brief.")
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
        WidgetCenter.shared.reloadTimelines(ofKind: "BaroqueQuote")
        return .result()
    }
}

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: Quote
    let total: Int
    var error: String? = nil
}

struct QuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: Date(), quote: DataLoader.fallbackQuotes[0], total: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        let quotes = Store.shared.quoteSnapshot?.quotes ?? DataLoader.fallbackQuotes
        let list = quotes.isEmpty ? DataLoader.fallbackQuotes : quotes
        let idx = DataLoader.quoteIndex(count: list.count, offset: Store.shared.quoteOffset, at: Date(), settings: Store.shared.settings)
        completion(QuoteEntry(date: Date(), quote: list[idx], total: list.count))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        Task {
            let snap = await DataLoader.loadQuotes()
            let list = snap.quotes.isEmpty ? DataLoader.fallbackQuotes : snap.quotes
            let settings = Store.shared.settings
            let step = DataLoader.quoteStep(settings: settings)
            let offset = Store.shared.quoteOffset
            let first = DataLoader.quoteSlot(at: Date(), settings: settings)
            // Six rotations ahead, on wall-clock slots so the sequence keeps moving across reloads.
            // The next-quote button bumps the offset, which shifts the whole sequence forward.
            var entries: [QuoteEntry] = []
            for i in 0..<6 {
                let idx = (offset + first + i) % list.count
                let date = Date(timeIntervalSince1970: Double(first + i) * step)
                entries.append(QuoteEntry(date: date, quote: list[idx], total: list.count, error: snap.error))
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
        Color.clear
            .containerBackground(for: .widget) {
                Image(family == .systemLarge ? "RococoStillLifeLarge" : "RococoStillLife")
                    .resizable()
                    .interpolation(.high)
                    .rococoFullColor()
                    .scaledToFill()
            }
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
            Color.clear
                .containerBackground(for: .widget) {
                    Image(RococoPhotos.small(at: entry.date)).resizable().interpolation(.high).rococoFullColor().scaledToFill()
                }
        }
        .configurationDisplayName("Baroque Photograph")
        .description("Your own photographs, repainted in oils, and nothing else: a new one every three hours.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
