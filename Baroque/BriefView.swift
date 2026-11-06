import SwiftUI

// The whole Daily Brief (2026-11-06: "If I click on the daily brief widget can you make it so it pulls up the rest of
// the brief"). The Today widget opens baroque://brief; the app fetches Daily Brief/Today.md from the vault on GitHub,
// keeps the last copy for when it's offline, and sets it out like the note: the title, the summary, each section, its
// tasks and its bullets. Open in Obsidian opens the note itself.

enum Brief {
    static let path = "Daily Brief/Today.md"
    static let url = URL(string: "baroque://brief")!
    /// The note in Obsidian on the phone, in the vault named as on the Mac.
    static let obsidian = URL(string: "obsidian://open?vault=Obsidian%20Vault&file=Daily%20Brief%2FToday")!

    enum Block: Hashable {
        case title(String)
        case section(String)
        case task(String, done: Bool)
        case bullet(String)
        case paragraph(String)
    }

    /// The note's blocks, and its "generated" line from the front matter.
    static func parse(_ markdown: String) -> (blocks: [Block], generated: String?) {
        var lines = markdown.components(separatedBy: .newlines)
        var generated: String?
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            for line in lines[1..<end] where line.hasPrefix("generated:") {
                generated = line.dropFirst("generated:".count).trimmingCharacters(in: .whitespaces)
            }
            lines.removeSubrange(0...end)
        }
        var blocks: [Block] = []
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("## ") {
                blocks.append(.section(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                blocks.append(.title(String(line.dropFirst(2))))
            } else if line.hasPrefix("- [ ] ") || line.lowercased().hasPrefix("- [x] ") {
                let done = !line.hasPrefix("- [ ] ")
                let text = TaskParser.parse(markdown: "- [ ] " + line.dropFirst(6), sourcePath: path).first?.text ?? String(line.dropFirst(6))
                blocks.append(.task(text, done: done))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(.bullet(TaskParser.cleanInline(String(line.dropFirst(2)))))
            } else {
                blocks.append(.paragraph(TaskParser.cleanInline(line)))
            }
        }
        return (blocks, generated)
    }
}

struct BriefView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var snapshot = Store.shared.brief
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let snapshot {
                        content(Brief.parse(snapshot.markdown), fetchedAt: snapshot.fetchedAt)
                    } else if loading {
                        ProgressView().tint(Stone.gold).frame(maxWidth: .infinity).padding(.top, 60)
                    }
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
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
                    Button { openURL(Brief.obsidian) } label: { Label("Open in Obsidian", systemImage: "arrow.up.forward.app") }
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
                Text(text).font(RococoType.serif(30)).foregroundStyle(Stone.gold)
                    .padding(.bottom, 4)
                Text(stamp(note.generated, fetchedAt: fetchedAt))
                    .font(RococoType.sansMedium(9.5)).tracking(1.6).foregroundStyle(Stone.goldFaint)
                    .padding(.bottom, 14)
            case .section(let text):
                Text(text.uppercased())
                    .font(RococoType.sansMedium(11)).tracking(2).foregroundStyle(Stone.gold)
                    .padding(.top, 22).padding(.bottom, 8)
                Rectangle().fill(Stone.gold.opacity(0.3)).frame(height: 0.7).padding(.bottom, 10)
            case .task(let text, let done):
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(done ? Stone.goldMuted : Stone.copperInk)
                    inline(text).strikethrough(done).foregroundStyle(done ? Stone.goldMuted : Stone.parchment)
                }
                .font(RococoType.serif(17))
                .padding(.bottom, 10)
            case .bullet(let text):
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle().fill(Stone.gold).frame(width: 4, height: 4).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
                    inline(text).foregroundStyle(Stone.parchment)
                }
                .font(RococoType.serif(15.5))
                .padding(.bottom, 8)
            case .paragraph(let text):
                inline(text).font(RococoType.italic(17)).foregroundStyle(Stone.parchment)
                    .padding(.bottom, 6)
            }
        }
    }

    /// Bold, italic and links inside a line, as Markdown has them.
    private func inline(_ text: String) -> Text {
        if let a = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(a)
        }
        return Text(text)
    }

    private func stamp(_ generated: String?, fetchedAt: Date) -> String {
        let fetched = "FETCHED \(RococoWords.clock(fetchedAt).uppercased())"
        guard let generated else { return fetched }
        // "2026-11-06 05:42 PT" from the front matter: shown as a time, like the fetch.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/Los_Angeles")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        let written = f.date(from: String(generated.prefix(16))).map { RococoWords.clock($0) } ?? generated
        return "WRITTEN \(written.uppercased())  ·  \(fetched)"
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
            let text = try await GitHubClient(settings: store.settings, token: store.githubToken).fetchText(path: Brief.path)
            let fresh = BriefSnapshot(markdown: text, fetchedAt: Date())
            store.brief = fresh
            snapshot = fresh
            error = nil
        } catch {
            self.error = snapshot == nil
                ? "Couldn't read \(Brief.path): \(error.localizedDescription)"
                : "Showing the copy from \(RococoWords.clock(snapshot!.fetchedAt)); couldn't refresh: \(error.localizedDescription)"
        }
    }
}
