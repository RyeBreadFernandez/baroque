import SwiftUI

// The To-do widget: an ivory card behind a slim beaded gilt frame on the same damask wall, "Today's errands" set
// in italic over ruled lines, each task with a domed brass stud for its checkbox (oxblood enamel when it is late).

struct GFTodo: View {
    var snapshot: DaySnapshot
    var family: Family

    var body: some View {
        let size = Mock.size(family)
        let frame = GFGeometry.card(family)
        ZStack(alignment: .topLeading) {
            GFWall(size: size, focus: UnitPoint(x: 0.5, y: -0.1), night: false)
            GFFrameShadow(texture: frame.texture)
            GFCard(size: frame.sight.size) {
                if family == .small {
                    GFTodoSmall(snapshot: snapshot)
                } else {
                    GFTodoMedium(snapshot: snapshot)
                }
            }
            .offset(x: frame.sight.minX, y: frame.sight.minY)
            GFFrameGilt(frame: frame)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The ivory card under the frame's sight, its edges a little toned.
struct GFCard<Content: View>: View {
    var size: CGSize
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Mock.texture("weather-gilt-frame/card")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
            RadialGradient(colors: [.clear, Color(hex: 0x5A4024).opacity(0.18)], center: UnitPoint(x: 0.45, y: 0.35),
                           startRadius: min(size.width, size.height) * 0.35, endRadius: max(size.width, size.height) * 0.75)
            content
                .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

/// One task's due note and whether it is late, against the snapshot's own day.
private func gfDue(_ task: TaskItem, _ snapshot: DaySnapshot) -> (String?, Bool) {
    let label = Mock.dueLabel(task, now: snapshot.date)
    return (label, label?.hasSuffix("late") == true)
}

/// A printed rule on the card: a fine double line.
struct GFCardRule: View {
    var body: some View {
        VStack(spacing: 1.2) {
            GFInk.ink.opacity(0.55).frame(height: 0.6)
            GFInk.ink.opacity(0.3).frame(height: 0.4)
        }
    }
}

/// The empty and error lines, in the card's italic.
struct GFTodoNote: View {
    var snapshot: DaySnapshot
    var size: CGFloat

    var body: some View {
        if let error = snapshot.taskError, !error.isEmpty {
            Text("Couldn't fetch tasks: \(error)")
                .font(GFType.italic(size))
                .gfInked(GFInk.oxblood)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        } else if snapshot.tasks.isEmpty {
            Text("Nothing on the list. A quiet day.")
                .font(GFType.italic(size))
                .gfInked(GFInk.inkSoft)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct GFTodoMedium: View {
    var snapshot: DaySnapshot

    var body: some View {
        let tasks = Array(snapshot.tasks.prefix(snapshot.taskError == nil ? 4 : 2))
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's errands")
                    .font(GFType.italic(16))
                    .gfInked()
                Spacer()
                if !snapshot.tasks.isEmpty {
                    Text("\(snapshot.tasks.count)")
                        .font(GFType.numeral(20))
                        .gfInked()
                    Text(snapshot.tasks.count == 1 ? "TASK" : "TASKS")
                        .font(GFType.caps(8))
                        .tracking(1)
                        .gfInked(GFInk.inkSoft)
                }
            }
            .padding(.bottom, 3)
            GFCardRule()
            if snapshot.taskError != nil || tasks.isEmpty {
                GFTodoNote(snapshot: snapshot, size: 13)
                    .padding(.top, 8)
            }
            ForEach(Array(tasks.enumerated()), id: \.offset) { i, task in
                let (due, late) = gfDue(task, snapshot)
                HStack(spacing: 7) {
                    GFStud(late: late, diameter: 7.5)
                    Text(task.text)
                        .font(GFType.serif(12.5))
                        .gfInked()
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    if let due {
                        Text(due.uppercased())
                            .font(GFType.caps(late ? 8.5 : 8))
                            .tracking(0.6)
                            .gfInked(late ? GFInk.oxblood : GFInk.inkSoft)
                            .fixedSize()
                    }
                }
                .frame(height: 19)
                if i < tasks.count - 1 {
                    GFInk.ink.opacity(0.16).frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }
}

struct GFTodoSmall: View {
    var snapshot: DaySnapshot

    var body: some View {
        let tasks = Array(snapshot.tasks.prefix(2))
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(snapshot.tasks.count)")
                    .font(GFType.numeral(26))
                    .gfInked()
                VStack(alignment: .leading, spacing: 0) {
                    Text("Today's")
                        .font(GFType.italic(11))
                        .gfInked(GFInk.inkSoft)
                    Text("errands")
                        .font(GFType.italic(11))
                        .gfInked(GFInk.inkSoft)
                }
            }
            .padding(.bottom, 1)
            GFCardRule()
            if snapshot.taskError != nil || tasks.isEmpty {
                GFTodoNote(snapshot: snapshot, size: 11)
                    .padding(.top, 6)
            } else {
                ForEach(Array(tasks.enumerated()), id: \.offset) { i, task in
                    let (due, late) = gfDue(task, snapshot)
                    HStack(alignment: .top, spacing: 6) {
                        GFStud(late: late, diameter: 7)
                            .padding(.top, 3)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(task.text)
                                .font(GFType.serif(11.5))
                                .gfInked()
                                .lineLimit(i == 0 ? 2 : 1)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: false, vertical: true)
                            if let due {
                                Text(due.uppercased())
                                    .font(GFType.caps(8))
                                    .tracking(0.6)
                                    .gfInked(late ? GFInk.oxblood : GFInk.inkSoft)
                            }
                        }
                    }
                    .padding(.vertical, 3.5)
                    if i < tasks.count - 1 {
                        GFInk.ink.opacity(0.16).frame(height: 0.5)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }
}
