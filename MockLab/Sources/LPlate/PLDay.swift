import SwiftUI

// The Day widget as a storybook page: today's sky painted in a plate sunk into the board, the weather
// as the plate's caption, the date in gilt and the tasks as a ruled ledger cut into the board.

struct PLDayWidget: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        Group {
            switch family {
            case .large: large
            case .medium: medium
            case .small: small
            }
        }
        .frame(width: Mock.size(family).width, height: Mock.size(family).height, alignment: .topLeading)
        .background(PLBoard())
    }

    private var date: Date { snapshot.date }

    // MARK: Large: the plate across the top, its caption, then the date beside the ledger.

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            PLPlate(shape: PLArch(rise: 0, corner: 7)) {
                PLDayScene(snapshot: snapshot, scene: .large)
            }
            .frame(height: 126)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            PLWeatherCaption(weather: snapshot.weather)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            HStack(alignment: .top, spacing: 0) {
                PLDateColumn(date: date, weather: snapshot.weather, taskCount: snapshot.tasks.count)
                    .frame(width: 64, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .top)
                PLVerticalRule()
                    .padding(.horizontal, 9)
                PLLedger(tasks: snapshot.tasks, error: snapshot.taskError, maxRows: 5, compact: false, rowHeight: 25)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
    }

    // MARK: Medium: a round-headed plate on the left, the date line and three tasks on the right.

    private var medium: some View {
        HStack(alignment: .top, spacing: 0) {
            PLPlate(shape: PLArch(rise: 60, corner: 6)) {
                PLDayScene(snapshot: snapshot, scene: .medium)
                    .overlay(alignment: .bottom) {
                        PLPlateWeather(weather: snapshot.weather, compact: false)
                            .padding(.bottom, 4)
                    }
            }
            .frame(width: 120)
            .padding(.leading, 19)
            .padding(.vertical, 19)

            VStack(alignment: .leading, spacing: 0) {
                PLDateLine(date: date, taskCount: snapshot.tasks.count, compact: false)
                PLLedger(tasks: snapshot.tasks, error: snapshot.taskError, maxRows: 3, compact: true, rowHeight: 22)
                    .padding(.top, 5)
            }
            .padding(.leading, 17)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: Small: a low arched plate with the sun and temperature, the date and next task beneath.

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            PLPlate(shape: PLArch(rise: 26, corner: 5), ruleGap: nil) {
                PLDayScene(snapshot: snapshot, scene: .small)
                    .overlay(alignment: .bottomTrailing) {
                        PLPlateWeather(weather: snapshot.weather, compact: true)
                            .padding(.trailing, 7)
                            .padding(.bottom, 1)
                    }
            }
            .frame(height: 54)
            .padding(.horizontal, 17)
            .padding(.top, 15)

            VStack(alignment: .leading, spacing: 0) {
                PLDateLine(date: date, taskCount: snapshot.tasks.count, compact: true)
                EngravedRule()
                    .padding(.top, 4)
                    .padding(.bottom, 5)
                PLTaskPeek(tasks: snapshot.tasks, error: snapshot.taskError)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - The plate's painting

struct PLDayScene: View {
    enum Scene { case large, medium, small }

    var snapshot: DaySnapshot
    var scene: Scene

    var body: some View {
        let clock = SkyClock(now: snapshot.date, weather: snapshot.weather)
        let condition = SkyCondition(code: snapshot.weather?.code)
        GeometryReader { geo in
            let w = geo.size.width
            PaintedSky(palette: SkyPalette(clock: clock, condition: condition), horizon: horizon)
                .overlay {
                    if !clock.isDay && !condition.gray {
                        PLStars(region: starRegion, count: scene == .large ? 16 : 6, sparkles: scene == .large ? 3 : 1, u: u)
                    }
                }
                .overlay(PLSkyBack(clock: clock, condition: condition, arc: arc, phase: MoonPhase(date: snapshot.date), u: u))
                .overlay(MountainRange(layers: layers(width: w), night: !clock.isDay, snowLower: condition == .snow ? 0.03 : 0))
                .overlay(mist(night: !clock.isDay))
                .overlay(PLSkyFront(clock: clock, condition: condition, arc: arc, u: u))
                // The foreground falls into shade toward the foot of the plate, as in a book engraving.
                .overlay(LinearGradient(stops: [.init(color: .clear, location: 0.7),
                                                .init(color: Stone.shadow.opacity(0.5), location: 1)],
                                        startPoint: .top, endPoint: .bottom))
        }
    }

    // Sun and cloud scale: full size on the wide plate, a little smaller in the windows.
    private var u: CGFloat {
        switch scene {
        case .large: return 1
        case .medium: return 0.85
        case .small: return 0.68
        }
    }

    private var horizon: CGFloat {
        switch scene {
        case .large: return 0.62
        case .medium: return 0.58
        case .small: return 0.66
        }
    }

    // The sun's path: across the wide plate, and following the arch of the windows.
    private var arc: SkyArc {
        switch scene {
        case .large: return SkyArc(centerX: 0.5, horizon: 0.64, radiusX: 0.34, radiusY: 0.46)
        case .medium: return SkyArc(centerX: 0.5, horizon: 0.56, radiusX: 0.33, radiusY: 0.37)
        case .small: return SkyArc(centerX: 0.42, horizon: 0.70, radiusX: 0.30, radiusY: 0.48)
        }
    }

    private var starRegion: CGRect {
        switch scene {
        case .large: return CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.3)
        case .medium: return CGRect(x: 0.2, y: 0.12, width: 0.6, height: 0.25)
        case .small: return CGRect(x: 0.25, y: 0.12, width: 0.5, height: 0.3)
        }
    }

    @ViewBuilder
    private func mist(night: Bool) -> some View {
        let haze = night ? Color(hex: 0x6F8380) : Color(hex: 0xA9B5A4)
        let (a, b, c): (CGFloat, CGFloat, CGFloat) = {
            switch scene {
            case .large: return (0.56, 0.68, 0.80)
            case .medium: return (0.5, 0.6, 0.68)
            case .small: return (0.58, 0.68, 0.78)
            }
        }()
        LinearGradient(stops: [
            .init(color: haze.opacity(0), location: a),
            .init(color: haze.opacity(0.24), location: b),
            .init(color: haze.opacity(0), location: c)
        ], startPoint: .top, endPoint: .bottom)
    }

    private func layers(width w: CGFloat) -> [MountainLayer] {
        let p = PLScenery.p
        switch scene {
        case .large:
            // A wide range: the high peaks right of centre, under the top of the sun's arc,
            // so the morning and evening sun clears them on either side.
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.60), p(0.07, 0.56), p(0.14, 0.58), p(0.22, 0.50), p(0.29, 0.54), p(0.37, 0.44), p(0.44, 0.48),
                    p(0.52, 0.36), p(0.58, 0.29), p(0.64, 0.37), p(0.70, 0.33), p(0.77, 0.43), p(0.85, 0.47), p(0.92, 0.44),
                    p(1, 0.50)], seed: 11),
                              top: Ridges.far.top, bottom: Ridges.far.bottom, rim: 0.6, snowline: 0.44),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.68), p(0.1, 0.64), p(0.2, 0.67), p(0.31, 0.60), p(0.42, 0.64), p(0.55, 0.57), p(0.66, 0.63),
                    p(0.78, 0.60), p(0.9, 0.65), p(1, 0.62)], seed: 23),
                              top: Ridges.mid.top, bottom: Ridges.mid.bottom, rim: 0.35,
                              trees: PLScenery.trees(4...7, spacing: 5, coverage: 0.55, width: w)),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.79), p(0.14, 0.76), p(0.28, 0.79), p(0.42, 0.74), p(0.56, 0.78), p(0.70, 0.73), p(0.84, 0.77),
                    p(1, 0.75)], seed: 31),
                              top: Ridges.near.top, bottom: Ridges.near.bottom, rim: 0.25,
                              trees: PLScenery.trees(6...11, spacing: 5, coverage: 0.8, width: w))
            ]
        case .medium:
            // Peaks right of the sun; the near ridge is low and dark so the temperature stands on it.
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.56), p(0.1, 0.51), p(0.22, 0.54), p(0.34, 0.47), p(0.46, 0.43), p(0.58, 0.36), p(0.68, 0.42),
                    p(0.78, 0.40), p(0.9, 0.47), p(1, 0.50)], seed: 41),
                              top: Ridges.far.top, bottom: Ridges.far.bottom, rim: 0.6, snowline: 0.45),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.60), p(0.16, 0.56), p(0.32, 0.59), p(0.5, 0.54), p(0.66, 0.58), p(0.82, 0.55), p(1, 0.58)], seed: 43),
                              top: Ridges.mid.top, bottom: Ridges.mid.bottom, rim: 0.35,
                              trees: PLScenery.trees(4...7, spacing: 5, coverage: 0.6, width: w)),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.66), p(0.2, 0.63), p(0.4, 0.66), p(0.6, 0.62), p(0.8, 0.65), p(1, 0.63)], seed: 47, roughness: 0.3),
                              top: Ridges.near.top, bottom: Ridges.near.bottom, rim: 0.25,
                              trees: PLScenery.trees(6...10, spacing: 5, coverage: 0.8, width: w))
            ]
        case .small:
            // The peak sits left of centre under the sun; the right foot stays low for the temperature.
            return [
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.62), p(0.1, 0.56), p(0.2, 0.58), p(0.3, 0.48), p(0.4, 0.52), p(0.5, 0.42), p(0.58, 0.48),
                    p(0.68, 0.55), p(0.8, 0.60), p(0.9, 0.58), p(1, 0.62)], seed: 51),
                              top: Ridges.far.top, bottom: Ridges.far.bottom, rim: 0.6, snowline: 0.51),
                MountainLayer(profile: RidgeProfile(keys: [
                    p(0, 0.80), p(0.18, 0.75), p(0.36, 0.79), p(0.52, 0.72), p(0.68, 0.76), p(0.84, 0.72), p(1, 0.74)], seed: 57),
                              top: Ridges.near.top, bottom: Ridges.near.bottom, rim: 0.25,
                              trees: PLScenery.trees(5...8, spacing: 5, coverage: 0.75, width: w))
            ]
        }
    }
}

/// The temperature written into the plate's foreground (the medium and small windows).
struct PLPlateWeather: View {
    var weather: WeatherSnapshot?
    var compact: Bool

    private var temp: String { weather.map { "\(Int($0.temperature.rounded()))°" } ?? "—" }

    var body: some View {
        VStack(spacing: -1) {
            Text(temp)
                .font(Serif.font(compact ? 20 : 26, weight: .semibold))
                .foregroundStyle(Gilt.style)
                .lineLimit(1)
                .fixedSize()
            if !compact {
                Text(weather?.label ?? "Unavailable")
                    .font(Serif.font(11.5, weight: .medium, italic: true))
                    .foregroundStyle(Stone.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .legible()
    }
}

// MARK: - The caption under the large plate

/// "Mostly clear · 64° · ↑68° ↓52°", centred under the plate between two fading rules.
/// (The next sunrise or sunset is in the date column, below.)
struct PLWeatherCaption: View {
    var weather: WeatherSnapshot?

    private var temp: String { weather.map { "\(Int($0.temperature.rounded()))°" } ?? "—" }

    var body: some View {
        HStack(spacing: 8) {
            PLFadingRule(toLeading: true)
                .frame(minWidth: 10)
            ViewThatFits(in: .horizontal) {
                line(highLow: true)
                line(highLow: false)
            }
            .layoutPriority(1)
            PLFadingRule(toLeading: false)
                .frame(minWidth: 10)
        }
    }

    private var dot: some View {
        Text("·")
            .font(Serif.font(14, weight: .bold))
            .foregroundStyle(Stone.goldMuted)
    }

    private func line(highLow: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            WeatherGlyph(symbol: weather?.symbolName ?? "cloud.fill", size: 12)
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 4.5 }
            Text(weather?.label ?? "Weather unavailable")
                .font(Serif.font(14, weight: .medium, italic: true))
                .foregroundStyle(Stone.parchment)
            dot
            Text(temp)
                .font(Serif.font(19, weight: .semibold))
                .foregroundStyle(Gilt.style)
            if let w = weather, highLow {
                dot
                HighLow(high: w.high, low: w.low, size: 11)
                    .foregroundStyle(Stone.gold)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .raised()
    }
}

// MARK: - Date

/// The large widget's date column, set like an almanac: weekday, a big gilt numeral, month and year,
/// the next sunrise or sunset, and the task count.
struct PLDateColumn: View {
    var date: Date
    var weather: WeatherSnapshot?
    var taskCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // DateBlock's weekday, tracked a little tighter so WEDNESDAY fits the narrow column.
            Text(date, format: .dateTime.weekday(.wide))
                .font(.system(size: 10.5, weight: .bold))
                .tracking(1.9)
                .textCase(.uppercase)
                .foregroundStyle(Stone.copperInk)
                .raised()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            PLGiltDay(date: date, size: 58)
                .padding(.top, -3)
                .padding(.bottom, -7)
            Text(date, format: .dateTime.month(.wide))
                .font(Serif.font(15, italic: true))
                .foregroundStyle(Stone.goldMuted)
                .raised()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(date, format: .dateTime.year())
                .font(Serif.font(13, italic: true))
                .foregroundStyle(Stone.goldMuted)
                .raised()
            if let w = weather, let rise = w.sunrise, let set = w.sunset {
                SunEvent(now: date, sunrise: rise, sunset: set)
                    .raised()
                    .padding(.top, 9)
            }
            Spacer(minLength: 6)
            if taskCount > 0 {
                HStack(spacing: 5) {
                    CountPill(count: taskCount)
                    Text(taskCount == 1 ? "task" : "tasks")
                        .font(Serif.font(12, italic: true))
                        .foregroundStyle(Stone.goldMuted)
                        .raised()
                }
            }
        }
    }
}

/// One line of date for the medium and small widgets: gilt numeral, weekday over month, task count.
struct PLDateLine: View {
    var date: Date
    var taskCount: Int
    var compact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 6 : 8) {
            PLGiltDay(date: date, size: compact ? 28 : 36)
                // Serif digits carry a tall line box; let the numeral set the line's height by its ink.
                .padding(.vertical, compact ? -4 : -3)
            VStack(alignment: .leading, spacing: compact ? 0 : 1) {
                DateBlock.weekday(date, style: compact ? .small : .medium)
                Group {
                    if compact {
                        Text(date, format: .dateTime.month(.wide))
                    } else {
                        Text(date, format: .dateTime.month(.wide).year())
                    }
                }
                .font(Serif.font(compact ? 11.5 : 12.5, italic: true))
                .foregroundStyle(Stone.goldMuted)
                .raised()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            if taskCount > 0 {
                CountPill(count: taskCount)
            }
        }
    }
}

// MARK: - Tasks

/// Tasks as a ruled ledger cut into the board: each row's socket carved in, a hairline under every row.
struct PLLedger: View {
    var tasks: [TaskItem]
    var error: String?
    var maxRows: Int
    var compact: Bool
    var rowHeight: CGFloat

    private var shown: Int { min(tasks.count, max(1, maxRows)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if tasks.isEmpty {
                PLEmptyLedger(error: error, compact: compact)
            } else {
                if !compact { EngravedRule() }
                ForEach(Array(tasks.prefix(shown).enumerated()), id: \.element.id) { i, t in
                    Group {
                        if compact { TaskRow(task: t, compact: true) } else { PLLedgerRow(task: t) }
                    }
                    .frame(height: rowHeight)
                    if !compact || i < shown - 1 { EngravedRule() }
                }
                Spacer(minLength: 0)
                if tasks.count > shown || error != nil {
                    HStack(spacing: 10) {
                        if tasks.count > shown {
                            PLMoreLabel(count: tasks.count - shown)
                        }
                        if let error {
                            // Cached tasks are still shown; say why they may be stale.
                            ErrorLine(message: error, prefix: "Cached", color: Stone.copperInk)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(height: 13)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// No tasks: a carved check (or warning) and one line, centred on the ledger.
struct PLEmptyLedger: View {
    var error: String?
    var compact: Bool

    var body: some View {
        VStack(alignment: compact ? .leading : .center, spacing: compact ? 4 : 7) {
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Image(systemName: error == nil ? "checkmark" : "exclamationmark")
                    .font(.system(size: compact ? 10 : 13, weight: .bold))
                    .foregroundStyle(error == nil ? Stone.sage : Stone.copperInk)
                    .raised()
                    .frame(width: compact ? 22 : 30, height: compact ? 22 : 30)
                    .carved(Circle())
                Text(error == nil ? "Nothing due. Nice." : "Couldn't load tasks")
                    .font(Serif.font(compact ? 13 : 15, weight: .semibold))
                    .foregroundStyle(Stone.gold)
                    .raised()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            if let error {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Stone.copperInk)
                    .raised()
                    .multilineTextAlignment(compact ? .leading : .center)
                    .lineLimit(compact ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)
    }
}

/// The shipped TaskRow (socket, title, due label or late pebble) set half a point smaller with a
/// tighter gutter, so a typical title fits the large widget's ledger beside the date column.
struct PLLedgerRow: View {
    var task: TaskItem

    private var dueLabel: String? {
        guard let d = task.due else { return nil }
        if task.isDueToday { return "today" }
        if task.isOverdue {
            let cal = Calendar.current
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: Date())).day ?? 0
            return "\(days)d late"
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    var body: some View {
        HStack(spacing: 7) {
            TaskSocket(accent: PLTaskPeek.accent(task), size: 14)
            Text(task.text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Stone.parchment)
                .raised(0.8)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let due = dueLabel {
                if task.isOverdue {
                    Text(due)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Stone.parchment)
                        .raised()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Pebble(shape: Capsule()))
                        .fixedSize()
                } else {
                    Text(due)
                        .font(Serif.font(12, weight: .medium, italic: true))
                        .foregroundStyle(Stone.goldMuted)
                        .raised()
                        .fixedSize()
                }
            }
        }
    }
}

/// The small widget's next task: its socket and up to two lines of title (or the error, or the empty line).
struct PLTaskPeek: View {
    var tasks: [TaskItem]
    var error: String?

    var body: some View {
        if let first = tasks.first {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: 6) {
                    TaskSocket(accent: Self.accent(first), size: 12)
                        .padding(.top, 1.5)
                    Text(first.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Stone.parchment)
                        .raised(0.8)
                        .lineLimit(error == nil ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let error {
                    ErrorLine(message: error, prefix: "Cached", color: Stone.copperInk, fontSize: 9.5)
                }
            }
        } else if let error {
            Label {
                Text(error)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9.5, weight: .semibold))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Stone.copperInk)
            .raised()
        } else {
            Label {
                Text("Nothing due. Nice.")
            } icon: {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Stone.sage)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Stone.goldMuted)
            .raised()
        }
    }

    // TaskRow's gem colours: overdue copper, high priority gold, otherwise sage.
    static func accent(_ task: TaskItem) -> Color {
        if task.isOverdue { return Stone.copperLight }
        if task.priority >= .high { return Stone.gold }
        return Stone.sage
    }
}
