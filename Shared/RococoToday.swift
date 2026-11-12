import SwiftUI

// The Today widget in rococo: today's tasks from the vault on painted limestone, each with a carved ring to tick
// (terracotta when late). Medium adds a panel of the flower still life the user sent, with a line in italic. Large
// (2026-11-07, "a bigger version of the tasks list") lays the still life across the top and gives each task room for
// two lines, its due note, and the brief's source note as a caption. The widget wraps each ring in its tick button
// (`tick`), so tapping a ring ticks that task off.

struct RococoTodayView: View {
    var snapshot: DaySnapshot
    var size: BaroqueSize
    /// Wraps each task's ring (the widget passes its tick button; the app's preview and MockLab leave it as it is).
    var tick: (TaskItem, AnyView) -> AnyView = { $1 }

    var body: some View {
        RococoFrame(size: size) {
            switch size {
            case .small: RococoTodaySmall(snap: snapshot, tick: tick)
            case .medium: RococoTodayMedium(snap: snapshot, tick: tick)
            case .large: RococoTodayLarge(snap: snapshot, tick: tick)
            }
        }
    }
}

/// A carved ring to tick; terracotta when the task is late.
struct RococoRing: View {
    var late: Bool

    var body: some View {
        ZStack {
            RococoCarve(shape: Circle(), width: 1)
            if late { Circle().strokeBorder(RococoInk.terracotta.opacity(0.8), lineWidth: 1.1) }
        }
        .frame(width: 13, height: 13)
    }
}

/// A task's ring handed to `tick`: padded out to a 28 point square that takes the tap, then laid out at the ring's
/// own 13 points, so the button is easy to hit and nothing around it moves.
struct RococoTickRing: View {
    var task: TaskItem
    var late: Bool
    var tick: (TaskItem, AnyView) -> AnyView

    static let hitPadding: CGFloat = 7.5   // (28 - 13) / 2

    var body: some View {
        tick(task, AnyView(RococoRing(late: late).padding(Self.hitPadding).contentShape(Rectangle())))
            .padding(-Self.hitPadding)
    }
}

/// "Today", the tasks, and the count of any that don't fit. With a fetch error and tasks to show (the cache), the
/// error takes the last row so it can be read.
struct RococoTodayList: View {
    var snap: DaySnapshot
    var rows: Int
    var width: CGFloat
    var tick: (TaskItem, AnyView) -> AnyView = { $1 }

    var body: some View {
        let error = snap.taskError
        let shown = Array(snap.tasks.prefix(error == nil || snap.tasks.isEmpty ? rows : rows - 1))
        let more = snap.tasks.count - shown.count
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today").font(RococoType.serif(18)).foregroundStyle(RococoInk.ink)
                Spacer()
                if more > 0 {
                    Text(RococoWords.more(more)).font(RococoType.sans(9)).foregroundStyle(RococoInk.inkSoft)
                }
            }
            .padding(.bottom, 8)
            if snap.tasks.isEmpty {
                Text(error ?? "Nothing due today.")
                    .font(RococoType.sans(10.5))
                    .foregroundStyle(error == nil ? RococoInk.inkSoft : RococoInk.terracotta)
                    .lineLimit(3)
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { _, t in
                let late = t.isOverdue(asOf: snap.date)
                HStack(spacing: 9) {
                    RococoTickRing(task: t, late: late, tick: tick)
                    Text(t.text)
                        .font(RococoType.sans(11))
                        .foregroundStyle(late ? RococoInk.terracotta : RococoInk.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(height: 24, alignment: .leading)
            }
            if let error, !snap.tasks.isEmpty {
                Text(error)
                    .font(RococoType.sans(8.5))
                    .foregroundStyle(RococoInk.terracotta)
                    .lineLimit(2)
                    .padding(.top, 5)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

struct RococoTodaySmall: View {
    var snap: DaySnapshot
    var tick: (TaskItem, AnyView) -> AnyView = { $1 }

    var body: some View {
        let size = BaroqueSize.small.designSize
        ZStack(alignment: .topLeading) {
            RococoSlab()
            RococoTodayList(snap: snap, rows: 4, width: 132, tick: tick)
                .offset(x: 16, y: 13)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The list on the left; on the right an inset panel of the still life's roses, "Small steps, every day" on its dark
/// ground.
struct RococoTodayMedium: View {
    var snap: DaySnapshot
    var tick: (TaskItem, AnyView) -> AnyView = { $1 }

    var body: some View {
        let size = BaroqueSize.medium.designSize
        let panel = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let night = !SkyClock(now: snap.date, weather: snap.weather).isDay
        ZStack(alignment: .topLeading) {
            RococoSlab()
            RococoTodayList(snap: snap, rows: 4, width: 160, tick: tick)
                .offset(x: 18, y: 13)
            ZStack(alignment: .topLeading) {
                RococoPicture(name: "RococoFlowers", night: night)
                RococoScrim {
                    LinearGradient(colors: [.clear, RococoInk.umber.opacity(0.45)], startPoint: .center, endPoint: .bottomTrailing)
                }
                VStack(alignment: .leading, spacing: -4) {
                    Text("Small").font(RococoType.italic(17))
                    Text("steps,").font(RococoType.italic(17))
                    Text("every day").font(RococoType.italic(17))
                    Rectangle().frame(width: 14, height: 0.8).padding(.top, 10)
                }
                .foregroundStyle(RococoInk.cream)
                .shadow(color: RococoInk.shadow.opacity(0.6), radius: 2, x: 0, y: 1)
                .fixedSize()
                .offset(x: 80, y: 74)
            }
            .frame(width: 152, height: 148)
            .clipShape(panel)
            .overlay(panel.strokeBorder(LinearGradient(colors: [.black.opacity(0.25), .clear, .white.opacity(0.3)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .offset(x: 188, y: 8)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The still life's bouquet across the top with "Today" and the date on its dark side; below it, the tasks at a
/// reading size, each with its due note and, for the Daily Brief's tasks, where it came from.
struct RococoTodayLarge: View {
    var snap: DaySnapshot
    var tick: (TaskItem, AnyView) -> AnyView = { $1 }

    var body: some View {
        let size = BaroqueSize.large.designSize
        let band = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let night = !SkyClock(now: snap.date, weather: snap.weather).isDay
        ZStack(alignment: .topLeading) {
            RococoSlab()
            // The band: the middle of the still life, darkened toward the words at its foot.
            RococoPicture(name: "RococoStillLifeLarge", night: night)
                .frame(width: 328, height: 82)
                .overlay(RococoScrim {
                    LinearGradient(colors: [RococoInk.umber.opacity(0.75), RococoInk.umber.opacity(0.2), .clear],
                                   startPoint: .bottom, endPoint: .top)
                })
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Today").font(RococoType.serif(28))
                        Spacer()
                        Text(RococoWords.month(snap.date) + " " + RococoWords.day(snap.date)).font(RococoType.italic(15))
                    }
                    .foregroundStyle(RococoInk.cream)
                    .shadow(color: RococoInk.shadow.opacity(0.7), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 9)
                }
                .clipShape(band)
                .overlay(band.strokeBorder(LinearGradient(colors: [.black.opacity(0.25), .clear, .white.opacity(0.3)],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .offset(x: 10, y: 10)

            // As many tasks as fit: seven short ones, or fewer that wrap.
            ViewThatFits(in: .vertical) {
                ForEach([7, 6, 5, 4, 3], id: \.self) { list($0) }
            }
            .frame(width: 312, height: 252, alignment: .topLeading)
            .offset(x: 18, y: 104)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// The first `rows` tasks (one fewer when a fetch error needs the last line) and the count of the rest.
    private func list(_ rows: Int) -> some View {
        let error = snap.taskError
        let shown = Array(snap.tasks.prefix(error == nil || snap.tasks.isEmpty ? rows : rows - 1))
        let more = snap.tasks.count - shown.count
        return VStack(alignment: .leading, spacing: 8) {
            if snap.tasks.isEmpty {
                Text(error ?? "Nothing due today.")
                    .font(RococoType.italic(17))
                    .foregroundStyle(error == nil ? RococoInk.inkSoft : RococoInk.terracotta)
                    .lineLimit(3)
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { _, t in
                RococoTaskRow(task: t, now: snap.date, tick: tick)
            }
            if (error != nil && !snap.tasks.isEmpty) || more > 0 {
                HStack(alignment: .firstTextBaseline) {
                    if let error, !snap.tasks.isEmpty {
                        Text(error).font(RococoType.sans(9)).foregroundStyle(RococoInk.terracotta).lineLimit(2)
                    }
                    Spacer()
                    if more > 0 {
                        Text(RococoWords.more(more)).font(RococoType.sans(10)).foregroundStyle(RococoInk.inkSoft)
                    }
                }
            }
        }
        .frame(width: 312, alignment: .topLeading)
    }
}

/// One task at the large size: the ring, up to two lines of the task, its due note on the right, and a trailing
/// "(source, …)" note set below as a caption.
struct RococoTaskRow: View {
    var task: TaskItem
    var now: Date
    var tick: (TaskItem, AnyView) -> AnyView = { $1 }

    var body: some View {
        let late = task.isOverdue(asOf: now)
        let (text, source) = TaskParser.sourceNote(task.text, sourcePath: task.sourcePath)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            RococoTickRing(task: task, late: late, tick: tick).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(RococoType.sans(13))
                    .lineSpacing(-1)
                    .foregroundStyle(late ? RococoInk.terracotta : RococoInk.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let source {
                    Text(source.uppercased())
                        .font(RococoType.sansMedium(6.5))
                        .tracking(1.2)
                        .foregroundStyle(RococoInk.inkSoft)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if let due = RococoWords.due(task, now: now) {
                Text(due)
                    .font(RococoType.italic(12.5))
                    .foregroundStyle(late ? RococoInk.terracotta : RococoInk.inkSoft)
                    .fixedSize()
            }
        }
    }
}
