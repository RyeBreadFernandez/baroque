import SwiftUI

// The few pieces of the painted sky the widgets use: where the sun or moon is on its arc and whether it's day
// (SkyClock, SkyArc), tonight's moon (MoonPhase, MoonLitShape) and hex colours. The app's own painted backdrop
// (Baroque/Theme.swift, Baroque/Landscape.swift) builds on them.

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// Where the sun (or moon) is right now along its arc, from the snapshot's sunrise and sunset.
struct SkyClock {
    var isDay: Bool
    var progress: Double  // 0 at rise, 1 at set (of the sun by day, the moon's arc by night)
    var twilight: Double  // 1 at sunrise or sunset, fading to 0 an hour away

    init(now: Date, weather: WeatherSnapshot?) {
        let cal = Calendar.current
        func today(_ d: Date?, hour: Int, minute: Int) -> Date {
            let c = d.map { cal.dateComponents([.hour, .minute], from: $0) }
            return cal.date(bySettingHour: c?.hour ?? hour, minute: c?.minute ?? minute, second: 0, of: now) ?? now
        }
        let rise = today(weather?.sunrise, hour: 6, minute: 30)
        let set = today(weather?.sunset, hour: 17, minute: 45)
        let t = now.timeIntervalSince1970
        if now >= rise && now <= set {
            isDay = true
            progress = (t - rise.timeIntervalSince1970) / max(1, set.timeIntervalSince(rise))
        } else {
            isDay = false
            let start = now > set ? set : set.addingTimeInterval(-86_400)
            let end = now > set ? rise.addingTimeInterval(86_400) : rise
            progress = (t - start.timeIntervalSince1970) / max(1, end.timeIntervalSince(start))
        }
        let nearest = min(abs(now.timeIntervalSince(rise)), abs(now.timeIntervalSince(set)))
        twilight = max(0, 1 - nearest / 3600)
    }
}

// The half-ellipse the sun and moon travel, in fractions of the widget.
struct SkyArc {
    var centerX: CGFloat
    var horizon: CGFloat
    var radiusX: CGFloat
    var radiusY: CGFloat

    func point(_ progress: Double, in size: CGSize) -> CGPoint {
        let angle = Double.pi * (1 - min(1, max(0, progress)))
        return CGPoint(x: centerX * size.width + radiusX * size.width * CGFloat(cos(angle)),
                       y: horizon * size.height - radiusY * size.height * CGFloat(sin(angle)))
    }
}

// Tonight's moon: the fraction of the way through the lunar month (0 new, 0.5 full).
struct MoonPhase {
    var fraction: Double

    init(date: Date) {
        let knownNew = Date(timeIntervalSince1970: 947_182_440) // 2000-01-06 18:14 UTC
        let month = 29.530588853 * 86_400
        let f = (date.timeIntervalSince(knownNew) / month).truncatingRemainder(dividingBy: 1)
        fraction = f < 0 ? f + 1 : f
    }

    init(fraction: Double) { self.fraction = fraction }

    var waxing: Bool { fraction < 0.5 }
}

// The lit part of the moon: the bright limb on one side, the terminator as a half-ellipse.
struct MoonLitShape: Shape {
    var phase: MoonPhase

    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let side: CGFloat = phase.waxing ? 1 : -1 // waxing moons are lit on the right (northern hemisphere)
        // 1 at new moon, -1 at full; kept off 1 so a new moon still shows a hairline.
        let k = min(0.86, CGFloat(cos(2 * Double.pi * phase.fraction)))
        var p = Path()
        let steps = 36
        for i in 0...steps {
            let a = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
            let pt = CGPoint(x: c.x + side * r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        for i in 0...steps {
            let a = Double.pi / 2 - Double.pi * Double(i) / Double(steps)
            p.addLine(to: CGPoint(x: c.x + side * k * r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a))))
        }
        p.closeSubpath()
        return p
    }
}
