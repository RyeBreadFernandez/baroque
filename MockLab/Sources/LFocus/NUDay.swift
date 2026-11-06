import SwiftUI

// The Next Up Day widget. One task is the hero; everything else steps back.
//   small:  a tiny "TUE 3 · 64°" line over a band of peaks, then the hero card nearly filling the widget,
//           two cards stacked behind it and a "+6" pebble on the stack.
//   medium: the hero card on the left with the deck peeking out to its right; on the right the slim line,
//           the peaks, and a short "Then" list standing on the dark near ridge.
//   large:  the slim line, a landscape band with the live sun on its arc, the hero card resting on the
//           near ridge, and the next three cards of the deck showing their lower edges beneath it.
struct NUDayWidget: View {
    var snapshot: DaySnapshot
    var family: Family

    private var now: Date { snapshot.date }
    private var tasks: [TaskItem] { snapshot.tasks }
    private var rest: [TaskItem] { Array(tasks.dropFirst()) }
    private var style: NUStyle { NUStyle(family) }

    var body: some View {
        Group {
            switch family {
            case .small: small
            case .medium: medium
            case .large: large
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NUDayGround(snapshot: snapshot, style: style))
    }

    private var hero: NUHeroCard {
        NUHeroCard(tasks: tasks, error: snapshot.taskError, now: now, style: style)
    }

    // MARK: Small

    private var small: some View {
        VStack(spacing: 0) {
            NUSlimHeader(date: now, weather: snapshot.weather, style: .small)
                .padding(.horizontal, 16)
                .padding(.top, 14)
            Spacer(minLength: 0)
            hero
                .background(NUDeck(cards: min(2, rest.count), fan: .up, radius: 15, step: 5))
                .overlay(alignment: .topTrailing) {
                    // How many cards wait behind this one, pinned to the stack.
                    if !rest.isEmpty {
                        NUCountPebble(count: rest.count)
                            .offset(x: -9, y: -11)
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
    }

    // MARK: Medium

    private var medium: some View {
        HStack(alignment: .top, spacing: 0) {
            hero
                .background(NUDeck(cards: min(2, rest.count), fan: .right, radius: 18, step: 6))
                .frame(width: 170)
                .padding(.leading, 12)
                .padding(.vertical, 12)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 0) {
                NUSlimHeader(date: now, weather: snapshot.weather, style: .medium)
                Spacer(minLength: 0)
                if rest.isEmpty {
                    weatherDetail
                } else {
                    NUThenList(tasks: Array(rest.prefix(3)), more: max(0, rest.count - 3), now: now)
                }
            }
            .frame(width: 128)
            .padding(.trailing, 16)
            .padding(.top, 15)
            .padding(.bottom, 15)
        }
    }

    /// With nothing else on the agenda the right column has room for the rest of the weather.
    private var weatherDetail: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.weather?.label ?? "Weather unavailable")
                .font(Serif.font(13, weight: .medium, italic: true))
                .foregroundStyle(Stone.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let w = snapshot.weather {
                HighLow(high: w.high, low: w.low, size: 10.5)
                    .foregroundStyle(Stone.gold)
                if let rise = w.sunrise, let set = w.sunset {
                    SunEvent(now: now, sunrise: rise, sunset: set)
                }
            }
        }
        .legible()
    }

    // MARK: Large

    private static let stripHeight: CGFloat = 27
    private static let strips = 3

    private var large: some View {
        let shown = Array(rest.prefix(Self.strips))
        let more = rest.count - shown.count
        return VStack(spacing: 0) {
            NUSlimHeader(date: now, weather: snapshot.weather, style: .large)
                .padding(.horizontal, 16)
                .padding(.top, 15)
            // The landscape band: the sun's arc and the peaks show here.
            Color.clear.frame(height: 58)
            VStack(spacing: 0) {
                hero
                    .frame(maxHeight: shown.isEmpty ? .infinity : 152)
                    .zIndex(10)
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, t in
                    deckStrip(t, depth: i + 1)
                        .zIndex(Double(9 - i))
                }
            }
            .padding(.horizontal, 12)
            if !shown.isEmpty {
                Spacer(minLength: 0)
                if more > 0 {
                    Text("+\(more) more")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Stone.goldMuted)
                        .legible()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 18)
                }
            }
        }
        .padding(.bottom, 16)
    }

    /// A card further back in the deck: only its lower strip shows beneath the card in front of it,
    /// a little narrower and darker each step back.
    private func deckStrip(_ task: TaskItem, depth: Int) -> some View {
        let d = CGFloat(depth)
        let overlap: CGFloat = 40
        return NUDeckStrip(task: task, now: now)
            .padding(.horizontal, 14)
            .frame(height: Self.stripHeight - 3)
            // The cut side of the card in front lies over the top of the strip.
            .padding(.top, 3)
            .background {
                NUCardBack(radius: 16, shade: 0.08 * Double(depth))
                    .padding(.top, -overlap)
            }
            .padding(.horizontal, 6 * d)
    }
}
