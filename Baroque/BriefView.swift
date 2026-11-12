import SwiftUI

// The whole Daily Brief (2026-11-06: "If I click on the daily brief widget can you make it so it pulls up the rest of
// the brief"). The Today widget opens baroque://brief; the app fetches the brief from the vault on GitHub, keeps the
// last copy for when it's offline, and sets it out like the note: the title, the summary, each section, its tasks and
// its bullets. Open in Obsidian opens the note itself. The reading is Shared/Brief.swift.

struct BriefView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var snapshot = Store.shared.brief
    @State private var error: String?
    @State private var notice: String?
    @State private var loading = false
    /// The note this page reads: the Daily Brief, or the first task path when the brief isn't one.
    private let path = Brief.path(settings: Store.shared.settings)

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
        }
        .tint(Stone.copperLight)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(_ note: (blocks: [Brief.Block], generated: String?), fetchedAt: Date) -> some View {
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
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(task.done ? Stone.goldMuted : Stone.copperInk)
                    Text(verbatim: task.text).strikethrough(task.done).foregroundStyle(task.done ? Stone.goldMuted : Stone.parchment)
                }
                .font(RococoType.serif(17))
                .padding(.bottom, 10)
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
        } catch {
            self.error = snapshot.map { "Showing the copy from \(Brief.when($0.fetchedAt)); couldn't refresh: \(error.localizedDescription)" }
                ?? "Couldn't read \(path): \(error.localizedDescription)"
        }
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
