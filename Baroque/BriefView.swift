import SwiftUI

// The whole Daily Brief (2026-11-06: "If I click on the daily brief widget can you make it so it pulls up the rest of
// the brief"). The Today widget opens baroque://brief; the app fetches the brief from the vault on GitHub, keeps the
// last copy for when it's offline, and sets it out like the note: the title, the summary, each section, its tasks and
// its bullets. Each task's ring ticks it in the vault (2026-11-11: "the tasks on the app should be clickable so that
// it syncs with obsidian"), through TaskSync. Open in Obsidian opens the note itself. The reading is Shared/Brief.swift.

struct BriefView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot = Store.shared.brief
    @State private var error: String?
    @State private var notice: String?
    @State private var loading = false
    /// The note this page reads and ticks: the Daily Brief, or the first task path when the brief isn't one.
    private let path = Brief.path(settings: Store.shared.settings)

    // Ticks: what's waiting to be written, what's remembered, which taps on this page are being written now, and
    // the problems of taps that are no longer waiting (the task changed in the vault); a task by its line number.
    @State private var pending = Store.shared.pendingToggles
    @State private var remembered = Store.shared.doneTasks
    @State private var saving: Set<Int> = []
    @State private var retrying = false
    @State private var problems: [Int: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let snapshot {
                        content(Brief.parse(snapshot.markdown), fetchedAt: snapshot.fetchedAt)
                    } else if loading {
                        ProgressView().tint(Stone.gold).frame(maxWidth: .infinity).padding(.top, 60)
                    }
                    ForEach([error, notice].compactMap { $0 }, id: \.self) { line in
                        Label(line, systemImage: "exclamationmark.triangle")
                            .font(RococoType.sans(13))
                            .foregroundStyle(Stone.copperInk)
                            .padding(.top, 18)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
            .background(StoneSurface(material: .appPanel).overlay(Color.black.opacity(0.2)).ignoresSafeArea())
            .navigationTitle("Daily Brief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openInObsidian) { Label("Open in Obsidian", systemImage: "arrow.up.forward.app") }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await retry() } }
            }
        }
        .tint(Stone.copperLight)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(_ note: (blocks: [Brief.Block], generated: String?), fetchedAt: Date) -> some View {
        // Each waiting tap belongs to one task, so two tasks worded alike are ticked one at a time.
        let tasks = note.blocks.compactMap { block -> Brief.TaskLine? in
            if case .task(let task) = block { return task }
            return nil
        }
        let ticks = TaskSync.shown(tasks, path: path, pending: pending, done: remembered)
        ForEach(Array(note.blocks.enumerated()), id: \.offset) { _, block in
            switch block {
            case .title(let text):
                Text(verbatim: text).font(RococoType.serif(30)).foregroundStyle(Stone.gold)
                    .padding(.bottom, 4)
                Text(verbatim: Brief.stamp(generated: note.generated, fetchedAt: fetchedAt))
                    .font(RococoType.sansMedium(9.5)).tracking(1.6).foregroundStyle(Stone.goldFaint)
                    .padding(.bottom, 14)
            case .section(let text):
                Text(verbatim: text.uppercased())
                    .font(RococoType.sansMedium(11)).tracking(2).foregroundStyle(Stone.gold)
                    .padding(.top, 22).padding(.bottom, 8)
                Rectangle().fill(Stone.gold.opacity(0.3)).frame(height: 0.7).padding(.bottom, 10)
            case .task(let task):
                taskRow(task, shown: ticks[task.lineNumber] ?? (task.done, nil))
            case .bullet(let text):
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle().fill(Stone.gold).frame(width: 4, height: 4).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
                    Text(verbatim: text).foregroundStyle(Stone.parchment)
                }
                .font(RococoType.serif(15.5))
                .padding(.bottom, 8)
            case .paragraph(let text):
                Text(verbatim: text).font(RococoType.italic(17)).foregroundStyle(Stone.parchment)
                    .padding(.bottom, 6)
            }
        }
    }

    /// A task: its ring is the tick button, and a line under it says while it's saving or why it isn't saved. A
    /// repeating task's ring is no button, and its line says it's ticked in Obsidian (ticked here, it would stop
    /// repeating).
    private func taskRow(_ task: Brief.TaskLine, shown: (done: Bool, pending: PendingToggle?)) -> some View {
        let note = task.repeats ? (text: "Repeats: tick it in Obsidian", problem: false) : self.note(for: task, waiting: shown.pending)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            if task.repeats {
                ring(done: shown.done)
                    .accessibilityLabel(Text(verbatim: "\(task.text). Repeats: tick it in Obsidian"))
            } else {
                Button { tap(task, done: !shown.done) } label: { ring(done: shown.done) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: shown.done ? "Untick \(task.text)" : "Tick \(task.text)"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: task.text).strikethrough(shown.done).foregroundStyle(shown.done ? Stone.goldMuted : Stone.parchment)
                if let note {
                    Text(verbatim: note.text)
                        .font(RococoType.sans(11.5))
                        .foregroundStyle(note.problem ? Stone.copperInk : Stone.goldFaint)
                }
            }
        }
        .font(RococoType.serif(17))
        .padding(.bottom, 4)
    }

    private func ring(done: Bool) -> some View {
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 14))
            .foregroundStyle(done ? Stone.goldMuted : Stone.copperInk)
            .frame(width: 28, height: 30, alignment: .leading)   // a tap area larger than the ring
            .contentShape(Rectangle())
    }

    /// "Saving…" while a tap is being written; then nothing, or why it isn't written yet.
    private func note(for task: Brief.TaskLine, waiting: PendingToggle?) -> (text: String, problem: Bool)? {
        if saving.contains(task.lineNumber) { return ("Saving…", false) }
        if let waiting {
            if let error = waiting.error { return waiting.retryHelps ? (TaskSync.retryMessage, true) : (error, true) }
            return retrying ? ("Saving…", false) : (TaskSync.retryMessage, true)
        }
        return problems[task.lineNumber].map { ($0, true) }
    }

    private func tap(_ task: Brief.TaskLine, done: Bool) {
        let request = PendingToggle(path: path, line: task.line, text: task.text, lineNumber: task.lineNumber, due: task.due, done: done)
        problems[task.lineNumber] = nil
        saving.insert(task.lineNumber)
        TaskSync.record(request)
        refreshTicks()
        Task {
            let outcome = await TaskSync.write(request)
            saving.remove(task.lineNumber)
            if case .failed(let reason) = outcome, !Store.shared.pendingToggles.contains(where: { $0.isSameTap(as: request) }) {
                problems[task.lineNumber] = reason   // not waiting any more: the task changed in the vault
            }
            refreshTicks()
        }
    }

    /// The page's copy of what's waiting and remembered, and the brief as the last write left it.
    private func refreshTicks() {
        let store = Store.shared
        pending = store.pendingToggles
        remembered = store.doneTasks
        if let brief = store.brief, brief.fetchedAt > (snapshot?.fetchedAt ?? .distantPast) { snapshot = brief }
    }

    /// Writes whatever is waiting (ticks made offline, on the widget, or made again for a task listed anew).
    private func retry() async {
        guard !retrying, !Store.shared.pendingToggles.isEmpty else { return }
        retrying = true
        refreshTicks()
        await TaskSync.retryPending()
        retrying = false
        refreshTicks()
    }

    private func load() async {
        let store = Store.shared
        guard !store.githubToken.isEmpty else {
            error = "No GitHub token. Add one in Baroque to read the brief."
            return
        }
        loading = true
        defer { loading = false }
        do {
            let text = try await GitHubClient(settings: store.settings, token: store.githubToken).fetchText(path: path)
            let fresh = BriefSnapshot(markdown: text, fetchedAt: Date())
            store.brief = fresh
            snapshot = fresh
            error = nil
            // A task ticked before that the brief lists again unticked shows ticked, and is ticked in the file again.
            _ = TaskSync.visible(TaskParser.parse(markdown: text, sourcePath: path))
        } catch {
            self.error = snapshot.map { "Showing the copy from \(Brief.when($0.fetchedAt)); couldn't refresh: \(error.localizedDescription)" }
                ?? "Couldn't read \(path): \(error.localizedDescription)"
        }
        refreshTicks()
        await retry()
    }

    private func openInObsidian() {
        notice = nil
        let vault = Store.shared.settings.obsidianVault
        guard let url = Brief.obsidianURL(vault: vault, path: path) else {
            notice = "Couldn't make a link to \(path) in Obsidian."
            return
        }
        openURL(url) { accepted in
            if !accepted { notice = "Couldn't open Obsidian. Is it installed on this iPhone?" }
        }
    }
}
