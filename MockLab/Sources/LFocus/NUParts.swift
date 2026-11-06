import SwiftUI

// Pieces shared by the Next Up Day and Quote widgets: the hero card, the deck behind it, the slim
// date/weather line, the "Then" list, and the painted grounds with their own ridge layouts.

enum NUStyle { case small, medium, large }

extension NUStyle {
    init(_ family: Family) {
        switch family {
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        }
    }
}

// MARK: - Task facts

enum NUTask {
    /// The gem colour: overdue copper, high priority gold, otherwise sage (as TaskRow does).
    static func accent(_ t: TaskItem, now: Date) -> Color {
        if t.isOverdue(asOf: now) { return Stone.copperLight }
        if t.priority >= .high { return Stone.gold }
        return Stone.sage
    }

    /// "1d late", "today", "tomorrow", otherwise "Nov 4"; nil when undated.
    static func due(_ t: TaskItem, now: Date) -> String? {
        guard let d = t.due else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day ?? 0
        if days < 0 { return "\(-days)d late" }
        if days == 0 { return "today" }
        if days == 1 { return "tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    static func priorityWord(_ p: TaskPriority) -> String? {
        switch p {
        case .highest: return "Highest priority"
        case .high: return "High priority"
        case .medium: return "Medium priority"
        case .low, .lowest, .none: return nil
        }
    }
}

// The due date as a chip: a copper pebble when late, a carved channel with gold italic otherwise.
struct NUDueChip: View {
    var task: TaskItem
    var now: Date
    var size: CGFloat = 10.5

    var body: some View {
        if let label = NUTask.due(task, now: now) {
            if task.isOverdue(asOf: now) {
                Text(label)
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(Stone.parchment)
                    .raised()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Pebble(shape: Capsule()))
                    .fixedSize()
            } else {
                Text(label)
                    .font(Serif.font(size + 1.5, weight: .medium, italic: true))
                    .foregroundStyle(Stone.gold)
                    .raised()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1.5)
                    .carved(Capsule())
                    .fixedSize()
            }
        }
    }
}

// A copper count pebble: "+6" cards waiting behind the hero.
struct NUCountPebble: View {
    var count: Int

    var body: some View {
        Text("+\(count)")
            .font(.system(size: 11, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Stone.parchment)
            .raised()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .frame(minWidth: 24)
            .background(Pebble(shape: Capsule()))
            .fixedSize()
    }
}

// MARK: - The hero card

/// The first task in agenda order, set large on a raised espresso slab with its priority gem and due chip.
/// Also carries the empty state, the error state (no cached tasks) and the "Cached" warning line.
struct NUHeroCard: View {
    var tasks: [TaskItem]
    var error: String?
    var now: Date
    var style: NUStyle

    private var titleSizes: [CGFloat] {
        switch style {
        case .small: return [21, 19, 17.5, 16, 15]
        case .medium: return [25, 23, 21, 19, 17, 15.5]
        case .large: return [30, 28, 26, 24, 22, 20, 18]
        }
    }

    private var titleLines: Int { style == .large ? 3 : (style == .medium ? 4 : 3) }
    private var radius: CGFloat { style == .small ? 15 : 18 }
    private var pad: EdgeInsets {
        switch style {
        case .small: return EdgeInsets(top: 10, leading: 11, bottom: 10, trailing: 11)
        case .medium: return EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 13)
        case .large: return EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 15)
        }
    }

    var body: some View {
        content
            .padding(pad)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .stoneSlab(.panel, radius: radius, depth: style == .small ? 2.5 : 3)
    }

    @ViewBuilder
    private var content: some View {
        if let task = tasks.first {
            VStack(alignment: .leading, spacing: style == .small ? 6 : 8) {
                topRow(task)
                title(task.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style == .small ? .topLeading : .leading)
                    .layoutPriority(1)
                if let error {
                    // Cached tasks are on show; say why they may be stale.
                    ErrorLine(message: error, prefix: style == .small ? nil : "Cached", color: Stone.copperInk,
                              fontSize: style == .small ? 9.5 : 10)
                } else if style != .small, let word = NUTask.priorityWord(task.priority) {
                    priorityFoot(word, accent: NUTask.accent(task, now: now))
                }
            }
        } else {
            emptyState
        }
    }

    private func topRow(_ task: TaskItem) -> some View {
        HStack(alignment: .center, spacing: style == .small ? 5 : 6) {
            TaskSocket(accent: NUTask.accent(task, now: now), size: style == .small ? 13 : 15)
            if style == .small {
                // The small card's top-right corner carries the deck's count pebble; the chip sits by the gem.
                NUDueChip(task: task, now: now, size: 10)
            } else {
                Text("Next up")
                    .font(.system(size: style == .large ? 10.5 : 9.5, weight: .bold))
                    .tracking(style == .large ? 2 : 1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Stone.copperInk)
                    .raised()
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if style != .small {
                NUDueChip(task: task, now: now, size: 10.5)
            }
        }
    }

    private func title(_ text: String) -> some View {
        ViewThatFits(in: .vertical) {
            ForEach(titleSizes, id: \.self) { s in
                titleText(text, s)
            }
            titleText(text, titleSizes.last ?? 15).lineLimit(titleLines)
        }
    }

    private func titleText(_ text: String, _ s: CGFloat) -> some View {
        Text(text)
            .font(Serif.font(s, weight: .medium))
            .foregroundStyle(Stone.parchment)
            .lineSpacing(s > 20 ? -1 : 0)
            .raised()
    }

    private func priorityFoot(_ word: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(accent.opacity(0.85)).frame(width: 14, height: 1.2)
            Text(word)
                .font(Serif.font(12.5, italic: true))
                .foregroundStyle(Stone.goldMuted)
                .raised()
        }
    }

    // Nothing on the agenda (or nothing cached and the fetch failed). Large centres it on the card;
    // the smaller cards drop the icon row when the message needs the room.
    @ViewBuilder
    private var emptyState: some View {
        if style == .large {
            VStack(spacing: 9) {
                emptyIcon(size: 38)
                emptyTitle(26)
                    .multilineTextAlignment(.center)
                emptyMessage(lines: 3)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let t: CGFloat = style == .small ? 18 : 22
            ViewThatFits(in: .vertical) {
                VStack(alignment: .leading, spacing: style == .small ? 6 : 8) {
                    HStack(spacing: 7) {
                        emptyIcon(size: style == .small ? 22 : 26)
                        emptyLabel
                    }
                    emptyTitle(t)
                    emptyMessage(lines: 2)
                }
                VStack(alignment: .leading, spacing: 5) {
                    emptyTitle(t - 2)
                    emptyMessage(lines: 2)
                }
                VStack(alignment: .leading, spacing: 4) {
                    emptyTitle(t - 3)
                    emptyMessage(lines: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func emptyIcon(size: CGFloat) -> some View {
        Image(systemName: error == nil ? "checkmark" : "exclamationmark")
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(error == nil ? Stone.sage : Stone.copperInk)
            .raised()
            .frame(width: size, height: size)
            .carved(Circle())
    }

    private var emptyLabel: some View {
        Text(error == nil ? "All clear" : "Tasks")
            .font(.system(size: 9.5, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(error == nil ? Stone.goldFaint : Stone.copperInk)
            .raised()
    }

    private func emptyTitle(_ s: CGFloat) -> some View {
        Text(error == nil ? "Nothing due.\nNice." : "Couldn't load tasks")
            .font(Serif.font(s, weight: .medium))
            .foregroundStyle(Stone.parchment)
            .lineSpacing(-1)
            .raised()
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func emptyMessage(lines: Int) -> some View {
        if let error {
            Text(error)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Stone.copperInk)
                .lineLimit(lines)
                .fixedSize(horizontal: false, vertical: true)
                .raised()
        }
    }
}

// MARK: - The deck behind

/// The back of a card in the deck: painted face, cut side underneath, one cast shadow, gold inlay.
/// A lighter cousin of `.stoneSlab` (one shadow, no blurred glow) since several stack up per widget.
struct NUCardBack: View {
    var radius: CGFloat
    var shade: Double = 0
    var depth: CGFloat = 2.5

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape
                .fill(LinearGradient(colors: StoneMaterial.panel.edge, startPoint: .top, endPoint: .bottom))
                .offset(y: depth)
                .shadow(color: Stone.shadow.opacity(0.55), radius: 4, x: 0, y: depth + 1.5)
            StoneSurface(material: .panel, weave: false)
                .overlay(StoneMaterial.panel.lighting)
                .overlay(Stone.shadow.opacity(shade))
                .clipShape(shape)
                .overlay(shape.strokeBorder(
                    LinearGradient(stops: [
                        .init(color: Stone.goldBright.opacity(0.36), location: 0),
                        .init(color: Stone.goldBright.opacity(0.06), location: 0.3),
                        .init(color: .black.opacity(0), location: 0.65),
                        .init(color: .black.opacity(0.45), location: 1)
                    ], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.1))
            shape.inset(by: 4)
                .stroke(Stone.gold.opacity(0.2), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Cards stacked behind the hero, drawn as its background so they follow its frame.
struct NUDeck: View {
    enum Fan {
        case up      // each card further back is narrower and higher: a stack seen from the front
        case right   // the stack peeks out to the right
        case tilted       // loose cards, turned a little, peeking above (the quote deck)
        case tiltedRight  // loose cards peeking out to the right
    }

    var cards: Int
    var fan: Fan
    var radius: CGFloat
    var step: CGFloat = 5
    var spread: CGFloat = 1

    var body: some View {
        ZStack {
            ForEach((0..<max(0, cards)).reversed(), id: \.self) { i in
                card(i)
            }
        }
    }

    @ViewBuilder
    private func card(_ i: Int) -> some View {
        let k = CGFloat(i + 1)
        let back = NUCardBack(radius: radius, shade: 0.10 + 0.10 * Double(i))
        switch fan {
        case .up:
            back.padding(.horizontal, 7 * k).offset(y: -step * k)
        case .right:
            back.padding(.vertical, 7 * k).offset(x: step * k)
        case .tilted:
            let angles: [Double] = [2.4, -2.2, 3.6]
            let shifts: [CGSize] = [CGSize(width: 5, height: -7), CGSize(width: -4, height: -12), CGSize(width: 2, height: -16)]
            back.rotationEffect(.degrees(angles[i % 3]))
                .offset(x: shifts[i % 3].width * spread, y: shifts[i % 3].height * spread)
        case .tiltedRight:
            let angles: [Double] = [2.0, -1.8, 3.0]
            let shifts: [CGSize] = [CGSize(width: 9, height: -2), CGSize(width: 17, height: 2), CGSize(width: 24, height: -1)]
            back.padding(.vertical, 4 * k)
                .rotationEffect(.degrees(angles[i % 3]))
                .offset(shifts[i % 3])
        }
    }
}

// MARK: - The slim date and weather line

/// "TUE 3 · ☀ 64°": the date and the weather shrunk to one line over the sky.
struct NUSlimHeader: View {
    var date: Date
    var weather: WeatherSnapshot?
    var style: NUStyle

    private var temp: String { weather.map { "\(Int($0.temperature.rounded()))°" } ?? "—" }
    private var numeral: CGFloat { style == .large ? 23 : 18 }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            dateGroup
            Spacer(minLength: 6)
            if style == .large {
                ViewThatFits(in: .horizontal) {
                    weatherGroup(details: 2)
                    weatherGroup(details: 1)
                    weatherGroup(details: 0)
                }
            } else {
                weatherGroup(details: 0)
            }
        }
        .lineLimit(1)
    }

    private var dateGroup: some View {
        HStack(alignment: .lastTextBaseline, spacing: style == .large ? 7 : 4) {
            Text(date, format: .dateTime.weekday(style == .large ? .wide : .abbreviated))
                .font(.system(size: style == .large ? 11 : 10, weight: .bold))
                .tracking(style == .large ? 2.2 : 1.4)
                .textCase(.uppercase)
                .foregroundStyle(Stone.copperInk)
                .legible()
            Text(date, format: .dateTime.day())
                .font(Serif.font(numeral, weight: .medium))
                .foregroundStyle(Gilt.style)
                .legible(1.2)
            if style == .large {
                Text(date, format: .dateTime.month(.wide))
                    .font(Serif.font(15, italic: true))
                    .foregroundStyle(Stone.goldMuted)
                    .legible()
            }
        }
        .fixedSize()
    }

    /// details: 0 the temperature, 1 adds high and low, 2 adds the next sunrise or sunset.
    private func weatherGroup(details: Int) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: style == .large ? 5 : 4) {
            if let w = weather {
                WeatherGlyph(symbol: w.symbolName, size: style == .large ? 15 : 12)
                    .alignmentGuide(.lastTextBaseline) { d in d[VerticalAlignment.center] + (style == .large ? 6 : 5) }
                    .legible()
            }
            Text(temp)
                .font(Serif.font(numeral, weight: .semibold))
                .foregroundStyle(weather == nil ? AnyShapeStyle(Stone.goldMuted) : AnyShapeStyle(Gilt.style))
                .legible(1.2)
            if details >= 1, let w = weather {
                HighLow(high: w.high, low: w.low, size: 10.5)
                    .foregroundStyle(Stone.gold)
                    .legible()
                    .padding(.leading, 3)
            }
            if details >= 2, let w = weather, let rise = w.sunrise, let set = w.sunset {
                SunEvent(now: date, sunrise: rise, sunset: set)
                    .legible()
                    .padding(.leading, 3)
            }
        }
        .fixedSize()
    }
}

// MARK: - "Then": the rest of the agenda, stepped back

/// The next few titles written small on the dark near ridge beside the hero card.
struct NUThenList: View {
    var tasks: [TaskItem]
    var more: Int
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Then")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Stone.copperInk)
                Spacer(minLength: 2)
                if more > 0 {
                    Text("+\(more) more")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Stone.goldMuted)
                }
            }
            .legible()
            ForEach(tasks) { t in
                HStack(spacing: 4) {
                    TaskSocket(accent: NUTask.accent(t, now: now), size: 10)
                    Text(t.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Stone.parchment)
                        .lineLimit(1)
                        .legible()
                }
            }
        }
    }
}

/// One card further back in the large deck: only its lower strip shows below the card in front.
struct NUDeckStrip: View {
    var task: TaskItem
    var now: Date

    var body: some View {
        HStack(spacing: 8) {
            TaskSocket(accent: NUTask.accent(task, now: now), size: 13)
            Text(task.text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Stone.parchment)
                .raised(0.8)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let label = NUTask.due(task, now: now) {
                if task.isOverdue(asOf: now) {
                    Text(label)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Stone.parchment)
                        .raised()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Pebble(shape: Capsule()))
                        .fixedSize()
                } else {
                    Text(label)
                        .font(Serif.font(11.5, weight: .medium, italic: true))
                        .foregroundStyle(Stone.goldMuted)
                        .raised()
                        .fixedSize()
                }
            }
        }
    }
}
