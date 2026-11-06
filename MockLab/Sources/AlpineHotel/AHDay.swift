import SwiftUI

// Day widgets: the concierge's desk in front of a painted mural of the hotel. The date is a postage stamp, the
// weather a brass barometer, the week a cabinet of pigeonholes and the tasks a page of the hotel register, each
// task a numbered brass key.

// MARK: - Shared pieces

/// The painted lobby wall below the mural: blush lacquer panels with gold beading.
struct AHWainscot: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            ctx.fill(Path(r), with: .linearGradient(Gradient(colors: [AH.wall, Color(hex: 0xE7A2B6)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            AHTex.lay(ctx, AHTex.gouache, in: r, opacity: 0.9)
            let panels = 4
            let gap: CGFloat = 8
            let pw = (size.width - gap * CGFloat(panels + 1)) / CGFloat(panels)
            for i in 0..<panels {
                let p = CGRect(x: gap + CGFloat(i) * (pw + gap), y: 14, width: pw, height: size.height - 22)
                ctx.stroke(Path(roundedRect: p.offsetBy(dx: 0.6, dy: 0.8), cornerRadius: 3), with: .color(Color.white.opacity(0.5)), lineWidth: 0.8)
                ctx.stroke(Path(roundedRect: p, cornerRadius: 3), with: .color(AH.wallDeep), lineWidth: 0.8)
                ctx.stroke(Path(roundedRect: p.insetBy(dx: 3, dy: 3), cornerRadius: 2), with: .color(AH.gold.opacity(0.7)), lineWidth: 0.5)
            }
            ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 4)), with: .linearGradient(Gradient(colors: [AH.goldLight, AH.goldDeep]),
                                                                                                startPoint: .zero, endPoint: CGPoint(x: 0, y: 4)))
        }
    }
}

/// The date as a postage stamp: weekday, day number and month over an engraved alpine vignette.
struct AHDateStamp: View {
    var date: Date
    var number: CGFloat
    var label: CGFloat
    var weekday: Bool = true
    var month: Bool = true
    var shortNames = false

    var body: some View {
        ZStack {
            AHStamp(fill: AH.blush, vignette: 0.4)
            VStack(spacing: 0) {
                if weekday {
                    Text(AHDates.string(date, shortNames ? "EEE" : "EEEE").uppercased())
                        .ahCaps(label, AH.burgundy, tracking: label * 0.16)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                Text(AHDates.string(date, "d"))
                    .font(AH.futura(number))
                    .foregroundStyle(AH.plum)
                    .shadow(color: Color.white.opacity(0.7), radius: 0, x: 0.6, y: 0.8)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.vertical, -number * 0.13)
                if month {
                    Text(AHDates.string(date, shortNames ? "MMM" : "MMMM").uppercased())
                        .ahCaps(label * 0.95, AH.burgundy, tracking: label * 0.14)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            .padding(.horizontal, max(5, number * 0.16))
        }
    }
}

/// A brass plaque with one or two lines of caps.
struct AHLabelPlaque: View {
    var lines: [String]
    var size: CGFloat
    var color: Color = AH.espresso

    var body: some View {
        ZStack {
            AHPlaque(radius: 3, screws: false)
            VStack(spacing: size * 0.12) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, s in
                    Text(s)
                        .font(i == 0 ? AH.futura(size) : AH.futuraMed(size * 0.95))
                        .tracking(size * 0.14)
                        .foregroundStyle(i == 0 ? color : AH.plum)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 5)
        }
    }
}

enum AHWeatherText {
    static func lines(_ s: DaySnapshot) -> (condition: String, range: String, sun: [String]) {
        guard let w = s.weather else { return ("NO REPORT", "THE GLASS IS RESTING", ["AWAITING", "THE WIRE"]) }
        let range = "H \(Int(w.high.rounded()))°  ·  L \(Int(w.low.rounded()))°"
        var sun: [String] = []
        if let rise = w.sunrise { sun.append("SUNRISE \(AHText.clock(rise))") }
        if let set = w.sunset { sun.append("SUNSET \(AHText.clock(set))") }
        if sun.isEmpty { sun = ["FEELS \(Int(w.apparent.rounded()))°"] }
        return (w.label.uppercased(), range, sun)
    }
}

/// One line of the register: brass key tag, the task, a high-priority star and the due mark.
struct AHLedgerRow: View {
    var task: TaskItem
    var number: Int
    var font: CGFloat
    var height: CGFloat
    var showDue = true

    var body: some View {
        HStack(spacing: font * 0.45) {
            AHKeyTag(number: number, urgent: task.isOverdue(asOf: Mock.now), height: font * 0.98)
            Text(task.text)
                .font(AH.futuraMed(font))
                .foregroundStyle(AH.espresso)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            if task.priority >= .high {
                AHStar(points: task.priority == .highest ? 2 : 1).frame(width: font * (task.priority == .highest ? 1.2 : 0.62), height: font * 0.62)
            }
            Spacer(minLength: font * 0.3)
            if showDue { AHDueMark(task: task, size: font * 0.66) }
        }
        .frame(height: height)
    }
}

/// Little gold-leaf stars for priority (one or two).
struct AHStar: View {
    var points: Int
    var body: some View {
        Canvas { ctx, size in
            let s = size.height
            for i in 0..<points {
                let c = CGPoint(x: s / 2 + CGFloat(i) * s * 0.95, y: s / 2)
                var p = Path()
                for k in 0..<10 {
                    let r = k % 2 == 0 ? s / 2 : s * 0.22
                    let a = Double(k) * .pi / 5 - .pi / 2
                    let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                    if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
                ctx.fill(p, with: .linearGradient(Gradient(colors: [AH.goldLight, AH.gold, AH.goldDeep]), startPoint: CGPoint(x: c.x, y: 0), endPoint: CGPoint(x: c.x, y: s)))
                ctx.stroke(p, with: .color(AH.goldDeep), lineWidth: 0.4)
            }
        }
    }
}

/// The hotel register: a ruled cream page with a raspberry margin, the day's requests as numbered keys.
struct AHLedger: View {
    var snap: DaySnapshot
    var limit: Int
    var font: CGFloat
    var row: CGFloat
    var header: Bool
    var padding: EdgeInsets

    var body: some View {
        let shown = Array(snap.tasks.prefix(limit))
        let extra = snap.tasks.count - shown.count
        VStack(spacing: 0) {
            if header {
                HStack(spacing: 7) {
                    AHRule()
                    Text("THE REGISTER").ahCaps(font * 0.72, AH.burgundy, tracking: font * 0.24).fixedSize()
                    if !snap.tasks.isEmpty {
                        Text("·  \(snap.tasks.count)").ahCaps(font * 0.72, AH.raspberry, tracking: font * 0.1).fixedSize()
                    }
                    AHRule()
                }
                .frame(height: font * 1.35)
                .padding(.bottom, 2)
            }
            if shown.isEmpty {
                AHLedgerEmpty(error: snap.taskError, font: font, bell: header)
                    .frame(maxHeight: .infinity)
            } else {
                ForEach(Array(shown.enumerated()), id: \.offset) { i, t in
                    AHLedgerRow(task: t, number: i + 1, font: font, height: row)
                        .overlay(alignment: .bottom) { AHLedgerRule() }
                }
                // the rest of the page stays ruled, like an open register
                ForEach(0..<max(0, limit - shown.count), id: \.self) { _ in
                    Color.clear.frame(height: row).overlay(alignment: .bottom) { AHLedgerRule() }
                }
                Spacer(minLength: 0)
                if let err = snap.taskError {
                    AHErrorLine(text: err, size: font * 0.66, cached: true)
                        .frame(height: font * 1.1)
                } else if extra > 0 {
                    Text(AHText.more(extra))
                        .ahCaps(font * 0.64, AH.raspberry, tracking: font * 0.2)
                        .frame(maxWidth: .infinity)
                        .frame(height: font * 1.05)
                }
            }
        }
        .padding(padding)
        .background {
            ZStack(alignment: .topLeading) {
                AHCard(fill: AH.card, rule: AH.raspberry, corner: 5, inset: 3.5)
                // the register's double margin line, through the key column
                HStack(spacing: 1.6) {
                    Rectangle().fill(AH.raspberry.opacity(0.55)).frame(width: 0.6)
                    Rectangle().fill(AH.raspberry.opacity(0.55)).frame(width: 0.6)
                }
                .padding(.vertical, 7)
                .offset(x: padding.leading + font * 1.98)
            }
        }
    }
}

struct AHLedgerRule: View {
    var body: some View {
        Rectangle().fill(Color(hex: 0x9DBCDD, opacity: 0.7)).frame(height: 0.6).padding(.leading, -2)
    }
}

struct AHRule: View {
    var body: some View {
        VStack(spacing: 1.4) {
            Rectangle().fill(AH.raspberry.opacity(0.8)).frame(height: 0.8)
            Rectangle().fill(AH.gold).frame(height: 0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AHLedgerEmpty: View {
    var error: String?
    var font: CGFloat
    var bell = false

    var body: some View {
        VStack(spacing: font * 0.3) {
            if let error {
                Text("THE REGISTER COULD NOT BE FETCHED").ahCaps(font * 0.66, AH.raspberry, tracking: font * 0.12)
                    .multilineTextAlignment(.center)
                Text(error)
                    .font(AH.futuraMed(font * 0.8))
                    .foregroundStyle(AH.espresso)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            } else {
                if bell { AHBellPush(size: font * 3.2).padding(.bottom, font * 0.3) }
                Text("NO REQUESTS AT THE DESK").ahCaps(font * 0.7, AH.burgundy, tracking: font * 0.16)
                    .multilineTextAlignment(.center)
                Text("The day is entirely your own.")
                    .font(AH.futuraMed(font * 0.85))
                    .foregroundStyle(AH.plum)
                    .multilineTextAlignment(.center)
            }
        }
        .lineLimit(2)
        .frame(maxWidth: .infinity)
    }
}

/// A readable error line, set like a hotel notice.
struct AHErrorLine: View {
    var text: String
    var size: CGFloat
    var cached: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(cached ? "SAVED COPY" : "NOTICE").ahCaps(size, AH.cream, tracking: size * 0.1)
                .padding(.horizontal, 3).padding(.vertical, 0.5)
                .background(RoundedRectangle(cornerRadius: 1.5).fill(AH.raspberry))
                .fixedSize()
            Text(text)
                .font(AH.futuraMed(size * 1.1))
                .foregroundStyle(AH.raspberryDeep)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Large

struct AHDayLarge: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.large)
        let sky = AHSky(snap.weather)
        let wt = AHWeatherText.lines(snap)
        ZStack(alignment: .topLeading) {
            AHWainscot().ahPlace(0, 176, s.width, s.height - 176)
            AHBackdrop(spec: AHSceneSpec(sky: sky, apex: 0.18, shoulders: 0.38, far: 0.4, base: 0.76, hills: 0.63, ledge: 0.68, meadow: 0.9,
                                         hotel: 112, seed: 11))
                .ahPlace(0, 0, s.width, 190)
            AHValance(depth: 20, scallops: 9).ahPlace(0, 0, s.width, 26)

            // left: the date stamp with its postmark, and the hours of daylight on a plaque
            AHDateStamp(date: snap.date, number: 36, label: 8).ahPlace(18, 32, 74, 82)
            AHPostmark(top: "HOTEL TERRA", bottom: "POSTE ALPINE", center: AHDates.string(snap.date, "yyyy"))
                .rotationEffect(.degrees(-14))
                .ahPlace(84, 58, 32, 32)
            AHLabelPlaque(lines: wt.sun.count > 1 ? wt.sun : [wt.sun.first ?? "", " "], size: 7.2).ahPlace(14, 122, 82, 27)

            // right: the barometer and its reading
            AHBarometer(weather: snap.weather, diameter: 80).ahPlace(255, 30, 80, 80)
            AHLabelPlaque(lines: [wt.condition, wt.range], size: 7.2).ahPlace(252, 122, 82, 27)

            AHPigeonholes(date: snap.date, tasks: snap.tasks).ahPlace(14, 180, 320, 40)
            AHLedger(snap: snap, limit: 5, font: 12, row: 18.5, header: true, padding: EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 12))
                .ahPlace(12, 226, 324, 128)
        }
        .frame(width: s.width, height: s.height)
        .modifier(AHFinish())
    }
}

// MARK: - Medium

struct AHDayMedium: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.medium)
        let sky = AHSky(snap.weather)
        let wt = AHWeatherText.lines(snap)
        ZStack(alignment: .topLeading) {
            AHWainscot().ahPlace(0, 90, s.width, s.height - 90)
            AHBackdrop(spec: AHSceneSpec(sky: sky, apex: 0.16, shoulders: 0.36, far: 0.4, base: 0.78, hills: 0.62, ledge: 0.74, meadow: 0.94,
                                         hotel: 78, sign: false, framingPines: 0.8, pineScale: 0.8, sunSize: 0.12, seed: 21))
                .ahPlace(0, 0, s.width, 100)
            AHValance(depth: 14, scallops: 11).ahPlace(0, 0, s.width, 20)

            AHDateStamp(date: snap.date, number: 27, label: 7.5, weekday: false, shortNames: true).ahPlace(20, 15, 50, 52)
            AHBarometer(weather: snap.weather, diameter: 54).ahPlace(277, 14, 54, 54)
            AHLabelPlaque(lines: [AHDates.string(snap.date, "EEEE").uppercased()], size: 7).ahPlace(14, 70, 62, 13)
            AHLabelPlaque(lines: [wt.condition], size: 7).ahPlace(268, 70, 66, 13)

            AHLedger(snap: snap, limit: 3, font: 11, row: 14.5, header: false, padding: EdgeInsets(top: 6, leading: 9, bottom: 7, trailing: 11))
                .ahPlace(10, 87, 328, 69)
        }
        .frame(width: s.width, height: s.height)
        .modifier(AHFinish())
    }
}

// MARK: - Small

struct AHDaySmall: View {
    var snap: DaySnapshot

    var body: some View {
        let s = Mock.size(.small)
        let sky = AHSky(snap.weather)
        ZStack(alignment: .topLeading) {
            AHBackdrop(spec: AHSceneSpec(sky: sky, apex: 0.15, shoulders: 0.32, far: 0.36, base: 0.6, hills: 0.47, ledge: 0.53, meadow: 0.72,
                                         hotel: 56, sign: false, framingPines: 0.7, pineScale: 0.75, sunSize: 0.075, seed: 31))
                .ahPlace(0, 0, s.width, s.height)
            AHValance(depth: 12, scallops: 6).ahPlace(0, 0, s.width, 18)

            AHDateStamp(date: snap.date, number: 20, label: 7, shortNames: true).ahPlace(14, 18, 44, 52)
            AHBarometer(weather: snap.weather, diameter: 46).ahPlace(104, 20, 46, 46)

            AHSmallTicket(snap: snap).ahPlace(10, 98, 144, 54)
        }
        .frame(width: s.width, height: s.height)
        .modifier(AHFinish())
    }
}

/// The small widget's ticket: the first request on a key tag, and how many wait behind it.
struct AHSmallTicket: View {
    var snap: DaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let first = snap.tasks.first {
                HStack(alignment: .top, spacing: 5) {
                    AHKeyTag(number: 1, urgent: first.isOverdue(asOf: Mock.now), height: 10.5)
                        .padding(.top, 1.5)
                    Text(first.text)
                        .font(AH.futuraMed(11))
                        .foregroundStyle(AH.espresso)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    if snap.taskError != nil {
                        Text("NOT REFRESHED").ahCaps(7, AH.cream, tracking: 0.8)
                            .padding(.horizontal, 3).padding(.vertical, 0.5)
                            .background(RoundedRectangle(cornerRadius: 1.5).fill(AH.raspberry))
                            .fixedSize()
                    } else if snap.tasks.count > 1 {
                        Text(AHText.more(snap.tasks.count - 1)).ahCaps(7.5, AH.raspberry, tracking: 1.3)
                    }
                    Spacer(minLength: 2)
                    if let first = snap.tasks.first { AHDueMark(task: first, size: 7.2) }
                }
            } else {
                AHLedgerEmpty(error: snap.taskError, font: 10).frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 6)
        .background(AHCard(fill: AH.card, rule: AH.raspberry, corner: 5, inset: 3))
    }
}
