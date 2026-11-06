import SwiftUI

// The snapshot's tasks arranged by when they are due, for the Trail layout. Everything is measured from the
// snapshot's date (not the clock), so a widget timeline entry for tomorrow groups its tasks for tomorrow.

/// Where a task sits on the trail: behind you, where you stand, the week ahead, and beyond it.
enum TRStage: Int, CaseIterable, Identifiable {
    case late, today, soon, someday

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .late: return "Late"
        case .today: return "Today"
        case .soon: return "Soon"
        case .someday: return "Someday"
        }
    }

    /// Small-caps label color: copper for what's behind, gold for today, quieter golds further on.
    var ink: Color {
        switch self {
        case .late: return Stone.copperInk
        case .today: return Stone.gold
        case .soon: return Stone.goldMuted
        case .someday: return Stone.goldFaint
        }
    }
}

struct TRSection: Identifiable {
    var stage: TRStage
    var tasks: [TaskItem]
    /// All tasks in the stage, including any trimmed to fit.
    var total: Int
    var id: Int { stage.rawValue }
}

/// A stop on the medium widget's horizontal trail.
struct TRWaypoint: Identifiable {
    enum Kind: Int { case late, today, tomorrow, later }
    var kind: Kind
    var tasks: [TaskItem]
    var id: Int { kind.rawValue }

    var title: String {
        switch kind {
        case .late: return "Late"
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .later: return "Later"
        }
    }

    var ink: Color {
        switch kind {
        case .late: return Stone.copperInk
        case .today: return Stone.gold
        case .tomorrow: return Stone.goldMuted
        case .later: return Stone.goldFaint
        }
    }
}

struct TRAgenda {
    var now: Date
    /// In the app's agenda order (overdue, today, undated high priority, soon, undated, later).
    var tasks: [TaskItem]

    /// "Soon" is the rest of the week strip: the six days after today.
    static let soonDays = 6

    private var cal: Calendar { .current }
    var today: Date { cal.startOfDay(for: now) }

    /// Whole days from today to the task's day (negative when late). Nil when undated.
    func dayOffset(_ task: TaskItem) -> Int? {
        guard let due = task.due else { return nil }
        return cal.dateComponents([.day], from: today, to: cal.startOfDay(for: due)).day
    }

    func stage(_ task: TaskItem) -> TRStage {
        guard let d = dayOffset(task) else { return .someday }
        if d < 0 { return .late }
        if d == 0 { return .today }
        return d <= Self.soonDays ? .soon : .someday
    }

    /// The four stages in trail order. Inside a stage the agenda order holds (priority first), except
    /// Soon, which follows the calendar so the rows read as days ahead.
    var sections: [TRSection] {
        TRStage.allCases.map { s in
            var list = tasks.enumerated().filter { stage($0.element) == s }
            if s == .soon {
                list.sort { a, b in
                    let x = dayOffset(a.element) ?? 0, y = dayOffset(b.element) ?? 0
                    return x != y ? x < y : a.offset < b.offset
                }
            }
            let items = list.map(\.element)
            return TRSection(stage: s, tasks: items, total: items.count)
        }
    }

    /// Trims the sections to `rows` task rows: every stage with tasks keeps at least one row while there is
    /// room, then the rows fill in trail order. Today always stays, even when empty, as the "you are here" stop.
    func trail(rows: Int) -> [TRSection] {
        let all = sections
        var quota = all.map { _ in 0 }
        var left = max(0, rows)
        for (i, s) in all.enumerated() where !s.tasks.isEmpty && left > 0 {
            quota[i] = 1
            left -= 1
        }
        for (i, s) in all.enumerated() where left > 0 {
            let extra = min(left, s.tasks.count - quota[i])
            quota[i] += extra
            left -= extra
        }
        return all.enumerated().compactMap { i, s in
            if s.tasks.isEmpty && s.stage != .today { return nil }
            return TRSection(stage: s.stage, tasks: Array(s.tasks.prefix(quota[i])), total: s.total)
        }
    }

    /// Today and the six days after it, with how many tasks fall due on each.
    var week: [(date: Date, count: Int)] {
        (0...Self.soonDays).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: today) else { return nil }
            return (d, tasks.filter { dayOffset($0) == i }.count)
        }
    }

    /// Late (only when something is late), Today, Tomorrow, Later.
    var waypoints: [TRWaypoint] {
        var late: [TaskItem] = [], todays: [TaskItem] = [], tomorrow: [TaskItem] = [], later: [TaskItem] = []
        for t in tasks {
            switch dayOffset(t) {
            case let d? where d < 0: late.append(t)
            case 0?: todays.append(t)
            case 1?: tomorrow.append(t)
            default: later.append(t)
            }
        }
        var list = [TRWaypoint(kind: .today, tasks: todays),
                    TRWaypoint(kind: .tomorrow, tasks: tomorrow),
                    TRWaypoint(kind: .later, tasks: later)]
        if !late.isEmpty { list.insert(TRWaypoint(kind: .late, tasks: late), at: 0) }
        return list
    }

    var late: [TaskItem] { tasks.filter { stage($0) == .late } }
    var dueToday: [TaskItem] { tasks.filter { stage($0) == .today } }

    /// The next thing to do: the first task that isn't late (today's most urgent, else whatever comes next).
    var next: TaskItem? { tasks.first { stage($0) != .late } }

    /// A short due label for a row whose stage is already shown: "1d late", "tomorrow", "Thu", "Dec 13".
    func dueLabel(_ task: TaskItem) -> String? {
        guard let d = dayOffset(task), let due = task.due else { return nil }
        if d < 0 { return "\(-d)d late" }
        if d == 0 { return "today" }
        if d == 1 { return "tomorrow" }
        let f = DateFormatter()
        f.dateFormat = d <= Self.soonDays ? "EEE" : "MMM d"
        return f.string(from: due)
    }
}
