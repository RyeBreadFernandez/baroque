import SwiftUI

// The Day widget as a bento box. Each tile holds one fact:
//   large   sky window (hero: today's arc, sunrise and sunset) | date page
//           week channel                                       | weather well
//           task slab, five rows, across the bottom
//   medium  date page | temperature well   ||  task slab, three rows
//           landscape window               ||
//   small   date page | weather window (the temperature on the near ridge)
//           next task with the count, across the bottom

/// What a tile is made of.
enum BNMaterial {
    case slab, well, window
}

/// One tile at its rect: content sized to the tile, its material behind, set in place in the widget.
struct BNTile<Content: View>: View {
    var rect: CGRect
    var material: BNMaterial
    var ornament: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: rect.width, height: rect.height)
            .background {
                switch material {
                case .slab: BNSlab(rect: rect)
                case .well: BNWell()
                case .window: BNWindowFrame(ornament: ornament)
                }
            }
            .position(x: rect.midX, y: rect.midY)
    }
}

struct BNDayWidget: View {
    var snapshot: DaySnapshot
    var size: BaroqueSize
    var canvas: CGSize
    var maxTasks: Int = 5

    var body: some View {
        Group {
            switch size {
            case .large: large
            case .medium: medium
            case .small: small
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .overlay(BNRim())
    }

    // MARK: Large

    private var large: some View {
        let g = BN.grid(canvas)
        let band = g.bnRows([.fr(1), .pt(163)])
        let cols = band[0].bnColumns([.fr(196), .fr(127)])
        let left = cols[0].bnRows([.fr(1), .pt(40)])
        let right = cols[1].bnRows([.fr(1), .pt(66)])
        let window = left[0], week = left[1], date = right[0], weather = right[1], tasks = band[1]
        let seam = cols[0].maxX + BN.gutter / 2
        return ZStack {
            BNDayScene(snapshot: snapshot, plan: .day(.large, window: window, canvas: canvas))
            BNTile(rect: window, material: .window) {
                BNDaylight(weather: snapshot.weather)
            }
            BNTile(rect: date, material: .slab) {
                BNDatePage(date: snapshot.date, style: .large)
            }
            BNTile(rect: weather, material: .well) {
                BNWeatherWell(weather: snapshot.weather)
            }
            BNTile(rect: week, material: .well) {
                BNWeekChannel(date: snapshot.date)
            }
            BNTile(rect: tasks, material: .slab) {
                BNTaskSlab(tasks: snapshot.tasks, error: snapshot.taskError, maxRows: min(maxTasks, 5), compact: false)
            }
            BNStud(size: 8).position(x: seam, y: band[0].maxY + BN.gutter / 2)
        }
    }

    // MARK: Medium

    private var medium: some View {
        let g = BN.grid(canvas)
        let cols = g.bnColumns([.fr(128), .fr(195)])
        let left = cols[0].bnRows([.fr(1), .pt(54)])
        let top = left[0].bnColumns([.fr(1), .fr(1)])
        let date = top[0], temp = top[1], window = left[1], tasks = cols[1]
        return ZStack {
            BNDayScene(snapshot: snapshot, plan: .day(.medium, window: window, canvas: canvas))
            BNTile(rect: window, material: .window) { Color.clear }
            BNTile(rect: date, material: .slab) {
                BNDatePage(date: snapshot.date, style: .compact)
            }
            BNTile(rect: temp, material: .well) {
                BNTemperatureWell(weather: snapshot.weather)
            }
            BNTile(rect: tasks, material: .slab) {
                BNTaskSlab(tasks: snapshot.tasks, error: snapshot.taskError, maxRows: min(maxTasks, 3), compact: true)
            }
            BNStud(size: 7).position(x: cols[0].maxX + BN.gutter / 2, y: left[0].maxY + BN.gutter / 2)
        }
    }

    // MARK: Small

    private var small: some View {
        let g = BN.grid(canvas)
        let rows = g.bnRows([.fr(1), .pt(52)])
        let top = rows[0].bnColumns([.fr(1), .fr(1)])
        let date = top[0], window = top[1], task = rows[1]
        return ZStack {
            BNDayScene(snapshot: snapshot, plan: .day(.small, window: window, canvas: canvas))
            BNTile(rect: window, material: .window) {
                BNWeatherWindow(weather: snapshot.weather)
            }
            BNTile(rect: date, material: .slab) {
                BNDatePage(date: snapshot.date, style: .compact)
            }
            BNTile(rect: task, material: .slab) {
                BNNextTask(tasks: snapshot.tasks, error: snapshot.taskError)
            }
            BNStud(size: 6.5).position(x: top[0].maxX + BN.gutter / 2, y: rows[0].maxY + BN.gutter / 2)
        }
    }
}

// MARK: - Date page

/// A calendar page in gold leaf: weekday, the day's numeral, the month.
struct BNDatePage: View {
    enum Style { case large, compact }

    var date: Date
    var style: Style

    var body: some View {
        let large = style == .large
        VStack(spacing: 0) {
            Group {
                if large {
                    Text(date, format: .dateTime.weekday(.wide))
                } else {
                    Text(date, format: .dateTime.weekday(.abbreviated))
                }
            }
            .font(.system(size: large ? 10.5 : 10, weight: .bold))
            .tracking(large ? 2.2 : 1.8)
            .textCase(.uppercase)
            .foregroundStyle(Stone.copperInk)
            .raised()
            .lineLimit(1)
            .minimumScaleFactor(0.9)

            Text(date, format: .dateTime.day())
                .font(Serif.font(large ? 54 : 40, weight: .medium))
                .foregroundStyle(Gilt.style)
                .raised(1.2)
                .lineLimit(1)
                .padding(.top, large ? -2 : -3)
                .padding(.bottom, large ? -6 : -5)

            ViewThatFits(in: .horizontal) {
                if large {
                    Text(date, format: .dateTime.month(.wide).year())
                }
                Text(date, format: .dateTime.month(.wide))
                Text(date, format: .dateTime.month(.abbreviated))
            }
            .font(Serif.font(large ? 13.5 : 12, italic: true))
            .foregroundStyle(Stone.goldMuted)
            .raised()
            .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Weather

private func bnTemp(_ w: WeatherSnapshot?) -> String { w.map { "\(Int($0.temperature.rounded()))°" } ?? "—" }

/// Large: the reading, high and low, and the condition, carved into the scene beside the date.
struct BNWeatherWell: View {
    var weather: WeatherSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 5) {
                WeatherGlyph(symbol: weather?.symbolName ?? "cloud.fill", size: 16)
                Text(bnTemp(weather))
                    .font(Serif.font(30, weight: .semibold))
                    .foregroundStyle(Gilt.style)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 2)
                if let w = weather {
                    VStack(alignment: .trailing, spacing: 1) {
                        HighLow(high: w.high, low: nil, size: 10.5)
                        HighLow(high: nil, low: w.low, size: 10.5)
                    }
                    .foregroundStyle(Stone.gold)
                    .fixedSize()
                }
            }
            Text(weather?.label ?? "Unavailable")
                .font(Serif.font(13, weight: .medium, italic: true))
                .foregroundStyle(Stone.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, -2)
        }
        .legible()
        .padding(.horizontal, BN.pad + 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Medium: the temperature alone, with its glyph and the day's range.
struct BNTemperatureWell: View {
    var weather: WeatherSnapshot?

    var body: some View {
        VStack(spacing: 1) {
            WeatherGlyph(symbol: weather?.symbolName ?? "cloud.fill", size: 15)
            Text(bnTemp(weather))
                .font(Serif.font(25, weight: .semibold))
                .foregroundStyle(Gilt.style)
                .lineLimit(1)
                .fixedSize()
            if let w = weather {
                ViewThatFits(in: .horizontal) {
                    HighLow(high: w.high, low: w.low, size: 9.5)
                    VStack(spacing: 0) {
                        HighLow(high: w.high, low: nil, size: 9.5)
                        HighLow(high: nil, low: w.low, size: 9.5)
                    }
                }
                .foregroundStyle(Stone.gold)
            } else {
                Text("Unavailable")
                    .font(Serif.font(11, italic: true))
                    .foregroundStyle(Stone.goldMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .legible()
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Small: the window is the weather (sun or moon, clouds, rain or snow); the temperature stands on the near ridge.
struct BNWeatherWindow: View {
    var weather: WeatherSnapshot?

    var body: some View {
        Text(bnTemp(weather))
            .font(Serif.font(24, weight: .semibold))
            .foregroundStyle(Gilt.style)
            .legible(1.1)
            .lineLimit(1)
            .fixedSize()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 7)
    }
}

/// Large window: sunrise and sunset written at the feet of the day's arc.
struct BNDaylight: View {
    var weather: WeatherSnapshot?

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if let rise = weather?.sunrise, let set = weather?.sunset {
                HStack(alignment: .lastTextBaseline) {
                    event("sunrise.fill", rise, leading: true)
                    Spacer(minLength: 4)
                    event("sunset.fill", set, leading: false)
                }
            }
        }
        .padding(.horizontal, BN.pad + 1)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func event(_ symbol: String, _ time: Date, leading: Bool) -> some View {
        HStack(spacing: 3) {
            if leading { icon(symbol) }
            Text(time, format: .dateTime.hour().minute())
                .font(.system(size: 10.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Stone.gold)
            if !leading { icon(symbol) }
        }
        .legible()
        .fixedSize()
    }

    private func icon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Stone.copperInk)
    }
}

// MARK: - Week

/// The week cut as a channel; today is a copper pebble whose corners nest in the channel's.
struct BNWeekChannel: View {
    var date: Date

    private var days: [(label: String, date: Date)] {
        let cal = Calendar.current
        let mondayOffset = (cal.component(.weekday, from: date) + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -mondayOffset, to: cal.startOfDay(for: date)) else { return [] }
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).compactMap { i in
            cal.date(byAdding: .day, value: i, to: monday).map { (letters[i], $0) }
        }
    }

    var body: some View {
        let cal = Calendar.current
        HStack(spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, item in
                let isToday = cal.isDate(item.date, inSameDayAs: date)
                let isPast = !isToday && item.date < cal.startOfDay(for: date)
                VStack(spacing: -1) {
                    Text(item.label)
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.6)
                    Text(item.date, format: .dateTime.day())
                        .font(Serif.font(14.5, weight: isToday ? .bold : .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(isToday ? Stone.parchment : Stone.gold.opacity(isPast ? 0.62 : 0.95))
                .raised()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isToday { Pebble(shape: RoundedRectangle(cornerRadius: BN.radius - 3, style: .continuous)) }
                }
            }
        }
        .padding(3)
    }
}

// MARK: - Tasks

/// The task slab: "Today" with the count, rows in agenda order, then what didn't fit and any fetch error.
struct BNTaskSlab: View {
    var tasks: [TaskItem]
    var error: String?
    var maxRows: Int
    var compact: Bool

    private var shown: Int { min(tasks.count, max(1, maxRows)) }
    private var spacing: CGFloat { compact ? 5 : 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack(alignment: .center) {
                Text("Today")
                    .font(Serif.font(compact ? 14.5 : 16.5, weight: .semibold))
                    .foregroundStyle(Stone.gold)
                    .raised()
                Spacer(minLength: 4)
                if !tasks.isEmpty { CountPill(count: tasks.count) }
            }
            if tasks.isEmpty {
                emptyState
            } else {
                ForEach(Array(tasks.prefix(shown).enumerated()), id: \.element.id) { i, t in
                    TaskRow(task: t, compact: compact)
                        .frame(maxHeight: compact ? 22 : 24)
                        .overlay(alignment: .top) {
                            if i > 0 {
                                EngravedRule()
                                    .padding(.leading, compact ? 18 : 22)
                                    .offset(y: -(spacing / 2) - 0.7)
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
                            ErrorLine(message: error, prefix: "Cached", color: Stone.copperInk)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, compact ? 11 : 13)
        .padding(.top, compact ? 9 : 10)
        .padding(.bottom, compact ? 8 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var emptyState: some View {
        Spacer(minLength: 0)
        VStack(spacing: compact ? 4 : 6) {
            Image(systemName: error == nil ? "checkmark" : "exclamationmark")
                .font(.system(size: compact ? 12 : 15, weight: .bold))
                .foregroundStyle(error == nil ? Stone.sage : Stone.copperInk)
                .raised()
                .frame(width: compact ? 28 : 36, height: compact ? 28 : 36)
                .carved(Circle())
            Text(error == nil ? "Nothing due. Nice." : "Couldn't load tasks")
                .font(Serif.font(compact ? 13 : 15, weight: .semibold))
                .foregroundStyle(Stone.gold)
                .raised()
            if let error {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Stone.copperInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(compact ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        Spacer(minLength: 0)
    }
}

/// Small: the next task in agenda order across the bottom, on two lines if it needs them, with the count.
struct BNNextTask: View {
    var tasks: [TaskItem]
    var error: String?

    // TaskRow's gem colors: overdue copper, high priority gold, otherwise sage.
    private func accent(_ t: TaskItem) -> Color {
        if t.isOverdue { return Stone.copperLight }
        if t.priority >= .high { return Stone.gold }
        return Stone.sage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if tasks.isEmpty, let error {
                Label {
                    Text(error).lineLimit(2)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9.5, weight: .semibold))
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Stone.copperInk)
            } else if let first = tasks.first {
                if let error {
                    // Cached tasks: say why they may be stale, and keep the next one visible.
                    ErrorLine(message: error, prefix: "Cached", color: Stone.copperInk, fontSize: 9.5)
                }
                HStack(alignment: .center, spacing: 5) {
                    TaskSocket(accent: accent(first), size: 12)
                    Text(first.text)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Stone.parchment)
                        .raised(0.8)
                        .lineLimit(error == nil ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 2)
                    CountPill(count: tasks.count)
                }
            } else {
                Label {
                    Text("Nothing due. Nice.")
                } icon: {
                    Image(systemName: "checkmark.circle").foregroundStyle(Stone.sage)
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Stone.goldMuted)
            }
        }
        .padding(.leading, 9)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
