import SwiftUI

/// Field Journal palette and type: a naturalist's sketchbook in daylight.
enum FJ {
    // Paper and ink
    static let paper = Color(hex: 0xF4ECD9)
    static let paperShade = Color(hex: 0xE2D3B4)
    static let ink = Color(hex: 0x3A281A)          // sepia ink
    static let inkSoft = Color(hex: 0x5E4430)
    static let blueInk = Color(hex: 0x27384F)      // iron-gall blue-black, the handwriting pen
    static let pencil = Color(hex: 0x6A655C)
    static let redPencil = Color(hex: 0xBF3328)

    // Watercolour pans
    static let sap = Color(hex: 0x76923C)
    static let sapDeep = Color(hex: 0x4D6628)
    static let olive = Color(hex: 0x8C8A3E)
    static let cerulean = Color(hex: 0x3E8FCC)
    static let ceruleanDeep = Color(hex: 0x2F6A93)
    static let ceruleanPale = Color(hex: 0xA9D0EC)
    static let sienna = Color(hex: 0xB65C2E)
    static let siennaPale = Color(hex: 0xE2A57C)
    static let ochre = Color(hex: 0xDDA640)
    static let ochrePale = Color(hex: 0xF0D08A)
    static let violetGrey = Color(hex: 0x9590B0)
    static let indigoGrey = Color(hex: 0x5D6684)
    static let rose = Color(hex: 0xC97C84)

    // Book cloth under the page stack
    static let cloth = Color(hex: 0x3D4A2E)

    // Type. PostScript names that ship on iOS 17 and macOS.
    static func hand(_ size: CGFloat) -> Font { .custom("BradleyHandITCTT-Bold", size: size) }
    static func note(_ size: CGFloat) -> Font { .custom("Noteworthy-Light", size: size) }
    static func noteBold(_ size: CGFloat) -> Font { .custom("Noteworthy-Bold", size: size) }
    static func serif(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
    static func serifSemi(_ size: CGFloat) -> Font { .custom("Baskerville-SemiBold", size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", size: size) }
    static func italicSemi(_ size: CGFloat) -> Font { .custom("Baskerville-SemiBoldItalic", size: size) }
}

extension Family {
    var paperTexture: String {
        switch self {
        case .small: return "field-journal/paper-small"
        case .medium: return "field-journal/paper-medium"
        case .large: return "field-journal/paper-large"
        }
    }
}

enum FJTex {
    /// The paper-tooth mask as a template image, so `shading` can tint it with pigment.
    static func tooth(_ ctx: GraphicsContext) -> GraphicsContext.ResolvedImage {
        ctx.resolve(Mock.texture("field-journal/tooth").renderingMode(.template))
    }
}

enum FJDates {
    static func string(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = format
        return f.string(from: date)
    }

    /// Monday-first week containing `date`.
    static func week(of date: Date) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
}
