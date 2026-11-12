import Foundation

struct BaroqueSettings: Codable, Equatable {
    // The vault's GitHub repository, entered in the app (a saved setting keeps whatever was entered before).
    var githubOwner: String = ""
    var githubRepo: String = ""
    var githubBranch: String = "main"
    // Newline separated list of vault paths that contain tasks. {daily} expands to today's daily note. Since 2026-11-06
    // the tasks come from the Daily Brief, the note the user's morning brief rewrites in the vault each day.
    var taskPaths: String = BaroqueSettings.dailyBriefPath
    var dailyNoteFolder: String = "daily note"
    var dailyNoteFormat: String = "MM.dd.yyyy - EEEE"
    var quotesPath: String = "main/Quotes/Quotes.md"
    var latitude: Double = 34.0522
    var longitude: Double = -118.2437
    /// True once a location was saved or found in the app. Until then the widgets ask for one rather than quietly
    /// showing the default coordinates' weather. Settings saved before this field existed decode as set.
    var locationSet: Bool = false
    var cityName: String = "Los Angeles"
    var useFahrenheit: Bool = true
    var maxTasks: Int = 5
    var includeUndatedTasks: Bool = true
    var quoteRotationMinutes: Int = 60
    /// The vault's name in Obsidian, for the Brief page's "Open in Obsidian" link.
    var obsidianVault: String = "Obsidian Vault"

    static let `default` = BaroqueSettings()
    /// The note the morning brief rewrites each day. The Brief page reads it, and only its tasks carry a source note.
    static let dailyBriefPath = "Daily Brief/Today.md"
    /// The task paths before the Daily Brief; settings still holding exactly these are moved to it once (Store).
    static let masterListTaskPaths = "Tasks/Master Task List.md\n{daily}"
}

extension BaroqueSettings {
    /// Saved settings decode field by field: a field added in a later version takes its default, instead of making the
    /// whole saved value unreadable (which would quietly reset everything entered in the app).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BaroqueSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback }
        githubOwner = value(.githubOwner, d.githubOwner)
        githubRepo = value(.githubRepo, d.githubRepo)
        githubBranch = value(.githubBranch, d.githubBranch)
        taskPaths = value(.taskPaths, d.taskPaths)
        dailyNoteFolder = value(.dailyNoteFolder, d.dailyNoteFolder)
        dailyNoteFormat = value(.dailyNoteFormat, d.dailyNoteFormat)
        quotesPath = value(.quotesPath, d.quotesPath)
        latitude = value(.latitude, d.latitude)
        longitude = value(.longitude, d.longitude)
        locationSet = value(.locationSet, c.contains(.latitude))
        cityName = value(.cityName, d.cityName)
        useFahrenheit = value(.useFahrenheit, d.useFahrenheit)
        maxTasks = value(.maxTasks, d.maxTasks)
        includeUndatedTasks = value(.includeUndatedTasks, d.includeUndatedTasks)
        quoteRotationMinutes = value(.quoteRotationMinutes, d.quoteRotationMinutes)
        obsidianVault = value(.obsidianVault, d.obsidianVault)
    }
}

/// The three widget families, and the iPhone 17 size in points every layout is drawn at (RococoFrame scales it to
/// the phone's own widget size).
enum BaroqueSize {
    case small, medium, large

    var designSize: CGSize {
        switch self {
        case .small: return CGSize(width: 164, height: 164)
        case .medium: return CGSize(width: 348, height: 164)
        case .large: return CGSize(width: 348, height: 365)
        }
    }
}

/// The Daily Brief note as fetched, for the app's Brief page (the Today widget opens it).
struct BriefSnapshot: Codable, Equatable {
    var markdown: String
    var fetchedAt: Date
}

enum TaskPriority: Int, Codable, Comparable {
    case lowest = 0, low, none, medium, high, highest
    static func < (a: TaskPriority, b: TaskPriority) -> Bool { a.rawValue < b.rawValue }
}

struct TaskItem: Codable, Identifiable, Hashable {
    var id: String { sourcePath + "#" + String(lineNumber) }
    var text: String
    var due: Date?
    var priority: TaskPriority
    var sourcePath: String
    var lineNumber: Int

    var isOverdue: Bool {
        guard let due else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }
    var isDueToday: Bool {
        guard let due else { return false }
        return Calendar.current.isDateInToday(due)
    }
}

struct Quote: Codable, Identifiable, Hashable {
    var id: String { text + "|" + (author ?? "") }
    var text: String
    var author: String?
}

struct WeatherSnapshot: Codable, Hashable {
    var temperature: Double
    var apparent: Double
    var high: Double
    var low: Double
    var code: Int
    var fetchedAt: Date
    var isDay: Bool? = nil // nil in snapshots cached before this field existed
    var sunrise: Date? = nil
    var sunset: Date? = nil
    /// The days after today (the rococo Day widget's "days ahead"); nil in snapshots cached before this field existed.
    var days: [ForecastDay]? = nil

    var symbolName: String { WeatherCode.symbol(for: code, isDay: isDay ?? true) }
    var label: String { WeatherCode.label(for: code) }
}

struct ForecastDay: Codable, Hashable {
    var date: Date
    var high: Double
    var low: Double
    var code: Int
    /// The day's highest chance of rain, in percent.
    var rain: Int?
}

struct DaySnapshot: Codable, Equatable {
    var date: Date
    var weather: WeatherSnapshot?
    var tasks: [TaskItem]
    var taskError: String?
    var weatherError: String?
}

struct QuoteSnapshot: Codable, Equatable {
    var quotes: [Quote]
    var fetchedAt: Date
    var error: String?
}

enum WeatherCode {
    static func label(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Hail"
        default: return "Weather"
        }
    }

    static func symbol(for code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1: return isDay ? "sun.min.fill" : "moon.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

// Date-injectable versions of `isOverdue` / `isDueToday`, so the agenda can be computed
// for a fixed "now" (tests, widget timeline entries). The properties above use Date().
extension TaskItem {
    func isOverdue(asOf now: Date, calendar: Calendar = .current) -> Bool {
        guard let due else { return false }
        return due < calendar.startOfDay(for: now)
    }

    func isDueToday(asOf now: Date, calendar: Calendar = .current) -> Bool {
        guard let due else { return false }
        return calendar.isDate(due, inSameDayAs: now)
    }
}
