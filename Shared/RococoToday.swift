import SwiftUI

// The Today widget in rococo: today's tasks from the vault on painted limestone, each with a carved ring to tick
// (terracotta when late). Medium adds a panel of the flower still life the user sent, with a line in italic.

struct RococoTodayView: View {
    var snapshot: DaySnapshot
    var size: BaroqueSize

    var body: some View {
        RococoFrame(size: size) {
            switch size {
            case .small: RococoTodaySmall(snap: snapshot)
            default: RococoTodayMedium(snap: snapshot)
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

/// "Today", the tasks, and the count of any that don't fit. With a fetch error and tasks to show (the cache), the
/// error takes the last row so it can be read.
struct RococoTodayList: View {
    var snap: DaySnapshot
    var rows: Int
    var width: CGFloat

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
                    RococoRing(late: late)
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

    var body: some View {
        let size = BaroqueSize.small.designSize
        ZStack(alignment: .topLeading) {
            RococoSlab()
            RococoTodayList(snap: snap, rows: 4, width: 132)
                .offset(x: 16, y: 13)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The list on the left; on the right an inset panel of the still life's roses, "Small steps, every day" on its dark
/// ground.
struct RococoTodayMedium: View {
    var snap: DaySnapshot

    var body: some View {
        let size = BaroqueSize.medium.designSize
        let panel = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let night = !SkyClock(now: snap.date, weather: snap.weather).isDay
        ZStack(alignment: .topLeading) {
            RococoSlab()
            RococoTodayList(snap: snap, rows: 4, width: 160)
                .offset(x: 18, y: 13)
            ZStack(alignment: .topLeading) {
                RococoPicture(name: "RococoFlowers", night: night)
                LinearGradient(colors: [.clear, RococoInk.umber.opacity(0.45)], startPoint: .center, endPoint: .bottomTrailing)
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
