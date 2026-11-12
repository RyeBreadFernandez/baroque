import Foundation

/// Ticking tasks off and keeping them ticked. The app's Brief page, the Today widget's tick button and the widget's
/// loader all go through here.
///
/// Stubbed by the prep commit so every workstream builds against the same names; the real versions remember each
/// tick (`Store.doneTasks`), hide tasks the morning brief lists again, and write pending ticks to the vault.
enum TaskSync {
    /// The tasks that are still open: drops any task that was ticked in the app or on the widget, even when the
    /// morning brief has listed it again unticked (it queues that one to be ticked in the file again).
    static func visible(_ tasks: [TaskItem]) -> [TaskItem] { tasks }

    /// Tries every pending tick or untick once. It never throws; whatever fails stays pending for the next try.
    static func retryPending() async {}
}
