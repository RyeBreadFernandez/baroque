import Foundation

enum WeatherService {
    struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let apparent_temperature: Double
            let weather_code: Int
            let is_day: Int?
        }
        struct Daily: Decodable {
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let weather_code: [Int]
            let sunrise: [Double]?
            let sunset: [Double]?
            let time: [Double]?
            let precipitation_probability_max: [Int?]?
        }
        let current: Current
        let daily: Daily
    }

    static func fetch(latitude: Double, longitude: Double, fahrenheit: Bool) async throws -> WeatherSnapshot {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset,precipitation_probability_max"),
            URLQueryItem(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
            URLQueryItem(name: "forecast_days", value: "5"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime")
        ]
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "Weather", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Weather HTTP \(http.statusCode)"])
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        // Today is the first daily row; the rest are the days ahead.
        let d = r.daily
        let ahead: [ForecastDay] = (d.time ?? []).indices.dropFirst().compactMap { i in
            guard i < d.temperature_2m_max.count, i < d.temperature_2m_min.count, i < d.weather_code.count else { return nil }
            return ForecastDay(date: Date(timeIntervalSince1970: d.time![i]), high: d.temperature_2m_max[i],
                               low: d.temperature_2m_min[i], code: d.weather_code[i],
                               rain: d.precipitation_probability_max.flatMap { i < $0.count ? $0[i] : nil })
        }
        return WeatherSnapshot(
            temperature: r.current.temperature_2m,
            apparent: r.current.apparent_temperature,
            high: r.daily.temperature_2m_max.first ?? r.current.temperature_2m,
            low: r.daily.temperature_2m_min.first ?? r.current.temperature_2m,
            code: r.current.weather_code,
            fetchedAt: Date(),
            isDay: r.current.is_day.map { $0 == 1 },
            sunrise: r.daily.sunrise?.first.map { Date(timeIntervalSince1970: $0) },
            sunset: r.daily.sunset?.first.map { Date(timeIntervalSince1970: $0) },
            days: ahead
        )
    }
}

enum DataLoader {
    static func dailyNotePath(settings: BaroqueSettings, date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = settings.dailyNoteFormat
        let name = f.string(from: date)
        let folder = settings.dailyNoteFolder.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return folder.isEmpty ? "\(name).md" : "\(folder)/\(name).md"
    }

    static func resolvedTaskPaths(settings: BaroqueSettings) -> [String] {
        settings.taskPaths
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { $0 == "{daily}" ? dailyNotePath(settings: settings) : $0 }
            .reduce(into: [String]()) { paths, p in if !paths.contains(p) { paths.append(p) } } // same file twice would duplicate task ids
    }

    // Fetches every task path. Returns nil tasks when nothing could be read, so callers keep their cache.
    // A missing daily note is normal and not an error; any other failure is reported even if other paths worked.
    static func fetchTasks(client: GitHubClient, settings: BaroqueSettings) async -> (tasks: [TaskItem]?, error: Error?) {
        let dailyPath = dailyNotePath(settings: settings)
        var all: [TaskItem] = []
        var firstError: Error?
        var anySuccess = false
        for path in resolvedTaskPaths(settings: settings) {
            do {
                let text = try await client.fetchText(path: path)
                all.append(contentsOf: TaskParser.parse(markdown: text, sourcePath: path))
                anySuccess = true
            } catch GitHubError.notFound where path == dailyPath {
                continue
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        // A private repo answers 404 without a token, which reads like "file missing". Say what's really wrong.
        if !anySuccess && client.token.isEmpty { return (nil, GitHubError.noToken) }
        if !anySuccess && firstError != nil { return (nil, firstError) }
        return (all, firstError)
    }

    // Loads weather + tasks. Never throws; errors are recorded in the snapshot and cached data is reused.
    static func loadDay() async -> DaySnapshot {
        let store = Store.shared
        let settings = store.settings
        let client = GitHubClient(settings: settings, token: store.githubToken)
        let previous = store.daySnapshot

        async let weatherResult: Result<WeatherSnapshot, Error> = {
            do { return .success(try await WeatherService.fetch(latitude: settings.latitude, longitude: settings.longitude, fahrenheit: settings.useFahrenheit)) }
            catch { return .failure(error) }
        }()
        async let tasksResult = fetchTasks(client: client, settings: settings)

        let w = await weatherResult
        let t = await tasksResult

        // Cached weather is only worth showing on the day it was fetched.
        let cachedWeather = previous?.weather.flatMap { Calendar.current.isDateInToday($0.fetchedAt) ? $0 : nil }
        let cachedTasks = TaskParser.todaysAgenda(previous?.tasks ?? [], includeUndated: settings.includeUndatedTasks, limit: 12)
        var snap = DaySnapshot(date: Date(), weather: cachedWeather, tasks: cachedTasks, taskError: nil, weatherError: nil)
        switch w {
        case .success(let ws): snap.weather = ws
        case .failure(let e): snap.weatherError = e.localizedDescription
        }
        if let fresh = t.tasks {
            snap.tasks = TaskParser.todaysAgenda(fresh, includeUndated: settings.includeUndatedTasks, limit: 12)
        }
        snap.taskError = t.error?.localizedDescription
        store.daySnapshot = snap
        return snap
    }

    static func loadQuotes() async -> QuoteSnapshot {
        let store = Store.shared
        let settings = store.settings
        let client = GitHubClient(settings: settings, token: store.githubToken)
        do {
            let text = try await client.fetchText(path: settings.quotesPath)
            let quotes = QuoteParser.parse(markdown: text)
            let snap = QuoteSnapshot(quotes: quotes, fetchedAt: Date(), error: quotes.isEmpty ? "No quotes found in \(settings.quotesPath)" : nil)
            if !quotes.isEmpty { store.quoteSnapshot = snap }
            return snap
        } catch {
            var snap = store.quoteSnapshot ?? QuoteSnapshot(quotes: [], fetchedAt: Date(), error: nil)
            snap.error = error.localizedDescription
            if case GitHubError.notFound = error, client.token.isEmpty {
                snap.error = GitHubError.noToken.localizedDescription
            }
            return snap
        }
    }

    // Which quote is showing: the next-quote offset plus a wall-clock rotation slot, so the widget's
    // timeline and the app preview agree, and the sequence keeps moving across timeline reloads.
    static func quoteStep(settings: BaroqueSettings) -> TimeInterval {
        TimeInterval(max(5, settings.quoteRotationMinutes) * 60)
    }

    static func quoteSlot(at date: Date, settings: BaroqueSettings) -> Int {
        Int(date.timeIntervalSince1970 / quoteStep(settings: settings))
    }

    static func quoteIndex(count: Int, offset: Int, at date: Date, settings: BaroqueSettings) -> Int {
        guard count > 0 else { return 0 }
        return (offset + quoteSlot(at: date, settings: settings)) % count
    }

    static let fallbackQuotes: [Quote] = [
        Quote(text: "Make the quiet thing first, then the loud one.", author: nil),
        Quote(text: "Good ideas take time.", author: nil),
        Quote(text: "Add quotes to main/Quotes/Quotes.md in your vault to see them here.", author: "Baroque")
    ]
}
