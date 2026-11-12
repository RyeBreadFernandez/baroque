import Foundation

// Sample content for the widget gallery and for DEBUG screenshots (launch the app with -seedDemoData).
enum DemoData {
    static func day(now: Date = Date()) -> DaySnapshot {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: today) ?? today }
        let tasks = [
            TaskItem(text: "Finish the chapter 3 exercises", due: days(-1), priority: .high, sourcePath: "Tasks/Master Task List.md", lineNumber: 3),
            TaskItem(text: "Submit the physics lab report with the full error analysis appendix", due: today, priority: .highest, sourcePath: "Tasks/Master Task List.md", lineNumber: 4),
            TaskItem(text: "Email the landlord", due: today, priority: .none, sourcePath: "Tasks/Master Task List.md", lineNumber: 5),
            TaskItem(text: "Pump tires, get gas", due: nil, priority: .high, sourcePath: "Tasks/Master Task List.md", lineNumber: 6),
            TaskItem(text: "Call the dentist", due: days(1), priority: .medium, sourcePath: "Tasks/Master Task List.md", lineNumber: 7),
            TaskItem(text: "Renew parking permit", due: nil, priority: .none, sourcePath: "Tasks/Master Task List.md", lineNumber: 8),
            TaskItem(text: "Plan spring break trip", due: days(40), priority: .low, sourcePath: "Tasks/Master Task List.md", lineNumber: 9)
        ]
        return DaySnapshot(
            date: now,
            weather: WeatherSnapshot(temperature: 64, apparent: 63, high: 68, low: 52, code: 1, fetchedAt: now,
                                     sunrise: cal.date(bySettingHour: 6, minute: 14, second: 0, of: today),
                                     sunset: cal.date(bySettingHour: 16, minute: 58, second: 0, of: today),
                                     days: [ForecastDay(date: days(1), high: 61, low: 49, code: 61, rain: 80),
                                            ForecastDay(date: days(2), high: 63, low: 50, code: 2, rain: 20),
                                            ForecastDay(date: days(3), high: 69, low: 52, code: 0, rain: 0),
                                            ForecastDay(date: days(4), high: 71, low: 53, code: 0, rain: 0)]),
            tasks: TaskParser.todaysAgenda(tasks, includeUndated: true, limit: 12),
            taskError: nil, weatherError: nil)
    }

    static let quotes: [Quote] = [
        Quote(text: "Our life is frittered away by detail.", author: "Henry David Thoreau, Walden"),
        Quote(text: "Begin at once to live, and count each separate day as a separate life.", author: "Seneca"),
        Quote(text: "Make the quiet thing first, then the loud one.", author: nil),
        Quote(text: "Good ideas take time.", author: "unknown")
    ]
}
