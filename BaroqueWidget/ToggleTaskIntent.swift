import AppIntents

/// The Today widget's ring (2026-11-11: tasks can be ticked everywhere). A tap ticks the task in the vault the way the
/// Brief page does, through TaskSync: the tick is remembered and the task leaves the cached snapshot first, so the
/// widget redraws without it; then the write is tried, and if it fails it stays in `Store.pendingToggles` for the app
/// (or the widget's next load) to retry. WidgetKit reloads the timeline when `perform` returns.
///
/// The widget wraps each ring: `Button(intent: ToggleTaskIntent(task)) { ring }.buttonStyle(.plain)`.
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Tick a task"
    static var description = IntentDescription("Ticks a task off in your Obsidian vault.")
    static var isDiscoverable: Bool = false

    /// The vault file the task is in.
    @Parameter(title: "File") var path: String
    /// The task's text as the widget shows it: how it's found in the file when `line` isn't known.
    @Parameter(title: "Task") var text: String
    /// Where it was (1-based) when the widget was drawn; it's preferred when the file has the task more than once.
    @Parameter(title: "Line number") var lineNumber: Int
    /// The line exactly as it was in the file, when known; nil from a `TaskItem`, which doesn't keep it.
    @Parameter(title: "Line") var line: String?
    /// The task's due date, if it has one: it tells the task apart from another with the same words when the lines
    /// have moved since the widget was drawn. Nil in buttons drawn before it was carried.
    @Parameter(title: "Due") var due: Date?
    /// Ticked (true) or unticked.
    @Parameter(title: "Done") var done: Bool

    init() {}

    init(path: String, text: String, lineNumber: Int, line: String? = nil, due: Date? = nil, done: Bool = true) {
        self.path = path
        self.text = text
        self.lineNumber = lineNumber
        self.line = line
        self.due = due
        self.done = done
    }

    /// A tick for a task the widget lists (they're all open, so the default is to tick it).
    init(_ task: TaskItem, done: Bool = true) {
        self.init(path: task.sourcePath, text: task.text, lineNumber: task.lineNumber, due: task.due, done: done)
    }

    func perform() async throws -> some IntentResult {
        await TaskSync.toggle(PendingToggle(path: path, line: line, text: text, lineNumber: lineNumber, due: due, done: done))
        return .result()
    }
}
