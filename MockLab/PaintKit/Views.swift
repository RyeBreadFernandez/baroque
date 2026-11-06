import SwiftUI

// MARK: - Day widget content (date + weather + today's tasks)

// Layout budgets assume the content area inside WidgetKit's 16pt margins: 126pt (small/medium) and
// 322pt (large) tall on 6.1" iPhones, 132pt / 333pt on iPhone 17 and 17 Pro, 138pt / 350pt on Pro Max.
// The mountains and sky are drawn by DayBackground and line up with this layout: on large the header's
// middle stays open for the sun's arc; on medium the weather sits on the near ridge at the bottom left.
struct DayView: View {
    var snapshot: DaySnapshot
    var settings: BaroqueSettings
    var size: BaroqueSize

    private var date: Date { snapshot.date }

    var body: some View {
        switch size {
        case .large: large
        case .medium: medium
        case .small: small
        }
    }

    // MARK: Large

    private var large: some View {
        // Tighter spacing on short widgets so five tasks still fit.
        ViewThatFits(in: .vertical) {
            largeLayout(spacing: 7)
            largeLayout(spacing: 4)
        }
    }

    private func largeLayout(spacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack(alignment: .top, spacing: 8) {
                DateBlock(date: date, style: .large)
                Spacer(minLength: 0)
                SkyWeather(weather: snapshot.weather, now: date, style: .large)
            }
            WeekStrip(date: date)
            TaskList(tasks: snapshot.tasks, error: snapshot.taskError, maxRows: min(settings.maxTasks, 5), compact: false)
                .frame(maxHeight: .infinity)
        }
    }

    // MARK: Medium

    private var medium: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                DateBlock(date: date, style: .medium)
                Spacer(minLength: 4)
                GroundWeather(weather: snapshot.weather)
            }
            .frame(width: 114)
            TaskList(tasks: snapshot.tasks, error: snapshot.taskError, maxRows: min(settings.maxTasks, 3), compact: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Small

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                DateBlock(date: date, style: .small)
                Spacer(minLength: 0)
                SkyWeather(weather: snapshot.weather, now: date, style: .small)
            }
            Spacer(minLength: 6)
            TaskPeek(tasks: snapshot.tasks, error: snapshot.taskError)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DateBlock: View {
    enum Style { case large, medium, small }

    var date: Date
    var style: Style
    var showsWeekday: Bool = true

    private var daySize: CGFloat { style == .large ? 52 : 36 }

    static func weekday(_ date: Date, style: Style) -> some View {
        Text(date, format: .dateTime.weekday(.wide))
            .font(.system(size: style == .large ? 11 : 10, weight: .bold))
            .tracking(style == .large ? 2.4 : 1.6)
            .textCase(.uppercase)
            .foregroundStyle(Stone.copperInk)
            .legible()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsWeekday {
                DateBlock.weekday(date, style: style)
            }
            // Gold leaf, standing off the painting.
            Text(date, format: .dateTime.day())
                .font(Serif.font(daySize, weight: .medium))
                .foregroundStyle(Gilt.style)
                .legible(1.2)
                .lineLimit(1)
                // Serif digits carry a tall line box; pull the month up under the numeral.
                .padding(.bottom, style == .large ? -4 : -3)
            Group {
                if style == .small {
                    Text(date, format: .dateTime.month(.wide))
                } else {
                    Text(date, format: .dateTime.month(.wide).year())
                }
            }
            .font(Serif.font(style == .large ? 15 : 12.5, italic: true))
            .foregroundStyle(Stone.goldMuted)
            .legible()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
    }
}

struct WeekStrip: View {
    var date: Date

    private var days: [(label: String, date: Date)] {
        let cal = Calendar.current
        let weekdayIndex = cal.component(.weekday, from: date) // 1 = Sunday
        let mondayOffset = (weekdayIndex + 5) % 7 // days since Monday
        guard let monday = cal.date(byAdding: .day, value: -mondayOffset, to: cal.startOfDay(for: date)) else { return [] }
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: monday) else { return nil }
            return (letters[i], d)
        }
    }

    var body: some View {
        // A channel cut into the ground; today is a copper pebble set into it.
        HStack(spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, item in
                let cal = Calendar.current
                let isToday = cal.isDate(item.date, inSameDayAs: date)
                let isPast = !isToday && item.date < cal.startOfDay(for: date)
                VStack(spacing: -1) {
                    Text(item.label)
                        .font(.system(size: 7.5, weight: .heavy))
                        .tracking(0.8)
                    Text(item.date, format: .dateTime.day())
                        .font(Serif.font(13, weight: isToday ? .bold : .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(isToday ? Stone.parchment : Stone.gold.opacity(isPast ? 0.55 : 0.92))
                .raised()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background {
                    if isToday { Pebble(shape: RoundedRectangle(cornerRadius: 9, style: .continuous)) }
                }
            }
        }
        .padding(2.5)
        .carved(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// Weather written into the sky: right-aligned at the top of the large and small Day widgets.
struct SkyWeather: View {
    enum Style { case large, small }

    var weather: WeatherSnapshot?
    var now: Date
    var style: Style

    private var temp: String { weather.map { "\(Int($0.temperature.rounded()))°" } ?? "—" }
    private var symbol: String { weather?.symbolName ?? "cloud.fill" }

    var body: some View {
        Group {
            switch style {
            case .large:
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .center, spacing: 5) {
                        WeatherGlyph(symbol: symbol, size: 18)
                        Text(temp)
                            .font(Serif.font(32, weight: .semibold))
                            .foregroundStyle(Gilt.style)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    Text(weather?.label ?? "Unavailable")
                        .font(Serif.font(14, weight: .medium, italic: true))
                        .foregroundStyle(Stone.parchment)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let w = weather {
                        HighLow(high: w.high, low: w.low, size: 10.5)
                            .foregroundStyle(Stone.gold)
                            .padding(.top, 2)
                        if let rise = w.sunrise, let set = w.sunset {
                            SunEvent(now: now, sunrise: rise, sunset: set)
                                .padding(.top, 1)
                        }
                    }
                }
                .frame(maxWidth: 124, alignment: .trailing)
            case .small:
                VStack(alignment: .trailing, spacing: 1) {
                    WeatherGlyph(symbol: symbol, size: 15)
                    Text(temp)
                        .font(Serif.font(20, weight: .semibold))
                        .foregroundStyle(Gilt.style)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .legible()
    }
}

// Weather standing on the dark near ridge at the bottom left of the medium Day widget.
struct GroundWeather: View {
    var weather: WeatherSnapshot?

    private var temp: String { weather.map { "\(Int($0.temperature.rounded()))°" } ?? "—" }
    private var symbol: String { weather?.symbolName ?? "cloud.fill" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                row(showsHighLow: true)
                row(showsHighLow: false)
            }
            Text(weather?.label ?? "Unavailable")
                .font(Serif.font(12, weight: .medium, italic: true))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(Stone.parchment)
        .legible()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(showsHighLow: Bool) -> some View {
        HStack(alignment: .center, spacing: 4) {
            WeatherGlyph(symbol: symbol, size: 13)
            Text(temp)
                .font(Serif.font(22, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
            if showsHighLow, let w = weather {
                Spacer(minLength: 2)
                VStack(alignment: .trailing, spacing: 0) {
                    HighLow(high: w.high, low: nil, size: 9.5)
                    HighLow(high: nil, low: w.low, size: 9.5)
                }
                .fixedSize()
            }
        }
    }
}

// Sun and moon in gold; clouds and rain in parchment.
struct WeatherGlyph: View {
    var symbol: String
    var size: CGFloat

    var body: some View {
        let warm = Stone.goldBright
        let base = Stone.parchment
        let image = Image(systemName: symbol).font(.system(size: size, weight: .semibold))
        if symbol.hasPrefix("sun") {
            image.foregroundStyle(warm)
        } else if symbol.contains("sun") || symbol.contains("moon") {
            image.symbolRenderingMode(.palette).foregroundStyle(base, warm)
        } else {
            image.symbolRenderingMode(.hierarchical).foregroundStyle(base)
        }
    }
}

struct HighLow: View {
    var high: Double?
    var low: Double?
    var size: CGFloat

    var body: some View {
        HStack(spacing: 7) {
            if let high { part("arrow.up", high) }
            if let low { part("arrow.down", low) }
        }
    }

    private func part(_ symbol: String, _ value: Double) -> some View {
        HStack(spacing: 1.5) {
            Image(systemName: symbol).font(.system(size: size - 2.5, weight: .heavy)).opacity(0.85)
            Text("\(Int(value.rounded()))°").font(.system(size: size, weight: .semibold)).monospacedDigit()
        }
    }
}

// The next sunrise or sunset (the sky shows where the sun is now).
struct SunEvent: View {
    var now: Date
    var sunrise: Date
    var sunset: Date

    private var next: (symbol: String, time: Date) {
        let cal = Calendar.current
        func today(_ d: Date) -> Date {
            let c = cal.dateComponents([.hour, .minute], from: d)
            return cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: now) ?? d
        }
        let rise = today(sunrise), set = today(sunset)
        if now < rise { return ("sunrise.fill", rise) }
        if now < set { return ("sunset.fill", set) }
        return ("sunrise.fill", rise.addingTimeInterval(86_400))
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: next.symbol)
                .font(.system(size: 10, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Stone.copperInk)
            Text(next.time, format: .dateTime.hour().minute())
                .font(.system(size: 10.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Stone.gold)
        }
        .fixedSize()
    }
}

struct CountPill: View {
    var count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Stone.parchment)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .raised()
            .frame(minWidth: 20)
            .background(Pebble(shape: Capsule()))
    }
}

// One-line warning that shortens itself to fit: "Cached · full message", then the full message,
// then its first sentence, then a truncated first sentence.
struct ErrorLine: View {
    var message: String
    var prefix: String? = nil
    var color: Color
    var fontSize: CGFloat = 10

    private var firstSentence: String {
        guard let r = message.range(of: ". ") else { return message }
        return String(message[..<r.lowerBound]) + "."
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            line(prefix.map { "\($0) · \(message)" } ?? message)
            line(message)
            line(prefix.map { "\($0) · \(firstSentence)" } ?? firstSentence)
            line(firstSentence)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Always one line tall: stacks must not treat it as squeezable when they divide up the height.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func line(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: fontSize - 1, weight: .semibold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: fontSize, weight: .semibold))
        .foregroundStyle(color)
    }
}

struct TaskList: View {
    var tasks: [TaskItem]
    var error: String?
    var maxRows: Int
    var compact: Bool

    private var shown: Int { min(tasks.count, max(1, maxRows)) }
    private var rowSpacing: CGFloat { compact ? 5 : 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            HStack(alignment: .center) {
                Text("Today")
                    .font(Serif.font(compact ? 14.5 : 17, weight: .semibold))
                    .foregroundStyle(Stone.gold)
                    .raised()
                Spacer(minLength: 4)
                if !tasks.isEmpty {
                    CountPill(count: tasks.count)
                }
            }

            if tasks.isEmpty {
                if compact {
                    emptyState
                    Spacer(minLength: 0)
                } else {
                    // Large slab: center the message so the empty space reads as intentional.
                    Spacer(minLength: 0)
                    emptyState
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                    Spacer(minLength: 0)
                }
            } else {
                ForEach(Array(tasks.prefix(shown).enumerated()), id: \.element.id) { i, t in
                    // Rows may grow a little so spare height spreads between them instead of pooling at the bottom.
                    TaskRow(task: t, compact: compact)
                        .frame(maxHeight: compact ? 20 : 24)
                        // A cut line between rows, drawn in the gap so it costs no height.
                        .overlay(alignment: .top) {
                            if i > 0 {
                                EngravedRule()
                                    .padding(.leading, compact ? 18 : 22)
                                    .offset(y: -(rowSpacing / 2) - 0.7)
                            }
                        }
                }
                Spacer(minLength: 0)
                if tasks.count > shown || error != nil {
                    HStack(spacing: 10) {
                        if tasks.count > shown {
                            Text("+\(tasks.count - shown) more")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Stone.goldFaint)
                                .fixedSize()
                        }
                        if let error {
                            // Showing cached tasks; say why they may be stale.
                            ErrorLine(message: error, prefix: "Cached", color: Stone.copperInk)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .stoneSlab(.panel, radius: compact ? 15 : 18, depth: compact ? 2.5 : 3)
    }

    @ViewBuilder
    private var emptyState: some View {
        if compact {
            if let error {
                VStack(alignment: .leading, spacing: 2) {
                    Label {
                        Text("Couldn't load tasks")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Stone.copperInk)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Stone.goldMuted)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Label {
                    Text("Nothing due. Nice.")
                } icon: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(Stone.sage)
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Stone.goldMuted)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: error == nil ? "checkmark" : "exclamationmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(error == nil ? Stone.sage : Stone.copperInk)
                    .raised()
                    .frame(width: 36, height: 36)
                    .carved(Circle())
                Text(error == nil ? "Nothing due. Nice." : "Couldn't load tasks")
                    .font(Serif.font(15, weight: .semibold))
                    .foregroundStyle(Stone.gold)
                    .raised()
                if let error {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Stone.copperInk)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

// Small widget: the most urgent task (or the error) on a little painted slab.
struct TaskPeek: View {
    var tasks: [TaskItem]
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if tasks.isEmpty, let error {
                Label {
                    Text(error)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Stone.copperInk)
            } else {
                HStack(alignment: .center, spacing: 6) {
                    if let error {
                        ErrorLine(message: error, color: Stone.copperInk)
                    } else {
                        Text("Today")
                            .font(Serif.font(13, weight: .semibold))
                            .foregroundStyle(Stone.gold)
                            .raised()
                    }
                    Spacer(minLength: 0)
                    if !tasks.isEmpty && error == nil {
                        CountPill(count: tasks.count)
                    }
                }
                if let first = tasks.first {
                    TaskRow(task: first, compact: true, showsDue: false)
                } else {
                    Text("Nothing due. Nice.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Stone.goldMuted)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stoneSlab(.panel, radius: 13, depth: 2.5, inlay: false)
    }
}

struct TaskRow: View {
    var task: TaskItem
    var compact: Bool
    var showsDue: Bool = true

    private var accent: Color {
        if task.isOverdue { return Stone.copperLight }
        if task.priority >= .high { return Stone.gold }
        return Stone.sage
    }

    private var dueLabel: String? {
        guard showsDue, let d = task.due else { return nil }
        // The list is headed "Today"; compact rows skip the redundant label to keep room for the title.
        if task.isDueToday { return compact ? nil : "today" }
        if task.isOverdue {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: d), to: Calendar.current.startOfDay(for: Date())).day ?? 0
            return days == 1 ? "1d late" : "\(days)d late"
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            TaskSocket(accent: accent, size: compact ? 12 : 14)
            Text(task.text)
                .font(.system(size: compact ? 12 : 13, weight: .medium))
                .foregroundStyle(Stone.parchment)
                .raised(0.8)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let due = dueLabel {
                if task.isOverdue {
                    Text(due)
                        .font(.system(size: compact ? 9 : 9.5, weight: .bold))
                        .foregroundStyle(Stone.parchment)
                        .raised()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Pebble(shape: Capsule()))
                        .fixedSize()
                } else {
                    Text(due)
                        .font(Serif.font(compact ? 11 : 12, weight: .medium, italic: true))
                        .foregroundStyle(Stone.goldMuted)
                        .raised()
                        .fixedSize()
                }
            }
        }
    }
}

// A round socket cut into the slab with a small polished gem set in it; the gem's color is the priority.
struct TaskSocket: View {
    var accent: Color
    var size: CGFloat

    var body: some View {
        Circle()
            .fill(accent)
            .overlay(EllipticalGradient(colors: [.white.opacity(0.55), .white.opacity(0)],
                                        center: UnitPoint(x: 0.35, y: 0.25), startRadiusFraction: 0, endRadiusFraction: 0.7))
            .shadow(color: accent.opacity(0.6), radius: 1.5)
            .frame(width: size * 0.46, height: size * 0.46)
            .frame(width: size, height: size)
            .carved(Circle())
    }
}

// MARK: - Quote widget content

struct QuoteView: View {
    var quote: Quote
    var size: BaroqueSize
    var error: String? = nil

    // Largest first; the first size that shows the whole quote wins.
    private var textSizes: [CGFloat] {
        switch size {
        case .small: return [17, 15.5, 14, 13, 12, 11]
        case .medium: return [21, 19, 17, 15.5, 14, 13, 12]
        case .large: return [30, 27, 24, 21, 19, 17, 15.5, 14]
        }
    }

    // Medium and large widgets overlay the 30pt next-quote arrow bottom-right; keep the footer clear of it.
    private var arrowInset: CGFloat { size == .small ? 0 : 40 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: size == .small ? 3 : 6) {
                ViewThatFits(in: .vertical) {
                    ForEach(textSizes, id: \.self) { s in
                        quoteText(s)
                    }
                    // Too long for every size: fill the space and truncate the tail.
                    quoteText(textSizes.last ?? 12)
                }
            }
            // Short quotes sit in the middle of the tile instead of leaving a hole above the author.
            .frame(maxHeight: .infinity, alignment: .leading)
            .layoutPriority(1)

            // Author and error share a band beside the arrow (30pt tall on medium and large).
            VStack(alignment: .leading, spacing: 3) {
                if let a = quote.author, !a.isEmpty {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Stone.copperLight)
                            .frame(width: size == .small ? 14 : 20, height: 1.5)
                        Text(a)
                            .font(.system(size: size == .small ? 9 : 10, weight: .semibold))
                            .tracking(size == .small ? 0.6 : 1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Stone.gold)
                            .raised()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if let error {
                    ErrorLine(message: error, color: Stone.parchment.opacity(0.9), fontSize: size == .small ? 9.5 : 10)
                }
            }
            .padding(.trailing, arrowInset)
            .frame(maxWidth: .infinity, minHeight: size == .small ? 0 : 30, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .topLeading) { watermark }
    }

    // An oversized opening quote in faint gold leaf behind the text.
    private var watermark: some View {
        Text("\u{201C}")
            .font(Serif.font(size == .small ? 120 : 190, weight: .bold))
            .foregroundStyle(Stone.gold.opacity(0.13).shadow(.inner(color: .black.opacity(0.5), radius: 2, x: 0, y: 2.5)))
            .shadow(color: Stone.shadow.opacity(0.5), radius: 0, x: 0, y: 1.2)
            .fixedSize()
            .offset(x: size == .small ? -8 : -12, y: size == .small ? -30 : -50)
            .accessibilityHidden(true)
    }

    private func quoteText(_ pointSize: CGFloat) -> some View {
        Text(quote.text)
            .font(Serif.font(pointSize, weight: .medium, italic: true))
            .foregroundStyle(Stone.parchment)
            .legible()
            .lineSpacing(pointSize > 18 ? 2 : 1)
    }
}

// The copper "next quote" arrow. The widget wraps it in Button(intent:); the app preview shows it as is.
struct NextQuoteArrow: View {
    var body: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Stone.parchment)
            .raised()
            .frame(width: 30, height: 30)
            .background(Pebble(shape: Circle()))
    }
}

// Lays widget content out at an exact widget size the way WidgetKit does: inset by the 16pt default
// content margins over the container background, clipped to the widget's continuous rounded shape.
// Used by the app's live previews and the DEBUG render harness.
struct WidgetCanvas<Content: View, Background: View>: View {
    var size: CGSize
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: Content
    @ViewBuilder var background: Background

    var body: some View {
        content
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background(background)
            .containerShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
