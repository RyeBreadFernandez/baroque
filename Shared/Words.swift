import Foundation

// The words the rococo widgets write, and which photograph each one shows when. Foundation only, so ParserTests and
// MockLab compile it as it ships (both link this file).

/// The user's repainted photographs taking turns (2026-11-08): a new one every three hours on the clock (midnight,
/// 3, 6 …), on the large Day widget and, never the same one at once, on the Photograph widget. The images are
/// RococoPhoto-<name> (696 x 730) and RococoPhoto-<name>-small (328 x 328), cut by scripts/export_rococo_textures.py.
enum RococoPhotos {
    static let hours = 3
    /// All of them, for the Photograph widget, which has no words on it.
    static let all = ["kings-canyon", "valley", "river", "dead-tree", "falls", "bryce", "arch", "zion", "sunset", "zion-canyon"]
    /// The large Day widget's: landscapes with no one where the quote sits (checked by eye, by day and by night, with
    /// MockLab's HEROES=1). The photographs of people (falls, zion, sunset, dead-tree) show only on the Photograph
    /// widget, with nothing over them.
    static let underWords = ["kings-canyon", "valley", "river", "bryce", "arch", "zion-canyon"]

    /// Which three-hour turn of the local day `date` falls in, counted from 1970 so it keeps moving across days: the
    /// local days since 1970 times the turns in a day, plus the turn of the local hour. Read off the local clock, so a
    /// turn starts at 0:00, 3:00, 6:00 … on the days the clocks change too.
    static func turn(_ date: Date, calendar: Calendar = .current) -> Int {
        let cal = gregorian(calendar.timeZone)
        let c = cal.dateComponents([.year, .month, .day, .hour], from: date)
        // The same date at midnight UTC counts whole days since 1970, whatever the local offset is.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = utc.date(from: DateComponents(year: c.year, month: c.month, day: c.day)) ?? date
        let days = Int((midnight.timeIntervalSince1970 / 86_400).rounded(.down))
        return days * (24 / hours) + (c.hour ?? 0) / hours
    }

    /// When the next turn begins: the next local time whose hour is a multiple of `hours`, at minute 0.
    static func nextChange(after date: Date, calendar: Calendar = .current) -> Date {
        let cal = gregorian(calendar.timeZone)
        let next = (cal.component(.hour, from: date) / hours + 1) * hours
        let start = cal.startOfDay(for: date)
        if next >= 24 {
            let tomorrow = cal.date(byAdding: .day, value: 1, to: start) ?? date.addingTimeInterval(86_400)
            return cal.startOfDay(for: tomorrow)
        }
        return cal.date(bySettingHour: next, minute: 0, second: 0, of: start) ?? date.addingTimeInterval(Double(hours) * 3600)
    }

    static func largeName(at date: Date, calendar: Calendar = .current) -> String {
        underWords[turn(date, calendar: calendar) % underWords.count]
    }

    static func large(at date: Date, calendar: Calendar = .current) -> String {
        "RococoPhoto-" + largeName(at: date, calendar: calendar)
    }

    /// Half the list on from the large one, and never the same photograph.
    static func small(at date: Date, calendar: Calendar = .current) -> String {
        var name = all[(turn(date, calendar: calendar) + all.count / 2) % all.count]
        if name == largeName(at: date, calendar: calendar) { name = all[(all.firstIndex(of: name)! + 1) % all.count] }
        return "RococoPhoto-" + name + "-small"
    }

    /// The hour and day are read in a Gregorian calendar on the given clock, whatever calendar the phone uses.
    private static func gregorian(_ zone: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal
    }
}

enum RococoWords {
    static func month(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }

    static func day(_ date: Date) -> String { String(Calendar.current.component(.day, from: date)) }

    /// "4:58": a twelve-hour clock whatever the system setting.
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    static func temp(_ w: WeatherSnapshot?) -> String {
        guard let w else { return "—" }
        return "\(Int(w.temperature.rounded()))°"
    }

    static func more(_ n: Int) -> String { "+ \(n) more" }

    /// A task's due note against the snapshot's day. Nil when undated. Never a weekday name.
    ///
    /// | Due                                       | Says       |
    /// | ----------------------------------------- | ---------- |
    /// | before today                              | "2d late"  |
    /// | today                                     | "today"    |
    /// | tomorrow                                  | "tomorrow" |
    /// | within the next 6 days, in the same month | "the 9th"  |
    /// | anything later, or in another month       | "Dec 5"    |
    static func due(_ task: TaskItem, now: Date, calendar: Calendar = .current) -> String? {
        guard let due = task.due else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 0
        switch days {
        case ..<0: return "\(-days)d late"
        case 0: return "today"
        case 1: return "tomorrow"
        case 2...6 where calendar.isDate(due, equalTo: now, toGranularity: .month):
            return "the " + ordinal(calendar.component(.day, from: due))
        default: return shortDate(due, calendar: calendar)
        }
    }

    /// "Dec 5": a short month and the day.
    static func shortDate(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    /// Today's sunrise or sunset moved onto the snapshot's day.
    static func today(_ d: Date, at now: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: cal.component(.hour, from: d), minute: cal.component(.minute, from: d), second: 0, of: now) ?? d
    }

    /// "10 h 44 m": sunrise to sunset.
    static func daylight(_ snap: DaySnapshot) -> String? {
        guard let w = snap.weather, let rise = w.sunrise, let set = w.sunset else { return nil }
        let m = max(0, Int((today(set, at: snap.date).timeIntervalSince(today(rise, at: snap.date)) / 60).rounded()))
        return m >= 60 ? "\(m / 60) h \(m % 60) m" : "\(m) m"
    }

    /// "tomorrow", then "the 6th", "the 7th": no weekday names. For the forecast's days ahead.
    static func dayName(_ date: Date, from now: Date) -> String {
        let cal = Calendar.current
        let offset = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        if offset == 1 { return "tomorrow" }
        return "the " + ordinal(cal.component(.day, from: date))
    }

    /// "1st", "2nd", "3rd", "11th", "22nd".
    static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 10, n % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    /// Whether a line is short enough to set in script (Savoye only reads at a large size).
    static func fitsScript(_ text: String) -> Bool {
        text.count <= 26 && text.split(separator: " ").count <= 5
    }

    /// The quote's words inside curly quotation marks, the author left outside them (2026-11-12: "I want the
    /// quotations to be in the quotes part of the quote"). Marks the vault already put round the whole line are taken
    /// off first, so they're never doubled, and quotation marks inside become single ones, as nested quotes are set.
    static func quoted(_ text: String) -> String {
        "\u{201C}" + inner(text) + "\u{201D}"
    }

    /// The words without marks round the whole line, their inner double quotation marks made single.
    static func inner(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let opens: Set<Character> = ["\u{201C}", "\"", "\u{201E}", "\u{00AB}"]
        let closes: Set<Character> = ["\u{201D}", "\"", "\u{201C}", "\u{00BB}"]
        if t.count >= 2, let first = t.first, let last = t.last, opens.contains(first), closes.contains(last) {
            t = String(t.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        var out = ""
        var openNext = true   // straight marks take turns opening and closing
        for c in t {
            switch c {
            case "\u{201C}": out.append("\u{2018}")
            case "\u{201D}": out.append("\u{2019}")
            case "\"":
                out.append(openNext ? "\u{2018}" : "\u{2019}")
                openNext.toggle()
            default: out.append(c)
            }
        }
        return out
    }
}
