import SwiftUI

// Type and ink: letters painted on the glass. Over jewel glass they are silver-stain cream with a dark halo;
// on the pale cathedral panels they are grisaille, the umber vitreous paint glass painters fire onto clear glass.

enum SGFont {
    static func caps(_ s: CGFloat) -> Font { .custom("Copperplate-Bold", size: s) }
    static func numeral(_ s: CGFloat) -> Font { .custom("Didot-Bold", size: s) }
    static func italic(_ s: CGFloat) -> Font { .custom("Cochin-Italic", size: s) }
    static func body(_ s: CGFloat) -> Font { .custom("Optima-Regular", size: s) }
    static func due(_ s: CGFloat) -> Font { .custom("Optima-Italic", size: s) }
    static func dueBold(_ s: CGFloat) -> Font { .custom("Optima-BoldItalic", size: s) }
    static func quote(_ s: CGFloat) -> Font { .custom("Didot-Italic", size: s) }
    static func bodyBold(_ s: CGFloat) -> Font { .custom("Optima-Bold", size: s) }
}

enum Ink {
    static let silver = Color(hex: 0xfff5dc)
    static let grisaille = Color(hex: 0x2a1b12)
    static let grisailleSoft = Color(hex: 0x5b4434)
    static let late = Color(hex: 0x9a0f24)
    static let today = Color(hex: 0x8a4b05)
    static let gold = LinearGradient(colors: [Color(hex: 0xfff6c8), Color(hex: 0xffcf4a), Color(hex: 0xe08a10)],
                                     startPoint: .top, endPoint: .bottom)
}

extension View {
    /// Light lettering over dark jewel glass, with a dark halo so it reads across the lead lines.
    func silverStain() -> some View {
        self.foregroundStyle(Ink.silver)
            .shadow(color: .black.opacity(0.9), radius: 0.8, x: 0, y: 0.8)
            .shadow(color: Color(hex: 0x060418).opacity(0.85), radius: 4)
    }

    /// Place a view in a rect of the widget's coordinate space.
    func place(_ r: CGRect, _ a: Alignment = .topLeading) -> some View {
        self.frame(width: r.width, height: r.height, alignment: a)
            .position(x: r.midX, y: r.midY)
    }
}

struct GlassView: View {
    let window: Window
    var body: some View {
        Canvas { ctx, size in GlassRenderer.render(window, &ctx, size) }
    }
}

enum Fmt {
    static func temp(_ t: Double) -> String { "\(Int(t.rounded()))°" }

    static func string(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date)
    }

    /// Monday-first week containing `date`, with the index of `date` in it.
    static func week(_ date: Date) -> (days: [Date], today: Int) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let wd = cal.component(.weekday, from: start)  // 1 = Sunday
        let idx = (wd + 5) % 7
        let monday = cal.date(byAdding: .day, value: -idx, to: start) ?? start
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday) ?? monday }
        return (days, idx)
    }

    static func bead(_ p: TaskPriority) -> Glass {
        switch p {
        case .highest: return .ruby
        case .high: return .amber
        case .medium: return .emerald
        case .none: return .opal
        case .low: return .sapphire
        case .lowest: return .violet
        }
    }
}

/// A due label in grisaille: late in ruby-red paint, today in amber.
struct DueLabel: View {
    let task: TaskItem
    var size: CGFloat = 13
    var body: some View {
        if let label = Mock.dueLabel(task) {
            let late = task.isOverdue(asOf: Mock.now)
            let today = task.isDueToday(asOf: Mock.now)
            Text(label)
                .font(late || today ? SGFont.dueBold(size) : SGFont.due(size))
                .foregroundStyle(late ? Ink.late : (today ? Ink.today : Ink.grisailleSoft))
                .lineLimit(1)
                .fixedSize()
        }
    }
}
