import Foundation

enum WeatherError: LocalizedError {
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .http(let code): return "Weather HTTP \(code)"
        }
    }
}

/// Open-Meteo (no key, no account): the current conditions and five days of highs, lows, weather codes, sunrise,
/// sunset and the chance of rain, in one request. The first daily row is today; the rest are the days ahead.
enum WeatherClient {
    private struct Response: Decodable {
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
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw WeatherError.http(http.statusCode) }
        let r = try JSONDecoder().decode(Response.self, from: data)
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
            high: d.temperature_2m_max.first ?? r.current.temperature_2m,
            low: d.temperature_2m_min.first ?? r.current.temperature_2m,
            code: r.current.weather_code,
            fetchedAt: Date(),
            isDay: r.current.is_day.map { $0 == 1 },
            sunrise: d.sunrise?.first.map { Date(timeIntervalSince1970: $0) },
            sunset: d.sunset?.first.map { Date(timeIntervalSince1970: $0) },
            days: ahead
        )
    }
}
