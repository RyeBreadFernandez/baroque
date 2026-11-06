import SwiftUI

// Grand Hotel Calm: Grand Hotel's palette, scene and materials (GHStyle, GHScene, GHProps, shared by symlink), with
// far less of everything. One quiet card stock for every slab that carries text, type set straight onto the painted
// sky, and a handful of small parts both variants share.

// MARK: - Textures

enum GCTex {
    /// Grand Hotel's cream card turned down to a faint grain (Textures/grand-hotel-calm/make.py).
    static let vellum = Mock.texture("grand-hotel-calm/vellum")
}

// MARK: - The quiet slab

/// A raised card built like GHSlabModifier (cut side, two-part cast shadow, ChamferRim), but faced with the quiet
/// vellum: the full-strength brushed cream shows only in a feathered band along the rim, so the paint is felt at the
/// edges and the middle stays calm behind the type.
struct GCSlabModifier<S: InsettableShape>: ViewModifier {
    var shape: S
    var depth: CGFloat
    var rim: CGFloat
    var inlay: Bool

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                shape
                    .fill(LinearGradient(colors: GHMaterial.cream.edge, startPoint: .top, endPoint: .bottom))
                    .offset(y: depth)
                    .shadow(color: GH.shadow.opacity(0.5), radius: 7, x: 0, y: depth + 3)
                    .shadow(color: GH.shadow.opacity(0.5), radius: 1, x: 0, y: depth * 0.6)
                GHMaterial.cream.base
                    .overlay { GCTex.vellum.resizable().interpolation(.high).scaledToFill() }
                    .overlay {
                        GHTex.cream.resizable().interpolation(.high).scaledToFill()
                            .mask { shape.strokeBorder(lineWidth: rim).blur(radius: rim * 0.45) }
                    }
                    .overlay(CanvasWeave(opacity: 0.6))
                    .overlay(GHMaterial.cream.lighting)
                    .clipShape(shape)
                    .overlay(ChamferRim(shape: shape))
                if inlay {
                    shape.inset(by: 4)
                        .stroke(GH.gold.opacity(0.6), lineWidth: 0.6)
                }
            }
        }
    }
}

extension View {
    func gcSlab(radius: CGFloat = 12, depth: CGFloat = 3, rim: CGFloat = 6, inlay: Bool = false) -> some View {
        modifier(GCSlabModifier(shape: RoundedRectangle(cornerRadius: radius, style: .continuous), depth: depth, rim: rim, inlay: inlay))
    }
}

// MARK: - Type

/// Fixed type sizes. Each variant draws from these and nothing else.
enum GCSize {
    static let caps: CGFloat = 8.5
}

/// A gilt serif numeral set on the painted sky (the date, the temperature).
struct GCNumeral: View {
    var text: String
    var size: CGFloat

    var body: some View {
        Text(text)
            .font(Serif.font(size, weight: .medium))
            .foregroundStyle(Gilt.style)
            .legible(1.1)
            .lineLimit(1)
            .fixedSize()
    }
}

extension Text {
    /// Spaced Futura capitals in cream, set on the painted sky.
    func gcSkyCaps(_ size: CGFloat = GCSize.caps, tracking: CGFloat? = nil, medium: Bool = false) -> some View {
        ghCaps(size, GH.cream, tracking: tracking ?? size * 0.2, medium: medium)
            .legible()
            .lineLimit(1)
            .fixedSize()
    }

    /// Spaced Futura capitals in ink, pressed into the card.
    func gcCardCaps(_ color: Color, size: CGFloat = GCSize.caps, tracking: CGFloat? = nil, medium: Bool = false) -> some View {
        ghCaps(size, color, tracking: tracking ?? size * 0.16, medium: medium)
            .ghPressed()
            .lineLimit(1)
            .fixedSize()
    }
}

// MARK: - Words

enum GCWords {
    static func temp(_ snap: DaySnapshot) -> String {
        snap.weather.map { GHText.temp($0.temperature) } ?? "—"
    }

    static func condition(_ snap: DaySnapshot) -> String {
        snap.weather?.label.uppercased() ?? "NO REPORT"
    }

    /// "H 68° · L 52°", or why there is no weather.
    static func highLow(_ snap: DaySnapshot) -> String {
        if let w = snap.weather { return "H \(GHText.temp(w.high))  ·  L \(GHText.temp(w.low))" }
        return (snap.weatherError ?? "Unavailable").uppercased()
    }

    /// The next of today's sunrise and sunset ("SUNSET 4:58"); after dark, the morning's.
    static func sun(_ snap: DaySnapshot) -> String? {
        guard let w = snap.weather, let rise = w.sunrise, let set = w.sunset else { return nil }
        let cal = Calendar.current
        func today(_ d: Date) -> Date {
            let c = cal.dateComponents([.hour, .minute], from: d)
            return cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: snap.date) ?? d
        }
        if snap.date < today(rise) || snap.date >= today(set) { return "SUNRISE \(GHDates.clock(rise))" }
        return "SUNSET \(GHDates.clock(set))"
    }

    static func month(_ date: Date, short: Bool = false) -> String {
        GHDates.string(date, short ? "MMM" : "MMMM").uppercased()
    }

    static func more(_ n: Int) -> String { "+ \(n) MORE" }

    /// "GitHub returned 401." from "GitHub returned 401. Check the token in Settings.": for the smallest slabs.
    static func firstSentence(_ message: String) -> String {
        guard let r = message.range(of: ". ") else { return message }
        return String(message[..<r.lowerBound]) + "."
    }
}

// MARK: - Due labels

/// The due date in small capitals: raspberry and bold when late, plum ink for today, soft ink otherwise.
struct GCDue: View {
    var task: TaskItem
    var now: Date
    var size: CGFloat = GCSize.caps
    var todayInk: Color = GH.plum

    var body: some View {
        if let label = Mock.dueLabel(task, now: now)?.uppercased() {
            if task.isOverdue(asOf: now) {
                Text(label).gcCardCaps(GH.raspberry, size: size, tracking: size * 0.12)
            } else if task.isDueToday(asOf: now) {
                Text(label).gcCardCaps(todayInk, size: size, tracking: size * 0.12)
            } else {
                Text(label).gcCardCaps(GH.inkSoft, size: size, tracking: size * 0.1, medium: true)
            }
        }
    }
}

// MARK: - The week

enum GCWeek {
    struct Day {
        var date: Date
        var number: String
        var today: Bool
        var past: Bool
        var due: Bool
    }

    static func days(of date: Date, tasks: [TaskItem]) -> [Day] {
        let cal = Calendar.current
        let due = Set(tasks.compactMap { $0.due.map { cal.startOfDay(for: $0) } })
        return GHDates.week(of: date).map { d in
            let today = cal.isDate(d, inSameDayAs: date)
            return Day(date: d, number: GHDates.string(d, "d"), today: today,
                       past: !today && d < cal.startOfDay(for: date), due: due.contains(cal.startOfDay(for: d)))
        }
    }
}

/// The week as the shipped WeekStrip builds it: one slim channel carved into the scene, the dates in cream, today a
/// raspberry pebble set into the channel, and a tiny dot under any day with something due. Dates only.
struct GCWeekChannel: View {
    var date: Date
    var tasks: [TaskItem]
    var height: CGFloat = 26

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: height / 2, style: .continuous)
        HStack(spacing: 2) {
            ForEach(Array(GCWeek.days(of: date, tasks: tasks).enumerated()), id: \.offset) { _, d in
                ZStack {
                    if d.today {
                        GHPebble(shape: RoundedRectangle(cornerRadius: (height - 5) / 2, style: .continuous), material: .raspberry)
                    }
                    // The numeral's line box carries its descent, so the dot sits clear of the digits.
                    VStack(spacing: 0.5) {
                        Text(d.number)
                            .font(Serif.font(13, weight: d.today ? .bold : .semibold))
                            .monospacedDigit()
                            .foregroundStyle(d.today ? GH.cream : GH.cream.opacity(d.past ? 0.6 : 1))
                            .shadow(color: GH.shadow.opacity(d.today ? 0.6 : 0.85), radius: 0, x: 0, y: d.today ? -0.6 : 1)
                        Circle()
                            .fill(d.today ? GH.cream.opacity(0.9) : Color(hex: 0xF07C9E))
                            .frame(width: 3, height: 3)
                            .opacity(d.due ? 1 : 0)
                    }
                    .padding(.top, 1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(2.5)
        .frame(height: height)
        .background(shape.fill(GH.shadow.opacity(0.32)))
        .carved(shape)
    }
}

// MARK: - Errors

/// A one-line error in the card's raspberry ink, sized for the variants' caps.
struct GCErrorLine: View {
    var message: String
    var prefix: String? = nil
    var short: String? = nil

    var body: some View {
        GHErrorLine(message: message, prefix: prefix, color: GH.raspberry, size: GCSize.caps, short: short)
    }
}

// MARK: - Next quote

/// The next-quote button: a raspberry enamel pebble with a cream arrow, as NextQuoteArrow is a copper one.
struct GCNextButton: View {
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GH.cream)
            .raised()
            .frame(width: size, height: size)
            .background(GHPebble(shape: Circle(), material: .raspberry))
            .accessibilityLabel("Next quote")
    }
}

// MARK: - Quote cards

/// One quote card on the quiet slab: the quote centred in serif, then a foot row with the author centred in spaced
/// capitals and, on medium and large, the next-quote pebble at the right. The foot row is as tall as the pebble, so
/// a long quote shrinks or truncates above it and never runs under the button.
struct GCQuoteCard: View {
    var quote: Quote
    var sizes: [CGFloat]
    var button: Bool
    var padding: EdgeInsets
    var radius: CGFloat = 12

    private var hasAuthor: Bool { !(quote.author ?? "").trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            GCQuoteText(text: quote.text, sizes: sizes)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
            if hasAuthor || button {
                ZStack {
                    if hasAuthor {
                        GCAuthor(author: quote.author)
                            .padding(.horizontal, button ? 36 : 0)
                    }
                    if button {
                        HStack {
                            Spacer(minLength: 0)
                            GCNextButton().padding(.trailing, -(padding.trailing - 8))
                        }
                    }
                }
                .frame(height: button ? 30 : nil)
                .padding(.top, button ? 3 : 5)
                .padding(.bottom, button ? -(padding.bottom - 7) : 0)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gcSlab(radius: radius, depth: 3)
    }
}

// MARK: - Quote text

/// The quote in serif, centred, at the largest size that shows all of it; truncated at the smallest.
struct GCQuoteText: View {
    var text: String
    var sizes: [CGFloat]
    var alignment: TextAlignment = .center

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes, id: \.self) { s in line(s) }
            line(sizes.last ?? 12)
                .truncationMode(.tail)
                .frame(maxHeight: .infinity)
        }
    }

    private func line(_ size: CGFloat) -> some View {
        Text(text)
            .font(Serif.font(size, weight: .medium))
            .foregroundStyle(GH.plum)
            .multilineTextAlignment(alignment)
            .lineSpacing(size > 15 ? 2.5 : 1.5)
            .ghPressed()
    }
}

/// "— GEORGE ORWELL, 1984 —", shortening itself to fit; nothing at all when there is no author.
struct GCAuthor: View {
    var author: String?
    var size: CGFloat = GCSize.caps

    var body: some View {
        if let a = author?.trimmingCharacters(in: .whitespaces), !a.isEmpty {
            ViewThatFits(in: .horizontal) {
                line("—  \(a.uppercased())  —", tracking: size * 0.2)
                line(a.uppercased(), tracking: size * 0.2)
                line(a.uppercased(), tracking: size * 0.06)
                line(a.uppercased(), tracking: size * 0.06).truncationMode(.tail)
            }
        }
    }

    private func line(_ s: String, tracking: CGFloat) -> some View {
        Text(s)
            .ghCaps(size, GH.burgundy, tracking: tracking)
            .ghPressed()
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
    }
}
