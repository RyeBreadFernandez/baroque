import SwiftUI

// Storybook Night's paint box and type: the frame's dark lacquer, gold leaf for the filigree and headings, cream for the
// figures set over the picture, and on the To-do page, iron-gall ink with red ink for what is late.

enum SBInk {
    static let cream = Color(hex: 0xF3E8CC)
    static let creamDim = Color(hex: 0xD8CBAA)
    static let gold = Color(hex: 0xD9B66C)
    static let goldBright = Color(hex: 0xF4DFA2)
    static let goldDeep = Color(hex: 0x9C7334)
    static let night = Color(hex: 0x060D0C)
    static let lacquer = Color(hex: 0x14110D)
    static let ribbon = Color(hex: 0x24402F)
    static let ribbonDeep = Color(hex: 0x12241A)
    static let ribbonBack = Color(hex: 0x0C1912)
    static let moonlight = Color(hex: 0xF4EBCF)
    static let sunlight = Color(hex: 0xFFE3A6)
    static let ink = Color(hex: 0x30221A)
    static let inkFaded = Color(hex: 0x6B5440)
    static let inkRed = Color(hex: 0x9B3A1E)
    static let rule = Color(hex: 0x8A6A48)
    static let rain = Color(hex: 0x8DB2C8)
}

enum SBFont {
    static func roman(_ size: CGFloat) -> Font { .custom("Cochin", size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", size: size) }
    static func bold(_ size: CGFloat) -> Font { .custom("Cochin-Bold", size: size) }
}

/// Gold leaf: pale where the light strikes the top of each stroke, deeper at its foot.
enum SBGilt {
    static var fill: LinearGradient {
        LinearGradient(colors: [SBInk.goldBright, SBInk.gold, SBInk.goldDeep], startPoint: .top, endPoint: .bottom)
    }
    static var diagonal: LinearGradient {
        LinearGradient(colors: [SBInk.goldBright, SBInk.gold, SBInk.goldDeep], startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
}

extension View {
    /// Type over the picture: a tight dark shadow under each stroke and a soft dark halo, so cream and gold read on the
    /// lightest paint near them.
    func sbLegible(_ strength: Double = 1) -> some View {
        shadow(color: SBInk.night.opacity(min(1, 0.85 * strength)), radius: 0.6, x: 0, y: 0.8)
            .shadow(color: SBInk.night.opacity(min(1, 0.7 * strength)), radius: 4, x: 0, y: 0)
    }

    /// Gold work standing proud of the frame: a hairline shadow below it.
    func sbRaised() -> some View {
        shadow(color: Color.black.opacity(0.7), radius: 0.35, x: 0, y: 0.7)
    }
}

enum SBText {
    /// The month as a chapter number: November is Chapter XI.
    static func roman(_ n: Int) -> String {
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = n, out = ""
        for (v, s) in table {
            while n >= v { out += s; n -= v }
        }
        return out
    }

    static func month(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }

    static func chapter(_ date: Date) -> String {
        "Chapter " + roman(Calendar.current.component(.month, from: date))
    }

    /// "6:14", always on the 12-hour clock (the system may prefer 24-hour).
    static func time(_ date: Date?) -> String {
        guard let date else { return "--" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }
}
