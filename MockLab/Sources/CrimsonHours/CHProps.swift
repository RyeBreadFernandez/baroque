import SwiftUI

// Things in the room: the tear-off day calendar on its nail, the folded letter used as a task ledger,
// the intertitle type for quotes, and the enamel next-quote button.

// MARK: - Tear-off calendar

struct CHTearCalendar: View {
    enum Style { case small, medium, large }
    var date: Date
    var style: Style
    var size: CGSize
    var seed: UInt64 = 5

    private let bleed: CGFloat = 14
    private var bindingTop: CGFloat { style == .small ? 6 : 8 }
    private var bindingH: CGFloat { style == .small ? 8 : 10 }
    private var stackDepth: CGFloat { style == .small ? 4.5 : 6.5 }
    private var page: CGRect {
        let top = bindingTop + bindingH + 1.5
        return CGRect(x: 0, y: top, width: size.width - stackDepth * 0.35, height: size.height - top - stackDepth)
    }

    var body: some View {
        Canvas { ctx, _ in
            var c = ctx
            c.translateBy(x: bleed, y: bleed)
            drawPad(c)
        }
        .padding(-bleed)
        .overlay(alignment: .topLeading) {
            pageText
                .frame(width: page.width, height: page.height)
                .offset(x: page.minX, y: page.minY)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Paper and hardware

    private func drawPad(_ ctx: GraphicsContext) {
        let p = page
        let pad = CGRect(x: -1, y: bindingTop, width: size.width + 1, height: size.height - bindingTop)
        // Cast shadow from the lamp, upper left.
        var sh = ctx
        sh.addFilter(.blur(radius: 3.5))
        sh.fill(Path(roundedRect: pad.offsetBy(dx: 3, dy: 4), cornerRadius: 2), with: .color(.black.opacity(0.7)))
        var contact = ctx
        contact.addFilter(.blur(radius: 0.8))
        contact.fill(Path(pad.offsetBy(dx: 0.6, dy: 1)), with: .color(.black.opacity(0.5)))

        // The stack of days to come, each edge a hair lower.
        let n = style == .small ? 4 : 6
        for i in stride(from: n, through: 1, by: -1) {
            let f = CGFloat(i)
            let r = CGRect(x: p.minX + f * 0.25, y: p.minY + f * (stackDepth / CGFloat(n)), width: p.width, height: p.height)
            let shade = 0.80 - Double(f) * 0.035
            ctx.fill(Path(r), with: .color(CHColor.mix(0x8A7552, 0xEFE2C2, shade)))
            ctx.stroke(Path(CGRect(x: r.minX, y: r.maxY - 0.3, width: r.width, height: 0)), with: .color(Color(hex: 0x3A2A1A, opacity: 0.45)), lineWidth: 0.5)
        }

        // Today's page.
        var pg = ctx
        pg.clip(to: Path(p))
        pg.draw(ctx.resolve(CH.texture("paper-cal")), in: p.insetBy(dx: -2, dy: -2))
        // Lamp light across the page (warm, from the upper left), and the lifted lower-right corner in shade.
        var warm = pg
        warm.blendMode = .multiply
        warm.fill(Path(p), with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF6E4), Color(hex: 0xF8E2BC), Color(hex: 0xD2AE80)]),
                                                 startPoint: CGPoint(x: p.minX, y: p.minY), endPoint: CGPoint(x: p.maxX, y: p.maxY)))
        let cs = p.width * 0.22
        var curl = Path()
        curl.move(to: CGPoint(x: p.maxX, y: p.maxY - cs))
        curl.addQuadCurve(to: CGPoint(x: p.maxX - cs, y: p.maxY), control: CGPoint(x: p.maxX - cs * 0.25, y: p.maxY - cs * 0.25))
        curl.addLine(to: CGPoint(x: p.maxX, y: p.maxY))
        curl.closeSubpath()
        var cpg = pg
        cpg.addFilter(.blur(radius: 2))
        cpg.fill(curl, with: .color(Color(hex: 0x3A2410, opacity: 0.35)))
        // Perforation just under the binding, where yesterday was torn away.
        var perf = Path()
        var x = p.minX + 2
        while x < p.maxX - 1 {
            perf.addEllipse(in: CGRect(x: x, y: p.minY + 2.2, width: 0.9, height: 0.9))
            x += 2.6
        }
        pg.fill(perf, with: .color(Color(hex: 0x6A5236, opacity: 0.55)))

        // Torn stubs of the pages already gone, ragged under the binding.
        var rng = CHRandom(seed)
        var stub = Path()
        let sy = bindingTop + bindingH
        stub.move(to: CGPoint(x: -0.5, y: sy - 1))
        stub.addLine(to: CGPoint(x: size.width + 0.5, y: sy - 1))
        var tx = size.width + 0.5
        while tx > -0.5 {
            stub.addLine(to: CGPoint(x: tx, y: sy + rng.range(0.6...3.2)))
            tx -= rng.range(1.2...3.4)
        }
        stub.addLine(to: CGPoint(x: -0.5, y: sy + 1.5))
        stub.closeSubpath()
        var stubShadow = ctx
        stubShadow.addFilter(.blur(radius: 0.7))
        stubShadow.fill(stub.offsetBy(dx: 0.3, dy: 0.8), with: .color(.black.opacity(0.35)))
        ctx.fill(stub, with: .color(Color(hex: 0xE6D6B2)))

        // Binding board: crimson card printed with a gilt rule, two staples.
        let b = CGRect(x: -1.5, y: bindingTop, width: size.width + 2.5, height: bindingH)
        var bs = ctx
        bs.addFilter(.blur(radius: 1))
        bs.fill(Path(b.offsetBy(dx: 0.5, dy: 1.2)), with: .color(.black.opacity(0.55)))
        ctx.fill(Path(roundedRect: b, cornerRadius: 1), with: .linearGradient(Gradient(colors: [Color(hex: 0xB0302A), Color(hex: 0x7A1418), Color(hex: 0x4A0A0E)]),
                                                                    startPoint: CGPoint(x: b.minX, y: b.minY), endPoint: CGPoint(x: b.minX, y: b.maxY)))
        ctx.stroke(Path(CGRect(x: b.minX + 2, y: b.minY + 2, width: b.width - 4, height: b.height - 4)), with: .color(Color(hex: 0xD9A85A, opacity: 0.55)), lineWidth: 0.45)
        ctx.fill(Path(CGRect(x: b.minX, y: b.minY, width: b.width, height: 0.6)), with: .color(CH.tungsten.opacity(0.4)))
        for sx in [0.2, 0.8] {
            let s = CGRect(x: b.minX + b.width * sx - 2.5, y: b.midY - 0.5, width: 5, height: 1.1)
            ctx.fill(Path(roundedRect: s, cornerRadius: 0.5), with: .color(Color(hex: 0xC8C4BC)))
            ctx.fill(Path(CGRect(x: s.minX, y: s.maxY, width: s.width, height: 0.4)), with: .color(.black.opacity(0.5)))
        }

        // Brass nail through a hole in the binding.
        let nc = CGPoint(x: size.width / 2, y: bindingTop + bindingH * 0.45)
        let nr: CGFloat = style == .small ? 2.4 : 3.0
        var ns = ctx
        ns.addFilter(.blur(radius: 1))
        ns.fill(Path(ellipseIn: CGRect(x: nc.x - nr + 1.6, y: nc.y - nr + 2.0, width: nr * 2, height: nr * 2)), with: .color(.black.opacity(0.7)))
        ctx.fill(Path(ellipseIn: CGRect(x: nc.x - nr, y: nc.y - nr, width: nr * 2, height: nr * 2)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE6A8), Color(hex: 0xC48A3A), Color(hex: 0x5A3812)]),
                                       center: CGPoint(x: nc.x - nr * 0.35, y: nc.y - nr * 0.35), startRadius: 0, endRadius: nr * 1.3))
    }

    // MARK: Print

    private var numeralSize: CGFloat {
        switch style {
        case .small: return page.height * 0.50
        case .medium: return page.height * 0.46
        case .large: return page.height * 0.44
        }
    }

    @ViewBuilder private var pageText: some View {
        let ms: CGFloat = style == .small ? 7.5 : (style == .medium ? 8.5 : 9.5)
        let ws: CGFloat = style == .small ? 8 : (style == .medium ? 9 : 10)
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(CHDates.string(date, style == .small ? "MMM" : "MMMM").uppercased())
                    .font(CH.labelBold(ms))
                    .foregroundStyle(CH.redPrint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Text(CHDates.string(date, "yyyy"))
                    .font(CH.label(ms * 0.85))
                    .foregroundStyle(CH.inkSoft)
                    .fixedSize()
            }
            .padding(.top, style == .small ? 6 : 8)
            CHDoubleRule(color: CH.redPrint)
                .frame(height: 2.6)
                .padding(.top, 2)
            numeral
                .frame(maxHeight: .infinity)
            HStack(spacing: 4) {
                CHDiamond().fill(CH.redPrint).frame(width: 3.2, height: 4.2)
                Text(CHDates.string(date, style == .small ? "EEE" : "EEEE").uppercased())
                    .font(CH.labelBold(ws))
                    .tracking(style == .small ? 0.6 : 1.0)
                    .foregroundStyle(CH.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                CHDiamond().fill(CH.redPrint).frame(width: 3.2, height: 4.2)
            }
            .padding(.bottom, style == .large ? 3 : (style == .small ? 5 : 7))
            if style == .large {
                CHDoubleRule(color: CH.redPrint).frame(height: 2.6)
                weekRow.padding(.top, 3).padding(.bottom, 6)
            }
        }
        .padding(.horizontal, style == .small ? 6 : 7)
    }

    private var numeral: some View {
        let d = CHDates.string(date, "d")
        return ZStack {
            // Misregistered second pass of the red plate.
            Text(d).font(CH.bodoniBold(numeralSize)).foregroundStyle(Color(hex: 0xE0503C, opacity: 0.35)).offset(x: 1.1, y: 0.7)
            Text(d).font(CH.bodoniBold(numeralSize)).foregroundStyle(CH.redPrint)
            Text(d).font(CH.bodoniBold(numeralSize)).foregroundStyle(Color(hex: 0x6A0A0A, opacity: 0.25)).blendMode(.multiply).offset(x: 0.3, y: 0.4)
        }
        .fixedSize()
        .padding(.vertical, -numeralSize * 0.14)
    }

    private var weekRow: some View {
        let days = CHDates.week(of: date)
        let cal = Calendar.current
        return HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                let today = cal.isDate(d, inSameDayAs: date)
                VStack(spacing: 0) {
                    Text(String(CHDates.string(d, "EEEEE")))
                        .font(CH.label(6.5))
                        .foregroundStyle(i == 6 ? CH.redPrint : CH.inkSoft)
                    Text(CHDates.string(d, "d"))
                        .font(CH.bodoniBold(10))
                        .foregroundStyle(today ? CH.redPrint : (i == 6 ? CH.redPrint.opacity(0.85) : CH.ink))
                        .background {
                            if today {
                                CHInkRing(seed: 3).stroke(CH.redInk.opacity(0.85), lineWidth: 0.9).frame(width: 15, height: 13).offset(y: 0.5)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct CHDoubleRule: View {
    var color: Color
    var body: some View {
        Canvas { ctx, s in
            ctx.fill(Path(CGRect(x: 0, y: 0, width: s.width, height: 0.9)), with: .color(color))
            ctx.fill(Path(CGRect(x: 0, y: s.height - 0.5, width: s.width, height: 0.5)), with: .color(color.opacity(0.8)))
        }
    }
}

struct CHDiamond: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// A quick hand-inked loop, as if circled with a fountain pen.
struct CHInkRing: Shape {
    var seed: UInt64
    func path(in r: CGRect) -> Path {
        var pts: [CGPoint] = []
        let n = 22
        for i in 0...n + 3 {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi * 1.0 - .pi * 0.7
            let wob = 1 + CHGeo.wobble(CGFloat(i), seed: seed, base: 0.7) * 0.07 + CGFloat(i) / CGFloat(n) * 0.06
            pts.append(CGPoint(x: r.midX + cos(a) * r.width / 2 * wob, y: r.midY + sin(a) * r.height / 2 * wob))
        }
        return CHGeo.smooth(pts)
    }
}

// MARK: - The ledger (a folded letter with the day's tasks)

struct CHLedgerMetrics {
    var font: CGFloat
    var due: CGFloat
    var row: CGFloat
    var header: CGFloat
    var margin: CGFloat         // x of the text column
    var padTop: CGFloat
    var padRight: CGFloat
    var twoLine: Bool           // due label under the task instead of beside it
    var clip: Bool = false
    var showCount: Bool = true

    static let large = CHLedgerMetrics(font: 14.5, due: 9.5, row: 23, header: 24, margin: 34, padTop: 9, padRight: 12, twoLine: false, clip: true)
    static let medium = CHLedgerMetrics(font: 12.5, due: 8.5, row: 31, header: 19, margin: 24, padTop: 7, padRight: 9, twoLine: true, showCount: false)
}

struct CHLedger: View {
    var tasks: [TaskItem]
    var total: Int
    var error: String?
    var size: CGSize
    var m: CHLedgerMetrics
    var seed: UInt64 = 9

    private let bleed: CGFloat = 12
    private var more: Int { max(0, total - tasks.count) }

    var body: some View {
        Canvas { ctx, _ in
            var c = ctx
            c.translateBy(x: bleed, y: bleed)
            drawPaper(c)
        }
        .padding(-bleed)
        .overlay(alignment: .topLeading) { content }
        .frame(width: size.width, height: size.height)
    }

    private var foldY: CGFloat { size.height * 0.36 }

    private func drawPaper(_ ctx: GraphicsContext) {
        let r = CGRect(origin: .zero, size: size)
        let ear: CGFloat = m.twoLine ? 9 : 12
        var sheet = Path()
        sheet.move(to: CGPoint(x: r.minX, y: r.minY))
        sheet.addLine(to: CGPoint(x: r.maxX - ear, y: r.minY))
        sheet.addLine(to: CGPoint(x: r.maxX, y: r.minY + ear))
        sheet.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        sheet.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        sheet.closeSubpath()
        var sh = ctx
        sh.addFilter(.blur(radius: 4))
        sh.fill(sheet.offsetBy(dx: 3, dy: 4.5), with: .color(.black.opacity(0.75)))
        var contact = ctx
        contact.addFilter(.blur(radius: 0.8))
        contact.fill(sheet.offsetBy(dx: 0.5, dy: 0.9), with: .color(.black.opacity(0.5)))

        var p = ctx
        p.clip(to: sheet)
        p.draw(ctx.resolve(CH.texture("paper")), in: r.insetBy(dx: -2, dy: -2))
        // The fold: the upper third tilts toward the lamp, the rest away.
        p.fill(Path(CGRect(x: 0, y: 0, width: r.width, height: foldY)),
               with: .linearGradient(Gradient(colors: [.white.opacity(0.10), Color(hex: 0x6A4A2A, opacity: 0.06)]),
                                     startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: foldY)))
        p.fill(Path(CGRect(x: 0, y: foldY, width: r.width, height: r.height - foldY)),
               with: .linearGradient(Gradient(colors: [Color(hex: 0x6A4A2A, opacity: 0.12), .clear, Color(hex: 0x4A2E18, opacity: 0.10)]),
                                     startPoint: CGPoint(x: 0, y: foldY), endPoint: CGPoint(x: 0, y: r.maxY)))
        p.fill(Path(CGRect(x: 0, y: foldY - 0.4, width: r.width, height: 0.5)), with: .color(Color(hex: 0x5A3E26, opacity: 0.35)))
        p.fill(Path(CGRect(x: 0, y: foldY + 0.2, width: r.width, height: 0.6)), with: .color(.white.opacity(0.4)))
        // Tungsten on paper: warm where the lamp reaches, falling to umber in the far corner.
        var lit = p
        lit.blendMode = .multiply
        lit.fill(Path(r), with: .radialGradient(Gradient(stops: [
            .init(color: Color(hex: 0xFFF3DC), location: 0), .init(color: Color(hex: 0xF6DDB2), location: 0.45),
            .init(color: Color(hex: 0xC09A70), location: 1)]),
            center: CGPoint(x: r.width * 0.18, y: -r.height * 0.15), startRadius: 0, endRadius: hypot(r.width, r.height) * 0.95))
        // A tea-cup ring someone set down on the letter.
        if !m.twoLine {
            let cc = CGPoint(x: r.maxX - r.width * 0.12, y: r.maxY - r.height * 0.1)
            let cr = r.height * 0.17
            var ring = Path()
            for i in 0...40 {
                let a = CGFloat(i) / 40 * 2 * .pi
                let rr = cr * (1 + CHGeo.wobble(CGFloat(i), seed: 5, base: 0.4) * 0.03)
                let pt = CGPoint(x: cc.x + cos(a) * rr, y: cc.y + sin(a) * rr)
                if i == 0 { ring.move(to: pt) } else { ring.addLine(to: pt) }
            }
            var rc = p
            rc.addFilter(.blur(radius: 0.5))
            rc.stroke(ring, with: .color(Color(hex: 0x7A4A22, opacity: 0.16)), lineWidth: 1.6)
            rc.stroke(ring.offsetBy(dx: 0.8, dy: 0.5), with: .color(Color(hex: 0x6A3A18, opacity: 0.12)), lineWidth: 0.6)
        }

        // Ruling: faint blue lines under each row, a red double margin.
        let first = m.padTop + m.header
        var rules = Path()
        for i in 0..<40 {
            let y = first + m.row * CGFloat(i + 1) - (m.twoLine ? 2 : 3.5)
            guard y < r.maxY - 3 else { break }
            rules.move(to: CGPoint(x: 4, y: y))
            rules.addLine(to: CGPoint(x: r.maxX - 4, y: y))
        }
        p.stroke(rules, with: .color(Color(hex: 0x6F8AA6, opacity: 0.35)), lineWidth: 0.5)
        let mx = m.margin - 6
        p.fill(Path(CGRect(x: mx, y: 0, width: 0.6, height: r.height)), with: .color(CH.redInk.opacity(0.45)))
        p.fill(Path(CGRect(x: mx + 1.6, y: 0, width: 0.4, height: r.height)), with: .color(CH.redInk.opacity(0.35)))
        // Header underline in red ink.
        p.fill(Path(CGRect(x: 4, y: first - 3, width: r.width - 8, height: 0.7)), with: .color(CH.redInk.opacity(0.55)))

        // Dog-ear.
        var fold = Path()
        fold.move(to: CGPoint(x: r.maxX - ear, y: r.minY))
        fold.addLine(to: CGPoint(x: r.maxX - ear, y: r.minY + ear))
        fold.addLine(to: CGPoint(x: r.maxX, y: r.minY + ear))
        fold.closeSubpath()
        var fs = ctx
        fs.addFilter(.blur(radius: 1.2))
        fs.fill(fold.offsetBy(dx: -0.8, dy: 1), with: .color(.black.opacity(0.35)))
        ctx.fill(fold, with: .linearGradient(Gradient(colors: [Color(hex: 0xE4D4B0), Color(hex: 0xBFA67E)]),
                                             startPoint: CGPoint(x: r.maxX - ear, y: r.minY + ear), endPoint: CGPoint(x: r.maxX - ear * 0.4, y: r.minY + ear * 0.4)))

        if m.clip { paperClip(ctx, at: CGPoint(x: m.margin + 10, y: -5)) }
    }

    private func paperClip(_ ctx: GraphicsContext, at o: CGPoint) {
        var outer = Path(roundedRect: CGRect(x: o.x, y: o.y, width: 9, height: 26), cornerRadius: 4.5)
        outer.addPath(Path(roundedRect: CGRect(x: o.x + 2.2, y: o.y + 3.5, width: 4.6, height: 17), cornerRadius: 2.3))
        let wire = outer.strokedPath(StrokeStyle(lineWidth: 1.1))
        var s = ctx
        s.addFilter(.blur(radius: 0.9))
        s.fill(wire.offsetBy(dx: 1, dy: 1.4), with: .color(.black.opacity(0.55)))
        ctx.fill(wire, with: .linearGradient(Gradient(colors: [Color(hex: 0xF4D894), Color(hex: 0xA8782E), Color(hex: 0x6A4614)]),
                                             startPoint: CGPoint(x: o.x, y: o.y), endPoint: CGPoint(x: o.x + 9, y: o.y + 26)))
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Things to do")
                    .font(CH.baskSemiItalic(m.header * 0.6))
                    .foregroundStyle(CH.ink)
                Spacer(minLength: 4)
                if m.showCount, error == nil, total > 0 {
                    Text("\(CHDates.numberWord(total)) in all")
                        .font(CH.label(m.due))
                        .foregroundStyle(CH.inkSoft)
                        .lineLimit(1)
                }
            }
            .padding(.leading, m.margin)
            .padding(.trailing, m.padRight + (m.twoLine ? 8 : 10))
            .frame(height: m.header - 4, alignment: .center)
            .padding(.bottom, 4)

            if let error {
                VStack(alignment: .leading, spacing: 3) {
                    Text("The list didn't come tonight.")
                        .font(CH.baskItalic(m.font))
                        .foregroundStyle(CH.redInk)
                        .lineLimit(2)
                    Text(error)
                        .font(CH.label(m.due))
                        .foregroundStyle(CH.inkSoft)
                        .lineLimit(m.twoLine ? 3 : 2)
                        .truncationMode(.tail)
                }
                .padding(.leading, m.margin)
                .padding(.trailing, m.padRight)
                .padding(.top, 6)
            } else if tasks.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nothing on the list tonight.")
                        .font(CH.baskItalic(m.font))
                        .foregroundStyle(CH.ink)
                        .lineLimit(2)
                    Text("the evening is yours")
                        .font(CH.label(m.due))
                        .foregroundStyle(CH.inkSoft)
                }
                .padding(.leading, m.margin)
                .padding(.trailing, m.padRight)
                .padding(.top, 6)
            } else {
                ForEach(Array(tasks.enumerated()), id: \.offset) { i, t in
                    row(t, index: i)
                        .frame(height: m.row)
                }
                if more > 0 {
                    Text("+\(more) more")
                        .font(CH.baskItalic(m.font * 0.8))
                        .foregroundStyle(CH.inkSoft)
                        .padding(.leading, m.margin)
                        .frame(height: m.twoLine ? 13 : 18, alignment: .center)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, m.padTop)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func row(_ t: TaskItem, index i: Int) -> some View {
        let overdue = t.isOverdue(asOf: Mock.now)
        return HStack(alignment: m.twoLine ? .top : .firstTextBaseline, spacing: 0) {
            Text("\(i + 1)")
                .font(CH.bodoniItalic(m.font * 0.86))
                .foregroundStyle(overdue ? CH.redInk : CH.inkSoft)
                .background {
                    if overdue {
                        CHInkRing(seed: UInt64(i) &+ 11).stroke(CH.redInk.opacity(0.8), lineWidth: 0.8)
                            .frame(width: m.font * 1.1, height: m.font * 1.0)
                            .offset(x: 0.5, y: 0.5)
                    }
                }
                .frame(width: m.margin - 10, alignment: .center)
                .padding(.trailing, 10)
                .padding(.top, m.twoLine ? 2 : 0)
            if m.twoLine {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        taskText(t)
                        CHPriorityMark(priority: t.priority)
                    }
                    CHDueLabel(task: t, size: m.due)
                }
                .padding(.trailing, m.padRight)
            } else {
                taskText(t)
                CHPriorityMark(priority: t.priority).padding(.leading, 4).alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 1 }
                Spacer(minLength: 8)
                CHDueLabel(task: t, size: m.due)
                    .padding(.trailing, m.padRight)
            }
        }
    }

    private func taskText(_ t: TaskItem) -> some View {
        Text(t.text)
            .font(CH.baskItalic(m.font))
            .foregroundStyle(CH.ink)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

struct CHPriorityMark: View {
    var priority: TaskPriority
    var body: some View {
        let n = priority == .highest ? 2 : (priority == .high ? 1 : 0)
        if n > 0 {
            HStack(spacing: 1) {
                ForEach(0..<n, id: \.self) { _ in CHDiamond().fill(CH.redInk.opacity(0.85)).frame(width: 3.6, height: 5) }
            }
            .fixedSize()
        }
    }
}

struct CHDueLabel: View {
    var task: TaskItem
    var size: CGFloat

    var body: some View {
        if let label = Mock.dueLabel(task) {
            if task.isOverdue(asOf: Mock.now) {
                // A rubber stamp in red: boxed, slightly askew.
                Text(label)
                    .font(CH.labelBold(size))
                    .foregroundStyle(CH.redInk)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 0.5)
                    .overlay { RoundedRectangle(cornerRadius: 1.5).stroke(CH.redInk.opacity(0.85), lineWidth: 0.9) }
                    .rotationEffect(.degrees(-4))
                    .fixedSize()
            } else if task.isDueToday(asOf: Mock.now) {
                Text(label)
                    .font(CH.labelBold(size))
                    .foregroundStyle(CH.ink)
                    .background(alignment: .bottom) {
                        Rectangle().fill(CH.redInk.opacity(0.7)).frame(height: 0.8).offset(y: 1.2)
                    }
                    .fixedSize()
            } else {
                Text(label)
                    .font(CH.label(size))
                    .foregroundStyle(CH.inkSoft)
                    .fixedSize()
            }
        }
    }
}

// MARK: - Intertitle type and the next button

struct CHRedRule: View {
    var width: CGFloat = 36
    var body: some View {
        HStack(spacing: 4) {
            Rectangle().fill(CH.crimsonLit).frame(width: width, height: 0.9)
            CHDiamond().fill(CH.crimsonLit).frame(width: 3.5, height: 4.5)
        }
        .shadow(color: CH.crimsonLit.opacity(0.6), radius: 2)
    }
}

struct CHIntertitle: View {
    var quote: Quote
    var font: CGFloat
    var authorSize: CGFloat
    var maxLines: Int
    var ruleWidth: CGFloat = 36
    var authorInset: CGFloat = 0
    var gap: CGFloat = 0.45

    var body: some View {
        VStack(alignment: .leading, spacing: font * gap) {
            CHRedRule(width: ruleWidth)
            Text(quote.text)
                .font(CH.didotItalic(font))
                .lineSpacing(font * 0.06)
                .foregroundStyle(CH.cream)
                .lineLimit(maxLines)
                .minimumScaleFactor(0.72)
                .truncationMode(.tail)
                .layoutPriority(1)
                .chHalo(radius: 1.6, opacity: 0.9)
            if let a = quote.author, !a.isEmpty {
                Text("— " + a)
                    .font(CH.label(authorSize))
                    .tracking(1.1)
                    .foregroundStyle(CH.tungsten)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.trailing, authorInset)
                    .chHalo(radius: 1.2)
            }
        }
    }
}

/// The next-quote button: an oxblood enamel disc with a cream arrow, lit from the lamp.
struct CHNextButton: View {
    var size: CGFloat = 26

    var body: some View {
        Canvas { ctx, s in
            let d = CGRect(x: (s.width - size) / 2, y: (s.height - size) / 2, width: size, height: size)
            var sh = ctx
            sh.addFilter(.blur(radius: 2.5))
            sh.fill(Path(ellipseIn: d.offsetBy(dx: 1.2, dy: 2.2)), with: .color(.black.opacity(0.8)))
            ctx.fill(Path(ellipseIn: d), with: .radialGradient(Gradient(colors: [Color(hex: 0xC8402F), Color(hex: 0x7A1418), Color(hex: 0x3A060A)]),
                                                               center: CGPoint(x: d.minX + d.width * 0.35, y: d.minY + d.height * 0.3),
                                                               startRadius: 0, endRadius: size * 0.75))
            ctx.stroke(Path(ellipseIn: d.insetBy(dx: 0.4, dy: 0.4)), with: .color(CH.tungsten.opacity(0.75)), lineWidth: 0.8)
            ctx.stroke(Path(ellipseIn: d.insetBy(dx: 2.2, dy: 2.2)), with: .color(.black.opacity(0.35)), lineWidth: 0.6)
            // Glaze highlight.
            ctx.fill(Path(ellipseIn: CGRect(x: d.minX + size * 0.2, y: d.minY + size * 0.1, width: size * 0.38, height: size * 0.2)),
                     with: .color(.white.opacity(0.22)))
            // Arrow: a long hairline shaft and a fine barbed head.
            let cy = d.midY
            var a = Path()
            a.move(to: CGPoint(x: d.minX + size * 0.26, y: cy))
            a.addLine(to: CGPoint(x: d.maxX - size * 0.27, y: cy))
            var head = Path()
            head.move(to: CGPoint(x: d.maxX - size * 0.40, y: cy - size * 0.15))
            head.addQuadCurve(to: CGPoint(x: d.maxX - size * 0.25, y: cy), control: CGPoint(x: d.maxX - size * 0.33, y: cy - size * 0.03))
            head.addQuadCurve(to: CGPoint(x: d.maxX - size * 0.40, y: cy + size * 0.15), control: CGPoint(x: d.maxX - size * 0.33, y: cy + size * 0.03))
            var ds = ctx
            ds.addFilter(.shadow(color: .black.opacity(0.6), radius: 0.6, x: 0.3, y: 0.6))
            ds.stroke(a, with: .color(CH.cream), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            ds.stroke(head, with: .color(CH.cream), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size + 8, height: size + 8)
    }
}
