import SwiftUI
import UIKit
import WebKit

// The whole Daily Brief (2026-11-06: "If I click on the daily brief widget can you make it so it pulls up the rest of
// the brief"), looking as it does in Obsidian (2026-11-12: "it does not look the same at all. i want it to have the
// same UI"). The Today widget opens baroque://brief. The page fetches the note from the vault on GitHub, with the CSS
// snippets its front matter names and the vault's fonts (BriefStyle), keeps the last copies for when it's offline,
// and shows the note in a web view built as Obsidian's reading view builds it (BriefHTML), styled by the vault's own
// CSS. Each task's checkbox ticks it in the vault (2026-11-11: "the tasks on the app should be clickable so that it
// syncs with obsidian"), through TaskSync. Open in Obsidian opens the note itself.

/// The page's own colours for its native parts (the bar and the messages); the page itself is the vault's CSS.
enum BriefChrome {
    static let cream = Color(hex: 0xFBF6EE)
    static let ink = Color(hex: 0x2A241C)
    static let brown = Color(hex: 0x6B5A3A)
    static let line = Color(hex: 0x785A28, opacity: 0.18)
    /// Quiet's terracotta, 4.5:1 or better on the cream.
    static let problem = Color(hex: 0x713620)
}

struct BriefView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var page = BriefPage()

    var body: some View {
        NavigationStack {
            BriefWebView(webView: page.webView)
                .overlay {
                    if page.snapshot == nil, page.loading { ProgressView().tint(BriefChrome.brown) }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { messages }
                .background(BriefChrome.cream.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }.foregroundStyle(BriefChrome.brown)
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Daily Brief").font(.system(.headline, design: .serif)).foregroundStyle(BriefChrome.ink)
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { Task { await page.load(force: true) } } label: {
                            if page.loading { ProgressView().tint(BriefChrome.brown) } else { Label("Refresh", systemImage: "arrow.clockwise") }
                        }
                        .disabled(page.loading)
                        Button(action: page.openInObsidian) { Label("Open in Obsidian", systemImage: "arrow.up.forward.app") }
                    }
                }
                .toolbarBackground(BriefChrome.cream, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .task { await page.load() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await page.retry() } }
                }
        }
        .tint(BriefChrome.brown)
        // The brief is always a cream page.
        .preferredColorScheme(.light)
    }

    /// Why the brief couldn't be fetched (and that the page shows the last copy), or why Obsidian didn't open.
    @ViewBuilder
    private var messages: some View {
        let lines = [page.error, page.notice].compactMap { $0 }
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.self) { line in
                    Label(line, systemImage: "exclamationmark.triangle")
                        .font(RococoType.sans(13))
                        .foregroundStyle(BriefChrome.problem)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(BriefChrome.cream.overlay(alignment: .top) { BriefChrome.line.frame(height: 0.5) }.ignoresSafeArea())
        }
    }
}

/// The page's web view, made once by `BriefPage`.
private struct BriefWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// The brief, its look and its ticks, and the web view that shows them. The web view is loaded once and then changed
/// in place: when the note, a task's state or the stamp changes, only the blocks that changed are swapped
/// (`baroque.update`), so the page keeps its place.
@MainActor
final class BriefPage: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var snapshot: BriefSnapshot?
    @Published private(set) var error: String?
    @Published private(set) var notice: String?
    @Published private(set) var loading = false

    let webView: WKWebView
    /// The note this page reads and ticks: the Daily Brief, or the first task path when the brief isn't one.
    private let path = Brief.path(settings: Store.shared.settings)
    private var style: BriefStyle.Sheets
    /// Debug builds can give the style from files (`-briefCSS`, `-briefAppearance`); the vault's isn't fetched then.
    private let fixedStyle: Bool

    // Ticks: what's waiting to be written, what's remembered, which taps on this page are being written now, and
    // the problems of taps that are no longer waiting (the task changed in the vault); a task by its line number.
    private var pending = Store.shared.pendingToggles
    private var remembered = Store.shared.doneTasks
    private var saving: Set<Int> = []
    private var retrying = false
    private var problems: [Int: String] = [:]
    /// The note's tasks, as the page last showed them.
    private var tasks: [Brief.TaskLine] = []

    /// What the web view shows, and whether its page has loaded (so `baroque.update` is there).
    private var shown: BriefHTML.Rendered?
    private var ready = false
    private var ranDebugActions = false

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = []
        webView = WKWebView(frame: .zero, configuration: configuration)
        snapshot = Store.shared.brief
        #if DEBUG
        let debugStyle = DebugLaunch.briefStyle()
        #else
        let debugStyle: BriefStyle.Sheets? = nil
        #endif
        fixedStyle = debugStyle != nil
        style = debugStyle ?? BriefStyle.cached(classes: BriefHTML.cssClasses(in: Store.shared.brief?.markdown ?? ""), folder: BriefStyle.folder)
        super.init()
        webView.configuration.userContentController.add(ScriptHandler(page: self), name: "brief")
        webView.navigationDelegate = self
        webView.allowsLinkPreview = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(BriefChrome.cream)
        webView.scrollView.backgroundColor = UIColor(BriefChrome.cream)
        webView.overrideUserInterfaceStyle = .light
        let refresh = UIRefreshControl()
        refresh.tintColor = UIColor(BriefChrome.brown)
        refresh.addTarget(self, action: #selector(pulled(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        #if DEBUG
        webView.isInspectable = true
        #endif
        render()
    }

    // MARK: Loading

    /// Fetches the brief, then the vault's style for it (at most about once a day unless `force`), and shows them.
    func load(force: Bool = false) async {
        let store = Store.shared
        guard !store.githubToken.isEmpty else {
            error = "No GitHub token. Add one in Baroque to read the brief."
            return
        }
        guard !loading else { return }
        loading = true
        defer { loading = false }
        let client = GitHubClient(settings: store.settings, token: store.githubToken)
        do {
            let text = try await client.fetchText(path: path)
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
        if !fixedStyle, let markdown = snapshot?.markdown {
            style = await BriefStyle.refresh(classes: BriefHTML.cssClasses(in: markdown), client: client, folder: BriefStyle.folder, force: force)
        }
        refreshTicks()
        await retry()
    }

    @objc private func pulled(_ control: UIRefreshControl) {
        Task {
            await load(force: true)
            control.endRefreshing()
        }
    }

    /// Writes whatever is waiting (ticks made offline, on the widget, or made again for a task listed anew).
    func retry() async {
        guard !retrying, !Store.shared.pendingToggles.isEmpty else { return }
        retrying = true
        refreshTicks()
        await TaskSync.retryPending()
        retrying = false
        refreshTicks()
    }

    /// The page's copy of what's waiting and remembered, and the brief as the last write left it.
    private func refreshTicks() {
        let store = Store.shared
        pending = store.pendingToggles
        remembered = store.doneTasks
        if let brief = store.brief, brief.fetchedAt > (snapshot?.fetchedAt ?? .distantPast) { snapshot = brief }
        render()
    }

    // MARK: Showing it

    private func pageModel() -> BriefHTML.Page {
        let markdown = snapshot?.markdown ?? ""
        let note = Brief.parse(markdown)
        tasks = note.blocks.compactMap { block -> Brief.TaskLine? in
            if case .task(let task) = block { return task }
            return nil
        }
        return BriefHTML.Page(markdown: markdown, css: style.css, appearance: style.appearance, tasks: taskStates(),
                              footer: snapshot.map { Brief.stamp(generated: note.generated, fetchedAt: $0.fetchedAt) },
                              nonce: BriefHTML.makeNonce())
    }

    /// Shows the brief as it is now: a fresh load when the page's classes or style changed (or it hasn't loaded yet),
    /// otherwise only the blocks that changed (`all`: every block, to undo a tap that wasn't taken).
    private func render(all: Bool = false) {
        let page = pageModel()
        let next = BriefHTML.render(page)
        guard all || next != shown else { return }
        guard let shown, ready, shown.head == next.head else {
            ready = false
            self.shown = next
            webView.loadHTMLString(BriefHTML.document(page, rendered: next), baseURL: nil)
            return
        }
        self.shown = next
        let changed = all || shown.blocks.count != next.blocks.count
            ? Array(next.blocks.indices) : next.blocks.indices.filter { shown.blocks[$0] != next.blocks[$0] }
        guard let blocks = json(next.blocks), let indices = json(changed) else { return }
        webView.evaluateJavaScript("baroque.update(\(blocks), \(indices))") { [weak self] result, error in
            // The page lost its script (or never had it): load it whole.
            if error != nil || (result as? Bool) != true { self?.reload() }
        }
    }

    private func reload() {
        shown = nil
        ready = false
        render()
    }

    private func json(_ value: Any) -> String? {
        (try? JSONSerialization.data(withJSONObject: value)).map { String(decoding: $0, as: UTF8.self) }
    }

    /// Each task's checkbox: ticked as TaskSync shows it, a line while it's saved or why it isn't, and no tap on a
    /// repeating task (ticked here, it would stop repeating).
    private func taskStates() -> [Int: BriefHTML.TaskState] {
        let ticks = TaskSync.shown(tasks, path: path, pending: pending, done: remembered)
        var out: [Int: BriefHTML.TaskState] = [:]
        for task in tasks {
            let shown = ticks[task.lineNumber] ?? (task.done, nil)
            if task.repeats {
                out[task.lineNumber] = .init(done: shown.done, enabled: false, note: "Repeats: tick it in Obsidian")
            } else {
                let note = self.note(for: task, waiting: shown.pending)
                out[task.lineNumber] = .init(done: shown.done, enabled: true, note: note?.text, problem: note?.problem ?? false)
            }
        }
        return out
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

    // MARK: Taps on the page

    fileprivate func received(_ body: Any) {
        guard let message = body as? [String: Any], let kind = message["kind"] as? String else { return }
        switch kind {
        case "tick":
            guard let line = (message["line"] as? NSNumber)?.intValue, let done = message["done"] as? Bool else { return }
            tick(line: line, done: done)
        case "external":
            if let href = message["href"] as? String { openLink(href) }
        case "internal":
            if let path = message["path"] as? String { openNote(path) }
        default:
            break
        }
    }

    /// A checkbox tapped: the tick (or untick) is kept and written as TaskSync does it everywhere. A task the page no
    /// longer has, or a repeating one, goes back as it was.
    private func tick(line: Int, done: Bool) {
        guard let task = tasks.first(where: { $0.lineNumber == line }), !task.repeats else {
            render(all: true)
            return
        }
        let request = PendingToggle(path: path, line: task.line, text: task.text, lineNumber: task.lineNumber, due: task.due, done: done)
        problems[line] = nil
        saving.insert(line)
        TaskSync.record(request)
        refreshTicks()
        Task {
            let outcome = await TaskSync.write(request)
            saving.remove(line)
            if case .failed(let reason) = outcome, !Store.shared.pendingToggles.contains(where: { $0.isSameTap(as: request) }) {
                problems[line] = reason   // not waiting any more: the task changed in the vault
            }
            refreshTicks()
        }
    }

    /// A link in the brief: the web in Safari (mail, phone and Obsidian links in their apps).
    private func openLink(_ href: String) {
        guard let url = URL(string: href), let scheme = url.scheme?.lowercased(),
              ["http", "https", "mailto", "tel", "obsidian"].contains(scheme) else { return }
        UIApplication.shared.open(url)
    }

    /// A link to a note in the vault, opened in Obsidian (a heading or block after `#` is left off).
    private func openNote(_ target: String) {
        let file = String(target.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        open(file.isEmpty ? path : file)
    }

    func openInObsidian() { open(path) }

    private func open(_ file: String) {
        notice = nil
        let vault = Store.shared.settings.obsidianVault
        guard let url = Brief.obsidianURL(vault: vault, path: file) else {
            notice = "Couldn't make a link to \(file) in Obsidian."
            return
        }
        UIApplication.shared.open(url) { [weak self] accepted in
            if !accepted { self?.notice = "Couldn't open Obsidian. Is it installed on this iPhone?" }
        }
    }

    // MARK: WKNavigationDelegate

    /// Only the page itself loads; a link goes to Safari or Obsidian, never inside the web view.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if navigationAction.navigationType == .other, navigationAction.request.url?.absoluteString == "about:blank" { return .allow }
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url { openLink(url.absoluteString) }
        return .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        // Anything that changed while it loaded.
        render()
        #if DEBUG
        if !ranDebugActions {
            ranDebugActions = true
            DebugLaunch.briefLoaded(webView, document: BriefHTML.document(pageModel()))
        }
        #endif
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reload()
    }
}

/// Hands the page's messages to `BriefPage` without the web view keeping it alive.
private final class ScriptHandler: NSObject, WKScriptMessageHandler {
    weak var page: BriefPage?
    init(page: BriefPage) { self.page = page }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        page?.received(message.body)
    }
}
