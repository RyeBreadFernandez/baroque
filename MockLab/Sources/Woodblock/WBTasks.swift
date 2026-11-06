import SwiftUI

// Agenda pieces: brush-bar priority marks (one, two, three strokes), due notes, the vermilion "late" stamp, the week band.

struct PriorityMark: View {
    var priority: TaskPriority

    var body: some View {
        switch priority {
        case .highest, .high, .medium:
            // brush numerals: three strokes for the most urgent, one for medium
            Text(priority == .highest ? "三" : (priority == .high ? "二" : "一"))
                .font(WB.minchoBold(12))
                .foregroundStyle(WB.indigo)
        case .none:
            Circle().stroke(WB.sumi.opacity(0.5), lineWidth: 0.9).frame(width: 4.6, height: 4.6)
        case .low, .lowest:
            Circle().fill(WB.sumi.opacity(0.4)).frame(width: 3.2, height: 3.2)
        }
    }
}

/// "1d late" pressed in vermilion like a small seal; other due notes in italic.
struct DueNote: View {
    var label: String
    var overdue: Bool
    var today: Bool
    var size: CGFloat = 11.5

    var body: some View {
        if overdue {
            Text(label)
                .font(WB.bodoni(size - 0.5))
                .foregroundStyle(WB.vermilionDeep)
                .padding(.horizontal, 4)
                .padding(.vertical, 0.5)
                .background(LateStamp())
                .rotationEffect(.degrees(-3))
        } else {
            Text(label)
                .font(WB.hoeflerItalic(size))
                .foregroundStyle(today ? WB.prussian : WB.sumiSoft)
        }
    }
}

struct LateStamp: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: 0.6, dy: 0.6)
            let box = Geo.roughRect(r, jitter: 0.3, seed: 19, steps: 4)
            ctx.fill(box, with: .color(WB.vermilion.opacity(0.12)))
            ctx.stroke(box, with: .color(WB.vermilion.opacity(0.95)),
                       style: StrokeStyle(lineWidth: 1.1, lineJoin: .round, dash: [18, 1.2, 9, 1]))
        }
    }
}

struct TaskLine: View {
    var task: TaskItem
    var size: CGFloat = 12.5
    var lines: Int = 1
    var showDue: Bool = true

    var overdue: Bool { task.isOverdue(asOf: Mock.now) }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            PriorityMark(priority: task.priority)
                .frame(width: 11, height: 9)
                .alignmentGuide(.firstTextBaseline) { d in d.height * 0.82 }
            Text(task.text)
                .font(WB.hoefler(size))
                .foregroundStyle(WB.sumi)
                .lineLimit(lines)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer(minLength: 4)
            if showDue, let due = Mock.dueLabel(task) {
                DueNote(label: due, overdue: overdue, today: task.isDueToday(asOf: Mock.now), size: size - 1)
                    .fixedSize()
            }
        }
    }
}

/// A faint ruled line, as printed on the scroll.
struct Rule: View {
    var body: some View {
        Rectangle().fill(WB.sumi.opacity(0.16)).frame(height: 0.6)
    }
}

/// The week, written on a mist band: weekday over numeral, today stamped with a small seal.
struct WeekBand: View {
    var date: Date
    var body: some View {
        let cal = Calendar.current
        HStack(spacing: 0) {
            ForEach(Array(WBDate.week(of: date).enumerated()), id: \.offset) { i, d in
                WeekCell(day: d, today: cal.isDate(d, inSameDayAs: date))
                    .frame(maxWidth: .infinity)
                if i < 6 {
                    Rectangle().fill(WB.sumi.opacity(0.22)).frame(width: 0.6, height: 16)
                }
            }
        }
    }
}

struct WeekCell: View {
    var day: Date
    var today: Bool
    var body: some View {
        VStack(spacing: -1) {
            Text(WBDate.weekdayShort(day).uppercased())
                .font(WB.bodoni(9.5))
                .tracking(0.8)
                .opacity(today ? 1 : 0.75)
            Text(WBDate.day(day))
                .font(today ? WB.bodoniBold(15) : WB.bodoni(15))
        }
        .foregroundStyle(today ? WB.washi : WB.sumi)
        .frame(width: 34, height: 29)
        .background {
            if today {
                Canvas { ctx, size in HankoInk(seed: 31).draw(ctx, size); HankoInk(seed: 31).wear(ctx, size) }
                    .rotationEffect(.degrees(-2.5))
            }
        }
    }
}
