import SwiftUI
import WidgetKit   // for RococoStyle's widgetAccentedRenderingMode (the app gets it through its other files)

// Small widget ideas in the shipped rococo look (2026-11-05: "theorize and create more small widget ideas"). Each is
// laid out at the iPhone 17 small size, 164 pt, on the app's own stone, gold, moon and type (Shared/RococoStyle.swift,
// linked here) and follows its rules: no weekday names, no gold frames, words on the dark side of a picture, Savoye
// only for a few words. The data each would read is in `SmallIdea.source`; the demo moment is the evening of
// 2026-11-05 in Los Angeles, with the afternoon used where an idea is about the coming sunset.

let small = CGSize(width: 164, height: 164)

func demo(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

struct SmallIdea: Identifiable {
    var slug: String
    var name: String
    var source: String
    var view: AnyView
    var id: String { slug }

    static let all: [SmallIdea] = [
        SmallIdea(slug: "moon", name: "Moon", source: "Tonight's phase, worked out on the phone", view: AnyView(MoonIdea(date: demo(11, 5, 18, 40)))),
        SmallIdea(slug: "golden-hour", name: "Golden Hour", source: "Today's sunset (already fetched)", view: AnyView(GoldenHourIdea())),
        SmallIdea(slug: "date", name: "Date", source: "The date, with tonight's moon", view: AnyView(DateIdea(date: demo(11, 5, 18, 40)))),
        SmallIdea(slug: "next", name: "Next", source: "Your most urgent task in the vault", view: AnyView(NextIdea())),
        SmallIdea(slug: "done", name: "Done Today", source: "Ticked tasks in today's daily note", view: AnyView(DoneIdea())),
        SmallIdea(slug: "countdown", name: "Countdown", source: "A dated #trip task in your vault", view: AnyView(CountdownIdea())),
        SmallIdea(slug: "light", name: "Light", source: "Sunrise and sunset, today and yesterday", view: AnyView(LightIdea())),
        SmallIdea(slug: "quarter", name: "Quarter", source: "The quarter's dates, set once in the app", view: AnyView(QuarterIdea())),
        SmallIdea(slug: "motto", name: "Motto", source: "One a day from a list (or a vault note)", view: AnyView(MottoIdea())),
        SmallIdea(slug: "photograph", name: "Photograph", source: "One of your repainted photos a day", view: AnyView(PhotographIdea())),
    ]
}

// MARK: - Pieces

/// The stone widgets' title, where Battery's sits.
struct StoneTitle: View {
    var text: String
    var body: some View {
        Text(text).font(RococoType.serif(15.5)).foregroundStyle(RococoInk.ink)
            .rococoBaseline(x: 16, y: 27, in: small)
    }
}

/// Small capitals across the widget (or from the left), with their first baseline at y.
struct Caps: View {
    var text: String
    var y: CGFloat
    var color = RococoInk.inkSoft
    var leading = false

    var body: some View {
        Text(text).font(RococoType.sansMedium(6.5)).tracking(1.6).foregroundStyle(color)
            .frame(width: leading ? nil : small.width, alignment: leading ? .leading : .center)
            .rococoBaseline(x: leading ? 16 : 0, y: y, in: small)
    }
}

/// A line of Didot across the widget, its baseline at y.
struct Centred: View {
    var text: Text
    var y: CGFloat
    var body: some View {
        text.foregroundStyle(RococoInk.ink).fixedSize().frame(width: small.width).rococoBaseline(x: 0, y: y, in: small)
    }
}

/// Gold set into the stone like the Battery widget's figure: the same gradient, lit edge and relief.
extension View {
    func gilt() -> some View {
        foregroundStyle(RococoMaterial.gold.gradient
            .shadow(.inner(color: .white.opacity(0.6), radius: 0.5, x: -0.6, y: -0.8))
            .shadow(.inner(color: .black.opacity(0.35), radius: 1, x: 0.8, y: 1)))
            .rococoRelief(1)
    }
}

struct GoldDot: View {
    var size: CGFloat = 8
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xFCEBB4), Color(hex: 0xE6B85E), Color(hex: 0xB07E31)],
                                 center: UnitPoint(x: 0.36, y: 0.3), startRadius: 0, endRadius: size * 0.62))
            .frame(width: size, height: size)
            .rococoRelief(0.7)
    }
}

enum MoonWords {
    static func name(_ p: MoonPhase) -> String {
        switch p.fraction {
        case ..<0.03, 0.97...: return "New moon"
        case ..<0.22: return "Waxing crescent"
        case ..<0.28: return "First quarter"
        case ..<0.47: return "Waxing gibbous"
        case ..<0.53: return "Full moon"
        case ..<0.72: return "Waning gibbous"
        case ..<0.78: return "Last quarter"
        default: return "Waning crescent"
        }
    }

    /// "FULL IN 4 NIGHTS" while it waxes, "NEW IN 9 NIGHTS" while it wanes.
    static func next(_ p: MoonPhase) -> String {
        let month = 29.530588853
        let nights = Int(((p.waxing ? 0.5 - p.fraction : 1 - p.fraction) * month).rounded())
        if nights == 0 { return p.waxing ? "FULL TONIGHT" : "NEW TONIGHT" }
        return "\(p.waxing ? "FULL" : "NEW") IN \(nights) NIGHT\(nights == 1 ? "" : "S")"
    }
}

// MARK: - Stone ideas

/// Tonight's moon raised in cream, its phase in italic and the nights to the next full or new moon.
struct MoonIdea: View {
    var date: Date
    var body: some View {
        let phase = MoonPhase(date: date)
        ZStack(alignment: .topLeading) {
            RococoSlab()
            RococoMoon(phase: phase, radius: 31).position(x: small.width / 2, y: 66)
            Centred(text: Text(MoonWords.name(phase)).font(RococoType.italic(16)), y: 126)
            Caps(text: MoonWords.next(phase), y: 146)
        }
        .frame(width: small.width, height: small.height)
    }
}

/// The gold sun half set into a carved horizon, the hour the light turns gold, and how long until then.
struct GoldenHourIdea: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RococoSlab()
            StoneTitle(text: "Golden hour")
            RococoCarve(shape: RococoLine(), width: 1.4).frame(width: 128, height: 2).position(x: 82, y: 84)
            RococoSun(radius: 10)
                .position(x: 82, y: 84)
                .mask(Rectangle().frame(width: small.width, height: 83).position(x: 82, y: 41.5))
            Centred(text: Text("4:23").font(RococoType.serif(34)), y: 124)
            Caps(text: "IN 1 H 13 M  ·  SUNSET 4:56", y: 146)
        }
        .frame(width: small.width, height: small.height)
    }
}

/// The day of the month as a great gilt numeral, the month under it and tonight's moon beside it. No weekday.
struct DateIdea: View {
    var date: Date
    var body: some View {
        ZStack(alignment: .topLeading) {
            RococoSlab()
            Text("\(Calendar.current.component(.day, from: date))")
                .font(RococoType.serif(96))
                .gilt()
                .fixedSize()
                .frame(width: small.width)
                .rococoBaseline(x: 0, y: 118, in: small)
            RococoMoon(phase: MoonPhase(date: date), radius: 7).position(x: 140, y: 24)
            Caps(text: RococoWords.month(date).uppercased(), y: 146, color: RococoInk.ink)
        }
        .frame(width: small.width, height: small.height)
    }
}

/// The one task that matters most now, large enough to read at a glance.
struct NextIdea: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RococoSlab()
            StoneTitle(text: "Next")
            GoldDot(size: 7).position(x: 148, y: 22)
            Text("Finish the M142 problem set")
                .font(RococoType.italic(18))
                .lineSpacing(-2)
                .foregroundStyle(RococoInk.ink)
                .frame(width: 136, alignment: .leading)
                .rococoBaseline(x: 16, y: 66, in: small)
            Caps(text: "DUE TOMORROW  ·  2 MORE", y: 146, color: RococoInk.terracotta, leading: true)
        }
        .frame(width: small.width, height: small.height)
    }
}

/// Today's ticked tasks as gold tally marks: four strokes and a fifth across them.
struct DoneIdea: View {
    var count = 4
    var total = 6

    var body: some View {
        ZStack(alignment: .topLeading) {
            RococoSlab()
            StoneTitle(text: "Done today")
            ZStack {
                RococoCarve(shape: RoundedRectangle(cornerRadius: 1), width: 0.6).frame(width: 64, height: 1).offset(y: 26)
                HStack(spacing: 9) {
                    ForEach(0..<min(count, 4), id: \.self) { _ in
                        Capsule().fill(RococoMaterial.gold.gradient).frame(width: 3.2, height: 40).rococoRelief(0.8)
                    }
                    ForEach(min(count, 4)..<4, id: \.self) { _ in
                        RococoCarve(shape: Capsule(), width: 0.8).frame(width: 3.2, height: 40)
                    }
                }
                if count >= 5 {
                    Capsule().fill(RococoMaterial.gold.gradient).frame(width: 3.2, height: 64).rotationEffect(.degrees(62)).rococoRelief(0.8)
                }
            }
            .position(x: 82, y: 76)
            Centred(text: Text("\(count) of \(total)").font(RococoType.italic(17)), y: 128)
            Caps(text: "FROM TODAY'S NOTE", y: 146)
        }
        .frame(width: small.width, height: small.height)
    }
}

/// How much daylight was gained or lost since yesterday, with the sun low on a short carved arc.
struct LightIdea: View {
    var body: some View {
        let arc = SkyArc(centerX: 0.5, horizon: 0.44, radiusX: 0.3, radiusY: 0.2)
        ZStack(alignment: .topLeading) {
            RococoSlab()
            RococoCarve(shape: RococoArcPath(arc: arc, from: 0, to: 1), width: 1.4)
            RococoArcPath(arc: arc, from: 0, to: 0.86)
                .stroke(RococoMaterial.gold.gradient, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            GoldDot(size: 9).position(arc.point(0.86, in: small))
            RococoCarve(shape: RococoLine(), width: 1).frame(width: 112, height: 2).position(x: 82, y: 72)
            Centred(text: Text("−1 m 37 s").font(RococoType.serif(27)), y: 112)
            Centred(text: Text("less light than yesterday").font(RococoType.italic(12)), y: 130)
            Caps(text: "10 H 40 M TODAY", y: 147)
        }
        .frame(width: small.width, height: small.height)
    }
}

/// Where the quarter stands: the week as a great numeral and ten notches, gold up to now.
struct QuarterIdea: View {
    var week = 7
    var body: some View {
        ZStack(alignment: .topLeading) {
            RococoSlab()
            Caps(text: "FALL QUARTER", y: 26, color: RococoInk.ink, leading: true)
            (Text("Week ").font(RococoType.serif(19)) + Text("\(week)").font(RococoType.serif(56))
                + Text("  of 10").font(RococoType.italic(15)))
                .foregroundStyle(RococoInk.ink)
                .fixedSize()
                .rococoBaseline(x: 16, y: 96, in: small)
            HStack(spacing: 6.4) {
                ForEach(1...10, id: \.self) { n in
                    if n <= week {
                        Capsule().fill(RococoMaterial.gold.gradient).frame(width: 7, height: 7).rococoRelief(0.6)
                    } else {
                        RococoCarve(shape: Circle(), width: 0.8).frame(width: 7, height: 7)
                    }
                }
            }
            .position(x: 82, y: 118)
            Caps(text: "FINALS IN 30 DAYS", y: 146, leading: true)
        }
        .frame(width: small.width, height: small.height)
    }
}

/// A Latin motto in script, its meaning in italic under a carved rule.
struct MottoIdea: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RococoSlab()
            Centred(text: Text("Festina lente").font(RococoType.script(36)), y: 80)
            RococoCarve(shape: RococoLine(), width: 1).frame(width: 40, height: 2).position(x: 82, y: 100)
            Centred(text: Text("make haste slowly").font(RococoType.italic(14)), y: 124)
            Caps(text: "AUGUSTUS", y: 146)
        }
        .frame(width: small.width, height: small.height)
    }
}

// MARK: - Picture ideas

/// Days to the next trip as a great cream numeral on the dark foot of one of the user's repainted photographs.
struct CountdownIdea: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RococoPicture(name: "RococoSquare")
            RococoCorners()
            LinearGradient(colors: [.clear, RococoInk.umber.opacity(0.7)], startPoint: UnitPoint(x: 0.5, y: 0.35), endPoint: .bottom)
            Text("12").font(RococoType.serif(62)).foregroundStyle(RococoInk.cream)
                .shadow(color: .black.opacity(0.4), radius: 3)
                .fixedSize()
                .rococoBaseline(x: 14, y: 116, in: small)
            Text("days to Big Pine Lakes").font(RococoType.italic(14)).foregroundStyle(RococoInk.cream)
                .shadow(color: .black.opacity(0.5), radius: 2)
                .fixedSize()
                .rococoBaseline(x: 15, y: 140, in: small)
        }
        .frame(width: small.width, height: small.height)
        .clipped()
    }
}

/// Just one of the user's repainted photographs, a different one each day, like the Still Life widget.
struct PhotographIdea: View {
    var body: some View {
        RococoPicture(name: "RococoHero")
            .frame(width: small.width, height: small.height)
            .clipped()
    }
}
