import SwiftUI

// Day widgets. Large: the field station in cutaway, a felt mountain sliced open to show five numbered rooms
// (one task each) above a walnut plinth with a brass plate; embroidered date and weather patches flank the
// summit and its sunburst. Medium: a typed mission log on a clipboard beside a felt mountain and the date
// patch. Small: satin-stitched date and temperature over a felt range, the first task on an index strip.

/// Places a view at an absolute rect inside a top-leading ZStack.
struct EXPlaced<Content: View>: View {
    var rect: CGRect
    var alignment: Alignment = .topLeading
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(width: rect.width, height: rect.height, alignment: alignment)
            .offset(x: rect.minX, y: rect.minY)
    }
}

enum EXDayText {
    static func weekday(_ d: Date) -> String { EXDates.string(d, "EEEE").uppercased() }
    static func weekdayShort(_ d: Date) -> String { EXDates.string(d, "EEE").uppercased() }
    static func day(_ d: Date) -> String { EXDates.string(d, "d") }
    static func month(_ d: Date) -> String { EXDates.string(d, "MMMM").uppercased() }
    static func monthShort(_ d: Date) -> String { EXDates.string(d, "MMM").uppercased() }

    static func stampColor(_ t: TaskItem) -> Color {
        if t.exLate { return EX.tomato }
        if t.exToday { return EX.tomatoDeep }
        if Mock.dueLabel(t) == "tomorrow" { return EX.teal }
        return EX.inkSoft
    }
}

/// The due stamp for a task, or nothing when it has no date.
struct EXDueStamp: View {
    var task: TaskItem
    var size: CGFloat = 9
    var body: some View {
        if let label = EXCopy.dueStamp(task) {
            EXStamp(text: label, color: EXDayText.stampColor(task), angle: task.exLate ? -4 : -2, size: size, filled: task.exLate)
        }
    }
}

// MARK: - Large

struct EXDayLarge: View {
    var snap: DaySnapshot

    static let size = Mock.size(.large)
    static let cutTop: CGFloat = 109
    static let plinthTop: CGFloat = 322
    static let shaft = CGRect(x: 13, y: 114, width: 21, height: 194)
    static let rooms: [CGRect] = (0..<5).map { CGRect(x: 40, y: 116 + CGFloat($0) * 39, width: 295, height: 34) }
    static let walls: [UInt32] = [0xEBC66C, 0xA9CBBE, 0xEDA987, 0xDCCB9E, 0xF1B95E]

    private var weather: EXWeather { EXWeather(code: snap.weather?.code) }
    private var shown: [TaskItem] { Array(snap.tasks.prefix(5)) }

    var body: some View {
        let s = Self.size
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in Self.drawScene(ctx, size, weather: weather, lateRooms: lateRooms) }
            EXPlaced(rect: CGRect(x: 12, y: 12, width: 88, height: 88)) { datePatch }
            EXPlaced(rect: CGRect(x: 232, y: 12, width: 104, height: 88)) { weatherPatch }
            ForEach(0..<5, id: \.self) { i in room(i) }
            if shown.isEmpty { emptyNote }
            EXPlaced(rect: CGRect(x: 18, y: 327, width: 312, height: 24)) { EXBrassPlate() }
            EXPlaced(rect: CGRect(x: 30, y: 327, width: 288, height: 24), alignment: .center) { plateText }
            EXFinish(gloom: weather.gloom)
        }
        .frame(width: s.width, height: s.height)
    }

    private var lateRooms: [Bool] { (0..<5).map { $0 < shown.count && shown[$0].exLate } }

    // MARK: Patches

    private var datePatch: some View {
        EXPatch(shape: .circle, fill: EX.tomato, border: EX.mustard, borderShade: EX.mustardDeep, seed: 11) {
            VStack(spacing: -3) {
                Text(EXDayText.weekday(snap.date)).font(EX.headMed(8.5)).kerning(1.4).foregroundStyle(EX.creamLight)
                    .lineLimit(1).minimumScaleFactor(0.7)
                EXStitchedText(text: EXDayText.day(snap.date), font: EX.head(40), color: EX.creamLight)
                    .padding(.vertical, -2)
                Text(EXDayText.month(snap.date)).font(EX.headMed(8.5)).kerning(1.4).foregroundStyle(EX.creamLight)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: 62)
        }
    }

    private var weatherPatch: some View {
        EXPatch(shape: .rounded(14), fill: EX.prussian, border: EX.mustard, borderShade: EX.mustardDeep, seed: 12) {
            if let w = snap.weather {
                VStack(spacing: 0) {
                    EXStitchedText(text: EXCopy.temp(w.temperature), font: EX.head(31), color: EX.goldenrod)
                    Text(w.label.uppercased()).font(EX.headMed(9.5)).kerning(1).foregroundStyle(EX.creamLight)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.top, -2)
                    Text("H \(EXCopy.temp(w.high))  L \(EXCopy.temp(w.low))").font(EX.type(8.5)).foregroundStyle(EX.cream)
                        .padding(.top, 2)
                    Text(sunLine(w)).font(EX.type(8.5)).foregroundStyle(EX.cream)
                }
                .lineLimit(1)
                .frame(width: 80)
            } else {
                VStack(spacing: 4) {
                    EXStitchedText(text: "NO SIGNAL", font: EX.head(17), color: EX.goldenrod, kerning: 1)
                        .lineLimit(1).fixedSize()
                    Text(snap.weatherError ?? "Weather offline").font(EX.type(8.5)).foregroundStyle(EX.cream)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                }
                .frame(width: 78)
            }
        }
    }

    private func sunLine(_ w: WeatherSnapshot) -> String {
        if let rise = w.sunrise, Mock.now < rise { return "SUNRISE \(EXDates.string(rise, "h:mm"))" }
        if let set = w.sunset { return "SUNSET \(EXDates.string(set, "h:mm"))" }
        return "SUNRISE \(w.sunrise.map { EXDates.string($0, "h:mm") } ?? "--")"
    }

    // MARK: Rooms

    @ViewBuilder private func room(_ i: Int) -> some View {
        let r = Self.rooms[i]
        if i < shown.count {
            let t = shown[i]
            EXPlaced(rect: CGRect(x: r.minX + 5, y: r.minY + 11, width: 15, height: 15)) {
                EXCallout(n: i + 1, size: 15, fill: EX.creamLight)
            }
            EXPlaced(rect: CGRect(x: r.minX + 26, y: r.minY + 2, width: r.width - 26 - 74, height: r.height - 4), alignment: .leading) {
                Text(t.text)
                    .font(t.exLate ? EX.typeBold(12) : EX.type(12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .exInk()
            }
            EXPlaced(rect: CGRect(x: r.maxX - 72, y: r.minY + 2, width: 66, height: r.height - 4), alignment: .trailing) {
                EXDueStamp(task: t, size: 9)
            }
        } else if i == 0, let err = snap.taskError {
            EXPlaced(rect: CGRect(x: r.minX + 8, y: r.minY + 2, width: r.width - 16, height: r.height - 4), alignment: .leading) {
                HStack(spacing: 6) {
                    EXStamp(text: "RADIO SILENCE", color: EX.tomato, angle: -3, size: 8.5, filled: true)
                    Text(err).font(EX.type(10)).lineLimit(2).minimumScaleFactor(0.85).exInk()
                }
            }
        }
    }

    @ViewBuilder private var emptyNote: some View {
        if snap.taskError == nil {
            let r = Self.rooms[1]
            EXPlaced(rect: CGRect(x: r.minX + 10, y: r.minY, width: r.width - 20, height: r.height), alignment: .center) {
                Text("All quiet at the station. Nothing on the log.")
                    .font(EX.type(11.5)).lineLimit(1).minimumScaleFactor(0.8).exInk()
            }
        }
    }

    // MARK: Plate

    private var plateText: some View {
        let more = max(0, snap.tasks.count - shown.count)
        let week = EXDates.week(of: snap.date)
        let cal = Calendar.current
        return HStack(spacing: 0) {
            Group {
                if snap.taskError != nil && !snap.tasks.isEmpty {
                    Text("CACHED LOG").foregroundStyle(EX.tomatoDeep)
                } else {
                    Text(snap.tasks.isEmpty ? "LOG CLEAR" : "\(snap.tasks.count) ON THE LOG")
                }
            }
            .frame(width: 84, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { i in
                    let today = cal.isDate(week[i], inSameDayAs: snap.date)
                    Text(String(EXDates.string(week[i], "EEEEE")))
                        .font(EX.head(9))
                        .foregroundStyle(today ? EX.creamLight : EX.walnutDeep.opacity(0.85))
                        .frame(width: 13, height: 13)
                        .background {
                            if today {
                                Circle().fill(RadialGradient(colors: [Color(hex: 0xE2574A), EX.tomatoDeep], center: UnitPoint(x: 0.35, y: 0.3),
                                                             startRadius: 0, endRadius: 9))
                                    .overlay(Circle().strokeBorder(EX.brassDeep, lineWidth: 0.6))
                            }
                        }
                }
            }
            Spacer(minLength: 0)
            Text(more > 0 ? "+\(more) MORE" : "ALL SHOWN")
                .frame(width: 84, alignment: .trailing)
        }
        .font(EX.headMed(9.5))
        .kerning(0.9)
        .lineLimit(1)
        .foregroundStyle(EX.walnutDeep)
        .shadow(color: .white.opacity(0.45), radius: 0, x: 0.4, y: 0.6)
    }

    // MARK: Scene

    static func drawScene(_ ctx: GraphicsContext, _ s: CGSize, weather w: EXWeather, lateRooms: [Bool]) {
        let kit = EXKit(ctx)
        let sb: CGFloat = w.snows ? 1.5 : 1
        EXScenery.sky(ctx, CGRect(x: 0, y: 0, width: s.width, height: 190), kit: kit, gloom: w.gloom)
        let sun = CGPoint(x: 174, y: 38)
        EXScenery.skyProps(ctx, w, sun: sun, radius: 26,
                           clouds: [CGPoint(x: 122, y: 30), CGPoint(x: 226, y: 22), CGPoint(x: 172, y: 10)],
                           cloudWidth: 40, kit: kit, seed: 70)
        // Far range, hazy.
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.25), CGPoint(x: 0.07, y: 0.19), CGPoint(x: 0.15, y: 0.235), CGPoint(x: 0.24, y: 0.16),
            CGPoint(x: 0.33, y: 0.225), CGPoint(x: 0.40, y: 0.19), CGPoint(x: 0.47, y: 0.235), CGPoint(x: 0.55, y: 0.20),
            CGPoint(x: 0.62, y: 0.225), CGPoint(x: 0.70, y: 0.15), CGPoint(x: 0.79, y: 0.22), CGPoint(x: 0.88, y: 0.17),
            CGPoint(x: 0.96, y: 0.23), CGPoint(x: 1.02, y: 0.21)],
            color: EX.hPrussian, haze: 0.5, bottom: 0.5, snow: 7 * sb, snowLine: 0.21, lift: 1.2, fuzz: 1.0, seed: 81), kit: kit)
        // Middle range, teal.
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.30), CGPoint(x: 0.08, y: 0.245), CGPoint(x: 0.17, y: 0.285), CGPoint(x: 0.27, y: 0.22),
            CGPoint(x: 0.36, y: 0.27), CGPoint(x: 0.5, y: 0.26), CGPoint(x: 0.64, y: 0.27), CGPoint(x: 0.73, y: 0.22),
            CGPoint(x: 0.83, y: 0.285), CGPoint(x: 0.92, y: 0.245), CGPoint(x: 1.02, y: 0.30)],
            color: EX.hTeal, haze: 0.18, bottom: 0.5, snow: 9 * sb, snowLine: 0.25, stitch: EX.thread.opacity(0.6), lift: 1.8, seed: 82), kit: kit)
        // The station's mountain, with its summit mast.
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.318), CGPoint(x: 0.07, y: 0.305), CGPoint(x: 0.15, y: 0.285), CGPoint(x: 0.23, y: 0.255),
            CGPoint(x: 0.30, y: 0.21), CGPoint(x: 0.37, y: 0.16), CGPoint(x: 0.43, y: 0.11), CGPoint(x: 0.5, y: 0.062),
            CGPoint(x: 0.57, y: 0.11), CGPoint(x: 0.63, y: 0.16), CGPoint(x: 0.70, y: 0.21), CGPoint(x: 0.77, y: 0.255),
            CGPoint(x: 0.85, y: 0.285), CGPoint(x: 0.93, y: 0.305), CGPoint(x: 1.02, y: 0.318)],
            color: 0xB2864A, bottom: 0.6, snow: 30 * sb, snowLine: 0.1, stitch: EX.thread.opacity(0.75),
            capStitch: EX.tomato.opacity(0.8), lift: 2.6, fuzz: 1.3, seed: 83), kit: kit)
        EXScenery.mast(ctx, base: CGPoint(x: 172, y: 24), height: 17)
        // Leader line, cutaway-diagram style: the weather patch reports what the summit mast reads.
        var leader = Path()
        leader.move(to: CGPoint(x: 236, y: 34))
        leader.addLine(to: CGPoint(x: 212, y: 14))
        leader.addLine(to: CGPoint(x: 195, y: 14))
        ctx.stroke(leader.offsetBy(dx: 0.5, dy: 0.7), with: .color(EX.shadow.opacity(0.25)), lineWidth: 0.6)
        ctx.stroke(leader, with: .color(EX.ink.opacity(0.85)), lineWidth: 0.6)
        ctx.fill(Path(ellipseIn: CGRect(x: 192.6, y: 11.6, width: 4.8, height: 4.8)), with: .color(EX.ink))
        ctx.fill(Path(ellipseIn: CGRect(x: 193.8, y: 12.8, width: 2.4, height: 2.4)), with: .color(EX.cream))
        EXScenery.precip(ctx, w, in: CGRect(x: 0, y: 4, width: s.width, height: 100), count: 22, kit: kit, seed: 77)
        drawCutaway(ctx, s, kit: kit, lateRooms: lateRooms)
        drawPlinth(ctx, s, kit: kit)
    }

    /// The cut face: felt strata with stitched seams, a ladder shaft, and five rooms cut into the rock.
    static func drawCutaway(_ ctx: GraphicsContext, _ s: CGSize, kit: EXKit, lateRooms: [Bool]) {
        var rng = SeededRandom(seed: 91)
        // Jagged cut line where the slice was taken.
        var cut: [CGPoint] = []
        var x: CGFloat = -4
        while x < s.width + 6 {
            cut.append(CGPoint(x: x, y: cutTop + rng.range(-2.6...2.6)))
            x += rng.range(7...12)
        }
        var face = cut
        face.append(CGPoint(x: s.width + 4, y: plinthTop + 8))
        face.append(CGPoint(x: -4, y: plinthTop + 8))
        let facePath = EXGeo.roundedPolygon(face, radius: 1.5)
        EXCraft.felt(ctx, facePath, edge: cut, closed: false,
                     style: EXFeltStyle(color: Color(hex: 0x8D6A3E), lift: 1.2, fuzz: 1.0, nap: 0.8), kit: kit, seed: 92)
        var inFace = ctx
        inFace.clip(to: facePath)
        // Strata: wavy felt bands, each seam sewn with a running stitch.
        let bands: [(CGFloat, UInt32)] = [(146, 0xA4582C), (190, 0x7A5634), (236, 0xB0873C), (278, 0x6E4B2E), (306, 0x9A5A2E)]
        for (n, band) in bands.enumerated() {
            var top: [CGPoint] = []
            var bx: CGFloat = -6
            let ph = CGFloat(n) * 1.7
            while bx < s.width + 8 {
                top.append(CGPoint(x: bx, y: band.0 + 4 * sin(bx * 0.028 + ph) + 1.5 * sin(bx * 0.09 + ph * 2)))
                bx += 6
            }
            var poly = top
            poly.append(CGPoint(x: s.width + 8, y: plinthTop + 10))
            poly.append(CGPoint(x: -6, y: plinthTop + 10))
            EXCraft.felt(inFace, EXGeo.roundedPolygon(poly, radius: 2), edge: top, closed: false,
                         style: EXFeltStyle(color: Color(hex: band.1), lift: 1.0, fuzz: 0.9, nap: 0.8, puff: 0.7, fibres: 0.6),
                         kit: kit, seed: 93 &+ UInt64(n))
            EXCraft.stitches(inFace, EXGeo.roundedPolyline(EXGeo.offset(top, by: 2.4), radius: 2), color: EX.thread.opacity(0.55),
                             width: 0.75, dash: [2.2, 2.2])
        }
        // Stitched seam along the cut line, like the slice was sewn on.
        EXCraft.stitches(inFace, EXGeo.roundedPolyline(EXGeo.offset(cut, by: 2.6), radius: 1.5), color: EX.thread.opacity(0.85))
        // Ladder shaft.
        let sh = shaft
        recess(ctx, sh, wall: Color(hex: 0x3B2A1E), kit: kit, seed: 96, felt: true)
        var rails = Path()
        rails.move(to: CGPoint(x: sh.minX + 5, y: sh.minY))
        rails.addLine(to: CGPoint(x: sh.minX + 5, y: sh.maxY))
        rails.move(to: CGPoint(x: sh.maxX - 5, y: sh.minY))
        rails.addLine(to: CGPoint(x: sh.maxX - 5, y: sh.maxY))
        var rungs = Path()
        var ry = sh.minY + 4
        while ry < sh.maxY {
            rungs.move(to: CGPoint(x: sh.minX + 5, y: ry))
            rungs.addLine(to: CGPoint(x: sh.maxX - 5, y: ry))
            ry += 5.5
        }
        var lad = ctx
        lad.clip(to: Path(sh))
        lad.stroke(rungs.offsetBy(dx: 0.6, dy: 1), with: .color(.black.opacity(0.4)), lineWidth: 0.9)
        lad.stroke(rungs, with: .color(Color(hex: 0x9C6B3C)), lineWidth: 0.9)
        lad.stroke(rails.offsetBy(dx: 0.8, dy: 0), with: .color(.black.opacity(0.4)), lineWidth: 1.3)
        lad.stroke(rails, with: .color(Color(hex: 0xB07A44)), lineWidth: 1.3)
        // The lift cable runs up past the ladder to the summit.
        var cable = Path()
        cable.move(to: CGPoint(x: sh.midX, y: sh.minY - 10))
        cable.addLine(to: CGPoint(x: sh.midX, y: sh.maxY))
        lad.stroke(cable, with: .color(EX.ink.opacity(0.8)), lineWidth: 0.5)
        // Lift cage parked between rooms 2 and 3.
        let cage = CGRect(x: sh.minX + 2.5, y: rooms[2].minY - 14, width: sh.width - 5, height: 22)
        lad.fill(Path(cage.offsetBy(dx: 1.2, dy: 1.6)), with: .color(.black.opacity(0.4)))
        lad.fill(Path(cage), with: .color(EX.tomato))
        lad.fill(Path(cage), with: .linearGradient(Gradient(colors: [.white.opacity(0.2), EX.shadow.opacity(0.3)]),
                                                    startPoint: CGPoint(x: cage.minX, y: cage.minY), endPoint: CGPoint(x: cage.maxX, y: cage.maxY)))
        var bars = Path()
        for k in 1..<4 {
            let bx2 = cage.minX + cage.width * CGFloat(k) / 4
            bars.move(to: CGPoint(x: bx2, y: cage.minY + 3))
            bars.addLine(to: CGPoint(x: bx2, y: cage.maxY - 3))
        }
        lad.stroke(bars, with: .color(EX.brassLight), lineWidth: 0.6)
        lad.stroke(Path(cage), with: .color(EX.brassDeep), lineWidth: 0.8)
        // Rooms.
        for (i, r) in rooms.enumerated() {
            recess(ctx, r, wall: Color(hex: walls[i]), kit: kit, seed: 100 &+ UInt64(i))
            wallpaper(ctx, r, style: i, color: Color(hex: EX.mixHex(walls[i], 0x3A2414, 0.5)))
            roomLight(ctx, r, alarm: i < lateRooms.count && lateRooms[i])
            floor(ctx, r, kit: kit)
        }
    }

    /// A recess cut into the face: wall colour, nap, ceiling and left-wall shadows, lit edge on the sill.
    static func recess(_ ctx: GraphicsContext, _ r: CGRect, wall: Color, kit: EXKit, seed: UInt64, felt: Bool = false) {
        var c = ctx
        c.clip(to: Path(r))
        c.fill(Path(r), with: .color(wall))
        var rng = SeededRandom(seed: seed)
        if felt {
            var nap = c
            nap.opacity = 0.32
            nap.draw(kit.felt, in: CGRect(x: r.minX - rng.range(0...40), y: r.minY - rng.range(0...200), width: 360, height: 380))
        } else {
            // Painted paper walls: the card stock's tooth multiplied into the paint.
            var paper = c
            paper.blendMode = .multiply
            paper.draw(kit.card, in: CGRect(x: r.minX - rng.range(0...20), y: r.minY - rng.range(0...200), width: 320, height: 280))
        }
        c.fill(Path(CGRect(x: r.minX, y: r.minY, width: r.width, height: 9)), with: .linearGradient(
            Gradient(colors: [EX.shadow.opacity(0.55), EX.shadow.opacity(0)]),
            startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: r.minY + 9)))
        c.fill(Path(CGRect(x: r.minX, y: r.minY, width: 7, height: r.height)), with: .linearGradient(
            Gradient(colors: [EX.shadow.opacity(0.42), EX.shadow.opacity(0)]),
            startPoint: CGPoint(x: r.minX, y: 0), endPoint: CGPoint(x: r.minX + 7, y: 0)))
        c.fill(Path(CGRect(x: r.maxX - 3, y: r.minY, width: 3, height: r.height)), with: .color(.white.opacity(0.1)))
        // Cut edge of the opening: dark lip above, light lip below.
        var lip = Path()
        lip.move(to: CGPoint(x: r.minX - 0.5, y: r.minY))
        lip.addLine(to: CGPoint(x: r.maxX + 0.5, y: r.minY))
        ctx.stroke(lip, with: .color(EX.shadow.opacity(0.6)), lineWidth: 1)
        var sill = Path()
        sill.move(to: CGPoint(x: r.minX - 0.5, y: r.maxY + 0.6))
        sill.addLine(to: CGPoint(x: r.maxX + 0.5, y: r.maxY + 0.6))
        ctx.stroke(sill, with: .color(.white.opacity(0.35)), lineWidth: 0.8)
    }

    /// Five wallpapers, one per room, kept faint so typed text stays legible.
    static func wallpaper(_ ctx: GraphicsContext, _ r: CGRect, style: Int, color: Color) {
        var c = ctx
        c.clip(to: Path(r))
        let ink = color.opacity(0.16)
        var p = Path()
        switch style % 5 {
        case 0:
            var x = r.minX + 2
            while x < r.maxX { p.move(to: CGPoint(x: x, y: r.minY)); p.addLine(to: CGPoint(x: x, y: r.maxY)); x += 4 }
            c.stroke(p, with: .color(ink), lineWidth: 0.6)
        case 1:
            var y = r.minY + 3
            var row = 0
            while y < r.maxY {
                var x = r.minX + (row % 2 == 0 ? 3 : 6.5)
                while x < r.maxX { p.addEllipse(in: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)); x += 7 }
                y += 5
                row += 1
            }
            c.fill(p, with: .color(ink))
        case 2:
            var x = r.minX
            while x < r.maxX { p.addRect(CGRect(x: x, y: r.minY, width: 5, height: r.height)); x += 10 }
            c.fill(p, with: .color(color.opacity(0.1)))
        case 3:
            var y = r.minY
            var row = 0
            while y < r.maxY + 6 {
                var x = r.minX + (row % 2 == 0 ? 0 : 5)
                while x < r.maxX + 6 {
                    p.move(to: CGPoint(x: x, y: y - 2.2)); p.addLine(to: CGPoint(x: x + 2.2, y: y))
                    p.addLine(to: CGPoint(x: x, y: y + 2.2)); p.addLine(to: CGPoint(x: x - 2.2, y: y)); p.closeSubpath()
                    x += 10
                }
                y += 6
                row += 1
            }
            c.stroke(p, with: .color(ink), lineWidth: 0.5)
        default:
            let wain = CGRect(x: r.minX, y: r.minY + r.height * 0.62, width: r.width, height: r.height * 0.38)
            c.fill(Path(wain), with: .color(color.opacity(0.14)))
            var rail = Path()
            rail.move(to: CGPoint(x: r.minX, y: wain.minY))
            rail.addLine(to: CGPoint(x: r.maxX, y: wain.minY))
            c.stroke(rail, with: .color(color.opacity(0.35)), lineWidth: 0.8)
            c.stroke(rail.offsetBy(dx: 0, dy: 1), with: .color(.white.opacity(0.25)), lineWidth: 0.5)
        }
    }

    /// A pendant lamp over the callout, its warm pool on the wall; red for an overdue room.
    static func roomLight(_ ctx: GraphicsContext, _ r: CGRect, alarm: Bool) {
        let lx = r.minX + 12.5
        let glow = alarm ? Color(hex: 0xFF5A3C) : Color(hex: 0xFFE3A0)
        var pool = ctx
        pool.clip(to: Path(r))
        pool.blendMode = .screen
        pool.fill(Path(r), with: .radialGradient(Gradient(colors: [glow.opacity(alarm ? 0.5 : 0.42), glow.opacity(0)]),
                                                 center: CGPoint(x: lx, y: r.minY + 6), startRadius: 0, endRadius: alarm ? 90 : 120))
        var cord = Path()
        cord.move(to: CGPoint(x: lx, y: r.minY))
        cord.addLine(to: CGPoint(x: lx, y: r.minY + 3))
        ctx.stroke(cord, with: .color(EX.ink), lineWidth: 0.5)
        var shade = Path()
        shade.move(to: CGPoint(x: lx - 1.6, y: r.minY + 3))
        shade.addLine(to: CGPoint(x: lx + 1.6, y: r.minY + 3))
        shade.addLine(to: CGPoint(x: lx + 3.6, y: r.minY + 6.4))
        shade.addLine(to: CGPoint(x: lx - 3.6, y: r.minY + 6.4))
        shade.closeSubpath()
        ctx.fill(shade, with: .color(alarm ? EX.tomato : EX.teal))
        ctx.fill(Path(ellipseIn: CGRect(x: lx - 1.5, y: r.minY + 5.6, width: 3, height: 2)), with: .color(alarm ? Color(hex: 0xFFB09A) : Color(hex: 0xFFF2C4)))
    }

    /// Plank floor with a lit front edge.
    static func floor(_ ctx: GraphicsContext, _ r: CGRect, kit: EXKit) {
        let f = CGRect(x: r.minX, y: r.maxY - 3, width: r.width, height: 3)
        var c = ctx
        c.clip(to: Path(f))
        c.draw(kit.walnut, in: CGRect(x: r.minX, y: f.minY - 40, width: 360, height: 200))
        c.fill(Path(CGRect(x: f.minX, y: f.minY, width: f.width, height: 0.7)), with: .color(.white.opacity(0.35)))
        var seams = Path()
        var x = r.minX + 22
        while x < r.maxX { seams.move(to: CGPoint(x: x, y: f.minY)); seams.addLine(to: CGPoint(x: x, y: f.maxY)); x += 31 }
        c.stroke(seams, with: .color(.black.opacity(0.35)), lineWidth: 0.4)
    }

    /// The walnut plinth the model stands on.
    static func drawPlinth(_ ctx: GraphicsContext, _ s: CGSize, kit: EXKit) {
        let top = plinthTop
        var sh = ctx
        sh.addFilter(.blur(radius: 2.4))
        sh.fill(Path(CGRect(x: 0, y: top - 2, width: s.width, height: 6)), with: .color(EX.shadow.opacity(0.5)))
        let body = CGRect(x: 0, y: top, width: s.width, height: s.height - top)
        var c = ctx
        c.clip(to: Path(body))
        c.draw(kit.walnut, in: CGRect(x: -6, y: top - 60, width: 360, height: 200))
        // Bevelled top edge catching the key light, then the front face falling into shade.
        c.fill(Path(CGRect(x: 0, y: top, width: s.width, height: 3.2)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0xE2B07A).opacity(0.75), Color(hex: 0xA06A3C).opacity(0.3)]),
            startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: top + 3.2)))
        c.fill(Path(CGRect(x: 0, y: top + 3.2, width: s.width, height: 1)), with: .color(.black.opacity(0.35)))
        c.fill(Path(body), with: .linearGradient(Gradient(colors: [.clear, EX.shadow.opacity(0.35)]),
                                                 startPoint: CGPoint(x: 0, y: top + 4), endPoint: CGPoint(x: 0, y: s.height)))
    }
}

// MARK: - Medium

struct EXDayMedium: View {
    var snap: DaySnapshot

    static let size = Mock.size(.medium)
    static let board = CGRect(x: 146, y: 7, width: 192, height: 152)
    static let sheet = CGRect(x: 154, y: 20, width: 172, height: 132)

    private var weather: EXWeather { EXWeather(code: snap.weather?.code) }
    private var shown: [TaskItem] { Array(snap.tasks.prefix(3)) }

    var body: some View {
        let s = Self.size
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in Self.drawScene(ctx, size, weather: weather) }
            EXPlaced(rect: CGRect(x: 12, y: 10, width: 76, height: 76)) { datePatch }
            EXPlaced(rect: CGRect(x: 14, y: 108, width: 114, height: 44)) { weatherTag }
            EXPlaced(rect: Self.board) { EXClipboard() }
            EXPlaced(rect: Self.sheet) { EXCardStock(seed: 21, lift: 1.4, corner: 1.5, header: 24) }
            EXPlaced(rect: CGRect(x: 216, y: 1, width: 48, height: 26)) { EXBoardClip() }
            Canvas { ctx, _ in Self.drawTabs(ctx, count: max(1, shown.count)) }
            logText
            EXFinish(gloom: weather.gloom)
        }
        .frame(width: s.width, height: s.height)
    }

    private var datePatch: some View {
        EXPatch(shape: .circle, fill: EX.tomato, border: EX.mustard, borderShade: EX.mustardDeep, seed: 31) {
            VStack(spacing: -2) {
                Text(EXDayText.weekdayShort(snap.date)).font(EX.headMed(9)).kerning(1.6).foregroundStyle(EX.creamLight)
                EXStitchedText(text: EXDayText.day(snap.date), font: EX.head(34), color: EX.creamLight)
                    .padding(.vertical, -2)
                Text(EXDayText.monthShort(snap.date)).font(EX.headMed(9)).kerning(1.6).foregroundStyle(EX.creamLight)
            }
            .lineLimit(1)
        }
    }

    private var weatherTag: some View {
        ZStack(alignment: .leading) {
            EXCardStock(seed: 32, lift: 1.6, corner: 2)
            HStack(alignment: .center, spacing: 6) {
                if let w = snap.weather {
                    Text(EXCopy.temp(w.temperature)).font(EX.head(25)).foregroundStyle(EX.tomato)
                        .shadow(color: EX.tomato.opacity(0.3), radius: 0.3)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(w.label.uppercased()).font(EX.headMed(9.5)).kerning(0.6).foregroundStyle(EX.ink)
                        Text("H\(EXCopy.temp(w.high)) L\(EXCopy.temp(w.low))").font(EX.type(8.5)).exInk(EX.inkSoft)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("NO SIGNAL").font(EX.head(13)).kerning(1).foregroundStyle(EX.tomato)
                        Text(snap.weatherError ?? "Weather offline").font(EX.type(8.5)).lineLimit(2).exInk(EX.inkSoft)
                    }
                    .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var logText: some View {
        let sh = Self.sheet
        let more = max(0, snap.tasks.count - shown.count)
        return ZStack(alignment: .topLeading) {
            EXPlaced(rect: CGRect(x: sh.minX + 8, y: sh.minY + 8, width: sh.width - 16, height: 14), alignment: .leading) {
                HStack {
                    Text("MISSION LOG").font(EX.head(10.5)).kerning(1.4).foregroundStyle(EX.tomato)
                    Spacer(minLength: 4)
                    Text(snap.tasks.isEmpty ? "" : "\(snap.tasks.count) ENTRIES").font(EX.headMed(9)).kerning(0.8).foregroundStyle(EX.inkSoft)
                }
                .lineLimit(1)
            }
            if shown.isEmpty {
                EXPlaced(rect: CGRect(x: sh.minX + 10, y: sh.minY + 32, width: sh.width - 20, height: 90), alignment: .topLeading) {
                    if let err = snap.taskError {
                        VStack(alignment: .leading, spacing: 5) {
                            EXStamp(text: "RADIO SILENCE", color: EX.tomato, angle: -3, size: 9, filled: true)
                            Text(err).font(EX.type(10)).lineLimit(3).exInk()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("All quiet at the station.").font(EX.type(11)).exInk()
                            Text("Nothing on the log today.").font(EX.type(10)).exInk(EX.inkSoft)
                        }
                        .lineLimit(1)
                    }
                }
            } else {
                ForEach(Array(shown.enumerated()), id: \.offset) { i, t in
                    let y = sh.minY + 31 + CGFloat(i) * 30
                    EXPlaced(rect: CGRect(x: sh.minX + 8, y: y + 0.5, width: 13, height: 13)) {
                        EXCallout(n: i + 1, size: 13, fill: EX.creamLight)
                    }
                    EXPlaced(rect: CGRect(x: sh.minX + 26, y: y, width: sh.width - 34, height: 14), alignment: .leading) {
                        Text(t.text).font(t.exLate ? EX.typeBold(11) : EX.type(11)).lineLimit(1).truncationMode(.tail).exInk()
                    }
                    EXPlaced(rect: CGRect(x: sh.minX + 26, y: y + 14.5, width: 90, height: 13), alignment: .leading) {
                        if t.due == nil {
                            Text("NO DATE").font(EX.headMed(8)).kerning(0.8).foregroundStyle(EX.inkSoft.opacity(0.8))
                        } else {
                            EXDueStamp(task: t, size: 8)
                        }
                    }
                }
                if more > 0 {
                    EXPlaced(rect: CGRect(x: sh.maxX - 70, y: sh.maxY - 18, width: 62, height: 12), alignment: .trailing) {
                        Text("+\(more) MORE").font(EX.head(9.5)).kerning(1).foregroundStyle(EX.tomato)
                    }
                }
            }
        }
    }

    /// Red index tabs sticking out of the sheet's right edge, one per entry.
    static func drawTabs(_ ctx: GraphicsContext, count: Int) {
        for i in 0..<count {
            let y = sheet.minY + 30 + CGFloat(i) * 30
            let r = CGRect(x: sheet.maxX - 2, y: y, width: 9, height: 13)
            let p = Path(roundedRect: r, cornerRadius: 2)
            var sh = ctx
            sh.addFilter(.blur(radius: 0.8))
            sh.fill(p.offsetBy(dx: 0.8, dy: 1.2), with: .color(EX.shadow.opacity(0.5)))
            ctx.fill(p, with: .color(i == 0 ? EX.tomato : (i == 1 ? EX.mustard : EX.teal)))
            ctx.fill(p, with: .linearGradient(Gradient(colors: [.white.opacity(0.22), EX.shadow.opacity(0.2)]),
                                              startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
        }
    }

    static func drawScene(_ ctx: GraphicsContext, _ s: CGSize, weather w: EXWeather) {
        let kit = EXKit(ctx)
        let sb: CGFloat = w.snows ? 1.5 : 1
        EXScenery.sky(ctx, CGRect(origin: .zero, size: s), kit: kit, gloom: w.gloom)
        EXScenery.skyProps(ctx, w, sun: CGPoint(x: 110, y: 44), radius: 15,
                           clouds: [CGPoint(x: 128, y: 92), CGPoint(x: 130, y: 16), CGPoint(x: 62, y: 98)],
                           cloudWidth: 26, kit: kit, seed: 170)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.58), CGPoint(x: 0.06, y: 0.44), CGPoint(x: 0.14, y: 0.55), CGPoint(x: 0.22, y: 0.40),
            CGPoint(x: 0.30, y: 0.52), CGPoint(x: 0.38, y: 0.42), CGPoint(x: 0.46, y: 0.56)],
            color: EX.hPrussian, haze: 0.48, snow: 6 * sb, snowLine: 0.5, lift: 1.2, fuzz: 1.0, seed: 181), kit: kit)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.78), CGPoint(x: 0.05, y: 0.66), CGPoint(x: 0.12, y: 0.70), CGPoint(x: 0.20, y: 0.50),
            CGPoint(x: 0.26, y: 0.36), CGPoint(x: 0.316, y: 0.27), CGPoint(x: 0.37, y: 0.37), CGPoint(x: 0.43, y: 0.55),
            CGPoint(x: 0.48, y: 0.68)],
            color: 0xB2864A, snow: 15 * sb, snowLine: 0.4, stitch: EX.thread.opacity(0.7), capStitch: EX.tomato.opacity(0.8),
            lift: 2.4, seed: 182), kit: kit)
        EXScenery.mast(ctx, base: CGPoint(x: 108, y: 45), height: 13)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.86), CGPoint(x: 0.08, y: 0.80), CGPoint(x: 0.18, y: 0.84), CGPoint(x: 0.28, y: 0.78),
            CGPoint(x: 0.40, y: 0.83), CGPoint(x: 0.5, y: 0.80)],
            color: EX.hOlive, shade: false, lift: 2.2, seed: 183), kit: kit)
        EXScenery.forest(ctx, size: s, ground: [CGPoint(x: -0.02, y: 0.86), CGPoint(x: 0.08, y: 0.80), CGPoint(x: 0.18, y: 0.84),
                                                 CGPoint(x: 0.28, y: 0.78), CGPoint(x: 0.40, y: 0.83), CGPoint(x: 0.5, y: 0.80)],
                         xs: 0.0...0.42, count: 9, heights: 13...21, color: EX.hPine, seed: 184)
        EXScenery.precip(ctx, w, in: CGRect(x: 0, y: 4, width: 150, height: 120), count: 12, kit: kit, seed: 177)
    }
}

// MARK: - Small

struct EXDaySmall: View {
    var snap: DaySnapshot
    static let size = Mock.size(.small)
    private var weather: EXWeather { EXWeather(code: snap.weather?.code) }

    var body: some View {
        let s = Self.size
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in Self.drawScene(ctx, size, weather: weather) }
            EXPlaced(rect: CGRect(x: 16, y: 11, width: 50, height: 52), alignment: .topLeading) {
                VStack(alignment: .leading, spacing: -4) {
                    Text(EXDayText.weekdayShort(snap.date)).font(EX.head(11)).kerning(1.6).foregroundStyle(EX.tomato)
                    EXStitchedText(text: EXDayText.day(snap.date), font: EX.head(29), color: EX.prussian)
                }
            }
            EXPlaced(rect: CGRect(x: 84, y: 11, width: 64, height: 52), alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: -4) {
                    Text(snap.weather.map { EXWeather(code: $0.code).short } ?? "NO SIGNAL").font(EX.head(11)).kerning(1.6)
                        .foregroundStyle(EX.tomato).lineLimit(1).fixedSize()
                    EXStitchedText(text: snap.weather.map { EXCopy.temp($0.temperature) } ?? "—", font: EX.head(29), color: EX.prussian)
                        .fixedSize()
                }
            }
            EXPlaced(rect: CGRect(x: 9, y: 101, width: 146, height: 54)) { EXCardStock(seed: 41, lift: 2, corner: 2, margin: 22) }
            card
            EXFinish(gloom: weather.gloom)
        }
        .frame(width: s.width, height: s.height)
    }

    @ViewBuilder private var card: some View {
        let more = max(0, snap.tasks.count - 1)
        if let t = snap.tasks.first {
            EXPlaced(rect: CGRect(x: 14, y: 108, width: 13, height: 13)) { EXCallout(n: 1, size: 13, fill: EX.creamLight) }
            EXPlaced(rect: CGRect(x: 36, y: 106, width: 112, height: 30), alignment: .topLeading) {
                Text(t.text).font(t.exLate ? EX.typeBold(11) : EX.type(11)).lineLimit(2).truncationMode(.tail)
                    .lineSpacing(-1).exInk()
            }
            EXPlaced(rect: CGRect(x: 34, y: 136, width: 70, height: 14), alignment: .leading) { EXDueStamp(task: t, size: 8) }
            if more > 0 {
                EXPlaced(rect: CGRect(x: 96, y: 136, width: 52, height: 14), alignment: .trailing) {
                    Text("+\(more) MORE").font(EX.head(9)).kerning(0.8).foregroundStyle(EX.tomato)
                }
            }
        } else {
            EXPlaced(rect: CGRect(x: 34, y: 106, width: 114, height: 44), alignment: .leading) {
                if let err = snap.taskError {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RADIO SILENCE").font(EX.head(9)).kerning(1).foregroundStyle(EX.tomato)
                        Text(err).font(EX.type(9.5)).lineLimit(2).exInk()
                    }
                } else {
                    Text("All quiet. Nothing on the log.").font(EX.type(10.5)).lineLimit(2).exInk()
                }
            }
        }
    }

    static func drawScene(_ ctx: GraphicsContext, _ s: CGSize, weather w: EXWeather) {
        let kit = EXKit(ctx)
        let sb: CGFloat = w.snows ? 1.5 : 1
        EXScenery.sky(ctx, CGRect(origin: .zero, size: s), kit: kit, gloom: w.gloom)
        EXScenery.skyProps(ctx, w, sun: CGPoint(x: 81, y: 51), radius: 10,
                           clouds: [CGPoint(x: 52, y: 66), CGPoint(x: 120, y: 74), CGPoint(x: 82, y: 14)],
                           cloudWidth: 24, kit: kit, seed: 270)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.52), CGPoint(x: 0.10, y: 0.42), CGPoint(x: 0.22, y: 0.50), CGPoint(x: 0.78, y: 0.50),
            CGPoint(x: 0.90, y: 0.41), CGPoint(x: 1.02, y: 0.50)],
            color: EX.hPrussian, haze: 0.45, snow: 6 * sb, snowLine: 0.45, lift: 1.2, fuzz: 1.0, seed: 281), kit: kit)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.66), CGPoint(x: 0.12, y: 0.59), CGPoint(x: 0.24, y: 0.54), CGPoint(x: 0.34, y: 0.44),
            CGPoint(x: 0.42, y: 0.35), CGPoint(x: 0.5, y: 0.285), CGPoint(x: 0.58, y: 0.35), CGPoint(x: 0.66, y: 0.44),
            CGPoint(x: 0.76, y: 0.54), CGPoint(x: 0.88, y: 0.59), CGPoint(x: 1.02, y: 0.66)],
            color: 0xB2864A, snow: 15 * sb, snowLine: 0.32, stitch: EX.thread.opacity(0.7), capStitch: EX.tomato.opacity(0.8),
            lift: 2.4, seed: 282), kit: kit)
        EXScenery.mast(ctx, base: CGPoint(x: 84, y: 48), height: 12, mirrored: true)
        EXScenery.ridge(ctx, size: s, EXRidge(top: [
            CGPoint(x: -0.02, y: 0.70), CGPoint(x: 0.14, y: 0.64), CGPoint(x: 0.3, y: 0.69), CGPoint(x: 0.5, y: 0.66),
            CGPoint(x: 0.7, y: 0.69), CGPoint(x: 0.86, y: 0.63), CGPoint(x: 1.02, y: 0.70)],
            color: EX.hTeal, shade: false, lift: 2.0, seed: 283), kit: kit)
        EXScenery.forest(ctx, size: s, ground: [CGPoint(x: -0.02, y: 0.70), CGPoint(x: 0.14, y: 0.64), CGPoint(x: 0.3, y: 0.69),
                                                 CGPoint(x: 0.5, y: 0.66), CGPoint(x: 0.7, y: 0.69), CGPoint(x: 0.86, y: 0.63),
                                                 CGPoint(x: 1.02, y: 0.70)],
                         xs: 0.0...1.0, count: 9, heights: 10...16, color: EX.hPine, seed: 284)
        EXScenery.precip(ctx, w, in: CGRect(x: 0, y: 4, width: s.width, height: 92), count: 10, kit: kit, seed: 277)
    }
}
